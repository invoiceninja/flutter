import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/repositories/auth/auth_session.dart';

/// Anchors the computed getters on [AuthSession] that the Account Management
/// Plan / Overview cards and the per-screen plan gates read. Trial math uses
/// `DateTime.now()`, so we phrase `trialStarted` / `planExpires` as offsets
/// from "now" rather than fixed timestamps.
AuthSession _session({
  String baseUrl = 'https://example.test',
  bool isHosted = true,
  String plan = '',
  String planExpires = '',
  String trialStarted = '',
  int numTrialDays = 0,
  int trialDaysLeft = -1,
  String eInvoicingToken = '',
  bool reportErrors = false,
}) => AuthSession(
  baseUrl: baseUrl,
  isHosted: isHosted,
  accountId: 'acc1',
  companies: const [],
  currentCompanyId: '',
  plan: plan,
  planExpires: planExpires,
  trialStarted: trialStarted,
  numTrialDays: numTrialDays,
  trialDaysLeft: trialDaysLeft,
  eInvoicingToken: eInvoicingToken,
  reportErrors: reportErrors,
);

void main() {
  group('AuthSession.isPaidPlanSlug', () {
    test('true for pro / enterprise / premium_business_plus', () {
      expect(_session(plan: 'pro').isPaidPlanSlug, isTrue);
      expect(_session(plan: 'enterprise').isPaidPlanSlug, isTrue);
      expect(_session(plan: 'premium_business_plus').isPaidPlanSlug, isTrue);
    });

    test('false for free / unknown / empty', () {
      expect(_session().isPaidPlanSlug, isFalse);
      expect(_session(plan: 'free').isPaidPlanSlug, isFalse);
      expect(_session(plan: 'something_else').isPaidPlanSlug, isFalse);
    });

    test('does not factor in self-hosted (slug-only)', () {
      // Self-hosted unlocks features, but the slug check is intentionally
      // strict — `canAddCompany` uses this to decide whether the hosted
      // company-count cap applies, and self-hosted has its own branch upstream.
      expect(_session(isHosted: false).isPaidPlanSlug, isFalse);
    });
  });

  group('AuthSession.isSelfHosted / isHosted', () {
    test('isSelfHosted is the inverse of isHosted', () {
      expect(_session(isHosted: true).isSelfHosted, isFalse);
      expect(_session(isHosted: false).isSelfHosted, isTrue);
    });
  });

  group('AuthSession.isProPlan / isEnterprisePlan', () {
    test('self-hosted always unlocks pro AND enterprise', () {
      // No plan slug, no expiry, no trial — pure licensing model.
      final s = _session(isHosted: false);
      expect(s.isProPlan, isTrue);
      expect(s.isEnterprisePlan, isTrue);
    });

    test('hosted pro unlocks pro but not enterprise', () {
      final s = _session(plan: 'pro');
      expect(s.isProPlan, isTrue);
      expect(s.isEnterprisePlan, isFalse);
    });

    test('hosted enterprise implies pro (enterprise unlocks both)', () {
      // Mirrors v1's `isProPlan => isEnterprisePlan || plan == kPlanPro`.
      final s = _session(plan: 'enterprise');
      expect(s.isProPlan, isTrue);
      expect(s.isEnterprisePlan, isTrue);
    });

    test('hosted free is neither', () {
      expect(_session().isProPlan, isFalse);
      expect(_session().isEnterprisePlan, isFalse);
    });

    test('expired hosted plan reverts to free', () {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      final s = _session(plan: 'pro', planExpires: yesterday);
      expect(s.isProPlan, isFalse);
      expect(s.isEnterprisePlan, isFalse);
    });

    test('future planExpires keeps the plan active', () {
      final tomorrow = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String();
      final s = _session(plan: 'pro', planExpires: tomorrow);
      expect(s.isProPlan, isTrue);
    });
  });

  group('AuthSession.isPlanExpired', () {
    test('false when planExpires is empty', () {
      expect(_session(plan: 'pro').isPlanExpired, isFalse);
    });

    test('false when self-hosted (licensing model has no plan expiry)', () {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      expect(
        _session(isHosted: false, planExpires: yesterday).isPlanExpired,
        isFalse,
      );
    });

    test('true when in the past, false when in the future', () {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      final tomorrow = DateTime.now()
          .add(const Duration(days: 1))
          .toIso8601String();
      expect(_session(planExpires: yesterday).isPlanExpired, isTrue);
      expect(_session(planExpires: tomorrow).isPlanExpired, isFalse);
    });

    test('false on malformed date string (defensive)', () {
      expect(_session(planExpires: 'not-a-date').isPlanExpired, isFalse);
    });
  });

  group('AuthSession.isPaidAccount', () {
    test('self-hosted always counts as paid', () {
      expect(_session(isHosted: false).isPaidAccount, isTrue);
    });

    test('hosted pro / enterprise, not trialing, not expired → paid', () {
      expect(_session(plan: 'pro').isPaidAccount, isTrue);
      expect(_session(plan: 'enterprise').isPaidAccount, isTrue);
    });

    test('trial subtracts: pro slug + active trial → not paid', () {
      final started = DateTime.now()
          .subtract(const Duration(days: 2))
          .toIso8601String();
      final s = _session(plan: 'pro', trialStarted: started, numTrialDays: 14);
      expect(s.isTrial, isTrue);
      expect(s.isPaidAccount, isFalse);
    });

    test('hosted free → not paid', () {
      expect(_session().isPaidAccount, isFalse);
    });
  });

  group('AuthSession.isFreePlan', () {
    test('true for hosted accounts without pro / enterprise access', () {
      expect(_session().isFreePlan, isTrue);
      expect(_session(plan: 'free').isFreePlan, isTrue);
    });

    test('false for hosted pro / enterprise', () {
      expect(_session(plan: 'pro').isFreePlan, isFalse);
      expect(_session(plan: 'enterprise').isFreePlan, isFalse);
    });

    test('false for self-hosted regardless of plan slug', () {
      expect(_session(isHosted: false).isFreePlan, isFalse);
      expect(_session(isHosted: false, plan: 'free').isFreePlan, isFalse);
    });

    test('true for expired hosted paid plan (reverts to free behavior)', () {
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      expect(_session(plan: 'pro', planExpires: yesterday).isFreePlan, isTrue);
    });
  });

  group('AuthSession.isPremiumBusinessPlusPlan', () {
    test('strict slug check, ignores hosted/self-hosted', () {
      expect(
        _session(plan: 'premium_business_plus').isPremiumBusinessPlusPlan,
        isTrue,
      );
      expect(_session(plan: 'pro').isPremiumBusinessPlusPlan, isFalse);
    });
  });

  group('AuthSession.isTrial / trialDaysRemaining', () {
    test('not in a trial when trialStarted is empty', () {
      expect(_session(numTrialDays: 14).isTrial, isFalse);
      expect(_session(numTrialDays: 14).trialDaysRemaining, 0);
    });

    test('not in a trial when numTrialDays is zero', () {
      final started = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      expect(_session(trialStarted: started).isTrial, isFalse);
      expect(_session(trialStarted: started).trialDaysRemaining, 0);
    });

    test('active trial: remaining shrinks as time passes', () {
      final started = DateTime.now()
          .subtract(const Duration(days: 3))
          .toIso8601String();
      final s = _session(trialStarted: started, numTrialDays: 14);
      expect(s.isTrial, isTrue);
      // 14 - 3 = 11 remaining (allow ±1 for boundary effects).
      expect(s.trialDaysRemaining, inInclusiveRange(10, 11));
    });

    test('expired trial: not a trial anymore, 0 days remaining', () {
      final started = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String();
      final s = _session(trialStarted: started, numTrialDays: 14);
      expect(s.isTrial, isFalse);
      expect(s.trialDaysRemaining, 0);
    });

    test('malformed trialStarted falls back to 0 remaining', () {
      final s = _session(trialStarted: 'not-a-date', numTrialDays: 14);
      expect(s.trialDaysRemaining, 0);
      expect(s.isTrial, isFalse);
    });

    test(
      'trialDaysRemaining never exceeds numTrialDays (clock skew safety)',
      () {
        // Pretend the trial started "in the future" (e.g. server clock skew).
        // Should clamp to numTrialDays rather than returning a value > total.
        final started = DateTime.now()
            .add(const Duration(days: 5))
            .toIso8601String();
        final s = _session(trialStarted: started, numTrialDays: 14);
        expect(s.trialDaysRemaining, lessThanOrEqualTo(14));
      },
    );
  });

  group('AuthSession.isDemo', () {
    test('true for the canonical demo URL', () {
      expect(_session(baseUrl: kDemoBaseUrl).isDemo, isTrue);
    });

    test('true for demo URL with trailing slash or /api/v1 suffix', () {
      // The user may have typed (or pasted) a URL with /api/v1 appended or a
      // stray trailing slash. The getter normalizes before comparing.
      expect(
        _session(baseUrl: 'https://demo.invoiceninja.com/').isDemo,
        isTrue,
      );
      expect(
        _session(baseUrl: 'https://demo.invoiceninja.com/api/v1').isDemo,
        isTrue,
      );
      expect(
        _session(baseUrl: 'https://demo.invoiceninja.com/api/v1/').isDemo,
        isTrue,
      );
      expect(
        _session(baseUrl: '  https://demo.invoiceninja.com  ').isDemo,
        isTrue,
      );
    });

    test('false for the hosted production URL', () {
      expect(_session(baseUrl: 'https://invoicing.co').isDemo, isFalse);
    });

    test('false for self-hosted / test URLs', () {
      expect(_session(baseUrl: 'https://example.test').isDemo, isFalse);
      expect(
        _session(baseUrl: 'https://my-self-host.example.com').isDemo,
        isFalse,
      );
    });
  });

  group('AuthSession.reportErrors', () {
    test('defaults to false (privacy-safe opt-in) when not supplied', () {
      expect(_session().reportErrors, isFalse);
    });

    test('round-trips through the constructor', () {
      expect(_session(reportErrors: true).reportErrors, isTrue);
    });

    test('is preserved through copyWith (account-stable, not a param)', () {
      final original = _session(reportErrors: true);
      final copy = original.copyWith(currentCompanyId: 'co_9');
      expect(copy.reportErrors, isTrue);
      expect(copy.currentCompanyId, 'co_9');
    });
  });

  group('AuthSession.eInvoicingToken', () {
    test('defaults to empty string when not supplied', () {
      expect(_session().eInvoicingToken, '');
    });

    test('round-trips through the constructor', () {
      expect(
        _session(eInvoicingToken: 'tok_abc123').eInvoicingToken,
        'tok_abc123',
      );
    });

    test('is preserved through copyWith (not part of the param surface)', () {
      // copyWith intentionally doesn't accept eInvoicingToken — the token
      // is set at login / refresh / restore time and shouldn't be edited
      // mid-session. Confirm it survives a copyWith that touches an
      // unrelated field.
      final original = _session(eInvoicingToken: 'tok_xyz');
      final copy = original.copyWith(currentCompanyId: 'co_42');
      expect(copy.eInvoicingToken, 'tok_xyz');
      expect(copy.currentCompanyId, 'co_42');
    });
  });

  group('premium_business_plus / white_label are full paid tiers', () {
    test('premium_business_plus unlocks pro AND enterprise', () {
      final s = _session(plan: 'premium_business_plus');
      expect(s.isProPlan, isTrue);
      expect(s.isEnterprisePlan, isTrue);
    });

    test('white_label unlocks pro AND enterprise', () {
      final s = _session(plan: 'white_label');
      expect(s.isProPlan, isTrue);
      expect(s.isEnterprisePlan, isTrue);
    });

    test('invariant: isPaidPlanSlug ⟹ isProPlan (no nag for payers)', () {
      for (final p in const [
        'pro',
        'enterprise',
        'premium_business_plus',
        'white_label',
      ]) {
        final s = _session(plan: p);
        expect(
          s.isPaidPlanSlug && !s.isProPlan,
          isFalse,
          reason: 'paid slug "$p" must grant pro access',
        );
      }
    });
  });

  group('AuthSession.hasProAccess / hasEnterpriseAccess (trial-aware)', () {
    test('hosted free has neither', () {
      expect(_session().hasProAccess, isFalse);
      expect(_session().hasEnterpriseAccess, isFalse);
    });

    test('active trial (server days left) unlocks pro AND enterprise', () {
      // Free slug but the server says the trial still has days — the user
      // must NOT be gated (regression vs both reference apps).
      final s = _session(trialDaysLeft: 5);
      expect(s.isTrial, isTrue);
      expect(s.isProPlan, isFalse, reason: 'slug is still free');
      expect(s.hasProAccess, isTrue);
      expect(s.hasEnterpriseAccess, isTrue);
    });

    test('expired trial (server days left 0) gates again', () {
      final s = _session(trialDaysLeft: 0);
      expect(s.isTrial, isFalse);
      expect(s.hasProAccess, isFalse);
    });

    test('paid pro has pro but not enterprise access', () {
      final s = _session(plan: 'pro');
      expect(s.hasProAccess, isTrue);
      expect(s.hasEnterpriseAccess, isFalse);
    });

    test('isFreePlan is trial-aware (false during an active trial) (R2)', () {
      expect(_session().isFreePlan, isTrue);
      expect(_session(trialDaysLeft: 4).isFreePlan, isFalse);
      expect(_session(plan: 'pro').isFreePlan, isFalse);
      expect(_session(isHosted: false).isFreePlan, isFalse);
    });
  });

  group('AuthSession.isEligibleForTrial', () {
    test('hosted, free slug, never trialed → eligible', () {
      expect(_session().isEligibleForTrial, isTrue);
    });

    test('not eligible once a trial has started', () {
      final started = DateTime.now().toIso8601String();
      expect(_session(trialStarted: started).isEligibleForTrial, isFalse);
    });

    test('not eligible on a paid slug or self-hosted', () {
      expect(_session(plan: 'pro').isEligibleForTrial, isFalse);
      expect(_session(isHosted: false).isEligibleForTrial, isFalse);
    });
  });

  group('AuthSession.trialDaysRemaining prefers the server value', () {
    test('uses server trial_days_left when provided (no client clock)', () {
      // trialStarted is empty / numTrialDays 0 — the old client-clock path
      // would return 0; the server value must win.
      expect(_session(trialDaysLeft: 9).trialDaysRemaining, 9);
    });

    test('falls back to client computation when server omits it', () {
      final started = DateTime.now()
          .subtract(const Duration(days: 2))
          .toIso8601String();
      final s = _session(trialStarted: started, numTrialDays: 14);
      expect(s.trialDaysRemaining, inInclusiveRange(11, 12));
    });
  });

  _permissionTests();
}

