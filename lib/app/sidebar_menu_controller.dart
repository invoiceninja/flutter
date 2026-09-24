import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/sidebar_menu.dart';

final _log = Logger('SidebarMenuController');

/// Owns the main menu's layout, order and per-row visibility — read by
/// `InSidebar` (rail and mobile drawer alike) and by the Menu card in Device
/// Settings, written by that card and its Customize sheet
/// (invoiceninja/flutter#125).
///
/// Device-local, one JSON blob (`DevicePrefKeys.sidebarMenu`) — an account
/// preference, so a deliberate sign-out forgets it, in memory as well as on
/// disk, the moment the data is wiped: without that a second user signing in
/// on the same install inherits the first one's order and hidden rows, and the
/// first control they touch persists that array as their own. An involuntary
/// 401 or an idle re-lock keeps local data, and the menu with it; resetting on
/// those paths (it once did) showed the same user the default menu and let
/// their next edit save it over their real order.
///
/// Nothing is stored until the user changes something, so a destination added
/// in a later release needs no backfill — [resolveMenuEntries] splices it in at
/// its default position. [prefs] is optional so unit tests can exercise the
/// resolution logic without a store.
class SidebarMenuController extends ChangeNotifier {
  SidebarMenuController({DevicePrefsStore? prefs}) : _prefs = prefs {
    if (prefs == null) return;
    restoreFromJson(prefs.read(DevicePrefKeys.sidebarMenu));
    prefs.addListener(_sync);
  }

  final DevicePrefsStore? _prefs;

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

  /// Follow the store: the boot load, or a data wipe forgetting the menu.
  /// Notifies on a change, because the sidebar is still mounted behind a
  /// sign-out.
  void _sync() {
    final layout = _layout;
    final entries = _entries;
    restoreFromJson(_prefs?.read(DevicePrefKeys.sidebarMenu));
    if (layout != _layout || !listEquals(entries, _entries)) {
      notifyListeners();
    }
  }

  /// Parse a stored blob into memory. Anything unrecognizable is dropped rather
  /// than thrown: an unknown layout name, a truncated entry, or a whole corrupt
  /// blob leaves the menu on its default instead of breaking boot. Does not
  /// notify.
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
    // Nothing customised at all removes the row rather than storing an empty
    // envelope, so Reset genuinely returns it to its never-touched state.
    final isDefault = _layout == SidebarMenuLayout.list && _entries.isEmpty;
    await _prefs?.write(
      DevicePrefKeys.sidebarMenu,
      isDefault ? null : jsonEncode(toJson()),
    );
  }

  @override
  void dispose() {
    _prefs?.removeListener(_sync);
    super.dispose();
  }
}
