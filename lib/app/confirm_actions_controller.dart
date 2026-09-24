import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// Owns the user's "prompt before running a risky action?" preference
/// (`DevicePrefKeys.confirmActions`, device-local).
///
/// Defaults to **on**: invoiceninja/flutter#49 reported users fat-fingering
/// Approve on a quote and Archive on a record while working from a phone in
/// the field. When on, actions tagged `confirm: true` (see
/// `EntityActionItem`) open an "Are you sure?" dialog first. An account
/// preference, so a sign-out puts the next user back on the guard.
///
/// Read it at the moment the action fires, never at build time — a menu built
/// before the switch was flipped must still honour the new value.
class ConfirmActionsController extends DevicePref<bool> {
  ConfirmActionsController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.confirmActions, fallback: true);
}
