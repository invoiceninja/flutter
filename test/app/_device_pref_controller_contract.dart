import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// What every controller built on [DevicePref] promises: its default with
/// nothing stored, a write that survives a relaunch, the boot load reaching
/// it, and no notification for a value it already holds. The key and the
/// scope themselves are pinned in `test/data/prefs/device_pref_keys_test.dart`.
void devicePrefControllerContract<T extends Object>({
  required DevicePref<T> Function(DevicePrefsStore prefs) build,
  required PrefKey<T> key,
  required T fallback,
  required T other,
}) {
  group('${key.name} controller', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('defaults to $fallback with nothing stored', () async {
      final prefs = DevicePrefsStore(db);
      await prefs.load();
      final controller = build(prefs);
      expect(controller.key, key);
      expect(controller.value, fallback);
    });

    test('set($other) survives a relaunch', () async {
      await build(DevicePrefsStore(db)).set(other);

      // A relaunch: a new store, loaded from the same database.
      final prefs = DevicePrefsStore(db);
      final controller = build(prefs);
      expect(controller.value, fallback, reason: 'before the boot load');
      await prefs.load();
      expect(controller.value, other);
    });

    test('set() does not notify for the value it already holds', () async {
      final controller = build(DevicePrefsStore(db));
      var notifications = 0;
      controller.addListener(() => notifications++);

      await controller.set(fallback);
      expect(notifications, 0);
      await controller.set(other);
      expect(notifications, 1);
    });
  });
}
