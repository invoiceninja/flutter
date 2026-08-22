import 'package:flutter/foundation.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/permissions.dart'
    show kPermissionNegative, kPermissionSpecial;

/// Hard cap on companies per account (matches admin-portal's UI limit).
const int kMaxCompaniesPerAccount = 10;

/// Hosted demo server. `AuthSession.isDemo` compares the session's `baseUrl`
/// against this — sessions logged into the demo can't toggle the UI language
/// (would break the demo's scripted tour). Mirrors admin-portal's
/// `kFlutterDemoUrl`.
const String kDemoBaseUrl = 'https://demo.invoiceninja.com';

/// Why "New Company" is unavailable, or `ok` if it is. The picker renders
/// the matching reason as an inline subtitle on the disabled row.
enum CanAddCompanyResult { ok, notOwner, capReached, hostedPlanLimit, demoMode }

/// What the rest of the app sees about the current login. Held as a single
/// immutable value so the shell can listen via `AuthRepository.session`.
@immutable
class AuthSession {
  const AuthSession({
    required this.baseUrl,
    required this.isHosted,
    required this.accountId,
    required this.companies,
    required this.currentCompanyId,
    this.plan = '',
    this.planExpires = '',
    this.trialPlan = '',
    this.trialStarted = '',
    this.numTrialDays = 0,
    this.trialDaysLeft = -1,
    this.hasIapPlan = false,
    this.defaultCompanyId = '',
    this.hostedClientCount = 0,
    this.hostedCompanyCount = 0,
    this.userId = '',
    this.userEmail = '',
    this.userPhone = '',
    this.userFirstName = '',
    this.userLastName = '',
    this.googleTwoFactorEnabled = false,
    this.verifiedPhoneNumber = false,
    this.biometricEnabled = false,
    this.referralCode = '',
    this.referralMeta = const <String, int>{},
    this.ninjaPortalUrl = '',
    this.eInvoicingToken = '',
    this.reportErrors = false,
  });

  final String baseUrl;
  final bool isHosted;
  final String accountId;

  /// Sorted by display name; UI uses this for the company switcher.
  final List<AuthCompany> companies;

  final String currentCompanyId;

  /// Account plan slug, e.g. `pro`, `enterprise`, `premium_business_plus`,
  /// `` (free). Drives whether the hosted company-count limit gates "New
  /// Company" and what the Account Management → Plan card shows.
  final String plan;

  /// ISO date string for when the paid plan expires. Empty on a free plan and
  /// on an unlicensed self-hosted install; on a self-hosted install with a
  /// white-label license it carries the *license* expiry (see
  /// [isWhiteLabeled]). Decoded from `account.plan_expires` in the login
  /// envelope.
  final String planExpires;

  /// Plan slug the user is currently trialing (e.g. `pro`). Empty when no
  /// trial is active. Server populates only while `trial_started` is set.
  final String trialPlan;

  /// ISO datetime string for when the active trial started (hosted only).
  /// Empty when no trial is in progress.
  final String trialStarted;

  /// How many days long the active trial was provisioned for. Used together
  /// with [trialStarted] to render the trial-countdown progress bar.
  final int numTrialDays;

  /// Server-authoritative trial days remaining. `-1` = the server didn't
  /// send `trial_days_left` (fall back to the client-clock computation in
  /// [trialDaysRemaining]). Preferring the server value keeps a long-offline
  /// or midnight-rollover session from false-locking a trialing user.
  final int trialDaysLeft;

  /// True when the subscription is managed by an App Store / Play in-app
  /// purchase. IAP subscribers must be routed to store-managed billing
  /// (Apple/Google forbid us cancelling/altering their subscription from a
  /// web portal). Mirrors admin-portal's `account.has_iap_plan`.
  final bool hasIapPlan;

  /// The account-level default company — what new sessions land on when no
  /// per-device override is set. Drives the "Set default company" button on
  /// Account Management → Overview: visible when the active company differs.
  final String defaultCompanyId;

  /// On hosted free / trial plans, the max number of clients the account
  /// can hold. `0` on paid plans (no cap) and self-hosted.
  final int hostedClientCount;

