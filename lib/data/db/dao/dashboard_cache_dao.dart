import 'package:drift/drift.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/company_scoped_dao.dart';
import 'package:admin/data/db/tables/dashboard_cache_table.dart';

part 'dashboard_cache_dao.g.dart';

/// Sentinel used as `filter_hash` for kinds that aren't filter-keyed (list
/// cards). Anything filter-keyed (`totals_*`, `chart`) passes a real hash.
const String kDashboardListFilterHash = '_';

@DriftAccessor(tables: [DashboardCache])
class DashboardCacheDao extends DatabaseAccessor<AppDatabase>
    with _$DashboardCacheDaoMixin, CompanyScopedDao {
  DashboardCacheDao(super.db);

  /// Watch one cache row by composite key. Emits `null` until the first
  /// successful refresh writes a payload for this `(company, kind, hash)`.
  Stream<DashboardCacheRow?> watch({
    required String companyId,
    required String kind,
    required String filterHash,
  }) {
    final q = select(dashboardCache)
      ..where(
        (c) =>
            c.companyId.equals(companyId) &
            c.kind.equals(kind) &
            c.filterHash.equals(filterHash),
      )
      ..limit(1);
    return q.watchSingleOrNull();
  }

  Future<DashboardCacheRow?> read({
    required String companyId,
    required String kind,
    required String filterHash,
  }) {
    final q = select(dashboardCache)
      ..where(
        (c) =>
            c.companyId.equals(companyId) &
            c.kind.equals(kind) &
            c.filterHash.equals(filterHash),
      )
      ..limit(1);
    return q.getSingleOrNull();
  }

  Future<void> upsert({
    required String companyId,
    required String kind,
    required String filterHash,
    required String payload,
    required int fetchedAt,
  }) => into(dashboardCache).insertOnConflictUpdate(
    DashboardCacheCompanion.insert(
      companyId: companyId,
      kind: kind,
      filterHash: filterHash,
      payload: payload,
      fetchedAt: fetchedAt,
    ),
  );

  Future<int> deleteForCompany(String companyId) => (delete(
    dashboardCache,
  )..where((c) => c.companyId.equals(companyId))).go();

  /// The `filter_hash` of every row of one `kind`, most recently fetched
  /// first. For a kind that keeps a bounded history rather than one row per
  /// fixed key.
  Future<List<String>> hashesNewestFirst({
    required String companyId,
    required String kind,
  }) async {
    final q = selectOnly(dashboardCache)
      ..addColumns([dashboardCache.filterHash])
      ..where(
        dashboardCache.companyId.equals(companyId) &
            dashboardCache.kind.equals(kind),
      )
      ..orderBy([OrderingTerm.desc(dashboardCache.fetchedAt)]);
    final rows = await q.get();
    return [for (final row in rows) row.read(dashboardCache.filterHash)!];
  }

  /// Delete the rows of one `kind` whose `filter_hash` is in [hashes].
  Future<int> deleteHashes({
    required String companyId,
    required String kind,
    required Iterable<String> hashes,
  }) {
    final list = hashes.toList();
    if (list.isEmpty) return Future.value(0);
    return (delete(dashboardCache)..where(
          (c) =>
              c.companyId.equals(companyId) &
              c.kind.equals(kind) &
              c.filterHash.isIn(list),
        ))
        .go();
  }

  /// Delete every cached row for one `kind` (all filter-hashes). Called when
  /// a configured dashboard card is removed/reconfigured so its per-card
  /// rows don't accumulate across every date-range/currency combination.
  Future<int> deleteKind({required String companyId, required String kind}) =>
      (delete(dashboardCache)
            ..where((c) => c.companyId.equals(companyId) & c.kind.equals(kind)))
          .go();
}
