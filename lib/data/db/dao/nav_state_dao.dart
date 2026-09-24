import 'package:drift/drift.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/tables/nav_state_table.dart';

part 'nav_state_dao.g.dart';

@DriftAccessor(tables: [NavState])
class NavStateDao extends DatabaseAccessor<AppDatabase>
    with _$NavStateDaoMixin {
  NavStateDao(super.db);

  Future<NavStateData?> current() =>
      (select(navState)
            ..where((n) => n.id.equals(0))
            ..limit(1))
          .getSingleOrNull();

  /// Watch the single nav_state row. List ViewModels subscribe so that when
  /// a saved view is applied (which writes through [saveFilters]), the
  /// running list re-hydrates from the new blob.
  Stream<NavStateData?> watchCurrent() =>
      (select(navState)..where((n) => n.id.equals(0))).watchSingleOrNull();

  /// Route-only update — used by the router observer on every navigation.
  /// Every write here touches only its own columns: device preferences live
  /// in `device_prefs` (`DevicePrefsStore`), never in this row.
  Future<void> saveRoute({required String route, required int now}) async {
    await into(navState).insertOnConflictUpdate(
      NavStateCompanion.insert(
        id: const Value(0),
        currentRoute: Value(route),
        updatedAt: now,
      ),
    );
  }

  /// Filters-only update — list ViewModels call this whenever their search /
  /// state / sort / custom filters change. Leaves the other fields
  /// (`currentRoute`, `recentEntitiesJson`) untouched.
  Future<void> saveFilters({
    required String filtersJson,
    required int now,
  }) async {
    await into(navState).insertOnConflictUpdate(
      NavStateCompanion.insert(
        id: const Value(0),
        filtersJson: Value(filtersJson),
        updatedAt: now,
      ),
    );
  }

  /// Recently-viewed-only update — [RecentlyViewedController] calls this as
  /// the user opens entity detail screens. Leaves the other fields untouched,
  /// same partial-write pattern as [saveFilters].
  Future<void> saveRecentEntities({
    required String? recentEntitiesJson,
    required int now,
  }) async {
    await into(navState).insertOnConflictUpdate(
      NavStateCompanion.insert(
        id: const Value(0),
        recentEntitiesJson: Value(recentEntitiesJson),
        updatedAt: now,
      ),
    );
  }

  Future<void> clear() => (delete(navState)..where((n) => n.id.equals(0))).go();
}
