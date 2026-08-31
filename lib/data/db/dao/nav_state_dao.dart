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

  Future<void> save({
    required String? currentRoute,
    required String? selectedCompanyId,
    required String? locale,
    required String? themeMode,
    required String? lightVariant,
    required String? darkVariant,
    required String? filtersJson,
    required bool? sidebarCollapsed,
    required int now,
    // Optional with default so the sidebar / locale partial-write callers
    // compile unchanged — only ThemeController persists the custom palette and
    // only TextScaleController persists the text scale.
    String? customThemeJson,
    double? textScale,
  }) => into(navState).insertOnConflictUpdate(
    NavStateCompanion.insert(
      // Single-row table: pin the primary key so insertOnConflictUpdate
      // actually detects the conflict against the prior row.
      id: const Value(0),
      currentRoute: Value(currentRoute),
      selectedCompanyId: Value(selectedCompanyId),
      locale: Value(locale),
      themeMode: Value(themeMode),
      lightVariant: Value(lightVariant),
      darkVariant: Value(darkVariant),
      filtersJson: Value(filtersJson),
      sidebarCollapsed: sidebarCollapsed == null
          ? const Value.absent()
          : Value(sidebarCollapsed),
      customThemeJson: customThemeJson == null
          ? const Value.absent()
          : Value(customThemeJson),
      textScale: textScale == null ? const Value.absent() : Value(textScale),
      updatedAt: now,
    ),
  );

  /// Route-only update — used by the router observer on every navigation.
  /// Cheaper than [save] when only the route changed.
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
  /// (`currentRoute`, `selectedCompanyId`, etc.) untouched.
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

  /// Keyboard-shortcut-overrides-only update — [KeyboardShortcutsController]
  /// calls this when the user rebinds / clears / resets a shortcut. Leaves the
  /// other fields untouched, same partial-write pattern as [saveFilters].
  Future<void> saveKeyboardShortcuts({
    required String? keyboardShortcutsJson,
    required int now,
  }) async {
    await into(navState).insertOnConflictUpdate(
      NavStateCompanion.insert(
        id: const Value(0),
        keyboardShortcutsJson: Value(keyboardShortcutsJson),
        updatedAt: now,
      ),
    );
  }

  /// Sidebar-counter-choices-only update — [SidebarBadgeModeController] calls
  /// this when the user picks a different counter for a sidebar row. Leaves
  /// the other fields untouched, same partial-write pattern as [saveFilters].
  Future<void> saveSidebarBadgeModes({
    required String? sidebarBadgeModesJson,
    required int now,
  }) async {
    await into(navState).insertOnConflictUpdate(
      NavStateCompanion.insert(
        id: const Value(0),
        sidebarBadgeModesJson: Value(sidebarBadgeModesJson),
        updatedAt: now,
      ),
    );
  }

  /// Confirm-actions-only update — [ConfirmActionsController] calls this when
  /// the user flips the "Confirm actions" switch. Leaves the other fields
  /// untouched, same partial-write pattern as [saveFilters].
  Future<void> saveConfirmActions({
    required bool enabled,
    required int now,
  }) async {
    await into(navState).insertOnConflictUpdate(
      NavStateCompanion.insert(
        id: const Value(0),
        confirmActions: Value(enabled),
        updatedAt: now,
      ),
    );
  }

  /// Status-tabs-only update — [StatusTabsController] calls this when the user
  /// flips the switch. Same partial-write pattern as [saveConfirmActions].
  Future<void> saveStatusTabs({required bool enabled, required int now}) async {
    await into(navState).insertOnConflictUpdate(
      NavStateCompanion.insert(
        id: const Value(0),
        statusTabs: Value(enabled),
        updatedAt: now,
      ),
    );
  }

  /// Contacts-sync-only update — [ContactsSyncController] calls this when the
  /// user flips the toggle, changes scope, or a reconcile finishes. Leaves the
  /// other fields untouched, same partial-write pattern as [saveFilters].
  ///
  /// Pass `null` for [json] to clear the preference entirely (the feature has
  /// never been used, or the last company's state was removed).
  Future<void> saveContactsSync({
    required String? json,
    required int now,
  }) async {
    await into(navState).insertOnConflictUpdate(
      NavStateCompanion.insert(
        id: const Value(0),
        contactsSyncJson: Value(json),
        updatedAt: now,
      ),
    );
  }

  Future<void> clear() => (delete(navState)..where((n) => n.id.equals(0))).go();
}
