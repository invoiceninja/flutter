import 'package:admin/app/show_seconds_controller.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';

import '_device_pref_controller_contract.dart';

/// Defaults to OFF — running timers already tick seconds; the switch adds
/// them where they are left out (docs/tasks-views.md).
void main() {
  devicePrefControllerContract(
    build: (prefs) => ShowSecondsController(prefs: prefs),
    key: DevicePrefKeys.showSeconds,
    fallback: false,
    other: true,
  );
}