  /// On hosted free / trial plans, the max number of companies the account's
  /// plan allows. `0` on paid plans (no cap) and self-hosted. Together with
  /// [companies] this drives the `canAddCompany` gate.
  final int hostedCompanyCount;

  /// Authenticated user's id (`users.id`), used to address `/company_users/{id}`.
  final String userId;
  final String userEmail;
  final String userPhone;

  /// User-level name fields. Populated in `_persistAndActivate` from the login
  /// envelope's `UserApi.first_name`/`last_name` (and recovered from Drift in
  /// `restore()` when offline), plus refreshed after Settings > User Details
  /// edits. The topbar / company picker fall back to email when both are blank.
  final String userFirstName;
  final String userLastName;

  /// True when the user has Google Authenticator–style 2FA enabled. Drives
  /// the enable-vs-disable branch of the 2FA settings screen.
  final bool googleTwoFactorEnabled;

  /// True when the user has completed SMS phone verification. On hosted this
  /// is the gate the server enforces before showing the QR setup; self-hosted
  /// skips the check.
  final bool verifiedPhoneNumber;

  /// User preference: gate cold launches with a biometric (FaceID / TouchID)
  /// prompt. Persisted via `kAuthBiometricEnabledKey`. The transient "we are
  /// currently locked" flag lives on `AuthRepository.requiresBiometricUnlock`
  /// — separating "preference" from "current state" keeps both observable
  /// without conflating them.
  final bool biometricEnabled;

  /// Referral program data — hosted-only. `referralCode` slots into the
  /// referral URL `https://app.invoicing.co/#/register?rc=<code>`;
  /// `referralMeta` is the per-plan count map (`{free: 12, pro: 3, ...}`).
  /// Both are empty on self-hosted and on cold restore (we don't persist
  /// them — fresh login refills them).
  final String referralCode;
  final Map<String, int> referralMeta;

  /// Pre-signed URL for the user's hosted billing portal. Empty on
  /// self-hosted and on cold restore (we don't persist it; fresh login
  /// refills). Hosted users land here from Account Management → Plan
  /// → "Manage Plan" / "Upgrade Plan" / "Change Plan".
  final String ninjaPortalUrl;

  /// PEPPOL e-invoicing token issued by the upstream provider when the
  /// account onboarded. Empty when the account hasn't connected to PEPPOL
  /// (the demo account is one such case — `e_invoicing_token` is omitted
  /// from `data[N].account` entirely). Required in the body of
  /// `POST /einvoice/peppol/disconnect` (and `/setup`, when that flow
  /// lands). Mirrors React's `account.e_invoicing_token`.
  final String eInvoicingToken;

  /// Account opt-in for remote (Sentry) error reporting. False = do not
  /// transmit (privacy-safe default; mirrors v1's `account.report_errors`
  /// "drop unless true" gate). Read by `main.dart`'s Sentry `beforeSend`.
  final bool reportErrors;

  AuthCompany? get currentCompany {
    for (final c in companies) {
      if (c.id == currentCompanyId) return c;
    }
    return companies.isEmpty ? null : companies.first;
  }

  /// Convenience: self-hosted is everything-not-hosted. Self-hosted accounts
  /// always unlock pro + enterprise features (they paid via licensing); the
  /// plan slug only matters on the hosted invoiceninja.com tier. Mirrors
  /// admin-portal's `isSelfHosted` and React's `isSelfHosted()` short-circuit.
  bool get isSelfHosted => !isHosted;

  /// Hosted plan whose `plan_expires` is in the past. False when empty
  /// (free / never-paid) or unparseable, false unconditionally on
  /// self-hosted. Used by the feature-access getters below so an expired
  /// hosted Pro account behaves like Free.
  bool get isPlanExpired {
    if (!isHosted) return false;
    if (planExpires.isEmpty) return false;
    final dt = DateTime.tryParse(planExpires);
    if (dt == null) return false;
    return dt.isBefore(DateTime.now());
  }

  /// Paid hosted slugs that unlock Pro-tier features. `premium_business_plus`
  /// and `white_label` are top tiers — they unlock everything Pro does (and
  /// Enterprise; see [_kEnterpriseSlugs]). Keeping the slug sets as the single
  /// source the three getters below share guarantees the invariant
  /// `isPaidPlanSlug ⟹ isProPlan` (enforced by a unit test) and prevents the
  /// `premium_business_plus` asymmetry that previously nagged paying
  /// customers to upgrade.
  static const Set<String> _kProSlugs = {
    'pro',
    'enterprise',
    'premium_business_plus',
    'white_label',
  };

