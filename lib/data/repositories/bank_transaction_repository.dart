import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/bank_transaction_dao.dart';
import 'package:admin/data/models/api/bank_transaction_api_model.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/base_entity_repository.dart';
import 'package:admin/data/services/bank_transactions_api.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sync/mutation.dart';

final _log = Logger('BankTransactionRepository');

/// Source of truth for BankTransaction (`bank_transaction`) data.
class BankTransactionRepository
    extends BaseEntityRepository<BankTransaction, BankTransactionApi> {
  BankTransactionRepository({
    required super.db,
    required this.api,
    super.uuid,
    super.now,
    super.onEnqueued,
    this.onRelatedEntitiesAffected,
    this.pageSize = 50,
  }) : super(
         entityType: EntityType.transaction,
         requiresPasswordFor: const {MutationKind.delete, MutationKind.purge},
       );

  final BankTransactionsApi api;
  final int pageSize;

  /// Fired after a transaction match/link/convert/unlink is applied, so the
  /// invoice(s) whose balance/status changed server-side are force-refetched
  /// into Drift instead of staying stale until a manual full resync (issue #7).
  /// Bank transactions carry no client id — the DI closure derives the client
  /// from the refreshed invoices. Wired by DI; null in tests that don't
  /// exercise the side-effect refresh.
  final RelatedEntitiesRefresher? onRelatedEntitiesAffected;

  @override
  String get entityTypeName => 'bank_transaction';

  Stream<List<BankTransaction>> watchPage({
    required String companyId,
    int loadedPages = 1,
    String? search,
    String? bankAccountId,
    Set<String>? statusIds,
    String? baseType,
    String? dateStart,
    String? dateEnd,
    String? dateOp,
    String? dateValue,
    Set<EntityState> states = const {EntityState.active},
    String sortField = BankTransactionFieldIds.date,
    bool sortAscending = false,
  }) {
    assert(loadedPages >= 1);
    return db.bankTransactionDao
        .watchPage(
          companyId: companyId,
          offset: 0,
          limit: pageSize * loadedPages,
          search: search,
          bankAccountId: bankAccountId,
          statusIds: statusIds,
          baseType: baseType,
          dateStart: dateStart,
          dateEnd: dateEnd,
          dateOp: dateOp,
          dateValue: dateValue,
          states: states,
          sortField: sortField,
          sortAscending: sortAscending,
        )
        .map((rows) => rows.map(_fromRow).toList(growable: false));
  }

  Stream<int> watchCount({required String companyId}) =>
      db.bankTransactionDao.watchActiveCount(companyId: companyId);

  @override
  Stream<BankTransaction?> watchByRealId({
    required String companyId,
    required String id,
  }) => db.bankTransactionDao
      .watchById(companyId: companyId, id: id)
      .map((row) => row == null ? null : _fromRow(row));

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
    // Default to active-banks filter so transactions tied to archived
    // bank integrations don't pollute the list. Clear by passing
    // `extraFilters: {'active_banks': {}}` if you ever need them.
    staticFilters: const {'active_banks': 'true'},
    ignoreCursor: ignoreCursor,
    listCall: api.list,
    itemsOf: (l) => l.data,
    idOf: (a) => a.id,
    toCompanion: (a) => _apiToCompanion(a, companyId),
    upsert: (byId) => db.bankTransactionDao.upsertAllPreservingDirty(
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
    const maxPages = 200;
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

  Future<SaveResult<BankTransaction>> create({
    required String companyId,
    required BankTransaction draft,
    String? existingTempId,
  }) async {
    final tmpId = existingTempId ?? mintTempId();
    final stored = draft.copyWith(id: tmpId);
    final companion = _domainToCompanion(stored, companyId, isDirty: true);

    var rowId = 0;
    await db.transaction(() async {
      await db.bankTransactionDao.upsert(companion);
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

  Future<SaveResult<BankTransaction>> save({
    required String companyId,
    required BankTransaction transaction,
  }) async {
    final companion = _domainToCompanion(transaction, companyId, isDirty: true);
    var rowId = 0;
    await db.transaction(() async {
      await db.bankTransactionDao.upsert(companion);
      await dedupPendingMutations(
        companyId: companyId,
        entityId: transaction.id,
        kind: MutationKind.update,
      );
      rowId = await enqueueMutation(
        companyId: companyId,
        entityId: transaction.id,
        kind: MutationKind.update,
        payload: transaction.toApiJson(preserveTempId: true),
      );
    });
    return SaveResult(entity: transaction, outboxRowId: rowId);
  }

  // ── match-action helpers ──

  /// CREDIT, create payment from invoices.
  Future<void> matchToPayment({
    required String companyId,
    required String transactionId,
    required List<String> invoiceIds,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: transactionId,
      kind: MutationKind.matchToPayment,
      payload: {
        'transactions': [
          {'id': transactionId, 'invoice_ids': invoiceIds.join(',')},
        ],
      },
    );
  }

  /// CREDIT, link to existing payment.
  Future<void> linkToPayment({
    required String companyId,
    required String transactionId,
    required String paymentId,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: transactionId,
      kind: MutationKind.linkToPayment,
      payload: {
        'transactions': [
          {'id': transactionId, 'payment_id': paymentId},
        ],
      },
    );
  }

  /// DEBIT, create expense from vendor + category.
  Future<void> matchToExpense({
    required String companyId,
    required String transactionId,
    required String vendorId,
    required String categoryId,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: transactionId,
      kind: MutationKind.matchToExpense,
      payload: {
        'transactions': [
          {
            'id': transactionId,
            // Omit empty keys rather than leaning on Laravel's empty-string→null
            // coercion. At least one is always present (the UI gates submit on
            // vendor or category being set).
            if (vendorId.isNotEmpty) 'vendor_id': vendorId,
            if (categoryId.isNotEmpty) 'ninja_category_id': categoryId,
          },
        ],
      },
    );
  }

  /// DEBIT, link to existing expense.
  Future<void> linkToExpense({
    required String companyId,
    required String transactionId,
    required String expenseId,
  }) async {
    await enqueueMutation(
      companyId: companyId,
      entityId: transactionId,
      kind: MutationKind.linkToExpense,
      payload: {
        'transactions': [
          {'id': transactionId, 'expense_id': expenseId},
        ],
      },
    );
  }

  /// Bulk: convert matched rows into expenses/payments on the server.
  /// Single-id calls use the transaction's real id as the outbox row's
  /// `entityId` so the Outbox screen renders meaningfully; genuinely
  /// batched calls (>1 id) use the synthetic [kBulkTransactionEntityId]
  /// since the row doesn't point at any one transaction. Either way
  /// the full id list lives in the payload.
  Future<void> convertMatched({
    required String companyId,
    required List<String> transactionIds,
  }) async {
    if (transactionIds.isEmpty) return;
    await enqueueMutation(
      companyId: companyId,
      entityId: transactionIds.length == 1
          ? transactionIds.first
          : kBulkTransactionEntityId,
      kind: MutationKind.convertMatched,
      payload: {'ids': transactionIds},
    );
  }

  /// Bulk: detach matched/converted rows from their linked entities.
  /// Same single-vs-bulk id treatment as [convertMatched].
  Future<void> unlinkTransactions({
    required String companyId,
    required List<String> transactionIds,
  }) async {
    if (transactionIds.isEmpty) return;
    await enqueueMutation(
      companyId: companyId,
      entityId: transactionIds.length == 1
          ? transactionIds.first
          : kBulkTransactionEntityId,
      kind: MutationKind.unlinkTransaction,
      payload: {'ids': transactionIds},
    );
  }

  @override
  Future<void> deleteLocalById({
    required String companyId,
    required String id,
  }) => db.bankTransactionDao.deleteById(companyId: companyId, id: id);

  @override
  Future<void> applyCreateResponse({
    required String companyId,
    required String tempId,
    required BankTransactionApi serverResponse,
  }) => applyCreateResponseTemplate(
    companyId: companyId,
    tempId: tempId,
    realId: serverResponse.id,
    companion: _apiToCompanion(serverResponse, companyId),
    upsert: db.bankTransactionDao.upsert,
    deleteById: (id) =>
        db.bankTransactionDao.deleteById(companyId: companyId, id: id),
  );

  @override
  Future<void> applyUpdateResponse({
    required String companyId,
    required BankTransactionApi serverResponse,
  }) async {
    // Read the pre-update row first, so `unlink` — whose response clears
    // `invoice_ids` — still refreshes the now-detached invoice.
    final existing = await db.bankTransactionDao
        .watchById(companyId: companyId, id: serverResponse.id)
        .first;
    await db.bankTransactionDao.upsert(
      _apiToCompanion(serverResponse, companyId),
    );
    final domain = BankTransaction.fromApi(serverResponse);
    // Union the response with the pre-update row so a reversal (`unlink`, whose
    // response clears the ids) still refreshes the now-detached invoice/expense.
    await _refreshRelated(companyId, {
      EntityType.invoice: {
        ...domain.linkedInvoiceIds,
        if (existing != null) ..._splitCsv(existing.invoiceIds),
      },
      EntityType.expense: {
        ...domain.linkedExpenseIds,
        if (existing != null) ..._splitCsv(existing.expenseId),
      },
      if (serverResponse.paymentId.isNotEmpty)
        EntityType.payment: {serverResponse.paymentId},
    });
  }

  /// Fire [onRelatedEntitiesAffected] for the entities a match/link/convert/unlink
  /// touched — invoice(s) (CREDIT side), expense(s) (DEBIT side), and the
  /// created/linked payment. Bank transactions carry no client id — the DI closure
  /// derives the client from the refreshed invoices. Runs inside the outbox drain,
  /// so failures are swallowed (see [onRelatedEntitiesAffected]).
  Future<void> _refreshRelated(
    String companyId,
    Map<EntityType, Set<String>> byType,
  ) async {
    final cb = onRelatedEntitiesAffected;
    if (cb == null) return;
    final cleaned = <EntityType, Set<String>>{};
    for (final entry in byType.entries) {
      final ids = entry.value.where((id) => id.isNotEmpty).toSet();
      if (ids.isNotEmpty) cleaned[entry.key] = ids;
    }
    if (cleaned.isEmpty) return;
    try {
      await cb(companyId, cleaned);
    } catch (e) {
      _log.warning('onRelatedEntitiesAffected failed: $e');
    }
  }

  List<String> _splitCsv(String csv) => csv.isEmpty
      ? const <String>[]
      : csv.split(',').where((e) => e.isNotEmpty).toList(growable: false);

  @override
  Future<void> applyDeleteResponse({
    required String companyId,
    required String id,
  }) async {
    final existing = await db.bankTransactionDao
        .watchById(companyId: companyId, id: id)
        .first;
    if (existing == null) return;
    await db.bankTransactionDao.upsert(
      existing
          .toCompanion(true)
          .copyWith(isDeleted: const Value(true), isDirty: const Value(false)),
    );
  }

  // -------------------- conversions --------------------

  BankTransactionsCompanion _apiToCompanion(
    BankTransactionApi a,
    String companyId,
  ) {
    final domain = BankTransaction.fromApi(a);
    return BankTransactionsCompanion.insert(
      id: a.id,
      companyId: companyId,
      amount: Value(domain.amount.toString()),
      currencyId: Value(domain.currencyId),
      category: Value(domain.category),
      baseType: Value(domain.baseType),
      date: Value(domain.date?.toIso() ?? ''),
      bankAccountId: Value(domain.bankAccountId),
      description: Value(domain.description),
      statusId: Value(domain.statusId),
      categoryId: Value(domain.categoryId),
      invoiceIds: Value(domain.invoiceIds),
      paymentId: Value(domain.paymentId),
      expenseId: Value(domain.expenseId),
      vendorId: Value(domain.vendorId),
      transactionId: Value(domain.transactionId),
      transactionRuleId: Value(domain.transactionRuleId),
      participantName: Value(domain.participantName),
      participant: Value(domain.participant),
      updatedAt: a.updatedAt,
      createdAt: Value(a.createdAt),
      archivedAt: a.archivedAt > 0 ? Value(a.archivedAt) : const Value(null),
      isDirty: const Value(false),
      isDeleted: Value(a.isDeleted),
      payload: jsonEncode(a.toJson()),
    );
  }

  BankTransactionsCompanion _domainToCompanion(
    BankTransaction t,
    String companyId, {
    required bool isDirty,
  }) {
    return BankTransactionsCompanion.insert(
      id: t.id,
      companyId: companyId,
      amount: Value(t.amount.toString()),
      currencyId: Value(t.currencyId),
      category: Value(t.category),
      baseType: Value(t.baseType),
      date: Value(t.date?.toIso() ?? ''),
      bankAccountId: Value(t.bankAccountId),
      description: Value(t.description),
      statusId: Value(t.statusId),
      categoryId: Value(t.categoryId),
      invoiceIds: Value(t.invoiceIds),
      paymentId: Value(t.paymentId),
      expenseId: Value(t.expenseId),
      vendorId: Value(t.vendorId),
      transactionId: Value(t.transactionId),
      transactionRuleId: Value(t.transactionRuleId),
      participantName: Value(t.participantName),
      participant: Value(t.participant),
      updatedAt: t.updatedAt.millisecondsSinceEpoch ~/ 1000,
      createdAt: Value(t.createdAt.millisecondsSinceEpoch ~/ 1000),
      archivedAt: t.archivedAt == null
          ? const Value.absent()
          : Value(t.archivedAt!.millisecondsSinceEpoch ~/ 1000),
      isDirty: Value(isDirty),
      isDeleted: Value(t.isDeleted),
      payload: jsonEncode(t.toApiJson(preserveTempId: true)),
    );
  }

  BankTransaction _fromRow(BankTransactionRow row) {
    final apiJson = jsonDecode(row.payload) as Map<String, dynamic>;
    final api = BankTransactionApi.fromJson(apiJson);
    return BankTransaction.fromApi(api).copyWith(isDirty: row.isDirty);
  }
}
