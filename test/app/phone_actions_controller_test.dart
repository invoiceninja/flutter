import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/phone_actions_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/phone/phone_actions_settings.dart';

/// Targets the PhoneActionsController persistence contract:
///   * a null column resolves per *device* (the reason it's a blob, not five
///     typed columns with SQL defaults)
///   * a stored blob is taken literally — the platform must not re-decide for
///     a user who has already chosen
///   * partial writes don't clobber sibling nav_state columns
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

  test('a fresh install takes the device defaults', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = PhoneActionsController(db: db);
    await controller.restore();
    expect(controller.value.tapToCall, isTrue);
    expect(controller.value.confirmBeforeCall, isFalse);
    expect(controller.value.warnOutsideBusinessHours, isTrue);
  });

  test('a desktop install defaults tap-to-call off', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final controller = PhoneActionsController(db: db);
    await controller.restore();
    expect(controller.value.tapToCall, isFalse);
  });

  test('a choice persists and restores on the next launch', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = PhoneActionsController(db: db);
    await controller.setConfirmBeforeCall(true);
    await controller.setBusinessHours(
      startMinutes: 9 * 60,
      endMinutes: 17 * 60,
    );

    final row = await db.navStateDao.current();
    final stored = jsonDecode(row!.phoneActionsJson!) as Map<String, dynamic>;
    expect(stored['confirmBeforeCall'], isTrue);
    expect(stored['startMinutes'], 9 * 60);

    final fresh = PhoneActionsController(db: db);
    expect(fresh.value.confirmBeforeCall, isFalse, reason: 'before restore');
    await fresh.restore();
    expect(fresh.value.confirmBeforeCall, isTrue);
    expect(fresh.value.startMinutes, 9 * 60);
    expect(fresh.value.endMinutes, 17 * 60);
  });

  test(
    'a stored blob wins over the platform default, so moving a device or '
    'reinstalling on the same one cannot silently flip a deliberate choice',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await PhoneActionsController(db: db).setTapToCall(false);

      final fresh = PhoneActionsController(db: db);
      await fresh.restore();
      expect(fresh.value.tapToCall, isFalse);
    },
  );

  test(
    'a corrupt blob falls back to the defaults instead of throwing',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await db.navStateDao.savePhoneActions(json: '{not json', now: 1);

      final controller = PhoneActionsController(db: db);
      await controller.restore();
      expect(controller.value, PhoneActionsSettings.deviceDefaults());
    },
  );

  test('a write leaves the other nav_state fields alone', () async {
    // `false` because `flutter test` reports TargetPlatform.android, where
    // tap-to-call already defaults on — setting it to `true` is a no-op and
    // writes nothing at all, which is the intended behaviour but proves
    // nothing about clobbering.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await db.navStateDao.saveRoute(route: '/clients', now: 1);
    await PhoneActionsController(db: db).setTapToCall(false);

    final row = await db.navStateDao.current();
    expect(row?.currentRoute, '/clients');
    expect(row?.phoneActionsJson, isNotNull);
  });

  test('does not notify when the same value is chosen twice', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = PhoneActionsController(db: db);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setTapToCall(true);
    expect(notifications, 0, reason: 'already on for a touch device');

    await controller.setTapToCall(false);
    expect(notifications, 1);
  });
}
