import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/schedules_table.dart';

part 'schedule_dao.g.dart';

class ScheduleFieldIds {
  static const String template = 'template';
  static const String nextRun = 'next_run';
  static const String updatedAt = 'updated_at';
}

@DriftAccessor(tables: [Schedules])
class ScheduleDao extends DatabaseAccessor<AppDatabase>
    with _$ScheduleDaoMixin, CompanyScopedDao {
  ScheduleDao(super.db);

  Stream<List<ScheduleRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Set<String> templates = const <String>{},
    String sortField = ScheduleFieldIds.nextRun,
    bool sortAscending = true,
  }) {
    final q = select(schedules)..where((t) => t.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (t) => entityStateFilter(
          states: states,
          archivedAt: t.archivedAt,
          isDeleted: t.isDeleted,
        ),
      );
    }

    if (templates.isNotEmpty) {
      q.where((t) => t.template.isIn(templates.toList(growable: false)));
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where(
        (t) => t.name.lower().like(needle) | t.template.lower().like(needle),
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

  Expression _sortExpression(Schedules t, String field) {
    switch (field) {
      case ScheduleFieldIds.template:
        return t.template;
      case ScheduleFieldIds.updatedAt:
        return t.updatedAt;
      case ScheduleFieldIds.nextRun:
      default:
        return t.nextRun;
    }
  }

  /// Watch every active schedule for a company, ordered by next_run
  /// ascending (soonest-first). Used by the settings list screen's
  /// default render.
  Stream<List<ScheduleRow>> watchAll({required String companyId}) {
    final q = select(schedules)
      ..where(
        (t) =>
            t.companyId.equals(companyId) &
            t.isDeleted.equals(false) &
            t.archivedAt.isNull(),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.nextRun),
        (t) => OrderingTerm(expression: t.id),
      ]);
    return q.watch().distinctRows();
  }

  Stream<ScheduleRow?> watchById({
    required String companyId,
    required String id,
  }) {
    final q = select(schedules)
      ..where((t) => t.companyId.equals(companyId) & t.id.equals(id))
      ..limit(1);
    return q.watchSingleOrNull();
  }

  Future<List<ScheduleRow>> getByIds({
    required String companyId,
    required Iterable<String> ids,
  }) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return Future.value(const <ScheduleRow>[]);
    final q = select(schedules)
      ..where((t) => t.companyId.equals(companyId) & t.id.isIn(list));
    return q.get();
  }

  Future<void> upsert(SchedulesCompanion row) =>
      into(schedules).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<SchedulesCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(schedules, rows));
  }

  /// Server-refresh upsert that preserves the user's in-flight edits.
  /// Mirrors [PaymentTermDao.upsertAllPreservingDirty].
  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, SchedulesCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(schedules)
      ..addColumns([schedules.id])
      ..where(
        schedules.companyId.equals(companyId) &
            schedules.id.isIn(candidateIds) &
            schedules.isDirty.equals(true),
      );
    final dirty = {for (final r in await dirtyQ.get()) r.read(schedules.id)!};
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      schedules,
    )..where((t) => t.companyId.equals(companyId) & t.id.equals(id))).go();
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
    return (update(schedules)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const SchedulesCompanion(isDirty: Value(false)));
  }
}