  /// Paid hosted slugs that unlock Enterprise-tier features. Strict subset of
  /// [_kProSlugs] minus plain `pro`.
  static const Set<String> _kEnterpriseSlugs = {
    'enterprise',
    'premium_business_plus',
    'white_label',
  };

  /// Slug-only check: is the hosted plan field one of the paid tiers? This is
  /// the question `canAddCompany` asks to decide whether the hosted
  /// company-count cap applies. Does NOT factor in self-hosted or expiry —
  /// use [isProPlan] / [isEnterprisePlan] / [isPaidAccount] for feature gating.
  bool get isPaidPlanSlug => _kProSlugs.contains(plan);

  /// True when the user has Pro-tier feature access. Self-hosted always
  /// unlocks; on hosted, requires a paid slug and a non-expired plan. Matches
  /// admin-portal's `isProPlan => isEnterprisePlan || plan == kPlanPro`
  /// (enterprise implies pro) and React's `proPlan() || enterprisePlan()`.
  /// NOTE: does not include trial — use [hasProAccess] for feature gating so
  /// trialing users aren't locked out.
  bool get isProPlan =>
      isSelfHosted || (_kProSlugs.contains(plan) && !isPlanExpired);

  /// True when the user has Enterprise-tier feature access. Self-hosted
  /// always unlocks; on hosted, requires an enterprise-tier slug and a
  /// non-expired plan. Use [hasEnterpriseAccess] for gating (trial-aware).
  bool get isEnterprisePlan =>
      isSelfHosted || (_kEnterpriseSlugs.contains(plan) && !isPlanExpired);

  bool get isPremiumBusinessPlusPlan => plan == 'premium_business_plus';

  /// True when a white-label license is active. This is the only paid state a
  /// self-hosted install has — the server sets `plan = 'white_label'` on a
  /// successful `/claim_license` (`LicenseController`) and clears `plan` once
  /// the license lapses (`Account::getPlan()`), so an expired license reads
  /// false here. A *failed* claim leaves `plan == 'free'`, which is why this
  /// is a slug match rather than a `plan.isNotEmpty` check.
  ///
  /// Display-only: self-hosted feature access is unconditional (see
  /// [isProPlan] / [isEnterprisePlan]) whether or not a license is applied.
  bool get isWhiteLabeled => plan == 'white_label';

  /// Trial-aware Pro gate — **this is what feature gating should call**, not
  /// [isProPlan]. Trialing hosted users get full Pro features for free
  /// (parity with admin-portal's `!isProPlan && !isTrial` gate predicates),
  /// so locking them out on `isProPlan` alone is a regression.
  bool get hasProAccess => isProPlan || isTrial;

  /// Trial-aware Enterprise gate — the gating counterpart to [hasProAccess].
  bool get hasEnterpriseAccess => isEnterprisePlan || isTrial;

  /// True when the account can still start a free trial: hosted, on the free
  /// (empty) slug, and never started one. Drives the "Start free trial" vs
  /// "Upgrade" copy split. Mirrors admin-portal's
  /// `isEligibleForTrial => trialStarted.isEmpty && plan == kPlanFree`.
  bool get isEligibleForTrial =>
      isHosted && plan.isEmpty && trialStarted.isEmpty;

  /// True when the user is "actually paying" — pro/enterprise feature access
  /// AND not currently inside a free trial. Used by trial banners to decide
  /// whether to keep nudging. Differs from [isProPlan] in that trial users
  /// (who get pro features for free) read `false` here.
  bool get isPaidAccount => isSelfHosted || (isProPlan && !isTrial);

  /// True on hosted accounts with no pro / enterprise feature access — i.e.
  /// the audience for the upgrade banner and sidebar lock icons. Always
  /// false on self-hosted (everything unlocked) and on paid / trialing
  /// hosted plans. Uses the trial-aware [hasProAccess] so a trialing user
  /// (who has full features) is not classed as free — matches `planGateFor`.
  bool get isFreePlan => isHosted && !hasProAccess;

