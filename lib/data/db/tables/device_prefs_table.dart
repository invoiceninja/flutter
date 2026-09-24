import 'package:drift/drift.dart';

/// This device's preferences, one row per `DevicePrefKeys` entry
/// (`lib/data/prefs/device_pref_keys.dart`): the theme, the language, the
/// keyboard-shortcut overrides, the main menu, and so on.
///
/// A key/value table so that adding a preference is adding a key — no schema
/// change and no migration. Through schema v11 each preference was a
/// `nav_state` column, and all ten schema bumps since release existed only to
/// add one: each ran `onUpgrade` on every installed database, the path whose
/// failure wipes the store. v12 moved the seventeen columns here
/// (`carryNavStatePrefs`).
///
/// A missing row means "never set": the controller that owns the key
/// supplies the default, which may depend on the device (tap-to-call follows
/// `Env.isTouchPrimary`, "Hide empty panels" whether it is a phone).
@DataClassName('DevicePrefRow')
class DevicePrefs extends Table {
  TextColumn get key => text()();

  /// Encoded by the key's `PrefCodec`.
  TextColumn get value => text()();
  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column> get primaryKey => {key};
}
