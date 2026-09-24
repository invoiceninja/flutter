import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/shortcuts/key_binding.dart';
import 'package:admin/app/shortcuts/keyboard_shortcuts_controller.dart';
import 'package:admin/app/shortcuts/shortcut_catalog.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// A relaunch: a new store, loaded from the same database.
  Future<KeyboardShortcutsController> relaunch() async {
    final prefs = DevicePrefsStore(db);
    await prefs.load();
    return KeyboardShortcutsController(prefs: prefs);
  }

  test('stored overrides load at boot', () async {
    // Produce a JSON blob the same way the controller would, then write its
    // row and load it into a fresh controller — the real row + load path end
    // to end.
    final producer = KeyboardShortcutsController();
    final custom = KeyBinding.logical(
      LogicalKeyboardKey.keyB.keyId,
      usesPrimary: true,
    );
    producer.setBinding(ShortcutActionIds.toggleSidebar, custom);
    producer.clearBinding(ShortcutActionIds.focusSearch);

    await db.devicePrefsDao.put(
      DevicePrefKeys.keyboardShortcuts.name,
      jsonEncode(producer.overridesToJson()),
      now: 1,
    );

    final restored = await relaunch();
    expect(restored.resolvedBinding(ShortcutActionIds.toggleSidebar), custom);
    expect(restored.isOverridden(ShortcutActionIds.focusSearch), isTrue);
    expect(restored.resolvedBinding(ShortcutActionIds.focusSearch), isNull);
    // Untouched actions still resolve to their catalog default.
    expect(
      restored.resolvedBinding(ShortcutActionIds.openCompanyPicker),
      KeyBinding.logical(LogicalKeyboardKey.keyK.keyId, usesPrimary: true),
    );
  });

  test('nothing stored leaves every action on its default', () async {
    final c = await relaunch();
    expect(c.conflictingIds(), isEmpty);
    expect(c.isOverridden(ShortcutActionIds.toggleSidebar), isFalse);
  });

  test('setBinding writes through, and survives a relaunch', () async {
    final c = KeyboardShortcutsController(prefs: DevicePrefsStore(db));
    final binding = KeyBinding.logical(
      LogicalKeyboardKey.comma.keyId,
      usesPrimary: true,
    );
    c.setBinding(ShortcutActionIds.openSettings, binding);
    // _persist is fire-and-forget; give the async write a beat to land.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final rows = await db.devicePrefsDao.readAll();
    expect(
      rows[DevicePrefKeys.keyboardShortcuts.name],
      contains('open_settings'),
    );

    final restored = await relaunch();
    expect(restored.resolvedBinding(ShortcutActionIds.openSettings), binding);
  });
}