  /// True when this session is logged into the hosted demo
  /// (`demo.invoiceninja.com`). Drives the language gate on Settings →
  /// Localization. Mirrors admin-portal's `AppState.isDemo`. Note this is a
  /// per-session flag, distinct from `Env.demoMode` (the build-time toggle
  /// that hard-blocks mutating endpoints regardless of which server the
  /// session is talking to).
  bool get isDemo {
    final normalized = baseUrl
        .trim()
        .replaceFirst(RegExp(r'/api/v1'), '')
        .replaceFirst(RegExp(r'/$'), '');
    return normalized == kDemoBaseUrl;
  }

  /// True when a trial is currently active: server sent a non-empty
  /// `trial_started`, and the elapsed days are still within `numTrialDays`.
  /// Returning the boolean is cheap; the UI uses [trialDaysRemaining] when
  /// it needs the actual countdown value.
  bool get isTrial {
    if (trialDaysLeft >= 0) return trialDaysLeft > 0;
    if (trialStarted.isEmpty || numTrialDays <= 0) return false;
    return trialDaysRemaining > 0;
  }

  /// Days left in the active trial, clamped to `[0, numTrialDays]`. Prefers
  /// the server-authoritative [trialDaysLeft] so a long-offline /
  /// midnight-rollover session doesn't false-lock a trialing user; falls
  /// back to the client-clock estimate when the server didn't send it.
  /// Returns 0 when no trial is in progress so callers can render without a
  /// null-check.
  int get trialDaysRemaining {
    if (trialDaysLeft >= 0) return trialDaysLeft;
    if (trialStarted.isEmpty || numTrialDays <= 0) return 0;
    final started = DateTime.tryParse(trialStarted);
    if (started == null) return 0;
    final elapsed = DateTime.now().difference(started).inDays;
    final remaining = numTrialDays - elapsed;
    if (remaining < 0) return 0;
    if (remaining > numTrialDays) return numTrialDays;
    return remaining;
  }

  /// First-failing reason for adding a new company, or `ok` when allowed.
  /// Order: demo build > not owner > hard cap > hosted plan limit.
  CanAddCompanyResult get canAddCompany {
    if (Env.demoMode) return CanAddCompanyResult.demoMode;
    final me = currentCompany;
    if (me == null || !me.isOwner) return CanAddCompanyResult.notOwner;
    if (companies.length >= kMaxCompaniesPerAccount) {
      return CanAddCompanyResult.capReached;
    }
    if (isHosted && !isPaidPlanSlug && companies.length >= hostedCompanyCount) {
      return CanAddCompanyResult.hostedPlanLimit;
    }
    return CanAddCompanyResult.ok;
  }

  AuthSession copyWith({
    String? currentCompanyId,
    List<AuthCompany>? companies,
    String? defaultCompanyId,
    bool? googleTwoFactorEnabled,
    bool? verifiedPhoneNumber,
    String? userPhone,
    String? userEmail,
    String? userFirstName,
    String? userLastName,
    bool? biometricEnabled,
  }) => AuthSession(
    baseUrl: baseUrl,
    isHosted: isHosted,
    accountId: accountId,
    companies: companies ?? this.companies,
    currentCompanyId: currentCompanyId ?? this.currentCompanyId,
    plan: plan,
    planExpires: planExpires,
    trialPlan: trialPlan,
    trialStarted: trialStarted,
    numTrialDays: numTrialDays,
    trialDaysLeft: trialDaysLeft,
    hasIapPlan: hasIapPlan,
    defaultCompanyId: defaultCompanyId ?? this.defaultCompanyId,
    hostedClientCount: hostedClientCount,
    hostedCompanyCount: hostedCompanyCount,
    userId: userId,
    userEmail: userEmail ?? this.userEmail,
    userPhone: userPhone ?? this.userPhone,
    userFirstName: userFirstName ?? this.userFirstName,
    userLastName: userLastName ?? this.userLastName,
    googleTwoFactorEnabled:
        googleTwoFactorEnabled ?? this.googleTwoFactorEnabled,
    verifiedPhoneNumber: verifiedPhoneNumber ?? this.verifiedPhoneNumber,
    biometricEnabled: biometricEnabled ?? this.biometricEnabled,
    referralCode: referralCode,
    referralMeta: referralMeta,
    ninjaPortalUrl: ninjaPortalUrl,
    eInvoicingToken: eInvoicingToken,
    reportErrors: reportErrors,
  );
}

