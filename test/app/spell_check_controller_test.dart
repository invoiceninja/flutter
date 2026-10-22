import 'package:admin/app/spell_check_controller.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';

import '_device_pref_controller_contract.dart';

/// Defaults to ON — the feature was asked for; the switch is for a catalog
/// of SKUs every checker flags (docs/spell-check.md).
void main() {
  devicePrefControllerContract(
    build: (prefs) => SpellCheckController(prefs: prefs),
    key: DevicePrefKeys.spellCheck,
    fallback: true,
    other: false,
  );
}
