import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:logging/logging.dart';

import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/billing_extra_filters.dart';
import 'package:admin/data/db/dao/expense_dao.dart';
import 'package:admin/data/models/api/document_api_model.dart';
import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/repositories/document_bearing_repository.dart';
import 'package:admin/data/services/expenses_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/data/services/upload_source.dart';
import 'package:admin/domain/sync/mutation.dart';
import 'package:admin/data/models/value/parsing.dart';

final _log = Logger('ExpenseRepository');

/// Source of truth for Expense data. The UI watches Drift via [watchPage]
/// and [watch]; the network only writes. Every mutation goes through the
/// outbox.
///
/// Page size is fixed at [pageSize]. Subsequent pages are fetched only on
/// demand — list screens call [ensurePageLoaded] near the scroll edge.
///
/// Mirrors `ProjectRepository`: document-bearing, password-gated
/// delete/purge/documentDelete, full apply-response triple + _fromRow
/// overlay.
class ExpenseRepository extends BaseEntityRepository<Expense, ExpenseApi>
    implements DocumentBearingRepository {
  ExpenseRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.expense,
         requiresPasswordFor: const {
           MutationKind.delete,
           MutationKind.purge,
           MutationKind.documentDelete,
         },
       );

  final ExpensesApi api;
  final int pageSize;

  @override
  String get entityTypeName => 'expense';

  /// Watch the first [loadedPages] pages worth of rows. [loadedPages] is
  /// 1-based — 1 means "show page 1," 2 means "show pages 1+2," etc.
  Stream<List<Expense>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = ExpenseFieldIds.date,
    bool sortAscending = false,
    String? clientId,
    String? vendorId,
    String? projectId,
    Map<String, Set<String>> extraFilters = const {},
  }) {
    assert(
      loadedPages >= 1,
      'loadedPages is 1-based; pass 1 for the first page',
    );
    return db.expenseDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
          clientId: clientId,
          vendorId: vendorId,
          projectId: projectId,
          clientIds: parseClientIdFilter(extraFilters),
          categoryIds: parseExpenseCategoryFilter(extraFilters),
          projectIds: parseCsvFilter(extraFilters, 'project_ids'),
          vendorIds: parseCsvFilter(extraFilters, 'vendor_ids'),
          statuses: parseExpenseStatusFilter(extraFilters),
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<int> watchCount({required String companyId}) =>
      db.expenseDao.watchCount(companyId: companyId);

  Stream<List<Expense>> watchForVendor({
    required String companyId,
    required String vendorId,
  }) {
    if (vendorId.isEmpty) {
      return Stream<List<Expense>>.value(const <Expense>[]);
    }
    return db.expenseDao
        .watchForVendor(companyId: companyId, vendorId: vendorId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<List<Expense>> watchForClient({
    required String companyId,
    required String clientId,
  }) {
    if (clientId.isEmpty) {
      return Stream<List<Expense>>.value(const <Expense>[]);
    }
    return db.expenseDao
        .watchForClient(companyId: companyId, clientId: clientId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<List<Expense>> watchForProject({
    required String companyId,
    required String projectId,
  }) {
    if (projectId.isEmpty) {
      return Stream<List<Expense>>.value(const <Expense>[]);
    }
    return db.expenseDao
        .watchForProject(companyId: companyId, projectId: projectId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<List<Expense>> watchForCategory({
    required String companyId,
    required String categoryId,
  }) {
    if (categoryId.isEmpty) {
      return Stream<List<Expense>>.value(const <Expense>[]);
    }
    return db.expenseDao
        .watchForCategory(companyId: companyId, categoryId: categoryId)
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  @override
  Stream<Expense?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.expenseDao
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
    excludeDeletedClients: true,
    // `?include=documents` — same rationale as Project/Client.
    staticFilters: const {'include': 'documents'},
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.expenseDao.upsertAllPreservingDirty(
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

  /// Create a new expense offline. Returns the expense with its tmp id so
  /// the UI can navigate to the detail screen immediately.
  Future<SaveResult<Expense>> create({
    required String companyId,
    required Expense draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.expenseDao.upsert(companion);
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

  Future<SaveResult<Expense>> save({
    required String companyId,
    required Expense expense,
  }) async {
    // If this entity's offline create already drained while the edit
    // form was open, id_remap now points the tmp id at the real row (the
    // tmp row was deleted). Saving under the stale tmp id would resurrect
    // it as a ghost duplicate — and deleting that ghost would delete the
    // real entity via the remap. Rebind to the real id first.
    final resolvedId = await resolveId(expense.id);
    if (resolvedId != expense.id) expense = expense.copyWith(id: resolvedId);

    final companion = _domainToCompanion(expense, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.expenseDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: expense.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: expense.id,
        kind: MutationKind.update,
        payload: expense.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: expense, outboxRowId: rowId);
  }

  /// Append a user comment to this expense's activity stream. Hits
  /// `/api/v1/activities/notes` via the outbox; the dispatcher's
  /// `customActions` map calls the `ActivitiesApi`.
  Future<void> addComment({
    required String companyId,
    required String expenseId,
    required String text,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: expenseId,
      kind: MutationKind.addComment,
      payload: {'entity_id': expenseId, 'notes': text.trim()},
    );
  }

  /// Apply a design / email template to this expense. Mirrors
  /// `InvoiceRepository.runTemplate`.
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

  /// Queue a document upload. Mirrors `ProjectRepository.uploadDocument` —
  /// the dispatcher's `MutationKind.documentUpload` handler streams the
  /// local file via multipart upload.
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
  }) => db.expenseDao.deleteById(companyId: companyId, id: id);

  @override
  BaseEntityDao<dynamic, dynamic> get localDao => db.expenseDao;

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required ExpenseApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.expenseDao.upsert,
    deleteById: (id) => db.expenseDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required ExpenseApi serverResponse,
  }) async {
    await db.expenseDao.upsert(_apiToCompanion(serverResponse, companyId));
  }

  /// Lazily hydrate a single expense into Drift on a cache miss — backs
  /// `ExpenseNameLabel` (e.g. the expense a bank transaction matched, which
  /// isn't on the prefetched first page). Deduped / negative-cached in the
  /// template; safe to call unconditionally per rebuild.
  Future<void> ensureLoaded({required String companyId, required String id}) =>
      ensureLoadedTemplate(
        companyId: companyId,
        id: id,
        fetch: (id) async => (await api.get(id)).data,
        idOf: (a) => a.id,
        toCompanion: (a) => _apiToCompanion(a, companyId),
        upsert: (byId) => db.expenseDao.upsertAllPreservingDirty(
          companyId: companyId,
          byId: byId,
        ),
      );

  /// Force-refetch expenses by id (e.g. after an invoice billed/un-billed them,
  /// or a PO/bank-transaction created one). See [refreshByIdsTemplate].
  @override
  Future<void> refreshByIds({
    required String companyId,
    required Iterable<String> ids,
  }) async {
    await refreshByIdsTemplate<ExpenseApi, ExpensesCompanion>(
      companyId: companyId,
      ids: ids,
      fetch: (id) async => (await api.get(id)).data,
      idOf: (a) => a.id,
      toCompanion: (a) => _apiToCompanion(a, companyId),
      upsert: (byId) => db.expenseDao.upsertAllPreservingDirty(
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
    final existing = await db.expenseDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.expenseDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  /// Drop a document from the expense's local `documents` JSON column.
  /// Mirror of `ProjectRepository.applyDocumentDeleted`.
  Future<void> applyDocumentDeleted({
    required String companyId,
    required String entityId,
    required String documentId,
  }) async {
    final row = await db.expenseDao
        .watchById(companyId: companyId, id: entityId)
        .first;
    if (row == null) return;
    final current = decodeRawDocumentsColumn(row.documents);
    final next = current.where((d) => d.id != documentId).toList();
    if (next.length == current.length) return;
    await (db.update(db.expenses)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          ExpensesCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  /// Replace (or insert) one document in the expense's local `documents`
  /// JSON column. Mirror of `ProjectRepository.applyDocumentChanged`.
  Future<void> applyDocumentChanged({
    required String companyId,
    required String entityId,
    required DocumentApi document,
  }) async {
    final row = await db.expenseDao
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
    await (db.update(db.expenses)
          ..where((e) => e.companyId.equals(companyId) & e.id.equals(entityId)))
        .write(
          ExpensesCompanion(
            documents: Value(jsonEncode(next.map((d) => d.toJson()).toList())),
          ),
        );
  }

  // -------------------- conversions --------------------

  ExpensesCompanion _apiToCompanion(ExpenseApi a, String companyId) {
    // Server-aligned paid flag (`payment_date` / `transaction_reference` only)
    // so the local status filter matches `ExpenseFilters::clientStatus`.
    final isPaid =
        a.paymentDate.isNotEmpty || a.transactionReference.isNotEmpty;
    return ExpensesCompanion.insert(
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
      isPaid: Value(isPaid),
      shouldBeInvoiced: Value(a.shouldBeInvoiced),
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

  ExpensesCompanion _domainToCompanion(
    Expense e,
    String companyId, {
    required bool isDirty,
  }) {
    // Server-aligned paid flag — see `_apiToCompanion`.
    final isPaid = (e.paymentDate != null) || e.transactionReference.isNotEmpty;
    return ExpensesCompanion.insert(
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
      isPaid: Value(isPaid),
      shouldBeInvoiced: Value(e.shouldBeInvoiced),
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

  Expense _fromRow(ExpenseRow row) {
    final json = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = ExpenseApi.fromJson(json);
    // is_dirty is local-only; documents live in their own column. Overlay
    // both onto the API-derived domain so the UI sees current state.
    return Expense.fromApi(api).copyWith(
      isDirty: row.isDirty,
      isDeleted: row.isDeleted,
      archivedAt: epochSecondsToUtcOrNull(row.archivedAt ?? 0),
      documents: decodeDocumentsColumn(row.documents),
    );
  }
}

/// The server sometimes returns money as a number, sometimes as a string;
/// normalize to a string for stable storage. Mirrors `_moneyString` in
/// `project_repository.dart`.
String _moneyString(Object raw) {
  if (raw is String) return raw;
  return raw.toString();
}
