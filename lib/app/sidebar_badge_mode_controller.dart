import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('SidebarBadgeModeController');

/// Owns what each sidebar row's count badge counts — "Overdue" on Invoices,
/// "Low stock" on Products, and so on. Read by the rail and by the Sidebar
/// counters card in Device Settings; written by the row's right-click menu and
/// that card's dropdowns.
///
/// Device-local persistence to `nav_state.sidebar_badge_modes_json`, same
/// pattern as [KeyboardShortcutsController] / [ThemeController] — and, like
/// them, **not preserved across logout**: `logout()` wipes every Drift table,
/// `nav_state` included, and nothing re-seeds the row.
///
/// Only non-default choices are stored, so a mode added in a later release
/// needs no backfill. [db] is optional so unit tests can exercise the
/// resolution logic without a database.
class SidebarBadgeModeController extends ChangeNotifier {
  SidebarBadgeModeController({AppDatabase? db, DateTime Function()? now})
    : _db = db,
      _now = now ?? DateTime.now;

  final AppDatabase? _db;
  final DateTime Function() _now;

  /// `EntityType.name` → chosen [SidebarBadgeMode.id]. An absent key means the
  /// row is on [kBadgeModeTotal].
  final Map<String, String> _modes = {};

  /// The chosen mode id for [type], or [kBadgeModeTotal] when the user hasn't
  /// picked one.
  ///
  /// Pass [available] (the entity's [EntityHandlers.badgeModes], already
  /// filtered for the live company) to have a mode that is no longer offered —
  /// a stale id, or a stock mode after inventory tracking was switched off —
  /// fall back to `total` rather than silently counting nothing.
  String modeFor(EntityType type, {List<SidebarBadgeMode>? available}) {
    final stored = _modes[type.name] ?? kBadgeModeTotal;
    if (available == null) return stored;
    final offered = available.any((m) => m.id == stored);
    return offered ? stored : kBadgeModeTotal;
  }

  /// True when the user has picked something other than the default for
  /// [type] — drives whether "Reset" has anything to do.
  bool get hasOverrides => _modes.isNotEmpty;

  Future<void> set(EntityType type, String modeId) async {
    final current = _modes[type.name] ?? kBadgeModeTotal;
    if (current == modeId) return;
    if (modeId == kBadgeModeTotal) {
      _modes.remove(type.name);
    } else {
      _modes[type.name] = modeId;
    }
    notifyListeners();
    await _persist();
  }

  /// Put every row back on [kBadgeModeTotal].
  Future<void> resetAll() async {
    if (_modes.isEmpty) return;
    _modes.clear();
    notifyListeners();
    await _persist();
  }

  /// Load persisted choices from the `nav_state` row. No-op without a [db].
  Future<void> restore() async {
    final db = _db;
    if (db == null) return;
    final row = await db.navStateDao.current();
    restoreFromJson(row?.sidebarBadgeModesJson);
  }

  /// Parse a stored blob into memory. Anything unrecognizable is dropped
  /// rather than thrown: an unknown entity name (a module that went away) or
  /// an unknown mode id (one renamed between releases) leaves that row on its
  /// default instead of breaking boot. Does not notify — called once at boot
  /// before the UI builds.
  @visibleForTesting
  void restoreFromJson(String? jsonStr) {
    _modes.clear();
    if (jsonStr == null || jsonStr.isEmpty) return;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return;
      final knownTypes = {for (final t in EntityType.values) t.name};
      decoded.forEach((key, value) {
        if (key is! String || value is! String) return;
        if (!knownTypes.contains(key)) return;
        if (!kSidebarBadgeModeIds.contains(value)) return;
        if (value == kBadgeModeTotal) return;
        _modes[key] = value;
      });
    } catch (e, st) {
      _log.warning('Failed to parse sidebar badge modes', e, st);
    }
  }

  /// Serialize the current non-default choices.
  @visibleForTesting
  Map<String, String> modesToJson() => Map<String, String>.from(_modes);

  Future<void> _persist() async {
    final db = _db;
    if (db == null) return;
    try {
      await db.navStateDao.saveSidebarBadgeModes(
        sidebarBadgeModesJson: jsonEncode(modesToJson()),
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      // A failed write keeps the in-memory choice for this session — same
      // trade-off as theme / text-scale persistence.
      _log.warning('Failed to persist sidebar badge modes', e, st);
    }
  }
}
