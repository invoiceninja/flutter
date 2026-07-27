import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/bank_accounts_table.dart';

part 'bank_account_dao.g.dart';

/// Stable field-id constants used by the list ViewModel for sort selection.
class BankAccountFieldIds {
  static const String name = 'name';
  static const String type = 'type';
  static const String provider = 'provider';
  static const String balance = 'balance';
  static const String state = 'state';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
}

@DriftAccessor(tables: [BankAccounts])
class BankAccountDao extends DatabaseAccessor<AppDatabase>
    with _$BankAccountDaoMixin, CompanyScopedDao {
  BankAccountDao(super.db);

  Stream<List<BankAccountRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = BankAccountFieldIds.updatedAt,
    bool sortAscending = false,
  }) {
    final q = select(bankAccounts)..where((b) => b.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (b) => entityStateFilter(
          states: states,
          archivedAt: b.archivedAt,
          isDeleted: b.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where(
        (b) => b.name.lower().like(needle) | b.provider.lower().like(needle),
      );
    }

    q.orderBy([
      (b) => OrderingTerm(
        expression: _sortExpression(b, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (b) => OrderingTerm(expression: b.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(BankAccounts b, String field) {
    switch (field) {
      case BankAccountFieldIds.name:
        return b.name.lower();
      case BankAccountFieldIds.type:
        return b.type.lower();
      case BankAccountFieldIds.provider:
        return b.provider.lower();
      case BankAccountFieldIds.balance:
        // Cast the TEXT-stored Decimal to REAL for numeric ordering.
        return const CustomExpression<double>('CAST(balance AS REAL)');
      case BankAccountFieldIds.createdAt:
        return b.createdAt;
      case BankAccountFieldIds.updatedAt:
      default:
        return b.updatedAt;
    }
  }

  Stream<BankAccountRow?> watchById({
    required String companyId,
    required String id,
  }) {
    return (select(bankAccounts)
          ..where((b) => b.companyId.equals(companyId) & b.id.equals(id))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> upsert(BankAccountsCompanion row) =>
      into(bankAccounts).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<BankAccountsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(bankAccounts, rows));
  }

  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, BankAccountsCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(bankAccounts)
      ..addColumns([bankAccounts.id])
      ..where(
        bankAccounts.companyId.equals(companyId) &
            bankAccounts.id.isIn(candidateIds) &
            bankAccounts.isDirty.equals(true),
      );
    final dirty = {
      for (final r in await dirtyQ.get()) r.read(bankAccounts.id)!,
    };
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      bankAccounts,
    )..where((b) => b.companyId.equals(companyId) & b.id.equals(id))).go();
  }

  Stream<int> watchActiveCount({required String companyId}) {
    final q = selectOnly(bankAccounts)
      ..addColumns([bankAccounts.id.count()])
      ..where(
        bankAccounts.companyId.equals(companyId) &
            bankAccounts.isDeleted.equals(false) &
            bankAccounts.archivedAt.isNull(),
      );
    return q.map((row) => row.read(bankAccounts.id.count()) ?? 0).watchSingle();
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
    return (update(bankAccounts)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const BankAccountsCompanion(isDirty: Value(false)));
  }
}
