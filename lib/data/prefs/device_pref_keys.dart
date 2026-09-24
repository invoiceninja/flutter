/// Whether a device preference belongs to the device or to whoever is signed
/// in — which decides whether wiping local data forgets it.
enum PrefScope {
  /// Kept when local data is wiped (a deliberate sign-out, or another identity
  /// signing in): how the app looks and responds on this device.
  device,

  /// Forgotten with the signed-in user's data: it describes their account —
  /// its entities, roster, dashboard or companies — and the next person to
  /// sign in on this device must not inherit it.
  account,
}

/// How a preference's value is written to its `device_prefs` row.
sealed class PrefCodec<T extends Object> {
  const PrefCodec();

  static const PrefCodec<String> string = _StringCodec();
  static const PrefCodec<bool> boolean = _BoolCodec();
  static const PrefCodec<double> decimal = _DoubleCodec();

  String encode(T value);

  /// Null when [raw] isn't a [T] — written by a newer build, say — which reads
  /// exactly like a preference that was never set.
  T? decode(String raw);
}

final class _StringCodec extends PrefCodec<String> {
  const _StringCodec();

  @override
  String encode(String value) => value;

  @override
  String decode(String raw) => raw;
}

/// `'1'` / `'0'` — also what SQLite made of the `nav_state` BOOLEAN columns
/// when v12 copied them into the TEXT `value` column.
final class _BoolCodec extends PrefCodec<bool> {
  const _BoolCodec();

  @override
  String encode(bool value) => value ? '1' : '0';

  @override
  bool? decode(String raw) => switch (raw) {
    '1' || 'true' => true,
    '0' || 'false' => false,
    _ => null,
  };
}

final class _DoubleCodec extends PrefCodec<double> {
  const _DoubleCodec();

  @override
  String encode(double value) => value.toString();

  @override
  double? decode(String raw) => double.tryParse(raw);
}

/// One device preference: the name of its `device_prefs` row, how its value
/// is encoded there, and whether a data wipe forgets it.
final class PrefKey<T extends Object> {
  const PrefKey(this.name, this.codec, this.scope);

  final String name;
  final PrefCodec<T> codec;
  final PrefScope scope;

  @override
  String toString() => 'PrefKey($name)';
}

/// A reserved `device_prefs` row: present once the store's `nav_state`
/// preference columns have been copied into `device_prefs`
/// (`carryNavStatePrefs`). Never a preference, and never wiped.
const String kPrefsCarriedFromNavState = '_carried_from_nav_state';

/// Every device preference. Adding one is adding a key here — no schema
/// change, no migration. A name is a row on installed devices, so it is never
/// renamed or reused (`test/data/prefs/device_pref_keys_test.dart`).
abstract final class DevicePrefKeys {
  // The seventeen that were `nav_state` columns through schema v11. Each row
  // is named after its column, so v12 could copy them across by name.
  static const locale = PrefKey<String>(
    'locale',
    PrefCodec.string,
    PrefScope.device,
  );
  static const themeMode = PrefKey<String>(
    'theme_mode',
    PrefCodec.string,
    PrefScope.device,
  );
  static const lightVariant = PrefKey<String>(
    'light_variant',
    PrefCodec.string,
    PrefScope.device,
  );
  static const darkVariant = PrefKey<String>(
    'dark_variant',
    PrefCodec.string,
    PrefScope.device,
  );
  static const customTheme = PrefKey<String>(
    'custom_theme_json',
    PrefCodec.string,
    PrefScope.device,
  );
  static const textScale = PrefKey<double>(
    'text_scale',
    PrefCodec.decimal,
    PrefScope.device,
  );
  static const keyboardShortcuts = PrefKey<String>(
    'keyboard_shortcuts_json',
    PrefCodec.string,
    PrefScope.device,
  );
  static const sidebarBadgeModes = PrefKey<String>(
    'sidebar_badge_modes_json',
    PrefCodec.string,
    PrefScope.account,
  );
  static const confirmActions = PrefKey<bool>(
    'confirm_actions',
    PrefCodec.boolean,
    PrefScope.account,
  );
  static const statusTabs = PrefKey<bool>(
    'status_tabs',
    PrefCodec.boolean,
    PrefScope.device,
  );
  static const contactsSync = PrefKey<String>(
    'contacts_sync_json',
    PrefCodec.string,
    PrefScope.account,
  );
  static const phoneActions = PrefKey<String>(
    'phone_actions_json',
    PrefCodec.string,
    PrefScope.device,
  );
  static const sidebarMenu = PrefKey<String>(
    'sidebar_menu_json',
    PrefCodec.string,
    PrefScope.account,
  );
  static const tasksView = PrefKey<String>(
    'tasks_view',
    PrefCodec.string,
    PrefScope.account,
  );
  static const hideUnverifiedUsers = PrefKey<bool>(
    'hide_unverified_users',
    PrefCodec.boolean,
    PrefScope.account,
  );
  static const hideEmptyPanels = PrefKey<bool>(
    'hide_empty_panels',
    PrefCodec.boolean,
    PrefScope.account,
  );
  static const sidebarCollapsed = PrefKey<bool>(
    'sidebar_collapsed',
    PrefCodec.boolean,
    PrefScope.device,
  );

  /// In the order they were added; append new keys at the end.
  static const List<PrefKey<Object>> all = [
    locale,
    themeMode,
    lightVariant,
    darkVariant,
    customTheme,
    textScale,
    keyboardShortcuts,
    sidebarBadgeModes,
    confirmActions,
    statusTabs,
    contactsSync,
    phoneActions,
    sidebarMenu,
    tasksView,
    hideUnverifiedUsers,
    hideEmptyPanels,
    sidebarCollapsed,
  ];

  /// The rows a data wipe leaves in place: the [PrefScope.device] keys and the
  /// carry marker. Anything else — an account key, or a key this build does
  /// not know (written by a newer one) — is forgotten, the safe answer when
  /// the next person to sign in may be someone else.
  static final Set<String> keptOnWipe = {
    for (final key in all)
      if (key.scope == PrefScope.device) key.name,
    kPrefsCarriedFromNavState,
  };
}
