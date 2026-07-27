import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/designs_table.dart';
import 'package:admin/domain/entity_state.dart';

part 'design_dao.g.dart';

class DesignFieldIds {
  static const String name = 'name';
  static const String updatedAt = 'updated_at';
  static const String isCustom = 'is_custom';
}

@DriftAccessor(tables: [Designs])
class DesignDao extends DatabaseAccessor<AppDatabase>
    with _$DesignDaoMixin, CompanyScopedDao {
  DesignDao(super.db);

  Stream<List<DesignRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = DesignFieldIds.name,
    bool sortAscending = true,
  }) {
    final q = select(designs)..where((d) => d.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (d) => entityStateFilter(
          states: states,
          archivedAt: d.archivedAt,
          isDeleted: d.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where((d) => d.name.lower().like(needle));
    }

    q.orderBy([
      (d) => OrderingTerm(
        expression: _sortExpression(d, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (d) => OrderingTerm(expression: d.id),
    ]);
    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(Designs d, String field) {
    switch (field) {
      case DesignFieldIds.updatedAt:
        return d.updatedAt;
      case DesignFieldIds.isCustom:
        return d.isCustom;
      case DesignFieldIds.name:
      default:
        return d.name.lower();
    }
  }

  /// Watch every active design for the design pickers. The picker filters by
  /// `entities` client-side because the comma-separated wire format doesn't
  /// fit a SQL `IN` predicate naturally.
  Stream<List<DesignRow>> watchAll({required String companyId}) {
    final q = select(designs)
      ..where(
        (d) =>
            d.companyId.equals(companyId) &
            d.isDeleted.equals(false) &
            d.archivedAt.isNull(),
      )
      ..orderBy([(d) => OrderingTerm(expression: d.name.lower())]);
    return q.watch().distinctRows();
  }

  Stream<DesignRow?> watchById({
    required String companyId,
    required String id,
  }) {
    final q = select(designs)
      ..where((d) => d.companyId.equals(companyId) & d.id.equals(id))
      ..limit(1);
    return q.watchSingleOrNull();
  }

  Future<List<DesignRow>> getByIds({
    required String companyId,
    required Iterable<String> ids,
  }) {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return Future.value(const <DesignRow>[]);
    final q = select(designs)
      ..where((d) => d.companyId.equals(companyId) & d.id.isIn(list));
    return q.get();
  }

  Future<void> upsert(DesignsCompanion row) =>
      into(designs).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<DesignsCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(designs, rows));
  }

  /// Server-refresh upsert that preserves the user's in-flight edits.
  /// Same shape as `TaskStatusDao.upsertAllPreservingDirty`.
  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, DesignsCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(designs)
      ..addColumns([designs.id])
      ..where(
        designs.companyId.equals(companyId) &
            designs.id.isIn(candidateIds) &
            designs.isDirty.equals(true),
      );
    final dirty = {for (final r in await dirtyQ.get()) r.read(designs.id)!};
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      designs,
    )..where((d) => d.companyId.equals(companyId) & d.id.equals(id))).go();
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
    return (update(designs)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const DesignsCompanion(isDirty: Value(false)));
  }
}
