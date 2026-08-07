import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/db/dao/recurring_invoice_dao.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/recurring_invoice_api_model.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/tag_denormalization.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/recurring_invoices_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('RecurringInvoiceRepository');

class RecurringInvoiceRepository
    extends BaseEntityRepository<RecurringInvoice, RecurringInvoiceApi> {
  RecurringInvoiceRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(entityType: EntityType.recurringInvoice);

  final RecurringInvoicesApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'recurring_invoice';

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.recurringInvoiceDao;

  /// Discard-ghost seam — `SyncRepository.discardOutboxRow` calls this to drop
  /// a never-synced offline create. Without it the base class throws
  /// `UnsupportedError` and the discard aborts before `deleteAllForEntity`,
  /// stranding both the ghost row and its outbox rows.
  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.recurringInvoiceDao.deleteById(companyId: companyId, id: id);

  @override
  bool requiresPasswordFor(MutationKind kind) =>
      kind == MutationKind.delete ||
      kind == MutationKind.purge ||
      kind == MutationKind.documentDelete;

  Stream<List<RecurringInvoice>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = RecurringInvoiceFieldIds.number,
    bool sortAscending = false,
    String? clientId,
    Map<int, Set<String>> customFilters = const {},
    Map<String, Set<String>> extraFilters = const {},
  }) {
    assert(loadedPages >= 1);
    return db.recurringInvoiceDao
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
          statusIds: parseRecurringInvoiceStatusFilter(extraFilters),
          customValues1: customFilters[1] ?? const {},
          customValues2: customFilters[2] ?? const {},
          customValues3: customFilters[3] ?? const {},
          customValues4: customFilters[4] ?? const {},
        )
        .map((rows) {
          final items = rows.map(_fromRow);
          final tagIds = extraFilters['tag_ids'] ?? const <String>{};
          if (tagIds.isEmpty) return items.toList(growable: false);
          return items
              .where((r) => matchesTagIdFilter(r.tagIds, tagIds))
              .toList(growable: false);
        });
  }

  Stream<int> watchCount({required String companyId}) =>
      db.recurringInvoiceDao.watchCount(companyId: companyId);

  /// Live count behind this entity's sidebar counter badge. [modeId] is one of
  /// the entity's `SidebarBadgeMode` ids; [currentUserId] is read only by the
  /// `assigned_to_me` mode.
  Stream<int> watchBadgeCount({
    required String companyId,
    String modeId = kBadgeModeTotal,
    String currentUserId = '',
  }) => db.recurringInvoiceDao.watchBadgeCount(
    companyId: companyId,
    modeId: modeId,
    currentUserId: currentUserId,
  );

  Stream<List<RecurringInvoice>> watchForClient({
    required String companyId,
    required String clientId,
  }) {
    if (clientId.isEmpty) {
      return Stream<List<RecurringInvoice>>.value(const <RecurringInvoice>[]);
    }
    return db.recurringInvoiceDao
        .watchForClient(companyId: companyId, clientId: clientId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  /// Recurring invoices belonging to a payment link (subscription). Used by
  /// the Payment Link detail screen's embedded "Recurring Invoices" card.
  Stream<List<RecurringInvoice>> watchForSubscription({
    required String companyId,
    required String subscriptionId,
  }) {
    if (subscriptionId.isEmpty) {
      return Stream<List<RecurringInvoice>>.value(const <RecurringInvoice>[]);
    }
    return db.recurringInvoiceDao
        .watchForSubscription(
          companyId: companyId,
          subscriptionId: subscriptionId,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<RecurringInvoice?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.recurringInvoiceDao
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
        (ignoreCursor || hasClientScope || isSearchScoped || page > 1)
        ? null
        : await db.syncStateDao.read(
            companyId: companyId,
            entityType: entityTypeName,
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
    await db.recurringInvoiceDao.upsertAllPreservingDirty(
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

  Future<SaveResult<RecurringInvoice>> create({
    required String companyId,
    required RecurringInvoice draft,
    Map<String, String>? extraQuery,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.recurringInvoiceDao.upsert(companion);
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

  Future<SaveResult<RecurringInvoice>> save({
    required String companyId,
    required RecurringInvoice recurringInvoice,
    Map<String, String>? extraQuery,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(recurringInvoice.id);
    if (resolvedId != recurringInvoice.id) {
      recurringInvoice = recurringInvoice.copyWith(id: resolvedId);
    }

    final companion = _domainToCompanion(
      recurringInvoice,
      companyId,
      isDirty: true,
    );
    var rowId = 0;
    await db.transaction(() async {
      await db.recurringInvoiceDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: recurringInvoice.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: recurringInvoice.id,
        kind: MutationKind.update,
        payload: _withSaveQuery(
          recurringInvoice.toApiJson(preserveTempId: true),
          extraQuery,
        ),
      );
    });
    return SaveResult(entity: recurringInvoice, outboxRowId: rowId);
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

  Future<void> start({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.start,
        payload: {'id': id},
      );

  Future<void> stop({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.stop,
        payload: {'id': id},
      );

  /// Clears the Postmark bounce/spam suppression for an invitation's
  /// `messageId` via `customActions[reactivateEmail]`. No local update — the
  /// Sends tab refreshes on the next recurring-invoice sync.
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

  /// Sends the next occurrence immediately. React-aligned: a normal update
  /// carrying `?send_now=true` (`PUT /recurring_invoices/{id}?send_now=true`
  /// with the full entity), NOT a bulk action — the server's recurring `/bulk`
  /// has no `send_now`. Reuses the SAVE-PARAM update plumbing; works per-id for
  /// the bulk action too.
  Future<void> sendNow({required String companyId, required String id}) async {
    final current = await watchByRealId(companyId: companyId, id: id).first;
    if (current == null) return;
    await save(
      companyId: companyId,
      recurringInvoice: current,
      extraQuery: const {'send_now': 'true'},
    );
  }

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

  Future<void> updatePrices({required String companyId, required String id}) =>
      enqueueMutation(
        companyId: companyId,
        entityId: id,
        kind: MutationKind.updatePrices,
        payload: {'id': id},
      );

  Future<void> increasePrices({
    required String companyId,
    required String id,
    required String percentageIncrease,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: id,
    kind: MutationKind.increasePrices,
    payload: {'id': id, 'percentage_increase': percentageIncrease},
  );

  Future<void> addComment({
    required String companyId,
    required String recurringInvoiceId,
    required String text,
  }) => enqueueMutation(
    companyId: companyId,
    entityId: recurringInvoiceId,
    kind: MutationKind.addComment,
    payload: {'entity_id': recurringInvoiceId, 'notes': text.trim()},
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
    required RecurringInvoiceApi serverResponse,
  }) async {
    final realId = serverResponse.id;
    await db.transaction(() async {
      await db.recurringInvoiceDao.upsert(
        _apiToCompanion(serverResponse, companyId),
      );
      if (realId != tempId) {
        await db.recurringInvoiceDao.deleteById(
          companyId: companyId,
          id: tempId,
        );
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
    required RecurringInvoiceApi serverResponse,
  }) async {
    await db.recurringInvoiceDao.upsert(
      _apiToCompanion(serverResponse, companyId),
    );
  }

  /// Force-refetch recurring invoices by id (e.g. as a `cloneToRecurring`
  /// target). See [refreshByIdsTemplate].
  /// Lazily hydrate a single recurring_invoice into Drift on a cache miss — backs detail
  /// screens reached from the dashboard (whose rows live only in the dashboard
  /// cache, not the entity table). Deduped / negative-cached in the template.
  Future<void> ensureLoaded({required String companyId, required String id}) =>
      ensureLoadedTemplate(
        companyId: companyId,
        id: id,
        fetch: (id) async => (await api.get(id)).data,
        idOf: (a) => a.id,
        toCompanion: (a) => _apiToCompanion(a, companyId),
        upsert: (byId) => db.recurringInvoiceDao.upsertAllPreservingDirty(
          companyId: companyId,
          byId: byId,
        ),
      );

  @override
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    await refreshByIdsTemplate<RecurringInvoiceApi, RecurringInvoicesCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.get(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) => db.recurringInvoiceDao.upsertAllPreservingDirty(
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
    final existing = await db.recurringInvoiceDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.recurringInvoiceDao.upsert(
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
    final row = await db.recurringInvoiceDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return;
    await (db.update(db.recurringInvoices)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          RecurringInvoicesCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.recurringInvoiceDao
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
    await (db.update(db.recurringInvoices)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          RecurringInvoicesCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  // ── Conversions ────────────────────────────────────────────────────

  RecurringInvoicesCompanion _apiToCompanion(
    RecurringInvoiceApi a,
    String companyId,
  ) {
    return RecurringInvoicesCompanion.insert(
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
      partial: Value(_moneyString(a.partial)),
      poNumber: Value(a.poNumber),
      designId: Value(a.designId),
      assignedUserId: Value(a.assignedUserId),
      frequencyId: Value(a.frequencyId),
      nextSendDate: Value(a.nextSendDate),
      remainingCycles: Value(a.remainingCycles),
      autoBill: Value(a.autoBill),
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

  RecurringInvoicesCompanion _domainToCompanion(
    RecurringInvoice r,
    String companyId, {
    required bool isDirty,
  }) {
    return RecurringInvoicesCompanion.insert(
      id: r.id,
      companyId: companyId,
      number: Value(r.number),
      statusId: Value(r.statusId.wireId),
      clientId: Value(r.clientId),
      vendorId: Value(r.vendorId),
      projectId: Value(r.projectId),
      subscriptionId: Value(r.subscriptionId),
      date: Value(r.date?.toIso() ?? ''),
      dueDate: Value(r.dueDate?.toIso() ?? ''),
      partialDueDate: Value(r.partialDueDate?.toIso() ?? ''),
      amount: Value(r.amount.toString()),
      balance: Value(r.balance.toString()),
      partial: Value(r.partial.toString()),
      poNumber: Value(r.poNumber),
      designId: Value(r.designId),
      assignedUserId: Value(r.assignedUserId),
      frequencyId: Value(r.frequencyId),
      nextSendDate: Value(r.nextSendDate?.toIso() ?? ''),
      remainingCycles: Value(r.remainingCycles),
      autoBill: Value(r.autoBill),
      updatedAt: dateToEpochSeconds(r.updatedAt),
      createdAt: Value(dateToEpochSeconds(r.createdAt)),
      archivedAt: r.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(r.archivedAt!)),
      customValue1: Value(r.customValue1),
      customValue2: Value(r.customValue2),
      customValue3: Value(r.customValue3),
      customValue4: Value(r.customValue4),
      isDirty: Value(isDirty),
      isDeleted: Value(r.isDeleted),
      documents: Value(
        jsonEncode(r.documents.map((d) => d.toApi().toJson()).toList()),
      ),
      payload: jsonEncode(r.toApiJson(preserveTempId: true)),
    );
  }

  RecurringInvoice _fromRow(RecurringInvoiceRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = RecurringInvoiceApi.fromJson(json);
    return RecurringInvoice.fromApi(api).copyWith(
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
