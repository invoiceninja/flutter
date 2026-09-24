import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// Owns the user's "show the status tab strip above lists" preference
/// (`DevicePrefKeys.statusTabs`, device-local).
///
/// Defaults to **on**. invoiceninja/flutter#98 asked for the strip precisely
/// because surfacing a draft through the search field's filter menu is three or
/// four taps; shipping it off by default would leave that cost in place for
/// everyone who never opens Settings. The switch is for people who would rather
/// have the vertical space back.
///
/// Turning it off hides the strip but does **not** clear an active tab — a list
/// can still be narrowed by a `badge_mode` restored from `nav_state` or applied
/// by a saved view. `EntityListScreenScaffold` therefore renders the strip
/// whenever a tab is active regardless of this flag, so a live filter always has
/// visible UI to clear it with.
class StatusTabsController extends DevicePref<bool> {
  StatusTabsController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.statusTabs, fallback: true);
}
