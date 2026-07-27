import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/transaction_rules_table.dart';

part 'transaction_rule_dao.g.dart';

class TransactionRuleFieldIds {
  static const String name = 'name';
  static const String appliesTo = 'applies_to';
  static const String state = 'state';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
}

@DriftAccessor(tables: [TransactionRules])
class TransactionRuleDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionRuleDaoMixin, CompanyScopedDao {
  TransactionRuleDao(super.db);

  Stream<List<TransactionRuleRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = TransactionRuleFieldIds.name,
    bool sortAscending = true,
  }) {
    final q = select(transactionRules)
      ..where((r) => r.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (r) => entityStateFilter(
          states: states,
          archivedAt: r.archivedAt,
          isDeleted: r.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where((r) => r.name.lower().like(needle));
    }

    q.orderBy([
      (r) => OrderingTerm(
        expression: _sortExpression(r, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (r) => OrderingTerm(expression: r.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(TransactionRules r, String field) {
    switch (field) {
      case TransactionRuleFieldIds.appliesTo:
        return r.appliesTo;
      case TransactionRuleFieldIds.createdAt:
        return r.createdAt;
      case TransactionRuleFieldIds.updatedAt:
        return r.updatedAt;
      case TransactionRuleFieldIds.name:
      default:
        return r.name.lower();
    }
  }

  Stream<TransactionRuleRow?> watchById({
    required String companyId,
    required String id,
  }) {
    return (select(transactionRules)
          ..where((r) => r.companyId.equals(companyId) & r.id.equals(id))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> upsert(TransactionRulesCompanion row) =>
      into(transactionRules).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<TransactionRulesCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(transactionRules, rows));
  }

  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, TransactionRulesCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(transactionRules)
      ..addColumns([transactionRules.id])
      ..where(
        transactionRules.companyId.equals(companyId) &
            transactionRules.id.isIn(candidateIds) &
            transactionRules.isDirty.equals(true),
      );
    final dirty = {
      for (final r in await dirtyQ.get()) r.read(transactionRules.id)!,
    };
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      transactionRules,
    )..where((r) => r.companyId.equals(companyId) & r.id.equals(id))).go();
  }

  Stream<int> watchActiveCount({required String companyId}) {
    final q = selectOnly(transactionRules)
      ..addColumns([transactionRules.id.count()])
      ..where(
        transactionRules.companyId.equals(companyId) &
            transactionRules.isDeleted.equals(false) &
            transactionRules.archivedAt.isNull(),
      );
    return q
        .map((row) => row.read(transactionRules.id.count()) ?? 0)
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
    return (update(transactionRules)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const TransactionRulesCompanion(isDirty: Value(false)));
  }
}
