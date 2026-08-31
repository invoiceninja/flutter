import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/product_api_model.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/data/services/products_api.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';

import '_base_entity_repository_contract.dart';

/// Covers the universal `BaseEntityRepository` contract via the shared
/// harness and a small set of Product-specific assertions for behavior
/// the contract intentionally doesn't probe (watchPage is_dirty overlay,
/// Decimal price round-trip).
EntityRepositoryContractFixture<Product, ProductApi> _productFixture() =>
    EntityRepositoryContractFixture.build(
      entityType: 'product',
      updatedAtOf: (item) => item.updatedAt,
      buildRepo: (db) => ProductRepository(db: db, api: _FakeProductsApi()),
      buildApiModel:
          ({
            required String id,
            String? displayValue,
            int updatedAt = 1700000000,
          }) => ProductApi(
            id: id,
            productKey: displayValue ?? id,
            updatedAt: updatedAt,
          ),
      fromApi: Product.fromApi,
      editCopy: (item, {required displayValue}) =>
          item.copyWith(productKey: displayValue),
      idOf: (item) => item.id,
      isDirtyOf: (item) => item.isDirty,
      create: (repo, {required companyId, required draft}) =>
          (repo as ProductRepository).create(
            companyId: companyId,
            draft: draft,
          ),
      save: (repo, {required companyId, required entity}) =>
          (repo as ProductRepository).save(
            companyId: companyId,
            product: entity,
          ),
      delete: (repo, {required companyId, required id}) =>
          (repo as ProductRepository).delete(companyId: companyId, id: id),
    );

