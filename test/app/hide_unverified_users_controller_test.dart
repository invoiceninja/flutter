import 'package:admin/app/hide_unverified_users_controller.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';

import '_device_pref_controller_contract.dart';

/// Defaults to OFF — the opposite of its two bool siblings, because this one
/// removes people from a form rather than adding chrome to one
/// (invoiceninja/flutter#150; `email_verified_at` conflates four states,
/// BACKEND.md § F4). Hiding colleagues is not a safe thing to switch on for a
/// user who never opened Settings.
void main() {
  devicePrefControllerContract(
    build: (prefs) => HideUnverifiedUsersController(prefs: prefs),
    key: DevicePrefKeys.hideUnverifiedUsers,
    fallback: false,
    other: true,
  );
}
