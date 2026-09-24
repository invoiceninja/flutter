import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/phone_actions_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/phone/phone_actions_settings.dart';

/// Targets the PhoneActionsController persistence contract:
///   * nothing stored resolves per *device* (the reason it's a blob, not five
///     typed values with fixed defaults)
///   * a stored blob is taken literally — the platform must not re-decide for
///     a user who has already chosen
///
/// It doesn't re-test Drift or ChangeNotifier.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await db.close();
  });

  /// A relaunch: a new store, loaded from the same database.
  Future<PhoneActionsController> relaunch() async {
    final prefs = DevicePrefsStore(db);
    await prefs.load();
    return PhoneActionsController(prefs: prefs);
  }

  test('a fresh install takes the device defaults', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = await relaunch();
    expect(controller.value.tapToCall, isTrue);
    expect(controller.value.confirmBeforeCall, isFalse);
    expect(controller.value.warnOutsideBusinessHours, isTrue);
  });

  test('a desktop install defaults tap-to-call off', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final controller = await relaunch();
    expect(controller.value.tapToCall, isFalse);
  });

  test('a choice persists and survives a relaunch', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = PhoneActionsController(prefs: DevicePrefsStore(db));
    await controller.setConfirmBeforeCall(true);
    await controller.setBusinessHours(
      startMinutes: 9 * 60,
      endMinutes: 17 * 60,
    );

    final rows = await db.devicePrefsDao.readAll();
    final stored =
        jsonDecode(rows[DevicePrefKeys.phoneActions.name]!)
            as Map<String, dynamic>;
    expect(stored['confirmBeforeCall'], isTrue);
    expect(stored['startMinutes'], 9 * 60);

    final fresh = await relaunch();
    expect(fresh.value.confirmBeforeCall, isTrue);
    expect(fresh.value.startMinutes, 9 * 60);
    expect(fresh.value.endMinutes, 17 * 60);
  });

  test(
    'a stored blob wins over the platform default, so moving a device or '
    'reinstalling on the same one cannot silently flip a deliberate choice',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await PhoneActionsController(
        prefs: DevicePrefsStore(db),
      ).setTapToCall(false);

      final fresh = await relaunch();
      expect(fresh.value.tapToCall, isFalse);
    },
  );

  test(
    'a corrupt blob falls back to the defaults instead of throwing',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await db.devicePrefsDao.put(
        DevicePrefKeys.phoneActions.name,
        '{not json',
        now: 1,
      );

      final controller = await relaunch();
      expect(controller.value, PhoneActionsSettings.deviceDefaults());
    },
  );

  test('does not notify when the same value is chosen twice', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = PhoneActionsController(prefs: DevicePrefsStore(db));
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setTapToCall(true);
    expect(notifications, 0, reason: 'already on for a touch device');

    await controller.setTapToCall(false);
    expect(notifications, 1);
  });
}
