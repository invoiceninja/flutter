import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// `decimal` — hours as a decimal number (`1.5`), what the weekly view always
/// showed.
const String kHoursFormatDecimal = 'decimal';

/// `hh_mm` — hours and minutes (`1:30`). The same value React stores.
const String kHoursFormatHoursMinutes = 'hh_mm';

/// Owns how the Tasks weekly view shows hours
/// (`DevicePrefKeys.hoursFormat`, React ui#3422). Defaults to decimal.
///
/// Read through [showsHoursMinutes], never by comparing [value] to
/// [kHoursFormatDecimal]: a value this build doesn't know (written by a newer
/// one) must still resolve to one of the two choices, and to the default.
class HoursFormatController extends DevicePref<String> {
  HoursFormatController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.hoursFormat, fallback: kHoursFormatDecimal);

  bool get showsHoursMinutes => value == kHoursFormatHoursMinutes;

  Future<void> setHoursMinutes(bool hoursMinutes) =>
      set(hoursMinutes ? kHoursFormatHoursMinutes : kHoursFormatDecimal);
}