void main() {
  runEntityRepositoryContract(_productFixture());

  group('ProductRepository — entity-specific', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });
    tearDown(() async {
      await db.close();
    });

    ProductRepository makeRepo() =>
        ProductRepository(db: db, api: _FakeProductsApi());

    test('_fromRow overlays is_dirty so the watchPage list reflects the '
        'unsaved state after restart', () async {
      final repo = makeRepo();
      final draft = Product.fromApi(
        const ProductApi(productKey: 'X', price: '1', updatedAt: 1700000000),
      );
      await repo.create(companyId: 'co', draft: draft);
      final created = await repo
          .watchPage(companyId: 'co', loadedPages: 1)
          .first;
      expect(created, hasLength(1));
      expect(created.first.isDirty, isTrue);
    });

    test('new inventory/tax/image fields survive Product.fromApi/toApiJson '
        'round-trip', () {
      final api = const ProductApi(
        id: 'prod_1',
        productKey: 'Widget',
        price: '10',
        maxQuantity: 99,
        productImage: 'https://example.com/img.png',
        inStockQuantity: 42,
        stockNotification: true,
        stockNotificationThreshold: 5,
        taxId: '3',
        updatedAt: 1700000000,
      );
      final domain = Product.fromApi(api);
      expect(domain.maxQuantity, Decimal.parse('99'));
      expect(domain.productImage, 'https://example.com/img.png');
      expect(domain.inStockQuantity, Decimal.parse('42'));
      expect(domain.stockNotification, isTrue);
      expect(domain.stockNotificationThreshold, Decimal.parse('5'));
      expect(domain.taxId, '3');

      final payload = domain.toApiJson();
      expect(payload['max_quantity'], 99.0);
      expect(payload['product_image'], 'https://example.com/img.png');
      expect(payload['in_stock_quantity'], 42.0);
      expect(payload['stock_notification'], isTrue);
      expect(payload['stock_notification_threshold'], 5.0);
      expect(payload['tax_id'], '3');
    });

    test(
      'read-only server fields (assigned_user_id / user_id / '
      'income_account_id) survive the Product.fromApi/toApiJson round-trip',
      () {
        final api = const ProductApi(
          id: 'prod_1',
          productKey: 'Widget',
          price: '10',
          updatedAt: 1700000000,
          userId: 'creator_1',
          assignedUserId: 'user_9',
          incomeAccountId: 'acct_7',
        );
        final domain = Product.fromApi(api);
        expect(domain.userId, 'creator_1');
        expect(domain.assignedUserId, 'user_9');
        expect(domain.incomeAccountId, 'acct_7');

        final payload = domain.toApiJson();
        expect(payload['assigned_user_id'], 'user_9');
        expect(payload['user_id'], 'creator_1');
        expect(payload['income_account_id'], 'acct_7');

        // assigned_user_id is always emitted (so clearing it unassigns); the
        // other two are omitted when empty.
        final blank = Product.fromApi(
          const ProductApi(productKey: 'Y', updatedAt: 1),
        ).toApiJson();
        expect(blank['assigned_user_id'], '');
        expect(blank.containsKey('user_id'), isFalse);
        expect(blank.containsKey('income_account_id'), isFalse);
      },
    );

    test('uploadDocument enqueues MutationKind.documentUpload with the right '
        'payload and is NOT password-gated', () async {
      final repo = makeRepo();
      await repo.uploadDocument(
        companyId: 'co',
        entityId: 'prod_1',
        source: fileUploadSource('/tmp/foo.pdf'),
      );
      final rows = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 9999999999999,
      );
      final row = rows.firstWhere(
        (r) => r.mutationKind == MutationKind.documentUpload.wireName,
      );
      expect(row.entityId, 'prod_1');
      expect(row.payload, contains('/tmp/foo.pdf'));
      expect(row.requiresPassword, isFalse);
    });

    test('deleteDocument enqueues MutationKind.documentDelete with '
        'requiresPassword=true', () async {
      final repo = makeRepo();
      await repo.deleteDocument(
        companyId: 'co',
        entityId: 'prod_1',
        documentId: 'doc_42',
      );
      final rows = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 9999999999999,
      );
      final row = rows.firstWhere(
        (r) => r.mutationKind == MutationKind.documentDelete.wireName,
      );
      expect(row.requiresPassword, isTrue);
      expect(row.payload, contains('doc_42'));
    });

    test('setDocumentVisibility enqueues MutationKind.documentVisibility '
        'with is_public flag, not password-gated', () async {
      final repo = makeRepo();
      await repo.setDocumentVisibility(
        companyId: 'co',
        entityId: 'prod_1',
        documentId: 'doc_42',
        isPublic: false,
      );
      final rows = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 9999999999999,
      );
      final row = rows.firstWhere(
        (r) => r.mutationKind == MutationKind.documentVisibility.wireName,
      );
      expect(row.requiresPassword, isFalse);
      expect(row.payload, contains('"is_public":false'));
    });

    test(
      'applyDocumentDeleted drops the document from the local row',
      () async {
        final repo = makeRepo();
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: 'prod_1',
          serverResponse: const ProductApi(
            id: 'prod_1',
            productKey: 'Widget',
            updatedAt: 1700000000,
            documents: [
              DocumentApi(id: 'd1', name: 'a.pdf'),
              DocumentApi(id: 'd2', name: 'b.pdf'),
            ],
          ),
        );
        await repo.applyDocumentDeleted(
          companyId: 'co',
          entityId: 'prod_1',
          documentId: 'd1',
        );
        final loaded = await repo.watch(companyId: 'co', id: 'prod_1').first;
        expect(loaded!.documents.map((d) => d.id), ['d2']);
      },
    );

    test('applyDocumentChanged replaces the matching document', () async {
      final repo = makeRepo();
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'prod_1',
        serverResponse: const ProductApi(
          id: 'prod_1',
          productKey: 'Widget',
          updatedAt: 1700000000,
          documents: [DocumentApi(id: 'd1', name: 'a.pdf', isPublic: true)],
        ),
      );
      await repo.applyDocumentChanged(
        companyId: 'co',
        entityId: 'prod_1',
        document: const DocumentApi(id: 'd1', name: 'a.pdf', isPublic: false),
      );
      final loaded = await repo.watch(companyId: 'co', id: 'prod_1').first;
      expect(loaded!.documents.single.isPublic, isFalse);
    });

    test(
      'API response that OMITS the documents field preserves local docs '
      "(regular PUT save's response doesn't include documents, so we must "
      "not wipe what's there — `_apiToCompanion`'s null guard handles this)",
      () async {
        final repo = makeRepo();
        // Seed: a product with one document, simulating an earlier upload.
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: 'prod_1',
          serverResponse: const ProductApi(
            id: 'prod_1',
            productKey: 'Widget',
            updatedAt: 1700000000,
            documents: [DocumentApi(id: 'd1', name: 'a.pdf')],
          ),
        );
        final seeded = await repo.watch(companyId: 'co', id: 'prod_1').first;
        expect(seeded!.documents.map((d) => d.id), ['d1']);

        // ProductApi() with `documents` defaulted (= null) is what we get
        // from a JSON response that omitted the `documents` key — that's
        // what a regular PUT response looks like (no ?include=documents).
        // The guard should leave the local docs alone.
        await repo.applyUpdateResponse(
          companyId: 'co',
          serverResponse: const ProductApi(
            id: 'prod_1',
            productKey: 'Widget v2',
            updatedAt: 1700000100,
            // documents intentionally unset → null
          ),
        );

        final after = await repo.watch(companyId: 'co', id: 'prod_1').first;
        expect(after!.productKey, 'Widget v2', reason: 'update applied');
        expect(
          after.documents.map((d) => d.id),
          ['d1'],
          reason:
              'documents column must survive because `Value.absent()` skips '
              'it on the UPDATE branch of `insertOnConflictUpdate`',
        );
      },
    );

    test(
      'API response that PRESENTS documents as an empty array IS authoritative '
      '(list refresh with `?include=documents` and an entity that genuinely '
      'has no docs server-side — local stale docs must be cleared)',
      () async {
        final repo = makeRepo();
        // Seed: a product with one stale document.
        await repo.applyCreateResponse(
          companyId: 'co',
          tempId: 'prod_1',
          serverResponse: const ProductApi(
            id: 'prod_1',
            productKey: 'Widget',
            updatedAt: 1700000000,
            documents: [DocumentApi(id: 'd1', name: 'a.pdf')],
          ),
        );

        // Now simulate the authoritative empty case: list refresh with
        // ?include=documents returning `documents: []`. Distinct from null —
        // the field was present in the response, just empty (e.g. another
        // device deleted the doc).
        await repo.applyUpdateResponse(
          companyId: 'co',
          serverResponse: const ProductApi(
            id: 'prod_1',
            productKey: 'Widget',
            updatedAt: 1700000100,
            documents: <DocumentApi>[], // present + empty == authoritative
          ),
        );

        final after = await repo.watch(companyId: 'co', id: 'prod_1').first;
        expect(
          after!.documents,
          isEmpty,
          reason:
              'authoritative empty response must clear the local cache so '
              'cross-device deletes propagate after the next list refresh',
        );
      },
    );

    test('Decimal price survives round-trip without precision loss', () async {
      final repo = makeRepo();
      // Seed an existing product with a non-trivial price.
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'prod_1',
        serverResponse: const ProductApi(
          id: 'prod_1',
          productKey: 'Widget',
          price: '10',
          updatedAt: 1700000000,
        ),
      );

      final loaded = await repo.watch(companyId: 'co', id: 'prod_1').first;
      final edited = loaded!.copyWith(
        price: Decimal.parse('15.00'),
        productKey: 'Widget v2',
      );
      await repo.save(companyId: 'co', product: edited);

      final row = await db.productDao
          .watchById(companyId: 'co', id: 'prod_1')
          .first;
      expect(row?.productKey, 'Widget v2');
      expect(row?.isDirty, isTrue);

      // The outbox has both the seed create (it was queued by
      // applyCreateResponse via repo.create) and the update.
      final outbox = await db.outboxDao.nextReady(
        companyId: 'co',
        now: 9999999999999,
      );
      expect(
        outbox.where((r) => r.mutationKind == MutationKind.update.wireName),
        hasLength(1),
      );
    });

    // --- in_stock_quantity save-query (server strips the field on a plain
    // PUT unless `?update_in_stock_quantity=true` rides along) ---

    Future<ProductRepository> seededRepo() async {
      final repo = makeRepo();
      await repo.applyCreateResponse(
        companyId: 'co',
        tempId: 'prod_1',
        serverResponse: const ProductApi(
          id: 'prod_1',
          productKey: 'Widget',
          inStockQuantity: 10,
          updatedAt: 1700000000,
        ),
      );
      return repo;
    }

    test('save(stockChanged: true) rides update_in_stock_quantity into the '
        'outbox payload save-query', () async {
      final repo = await seededRepo();
      final loaded = await repo.watch(companyId: 'co', id: 'prod_1').first;
      await repo.save(
        companyId: 'co',
        product: loaded!.copyWith(inStockQuantity: Decimal.parse('20')),
        stockChanged: true,
      );
      final payload = await _latestUpdatePayload(db);
      expect(payload[kSaveQueryPayloadKey], {
        'update_in_stock_quantity': 'true',
      });
    });

    test(
      'save(stockChanged: false) does NOT send update_in_stock_quantity',
      () async {
        final repo = await seededRepo();
        final loaded = await repo.watch(companyId: 'co', id: 'prod_1').first;
        await repo.save(
          companyId: 'co',
          product: loaded!.copyWith(productKey: 'Renamed'),
        );
        final payload = await _latestUpdatePayload(db);
        expect(payload.containsKey(kSaveQueryPayloadKey), isFalse);
      },
    );

    test('a later non-stock save inherits the stock save-query from a still-'
        'pending stock update (dedup hardening)', () async {
      final repo = await seededRepo();
      final loaded = await repo.watch(companyId: 'co', id: 'prod_1').first;
      // Offline stock edit — param attached, row stays pending.
      await repo.save(
        companyId: 'co',
        product: loaded!.copyWith(inStockQuantity: Decimal.parse('20')),
        stockChanged: true,
      );
      // Non-stock edit; dedup deletes the prior row, but the flag must carry
      // over so the queued stock change isn't silently dropped.
      final afterFirst = await repo.watch(companyId: 'co', id: 'prod_1').first;
      await repo.save(
        companyId: 'co',
        product: afterFirst!.copyWith(productKey: 'Renamed'),
      );
      final updates = await _pendingUpdates(db);
      expect(updates, hasLength(1), reason: 'dedup keeps a single update row');
      expect(jsonDecode(updates.single.payload)[kSaveQueryPayloadKey], {
        'update_in_stock_quantity': 'true',
      });
    });
  });
}

Future<List<OutboxRow>> _pendingUpdates(AppDatabase db) async {
  final outbox = await db.outboxDao.nextReady(
    companyId: 'co',
    now: 9999999999999,
  );
  return outbox
      .where((r) => r.mutationKind == MutationKind.update.wireName)
      .toList();
}

Future<Map<String, dynamic>> _latestUpdatePayload(AppDatabase db) async {
  final updates = await _pendingUpdates(db);
  return jsonDecode(updates.last.payload) as Map<String, dynamic>;
}

class _FakeProductsApi implements ProductsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
