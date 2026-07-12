import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart'
    show Value, BooleanExpressionOperators, Table, TableInfo, Variable;
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/db/dao/invoice_dao.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/schedule_item.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/repositories/settings_repository.dart';
import 'package:admin/data/services/invoices_api.dart';
import 'package:admin/domain/billing/invoice_lock.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';

final _log = Logger('InvoiceRepository');

/// Source of truth for Invoice data. The UI watches Drift via [watchPage]
/// and [watch]; the network only writes. Every mutation goes through the
/// outbox.
///
/// Page size is fixed at [pageSize]. Subsequent pages are fetched only on
/// demand — list screens call [ensurePageLoaded] near the scroll edge.
///
/// Document-bearing (same pattern as Expense / Client), with eleven
/// custom-action mutation kinds enqueued through the standard outbox.
class InvoiceRepository extends BaseEntityRepository<Invoice, InvoiceApi>
    implements DocumentBearingRepository {
  InvoiceRepository({
    required super.db,
    required this.api,
    required SettingsRepository settings,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.onRelatedEntitiesAffected,
    this.pageSize = 50,
  }) : _settings = settings,
       super(entityType: EntityType.invoice);

  final InvoicesApi api;
  final int pageSize;

  /// Fired after an invoice mutation applies, so entities the server changed as
  /// a side effect — the tasks/expenses it billed/un-billed (issue #7 sweep,
  /// Tier 1) — are force-refetched into Drift instead of lingering "unbilled"
  /// (a double-bill hazard). Wired by DI; null in tests that don't exercise it.
  final RelatedEntitiesRefresher? onRelatedEntitiesAffected;

  /// Resolves the `lock_invoices` settings cascade for the [save] backstop.
  /// [SettingsRepository] is a stateless wrapper over Drift, so a local
  /// instance is wired in `services_entity_wiring.dart`.
  final SettingsRepository _settings;

  @override
  String get entityTypeName => 'invoice';

  @override
  bool requiresPasswordFor(MutationKind kind) =>
      kind == MutationKind.delete ||
      kind == MutationKind.purge ||
      kind == MutationKind.documentDelete;

  /// Watch the first [loadedPages] pages worth of rows. [loadedPages] is
  /// 1-based — 1 means "show page 1," 2 means "show pages 1+2," etc.
  Stream<List<Invoice>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = InvoiceFieldIds.number,
    bool sortAscending = false,
    String? clientId,
    String? projectId,
    Map<int, Set<String>> customFilters = const {},
    Map<String, Set<String>> extraFilters = const {},
  }) {
    assert(
      loadedPages >= 1,
      'loadedPages is 1-based; pass 1 for the first page',
    );
    final dateRange = parseDateRangeFilter(extraFilters);
    final dueDateRange = parseDueDateRangeFilter(extraFilters);
    return db.invoiceDao
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
          statusIds: parseInvoiceStatusFilter(extraFilters),
          overdueAsOf: parseOverdueFilter(extraFilters)
              ? Date.today().toIso()
              : null,
          dateStart: dateRange.start,
          dateEnd: dateRange.end,
          dueDateStart: dueDateRange.start,
          dueDateEnd: dueDateRange.end,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<int> watchCount({required String companyId}) =>
      db.invoiceDao.watchCount(companyId: companyId);

  Stream<List<Invoice>> watchForClient({
    required String companyId,
    required String clientId,
  }) {
    if (clientId.isEmpty) {
      return Stream<List<Invoice>>.value(const <Invoice>[]);
    }
    return db.invoiceDao
        .watchForClient(companyId: companyId, clientId: clientId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  /// Invoices generated by a payment link (subscription). Used by the
  /// Payment Link detail screen's embedded "Invoices" card.
  Stream<List<Invoice>> watchForSubscription({
    required String companyId,
    required String subscriptionId,
  }) {
    if (subscriptionId.isEmpty) {
      return Stream<List<Invoice>>.value(const <Invoice>[]);
    }
    return db.invoiceDao
        .watchForSubscription(
          companyId: companyId,
          subscriptionId: subscriptionId,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<List<Invoice>> watchForProject({
    required String companyId,
    required String projectId,
  }) {
    if (projectId.isEmpty) {
      return Stream<List<Invoice>>.value(const <Invoice>[]);
    }
    return db.invoiceDao
        .watchForProject(companyId: companyId, projectId: projectId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<Invoice?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.invoiceDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

  /// Fetch one page from the server and upsert into Drift.
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
    // The shared `(companyId, entityType)` cursor is a page-1, UNSCOPED
    // delta probe only — same two gates as `ensurePageLoadedTemplate`:
    //  * a parent-scoped fetch (a client's Invoices tab) must neither read
    //    it (the tab would skip the client's older uncached rows) nor
    //    advance it (the scoped page's `data.last` is not a global
    //    high-water mark — advancing corrupts the standalone list's delta);
    //  * a page >= 2 fetch must not read it (the `updated_at >=` filter
    //    re-returns page 1's rows → near-empty page 2 → pagination, search
    //    and full resync silently cap at one page) nor advance it (deeper
    //    pages carry older rows under `id DESC` — last-write-wins would walk
    //    the watermark backwards).
    // An active text search is a filtered VIEW (same rationale as
    // `ensurePageLoadedTemplate`): skip the cursor read so the search looks
    // across full history, and skip the advance below so a search-scoped
    // `data.last` never corrupts the standalone list's delta sync.
    final isSearchScoped = search != null && search.isNotEmpty;
    final cursor =
        (ignoreCursor || hasClientScope || isSearchScoped || page > 1)
        ? null
        : await db.syncStateDao.read(
            companyId: companyId,
            entityType: entityTypeName,
          );
    final filters = <String, String>{
      ...stateQueryParams(states),
      // `?include=documents` — same rationale as Client/Expense. Without
      // it the list response omits documents and remote uploads never
      // propagate to the local cache.
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
    if (apiRows.isEmpty) {
      return false;
    }

    await db.invoiceDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: {for (final a in apiRows) a.id: _apiToCompanion(a, companyId)},
    );

    if (!hasClientScope &&
        !isSearchScoped &&
        page == 1 &&
        result.cursorUpdatedAt != null &&
        result.cursorId != null) {
      await advanceCursor(
        companyId: companyId,
        updatedAt: result.cursorUpdatedAt!,
        id: result.cursorId!,
        wasFullSync: ignoreCursor,
      );
    }
    return apiRows.length >= pageSize;
  }

  /// Backs `InvoiceNameLabel`'s cache-miss path: a quote/expense that
  /// references an invoice not on the prefetched first page. Deduped /
  /// negative-cached / tmp_-skipped by the shared template.
  Future<void> ensureLoaded({required String companyId, required String id}) =>
      ensureLoadedTemplate(
        companyId: companyId,
        id: id,
        // `getWithSchedule` (?show_schedule=true) so the detail screen's
        // invoice carries the read-only `schedule[]` projection. The
        // nullable+preserve guard in `_apiToCompanion` keeps list-page upserts
        // (which omit `schedule`) from wiping the stored column.
        fetch: (id) async => (await api.getWithSchedule(id)).data,
        idOf: (a) => a.id,
        toCompanion: (a) => _apiToCompanion(a, companyId),
        upsert: (byId) => db.invoiceDao.upsertAllPreservingDirty(
          companyId: companyId,
          byId: byId,
        ),
      );

  /// Force-refetches [ids] and upserts them dirty-preserving (the non-cache-gated
  /// sibling of [ensureLoaded]) to converge an invoice's balance/status/paid_to_date
  /// after a *payment* / *bank-transaction* / *quote-convert* / *merge* mutation
  /// changed it server-side (issue #7 + the stale-sibling sweep). **Returns the
  /// `clientId`s of the refreshed invoices** so the caller can also refresh those
  /// clients (the bank-transaction DTO carries no client id — this is how that path
  /// reaches the client). Runs inside the drain; see [refreshByIdsTemplate] for the
  /// load-bearing per-id error swallow.
  @override
  Future<Set<String>> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    final invoices = await refreshByIdsTemplate<InvoiceApi, InvoicesCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.getWithSchedule(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) => db.invoiceDao.upsertAllPreservingDirty(
        companyId: companyId,
        byId: byId,
      ),
    );
    return {
      for (final inv in invoices)
        if (inv.clientId.isNotEmpty) inv.clientId,
    };
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
        _log.warning(
          'refreshAll hit the $maxPages page safety cap for company '
          '$companyId — cursor will resume on the next sync trigger.',
        );
        break;
      }
    }
  }

  /// Create a new invoice offline. Returns the invoice with its tmp id so
  /// the UI can navigate to the detail screen immediately.
  Future<SaveResult<Invoice>> create({
    required String companyId,
    required Invoice draft,
    Map<String, String>? extraQuery,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.invoiceDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: tmpId,
        kind: MutationKind.create,
        payload: _withSaveQuery(_forMutation(stored.toApiJson()), extraQuery),
      );
    });
    return SaveResult(entity: stored, outboxRowId: rowId);
  }

  Future<SaveResult<Invoice>> save({
    required String companyId,
    required Invoice invoice,
    Map<String, String>? extraQuery,
  }) async {
    // Backstop for the `lock_invoices` setting. The UI hard-blocks at the
    // edit-entry point (invoice_actions.dart) before reaching here; this
    // guarantees no locked-invoice field edit can enter the outbox via any
    // future call site.
    //
    // Only plain field edits are gated: an `extraQuery`-bearing save is a
    // SAVE-PARAM status transition (mark_sent/paid/cancel/auto_bill), which
    // is intentionally allowed on a locked invoice (the VeriFactu nuance —
    // markPaid stays gated at the UI layer because the synthetic payment it
    // records is itself an edit). `create()` is never gated (a new draft is
    // never locked).
    if (extraQuery == null || extraQuery.isEmpty) {
      final reason = await resolveInvoiceLockReason(
        settings: _settings,
        companyId: companyId,
        invoice: invoice,
      );
      if (reason != InvoiceLockReason.none) {
        throw InvoiceLockedException(reason);
      }
    }
    final companion = _domainToCompanion(invoice, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.invoiceDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: invoice.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: invoice.id,
        kind: MutationKind.update,
        payload: _withSaveQuery(
          _forMutation(invoice.toApiJson(preserveTempId: true)),
          extraQuery,
        ),
      );
    });
    return SaveResult(entity: invoice, outboxRowId: rowId);
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
  ///
  /// `paid_to_date` is computed server-side from Payment records;
  /// `UpdateInvoiceRequest` 422s (`invoice_status_changed`) if the submitted
  /// value differs from the server's *current* value. Offline-first means our
  /// cached copy can be stale (a payment landed via the portal / auto-bill /
  /// another device while an edit sat in the outbox), so sending it would dead-
  /// letter the edit. The field stays in the *display* payload (`_domainToCompanion`)
  /// and the live-preview body — this only trims the outbound create/update body.
  /// Mutates and returns the passed map (`toApiJson` hands us a fresh one).
  Map<String, dynamic> _forMutation(Map<String, dynamic> payload) {
    payload.remove('paid_to_date');
    return payload;
  }

  // -------------------- custom actions (M2+ UI hooks) --------------------

  Future<void> markSent({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.markSent,
        payload: {'id': id},
      );

  /// Transmit via the configured e-invoice channel (PEPPOL/Verifactu).
  /// The dispatcher posts to `/api/v1/einvoice/peppol/send` then
  /// re-fetches the invoice so `backup`/`status` reflect the result.
  Future<void> sendEInvoice({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.sendEInvoice,
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
  /// `messageId`. The dispatcher's `customActions[reactivateEmail]` hits
  /// `POST /api/v1/reactivate_email/{messageId}`; no local update — the Sends
  /// tab refreshes on the next invoice sync.
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

  /// Payment schedule — number-of-payments flow. The dispatcher posts
  /// `[body]` to `/invoices/{id}/payment_schedule` then re-fetches the
  /// invoice (with `?show_schedule=true`) so `invoice.schedule[]` updates.
  Future<void> createPaymentSchedule({
    required String companyId,
    required String id,
    required Map<String, dynamic> body,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.paymentScheduleCreate,
    payload: {'id': id, 'body': body},
  );

  /// Payment schedule — custom-rows flow (`POST /task_schedulers`).
  Future<void> createCustomPaymentSchedule({
    required String companyId,
    required String id,
    required Map<String, dynamic> body,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.paymentScheduleCreateCustom,
    payload: {'id': id, 'body': body},
  );

  /// Payment schedule — remove (`DELETE /invoices/{id}/payment_schedule`).
  Future<void> deletePaymentSchedule({
    required String companyId,
    required String id,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.paymentScheduleDelete,
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

  /// Clone this invoice to a new entity of the chosen type. `targetType` is
  /// one of `invoice`, `quote`, `credit`, `recurring_invoice`,
  /// `purchase_order`. The dispatcher's customActions handler hits the
  /// matching server endpoint and applies the returned envelope.
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

  Future<void> autoBill({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.autoBill,
        payload: {'id': id},
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

  /// Append a user comment to this invoice's activity stream. Hits
  /// `/api/v1/activities/notes` via the outbox; the dispatcher's
  /// `customActions` map calls the `ActivitiesApi`.
  Future<void> addComment({
    required String companyId,
    required String invoiceId,
    required String text,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: invoiceId,
    kind: MutationKind.addComment,
    payload: {'entity_id': invoiceId, 'notes': text.trim()},
  );

  // -------------------- documents --------------------

  @override
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

  @override
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

  @override
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

  // -------------------- apply* response handlers --------------------

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.invoiceDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.invoiceDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required InvoiceApi serverResponse,
  }) async {
    await applyCreateResponseTemplate(
      companyId: companyId,
      tempId: tempId,
      realId: serverResponse.id,
      companion: _apiToCompanion(serverResponse, companyId),
      upsert: db.invoiceDao.upsert,
      deleteById: (id) =>
          db.invoiceDao.deleteById(companyId: companyId, id: id),
    );
    await _refreshInvoiceSideEffects(companyId, serverResponse);
  }

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required InvoiceApi serverResponse,
  }) async {
    await db.invoiceDao.upsert(_apiToCompanion(serverResponse, companyId));
    await _refreshInvoiceSideEffects(companyId, serverResponse);
  }

  /// Force-refetch the entities the server changed as a side effect of an
  /// invoice save (issue #7 sweep, Tier 1 + Tier 3):
  ///  * its **client** — a sent invoice's balance/paid_to_date rolls up into the
  ///    client aggregate;
  ///  * the **tasks/expenses** it billed — the server set their `invoice_id`, so
  ///    without a refetch they linger locally as "unbilled" (a double-bill
  ///    hazard). Ids come from the applied invoice's line items.
  /// Runs inside the drain; the callback swallows errors (see
  /// [onRelatedEntitiesAffected]).
  ///
  /// NOTE: covers newly-billed rows (the double-bill risk). Tasks the save
  /// *un-linked* (server cleared their `invoice_id`) aren't in the new line
  /// items and stay stale until the next resync — a smaller follow-up.
  Future<void> _refreshInvoiceSideEffects(
    String companyId,
    InvoiceApi serverResponse,
  ) async {
    final cb = onRelatedEntitiesAffected;
    if (cb == null) return;
    final taskIds = <String>{};
    final expenseIds = <String>{};
    for (final li in serverResponse.lineItems) {
      final taskId = li.taskId;
      if (taskId != null && taskId.isNotEmpty) taskIds.add(taskId);
      final expenseId = li.expenseId;
      if (expenseId != null && expenseId.isNotEmpty) expenseIds.add(expenseId);
    }
    // Also refresh tasks/expenses the save *un-linked*: rows whose local
    // `invoice_id` still points at this invoice but which are no longer in the
    // line items (the server cleared their `invoice_id`). Union so both the
    // newly-billed and newly-un-billed rows converge.
    final local = await _locallyBilledIds(companyId, serverResponse.id);
    taskIds.addAll(local.taskIds);
    expenseIds.addAll(local.expenseIds);
    final clientId = serverResponse.clientId;
    try {
      await cb(companyId, {
        if (clientId.isNotEmpty) EntityType.client: {clientId},
        if (taskIds.isNotEmpty) EntityType.task: taskIds,
        if (expenseIds.isNotEmpty) EntityType.expense: expenseIds,
      });
    } catch (e) {
      _log.warning('invoice side-effect refresh failed: $e');
    }
  }

  /// Local task/expense ids whose `invoice_id` COLUMN == [invoiceId] — the rows
  /// this invoice billed on a previous save. Read off the column (correct even
  /// though the domain reads it from the payload). Empty on create (no
  /// pre-existing links to a brand-new invoice).
  Future<({Set<String> taskIds, Set<String> expenseIds})> _locallyBilledIds(
    String companyId,
    String invoiceId,
  ) async {
    Future<Set<String>> idsIn(TableInfo<Table, dynamic> table) async {
      final rows = await db
          .customSelect(
            'SELECT id FROM ${table.actualTableName} '
            'WHERE company_id = ?1 AND invoice_id = ?2',
            variables: [
              Variable<String>(companyId),
              Variable<String>(invoiceId),
            ],
            readsFrom: {table},
          )
          .get();
      return rows
          .map((r) => r.read<String>('id'))
          .where((id) => id.isNotEmpty)
          .toSet();
    }

    return (
      taskIds: await idsIn(db.tasks),
      expenseIds: await idsIn(db.expenses),
    );
  }

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.invoiceDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.invoiceDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  /// Drop a document from the invoice's local `documents` JSON column.
  /// Mirror of `ExpenseRepository.applyDocumentDeleted`.
  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    final row = await db.invoiceDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return;
    await (db.update(db.invoices)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          InvoicesCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  /// Replace (or insert) one document in the invoice's local `documents`
  /// JSON column. Mirror of `ExpenseRepository.applyDocumentChanged`.
  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.invoiceDao
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
    await (db.update(db.invoices)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          InvoicesCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  // -------------------- conversions --------------------

  InvoicesCompanion _apiToCompanion(InvoiceApi a, String companyId) {
    return InvoicesCompanion.insert(
      id: a.id,
      companyId: companyId,
      number: Value(a.number),
      statusId: Value(a.statusId),
      clientId: Value(a.clientId),
      vendorId: Value(a.vendorId),
      projectId: Value(a.projectId),
      subscriptionId: Value(a.subscriptionId),
      date: Value(a.date),
      dueDate: Value(a.dueDate),
      partialDueDate: Value(a.partialDueDate),
      amount: Value(_moneyString(a.amount)),
      balance: Value(_moneyString(a.balance)),
      paidToDate: Value(_moneyString(a.paidToDate)),
      partial: Value(_moneyString(a.partial)),
      poNumber: Value(a.poNumber),
      designId: Value(a.designId),
      assignedUserId: Value(a.assignedUserId),
      isLocked: Value(a.isLocked),
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
      // `schedule` is present only on a `?show_schedule=true` fetch; null
      // (plain/list GET) ⇒ preserve the stored column rather than wiping
      // it (same guard rationale as `documents`).
      schedule: a.schedule == null
          ? const Value.absent()
          : Value(jsonEncode(a.schedule!.map((s) => s.toJson()).toList())),
      payload: jsonEncode(a.toJson()),
    );
  }

  InvoicesCompanion _domainToCompanion(
    Invoice i,
    String companyId, {
    required bool isDirty,
  }) {
    return InvoicesCompanion.insert(
      id: i.id,
      companyId: companyId,
      number: Value(i.number),
      statusId: Value(i.statusId.wireId),
      clientId: Value(i.clientId),
      vendorId: Value(i.vendorId),
      projectId: Value(i.projectId),
      subscriptionId: Value(i.subscriptionId),
      date: Value(i.date?.toIso() ?? ''),
      dueDate: Value(i.dueDate?.toIso() ?? ''),
      partialDueDate: Value(i.partialDueDate?.toIso() ?? ''),
      amount: Value(i.amount.toString()),
      balance: Value(i.balance.toString()),
      paidToDate: Value(i.paidToDate.toString()),
      partial: Value(i.partial.toString()),
      poNumber: Value(i.poNumber),
      designId: Value(i.designId),
      assignedUserId: Value(i.assignedUserId),
      isLocked: Value(i.isLocked),
      updatedAt: dateToEpochSeconds(i.updatedAt),
      createdAt: Value(dateToEpochSeconds(i.createdAt)),
      archivedAt: i.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(i.archivedAt!)),
      customValue1: Value(i.customValue1),
      customValue2: Value(i.customValue2),
      customValue3: Value(i.customValue3),
      customValue4: Value(i.customValue4),
      isDirty: Value(isDirty),
      isDeleted: Value(i.isDeleted),
      documents: Value(
        jsonEncode(i.documents.map((d) => d.toApi().toJson()).toList()),
      ),
      // Persist the read-only schedule projection from the domain (loaded
      // into `i` by `_fromRow`'s overlay) so a local invoice edit-save
      // round-trips it — `i.toApiJson` omits it from the outbound wire.
      schedule: Value(
        jsonEncode(i.schedule.map((s) => s.toApiJson()).toList()),
      ),
      payload: jsonEncode(i.toApiJson(preserveTempId: true)),
    );
  }

  Invoice _fromRow(InvoiceRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = InvoiceApi.fromJson(json);
    // is_dirty is local-only; documents live in their own column. Overlay
    // both onto the API-derived domain so the UI sees current state.
    return Invoice.fromApi(api).copyWith(
      isDirty: row.isDirty,
      documents: decodeDocumentsColumn(row.documents),
      // Same story as documents: `toApiJson` omits the read-only
      // `schedule[]` projection, so overlay it from its dedicated column.
      schedule: decodeScheduleColumn(row.schedule),
    );
  }
}

/// Map a `targetType` string (`invoice` / `quote` / `credit` /
/// `recurring_invoice` / `purchase_order`) to the corresponding
/// `MutationKind` clone variant. Unknown targets throw, since the dispatcher
/// uses the kind to pick its `customActions` handler.
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

/// The server sometimes returns money as a number, sometimes as a string;
/// normalize to a string for stable storage. Mirrors `_moneyString` in
/// `expense_repository.dart`.
String _moneyString(Object raw) {
  if (raw is String) return raw;
  return raw.toString();
}
