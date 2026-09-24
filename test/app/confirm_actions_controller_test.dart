import 'package:admin/app/confirm_actions_controller.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';

import '_device_pref_controller_contract.dart';

/// Defaults to ON — invoiceninja/flutter#49 ships the guard enabled.
void main() {
  devicePrefControllerContract(
    build: (prefs) => ConfirmActionsController(prefs: prefs),
    key: DevicePrefKeys.confirmActions,
    fallback: true,
    other: false,
  );
}
