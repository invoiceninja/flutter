import 'package:drift/drift.dart';

/// Single-row table that persists "where the user was" so app restart lands
/// them right back where they left off.
///
/// `filtersJson` is keyed by entity type — each entity's list VM serializes
/// its filter/sort/search state into the same blob to keep the schema small.
class NavState extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get currentRoute => text().named('current_route').nullable()();
  TextColumn get selectedCompanyId =>
      text().named('selected_company_id').nullable()();
  TextColumn get locale => text().nullable()();
  TextColumn get themeMode => text().named('theme_mode').nullable()();
  TextColumn get lightVariant => text().named('light_variant').nullable()();
  TextColumn get darkVariant => text().named('dark_variant').nullable()();
  TextColumn get customThemeJson =>
      text().named('custom_theme_json').nullable()();

  /// Device-local UI text-scale factor (Small 0.8 / Normal 1.0 / Large 1.2 /
  /// Extra Large 1.4). Null = follow the default (1.0). Applied app-wide via a
  /// `MediaQuery` `textScaler` override in `main.dart`.
  RealColumn get textScale => real().named('text_scale').nullable()();

  TextColumn get filtersJson => text().named('filters_json').nullable()();

  /// Device-local keyboard-shortcut overrides (Settings → Keyboard Shortcuts),
  /// as a JSON object keyed by catalog action id (value = binding JSON, or
  /// `null` for an explicitly-cleared shortcut). Null column = no overrides
  /// (everything at its catalog default). Only overrides are stored, never the
  /// full resolved set. Added in schema v2.
  TextColumn get keyboardShortcutsJson =>
      text().named('keyboard_shortcuts_json').nullable()();

  /// Device-local sidebar counter choices (Settings → Device Settings →
  /// Sidebar counters, or a right-click on the row), as a JSON object keyed by
  /// `EntityType.name` → `SidebarBadgeMode.id`. Null column = every row on its
  /// default (`total`). Only non-default choices are stored, so a mode added
  /// later doesn't need a backfill. Added in schema v3.
  TextColumn get sidebarBadgeModesJson =>
      text().named('sidebar_badge_modes_json').nullable()();

  /// Device-local "prompt before running a risky action" preference (Settings
  /// → Device Settings → Security). When true, outward-facing / irreversible
  /// actions (Approve, Mark Sent, Cancel, Archive, Delete, …) open an "Are you
  /// sure?" dialog first. Defaults to **on** — see invoiceninja/flutter#49,
  /// where users reported fat-fingering Approve / Archive on a phone in the
  /// field. Added in schema v4.
  BoolColumn get confirmActions =>
      boolean().named('confirm_actions').withDefault(const Constant(true))();

  /// JSON array of the most-recently-viewed entity records for the active
  /// company (newest first, capped). Surfaced as the command palette's
  /// "Recent" group. Company-scoped: cleared on company switch / logout,
  /// same as the in-memory [NavHistoryController] history.
  TextColumn get recentEntitiesJson =>
      text().named('recent_entities_json').nullable()();
  BoolColumn get sidebarCollapsed =>
      boolean().named('sidebar_collapsed').withDefault(const Constant(false))();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {id};
}
