import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/list_density_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

import '_device_pref_controller_contract.dart';

void main() {
  devicePrefControllerContract(
    build: (prefs) => ListDensityController(prefs: prefs),
    key: DevicePrefKeys.listDensity,
    fallback: kListDensityNormal,
    other: kListDensityCompact,
  );

  late AppDatabase db;
  late DevicePrefsStore prefs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    prefs = DevicePrefsStore(db);
    await prefs.load();
  });
  tearDown(() => db.close());

  test('isCompact follows the stored value', () async {
    final c = ListDensityController(prefs: prefs);
    expect(c.isCompact, isFalse);
    await c.setCompact(true);
    expect(c.value, kListDensityCompact);
    expect(c.isCompact, isTrue);
    await c.setCompact(false);
    expect(c.value, kListDensityNormal);
    expect(c.isCompact, isFalse);
  });

  test('toggle flips between the two densities', () async {
    final c = ListDensityController(prefs: prefs);
    await c.toggle();
    expect(c.isCompact, isTrue);
    await c.toggle();
    expect(c.isCompact, isFalse);
  });

  test('a value this build does not know reads as Normal', () async {
    // Written by a newer build that offers a third density.
    await prefs.write(DevicePrefKeys.listDensity, 'comfortable');
    final c = ListDensityController(prefs: prefs);
    expect(c.value, 'comfortable');
    expect(c.isCompact, isFalse);
    // And toggling from it lands on a real choice.
    await c.toggle();
    expect(c.value, kListDensityCompact);
  });
}
