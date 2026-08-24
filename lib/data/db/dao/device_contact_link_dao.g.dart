// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_contact_link_dao.dart';

// ignore_for_file: type=lint
mixin _$DeviceContactLinkDaoMixin on DatabaseAccessor<AppDatabase> {
  $DeviceContactLinksTable get deviceContactLinks =>
      attachedDatabase.deviceContactLinks;
  DeviceContactLinkDaoManager get managers => DeviceContactLinkDaoManager(this);
}

class DeviceContactLinkDaoManager {
  final _$DeviceContactLinkDaoMixin _db;
  DeviceContactLinkDaoManager(this._db);
  $$DeviceContactLinksTableTableManager get deviceContactLinks =>
      $$DeviceContactLinksTableTableManager(
        _db.attachedDatabase,
        _db.deviceContactLinks,
      );
}
