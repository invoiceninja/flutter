import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/hide_empty_panels_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

import '../_support/device_prefs_test_support.dart';

/// Tests target the HideEmptyPanelsController persistence contract
/// (invoiceninja/flutter#161):
///   * null means automatic — nothing is stored, and a fresh controller
///     carries no choice of its own
///   * [HideEmptyPanelsController.effectiveFor] turns automatic into the
///     device answer (on for a phone) and lets an explicit choice win
///   * set() writes `DevicePrefKeys.hideEmptyPanels` and a relaunch reads it
///   * set() stores automatic (no row) when the choice is what the device
///     would pick anyway, so a foldable or split-screen window keeps adapting
///   * a data wipe forgets the choice
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  Future<String?> storedRow() async =>
      (await db.devicePrefsDao.readAll())[DevicePrefKeys.hideEmptyPanels.name];

  test('starts on automatic — no choice of its own', () {
    expect(
      HideEmptyPanelsController(prefs: DevicePrefsStore(db)).value,
      isNull,
    );
  });

  group('effectiveFor', () {
    test('automatic hides on a phone and shows everywhere else', () {
      final controller = HideEmptyPanelsController(prefs: DevicePrefsStore(db));
      expect(controller.effectiveFor(isPhone: true), isTrue);
      expect(controller.effectiveFor(isPhone: false), isFalse);
    });

    test('an explicit choice wins on either device', () {
      final off = HideEmptyPanelsController(
        prefs: prefsWith({DevicePrefKeys.hideEmptyPanels: false}),
      );
      expect(
        off.effectiveFor(isPhone: true),
        isFalse,
        reason: 'a phone user who switched it off must see empty panels',
      );
      final on = HideEmptyPanelsController(
        prefs: prefsWith({DevicePrefKeys.hideEmptyPanels: true}),
      );
      expect(on.effectiveFor(isPhone: false), isTrue);
    });
  });

  test('stays on automatic when another preference was written', () async {
    await DevicePrefsStore(db).write(DevicePrefKeys.statusTabs, false);
    final prefs = DevicePrefsStore(db);
    await prefs.load();
    expect(HideEmptyPanelsController(prefs: prefs).value, isNull);
  });

  test('set(false) persists and survives a relaunch', () async {
    // The case "automatic" exists for: an explicit "off" on a phone, where
    // automatic would have said "on".
    final controller = HideEmptyPanelsController(prefs: DevicePrefsStore(db));
    await controller.set(false, isPhone: true);
    expect(await storedRow(), '0');

    final prefs = DevicePrefsStore(db);
    final fresh = HideEmptyPanelsController(prefs: prefs);
    expect(fresh.value, isNull, reason: 'before the boot load');
    await prefs.load();
    expect(fresh.value, isFalse);
    expect(fresh.effectiveFor(isPhone: true), isFalse);
  });

  test('set() does not notify when the same value is chosen twice', () async {
    final controller = HideEmptyPanelsController(
      prefs: prefsWith({DevicePrefKeys.hideEmptyPanels: true}),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.set(true, isPhone: false);
    expect(notifications, 0, reason: 'already an explicit on');

    await controller.set(false, isPhone: false);
    expect(notifications, 1);
  });

  group('choosing what the device would pick returns to automatic', () {
    test('a phone switched off and back on is automatic again', () async {
      final controller = HideEmptyPanelsController(prefs: DevicePrefsStore(db));
      await controller.set(false, isPhone: true);
      expect(controller.value, isFalse);

      await controller.set(true, isPhone: true);
      expect(controller.value, isNull);
      expect(await storedRow(), isNull, reason: 'automatic stores no row');
    });

    test('a desktop switched on and back off is automatic again', () async {
      final controller = HideEmptyPanelsController(prefs: DevicePrefsStore(db));
      await controller.set(true, isPhone: false);
      expect(controller.value, isTrue);

      await controller.set(false, isPhone: false);
      expect(controller.value, isNull);
    });

    test('a foldable keeps adapting until the user overrides it', () async {
      // Folded (a phone) the default is on, open (a tablet) it is off. Picking
      // each default where it applies stores nothing, so both halves keep
      // their own answer.
      final controller = HideEmptyPanelsController(prefs: DevicePrefsStore(db));
      await controller.set(true, isPhone: true);
      expect(controller.effectiveFor(isPhone: true), isTrue);
      expect(controller.effectiveFor(isPhone: false), isFalse);

      // A real override — "on" while open — applies to both halves.
      await controller.set(true, isPhone: false);
      expect(controller.effectiveFor(isPhone: true), isTrue);
      expect(controller.effectiveFor(isPhone: false), isTrue);
    });
  });

  test('a data wipe returns it to automatic, and says so', () async {
    // An account preference: the next person to sign in starts on automatic.
    final prefs = DevicePrefsStore(db);
    final controller = HideEmptyPanelsController(prefs: prefs);
    await controller.set(false, isPhone: true);
    var notifications = 0;
    controller.addListener(() => notifications++);

    prefs.forgetWiped();
    expect(controller.value, isNull);
    expect(notifications, 1);
  });
}
