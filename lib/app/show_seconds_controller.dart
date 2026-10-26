import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// Owns the user's "show seconds" preference (`DevicePrefKeys.showSeconds`,
/// device-local).
///
/// Defaults to **off**: every running timer already ticks seconds, and the
/// surfaces this adds them to (the kanban cards, a timer past a day, a time
/// entry's start and end) read cleaner without them for most people.
///
/// Read through its root provider with `watchShowSeconds(context)`, so a
/// surface rebuilds when it flips and a test without the provider simply
/// gets the default.
class ShowSecondsController extends DevicePref<bool> {
  ShowSecondsController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.showSeconds, fallback: false);
}
