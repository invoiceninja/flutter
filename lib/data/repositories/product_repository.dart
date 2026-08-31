import 'dart:async';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/product_dao.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/product_api_model.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/services/products_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';

final _log = Logger('ProductRepository');

/// Local low-stock filter applied over the decoded product page. The server
/// exposes no stock filter dimension, so this is a post-decode predicate on the
/// rows already loaded into Drift (mirrors the billing local-extra-filter
/// pattern). Completeness is therefore bounded by the loaded pages — the
/// Product report is the authoritative full-dataset low-stock / valuation view.
enum StockFilter { none, low, out }

/// Predicate backing [StockFilter] over a decoded [Product]. `out` = nothing on
/// hand (≤ 0). `low` = at/below the effective threshold — the product's own
/// threshold, or the company fallback when the product's is 0 — and so includes
/// out-of-stock. Mirrors the backend `AdjustProductInventory` two-tier check.
bool stockFilterMatches(
  Product p,
  StockFilter filter, {
  required int companyThreshold,
}) {
  switch (filter) {
    case StockFilter.none:
      return true;
    case StockFilter.out:
      return p.inStockQuantity <= Decimal.zero;
    case StockFilter.low:
      final threshold = p.stockNotificationThreshold > Decimal.zero
          ? p.stockNotificationThreshold
          : Decimal.fromInt(companyThreshold);
      return p.inStockQuantity <= threshold;
  }
}

