import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/locale_controller.dart';
import 'package:admin/app/text_scale_controller.dart';
import 'package:admin/app/theme_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

import '_device_pref_controller_contract.dart';

void main() {
  devicePrefControllerContract(
    build: (prefs) => TextScaleController(prefs: prefs),
    key: DevicePrefKeys.textScale,
    fallback: kTextScaleNormal,
    other: kTextScaleLarge,
  );

  test('a theme / locale write leaves the text scale alone', () async {
    // Through v11 these three shared one `nav_state` row, and the theme and
    // locale writes read the whole row and wrote it back — so a write racing
    // another could put back a value that had just changed. Each is its own
    // row now.
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final prefs = DevicePrefsStore(db);
    await TextScaleController(prefs: prefs).set(kTextScaleSmall);
    await ThemeController(prefs: prefs).setThemeMode(ThemeMode.light);
    await LocaleController(prefs: prefs).set(const Locale('de'));

    final fresh = DevicePrefsStore(db);
    await fresh.load();
    expect(TextScaleController(prefs: fresh).value, kTextScaleSmall);
    expect(ThemeController(prefs: fresh).themeMode, ThemeMode.light);
    expect(LocaleController(prefs: fresh).value, const Locale('de'));
  });

  test('textScaleLabelKey maps each factor to its label key', () {
    expect(textScaleLabelKey(kTextScaleSmall), 'small');
    expect(textScaleLabelKey(kTextScaleNormal), 'normal');
    expect(textScaleLabelKey(kTextScaleLarge), 'large');
    expect(textScaleLabelKey(kTextScaleExtraLarge), 'extra_large');
  });

  test('composeTextScaler multiplies the OS factor by the user factor', () {
    // Default factor → pure OS passthrough (the accessibility-regression guard).
    expect(
      composeTextScaler(
        const TextScaler.linear(1.3),
        kTextScaleNormal,
      ).scale(10),
      closeTo(13, 1e-9),
      reason: 'Normal must respect the OS scale, not force 1.0',
    );
    // Explicit factor scales relative to the OS baseline.
    expect(
      composeTextScaler(
        const TextScaler.linear(1.0),
        kTextScaleLarge,
      ).scale(10),
      closeTo(12, 1e-9),
    );
    expect(
      composeTextScaler(TextScaler.noScaling, kTextScaleSmall).scale(10),
      closeTo(8, 1e-9),
    );
  });
}
