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

  /// Device-local "show the status tab strip above lists" preference (Settings
  /// → Device Settings). The strip turns each entity's sidebar-counter buckets
  /// into one-tap filters with live counts — see `lib/domain/list_status_tabs.dart`
  /// and invoiceninja/flutter#98, which asked for exactly this because reaching
  /// a draft through the search field's filter menu costs three or four taps.
  ///
  /// Defaults to **on**: the issue's premise is that fewer taps should be the
  /// default, and the switch exists for people who would rather have the
  /// vertical space back. Added in schema v6.
  BoolColumn get statusTabs =>
      boolean().named('status_tabs').withDefault(const Constant(true))();

  /// Device-local contacts-sync preference (Settings → Device Settings →
  /// Contacts), as a JSON object:
  /// `{"enabled":bool,"scope":"all"|"mine",
  ///   "lastRun":{"&lt;companyId&gt;":1750000000000},
  ///   "groupIds":{"&lt;companyId&gt;":"12"}}`.
  /// Null column = the feature has never been switched on. One blob rather than
  /// four columns, same reasoning as [filtersJson] — both per-company maps are
  /// open-ended and none of it is ever queried by SQL. `groupIds` is the
  /// ownership record: the device address-book label is keyed on the company
  /// id, not its name, so two identically-named companies can't reconcile away
  /// each other's cards (see `docs/contacts-sync.md`). Added in schema v5.
  TextColumn get contactsSyncJson =>
      text().named('contacts_sync_json').nullable()();

  /// Device-local tap-to-call preference (Settings → Device Settings → Phone
  /// numbers), as a JSON object:
  /// `{"tapToCall":bool,"confirmBeforeCall":bool,
  ///   "warnOutsideBusinessHours":bool,"startMinutes":480,"endMinutes":1200}`.
  /// Null column = the user has never opened the card, and the defaults are
  /// then resolved *per device* (`PhoneActionsSettings.deviceDefaults()` reads
  /// `Env.isTouchPrimary`) — which is the reason this is a blob and not five
  /// columns: a SQL `withDefault` would have to pick one answer for a phone
  /// and a Linux desktop alike. Same one-blob reasoning as [contactsSyncJson]
  /// otherwise; none of it is ever queried by SQL. Added in schema v7.
  /// See `docs/tap-to-call.md`.
  TextColumn get phoneActionsJson =>
      text().named('phone_actions_json').nullable()();

  /// Device-local main-menu preference (Settings → Device Settings → Menu), as
  /// a JSON object:
  /// `{"layout":"list"|"grid","entries":["&lt;id&gt;|&lt;1|0&gt;", …]}`.
  /// Null column = never customised, i.e. the list layout in the app's own
  /// order with everything shown. Added in schema v8 for
  /// invoiceninja/flutter#125.
  ///
  /// One blob rather than a bool plus a table, for the same reason as
  /// [contactsSyncJson]: the array is open-ended, none of it is ever queried by
  /// SQL, and the two halves are one card in Settings. Unlike [statusTabs] a
  /// SQL `withDefault` could not express the interesting part of it at all —
  /// the default *order* is computed from the entity registry at runtime, so
  /// there is no literal to put in the column.
  ///
  /// Entries are stored sparsely in the sense that matters: the column stays
  /// null until the user changes something, and `resolveMenuEntries` splices in
  /// any destination a later release adds. See `lib/domain/sidebar_menu.dart`.
  TextColumn get sidebarMenuJson =>
      text().named('sidebar_menu_json').nullable()();

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