/// Source of truth for Product data. The UI watches Drift via [watchPage]
/// and [watch]; the network only writes. Every mutation goes through the
/// outbox.
///
/// Page size is fixed at [pageSize]. Subsequent pages are fetched only on
/// demand — list screens call [ensurePageLoaded] near the scroll edge.
///
/// Inventory note (deliberate): `in_stock_quantity` is adjusted SERVER-side
/// on invoice sent/paid (`AdjustProductInventory`) with no client mirror or
/// targeted refresh after invoice actions — cached stock badges can lag
/// within a session until the next products delta fetch / refreshAll.
/// Consistent with the Drift-first architecture; revisit only if the lag is
/// reported (the fix would be a products refresh keyed off affected drains).
class ProductRepository extends BaseEntityRepository<Product, ProductApi>
    implements DocumentBearingRepository {
  ProductRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.product,
         requiresPasswordFor: const {
           MutationKind.delete,
           MutationKind.purge,
           MutationKind.documentDelete,
         },
       );

  final ProductsApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'product';

  /// Watch the first [loadedPages] pages worth of rows (so an infinite-scroll
  /// list shows everything fetched so far). [loadedPages] is 1-based — 1
  /// means "show page 1," 2 means "show pages 1+2 contiguously," etc.
  ///
  /// `customFilters` mirrors the server `custom_value1..4` (products carry
  /// the `EntityCustomValueColumns` columns); the single-value server
  /// emission rides the generic VM's `_serverExtraFilters` seam.
  Stream<List<Product>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = ProductFieldIds.productKey,
    bool sortAscending = true,
    Map<int, Set<String>> customFilters = const {},
    String? groupField,
    // Status-tab filter — see `list_status_tabs.dart`.
    String? badgeModeId,
  }) {
    assert(
      loadedPages >= 1,
      'loadedPages is 1-based; pass 1 for the first page',
    );
    return db.productDao
        .watchPage(
          badgeModeId: badgeModeId,
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
          customValues1: customFilters[1] ?? const {},
          customValues2: customFilters[2] ?? const {},
          customValues3: customFilters[3] ?? const {},
          customValues4: customFilters[4] ?? const {},
          groupField: groupField,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  /// Distinct non-empty values populated by products in `companyId` for the
  /// given custom column (1..4). Drives the `custom1:`…`custom4:` filter
  /// tokens' value suggestions and the list's "group by" menu.
  Stream<List<String>> watchDistinctCustomValues({
    required String companyId,
    required int columnIndex,
  }) => db.productDao.watchDistinctCustomValues(
    companyId: companyId,
    columnIndex: columnIndex,
  );

  Stream<int> watchCount({required String companyId}) =>
      db.productDao.watchCount(companyId: companyId);

  /// Live count behind the Products sidebar counter. Plain passthrough like
  /// every other repo — the stock modes' dependency on the company's inventory
  /// settings is resolved inside the query (see
  /// `ProductDao.badgeModePredicate`), so nothing has to be composed here.
  Stream<int> watchBadgeCount({
    required String companyId,
    String modeId = kBadgeModeTotal,
    String currentUserId = '',
  }) => db.productDao.watchBadgeCount(
    companyId: companyId,
    modeId: modeId,
    currentUserId: currentUserId,
  );

  /// Distinct active `product_key` values as `(id, name)` pairs. Backs the
  /// reports product multi-select (the report filter keys on `product_key`).
  /// Mirrors `ClientRepository.watchActiveNames`.
  Stream<List<({String id, String name})>> watchActiveProductKeys({
    required String companyId,
  }) => db.productDao.watchActiveProductKeys(companyId: companyId);

  @override
  Stream<Product?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.productDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Fetch one page from the server and upsert into Drift.
  ///
  /// Idempotent: calling for the same page repeatedly is safe (Drift upserts
  /// are by id). Advances the cursor only on a successful page that returned
  /// data.
  ///
  /// [states] drives the server-side filter. Without it, the cursor only
  /// pulls `(updated_at, id)` slices and the local cache would be missing
  /// archived/deleted rows even when the user has toggled them on.
  ///
  /// [extraFilters] is an open-ended map of flat server query params populated
  /// from the token search field. Each value set is comma-joined. Products
  /// don't expose any token-search filter dimensions today, but the parameter
  /// mirrors `ClientRepository.ensurePageLoaded` so `GenericListViewModel.fetchPage`
  /// (which mandates `extraFilters`) flows uniformly across all entities — the
  /// implementation is a no-op for empty maps.
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) => ensurePageLoadedTemplate(
    companyId: companyId,
    page: page,
    pageSize: pageSize,
    search: search,
    states: states,
    extraFilters: extraFilters,
    ignoreCursor: ignoreCursor,
    // `?include=documents` — see `ClientRepository.ensurePageLoaded` for
    // the rationale.
    staticFilters: const {'include': 'documents'},
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.productDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: byId,
    ),
  );

  /// Pull-to-refresh / foreground-resume entry point.
  ///
  /// **[full] resets the cursor; it does NOT shorten the walk.** Page 1 of a
  /// non-full pass does apply the cursor, but `hasMoreAfterPage` returns true
  /// for ANY cursor'd page (deliberately — concluding "end of list" from a
  /// short delta latched `hasMore = false` and capped every warm-session list
  /// at one page), and `shouldReadCursor` then drops the cursor for `page > 1`.
  /// So pages 2..N are plain offset pages of the whole list and the loop only
  /// stops on a short one: both `full: true` and `full: false` cost the same
  /// number of requests. Lists converge on id-keyed upserts plus this periodic
  /// full walk (see CLAUDE.md § Sync); do not read [full] as "cheap refresh".
  ///
  /// Filter-agnostic by design: we pull every state into the local cache so
  /// the UI's state filter can flip between active/archived/deleted without
  /// re-hitting the network. The local watch stream applies the user's
  /// current selection on top.
  Future<void> refreshAll({
    required String companyId,
    bool full = false,
  }) async {
    if (full) {
      await db.syncStateDao.reset(
        companyId: companyId,
        entityType: entityTypeName,
      );
    }
    var page = 1;
    var hasMore = true;
    const maxPages = 1000; // 50 rows × 1000 = 50 000 products
    final allStates = EntityState.values.toSet();
    while (hasMore) {
      hasMore = await ensurePageLoaded(
        companyId: companyId,
        page: page,
        states: allStates,
        ignoreCursor: full && page == 1,
      );
      page++;
      if (page > maxPages) {
        _log.warning(
          'refreshAll hit the $maxPages page safety cap for company '
          '$companyId — cursor will resume on the next sync trigger.',
        );
        break;
      }
    }
  }

  /// Create a new product offline. Returns the product with its tmp id so the
  /// UI can navigate to the detail screen immediately.
  Future<SaveResult<Product>> create({
    required String companyId,
    required Product draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.productDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
        payload: stored.toApiJson(),
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  /// Save an existing product. The local row updates instantly via the watch
  /// stream; the outbox handles the round-trip.
  ///
  /// [stockChanged] must be true when the user edited `in_stock_quantity`.
  /// The server's `UpdateProductRequest` silently drops `in_stock_quantity`
  /// from a plain `PUT /products/{id}` unless the request also carries
  /// `?update_in_stock_quantity=true` — so without the flag the edit would be
  /// discarded and overwritten by the server's prior count on the next sync.
  /// We ride the flag in via the reserved [kSaveQueryPayloadKey], which the
  /// sync dispatcher strips from the body and promotes to the query string.
  /// Only sent when the user actually changed the count, so a normal edit
  /// never re-pushes (and thus never clobbers server-side inventory
  /// adjustments from invoice/PO posting).
  Future<SaveResult<Product>> save({
    required String companyId,
    required Product product,
    bool stockChanged = false,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(product.id);
    if (resolvedId != product.id) product = product.copyWith(id: resolvedId);

    // dedup deletes the prior pending update for this product and this save
    // replaces it. If that pending row already carried the stock flag (e.g.
    // an offline stock edit, then a navigate-away + non-stock edit), inherit
    // it so the queued stock change isn't silently dropped. Online, the prior
    // row has usually already drained, so there's nothing to inherit.
    var includeStockParam = stockChanged;
    if (!includeStockParam) {
      final pending = await db.outboxDao
          .watchPendingForEntity(
            companyId: companyId,
            entityType: entityTypeName,
            entityId: product.id,
            kind: MutationKind.update,
          )
          .first;
      includeStockParam = pending.any(_carriesStockParam);
    }
    final payload = product.toApiJson(preserveTempId: true);
    if (includeStockParam) {
      payload[kSaveQueryPayloadKey] = const {
        'update_in_stock_quantity': 'true',
      };
    }
    final companion = _domainToCompanion(product, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.productDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: product.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: product.id,
        kind: MutationKind.update,
        payload: payload,
      );
    });
    return SaveResult(entity: product, outboxRowId: rowId);
  }

  /// Permanently destroy the product. Irreversible. The outbox row carries
  /// `requiresPassword=true` so the sync engine prompts via
  /// `ConfirmPasswordSheet` before hitting `POST /products/:id/purge`.
  /// Queue a document upload for this product. See
  /// `ClientRepository.uploadDocument` for the lifecycle notes — same
  /// payload shape, same outbox kind.
  @override
  Future<void> uploadDocument({
    required String companyId,
    required String entityId,
    required UploadSource source,
  }) {
    return enqueueMutation(
      companyId: companyId,
      entityId: entityId,
      kind: MutationKind.documentUpload,
      payload: {'entity_id': entityId, ...source.toPayload()},
    );
  }

  /// Delete one document attached to a product. Password-gated — see
  /// `requiresPasswordFor` above.
  @override
  Future<void> deleteDocument({
    required String companyId,
    required String entityId,
    required String documentId,
  }) {
    return enqueueMutation(
      companyId: companyId,
      entityId: entityId,
      kind: MutationKind.documentDelete,
      payload: {'entity_id': entityId, 'document_id': documentId},
    );
  }

  /// Flip a document's public/private flag.
  @override
  Future<void> setDocumentVisibility({
    required String companyId,
    required String entityId,
    required String documentId,
    required bool isPublic,
  }) {
    return enqueueMutation(
      companyId: companyId,
      entityId: entityId,
      kind: MutationKind.documentVisibility,
      payload: {
        'entity_id': entityId,
        'document_id': documentId,
        'is_public': isPublic,
      },
    );
  }

  /// Concrete handler for the `create` round-trip. See base class for
  /// the steps that run inside the transaction.
  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.productDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.productDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required ProductApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.productDao.upsert,
    deleteById: (id) => db.productDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required ProductApi serverResponse,
  }) async {
    await db.productDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.productDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.productDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // -------------------- conversions --------------------

  ProductsCompanion _apiToCompanion(ProductApi a, String companyId) {
    return ProductsCompanion.insert(
      id: a.id,
      companyId: companyId,
      productKey: a.productKey,
      notes: a.notes,
      price: _moneyString(a.price),
      cost: _moneyString(a.cost),
      quantity: _moneyString(a.quantity),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      customValue1: Value(a.customValue1),
      customValue2: Value(a.customValue2),
      customValue3: Value(a.customValue3),
      customValue4: Value(a.customValue4),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      // See `ClientRepository._apiToCompanion` for the rationale — nullable
      // DTO distinguishes JSON-omitted from JSON-empty; `Value.absent()`
      // preserves prior column value on `insertOnConflictUpdate`'s UPDATE
      // branch.
      documents: a.documents == null
          ? const Value.absent()
          : Value(jsonEncode(a.documents!.map((d) => d.toJson()).toList())),
      payload: jsonEncode(a.toJson()),
    );
  }

  ProductsCompanion _domainToCompanion(
    Product p,
    String companyId, {
    required bool isDirty,
  }) {
    return ProductsCompanion.insert(
      id: p.id,
      companyId: companyId,
      productKey: p.productKey,
      notes: p.notes,
      price: p.price.toString(),
      cost: p.cost.toString(),
      quantity: p.quantity.toString(),
      updatedAt: dateToEpochSeconds(p.updatedAt),
      createdAt: Value(dateToEpochSeconds(p.createdAt)),
      archivedAt: p.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(p.archivedAt!)),
      customValue1: Value(p.customValue1),
      customValue2: Value(p.customValue2),
      customValue3: Value(p.customValue3),
      customValue4: Value(p.customValue4),
      isDirty: Value(isDirty),
      isDeleted: Value(p.isDeleted),
      documents: Value(
        jsonEncode(p.documents.map((d) => d.toApi().toJson()).toList()),
      ),
      payload: jsonEncode(p.toApiJson(preserveTempId: true)),
    );
  }

  /// Drop a document from the product's local `documents` JSON column.
  /// Mirror of `ClientRepository.applyDocumentDeleted` — see notes there.
  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    final row = await db.productDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return;
    await (db.update(db.products)
          ..where((p) => p.companyId.equals(companyId) & p.id.equals(entityId)))
        .write(
          ProductsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  /// Replace (or insert) one document in the product's local `documents`
  /// JSON column. Mirror of `ClientRepository.applyDocumentChanged`.
  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.productDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = [
      for (final d in current)
        if (d.id == document.id) document else d,
    ];
    if (!current.any((d) => d.id == document.id)) {
      next.add(document);
    }
    await (db.update(db.products)
          ..where((p) => p.companyId.equals(companyId) & p.id.equals(entityId)))
        .write(
          ProductsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  Product _fromRow(ProductRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = ProductApi.fromJson(json);
    // is_dirty is local-only (not in the API payload), so we layer it on
    // from the Drift row. `documents` lives in its own column (the API
    // `toApiJson` deliberately omits it) — decode separately and overlay.
    return Product.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      // The local save path writes `payload` from `toApiJson`, which
      // deliberately omits the server-assigned timestamps — so a dirty row's
      // decoded `created_at` / `updated_at` fall back to the DTO default of 0
      // and `epochSecondsToUtc` (no zero guard) turns that into 1970. Read
      // them from the authoritative columns instead, exactly as
      // `TagRepository._fromRow` does.
      createdAt: epochSecondsToUtc(row.createdAt),
      updatedAt: epochSecondsToUtc(row.updatedAt),
      documents: decodeDocumentsColumn(row.documents),
    );
  }

  /// Lazily hydrate one product by id when it isn't in the local cache —
  /// a deep-linked record the recipient has never browsed to, a restored
  /// route, or a cross-entity reference off the prefetched page. Cache-gated,
  /// coalesced, and negative-cached; see [ensureLoadedTemplate].
  Future<void> ensureLoaded({required String companyId, required String id}) =>
      ensureLoadedTemplate(
        companyId: companyId,
        id: id,
        fetch: (id) async => (await api.get(id)).data,
        idOf: (a) => a.id,
        toCompanion: (a) => _apiToCompanion(a, companyId),
        upsert: (byId) => db.productDao.upsertAllPreservingDirty(
          companyId: companyId,
          byId: byId,
        ),
      );
}

/// The server sometimes returns money as a number, sometimes as a string;
/// normalize to a string for stable storage.
String _moneyString(Object raw) {
  if (raw is String) return raw;
  return raw.toString();
}

/// True when a pending outbox row's payload carries the
/// `update_in_stock_quantity` save-query flag. Used by [ProductRepository.save]
/// to inherit the flag across a dedup so an offline stock edit isn't dropped
/// by a later non-stock edit to the same product.
bool _carriesStockParam(OutboxRow row) {
  final decoded = jsonDecode(row.payload);
  if (decoded is! Map) return false;
  final saveQuery = decoded[kSaveQueryPayloadKey];
  return saveQuery is Map && saveQuery['update_in_stock_quantity'] == 'true';
}
