import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/db/dao/credit_dao.dart';
import 'package:admin/data/models/api/credit_api_model.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/tag_denormalization.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/credits_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('CreditRepository');

class CreditRepository extends BaseEntityRepository<Credit, CreditApi> {
  CreditRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.onRelatedEntitiesAffected,
    this.pageSize = 50,
  }) : super(entityType: EntityType.credit);

  final CreditsApi api;

  /// Fired after a credit mutation applies. Deleting an applied credit reverses
  /// the client's credit-balance/paid_to_date and can refund its payments
  /// server-side; force-refetch those siblings so they don't show stale until
  /// their own list is reopened (issue #7 sweep). Wired by DI; null in tests.
  final RelatedEntitiesRefresher? onRelatedEntitiesAffected;
  final int pageSize;

  @override
  String get entityTypeName => 'credit';

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.creditDao;

  /// Discard-ghost seam — `SyncRepository.discardOutboxRow` calls this to drop
  /// a never-synced offline create. Without it the base class throws
  /// `UnsupportedError` and the discard aborts before `deleteAllForEntity`,
  /// stranding both the ghost row and its outbox rows.
  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.creditDao.deleteById(companyId: companyId, id: id);

  @override
  bool requiresPasswordFor(MutationKind kind) =>
      kind == MutationKind.delete ||
      kind == MutationKind.purge ||
      kind == MutationKind.documentDelete;

  Stream<List<Credit>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = CreditFieldIds.number,
    bool sortAscending = false,
    String? clientId,
    Map<int, Set<String>> customFilters = const {},
    Map<String, Set<String>> extraFilters = const {},
  }) {
    assert(loadedPages >= 1);
    final dateRange = parseDateRangeFilter(extraFilters);
    // Single-date comparators live in the `op:value` slot, not the range
    // slot — mirror them locally or the chip only narrows the server fetch.
    final dateCmp = parseComparableDateFilter(extraFilters, 'date');
    final dueDateCmp = parseComparableDateFilter(extraFilters, 'due_date');
    final dueDateRange = parseDueDateRangeFilter(extraFilters);
    return db.creditDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
          clientId: clientId,
          clientIds: parseClientIdFilter(extraFilters),
          statuses: parseCreditStatusFilter(extraFilters),
          customValues1: customFilters[1] ?? const {},
          customValues2: customFilters[2] ?? const {},
          customValues3: customFilters[3] ?? const {},
          customValues4: customFilters[4] ?? const {},
          dateOp: dateCmp.op,
          dateValue: dateCmp.value,
          dueDateOp: dueDateCmp.op,
          dueDateValue: dueDateCmp.value,
          dateStart: dateRange.start,
          dateEnd: dateRange.end,
          dueDateStart: dueDateRange.start,
          dueDateEnd: dueDateRange.end,
        )
        .map((rows) {
          final items = rows.map(_fromRow);
          final tagIds = extraFilters['tag_ids'] ?? const <String>{};
          if (tagIds.isEmpty) return items.toList(growable: false);
          return items
              .where((c) => matchesTagIdFilter(c.tagIds, tagIds))
              .toList(growable: false);
        });
  }

  Stream<int> watchCount({required String companyId}) =>
      db.creditDao.watchCount(companyId: companyId);

  /// Live count behind this entity's sidebar counter badge. [modeId] is one of
  /// the entity's `SidebarBadgeMode` ids; [currentUserId] is read only by the
  /// `assigned_to_me` mode.
  Stream<int> watchBadgeCount({
    required String companyId,
    String modeId = kBadgeModeTotal,
    String currentUserId = '',
  }) => db.creditDao.watchBadgeCount(
    companyId: companyId,
    modeId: modeId,
    currentUserId: currentUserId,
  );

  Stream<List<Credit>> watchForClient({
    required String companyId,
    required String clientId,
  }) {
    if (clientId.isEmpty) {
      return Stream<List<Credit>>.value(const <Credit>[]);
    }
    return db.creditDao
        .watchForClient(companyId: companyId, clientId: clientId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<Credit?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.creditDao
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
    final resolvedExtra = resolveRelativeFilterTokens(extraFilters);
    // Hide rows of soft-deleted clients (React parity) unless the fetch is
    // already scoped to a specific client (then the detail tab needs them).
    final hasClientScope =
        resolvedExtra.containsKey('client_id') ||
        resolvedExtra.containsKey('client_ids');
    // The shared `(companyId, entityType)` cursor is a page-1, UNSCOPED,
    // UN-NARROWED delta probe only — same gate as `ensurePageLoadedTemplate`,
    // shared with the ADVANCE below so the two can't disagree. See
    // `BaseEntityRepository.isNarrowedFetch`.
    final isSearchScoped = search != null && search.isNotEmpty;
    final cursor = await readCursorIfEligible(
      companyId: companyId,
      ignoreCursor: ignoreCursor,
      page: page,
      hasParentScope: hasClientScope,
      isSearchScoped: isSearchScoped,
      states: states,
      extraFilters: resolvedExtra,
    );
    final filters = <String, String>{
      ...stateQueryParams(states),
      'include': 'documents',
      if (!hasClientScope) 'without_deleted_clients': 'true',
      for (final entry in resolvedExtra.entries)
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
    await db.creditDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: {for (final a in apiRows) a.id: _apiToCompanion(a, companyId)},
    );
    // Shared rule (see `shouldAdvanceCursor`): only an unscoped,
    // unfiltered page 1 may move the global watermark.
    if (shouldAdvanceCursor(
          page: page,
          hasParentScope: hasClientScope,
          isSearchScoped: isSearchScoped,
          states: states,
          extraFilters: resolvedExtra,
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

  Future<SaveResult<Credit>> create({
    required String companyId,
    required Credit draft,
    Map<String, String>? extraQuery,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.creditDao.upsert(companion);
      final carried = await dedupPendingMutations(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
        payload: _withSaveQuery(
          _forMutation(stored.toApiJson()),
          mergeSaveQuery(carried, extraQuery),
        ),
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  Future<SaveResult<Credit>> save({
    required String companyId,
    required Credit credit,
    Map<String, String>? extraQuery,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(credit.id);
    if (resolvedId != credit.id) credit = credit.copyWith(id: resolvedId);

    final companion = _domainToCompanion(credit, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.creditDao.upsert(companion);
      final carried = await dedupPendingMutations(
        companyId: companyId,
        entityId: credit.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: credit.id,
        kind: MutationKind.update,
        payload: _withSaveQuery(
          _forMutation(credit.toApiJson(preserveTempId: true)),
          mergeSaveQuery(carried, extraQuery),
        ),
      );
    });
    return SaveResult(entity: credit, outboxRowId: rowId);
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

  /// Strip server-derived fields the client must not assert on a mutation.
  /// `paid_to_date` is computed server-side from Payment records; we never
  /// own it. Unlike `UpdateInvoiceRequest`, the credit update request has no
  /// "must match" guard today, so this is defensive/consistency-only — but it
  /// keeps the outbound body clean and future-proofs against the server adding
  /// the same rule. Stays in the display payload (`_domainToCompanion`).
  Map<String, dynamic> _forMutation(Map<String, dynamic> payload) {
    payload.remove('paid_to_date');
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

  Future<void> markPaid({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.markPaid,
        payload: {'id': id},
      );

  /// Clears the Postmark bounce/spam suppression for an invitation's
  /// `messageId` via `customActions[reactivateEmail]`. No local update — the
  /// Sends tab refreshes on the next credit sync.
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

  Future<void> cloneTo({
    required String companyId,
    required String id,
    required String targetType,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: _cloneKindFor(targetType),
    payload: {'id': id, 'target': targetType},
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
    required String creditId,
    required String text,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: creditId,
    kind: MutationKind.addComment,
    payload: {'entity_id': creditId, 'notes': text.trim()},
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
    required CreditApi serverResponse,
  }) async {
    final realId = serverResponse.id;
    await db.transaction(() async {
      await db.creditDao.upsert(_apiToCompanion(serverResponse, companyId));
      if (realId != tempId) {
        await db.creditDao.deleteById(companyId: companyId, id: tempId);
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
    required CreditApi serverResponse,
  }) async {
    await db.creditDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  /// Force-refetch credits by id (e.g. after a payment consumed/reversed them).
  /// See [refreshByIdsTemplate].
  @override
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    await refreshByIdsTemplate<CreditApi, CreditsCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.get(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) => db.creditDao.upsertAllPreservingDirty(
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
    final existing = await db.creditDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    // Read the side-effect ids BEFORE the write: deleting an applied credit
    // reverses the client's credit-balance/paid_to_date and can flip its
    // reversal payments to refunded server-side. Converge those locally.
    final paymentRows = await db.paymentDao
        .watchForCredit(companyId: companyId, creditId: id)
        .first;
    final paymentIds = paymentRows
        .map((p) => p.id)
        .where((pid) => pid.isNotEmpty)
        .toSet();
    await db.creditDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
    final cb = onRelatedEntitiesAffected;
    if (cb == null) return;
    final clientId = existing.clientId;
    try {
      await cb(companyId, {
        if (clientId.isNotEmpty) EntityType.client: {clientId},
        if (paymentIds.isNotEmpty) EntityType.payment: paymentIds,
      });
    } catch (e) {
      _log.warning('credit delete side-effect refresh failed: $e');
    }
  }

  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    final row = await db.creditDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return;
    await (db.update(db.credits)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          CreditsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.creditDao
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
    await (db.update(db.credits)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          CreditsCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  // ── Conversions ────────────────────────────────────────────────────

  CreditsCompanion _apiToCompanion(CreditApi a, String companyId) {
    return CreditsCompanion.insert(
      id: a.id,
      companyId: companyId,
      number: Value(a.number),
      statusId: Value(a.statusId),
      clientId: Value(a.clientId),
      vendorId: Value(a.vendorId),
      projectId: Value(a.projectId),
      date: Value(a.date),
      dueDate: Value(a.dueDate),
      amount: Value(_moneyString(a.amount)),
      balance: Value(_moneyString(a.balance)),
      paidToDate: Value(_moneyString(a.paidToDate)),
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

  CreditsCompanion _domainToCompanion(
    Credit c,
    String companyId, {
    required bool isDirty,
  }) {
    return CreditsCompanion.insert(
      id: c.id,
      companyId: companyId,
      number: Value(c.number),
      statusId: Value(c.statusId.wireId),
      clientId: Value(c.clientId),
      vendorId: Value(c.vendorId),
      projectId: Value(c.projectId),
      date: Value(c.date?.toIso() ?? ''),
      dueDate: Value(c.dueDate?.toIso() ?? ''),
      amount: Value(c.amount.toString()),
      balance: Value(c.balance.toString()),
      paidToDate: Value(c.paidToDate.toString()),
      poNumber: Value(c.poNumber),
      designId: Value(c.designId),
      assignedUserId: Value(c.assignedUserId),
      updatedAt: dateToEpochSeconds(c.updatedAt),
      createdAt: Value(dateToEpochSeconds(c.createdAt)),
      archivedAt: c.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(c.archivedAt!)),
      customValue1: Value(c.customValue1),
      customValue2: Value(c.customValue2),
      customValue3: Value(c.customValue3),
      customValue4: Value(c.customValue4),
      isDirty: Value(isDirty),
      isDeleted: Value(c.isDeleted),
      documents: Value(
        jsonEncode(c.documents.map((d) => d.toApi().toJson()).toList()),
      ),
      payload: jsonEncode(c.toApiJson(preserveTempId: true)),
    );
  }

  Credit _fromRow(CreditRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = CreditApi.fromJson(json);
    return Credit.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      documents: decodeDocumentsColumn(row.documents),
    );
  }
}

MutationKind _cloneKindFor(String targetType) {
  switch (targetType) {
    case 'invoice':
      return MutationKind.cloneToInvoice;
    case 'quote':
      return MutationKind.cloneToQuote;
    case 'credit':
      return MutationKind.cloneToCredit;
    case 'recurring_invoice':
      return MutationKind.cloneToRecurring;
    case 'purchase_order':
      return MutationKind.cloneToPurchaseOrder;
    default:
      throw ArgumentError(
        'Unknown clone target "$targetType" — must be one of '
        'invoice|quote|credit|recurring_invoice|purchase_order',
      );
  }
}

String _moneyString(Object raw) {
  if (raw is String) return raw;
  return raw.toString();
}
