import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<DevicePrefsStore> loaded() async {
    final prefs = DevicePrefsStore(db);
    await prefs.load();
    return prefs;
  }

  group('DevicePrefsStore', () {
    test('nothing stored reads as null — the owner supplies the default', () {
      expect(DevicePrefsStore(db).read(DevicePrefKeys.statusTabs), isNull);
    });

    test('a write reads back at once and survives a relaunch', () async {
      final prefs = DevicePrefsStore(db);
      await prefs.write(DevicePrefKeys.textScale, 1.4);
      expect(prefs.read(DevicePrefKeys.textScale), 1.4);

      expect((await loaded()).read(DevicePrefKeys.textScale), 1.4);
    });

    test('writing null removes the row', () async {
      final prefs = DevicePrefsStore(db);
      await prefs.write(DevicePrefKeys.tasksView, 'kanban');
      await prefs.write(DevicePrefKeys.tasksView, null);

      expect(prefs.read(DevicePrefKeys.tasksView), isNull);
      expect(await db.devicePrefsDao.readAll(), isEmpty);
    });

    test('a write touches its own row only', () async {
      // Through v11 preferences shared one `nav_state` row, and a theme or
      // locale write read the row and wrote it all back — so a change made
      // between the two was reverted. Each preference is its own row now.
      await db.devicePrefsDao.put(DevicePrefKeys.locale.name, 'de', now: 1);
      final prefs = DevicePrefsStore(db); // not loaded: it can't know `locale`
      await prefs.write(DevicePrefKeys.themeMode, 'dark');

      expect(await db.devicePrefsDao.readAll(), {
        DevicePrefKeys.locale.name: 'de',
        DevicePrefKeys.themeMode.name: 'dark',
      });
    });

    test('a value its codec can\'t read is treated as never set', () async {
      await db.devicePrefsDao.put(
        DevicePrefKeys.statusTabs.name,
        'maybe',
        now: 1,
      );
      await db.devicePrefsDao.put(DevicePrefKeys.textScale.name, 'big', now: 1);
      final prefs = await loaded();
      expect(prefs.read(DevicePrefKeys.statusTabs), isNull);
      expect(prefs.read(DevicePrefKeys.textScale), isNull);
    });

    test('a load notifies; a write does not', () async {
      final prefs = DevicePrefsStore(db);
      var notifications = 0;
      prefs.addListener(() => notifications++);

      await prefs.write(DevicePrefKeys.themeMode, 'dark');
      expect(
        notifications,
        0,
        reason: 'the one owner of a key already holds what it wrote',
      );
      await prefs.load();
      expect(notifications, 1);
    });

    test('forgetWiped keeps the device keys and the carry marker, and drops '
        'the account keys and any key this build does not know', () async {
      await db.devicePrefsDao.put(
        DevicePrefKeys.themeMode.name,
        'dark',
        now: 1,
      );
      await db.devicePrefsDao.put(
        DevicePrefKeys.tasksView.name,
        'kanban',
        now: 1,
      );
      await db.devicePrefsDao.put(kPrefsCarriedFromNavState, '1', now: 1);
      await db.devicePrefsDao.put('from_a_newer_build', 'x', now: 1);
      final prefs = await loaded();
      var notified = false;
      prefs.addListener(() => notified = true);

      prefs.forgetWiped();

      expect(prefs.read(DevicePrefKeys.themeMode), 'dark');
      expect(prefs.read(DevicePrefKeys.tasksView), isNull);
      expect(notified, isTrue);
    });

    test('the wipe itself keeps the same rows the mirror does', () async {
      for (final key in DevicePrefKeys.all) {
        await db.devicePrefsDao.put(key.name, '1', now: 1);
      }
      await db.devicePrefsDao.put(kPrefsCarriedFromNavState, '1', now: 1);
      await db.devicePrefsDao.put('from_a_newer_build', 'x', now: 1);

      await db.wipe();

      expect(
        (await db.devicePrefsDao.readAll()).keys.toSet(),
        DevicePrefKeys.keptOnWipe,
      );
    });

    test('a failed write keeps the new value for this launch', () async {
      final doomed = AppDatabase(NativeDatabase.memory());
      final prefs = DevicePrefsStore(doomed);
      await doomed.close();

      await prefs.write(DevicePrefKeys.statusTabs, false);
      expect(prefs.read(DevicePrefKeys.statusTabs), isFalse);
    });

    test('without a database it keeps preferences in memory', () async {
      final prefs = DevicePrefsStore(null);
      await prefs.write(DevicePrefKeys.statusTabs, false);
      await prefs.load();
      expect(prefs.read(DevicePrefKeys.statusTabs), isFalse);
    });
  });

  group('DevicePref', () {
    test(
      'follows the store back to its fallback when a wipe forgets it',
      () async {
        final prefs = DevicePrefsStore(db);
        final pref = DevicePref(
          prefs,
          DevicePrefKeys.confirmActions,
          fallback: true,
        );
        await pref.set(false);

        prefs.forgetWiped();
        expect(pref.value, isTrue);
      },
    );

    test('stops following once disposed', () async {
      final prefs = DevicePrefsStore(db);
      final pref = DevicePref(prefs, DevicePrefKeys.statusTabs, fallback: true);
      pref.dispose();
      await db.devicePrefsDao.put(DevicePrefKeys.statusTabs.name, '0', now: 1);
      await prefs.load(); // would throw on a disposed notifier if still bound
      expect(prefs.read(DevicePrefKeys.statusTabs), isFalse);
    });
  });
}
