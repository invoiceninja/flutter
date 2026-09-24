import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/sidebar_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

import '_device_pref_controller_contract.dart';

/// Defaults to expanded.
void main() {
  devicePrefControllerContract(
    build: (prefs) => SidebarController(prefs: prefs),
    key: DevicePrefKeys.sidebarCollapsed,
    fallback: false,
    other: true,
  );

  test('toggle() flips and persists the collapsed flag', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await SidebarController(prefs: DevicePrefsStore(db)).toggle();

    final prefs = DevicePrefsStore(db);
    await prefs.load();
    expect(SidebarController(prefs: prefs).value, isTrue);
  });
}
