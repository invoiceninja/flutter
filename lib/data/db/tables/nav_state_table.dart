import 'package:drift/drift.dart';

/// Single-row table that persists "where the user was" so app restart lands
/// them right back where they left off: the route, each list's filters, the
/// recently viewed records.
///
/// `filtersJson` is keyed by entity type — each entity's list VM serializes
/// its filter/sort/search state into the same blob to keep the schema small.
///
/// **Not for device preferences.** Through schema v11 every preference was a
/// column here, and every one of them cost a schema bump; v12 moved them to
/// `device_prefs` (`DevicePrefKeys`), where a new one needs no migration. The
/// seventeen columns marked *legacy* below stay declared so a build rolled
/// back past v12 can still open the store, but nothing reads or writes them —
/// and this table's column list is frozen
/// (`test/lint/nav_state_columns_frozen_test.dart`).
class NavState extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get currentRoute => text().named('current_route').nullable()();

  /// Unused — the active company lives in the auth session.
  TextColumn get selectedCompanyId =>
      text().named('selected_company_id').nullable()();

  /// Legacy (≤ v11) — `DevicePrefKeys.locale`.
  TextColumn get locale => text().nullable()();

  /// Legacy (≤ v11) — `DevicePrefKeys.themeMode`.
  TextColumn get themeMode => text().named('theme_mode').nullable()();

  /// Legacy (≤ v11) — `DevicePrefKeys.lightVariant`.
  TextColumn get lightVariant => text().named('light_variant').nullable()();

  /// Legacy (≤ v11) — `DevicePrefKeys.darkVariant`.
  TextColumn get darkVariant => text().named('dark_variant').nullable()();

  /// Legacy (≤ v11) — `DevicePrefKeys.customTheme`.
  TextColumn get customThemeJson =>
      text().named('custom_theme_json').nullable()();

  /// Legacy (≤ v11) — `DevicePrefKeys.textScale`.
  RealColumn get textScale => real().named('text_scale').nullable()();

  TextColumn get filtersJson => text().named('filters_json').nullable()();

  /// Legacy (v2 – v11) — `DevicePrefKeys.keyboardShortcuts`.
  TextColumn get keyboardShortcutsJson =>
      text().named('keyboard_shortcuts_json').nullable()();

  /// Legacy (v3 – v11) — `DevicePrefKeys.sidebarBadgeModes`.
  TextColumn get sidebarBadgeModesJson =>
      text().named('sidebar_badge_modes_json').nullable()();

  /// Legacy (v4 – v11) — `DevicePrefKeys.confirmActions`.
  BoolColumn get confirmActions =>
      boolean().named('confirm_actions').withDefault(const Constant(true))();

  /// Legacy (v6 – v11) — `DevicePrefKeys.statusTabs`.
  BoolColumn get statusTabs =>
      boolean().named('status_tabs').withDefault(const Constant(true))();

  /// Legacy (v5 – v11) — `DevicePrefKeys.contactsSync`.
  TextColumn get contactsSyncJson =>
      text().named('contacts_sync_json').nullable()();

  /// Legacy (v7 – v11) — `DevicePrefKeys.phoneActions`.
  TextColumn get phoneActionsJson =>
      text().named('phone_actions_json').nullable()();

  /// Legacy (v8 – v11) — `DevicePrefKeys.sidebarMenu`.
  TextColumn get sidebarMenuJson =>
      text().named('sidebar_menu_json').nullable()();

  /// Legacy (v9 – v11) — `DevicePrefKeys.tasksView`.
  TextColumn get tasksView => text().named('tasks_view').nullable()();

  /// Legacy (v10 – v11) — `DevicePrefKeys.hideUnverifiedUsers`.
  BoolColumn get hideUnverifiedUsers => boolean()
      .named('hide_unverified_users')
      .withDefault(const Constant(false))();

  /// Legacy (v11) — `DevicePrefKeys.hideEmptyPanels`.
  BoolColumn get hideEmptyPanels =>
      boolean().named('hide_empty_panels').nullable()();

  /// JSON array of the most-recently-viewed entity records for the active
  /// company (newest first, capped). Surfaced as the command palette's
  /// "Recent" group. Company-scoped: cleared on company switch / logout,
  /// same as the in-memory [NavHistoryController] history.
  TextColumn get recentEntitiesJson =>
      text().named('recent_entities_json').nullable()();

  /// Legacy (≤ v11) — `DevicePrefKeys.sidebarCollapsed`.
  BoolColumn get sidebarCollapsed =>
      boolean().named('sidebar_collapsed').withDefault(const Constant(false))();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
