import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/repositories/document_repository.dart';
import 'package:admin/data/repositories/embedded_documents_owner.dart';
import 'package:admin/data/services/company_switched_exception.dart';
import 'package:admin/data/services/documents_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';

/// The company-wide Documents list's repository. What sets it apart from the
/// other list repositories is what the server does with a document — no
/// lifecycle, a hard delete with no tombstone, no parent link in the list
/// response before invoiceninja/invoiceninja#13365 — and every test here pins
/// one consequence of that (`docs/documents-list.md`).
void main() {
  late AppDatabase db;
  late _FakeDocumentsApi api;
  late DocumentRepository repo;
  late _RecordingOwner owner;

  const co = 'co1';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    api = _FakeDocumentsApi();
    repo = DocumentRepository(db: db, api: api);
    owner = _RecordingOwner();
    repo.ownerFor = (type) => owner..lastType = type;
  });
  tearDown(() => db.close());

  DocumentApi doc(
    String id, {
    String name = 'file.pdf',
    int updatedAt = 1000,
    bool isPublic = true,
  }) => DocumentApi(
    id: id,
    name: name,
    type: 'pdf',
    hash: 'h-$id',
    size: 2048,
    isPublic: isPublic,
    createdAt: 900,
    updatedAt: updatedAt,
  );

  Future<List<String>> storedIds() async => [
    for (final r in await db.documentDao.allIds(companyId: co)) r.id,
  ];

  Future<Map<String, Object?>> outboxPayloadOf(int rowId) async {
    final row = await db.outboxDao.byId(rowId);
    return jsonDecode(row!.payload) as Map<String, Object?>;
  }

  group('fetching', () {
    test(
      'never sends a lifecycle status — the documents table has no '
      'is_deleted column, so status=archived|deleted fails server-side',
      () async {
        api.pages[1] = [doc('d1')];
        await repo.ensurePageLoaded(
          companyId: co,
          page: 1,
          states: const {EntityState.archived},
        );
        await repo.refreshAll(companyId: co);
        expect(api.listFilters, isNotEmpty);
        for (final filters in api.listFilters) {
          expect(filters.containsKey('status'), isFalse, reason: '$filters');
          expect(filters.containsKey('is_deleted'), isFalse);
          expect(filters.containsKey('without_deleted_clients'), isFalse);
        }
      },
    );

    test(
      'a page upsert keeps a parent link the list response cannot carry',
      () async {
        await repo.applyRefreshDelta(
          companyId: co,
          parents: [
            (
              type: EntityType.invoice,
              id: 'inv1',
              updatedAt: 1000,
              documents: [doc('d1')],
              prunable: true,
            ),
          ],
        );
        api.pages[1] = [doc('d1', name: 'renamed.pdf', updatedAt: 2000)];
        await repo.ensurePageLoaded(companyId: co, page: 1, ignoreCursor: true);

        final d = await repo.watch(companyId: co, id: 'd1').first;
        expect(d!.name, 'renamed.pdf');
        expect(d.parentType, EntityType.invoice);
        expect(d.parentId, 'inv1');
      },
    );

    test('a server that names the parent fills the link from a list page '
        '(invoiceninja/invoiceninja#13365)', () async {
      // Through `fromJson`, so the wire keys are pinned too — exactly what
      // `DocumentTransformer` sends: the snake_case model name and the
      // hashed id.
      api.pages[1] = [
        DocumentApi.fromJson({
          ...doc('d1').toJson(),
          'documentable_type': 'recurring_invoice',
          'documentable_id': 'ri1',
        }),
      ];
      await repo.ensurePageLoaded(companyId: co, page: 1);

      final d = await repo.watch(companyId: co, id: 'd1').first;
      expect(d!.parentType, EntityType.recurringInvoice);
      expect(d.parentId, 'ri1');
    });
  });

  group('writing', () {
    test('a rename queues only the name — sending the cached is_public too '
        'would undo a "make private" made elsewhere', () async {
      api.pages[1] = [doc('d1')];
      await repo.ensurePageLoaded(companyId: co, page: 1);
      final d = (await repo.watch(companyId: co, id: 'd1').first)!;

      final result = await repo.save(
        companyId: co,
        document: d.copyWith(name: 'new name.pdf'),
      );

      expect(await outboxPayloadOf(result.outboxRowId), {
        'name': 'new name.pdf',
      });
      final local = (await repo.watch(companyId: co, id: 'd1').first)!;
      expect(local.name, 'new name.pdf');
      expect(local.isDirty, isTrue);
    });

    test('a later change of the same file carries the earlier one\'s keys — '
        'the pending row it replaces is deleted', () async {
      api.pages[1] = [doc('d1')];
      await repo.ensurePageLoaded(companyId: co, page: 1);
      final d = (await repo.watch(companyId: co, id: 'd1').first)!;
      await repo.save(
        companyId: co,
        document: d.copyWith(name: 'n.pdf'),
      );
      final renamed = (await repo.watch(companyId: co, id: 'd1').first)!;

      final result = await repo.save(
        companyId: co,
        document: renamed.copyWith(isPublic: false),
      );

      expect(await outboxPayloadOf(result.outboxRowId), {
        'name': 'n.pdf',
        'is_public': false,
      });
      final rows = await db.outboxDao.pendingRowsForEntity(
        companyId: co,
        entityType: 'document',
        entityId: 'd1',
        mutationKind: MutationKind.update.wireName,
      );
      expect(rows, hasLength(1), reason: 'the first save was superseded');
    });

    test(
      'the update echo patches the parent record\'s embedded copy',
      () async {
        await repo.applyRefreshDelta(
          companyId: co,
          parents: [
            (
              type: EntityType.client,
              id: 'c1',
              updatedAt: 1000,
              documents: [doc('d1')],
              prunable: true,
            ),
          ],
        );
        await repo.applyUpdateResponse(
          companyId: co,
          serverResponse: doc('d1', name: 'x.pdf', updatedAt: 3000),
        );
        expect(owner.changed.single, ('c1', 'd1', 'x.pdf'));
        expect(owner.lastType, EntityType.client);
      },
    );

    test('a confirmed delete removes the row and the parent\'s copy', () async {
      await repo.applyRefreshDelta(
        companyId: co,
        parents: [
          (
            type: EntityType.expense,
            id: 'e1',
            updatedAt: 1000,
            documents: [doc('d1')],
            prunable: true,
          ),
        ],
      );
      await repo.delete(companyId: co, id: 'd1');
      // Hidden from the list while the delete is queued.
      expect(await repo.watchPage(companyId: co).first, isEmpty);

      await repo.applyDeleteResponse(companyId: co, id: 'd1');
      expect(await storedIds(), isEmpty);
      expect(owner.deleted.single, ('e1', 'd1'));
    });

    test('discarding a queued delete brings the file back — this list has '
        'no Deleted view to find it in', () async {
      api.pages[1] = [doc('d1')];
      await repo.ensurePageLoaded(companyId: co, page: 1);
      await repo.delete(companyId: co, id: 'd1');
      expect(await repo.watchPage(companyId: co).first, isEmpty);

      await repo.clearLocalDirty(companyId: co, id: 'd1');
      final rows = await repo.watchPage(companyId: co).first;
      expect(rows.single.id, 'd1');
      expect(rows.single.isDirty, isFalse);
    });
  });

  group('the /refresh harvest', () {
    test('links each file to the record that carries it', () async {
      await repo.applyRefreshDelta(
        companyId: co,
        parents: [
          (
            type: EntityType.purchaseOrder,
            id: 'po1',
            updatedAt: 1000,
            documents: [doc('d1'), doc('d2')],
            prunable: true,
          ),
        ],
      );
      final d2 = (await repo.watch(companyId: co, id: 'd2').first)!;
      expect(d2.parentType, EntityType.purchaseOrder);
      expect(d2.parentId, 'po1');
    });

    test('prunes a file its record no longer lists — clean, unqueued and '
        'older than the record only', () async {
      await repo.applyRefreshDelta(
        companyId: co,
        parents: [
          (
            type: EntityType.task,
            id: 't1',
            updatedAt: 1000,
            documents: [
              doc('gone'),
              doc('dirty'),
              doc('queued'),
              doc('newer', updatedAt: 5000),
              doc('kept'),
            ],
            prunable: true,
          ),
        ],
      );
      // A local rename still in the outbox.
      final dirty = (await repo.watch(companyId: co, id: 'dirty').first)!;
      await repo.save(
        companyId: co,
        document: dirty.copyWith(name: 'n'),
      );
      // A record tab's visibility change — queued against the PARENT, so it
      // names the file only in its payload.
      await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: co,
          entityType: 'task',
          entityId: 't1',
          mutationKind: MutationKind.documentVisibility.wireName,
          payload: jsonEncode({
            'entity_id': 't1',
            'document_id': 'queued',
            'is_public': false,
          }),
          idempotencyKey: 'kq',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );

      await repo.applyRefreshDelta(
        companyId: co,
        parents: [
          (
            type: EntityType.task,
            id: 't1',
            updatedAt: 2000,
            documents: [doc('kept')],
            prunable: true,
          ),
        ],
      );

      expect(
        await storedIds(),
        unorderedEquals(['dirty', 'queued', 'newer', 'kept']),
        reason:
            '"newer" postdates the record — an upload confirmed while this '
            'response was in flight',
      );
    });

    test('an older copy that only brings the link writes just the link — '
        'never the stale name over a newer echo', () async {
      api.pages[1] = [doc('d1')];
      await repo.ensurePageLoaded(companyId: co, page: 1);
      // The rename's echo landed: newer than anything the delta can carry.
      await repo.applyUpdateResponse(
        companyId: co,
        serverResponse: doc('d1', name: 'renamed.pdf', updatedAt: 3000),
      );

      // A /refresh the server built before the rename.
      await repo.applyRefreshDelta(
        companyId: co,
        parents: [
          (
            type: EntityType.credit,
            id: 'cr1',
            updatedAt: 1000,
            documents: [doc('d1', name: 'file.pdf', updatedAt: 1000)],
            prunable: true,
          ),
        ],
      );

      final d = (await repo.watch(companyId: co, id: 'd1').first)!;
      expect(d.name, 'renamed.pdf');
      expect(d.parentType, EntityType.credit);
      expect(d.parentId, 'cr1');
    });

    test('a file this session saw deleted is not put back by a refresh built '
        'before the delete — until the list itself returns it', () async {
      await repo.applyRefreshDelta(
        companyId: co,
        parents: [
          (
            type: EntityType.project,
            id: 'p1',
            updatedAt: 1000,
            documents: [doc('d1')],
            prunable: true,
          ),
        ],
      );
      await repo.applyDeleteResponse(companyId: co, id: 'd1');

      await repo.applyRefreshDelta(
        companyId: co,
        parents: [
          (
            type: EntityType.project,
            id: 'p1',
            updatedAt: 1000,
            documents: [doc('d1')],
            prunable: true,
          ),
        ],
      );
      expect(await storedIds(), isEmpty);

      // The server listing it again is proof it exists.
      api.pages[1] = [doc('d1')];
      await repo.ensurePageLoaded(companyId: co, page: 1, ignoreCursor: true);
      expect(await storedIds(), ['d1']);
    });

    test('never prunes from the company\'s own files, whose array is itself '
        'a delta', () async {
      await repo.applyRefreshDelta(
        companyId: co,
        parents: [
          (
            type: EntityType.company,
            id: co,
            updatedAt: 1000,
            documents: [doc('logo')],
            prunable: false,
          ),
        ],
      );
      await repo.applyRefreshDelta(
        companyId: co,
        parents: [
          (
            type: EntityType.company,
            id: co,
            updatedAt: 2000,
            documents: const [],
            prunable: false,
          ),
        ],
      );
      expect(await storedIds(), ['logo']);
    });

    test('a quiet tick writes nothing', () async {
      final parents = <DocumentParentSlice>[
        (
          type: EntityType.group,
          id: 'g1',
          updatedAt: 1000,
          documents: [doc('d1')],
          prunable: true,
        ),
      ];
      await repo.applyRefreshDelta(companyId: co, parents: parents);
      // The raw table, not `watchPage`: its `distinctRows` would hide a
      // rewrite of identical rows, which is exactly the write in question.
      var emissions = 0;
      final sub = db
          .select(db.documentRecords)
          .watch()
          .listen((_) => emissions++);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final settled = emissions;

      await repo.applyRefreshDelta(companyId: co, parents: parents);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        emissions,
        settled,
        reason: 'an unchanged file repainted the list',
      );

      // Control: a changed file is written, and the watch sees it.
      await repo.applyRefreshDelta(
        companyId: co,
        parents: [
          (
            type: EntityType.group,
            id: 'g1',
            updatedAt: 2000,
            documents: [doc('d1', name: 'renamed.pdf', updatedAt: 2000)],
            prunable: true,
          ),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();
      expect(emissions, greaterThan(settled));
    });
  });

  group('the full sweep', () {
    test(
      'removes what the server no longer has, keeping unsynced work',
      () async {
        api.pages[1] = [doc('a'), doc('stale'), doc('dirty'), doc('queued')];
        await repo.ensurePageLoaded(companyId: co, page: 1, ignoreCursor: true);
        final dirty = (await repo.watch(companyId: co, id: 'dirty').first)!;
        await repo.save(
          companyId: co,
          document: dirty.copyWith(name: 'n'),
        );
        await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: co,
            entityType: 'client',
            entityId: 'c1',
            mutationKind: MutationKind.documentVisibility.wireName,
            payload: jsonEncode({
              'entity_id': 'c1',
              'document_id': 'queued',
              'is_public': false,
            }),
            idempotencyKey: 'k',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );

        // Deleted on the web: the server stops listing it.
        api.pages[1] = [doc('a')];
        await repo.refreshAll(companyId: co, full: true);

        expect(await storedIds(), unorderedEquals(['a', 'dirty', 'queued']));
      },
    );

    test('keeps a file a cached record still lists — a restricted user\'s '
        'GET /documents returns only their own uploads', () async {
      // Harvested from a client this user can see, but did not upload.
      await repo.applyRefreshDelta(
        companyId: co,
        parents: [
          (
            type: EntityType.client,
            id: 'c1',
            updatedAt: 1000,
            documents: [doc('theirs'), doc('removed')],
            prunable: true,
          ),
        ],
      );
      // The client as the Sync pass just re-downloaded it: still listing
      // "theirs"; "removed" is gone from it.
      await db.clientDao.upsert(
        ClientsCompanion.insert(
          id: 'c1',
          companyId: co,
          updatedAt: 1000,
          payload: '{}',
          name: 'Acme',
          number: '1',
          email: '',
          displayName: 'Acme',
          balance: '0',
          documents: Value(jsonEncode([doc('theirs').toJson()])),
        ),
      );

      // The narrowed list: only this user's own upload.
      api.pages[1] = [doc('mine')];
      await repo.refreshAll(companyId: co, full: true);

      expect(await storedIds(), unorderedEquals(['mine', 'theirs']));
    });

    test('a partial sweep prunes nothing — its page 1 is a delta', () async {
      api.pages[1] = [doc('a'), doc('b')];
      await repo.ensurePageLoaded(companyId: co, page: 1, ignoreCursor: true);
      api.pages[1] = [doc('a')];
      await repo.refreshAll(companyId: co);
      expect(await storedIds(), unorderedEquals(['a', 'b']));
    });

    test('a company switch mid-sweep prunes nothing — the other company\'s '
        'empty page is not this company\'s end of list', () async {
      // One row a page, so the sweep needs three requests and the switch can
      // land between them; at the default 50, page 2 is never asked for.
      final sweeper = DocumentRepository(db: db, api: api, pageSize: 1);
      // Three clean server copies: no `tmp_` id, no outbox row, and no cached
      // record lists them, so a sweep that reached the end may take any it
      // didn't see.
      api.pages[1] = [doc('a'), doc('b'), doc('c')];
      await sweeper.ensurePageLoaded(
        companyId: co,
        page: 1,
        ignoreCursor: true,
      );
      expect(await storedIds(), unorderedEquals(['a', 'b', 'c']));

      // The sweep: `a` on page 1, `b` on page 2. The user switches company
      // while page 3 is in flight, and it comes back empty — company B's
      // answer, under B's token.
      api.pages
        ..clear()
        ..[1] = [doc('a')]
        ..[2] = [doc('b')];
      api.onList = (page) {
        if (page == 3) sweeper.activeCompanyId = () => 'co_b';
      };

      await expectLater(
        sweeper.refreshAll(companyId: co, full: true),
        throwsA(isA<CompanySwitchedException>()),
      );

      expect(
        await storedIds(),
        contains('c'),
        reason: 'never fetched is not the same as gone',
      );
      final cursor = await db.syncStateDao.read(
        companyId: co,
        entityType: 'document',
      );
      expect(
        cursor.lastFullAt,
        isNull,
        reason: 'a sweep that never finished must not stamp a full sync',
      );
    });
  });

  test(
    'relinkParents names the record from its cached documents column',
    () async {
      api.pages[1] = [doc('d1'), doc('orphan')];
      await repo.ensurePageLoaded(companyId: co, page: 1);
      await db.clientDao.upsert(
        ClientsCompanion.insert(
          id: 'c9',
          companyId: co,
          updatedAt: 1,
          payload: '{}',
          name: 'Acme',
          number: '1',
          email: '',
          displayName: 'Acme',
          balance: '0',
          documents: Value(jsonEncode([doc('d1').toJson()])),
        ),
      );
      // A malformed column must not break the pass.
      await db.invoiceDao.upsert(
        InvoicesCompanion.insert(
          id: 'i9',
          companyId: co,
          updatedAt: 1,
          payload: '{}',
          documents: const Value(''),
        ),
      );

      await repo.relinkParents(companyId: co);

      final d1 = (await repo.watch(companyId: co, id: 'd1').first)!;
      expect(d1.parentType, EntityType.client);
      expect(d1.parentId, 'c9');
      final orphan = (await repo.watch(companyId: co, id: 'orphan').first)!;
      expect(orphan.parentId, isNull);
    },
  );

  test('forgetMissing drops a vanished file and its parent copy, but never '
      'a dirty row', () async {
    await repo.applyRefreshDelta(
      companyId: co,
      parents: [
        (
          type: EntityType.vendor,
          id: 'v1',
          updatedAt: 1000,
          documents: [doc('gone'), doc('edited')],
          prunable: true,
        ),
      ],
    );
    final edited = (await repo.watch(companyId: co, id: 'edited').first)!;
    await repo.save(
      companyId: co,
      document: edited.copyWith(name: 'n'),
    );

    expect(await repo.forgetMissing(companyId: co, documentId: 'gone'), isTrue);
    expect(
      await repo.forgetMissing(companyId: co, documentId: 'edited'),
      isFalse,
    );
    expect(await storedIds(), ['edited']);
    expect(owner.deleted.single, ('v1', 'gone'));
  });
}

class _FakeDocumentsApi implements DocumentsApi {
  /// page → rows. Pages not in the map are empty.
  final Map<int, List<DocumentApi>> pages = {};
  final List<Map<String, String>> listFilters = [];

  /// Called with the requested page before it is answered — what a test uses
  /// to land a company switch while a page is in flight.
  void Function(int page)? onList;

  @override
  Future<({DocumentListApi data, int? cursorUpdatedAt, String? cursorId})>
  list({
    required int page,
    int perPage = 50,
    String? search,
    int? sinceUpdatedAt,
    String? sinceId,
    Map<String, String> filters = const {},
  }) async {
    onList?.call(page);
    listFilters.add(filters);
    final rows = pages[page] ?? const <DocumentApi>[];
    return (
      data: DocumentListApi(data: rows),
      cursorUpdatedAt: rows.isEmpty ? null : rows.last.updatedAt,
      cursorId: rows.isEmpty ? null : rows.last.id,
    );
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RecordingOwner implements EmbeddedDocumentsOwner {
  EntityType? lastType;
  final changed = <(String, String, String)>[];
  final deleted = <(String, String)>[];

  @override
  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async => changed.add((entityId, document.id, document.name));

  @override
  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async => deleted.add((entityId, documentId));
}
