import 'package:flutter/foundation.dart';

import 'package:admin/data/repositories/auth/auth_helpers.dart';

/// Who the first-run experience is for (docs/first-run-welcome.md).
///
/// [newAccount] gets the setup wizard and the dashboard checklist and never
/// the Welcome; the other two get the Welcome, opened on a different list.
enum WelcomeKind {
  /// Just signed up: the wizard and checklist are the welcome.
  newAccount('new_account'),

  /// An account that existed before this app, with no sign of the previous
  /// app: the Welcome opens on Get started.
  existingAccount('existing_account'),

  /// An account whose settings carry a key only the previous Flutter app
  /// writes: the Welcome opens on What's changed.
  fromOldApp('from_old_app');

  const WelcomeKind(this.wireName);

  final String wireName;

  static WelcomeKind? fromWire(Object? raw) {
    for (final k in values) {
      if (k.wireName == raw) return k;
    }
    return null;
  }
}

/// This app's own namespace in `company_user.react_settings` — the dashboard
/// syncs its cards and panels under it. Its presence means the user has run
/// this app somewhere.
const String kOwnReactSettingsKey = 'flutter_dashboard';

/// Written by the Welcome when it is closed, so a second device or a browser
/// with cleared storage does not greet the user again.
const String kWelcomeReactSettingsKey = 'flutter_welcome';

/// `company_user.settings` keys written **only** by the previous Flutter app
/// (admin-portal's `UserSettingsEntity`). React's user-create screen also
/// writes `report_settings`, `number_years_active` and
/// `include_deleted_clients` for every user it creates, so those are no
/// evidence and are deliberately absent. Present only when the user changed
/// the dashboard layout there; most previous-app users leave no trace, which
/// is why the guess only picks the Welcome's first list.
const Set<String> kOldAppSettingsKeys = {
  'dashboard_fields_per_row_mobile',
  'dashboard_fields_per_row_desktop',
};

/// The identity a Welcome record is filed under: the server and the user id,
/// since a hashed id is only unique within one server.
String welcomeUserKey(String baseUrl, String userId) =>
    '${canonicalBaseUrl(baseUrl)}#$userId';

/// What an interactive sign-in told us, read from the response while it is in
/// hand. Nothing here is persisted; only the decision is.
@immutable
class SignInFacts {
  const SignInFacts({
    required this.userKey,
    required this.isSignup,
    this.companyUserSettings = const [],
    this.reactSettings = const [],
    this.companyCount = 0,
  });

  final String userKey;

  /// The sign-in created the account (`/signup`, or an OAuth `create`).
  final bool isSignup;

  /// Every company's `company_user.settings`.
  final List<Map<String, dynamic>> companyUserSettings;

  /// Every company's `company_user.react_settings`; null where the response
  /// did not carry it.
  final List<Map<String, dynamic>?> reactSettings;

  final int companyCount;

  bool get hasOldAppFingerprint =>
      companyUserSettings.any((s) => s.keys.any(kOldAppSettingsKeys.contains));

  /// The server remembers this user seeing the Welcome, or running this app.
  bool get serverSaysWelcomed => reactSettings.any(
    (s) =>
        s != null &&
        (s.containsKey(kWelcomeReactSettingsKey) ||
            s.containsKey(kOwnReactSettingsKey)),
  );
}

/// What a sign-in decides for a user the record does not know yet: null when
/// there is nothing to show (the server says they were welcomed already).
WelcomeKind? decideWelcome(SignInFacts facts) {
  if (facts.isSignup) return WelcomeKind.newAccount;
  if (facts.serverSaysWelcomed) return null;
  if (facts.hasOldAppFingerprint) return WelcomeKind.fromOldApp;
  return WelcomeKind.existingAccount;
}
