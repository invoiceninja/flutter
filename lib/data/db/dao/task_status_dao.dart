import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/task_statuses_table.dart';

part 'task_status_dao.g.dart';

class TaskStatusFieldIds {
  static const String name = 'name';
  static const String statusOrder = 'status_order';
  static const String updatedAt = 'updated_at';
}

@DriftAccessor(tables: [TaskStatuses])
class TaskStatusDao extends DatabaseAccessor<AppDatabase>
    with _$TaskStatusDaoMixin, CompanyScopedDao {
  TaskStatusDao(super.db);

  Stream<List<TaskStatusRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = TaskStatusFieldIds.statusOrder,
    bool sortAscending = true,
  }) {
    final q = select(taskStatuses)..where((s) => s.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (s) => entityStateFilter(
          states: states,
          archivedAt: s.archivedAt,
          isDeleted: s.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where((s) => s.name.lower().like(needle));
    }

    q.orderBy([
      (s) => OrderingTerm(
        expression: _sortExpression(s, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (s) => OrderingTerm(expression: s.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(TaskStatuses s, String field) {
    switch (field) {
      case TaskStatusFieldIds.name:
        return s.name.lower();
      case TaskStatusFieldIds.statusOrder:
        return s.statusOrder;
      case TaskStatusFieldIds.updatedAt:
        return s.updatedAt;
      default:
        return s.statusOrder;
    }
  }

  /// Watch every active task status in order. Used by the kanban board
  /// (one column per row) and by the status dropdown on the Task edit form.
  Stream<List<TaskStatusRow>> watchAll({required String companyId}) {
    final q = select(taskStatuses)
      ..where(
        (s) =>
            s.companyId.equals(companyId) &
            s.isDeleted.equals(false) &
            s.archivedAt.isNull(),
      )
      ..orderBy([
        (s) => OrderingTerm(expression: s.statusOrder),
        (s) => OrderingTerm(expression: s.name.lower()),
      ]);
    return q.watch().distinctRows();
  }

  Stream<TaskStatusRow?> watchById({
    required String companyId,
    required String id,
  }) {
    final q = select(taskStatuses)
      ..where((s) => s.companyId.equals(companyId) & s.id.equals(id))
      ..limit(1);
    return q.watchSingleOrNull();
  }

  /// One-shot batch read by id — same purpose as `TaskDao.getByIds`.
  Future<List<TaskStatusRow>> getByIds({
    required String companyId,
    required Iterable<String> ids,
  }) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return Future.value(const <TaskStatusRow>[]);
    final q = select(taskStatuses)
      ..where((s) => s.companyId.equals(companyId) & s.id.isIn(list));
    return q.get();
  }

  Future<void> upsert(TaskStatusesCompanion row) =>
      into(taskStatuses).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<TaskStatusesCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(taskStatuses, rows));
  }

  /// Server-refresh upsert that preserves the user's in-flight edits.
  /// Mirrors [BaseEntityDao.upsertAllPreservingDirty]; used by
  /// `applyBundle` and `ensurePageLoaded` so the user's queued offline
  /// edit isn't clobbered by a stale server payload.
  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, TaskStatusesCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(taskStatuses)
      ..addColumns([taskStatuses.id])
      ..where(
        taskStatuses.companyId.equals(companyId) &
            taskStatuses.id.isIn(candidateIds) &
            taskStatuses.isDirty.equals(true),
      );
    final dirty = {
      for (final r in await dirtyQ.get()) r.read(taskStatuses.id)!,
    };
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      taskStatuses,
    )..where((s) => s.companyId.equals(companyId) & s.id.equals(id))).go();
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
    return (update(taskStatuses)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const TaskStatusesCompanion(isDirty: Value(false)));
  }
}
