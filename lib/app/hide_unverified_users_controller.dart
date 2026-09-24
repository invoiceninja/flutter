import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// Owns the user's "keep people who have never confirmed their email address
/// out of Assigned User fields" preference
/// (`DevicePrefKeys.hideUnverifiedUsers`, device-local).
///
/// Defaults to **off**, which is the opposite of its two bool siblings and is
/// deliberate. invoiceninja/flutter#150 asked for the toggle, but
/// `email_verified_at` conflates four states (BACKEND.md § F4) and three of
/// them are active, working users — so the cost of a wrong default here is a
/// colleague silently missing from every assignee field, not a little extra
/// chrome. `lib/domain/assignable_users.dart` narrows *which* users the rule
/// catches; this default is the other half of that trade.
///
/// Read live via a `ValueListenableBuilder` — `AssignedUserPickerField` and the
/// User Management roster both stay mounted behind the `/settings/**` route
/// while the switch is flipped, so a build-time read with no listener would
/// keep rendering the old answer until some unrelated rebuild.
///
/// An account preference: a sign-out forgets it, so a second user on the same
/// install never inherits a setting that silently drops colleagues out of
/// their Assigned User fields while the switch in Settings reads *off*.
class HideUnverifiedUsersController extends DevicePref<bool> {
  HideUnverifiedUsersController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.hideUnverifiedUsers, fallback: false);
}
