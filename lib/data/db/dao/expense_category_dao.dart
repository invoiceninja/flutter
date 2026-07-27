import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/expense_categories_table.dart';

part 'expense_category_dao.g.dart';

/// Stable identifiers for sortable / filterable ExpenseCategory fields.
/// Mirrors `TaskStatusFieldIds`. `updatedAt` is used as a tie-breaker
/// when callers don't specify a sort field.
class ExpenseCategoryFieldIds {
  static const String name = 'name';
  static const String updatedAt = 'updated_at';

  /// Payload-only column surfaced by the column picker.
  static const String color = 'color';
}

@DriftAccessor(tables: [ExpenseCategories])
class ExpenseCategoryDao extends DatabaseAccessor<AppDatabase>
    with _$ExpenseCategoryDaoMixin, CompanyScopedDao {
  ExpenseCategoryDao(super.db);

  Stream<List<ExpenseCategoryRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = ExpenseCategoryFieldIds.name,
    bool sortAscending = true,
  }) {
    final q = select(expenseCategories)
      ..where((c) => c.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (c) => entityStateFilter(
          states: states,
          archivedAt: c.archivedAt,
          isDeleted: c.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where((c) => c.name.lower().like(needle));
    }

    q.orderBy([
      (c) => OrderingTerm(
        expression: _sortExpression(c, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (c) => OrderingTerm(expression: c.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(ExpenseCategories c, String field) {
    switch (field) {
      case ExpenseCategoryFieldIds.name:
        return c.name.lower();
      case ExpenseCategoryFieldIds.updatedAt:
        return c.updatedAt;
      // Payload-only column. Without a case it hit the silent `name` fallback
      // below while still rendering a sortable header.
      case ExpenseCategoryFieldIds.color:
        return CustomExpression<String>(
          "LOWER(COALESCE(json_extract(payload, '\$.color'), ''))",
        );
      default:
        return c.name.lower();
    }
  }

  /// One-shot count of rows that match the active state filter — drives the
  /// scaffold's pagination-exhausted check.
  Stream<int> watchCount({
    required String companyId,
    Set<EntityState> states = const {EntityState.active},
  }) {
    final countExp = expenseCategories.id.count();
    final q = selectOnly(expenseCategories)
      ..addColumns([countExp])
      ..where(expenseCategories.companyId.equals(companyId));
    if (states.isNotEmpty) {
      q.where(
        entityStateFilter(
          states: states,
          archivedAt: expenseCategories.archivedAt,
          isDeleted: expenseCategories.isDeleted,
        ),
      );
    }
    return q.map((row) => row.read(countExp) ?? 0).watchSingle();
  }

  /// Watch every active category's `(id, name)` pair, ordered by name. Used
  /// by the Expense edit form's category picker so the dropdown stays in
  /// sync with category renames / archives without a manual refresh.
  Stream<List<ExpenseCategoryRow>> watchActiveNames({
    required String companyId,
  }) {
    final q = select(expenseCategories)
      ..where(
        (c) =>
            c.companyId.equals(companyId) &
            c.isDeleted.equals(false) &
            c.archivedAt.isNull(),
      )
      ..orderBy([(c) => OrderingTerm(expression: c.name.lower())]);
    return q.watch().distinctRows();
  }

  Stream<ExpenseCategoryRow?> watchById({
    required String companyId,
    required String id,
  }) {
    final q = select(expenseCategories)
      ..where((c) => c.companyId.equals(companyId) & c.id.equals(id))
      ..limit(1);
    return q.watchSingleOrNull();
  }

  Future<void> upsert(ExpenseCategoriesCompanion row) =>
      into(expenseCategories).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<ExpenseCategoriesCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(expenseCategories, rows));
  }

  /// Server-refresh upsert that preserves the user's in-flight edits.
  /// Mirrors [BaseEntityDao.upsertAllPreservingDirty]; used by `applyBundle`
  /// and `ensurePageLoaded` so the user's queued offline edit isn't clobbered
  /// by a stale server payload.
  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, ExpenseCategoriesCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(expenseCategories)
      ..addColumns([expenseCategories.id])
      ..where(
        expenseCategories.companyId.equals(companyId) &
            expenseCategories.id.isIn(candidateIds) &
            expenseCategories.isDirty.equals(true),
      );
    final dirty = {
      for (final r in await dirtyQ.get()) r.read(expenseCategories.id)!,
    };
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      expenseCategories,
    )..where((c) => c.companyId.equals(companyId) & c.id.equals(id))).go();
  }
}