@immutable
class AuthCompany {
  const AuthCompany({
    required this.id,
    required this.name,
    required this.displayName,
    required this.permissions,
    required this.isAdmin,
    required this.isOwner,
    this.logoUrl,
    this.enabledModules = 0,
  });

  final String id;
  final String name;
  final String displayName;

  /// Absolute URL to the company's uploaded logo, or null when none is set.
  final String? logoUrl;

  /// Comma-separated permission strings — the format admin-portal uses too.
  final String permissions;

  /// Bitmask mirror of `Company.enabled_modules`. Carried on the session so
  /// the sidebar / actions / routing can gate module-disabled UI reactively
  /// without watching the full Company stream — same pattern as [permissions].
  /// Defaults to 0 (no modules) for older persisted rows / test fixtures.
  final int enabledModules;

  final bool isAdmin;
  final bool isOwner;

  /// Whether the active company-user holds [permission].
  ///
  /// Mirrors the server's `User::hasPermission` (`app/Models/User.php`) for
  /// the CRUD grid, so the UI doesn't hide an action the API would accept.
  /// (The `kPermissionSpecial` toggles are a deliberate exception — see the
  /// last bullet.) The rules:
  ///
  ///   * `<verb>_all` grants every entity token for that verb. This is how the
  ///     app's OWN permission editor stores a whole column
  ///     (`permissionsAfterToggleAll` / the auto-promote in
  ///     `permissionsAfterToggleCell` collapse the 14 entity tokens into
  ///     `view_all` / `edit_all` / `create_all`), so exact-token matching left
  ///     a user granted "everything" with no dashboard, no Reports, no entity
  ///     actions and no bulk actions.
  ///   * `edit_<entity>` and `edit_all` imply `view_<entity>` — you cannot edit
  ///     what you cannot see, and the server says so explicitly.
  ///   * `delete_<entity>` is NOT a real token anywhere in the product (the
  ///     grid only produces create/view/edit). The server authorizes a destroy
  ///     through `EntityPolicy::edit`, so delete is treated as an edit here;
  ///     React gates its delete actions on `edit_*` for the same reason.
  ///
  /// [kPermissionSpecial] toggles (`view_dashboard` / `view_reports` /
  /// `disable_emails`) stay EXACT-token on purpose: they're standalone
  /// checkboxes above the grid, and React deliberately excludes them from
  /// `_all` expansion, so ticking "view all" shouldn't silently unlock Reports.
  bool can(String permission) {
    // Negative tokens are never conferred by admin status — holding one takes
    // an ability away, so the blanket grant below would invert them.
    if (kPermissionNegative.contains(permission)) {
      if (isAdmin || isOwner) return false;
      return permissions.split(',').map((p) => p.trim()).contains(permission);
    }
    if (isAdmin || isOwner) return true;
    if (permissions.isEmpty) return false;
    final held = permissions.split(',').map((p) => p.trim()).toSet();
    if (held.contains(permission)) return true;
    if (kPermissionSpecial.contains(permission)) return false;
    // Split on the FIRST underscore only: `view_recurring_invoice` must yield
    // ('view', 'recurring_invoice'), never ('view', 'recurring') — which would
    // leak permissions across the other `recurring_*` entities.
    final sep = permission.indexOf('_');
    if (sep <= 0) return false;
    var verb = permission.substring(0, sep);
    final entity = permission.substring(sep + 1);
    if (verb == 'delete') verb = 'edit';
    if (held.contains('${verb}_all') || held.contains('${verb}_$entity')) {
      return true;
    }
    if (verb == 'view') {
      return held.contains('edit_all') || held.contains('edit_$entity');
    }
    return false;
  }

  /// True when [type]'s module is enabled for this company (or the entity is
  /// always-on). Convenience over [isEntityModuleEnabledForCompany] so call
  /// sites read `me.moduleEnabled(EntityType.quote)` alongside `me.can(...)`.
  bool moduleEnabled(EntityType type) =>
      isEntityModuleEnabledForCompany(type, enabledModules);
}
