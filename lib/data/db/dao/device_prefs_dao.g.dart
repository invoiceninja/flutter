// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_prefs_dao.dart';

// ignore_for_file: type=lint
mixin _$DevicePrefsDaoMixin on DatabaseAccessor<AppDatabase> {
  $DevicePrefsTable get devicePrefs => attachedDatabase.devicePrefs;
  DevicePrefsDaoManager get managers => DevicePrefsDaoManager(this);
}

class DevicePrefsDaoManager {
  final _$DevicePrefsDaoMixin _db;
  DevicePrefsDaoManager(this._db);
  $$DevicePrefsTableTableManager get devicePrefs =>
      $$DevicePrefsTableTableManager(_db.attachedDatabase, _db.devicePrefs);
}
