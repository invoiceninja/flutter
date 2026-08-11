// Pins the Plan card's headline key per session type.
//
// The self-hosted branch is the point: the screen used to render a bare "Free"
// for every self-hosted install (issue #27), which reads as a downgrade on an
// install where every feature is in fact unlocked, and said nothing about the
// white-label license the user may have bought.
//
// The slug cases below are not hypothetical — the server writes all three.
// `LicenseController` sets `plan = 'white_label'` on a successful claim and
// resets it to `'free'` on a failed one, while `Account::getPlan()` returns
// `''` once `plan_expires` is past. That's why the check is a slug match and
// not `plan.isEmpty`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/plan_screen.dart';

AuthSession _session({required bool isHosted, String plan = ''}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: isHosted,
  accountId: 'acct',
  companies: const [],
  currentCompanyId: '',
  plan: plan,
);

void main() {
  group('planHeadlineKey — self-hosted reports license state', () {
    test('an active white-label license reads as white labeled', () {
      expect(
        planHeadlineKey(_session(isHosted: false, plan: 'white_label')),
        'plan_white_label',
      );
    });

    test('no license (empty slug) reads as free', () {
      expect(
        planHeadlineKey(_session(isHosted: false)),
        'plan_free_self_hosted',
      );
    });

    test('a failed claim (plan reset to "free") reads as free', () {
      expect(
        planHeadlineKey(_session(isHosted: false, plan: 'free')),
        'plan_free_self_hosted',
      );
    });
  });

  group('planHeadlineKey — hosted still reports the plan slug', () {
    test('empty slug is the free plan', () {
      expect(planHeadlineKey(_session(isHosted: true)), 'free');
    });

    test('paid slugs pass through as their own label key', () {
      for (final slug in ['pro', 'enterprise', 'premium_business_plus']) {
        expect(planHeadlineKey(_session(isHosted: true, plan: slug)), slug);
      }
    });

    test('white_label on hosted is not rewritten to the self-hosted copy', () {
      expect(
        planHeadlineKey(_session(isHosted: true, plan: 'white_label')),
        'white_label',
      );
    });
  });

  group('AuthSession.isWhiteLabeled', () {
    test('matches the white_label slug only', () {
      expect(
        _session(isHosted: false, plan: 'white_label').isWhiteLabeled,
        isTrue,
      );
      for (final slug in ['', 'free', 'pro', 'enterprise']) {
        expect(_session(isHosted: false, plan: slug).isWhiteLabeled, isFalse);
      }
    });
  });

  test('both self-hosted headline keys ship in en.json', () {
    // These come from Transifex, not `_app_pending.json` — a rename upstream
    // would silently render the raw key as the headline. Assert presence, not
    // the wording: `assets/i18n/*.json` is regenerated from Transifex every
    // release, so pinning the English copy would red-build CI on a routine
    // translator edit that breaks nothing.
    final strings =
        jsonDecode(File('assets/i18n/en.json').readAsStringSync())
            as Map<String, dynamic>;
    for (final key in ['plan_white_label', 'plan_free_self_hosted']) {
      expect(strings, contains(key));
      expect(
        strings[key],
        isA<String>().having((s) => s.isEmpty, 'empty', isFalse),
      );
    }
  });
}
