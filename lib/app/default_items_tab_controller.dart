import 'package:admin/data/prefs/device_pref.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// `products` — the Products items tab.
const String kItemsTabProducts = 'products';

/// `tasks` — the Tasks items tab.
const String kItemsTabTasks = 'tasks';

/// Owns "which items tab does a billing document open on"
/// (`DevicePrefKeys.defaultItemsTab`, React #3355). Consulted only when the
/// document's own lines don't decide — see `BillingDocItemsTabs._initialKind`.
/// Defaults to Products, which is what every document opened on before.
class DefaultItemsTabController extends DevicePref<String> {
  DefaultItemsTabController({required DevicePrefsStore prefs})
    : super(prefs, DevicePrefKeys.defaultItemsTab, fallback: kItemsTabProducts);

  bool get prefersTasks => value == kItemsTabTasks;
}
