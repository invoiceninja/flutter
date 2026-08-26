import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/db/dao/quote_dao.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/quote_api_model.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/tag_denormalization.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/quotes_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('QuoteRepository');

/// Source of truth for Quote data. Mirrors `InvoiceRepository` — same
/// outbox-mediated write pipeline + document handlers + page-by-page
/// fetch. Diff: quote-specific custom actions (`approve`,
/// `convertToInvoice`, `convertToProject`) and no `markPaid` / `autoBill`.
class QuoteRepository extends BaseEntityRepository<Quote, QuoteApi> {
  QuoteRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.onRelatedEntitiesAffected,
    this.pageSize = 50,
  }) : super(entityType: EntityType.quote);

  final QuotesApi api;

  /// Fired after a quote mutation applies. When the quote was **converted**, the
  /// server created a new invoice (and set the quote's `invoice_id`); force-refetch
  /// that invoice so it appears locally without a manual resync (issue #7 sweep,
  /// Tier 2). Wired by DI; null in tests that don't exercise it.
  final RelatedEntitiesRefresher? onRelatedEntitiesAffected;
  final int pageSize;

  @override
  String get entityTypeName => 'quote';

  @override
  bool requiresPasswordFor(MutationKind kind) =>
      kind == MutationKind.delete ||
      kind == MutationKind.purge ||
      kind == MutationKind.documentDelete;

  Stream<List<Quote>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = QuoteFieldIds.number,
    bool sortAscending = false,
    String? clientId,
    String? projectId,
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
    final statuses = parseQuoteStatusFilter(extraFilters);
    return db.quoteDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
          clientId: clientId,
          projectId: projectId,
          clientIds: parseClientIdFilter(extraFilters),
          customValues1: customFilters[1] ?? const {},
          customValues2: customFilters[2] ?? const {},
          customValues3: customFilters[3] ?? const {},
          customValues4: customFilters[4] ?? const {},
          statuses: statuses,
          statusAsOf: statuses.isEmpty ? null : Date.today().toIso(),
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
              .where((q) => matchesTagIdFilter(q.tagIds, tagIds))
              .toList(growable: false);
        });
  }

  Stream<int> watchCount({required String companyId}) =>
      db.quoteDao.watchCount(companyId: companyId);

  /// Live count behind this entity's sidebar counter badge. [modeId] is one of
  /// the entity's `SidebarBadgeMode` ids; [currentUserId] is read only by the
  /// `assigned_to_me` mode.
  Stream<int> watchBadgeCount({
    required String companyId,
    String modeId = kBadgeModeTotal,
    String currentUserId = '',
  }) => db.quoteDao.watchBadgeCount(
    companyId: companyId,
    modeId: modeId,
    currentUserId: currentUserId,
  );

  Stream<List<Quote>> watchForClient({
    required String companyId,
    required String clientId,
  }) {
    if (clientId.isEmpty) {
      return Stream<List<Quote>>.value(const <Quote>[]);
    }
    return db.quoteDao
        .watchForClient(companyId: companyId, clientId: clientId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<List<Quote>> watchForProject({
    required String companyId,
    required String projectId,
  }) {
    if (projectId.isEmpty) {
      return Stream<List<Quote>>.value(const <Quote>[]);
    }
    return db.quoteDao
        .watchForProject(companyId: companyId, projectId: projectId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<Quote?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.quoteDao
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
    await db.quoteDao.upsertAllPreservingDirty(
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

  Future<SaveResult<Quote>> create({
    required String companyId,
    required Quote draft,
    Map<String, String>? extraQuery,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.quoteDao.upsert(companion);
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
          stored.toApiJson(),
          mergeSaveQuery(carried, extraQuery),
        ),
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  Future<SaveResult<Quote>> save({
    required String companyId,
    required Quote quote,
    Map<String, String>? extraQuery,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(quote.id);
    if (resolvedId != quote.id) quote = quote.copyWith(id: resolvedId);

    final companion = _domainToCompanion(quote, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.quoteDao.upsert(companion);
      final carried = await dedupPendingMutations(
        companyId: companyId,
        entityId: quote.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: quote.id,
        kind: MutationKind.update,
        payload: _withSaveQuery(
          quote.toApiJson(preserveTempId: true),
          mergeSaveQuery(carried, extraQuery),
        ),
      );
    });
    return SaveResult(entity: quote, outboxRowId: rowId);
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

  // ── Custom actions ─────────────────────────────────────────────────

  Future<void> markSent({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.markSent,
        payload: {'id': id},
      );

  /// Clears the Postmark bounce/spam suppression for an invitation's
  /// `messageId` via `customActions[reactivateEmail]`. No local update — the
  /// Sends tab refreshes on the next quote sync.
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

  Future<void> approve({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.approve,
        payload: {'id': id},
      );

  Future<void> convertToInvoice({
    required String companyId,
    required String id,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.convertToInvoice,
    payload: {'id': id},
  );

  Future<void> convertToProject({
    required String companyId,
    required String id,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.convertToProject,
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

  Future<void> cancel({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.cancelEntity,
        payload: {'id': id},
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
    required String quoteId,
    required String text,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: quoteId,
    kind: MutationKind.addComment,
    payload: {'entity_id': quoteId, 'notes': text.trim()},
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
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.quoteDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.quoteDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required QuoteApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.quoteDao.upsert,
    deleteById: (id) => db.quoteDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required QuoteApi serverResponse,
  }) async {
    await db.quoteDao.upsert(_apiToCompanion(serverResponse, companyId));
    await _refreshConverted(companyId, serverResponse);
  }

  /// When a quote was converted, the server sets its `invoice_id`
  /// (convertToInvoice) or `project_id` (convertToProject) — force-refetch that
  /// new invoice/project so it appears locally. A normal quote leaves both
  /// empty, so this is a no-op except right after a convert (or, harmlessly, for
  /// a quote already associated with a project). Runs inside the drain; errors
  /// swallowed.
  Future<void> _refreshConverted(
    String companyId,
    QuoteApi serverResponse,
  ) async {
    final cb = onRelatedEntitiesAffected;
    if (cb == null) return;
    final invoiceId = serverResponse.invoiceId;
    final projectId = serverResponse.projectId;
    if (invoiceId.isEmpty && projectId.isEmpty) return;
    try {
      await cb(companyId, {
        if (invoiceId.isNotEmpty) EntityType.invoice: {invoiceId},
        if (projectId.isNotEmpty) EntityType.project: {projectId},
      });
    } catch (e) {
      _log.warning('quote convert refresh failed: $e');
    }
  }

  /// Force-refetch quotes by id (e.g. as a `cloneToQuote` target).
  /// See [refreshByIdsTemplate].
  /// Lazily hydrate a single quote into Drift on a cache miss — backs detail
  /// screens reached from the dashboard (whose rows live only in the dashboard
  /// cache, not the entity table). Deduped / negative-cached in the template.
  Future<void> ensureLoaded({required String companyId, required String id}) =>
      ensureLoadedTemplate(
        companyId: companyId,
        id: id,
        fetch: (id) async => (await api.get(id)).data,
        idOf: (a) => a.id,
        toCompanion: (a) => _apiToCompanion(a, companyId),
        upsert: (byId) => db.quoteDao.upsertAllPreservingDirty(
          companyId: companyId,
          byId: byId,
        ),
      );

  @override
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    await refreshByIdsTemplate<QuoteApi, QuotesCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.get(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) => db.quoteDao.upsertAllPreservingDirty(
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
    final existing = await db.quoteDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.quoteDao.upsert(
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
    final row = await db.quoteDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return;
    await (db.update(db.quotes)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          QuotesCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.quoteDao
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
    await (db.update(db.quotes)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          QuotesCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  // ── Conversions ────────────────────────────────────────────────────

  QuotesCompanion _apiToCompanion(QuoteApi a, String companyId) {
    return QuotesCompanion.insert(
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
      poNumber: Value(a.poNumber),
      designId: Value(a.designId),
      assignedUserId: Value(a.assignedUserId),
      invoiceId: Value(a.invoiceId),
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

  QuotesCompanion _domainToCompanion(
    Quote q,
    String companyId, {
    required bool isDirty,
  }) {
    return QuotesCompanion.insert(
      id: q.id,
      companyId: companyId,
      number: Value(q.number),
      statusId: Value(q.statusId.wireId),
      clientId: Value(q.clientId),
      vendorId: Value(q.vendorId),
      projectId: Value(q.projectId),
      date: Value(q.date?.toIso() ?? ''),
      dueDate: Value(q.dueDate?.toIso() ?? ''),
      amount: Value(q.amount.toString()),
      balance: Value(q.balance.toString()),
      poNumber: Value(q.poNumber),
      designId: Value(q.designId),
      assignedUserId: Value(q.assignedUserId),
      invoiceId: Value(q.invoiceId),
      updatedAt: dateToEpochSeconds(q.updatedAt),
      createdAt: Value(dateToEpochSeconds(q.createdAt)),
      archivedAt: q.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(q.archivedAt!)),
      customValue1: Value(q.customValue1),
      customValue2: Value(q.customValue2),
      customValue3: Value(q.customValue3),
      customValue4: Value(q.customValue4),
      isDirty: Value(isDirty),
      isDeleted: Value(q.isDeleted),
      documents: Value(
        jsonEncode(q.documents.map((d) => d.toApi().toJson()).toList()),
      ),
      payload: jsonEncode(q.toApiJson(preserveTempId: true)),
    );
  }

  Quote _fromRow(QuoteRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = QuoteApi.fromJson(json);
    return Quote.fromApi(api).copyWith(
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
