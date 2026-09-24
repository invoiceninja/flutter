import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../_support/device_prefs_test_support.dart';

/// Tests target ThemeController's persistence contract:
///   * setting any of mode / lightVariant / darkVariant writes the matching
///     device preference and survives a relaunch
///   * no notification fires when the same value is set twice
///   * an unrecognized stored string reads as the default (forwards-compat
///     for a future palette rename)
/// They don't re-test Drift or ChangeNotifier itself.

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  ThemeController newController() =>
      ThemeController(prefs: DevicePrefsStore(db));

  /// A relaunch: a new store, loaded from the same database.
  Future<ThemeController> relaunch() async {
    final prefs = DevicePrefsStore(db);
    await prefs.load();
    return ThemeController(prefs: prefs);
  }

  Future<Map<String, String>> rows() => db.devicePrefsDao.readAll();

  test('setThemeMode writes its preference and survives a relaunch', () async {
    await newController().setThemeMode(ThemeMode.dark);
    expect((await rows())[DevicePrefKeys.themeMode.name], 'dark');

    final prefs = DevicePrefsStore(db);
    final fresh = ThemeController(prefs: prefs);
    expect(fresh.themeMode, ThemeMode.system, reason: 'before the boot load');
    var notified = false;
    fresh.addListener(() => notified = true);
    await prefs.load();
    expect(fresh.themeMode, ThemeMode.dark);
    expect(notified, isTrue, reason: 'MaterialApp rebuilds on the load');
  });

  test(
    'setLightVariant + setDarkVariant write their columns and round-trip',
    () async {
      final controller = newController();
      await controller.setLightVariant(LightVariant.mist);
      await controller.setDarkVariant(DarkVariant.carbon);

      expect((await rows())[DevicePrefKeys.lightVariant.name], 'mist');
      expect((await rows())[DevicePrefKeys.darkVariant.name], 'carbon');

      final fresh = await relaunch();
      expect(fresh.lightVariant, LightVariant.mist);
      expect(fresh.darkVariant, DarkVariant.carbon);
    },
  );

  test('unrecognized variant strings read as the defaults', () async {
    // Bogus variant names — a future rename would land legacy installs in
    // this state; the controller must not crash.
    final controller = ThemeController(
      prefs: prefsWith({
        DevicePrefKeys.themeMode: 'light',
        DevicePrefKeys.lightVariant: 'no_such_variant',
        DevicePrefKeys.darkVariant: 'also_unknown',
      }),
    );
    expect(controller.themeMode, ThemeMode.light);
    expect(controller.lightVariant, LightVariant.sand);
    expect(controller.darkVariant, DarkVariant.espresso);
  });

  test(
    'override layers on the preset, then a preset change clears that side',
    () async {
      final controller = newController();
      await controller.setLightVariant(LightVariant.mist);
      await controller.setCustomOverride(
        Brightness.light,
        CustomToken.background,
        const Color(0xFF112233),
      );
      await controller.setCustomOverride(
        Brightness.dark,
        CustomToken.ink,
        const Color(0xFFAABBCC),
      );

      // Override sits on top of the selected preset (Mist), not Sand.
      expect(controller.lightTokens.bg, const Color(0xFF112233));
      expect(controller.lightTokens.surface, InTheme.lightMist.surface);

      // Switching the light preset clears the light overrides — the new
      // preset renders clean. The dark side is untouched.
      await controller.setLightVariant(LightVariant.paper);
      expect(controller.customTheme.lightOverrides, isEmpty);
      expect(controller.lightTokens, same(InTheme.lightPaper));
      expect(
        controller.customTheme.darkOverrides[CustomToken.ink],
        const Color(0xFFAABBCC),
      );

      expect((await rows())[DevicePrefKeys.lightVariant.name], 'paper');
      expect((await rows())[DevicePrefKeys.customTheme.name], isNotNull);

      final fresh = await relaunch();
      expect(fresh.lightVariant, LightVariant.paper);
      expect(fresh.customTheme.lightOverrides, isEmpty);
      expect(
        fresh.customTheme.darkOverrides[CustomToken.ink],
        const Color(0xFFAABBCC),
      );
    },
  );

  test('lightTokens identity: bare preset is the const singleton', () {
    final controller = newController();
    expect(controller.lightTokens, same(InTheme.lightSand));
    expect(identical(controller.lightTokens, controller.lightTokens), isTrue);

    controller.setCustomOverride(
      Brightness.light,
      CustomToken.surface,
      const Color(0xFF010203),
    );
    final a = controller.lightTokens;
    expect(
      identical(a, controller.lightTokens),
      isTrue,
      reason: 'memoised across unrelated reads',
    );
    expect(a, isNot(same(InTheme.lightSand)));
  });

  test(
    'clearCustomSide reverts the side to the bare preset singleton',
    () async {
      final controller = newController();
      await controller.setLightVariant(LightVariant.mist);
      await controller.setCustomOverride(
        Brightness.light,
        CustomToken.ink,
        const Color(0xFF445566),
      );
      expect(controller.customTheme.lightOverrides, isNotEmpty);
      expect(controller.lightTokens, isNot(same(InTheme.lightMist)));

      await controller.clearCustomSide(Brightness.light);
      expect(controller.customTheme.lightOverrides, isEmpty);
      expect(controller.lightTokens, same(InTheme.lightMist));

      final fresh = await relaunch();
      expect(fresh.customTheme.lightOverrides, isEmpty);
    },
  );

  test('setters are no-ops when the value is unchanged', () async {
    final controller = ThemeController(
      prefs: prefsWith({
        DevicePrefKeys.themeMode: 'light',
        DevicePrefKeys.lightVariant: 'paper',
      }),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.setThemeMode(ThemeMode.light);
    await controller.setLightVariant(LightVariant.paper);
    expect(notifications, 0, reason: 'identical values must not notify');

    await controller.setThemeMode(ThemeMode.dark);
    await controller.setLightVariant(LightVariant.mist);
    expect(notifications, 2);
  });

  test(
    'a variant loaded at boot drops the tokens resolved for the old one',
    () async {
      // The memoised light palette must be cleared whenever the preset under
      // the overrides changes — including a change that arrives from the store
      // rather than a setter.
      final prefs = DevicePrefsStore(db);
      final controller = ThemeController(prefs: prefs);
      await controller.setCustomOverride(
        Brightness.light,
        CustomToken.ink,
        const Color(0xFF445566),
      );
      expect(controller.lightTokens.surface, InTheme.lightSand.surface);

      await db.devicePrefsDao.put(
        DevicePrefKeys.lightVariant.name,
        'mist',
        now: 1,
      );
      await prefs.load();
      expect(controller.lightVariant, LightVariant.mist);
      expect(controller.lightTokens.surface, InTheme.lightMist.surface);
    },
  );
}
