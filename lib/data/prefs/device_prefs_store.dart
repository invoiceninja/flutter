import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';

final _log = Logger('DevicePrefsStore');

/// This device's preferences — the `device_prefs` table, mirrored in memory
/// so every read is synchronous.
///
/// [load] fills the mirror once at boot. A write updates the mirror, then its
/// own row, so no write can disturb another preference: the old single-row
/// `nav_state` writes read the whole row and wrote it back, and a theme change
/// could put back the route or filters that row held a moment earlier.
///
/// Listeners hear only about changes a preference's owner did not make —
/// [load], and a data wipe forgetting the account keys ([forgetWiped]) —
/// never about a [write]: each key has one owner, which already holds what it
/// wrote, and an owner that writes several keys (the theme) must not be
/// re-synced from a half-written set. So a preference that follows the store
/// needs no wipe hook to go back to its default (`DevicePref`).
class DevicePrefsStore extends ChangeNotifier {
  /// [db] null keeps the preferences in memory only — for tests of code that
  /// needs a store but not its persistence.
  DevicePrefsStore(AppDatabase? db, {DateTime Function()? now})
    : _db = db,
      _now = now ?? DateTime.now;

  final AppDatabase? _db;
  final DateTime Function() _now;
  final Map<String, String> _values = {};

  /// Replace the mirror with the table. Once at boot, bounded there: a
  /// failure leaves every preference on its default for this launch, and the
  /// rows untouched for the next.
  Future<void> load() async {
    final db = _db;
    if (db == null) return;
    final rows = await db.devicePrefsDao.readAll();
    _values
      ..clear()
      ..addAll(rows);
    notifyListeners();
  }

  /// The stored value, or null when there is none or it can't be decoded —
  /// the owner's default applies.
  T? read<T extends Object>(PrefKey<T> key) {
    final raw = _values[key.name];
    return raw == null ? null : key.codec.decode(raw);
  }

  /// Store [value] under [key]; null removes the row, returning the key to
  /// its owner's default. A failed write is logged and keeps the new value in
  /// memory — the user sees their choice until the next launch.
  Future<void> write<T extends Object>(PrefKey<T> key, T? value) async {
    final raw = value == null ? null : key.codec.encode(value);
    if (raw == null) {
      _values.remove(key.name);
    } else {
      _values[key.name] = raw;
    }
    final db = _db;
    if (db == null) return;
    try {
      if (raw == null) {
        await db.devicePrefsDao.remove(key.name);
      } else {
        await db.devicePrefsDao.put(
          key.name,
          raw,
          now: _now().millisecondsSinceEpoch,
        );
      }
    } catch (e, st) {
      _log.warning('Failed to persist the ${key.name} preference', e, st);
    }
  }

  /// The in-memory half of `AppDatabase.wipe`, which kept only
  /// [DevicePrefKeys.keptOnWipe]: forget the rest, and tell the owners.
  /// Called by `LocalDataDisposer.wipeAll` straight after the wipe.
  void forgetWiped() {
    final kept = DevicePrefKeys.keptOnWipe;
    _values.removeWhere((name, _) => !kept.contains(name));
    notifyListeners();
  }
}
