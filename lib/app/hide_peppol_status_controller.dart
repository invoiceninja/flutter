import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// Owns "hide the PEPPOL sent / failed icon on the invoice and credit lists"
/// (`DevicePrefKeys.hidePeppolStatus`, React ui#3410). Defaults to showing it,
/// as React does.
class HidePeppolStatusController extends DevicePref<bool> {
  HidePeppolStatusController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.hidePeppolStatus, fallback: false);
}
