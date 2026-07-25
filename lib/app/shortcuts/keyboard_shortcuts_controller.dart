import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Intent, ShortcutActivator;
import 'package:logging/logging.dart';

import 'package:admin/app/shortcuts/key_binding.dart';
import 'package:admin/app/shortcuts/shortcut_catalog.dart';
import 'package:admin/data/db/app_database.dart';

final _log = Logger('KeyboardShortcutsController');

/// Owns the user's keyboard-shortcut overrides and resolves the effective
/// binding for every catalog action (override → catalog default). The single
/// source of truth feeding the real key handling (`activatorsFor`), the
/// hold-modifier hint bar, and the `?` help dialog.
///
/// Three-state per action: **default** (no override), **custom** (an override
/// binding), **cleared** (an explicit `null` override that removes even the
/// default). Device-local persistence to `nav_state.keyboard_shortcuts_json`,
/// same pattern as [TextScaleController] / [ThemeController]; [db] is optional
/// so unit tests exercise the pure resolution logic without a database.
class KeyboardShortcutsController extends ChangeNotifier {
  KeyboardShortcutsController({AppDatabase? db, DateTime Function()? now})
    : _db = db,
      _now = now ?? DateTime.now;

  final AppDatabase? _db;
  final DateTime Function() _now;

  /// action id → override. A present key means "overridden"; its value may be a
  /// [KeyBinding] (custom) or `null` (explicitly cleared). Absent key = use the
  /// catalog default.
  final Map<String, KeyBinding?> _overrides = {};

  /// True when the user has set an explicit override (custom or cleared) for
  /// [id] — drives the "Reset" affordance in the settings row.
  bool isOverridden(String id) => _overrides.containsKey(id);

  /// The effective binding for [id]: the override if present (may be null =
  /// cleared), else the catalog default (may be null = ships unbound).
  KeyBinding? resolvedBinding(String id) {
    if (_overrides.containsKey(id)) return _overrides[id];
    return kShortcutCatalogById[id]?.defaultBinding;
  }

  /// Build the live `{activator: intent}` map for [scope]. [intents] maps action
  /// id → the [Intent] the consumer (the shell) wants fired; an action with no
  /// entry in [intents], or no resolved binding, is skipped. A primary-modified
  /// chord contributes both its meta + control activators.
  ///
  /// On a duplicate activator (a user-created conflict) the **first** catalog
  /// entry wins — deterministic, and surfaced in the settings UI via
  /// [conflictingIds]. Iterating [kShortcutCatalog] (stable order) keeps "first
  /// wins" stable across rebuilds.
  Map<ShortcutActivator, Intent> activatorsFor(
    ShortcutScope scope,
    Map<String, Intent> intents,
  ) {
    final out = <ShortcutActivator, Intent>{};
    for (final def in kShortcutCatalog) {
      if (def.scope != scope) continue;
      final intent = intents[def.id];
      if (intent == null) continue;
      final binding = resolvedBinding(def.id);
      if (binding == null) continue;
      for (final activator in binding.toActivators()) {
        out.putIfAbsent(activator, () => intent);
      }
    }
    return out;
  }

  /// Action ids whose resolved binding collides with another action's — two
  /// actions produce an overlapping activator. Both sides of every clash are
  /// included so the settings UI can flag each row.
  Set<String> conflictingIds() {
    // Key by the binding's canonical signature, not the produced activator —
    // SingleActivator/CharacterActivator use identity equality (see
    // KeyBinding.activatorSignatures).
    final bySignature = <String, List<String>>{};
    for (final def in kShortcutCatalog) {
      final binding = resolvedBinding(def.id);
      if (binding == null) continue;
      for (final signature in binding.activatorSignatures()) {
        (bySignature[signature] ??= <String>[]).add(def.id);
      }
    }
    final out = <String>{};
    for (final ids in bySignature.values) {
      if (ids.length > 1) out.addAll(ids);
    }
    return out;
  }

  /// Assign a custom binding.
  void setBinding(String id, KeyBinding binding) {
    _overrides[id] = binding;
    _persist();
    notifyListeners();
  }

  /// Explicitly clear a shortcut (removes even the catalog default). Distinct
  /// from [resetBinding], which reverts to the default.
  void clearBinding(String id) {
    _overrides[id] = null;
    _persist();
    notifyListeners();
  }

  /// Revert [id] to its catalog default.
  void resetBinding(String id) {
    if (_overrides.remove(id) == null) return;
    _persist();
    notifyListeners();
  }

  /// Revert every action to its catalog default.
  void resetAll() {
    if (_overrides.isEmpty) return;
    _overrides.clear();
    _persist();
    notifyListeners();
  }

  /// Load persisted overrides from the `nav_state` row. No-op without a [db].
  Future<void> restore() async {
    final db = _db;
    if (db == null) return;
    final row = await db.navStateDao.current();
    restoreFromJson(row?.keyboardShortcutsJson);
  }

  /// Parse a stored overrides blob into memory (unknown ids ignored, so a
  /// removed catalog action doesn't strand a dead override). Does not notify —
  /// called once at boot before the UI builds.
  @visibleForTesting
  void restoreFromJson(String? jsonStr) {
    _overrides.clear();
    if (jsonStr == null || jsonStr.isEmpty) return;
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        if (key is! String || !kShortcutCatalogById.containsKey(key)) return;
        if (value == null) {
          _overrides[key] = null; // explicitly cleared
        } else if (value is Map) {
          final binding = KeyBinding.fromJson(Map<String, dynamic>.from(value));
          if (binding != null) _overrides[key] = binding;
        }
      });
    } catch (e, st) {
      _log.warning('Failed to parse keyboard shortcut overrides', e, st);
    }
  }

  /// Serialize the current overrides (custom bindings + explicit clears).
  @visibleForTesting
  Map<String, dynamic> overridesToJson() => {
    for (final e in _overrides.entries) e.key: e.value?.toJson(),
  };

  Future<void> _persist() async {
    final db = _db;
    if (db == null) return;
    try {
      await db.navStateDao.saveKeyboardShortcuts(
        keyboardShortcutsJson: jsonEncode(overridesToJson()),
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      // A failed write keeps the in-memory overrides for this session — same
      // trade-off as theme / text-scale persistence.
      _log.warning('Failed to persist keyboard shortcut overrides', e, st);
    }
  }
}
