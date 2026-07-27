import 'package:drift/drift.dart';

import 'package:admin/data/db/dao/_distinct_stream.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/dao/entity_query_helpers.dart';
import 'package:admin/data/db/tables/company_gateways_table.dart';

part 'company_gateway_dao.g.dart';

/// Stable field-id constants used by the list ViewModel for sort selection.
/// Keep in sync with `CompanyGatewayRepository.watchPage`.
class CompanyGatewayFieldIds {
  static const String label = 'label';
  static const String gatewayKey = 'gateway_key';
  static const String state = 'state';
  static const String updatedAt = 'updated_at';
  static const String createdAt = 'created_at';
}

@DriftAccessor(tables: [CompanyGateways])
class CompanyGatewayDao extends DatabaseAccessor<AppDatabase>
    with _$CompanyGatewayDaoMixin, CompanyScopedDao {
  CompanyGatewayDao(super.db);

  /// Watch a windowed slice of company gateways. Filters: state (active /
  /// archived / deleted), free-text search across `label`.
  Stream<List<CompanyGatewayRow>> watchPage({
    required String companyId,
    required int offset,
    required int limit,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    String sortField = CompanyGatewayFieldIds.updatedAt,
    bool sortAscending = false,
  }) {
    final q = select(companyGateways)
      ..where((g) => g.companyId.equals(companyId));

    if (states.isNotEmpty) {
      q.where(
        (g) => entityStateFilter(
          states: states,
          archivedAt: g.archivedAt,
          isDeleted: g.isDeleted,
        ),
      );
    }

    if (search != null && search.isNotEmpty) {
      final needle = '%${search.toLowerCase()}%';
      q.where((g) => g.label.lower().like(needle));
    }

    q.orderBy([
      (g) => OrderingTerm(
        expression: _sortExpression(g, sortField),
        mode: sortAscending ? OrderingMode.asc : OrderingMode.desc,
      ),
      (g) => OrderingTerm(expression: g.id),
    ]);

    q.limit(limit, offset: offset);
    return q.watch().distinctRows();
  }

  Expression _sortExpression(CompanyGateways g, String field) {
    switch (field) {
      case CompanyGatewayFieldIds.label:
        return g.label.lower();
      case CompanyGatewayFieldIds.gatewayKey:
        return g.gatewayKey;
      case CompanyGatewayFieldIds.createdAt:
        return g.createdAt;
      case CompanyGatewayFieldIds.updatedAt:
      default:
        return g.updatedAt;
    }
  }

  Stream<List<CompanyGatewayRow>> watchAll({required String companyId}) {
    return (select(
      companyGateways,
    )..where((g) => g.companyId.equals(companyId))).watch().distinctRows();
  }

  Stream<CompanyGatewayRow?> watchById({
    required String companyId,
    required String id,
  }) {
    return (select(companyGateways)
          ..where((g) => g.companyId.equals(companyId) & g.id.equals(id))
          ..limit(1))
        .watchSingleOrNull();
  }

  Future<void> upsert(CompanyGatewaysCompanion row) =>
      into(companyGateways).insertOnConflictUpdate(row);

  Future<void> upsertAll(List<CompanyGatewaysCompanion> rows) async {
    if (rows.isEmpty) return;
    await batch((b) => b.insertAllOnConflictUpdate(companyGateways, rows));
  }

  /// Server-refresh upsert that preserves the user's in-flight edits.
  /// Mirrors [BaseEntityDao.upsertAllPreservingDirty]; used by
  /// `applyBundle` and `ensurePageLoaded` so the user's queued offline
  /// edit isn't clobbered by a stale server payload.
  Future<void> upsertAllPreservingDirty({
    required String companyId,
    required Map<String, CompanyGatewaysCompanion> byId,
  }) async {
    if (byId.isEmpty) return;
    final candidateIds = byId.keys.toList(growable: false);
    final dirtyQ = selectOnly(companyGateways)
      ..addColumns([companyGateways.id])
      ..where(
        companyGateways.companyId.equals(companyId) &
            companyGateways.id.isIn(candidateIds) &
            companyGateways.isDirty.equals(true),
      );
    final dirty = {
      for (final r in await dirtyQ.get()) r.read(companyGateways.id)!,
    };
    final filtered = [
      for (final entry in byId.entries)
        if (!dirty.contains(entry.key)) entry.value,
    ];
    await upsertAll(filtered);
  }

  Future<int> deleteById({required String companyId, required String id}) {
    return (delete(
      companyGateways,
    )..where((g) => g.companyId.equals(companyId) & g.id.equals(id))).go();
  }

  /// Total count for the sidebar badge. Active rows only.
  Stream<int> watchActiveCount({required String companyId}) {
    final q = selectOnly(companyGateways)
      ..addColumns([companyGateways.id.count()])
      ..where(
        companyGateways.companyId.equals(companyId) &
            companyGateways.isDeleted.equals(false) &
            companyGateways.archivedAt.isNull(),
      );
    return q
        .map((row) => row.read(companyGateways.id.count()) ?? 0)
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
    return (update(companyGateways)
          ..where((t) => t.companyId.equals(companyId) & t.id.equals(id)))
        .write(const CompanyGatewaysCompanion(isDirty: Value(false)));
  }
}
