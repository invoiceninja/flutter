import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/shortcuts/key_binding.dart';
import 'package:admin/app/shortcuts/keyboard_shortcuts_controller.dart';
import 'package:admin/app/shortcuts/shortcut_catalog.dart';
import 'package:admin/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('overrides persist to nav_state and restore reloads them', () async {
    // Produce a JSON blob the same way the controller would, then write it via
    // the DAO and restore into a fresh controller — exercises the real column +
    // saveKeyboardShortcuts + restore() path end to end.
    final producer = KeyboardShortcutsController();
    final custom = KeyBinding.logical(
      LogicalKeyboardKey.keyB.keyId,
      usesPrimary: true,
    );
    producer.setBinding(ShortcutActionIds.toggleSidebar, custom);
    producer.clearBinding(ShortcutActionIds.focusSearch);

    await db.navStateDao.saveKeyboardShortcuts(
      keyboardShortcutsJson: jsonEncode(producer.overridesToJson()),
      now: 1,
    );

    final restored = KeyboardShortcutsController(db: db);
    await restored.restore();
    expect(restored.resolvedBinding(ShortcutActionIds.toggleSidebar), custom);
    expect(restored.isOverridden(ShortcutActionIds.focusSearch), isTrue);
    expect(restored.resolvedBinding(ShortcutActionIds.focusSearch), isNull);
    // Untouched actions still resolve to their catalog default.
    expect(
      restored.resolvedBinding(ShortcutActionIds.openCompanyPicker),
      KeyBinding.logical(LogicalKeyboardKey.keyK.keyId, usesPrimary: true),
    );
  });

  test('restore is a no-op when nothing was persisted', () async {
    final c = KeyboardShortcutsController(db: db);
    await c.restore();
    expect(c.conflictingIds(), isEmpty);
    expect(c.isOverridden(ShortcutActionIds.toggleSidebar), isFalse);
  });

  test('setBinding writes through to nav_state', () async {
    final c = KeyboardShortcutsController(db: db, now: () => DateTime(2026));
    c.setBinding(
      ShortcutActionIds.openSettings,
      KeyBinding.logical(LogicalKeyboardKey.comma.keyId, usesPrimary: true),
    );
    // _persist is fire-and-forget; give the async write a beat to land.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final row = await db.navStateDao.current();
    expect(row?.keyboardShortcutsJson, isNotNull);
    expect(row!.keyboardShortcutsJson, contains('open_settings'));
  });
}
