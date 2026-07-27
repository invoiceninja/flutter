import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/columns/bank_transaction_columns.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/bank_transactions_table.dart';

part 'bank_transaction_dao.g.dart';

class BankTransactionFieldIds {
  static const String date = 'date';
  static const String amount = 'amount';
  static const String description = 'description';
  static const String participantName = 'participant_name';
  static const String statusId = 'status_id';
  static const String baseType = 'base_type';
  static const String state = 'state';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
}

@DriftAccessor(tables: [BankTransactions])
class BankTransactionDao extends DatabaseAccessor<AppDatabase>
    with _$BankTransactionDaoMixin, CompanyScopedDao {
  BankTransactionDao(super.db);

  Stream<List<BankTransactionRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String? bankAccountId,
    Set<String>? statusIds,
    String? baseType,
    String? dateStart,
    String? dateEnd,
    String? dateOp,
    String? dateValue,
    String sortField = BankTransactionFieldIds.date,
    bool sortAscending = false,
  }) {
    final q = select(bankTransactions)
      ..where((t) => t.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (t) => entityStateFilter(
          states: states,
          archivedAt: t.archivedAt,
          isDeleted: t.isDeleted,
        ),
      );
    }

    if (bankAccountId != null && bankAccountId.isNotEmpty) {
      q.where((t) => t.bankAccountId.equals(bankAccountId));
    }
    if (statusIds != null && statusIds.isNotEmpty) {
      q.where((t) => t.statusId.isIn(statusIds.toList(growable: false)));
    }
    if (baseType != null && baseType.isNotEmpty) {
      q.where((t) => t.baseType.equals(baseType));
    }
    // Date window (between) — mirrors the `date_range` filter slot. The `date`
    // column is ISO `YYYY-MM-DD` text, which compares lexically.
    if (dateStart != null && dateEnd != null) {
      q.where((t) => t.date.isBetweenValues(dateStart, dateEnd));
    }
    // Single-date comparator — mirrors the `date` (op:value) filter slot.
    if (dateValue != null && dateValue.isNotEmpty) {
      final v = dateValue;
      switch (dateOp) {
        case 'gt':
          q.where((t) => t.date.isBiggerThanValue(v));
        case 'lte':
          q.where((t) => t.date.isSmallerOrEqualValue(v));
        case 'lt':
          q.where((t) => t.date.isSmallerThanValue(v));
        case 'eq':
          q.where((t) => t.date.equals(v));
        case 'gte':
        default:
          q.where((t) => t.date.isBiggerOrEqualValue(v));
      }
    }
    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where(
        (t) =>
            t.description.lower().like(needle) |
            t.participantName.lower().like(needle) |
            t.participant.lower().like(needle),
      );
    }

    q.orderBy([
      (t) => OrderingTerm(
        expression: _sortExpression(t, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (t) => OrderingTerm(expression: t.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(BankTransactions t, String field) {
    switch (field) {
      case BankTransactionFieldIds.date:
        return t.date;
      case BankTransactionFieldIds.amount:
        return const CustomExpression<double>('CAST(amount AS REAL)');
      case BankTransactionFieldIds.description:
        return t.description.lower();
      case BankTransactionFieldIds.participantName:
        return t.participantName.lower();
      case BankTransactionFieldIds.statusId:
        return t.statusId;
      case BankTransactionFieldIds.baseType:
        return t.baseType;
      case BankTransactionFieldIds.createdAt:
        return t.createdAt;
      case BankTransactionFieldIds.updatedAt:
        return t.updatedAt;
      // Opt-in columns that ARE backed by real Drift columns. Without these
      // cases they hit the fallback and the header silently ordered by
      // `updated_at`.
      case BankTransactionColumnIds.bankAccountId:
        return t.bankAccountId;
      case BankTransactionColumnIds.currencyId:
        return t.currencyId;
      case BankTransactionColumnIds.invoices:
        return t.invoiceIds;
      case BankTransactionColumnIds.expenses:
        return t.expenseId;
      default:
        // Throw like every other list DAO rather than silently ordering by
        // something else: `sortable_columns_test` probes every registered
        // sortable column and can only detect a gap if the DAO throws. A
        // silent fallback here is what let six dead headers ship.
        throw ArgumentError.value(
          field,
          'sortField',
          'no sort expression for this bank-transaction column — add a case, '
              'or mark the column sortable: false',
        );
    }
  }

  Stream<BankTransactionRow?> watchById({
    required String companyId,
    required String id,
  }) {
    return (select(bankTransactions)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> upsert(BankTransactionsCompanion row) =>
      into(bankTransactions).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<BankTransactionsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(bankTransactions, rows));
  }

  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, BankTransactionsCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(bankTransactions)
      ..addColumns([bankTransactions.id])
      ..where(
        bankTransactions.companyId.equals(companyId) &
            bankTransactions.id.isIn(candidateIds) &
            bankTransactions.isDirty.equals(true),
      );
    final dirty = {
      for (final r in await dirtyQ.get()) r.read(bankTransactions.id)!,
    };
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      bankTransactions,
    )..where((t) => t.companyId.equals(companyId) & t.id.equals(id))).go();
  }

  Stream<int> watchActiveCount({required String companyId}) {
    final q = selectOnly(bankTransactions)
      ..addColumns([bankTransactions.id.count()])
      ..where(
        bankTransactions.companyId.equals(companyId) &
            bankTransactions.isDeleted.equals(false) &
            bankTransactions.archivedAt.isNull(),
      );
    return q
        .map((row) => row.read(bankTransactions.id.count()) ?? 0)
        .watchSingle();
  }

  /// Clear the local `is_dirty` flag for one row (mirrors
  /// [BaseEntityDao.clearDirtyById]).
  ///
  /// Load-bearing: this DAO doesn't extend `BaseEntityDao`, so
  /// `BaseEntityRepository.localDao` is null and the discard-reconciliation
  /// hook would be a silent no-op. Because every refresh path here goes
  /// through `upsertAllPreservingDirty`, a row left dirty after the user
  /// discards its edit is skipped by EVERY later refresh — the abandoned
  /// value would be shown as authoritative forever.
  Future<void> clearDirtyById({required String companyId, required String id}) {
    return (update(bankTransactions)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const BankTransactionsCompanion(isDirty: Value(false)));
  }
}
