import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/welcome.dart';

/// Who the first-run experience is for (docs/first-run-welcome.md): decided
/// once, at an interactive sign-in, from what the login response says.
void main() {
  SignInFacts facts({
    bool isSignup = false,
    List<Map<String, dynamic>> settings = const [],
    List<Map<String, dynamic>?> react = const [],
  }) => SignInFacts(
    userKey: 'https://invoicing.co#u1',
    isSignup: isSignup,
    companyUserSettings: settings,
    reactSettings: react,
    companyCount: 1,
  );

  group('decideWelcome', () {
    test('a sign-up is a new account — the wizard is its welcome', () {
      expect(decideWelcome(facts(isSignup: true)), WelcomeKind.newAccount);
    });

    test('an account with no sign of the previous app gets Get started', () {
      expect(decideWelcome(facts()), WelcomeKind.existingAccount);
    });

    for (final key in kOldAppSettingsKeys) {
      test('the previous app\'s "$key" opens What\'s changed', () {
        expect(
          decideWelcome(
            facts(
              settings: [
                {},
                {key: 2},
              ],
            ),
          ),
          WelcomeKind.fromOldApp,
        );
      });
    }

    test('keys React also writes are no evidence of the previous app', () {
      // React's user-create screen writes these for every user it makes.
      expect(
        decideWelcome(
          facts(
            settings: [
              {
                'report_settings': <String, dynamic>{},
                'number_years_active': 3,
                'include_deleted_clients': false,
                'table_columns': <String, dynamic>{},
                'accent_color': '#000',
              },
            ],
          ),
        ),
        WelcomeKind.existingAccount,
      );
    });

    test('a user the server says was welcomed is not greeted again', () {
      expect(
        decideWelcome(
          facts(
            react: [
              null,
              {
                kWelcomeReactSettingsKey: {'v': 1},
              },
            ],
          ),
        ),
        isNull,
      );
    });

    test('a user who already runs this app elsewhere is not greeted', () {
      expect(
        decideWelcome(
          facts(
            settings: [
              {'dashboard_fields_per_row_mobile': 2},
            ],
            react: [
              {kOwnReactSettingsKey: <String, dynamic>{}},
            ],
          ),
        ),
        isNull,
      );
    });

    test('a sign-up wins even over a server flag', () {
      expect(
        decideWelcome(
          facts(
            isSignup: true,
            react: [
              {kWelcomeReactSettingsKey: <String, dynamic>{}},
            ],
          ),
        ),
        WelcomeKind.newAccount,
      );
    });
  });

  test('the user key names the server, canonicalised, and the user', () {
    expect(
      welcomeUserKey('https://invoicing.co/', 'u1'),
      welcomeUserKey('https://invoicing.co', 'u1'),
    );
    expect(
      welcomeUserKey('https://a.example', 'u1'),
      isNot(welcomeUserKey('https://b.example', 'u1')),
    );
  });

  test('wire names round-trip', () {
    for (final k in WelcomeKind.values) {
      expect(WelcomeKind.fromWire(k.wireName), k);
    }
    expect(WelcomeKind.fromWire('nope'), isNull);
  });
}
