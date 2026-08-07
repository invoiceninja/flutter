import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/recurring_expense_dao.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/recurring_expense_api_model.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/services/recurring_expenses_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('RecurringExpenseRepository');

/// Source of truth for RecurringExpense data. Mirrors `ExpenseRepository`
/// (document-bearing, password-gated delete / purge / documentDelete) plus:
///   * `start(...)` / `stop(...)` enqueue `MutationKind.start` /
///     `MutationKind.stop` rows. The sync dispatcher's `customActions` map
///     for `EntityType.recurringExpense` routes them through
///     `RecurringExpensesApi.start` / `.stop`.
///   * `recurringDates` from the API response is **not persisted** — only
///     denormalized columns + `payload` JSON land in Drift. The detail
///     screen consumes the in-flight `get` response directly.
class RecurringExpenseRepository
    extends BaseEntityRepository<RecurringExpense, RecurringExpenseApi>
    implements DocumentBearingRepository {
  RecurringExpenseRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.recurringExpense,
         requiresPasswordFor: const {
           MutationKind.delete,
           MutationKind.purge,
           MutationKind.documentDelete,
         },
       );

  final RecurringExpensesApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'recurring_expense';

  /// Watch the first [loadedPages] pages worth of rows. `recurringStatus`
  /// is one of the 5 [kRecurringExpenseStatus*] values, or `null` for
  /// "all".
  Stream<List<RecurringExpense>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    String? recurringStatus,
    Set<EntityState> states = const {EntityState.active},
    String sortField = RecurringExpenseFieldIds.nextSendDate,
    bool sortAscending = false,
    String? vendorId,
    Map<int, Set<String>> customFilters = const {},
  }) {
    assert(
      loadedPages >= 1,
      'loadedPages is 1-based; pass 1 for the first page',
    );
    return db.recurringExpenseDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          recurringStatus: recurringStatus,
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
      db.recurringExpenseDao.watchCount(companyId: companyId);

  /// Live count behind this entity's sidebar counter badge. [modeId] is one of
  /// the entity's `SidebarBadgeMode` ids; [currentUserId] is read only by the
  /// `assigned_to_me` mode.
  Stream<int> watchBadgeCount({
    required String companyId,
    String modeId = kBadgeModeTotal,
    String currentUserId = '',
  }) => db.recurringExpenseDao.watchBadgeCount(
    companyId: companyId,
    modeId: modeId,
    currentUserId: currentUserId,
  );

  Stream<int> watchCountForStatus({
    required String companyId,
    String? recurringStatus,
  }) => db.recurringExpenseDao.watchCountForStatus(
    companyId: companyId,
    recurringStatus: recurringStatus,
  );

  Stream<List<RecurringExpense>> watchForVendor({
    required String companyId,
    required String vendorId,
  }) {
    if (vendorId.isEmpty) {
      return Stream<List<RecurringExpense>>.value(const <RecurringExpense>[]);
    }
    return db.recurringExpenseDao
        .watchForVendor(companyId: companyId, vendorId: vendorId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<List<RecurringExpense>> watchForClient({
    required String companyId,
    required String clientId,
  }) {
    if (clientId.isEmpty) {
      return Stream<List<RecurringExpense>>.value(const <RecurringExpense>[]);
    }
    return db.recurringExpenseDao
        .watchForClient(companyId: companyId, clientId: clientId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<List<RecurringExpense>> watchForProject({
    required String companyId,
    required String projectId,
  }) {
    if (projectId.isEmpty) {
      return Stream<List<RecurringExpense>>.value(const <RecurringExpense>[]);
    }
    return db.recurringExpenseDao
        .watchForProject(companyId: companyId, projectId: projectId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<List<RecurringExpense>> watchForCategory({
    required String companyId,
    required String categoryId,
  }) {
    if (categoryId.isEmpty) {
      return Stream<List<RecurringExpense>>.value(const <RecurringExpense>[]);
    }
    return db.recurringExpenseDao
        .watchForCategory(companyId: companyId, categoryId: categoryId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<RecurringExpense?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.recurringExpenseDao
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
  }) => ensurePageLoadedTemplate(
    companyId: companyId,
    page: page,
    pageSize: pageSize,
    search: search,
    states: states,
    extraFilters: extraFilters,
    ignoreCursor: ignoreCursor,
    // `?include=documents` so remote uploads propagate to the local cache.
    // `?show_dates=true` is **not** appended on list — the schedule
    // preview is only useful on detail.
    staticFilters: const {'include': 'documents'},
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.recurringExpenseDao.upsertAllPreservingDirty(
      companyId: companyId,
      byId: byId,
    ),
  );

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

  /// Create a new recurring expense offline. Returns the entity with its
  /// tmp id so the UI can navigate to the detail screen immediately.
  Future<SaveResult<RecurringExpense>> create({
    required String companyId,
    required RecurringExpense draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.recurringExpenseDao.upsert(companion);
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

  Future<SaveResult<RecurringExpense>> save({
    required String companyId,
    required RecurringExpense recurringExpense,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(recurringExpense.id);
    if (resolvedId != recurringExpense.id) {
      recurringExpense = recurringExpense.copyWith(id: resolvedId);
    }

    final companion = _domainToCompanion(
      recurringExpense,
      companyId,
      isDirty: true,
    );
    var rowId = 0;
    await db.transaction(() async {
      await db.recurringExpenseDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: recurringExpense.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: recurringExpense.id,
        kind: MutationKind.update,
        payload: recurringExpense.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: recurringExpense, outboxRowId: rowId);
  }

  /// `MutationKind.start` — Draft / Paused → Active. Captures the full entity
  /// as the outbox payload so the start PUT sends the same body the references
  /// do (see [_startStopPayload]).
  Future<void> start({required String companyId, required String id}) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: id,
      kind: MutationKind.start,
      payload: await _startStopPayload(companyId, id),
    );
  }

  /// `MutationKind.stop` — Active / Pending → Paused.
  Future<void> stop({required String companyId, required String id}) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: id,
      kind: MutationKind.stop,
      payload: await _startStopPayload(companyId, id),
    );
  }

  /// Body for a start/stop PUT: the full entity (`toApiJson`), matching
  /// admin-portal + React. Falls back to a bare `{'id': id}` if the row isn't
  /// in the cache — start/stop act on synced records, so that's defensive only.
  ///
  /// `preserveTempId: true` keeps the `id` key even for an unsynced (`tmp_`)
  /// row (e.g. a Draft created offline then bulk-started) so the outbox drain's
  /// `rewriteTempIdInPayloads` can rewrite it tmp→real before dispatch — same
  /// reason [save] preserves it. Omitting it would leave the handler's
  /// `payload['id']` null and fail the row on every drain.
  Future<Map<String, dynamic>> _startStopPayload(
    String companyId,
    String id,
  ) async {
    final row = await db.recurringExpenseDao
        .watchById(companyId: companyId, id: id)
        .first;
    return row == null
        ? {'id': id}
        : _fromRow(row).toApiJson(preserveTempId: true);
  }

  Future<void> addComment({
    required String companyId,
    required String recurringExpenseId,
    required String text,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: recurringExpenseId,
      kind: MutationKind.addComment,
      payload: {'entity_id': recurringExpenseId, 'notes': text.trim()},
    );
  }

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

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.recurringExpenseDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.recurringExpenseDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required RecurringExpenseApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.recurringExpenseDao.upsert,
    deleteById: (id) =>
        db.recurringExpenseDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required RecurringExpenseApi serverResponse,
  }) async {
    await db.recurringExpenseDao.upsert(
      _apiToCompanion(serverResponse, companyId),
    );
  }

  /// Force-refetch recurring expenses by id (e.g. after a client/vendor merge
  /// reassigned them). See [refreshByIdsTemplate].
  @override
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    await refreshByIdsTemplate<RecurringExpenseApi, RecurringExpensesCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.get(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) => db.recurringExpenseDao.upsertAllPreservingDirty(
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
    final existing = await db.recurringExpenseDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.recurringExpenseDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  /// Drop a document from the local `documents` JSON column. Mirror of
  /// `ExpenseRepository.applyDocumentDeleted`.
  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    final row = await db.recurringExpenseDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return;
    await (db.update(db.recurringExpenses)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          RecurringExpensesCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  /// Replace (or insert) one document in the local `documents` JSON column.
  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.recurringExpenseDao
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
    await (db.update(db.recurringExpenses)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          RecurringExpensesCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  // -------------------- conversions --------------------

  RecurringExpensesCompanion _apiToCompanion(
    RecurringExpenseApi a,
    String companyId,
  ) {
    return RecurringExpensesCompanion.insert(
      id: a.id,
      companyId: companyId,
      number: Value(a.number),
      date: Value(a.date),
      paymentDate: Value(a.paymentDate),
      amount: Value(_moneyString(a.amount)),
      vendorId: Value(a.vendorId),
      clientId: Value(a.clientId),
      projectId: Value(a.projectId),
      categoryId: Value(a.categoryId),
      invoiceId: Value(a.invoiceId),
      currencyId: Value(a.currencyId),
      shouldBeInvoiced: Value(a.shouldBeInvoiced),
      frequencyId: Value(a.frequencyId),
      remainingCycles: Value(a.remainingCycles),
      nextSendDate: Value(a.nextSendDate),
      lastSentDate: Value(a.lastSentDate),
      statusId: Value(a.statusId),
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
      // `recurring_dates` is intentionally NOT persisted — drop it before
      // serializing so the row stays small.
      payload: jsonEncode(_apiWithoutRecurringDates(a).toJson()),
    );
  }

  /// Strip the ephemeral `recurring_dates` array before persisting to
  /// Drift. The detail screen consumes it from the live `get` response.
  RecurringExpenseApi _apiWithoutRecurringDates(RecurringExpenseApi a) =>
      a.copyWith(recurringDates: null);

  RecurringExpensesCompanion _domainToCompanion(
    RecurringExpense e,
    String companyId, {
    required bool isDirty,
  }) {
    return RecurringExpensesCompanion.insert(
      id: e.id,
      companyId: companyId,
      number: Value(e.number),
      date: Value(e.date?.toIso() ?? ''),
      paymentDate: Value(e.paymentDate?.toIso() ?? ''),
      amount: Value(e.amount.toString()),
      vendorId: Value(e.vendorId),
      clientId: Value(e.clientId),
      projectId: Value(e.projectId),
      categoryId: Value(e.categoryId),
      invoiceId: Value(e.invoiceId),
      currencyId: Value(e.currencyId),
      shouldBeInvoiced: Value(e.shouldBeInvoiced),
      frequencyId: Value(e.frequencyId),
      remainingCycles: Value(e.remainingCycles),
      nextSendDate: Value(e.nextSendDate?.toIso() ?? ''),
      lastSentDate: Value(e.lastSentDate?.toIso() ?? ''),
      statusId: Value(e.statusId),
      updatedAt: dateToEpochSeconds(e.updatedAt),
      createdAt: Value(dateToEpochSeconds(e.createdAt)),
      archivedAt: e.archivedAt == null
          ? const Value.absent()
          : Value(dateToEpochSeconds(e.archivedAt!)),
      customValue1: Value(e.customValue1),
      customValue2: Value(e.customValue2),
      customValue3: Value(e.customValue3),
      customValue4: Value(e.customValue4),
      isDirty: Value(isDirty),
      isDeleted: Value(e.isDeleted),
      documents: Value(
        jsonEncode(e.documents.map((d) => d.toApi().toJson()).toList()),
      ),
      payload: jsonEncode(e.toApiJson(preserveTempId: true)),
    );
  }

  RecurringExpense _fromRow(RecurringExpenseRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = RecurringExpenseApi.fromJson(json);
    return RecurringExpense.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      documents: decodeDocumentsColumn(row.documents),
    );
  }
}

/// Server money values flip between number + string; normalize to a string
/// for stable storage. Mirrors `_moneyString` in `expense_repository.dart`.
String _moneyString(Object raw) {
  if (raw is String) return raw;
  return raw.toString();
}
