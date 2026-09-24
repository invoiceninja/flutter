import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// Owns the user's "is the wide-layout sidebar collapsed?" preference
/// (`DevicePrefKeys.sidebarCollapsed`, device-local), so the rail renders at
/// the correct width on the first frame of the next launch.
class SidebarController extends DevicePref<bool> {
  SidebarController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.sidebarCollapsed, fallback: false);

  Future<void> toggle() => set(!value);
}