AuthCompany _company({
  String permissions = '',
  bool isAdmin = false,
  bool isOwner = false,
}) => AuthCompany(
  id: 'co1',
  name: 'Acme',
  displayName: 'Acme',
  permissions: permissions,
  isAdmin: isAdmin,
  isOwner: isOwner,
);

void _permissionTests() {
  group('AuthCompany.can', () {
    test('admin and owner bypass every check', () {
      expect(_company(isAdmin: true).can('view_client'), isTrue);
      expect(_company(isOwner: true).can('edit_all'), isTrue);
      expect(_company(isAdmin: true).can('view_reports'), isTrue);
    });

    test('no permissions grants nothing', () {
      expect(_company().can('view_client'), isFalse);
      expect(_company().can('view_dashboard'), isFalse);
    });

    test('exact tokens still match', () {
      final c = _company(permissions: 'view_client,create_invoice');
      expect(c.can('view_client'), isTrue);
      expect(c.can('create_invoice'), isTrue);
      expect(c.can('view_product'), isFalse);
    });

    test('<verb>_all grants every entity for that verb — this is how the '
        'permission editor stores a whole column', () {
      final c = _company(permissions: 'view_all,create_all,edit_all');
      expect(c.can('view_client'), isTrue);
      expect(c.can('create_invoice'), isTrue);
      expect(c.can('edit_recurring_expense'), isTrue);
    });

    test('view_all does not leak across verbs', () {
      final c = _company(permissions: 'view_all');
      expect(c.can('view_invoice'), isTrue);
      expect(c.can('create_invoice'), isFalse);
      expect(c.can('edit_invoice'), isFalse);
    });

    test('edit implies view (server User::hasPermission parity)', () {
      expect(_company(permissions: 'edit_invoice').can('view_invoice'), isTrue);
      expect(_company(permissions: 'edit_all').can('view_client'), isTrue);
      // …but only for the same entity.
      expect(_company(permissions: 'edit_invoice').can('view_client'), isFalse);
    });

    test('delete resolves as edit — there is no delete_* token and the server '
        'authorizes destroy through EntityPolicy::edit', () {
      expect(
        _company(permissions: 'edit_invoice').can('delete_invoice'),
        isTrue,
      );
      expect(_company(permissions: 'edit_all').can('delete_quote'), isTrue);
      expect(
        _company(permissions: 'view_invoice').can('delete_invoice'),
        isFalse,
      );
    });

    test('multi-underscore entities split on the FIRST underscore only', () {
      final c = _company(permissions: 'view_recurring_invoice');
      expect(c.can('view_recurring_invoice'), isTrue);
      // Must not leak to the other `recurring_*` entity.
      expect(c.can('view_recurring_expense'), isFalse);
      expect(c.can('view_invoice'), isFalse);
    });

    test('special toggles stay exact-token — view_all must not unlock the '
        'dashboard or Reports (React parity)', () {
      final c = _company(permissions: 'view_all,edit_all');
      expect(c.can('view_dashboard'), isFalse);
      expect(c.can('view_reports'), isFalse);
      expect(
        _company(permissions: 'view_dashboard').can('view_dashboard'),
        isTrue,
      );
    });
  });

  group('AuthSession.isWhiteLabelLapsed', () {
    // Offsets from `now`, never literal calendar days: CI runs UTC and the dev
    // machines don't, so a fixed date would flip across the boundary.
    String daysFromNow(int days) =>
        DateTime.now().add(Duration(days: days)).toIso8601String();

    test('blanked slug + a past expiry reads as lapsed', () {
      // Exactly what the server sends once a license runs out: `getPlan()`
      // returns '' while `plan_expires` is still transmitted raw, which is the
      // only way to tell "renew" from "never bought one".
      final s = _session(isHosted: false, planExpires: daysFromNow(-30));
      expect(s.isWhiteLabeled, isFalse);
      expect(s.isWhiteLabelLapsed, isTrue);
    });

    test('a live license is not lapsed', () {
      final s = _session(
        isHosted: false,
        plan: 'white_label',
        planExpires: daysFromNow(30),
      );
      expect(s.isWhiteLabelLapsed, isFalse);
    });

    test('the slug wins over a stale date — it is server-authoritative', () {
      final s = _session(
        isHosted: false,
        plan: 'white_label',
        planExpires: daysFromNow(-1),
      );
      expect(s.isWhiteLabelLapsed, isFalse);
    });

    test('never licensed (no date at all) is not lapsed', () {
      expect(_session(isHosted: false).isWhiteLabelLapsed, isFalse);
    });

    test('an unparseable date is not lapsed', () {
      final s = _session(isHosted: false, planExpires: 'not-a-date');
      expect(s.isWhiteLabelLapsed, isFalse);
    });

    test('a MySQL zero-date is never-licensed, not lapsed', () {
      // The trap: `DateTime.tryParse('0000-00-00')` returns year -1, NOT
      // null, so a bare parse tells someone who never bought a license that
      // theirs expired. React guards the same way (`year() > 2000`).
      final s = _session(isHosted: false, planExpires: '0000-00-00');
      expect(s.planExpiresDate, isNull);
      expect(s.isWhiteLabelLapsed, isFalse);
    });

    test('a migrated-v4 epoch sentinel is not lapsed either', () {
      final s = _session(isHosted: false, planExpires: '1970-01-01');
      expect(s.isWhiteLabelLapsed, isFalse);
    });

    test('the sentinel boundary is year 2000 inclusive', () {
      expect(
        _session(isHosted: false, planExpires: '2000-12-31').planExpiresDate,
        isNull,
      );
      expect(
        _session(isHosted: false, planExpires: '2001-01-01').planExpiresDate,
        isNotNull,
      );
    });

    test('hosted never reports lapsed — that is isPlanExpired\'s job', () {
      final s = _session(
        isHosted: true,
        plan: 'pro',
        planExpires: daysFromNow(-30),
      );
      expect(s.isWhiteLabelLapsed, isFalse);
      expect(s.isPlanExpired, isTrue);
    });
  });
}
