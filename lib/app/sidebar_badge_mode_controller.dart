import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';

final _log = Logger('SidebarBadgeModeController');

/// Owns what each sidebar row's count badge counts — "Overdue" on Invoices,
/// "Low stock" on Products, and so on. Read by the rail and by the Sidebar
/// counters card in Device Settings; written by the row's right-click menu and
/// that card's dropdowns.
///
/// Device-local, one JSON blob (`DevicePrefKeys.sidebarBadgeModes`) — an
/// account preference, so a sign-out forgets it: the counters describe the
/// signed-in account's modules.
///
/// Only non-default choices are stored, so a mode added in a later release
/// needs no backfill. [prefs] is optional so unit tests can exercise the
/// resolution logic without a store.
class SidebarBadgeModeController extends ChangeNotifier {
  SidebarBadgeModeController({DevicePrefsStore? prefs}) : _prefs = prefs {
    if (prefs == null) return;
    restoreFromJson(prefs.read(DevicePrefKeys.sidebarBadgeModes));
    prefs.addListener(_sync);
  }

  final DevicePrefsStore? _prefs;

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

  /// Follow the store: the boot load, or a data wipe forgetting the choices.
  void _sync() {
    final before = modesToJson();
    restoreFromJson(_prefs?.read(DevicePrefKeys.sidebarBadgeModes));
    if (!mapEquals(before, _modes)) notifyListeners();
  }

  /// Parse a stored blob into memory. Anything unrecognizable is dropped
  /// rather than thrown: an unknown entity name (a module that went away) or
  /// an unknown mode id (one renamed between releases) leaves that row on its
  /// default instead of breaking boot. Does not notify.
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
    await _prefs?.write(
      DevicePrefKeys.sidebarBadgeModes,
      jsonEncode(modesToJson()),
    );
  }

  @override
  void dispose() {
    _prefs?.removeListener(_sync);
    super.dispose();
  }
}
