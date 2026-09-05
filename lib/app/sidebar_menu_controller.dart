import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/sidebar_menu.dart';

final _log = Logger('SidebarMenuController');

/// Owns the main menu's layout, order and per-row visibility — read by
/// `InSidebar` (rail and mobile drawer alike) and by the Menu card in Device
/// Settings, written by that card and its Customize sheet
/// (invoiceninja/flutter#125).
///
/// Device-local persistence to `nav_state.sidebar_menu_json`, same pattern as
/// [SidebarBadgeModeController]. **Not preserved across a deliberate logout**:
/// `logout()` wipes every Drift table, `nav_state` included, and nothing
/// re-seeds the row — and [resetInMemory] joins the `onBeforeLogout` fan-out so
/// that is true *immediately*, not merely after the next app launch. Without
/// it a second user signing in on the same install inherits the first one's
/// order and hidden rows, and the first control they touch persists that array
/// into their own fresh row. An involuntary 401 preserves local data, so it
/// keeps the menu.
///
/// Nothing is stored until the user changes something, so a destination added
/// in a later release needs no backfill — [resolveMenuEntries] splices it in at
/// its default position. [db] is optional so unit tests can exercise the
/// resolution logic without a database.
class SidebarMenuController extends ChangeNotifier {
  SidebarMenuController({AppDatabase? db, DateTime Function()? now})
    : _db = db,
      _now = now ?? DateTime.now;

  final AppDatabase? _db;
  final DateTime Function() _now;

  SidebarMenuLayout _layout = SidebarMenuLayout.list;

  /// The user's stored order + visibility, or empty when they've never
  /// customised the menu. Deliberately raw: it can name a destination this
  /// company can't render (a module that's off), and dropping those here rather
  /// than at render time would destroy the position the user chose for them.
  List<SidebarMenuEntryPref> _entries = const [];

  SidebarMenuLayout get layout => _layout;

  /// True when the user has reordered or hidden something — drives whether
  /// "Reset to defaults" has anything to do. Layout is deliberately excluded:
  /// it has its own always-visible control.
  bool get hasCustomEntries => _entries.isNotEmpty;

  /// The menu to render: [defaultOrder] permuted by the stored preference, with
  /// every id in [defaultOrder] present exactly once.
  ///
  /// The caller decides what [defaultOrder] holds, and the two callers differ
  /// on purpose — see [resolveMenuEntries] and [setEntries].
  List<SidebarMenuEntryPref> entriesFor(List<String> defaultOrder) =>
      resolveMenuEntries(defaultOrder: defaultOrder, stored: _entries);

  Future<void> setLayout(SidebarMenuLayout layout) async {
    if (_layout == layout) return;
    _layout = layout;
    notifyListeners();
    await _persist();
  }

  /// Replace the stored order + visibility.
  ///
  /// **One caller: the Customize sheet**, which resolves against *every*
  /// destination. Calling this with a list resolved from the sidebar's own
  /// (module-filtered) order would silently drop the stored position of every
  /// entity whose module is currently off.
  Future<void> setEntries(List<SidebarMenuEntryPref> entries) async {
    if (listEquals(_entries, entries)) return;
    _entries = List.unmodifiable(entries);
    notifyListeners();
    await _persist();
  }

  /// Put the menu back on the app's own order with everything shown. Leaves
  /// [layout] alone — that control is right there beside it and resetting it
  /// from under the user would read as a bug.
  Future<void> resetEntries() async {
    if (_entries.isEmpty) return;
    _entries = const [];
    notifyListeners();
    await _persist();
  }

  /// Drop the in-memory preference without writing anything.
  ///
  /// For the logout fan-out only, which runs *before* the Drift wipe — so
  /// persisting here would write a row that is about to be deleted. Notifies,
  /// because the sidebar is still mounted behind the sign-out.
  void resetInMemory() {
    if (_layout == SidebarMenuLayout.list && _entries.isEmpty) return;
    _layout = SidebarMenuLayout.list;
    _entries = const [];
    notifyListeners();
  }

  /// Load the persisted preference from the `nav_state` row. No-op without a
  /// [db].
  Future<void> restore() async {
    final db = _db;
    if (db == null) return;
    final row = await db.navStateDao.current();
    restoreFromJson(row?.sidebarMenuJson);
  }

  /// Parse a stored blob into memory. Anything unrecognizable is dropped rather
  /// than thrown: an unknown layout name, a truncated entry, or a whole corrupt
  /// blob leaves the menu on its default instead of breaking boot. Does not
  /// notify — called once at boot before the UI builds.
  @visibleForTesting
  void restoreFromJson(String? jsonStr) {
    _layout = SidebarMenuLayout.list;
    _entries = const [];
    if (jsonStr == null || jsonStr.isEmpty) return;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return;
      _layout = sidebarMenuLayoutFromName(decoded['layout']);
      final raw = decoded['entries'];
      if (raw is! List) return;
      final parsed = <SidebarMenuEntryPref>[];
      final seen = <String>{};
      for (final entry in raw) {
        final pref = SidebarMenuEntryPref.tryParse(entry);
        if (pref == null) continue;
        if (!seen.add(pref.id)) continue;
        parsed.add(pref);
      }
      _entries = List.unmodifiable(parsed);
    } catch (e, st) {
      _log.warning('Failed to parse the sidebar menu preference', e, st);
    }
  }

  /// Serialize the current preference.
  @visibleForTesting
  Map<String, Object?> toJson() => <String, Object?>{
    'layout': _layout.name,
    'entries': [for (final e in _entries) e.toJson()],
  };

  Future<void> _persist() async {
    final db = _db;
    if (db == null) return;
    try {
      // Nothing customised at all writes null rather than an empty envelope, so
      // Reset genuinely returns the row to its never-touched state.
      final isDefault = _layout == SidebarMenuLayout.list && _entries.isEmpty;
      await db.navStateDao.saveSidebarMenu(
        json: isDefault ? null : jsonEncode(toJson()),
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      // A failed write keeps the in-memory choice for this session — same
      // trade-off as theme / text-scale persistence.
      _log.warning('Failed to persist the sidebar menu preference', e, st);
    }
  }
}
