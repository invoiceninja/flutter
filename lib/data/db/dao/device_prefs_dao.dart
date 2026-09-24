import 'package:drift/drift.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/tables/device_prefs_table.dart';

part 'device_prefs_dao.g.dart';

/// Raw access to the `device_prefs` rows. Read and written only through
/// `DevicePrefsStore`, which owns the typed keys and the in-memory mirror.
@DriftAccessor(tables: [DevicePrefs])
class DevicePrefsDao extends DatabaseAccessor<AppDatabase>
    with _$DevicePrefsDaoMixin {
  DevicePrefsDao(super.db);

  Future<Map<String, String>> readAll() async => {
    for (final row in await select(devicePrefs).get()) row.key: row.value,
  };

  /// One row per key, so a write can never disturb another preference.
  Future<void> put(String key, String value, {required int now}) =>
      into(devicePrefs).insertOnConflictUpdate(
        DevicePrefsCompanion.insert(key: key, value: value, updatedAt: now),
      );

  Future<void> remove(String key) =>
      (delete(devicePrefs)..where((p) => p.key.equals(key))).go();
}
