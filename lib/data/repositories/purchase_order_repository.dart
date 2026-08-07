import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/purchase_order_dao.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/purchase_orders_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('PurchaseOrderRepository');

class PurchaseOrderRepository
    extends BaseEntityRepository<PurchaseOrder, PurchaseOrderApi> {
  PurchaseOrderRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.onRelatedEntitiesAffected,
    this.pageSize = 50,
  }) : super(entityType: EntityType.purchaseOrder);

  final PurchaseOrdersApi api;

  /// Fired after a purchase-order mutation applies. When the PO was **converted
  /// to an expense**, the server created a new expense (and set the PO's
  /// `expense_id`); force-refetch that expense so it appears locally (issue #7
  /// sweep, Tier 2). Wired by DI; null in tests that don't exercise it.
  final RelatedEntitiesRefresher? onRelatedEntitiesAffected;
  final int pageSize;

  @override
  String get entityTypeName => 'purchase_order';

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.purchaseOrderDao;

  /// Discard-ghost seam — `SyncRepository.discardOutboxRow` calls this to drop
  /// a never-synced offline create. Without it the base class throws
  /// `UnsupportedError` and the discard aborts before `deleteAllForEntity`,
  /// stranding both the ghost row and its outbox rows.
  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.purchaseOrderDao.deleteById(companyId: companyId, id: id);

  @override
  bool requiresPasswordFor(MutationKind kind) =>
      kind == MutationKind.delete ||
      kind == MutationKind.purge ||
      kind == MutationKind.documentDelete;

  Stream<List<PurchaseOrder>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = PurchaseOrderFieldIds.number,
    bool sortAscending = false,
    String? vendorId,
    Map<int, Set<String>> customFilters = const {},
  }) {
    assert(loadedPages >= 1);
    return db.purchaseOrderDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
          vendorId: vendorId,
          customValues1: customFilters[1] ?? const {},
          customValues2: customFilters[2] ?? const {},
          customValues3: customFilters[3] ?? const {},
          customValues4: customFilters[4] ?? const {},
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<int> watchCount({required String companyId}) =>
      db.purchaseOrderDao.watchCount(companyId: companyId);

  /// Live count behind this entity's sidebar counter badge. [modeId] is one of
  /// the entity's `SidebarBadgeMode` ids; [currentUserId] is read only by the
  /// `assigned_to_me` mode.
  Stream<int> watchBadgeCount({
    required String companyId,
    String modeId = kBadgeModeTotal,
    String currentUserId = '',
  }) => db.purchaseOrderDao.watchBadgeCount(
    companyId: companyId,
    modeId: modeId,
    currentUserId: currentUserId,
  );

  Stream<List<PurchaseOrder>> watchForVendor({
    required String companyId,
    required String vendorId,
  }) {
    if (vendorId.isEmpty) {
      return Stream<List<PurchaseOrder>>.value(const <PurchaseOrder>[]);
    }
    return db.purchaseOrderDao
        .watchForVendor(companyId: companyId, vendorId: vendorId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<PurchaseOrder?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.purchaseOrderDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async {
    // A vendor-scoped fetch (a vendor's Purchase Orders tab) is a filtered
    // view, not a canonical sync — it must neither read nor advance the
    // shared cursor (same contract as `ensurePageLoadedTemplate`).
    final hasVendorScope = extraFilters.containsKey('vendor_id');
    // The shared `(companyId, entityType)` cursor is a page-1, UNSCOPED
    // delta probe only — same two gates as `ensurePageLoadedTemplate`:
    // a parent-scoped fetch (embedded detail tab) must neither read nor
    // advance it, and a page >= 2 fetch must not read it (the
    // `updated_at >=` filter re-returns page 1's rows, capping pagination /
    // search / full resync at one page) nor advance it (deeper pages carry
    // older rows under `id DESC` — last-write-wins would walk the
    // watermark backwards).
    // An active text search is a filtered VIEW: skip the cursor read (search
    // across full history) and the advance below (a search-scoped data.last
    // is not a valid global high-water mark).
    final isSearchScoped = search != null && search.isNotEmpty;
    final cursor =
        (ignoreCursor || hasVendorScope || isSearchScoped || page > 1)
        ? null
        : await db.syncStateDao.read(
            companyId: companyId,
            entityType: entityTypeName,
          );
    final filters = <String, String>{
      ...stateQueryParams(states),
      'include': 'documents',
      for (final entry in extraFilters.entries)
        if (entry.value.isNotEmpty)
          entry.key: (entry.value.toList()..sort()).join(','),
    };
    final result = await api.list(
      page: page,
      perPage: pageSize,
      search: search,
      sinceUpdatedAt: cursor?.updatedAt,
      sinceId: cursor?.id,
      filters: filters,
    );
    final apiRows = result.data.data;
    // Shared rule (see `hasMoreAfterPage`): with the keyset cursor applied a
    // short/empty page is an exhausted DELTA, not end-of-list.
    if (apiRows.isEmpty) {
      return hasMoreAfterPage(
        rowCount: 0,
        cursorApplied: cursor?.isEmpty == false,
        pageSize: pageSize,
      );
    }
    await db.purchaseOrderDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: {for (final a in apiRows) a.id: _apiToCompanion(a, companyId)},
    );
    // Shared rule (see `shouldAdvanceCursor`): only an unscoped,
    // unfiltered page 1 may move the global watermark.
    if (shouldAdvanceCursor(
          page: page,
          hasParentScope: hasVendorScope,
          isSearchScoped: isSearchScoped,
          states: states,
          extraFilters: extraFilters,
        ) &&
        result.cursorUpdatedAt != null &&
        result.cursorId != null) {
      await advanceCursor(
        companyId: companyId,
        updatedAt: result.cursorUpdatedAt!,
        id: result.cursorId!,
        wasFullSync: ignoreCursor,
      );
    }
    return hasMoreAfterPage(
      rowCount: apiRows.length,
      cursorApplied: cursor?.isEmpty == false,
      pageSize: pageSize,
    );
  }

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
    const maxPages = 1000;
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
        _log.warning('refreshAll hit page cap for company $companyId');
        break;
      }
    }
  }

  Future<SaveResult<PurchaseOrder>> create({
    required String companyId,
    required PurchaseOrder draft,
    Map<String, String>? extraQuery,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.purchaseOrderDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
        payload: _withSaveQuery(stored.toApiJson(), extraQuery),
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  Future<SaveResult<PurchaseOrder>> save({
    required String companyId,
    required PurchaseOrder purchaseOrder,
    Map<String, String>? extraQuery,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(purchaseOrder.id);
    if (resolvedId != purchaseOrder.id) {
      purchaseOrder = purchaseOrder.copyWith(id: resolvedId);
    }

    final companion = _domainToCompanion(
      purchaseOrder,
      companyId,
      isDirty: true,
    );
    var rowId = 0;
    await db.transaction(() async {
      await db.purchaseOrderDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: purchaseOrder.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: purchaseOrder.id,
        kind: MutationKind.update,
        payload: _withSaveQuery(
          purchaseOrder.toApiJson(preserveTempId: true),
          extraQuery,
        ),
      );
    });
    return SaveResult(entity: purchaseOrder, outboxRowId: rowId);
  }

  /// Folds a SAVE-PARAM action's query map into the outbox payload under
  /// the reserved key the sync dispatcher promotes to the request's query
  /// string. No-op when no action is pending.
  Map<String, dynamic> _withSaveQuery(
    Map<String, dynamic> payload,
    Map<String, String>? extraQuery,
  ) {
    if (extraQuery != null && extraQuery.isNotEmpty) {
      payload[kSaveQueryPayloadKey] = extraQuery;
    }
    return payload;
  }

  // delete / archive / restore intentionally inherit BaseEntityRepository's
  // implementations, which optimistically flip the local row (is_deleted /
  // archived_at + is_dirty) inside the enqueue transaction so the row leaves
  // the active list immediately offline. (Earlier bespoke overrides here were
  // enqueue-only — no optimistic flip — so an offline delete/archive showed a
  // success toast while the row stayed put; removed.)

  // ── Custom actions ─────────────────────────────────────────────────

  Future<void> markSent({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.markSent,
        payload: {'id': id},
      );

  /// Clears the Postmark bounce/spam suppression for a vendor invitation's
  /// `messageId` via `customActions[reactivateEmail]`. No local update — the
  /// Sends tab refreshes on the next purchase-order sync.
  Future<int> reactivateInvitationEmail({
    required String companyId,
    required String id,
    required String messageId,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.reactivateEmail,
    payload: {'message_id': messageId},
  );

  /// `POST /purchase_orders/bulk {action:'add_to_inventory'}` — record the
  /// PO's line items as received stock and flip Accepted → Received. Server
  /// no-ops once `status_id >= RECEIVED`.
  Future<void> addToInventory({
    required String companyId,
    required String id,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.addToInventory,
    payload: {'id': id},
  );

  Future<void> cancel({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.cancelEntity,
        payload: {'id': id},
      );

  Future<void> convertToExpense({
    required String companyId,
    required String id,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.convertToExpense,
    payload: {'id': id},
  );

  Future<void> email({
    required String companyId,
    required String id,
    required String template,
    String? subject,
    String? body,
    String? ccEmail,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.emailEntity,
    payload: {
      'id': id,
      'template': template,
      if (subject != null) 'subject': subject,
      if (body != null) 'body': body,
      if (ccEmail != null) 'cc_email': ccEmail,
    },
  );

  Future<void> scheduleEmail({
    required String companyId,
    required String id,
    required String template,
    required String sendAt,
    String? subject,
    String? body,
    String? ccEmail,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.scheduleEmail,
    payload: {
      'id': id,
      'template': template,
      'send_at': sendAt,
      if (subject != null) 'subject': subject,
      if (body != null) 'body': body,
      if (ccEmail != null) 'cc_email': ccEmail,
    },
  );

  Future<void> runTemplate({
    required String companyId,
    required String id,
    required String templateId,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.runTemplate,
    payload: {'id': id, 'template_id': templateId},
  );

  Future<void> addComment({
    required String companyId,
    required String purchaseOrderId,
    required String text,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: purchaseOrderId,
    kind: MutationKind.addComment,
    payload: {'entity_id': purchaseOrderId, 'notes': text.trim()},
  );

  // ── Documents ──────────────────────────────────────────────────────

  Future<void> uploadDocument({
    required String companyId,
    required String entityId,
    required UploadSource source,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: entityId,
    kind: MutationKind.documentUpload,
    payload: {'entity_id': entityId, ...source.toPayload()},
  );

  Future<void> deleteDocument({
    required String companyId,
    required String entityId,
    required String documentId,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: entityId,
    kind: MutationKind.documentDelete,
    payload: {'entity_id': entityId, 'document_id': documentId},
  );

  Future<void> setDocumentVisibility({
    required String companyId,
    required String entityId,
    required String documentId,
    required bool isPublic,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: entityId,
    kind: MutationKind.documentVisibility,
    payload: {
      'entity_id': entityId,
      'document_id': documentId,
      'is_public': isPublic,
    },
  );

  // ── Apply* response handlers ───────────────────────────────────────

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required PurchaseOrderApi serverResponse,
  }) async {
    final realId = serverResponse.id;
    await db.transaction(() async {
      await db.purchaseOrderDao.upsert(
        _apiToCompanion(serverResponse, companyId),
      );
      if (realId != tempId) {
        await db.purchaseOrderDao.deleteById(companyId: companyId, id: tempId);
      }
      await recordCreateSuccess(
        companyId: companyId,
        tempId: tempId,
        realId: realId,
      );
    });
  }

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required PurchaseOrderApi serverResponse,
  }) async {
    await db.purchaseOrderDao.upsert(
      _apiToCompanion(serverResponse, companyId),
    );
    await _refreshConvertedExpense(companyId, serverResponse);
  }

  /// When a PO was converted to an expense, its `expense_id` is set — force-refetch
  /// that new expense so it appears locally. A PO without an expense link is a
  /// no-op. Runs inside the drain; errors swallowed.
  Future<void> _refreshConvertedExpense(
    String companyId,
    PurchaseOrderApi serverResponse,
  ) async {
    final cb = onRelatedEntitiesAffected;
    if (cb == null) return;
    final expenseId = serverResponse.expenseId;
    if (expenseId.isEmpty) return;
    try {
      await cb(companyId, {
        EntityType.expense: {expenseId},
      });
    } catch (e) {
      _log.warning('purchase-order convert refresh failed: $e');
    }
  }

  /// Force-refetch purchase orders by id (e.g. as a `cloneToPurchaseOrder`
  /// target). See [refreshByIdsTemplate].
  @override
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    await refreshByIdsTemplate<PurchaseOrderApi, PurchaseOrdersCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.get(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) => db.purchaseOrderDao.upsertAllPreservingDirty(
        companyId: companyId,
        byId: byId,
      ),
    );
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.purchaseOrderDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.purchaseOrderDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    final row = await db.purchaseOrderDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return;
    await (db.update(db.purchaseOrders)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          PurchaseOrdersCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.purchaseOrderDao
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
    await (db.update(db.purchaseOrders)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          PurchaseOrdersCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  // ── Conversions ────────────────────────────────────────────────────

  PurchaseOrdersCompanion _apiToCompanion(
    PurchaseOrderApi a,
    String companyId,
  ) {
    return PurchaseOrdersCompanion.insert(
      id: a.id,
      companyId: companyId,
      number: Value(a.number),
      statusId: Value(a.statusId),
      clientId: Value(a.clientId),
      vendorId: Value(a.vendorId),
      projectId: Value(a.projectId),
      expenseId: Value(a.expenseId),
      date: Value(a.date),
      dueDate: Value(a.dueDate),
      amount: Value(_moneyString(a.amount)),
      balance: Value(_moneyString(a.balance)),
      poNumber: Value(a.poNumber),
      designId: Value(a.designId),
      assignedUserId: Value(a.assignedUserId),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      customValue1: Value(a.customValue1),
      customValue2: Value(a.customValue2),
      customValue3: Value(a.customValue3),
      customValue4: Value(a.customValue4),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      documents: a.documents == null
          ? const Value.absent()
          : Value(jsonEncode(a.documents!.map((d) => d.toJson()).toList())),
      payload: jsonEncode(a.toJson()),
    );
  }

  PurchaseOrdersCompanion _domainToCompanion(
    PurchaseOrder p,
    String companyId, {
    required bool isDirty,
  }) {
    return PurchaseOrdersCompanion.insert(
      id: p.id,
      companyId: companyId,
      number: Value(p.number),
      statusId: Value(p.statusId.wireId),
      clientId: Value(p.clientId),
      vendorId: Value(p.vendorId),
      projectId: Value(p.projectId),
      expenseId: Value(p.expenseId),
      date: Value(p.date?.toIso() ?? ''),
      dueDate: Value(p.dueDate?.toIso() ?? ''),
      amount: Value(p.amount.toString()),
      balance: Value(p.balance.toString()),
      poNumber: Value(p.poNumber),
      designId: Value(p.designId),
      assignedUserId: Value(p.assignedUserId),
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

  PurchaseOrder _fromRow(PurchaseOrderRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = PurchaseOrderApi.fromJson(json);
    return PurchaseOrder.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      documents: decodeDocumentsColumn(row.documents),
    );
  }
}

String _moneyString(Object raw) {
  if (raw is String) return raw;
  return raw.toString();
}
