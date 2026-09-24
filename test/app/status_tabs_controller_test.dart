import 'package:admin/app/status_tabs_controller.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';

import '_device_pref_controller_contract.dart';

/// Defaults to ON — invoiceninja/flutter#98 asked for the strip because the
/// filter menu costs three or four taps.
void main() {
  devicePrefControllerContract(
    build: (prefs) => StatusTabsController(prefs: prefs),
    key: DevicePrefKeys.statusTabs,
    fallback: true,
    other: false,
  );
}
