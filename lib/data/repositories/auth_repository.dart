import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/models/api/user_api_model.dart';
import 'package:admin/data/repositories/auth/auth_helpers.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/company_repository.dart'
    show kCompanyWireName;
import 'package:admin/data/repositories/user_settings_repository.dart'
    show kUserSettingsWireName;
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/domain/sync/refresh_sync_constants.dart';

export 'package:admin/data/repositories/auth/auth_session.dart'
    show AuthSession, AuthCompany, CanAddCompanyResult, kMaxCompaniesPerAccount;

final _log = Logger('AuthRepository');

/// Outcome of [AuthRepository.switchCompany]. Callers surface anything that
/// isn't [ok] — a switch that quietly does nothing reads to the user as the
/// app ignoring them (issue #16).
enum SwitchCompanyResult {
  ok,

  /// No active session — nothing to switch. Only reachable if a logout raced
  /// the tap.
  noSession,

  /// The target company has no usable token, even after a healing refresh.
  /// Either the server has no `is_system` token for this (company, user) pair
  /// or we're offline with a roster that's ahead of the token map.
  noToken,
}

/// [AuthRepository.addCompany] created the company on the server but could not
/// activate it locally.
///
/// Distinct from a failed create, and the distinction is the whole point: the
/// company **exists**. Reporting this as "failed to add company" invites the
/// user to create a second one. The UI should say so and point them at the
/// company list instead.
class CompanyCreatedNotActivatedException implements Exception {
  const CompanyCreatedNotActivatedException(this.companyId, this.reason);

  /// Empty when `/refresh` never returned the new company at all, so we never
  /// learned its id.
  final String companyId;
  final String reason;

  @override
  String toString() =>
      'CompanyCreatedNotActivatedException($companyId, $reason)';
}

/// Owns the user's session: who they are, what company is active, what
/// `ApiCredentials` the network layer should use right now. Persists the
/// token in [FlutterSecureStorage] and the company/account metadata in Drift.
///
/// The UI listens to two things:
///   * [session] — the rich envelope (companies, account, permissions).
///   * [credentials] — what [ApiClient] reads on every request.
class AuthRepository {
  AuthRepository({
    required AppDatabase db,
    required AuthService authService,
    required TokenStorage tokenStorage,
    required PasswordCache passwordCache,
    DateTime Function()? now,
  }) : _db = db,
       _auth = authService,
       _secure = tokenStorage,
       _passwordCache = passwordCache,
       _now = now ?? DateTime.now;

  final AppDatabase _db;
  final AuthService _auth;
  final TokenStorage _secure;
  final PasswordCache _passwordCache;
  final DateTime Function() _now;

  /// Wired by DI after [ApiClient] is constructed — they have a mutual
  /// dependency (ApiClient needs [credentials] + [logout]), so the cycle is
  /// broken by injecting this lazily.
  ApiClient? _api;
  set apiClient(ApiClient client) => _api = client;

  /// Wired by DI after [SyncRepository] is constructed. Invoked at the top
  /// of [logout] so a pending outbox drain can settle before we wipe the
  /// local DB out from under it. Failures are logged and swallowed; logout
  /// must complete even if the hook throws.
  Future<void> Function()? onBeforeLogout;

  /// Wired by DI to reset in-memory, app-lifetime, per-SESSION repo state that
  /// survives logout (the `Services` bag — hence its repos — is built once at
  /// boot). Invoked synchronously in [logout]'s in-memory clear block so a
  /// second user on the same install never inherits the previous user's state
  /// (e.g. the calendar connection's connected email — a cross-user leak).
  /// Runs on both the full and `preserveLocalData` paths. Failures are
  /// swallowed; logout must complete regardless.
  void Function()? onSessionReset;

  /// Wired by DI to `SyncRepository.drainOnce`. Fires whenever the active
  /// company becomes non-null (login, restore, /refresh, addCompany) or
  /// switches ([switchCompany]) so any outbox rows pending for that company
  /// — left over from a prior session, or queued while we were offline —
  /// drain immediately instead of sitting until the next user action. Fire
  /// and forget; failures surface via the sync engine's own event stream.
  void Function(String companyId)? onActiveCompanyChanged;

  /// Last company id for which [_fireActiveCompanyChanged] invoked
  /// [onActiveCompanyChanged]. Guards against re-running the activation work
  /// (sidebar prefetch, settings reset, formatter warm) when a /refresh
  /// re-activates the *same* company — the background `_refreshSessionQuietly`
  /// after [restore] and the periodic delta pump both go through
  /// `_persistAndActivate`. Reset to null on [logout] so re-login to the same
  /// company re-activates.
  String? _lastActivatedCompanyId;

  /// Wired by DI to fan-out the per-entity `applyBundle` calls (task
  /// statuses, company gateways, …). Invoked once per company in the
  /// `/login` or `/refresh` envelope, *after* the user / company / settings
  /// rows have been persisted. Lets the auth layer stay ignorant of which
  /// entity repositories exist while still seeding their Drift tables from
  /// the bundled arrays on `data[N].company.*`. [fullSync] is false on a
  /// delta refresh — the envelope's bundled arrays are then *partial*, so
  /// `applyBundle` must upsert without claiming a full snapshot (it must not
  /// regress the per-entity keyset cursor or set `lastFullSyncAt`).
  Future<void> Function({
    required String companyId,
    required CompanyEnvelopeApi company,
    required bool fullSync,
  })?
  onPersistBundles;

  /// Wired by DI to `StaticsRepository.applyStatic`. The `/refresh` envelope
  /// already carries the full static catalog (`response.static`) when
  /// `include_static=true` was sent, so we seed the statics cache from it
  /// instead of an independent `GET /api/v1/statics` request. Best-effort;
  /// no-op on the empty map a delta refresh returns. Kept as a hook so the
  /// auth layer doesn't depend on `StaticsRepository` (layering).
  Future<void> Function(Map<String, dynamic>? blob)? onApplyStatic;

  ApiClient get _requireApi {
    final api = _api;
    if (api == null) {
      throw StateError(
        'AuthRepository.apiClient was not set before addCompany() was called',
      );
    }
    return api;
  }

  final ValueNotifier<AuthSession?> _session = ValueNotifier<AuthSession?>(
    null,
  );
  final ValueNotifier<ApiCredentials?> _credentials =
      ValueNotifier<ApiCredentials?>(null);

  /// Cold-launch biometric gate. Flipped on by [restore] when the user has
  /// opted in; flipped off by [completeBiometricUnlock]. The router watches
  /// this and redirects to `/lock` while it's true.
  final ValueNotifier<bool> _requiresBiometricUnlock = ValueNotifier<bool>(
    false,
  );

  /// Subscription to the Drift `companies` table. Rebuilds the
  /// `AuthSession.companies` slice whenever a row changes (e.g. the user
  /// edits the company name on Settings → Company Details) so the picker in
  /// the shell sidebar reflects the change without waiting for the next
  /// `/refresh` or app restart. Created on first session activation and torn
  /// down by [logout] / [dispose].
  StreamSubscription<List<CompanyRow>>? _companiesSub;

  ValueListenable<AuthSession?> get session => _session;

  /// The active company id, or `null` when there is no session — e.g. during
  /// logout teardown, after [logout] clears [session] but before the router has
  /// swapped to `/login`. Re-entrant `build` / `didChangeDependencies` /
  /// `didUpdateWidget` paths MUST use this instead of
  /// `session.value!.currentCompanyId`, since they can rebuild once more on the
  /// logout frame while still mounted. `initState`-cached reads keep
  /// `session.value!` (they run once, pre-logout).
  String? get currentCompanyId => _session.value?.currentCompanyId;

  ValueListenable<ApiCredentials?> get credentials => _credentials;
  ValueListenable<bool> get requiresBiometricUnlock => _requiresBiometricUnlock;

  bool get isAuthenticated => _credentials.value?.isAuthenticated ?? false;

  /// Per-company token map. Kept in memory for fast switching; secure storage
  /// is the durable copy.
  Map<String, String> _tokensByCompany = const {};

  /// Monotonic session epoch, bumped at the top of [logout]. A
  /// `_refreshSession` whose `/refresh` network call was already in flight when
  /// the user logged out captures the old value, sees the mismatch on return,
  /// and refuses to re-activate credentials — otherwise the late response would
  /// re-seed the session and bounce the user straight back into the app. A
  /// counter, not a bool: a logout *followed by an immediate re-login* leaves
  /// the stale refresh mismatched against the new session too, so it can't
  /// clobber the new session's token.
  int _sessionGeneration = 0;

  /// Ask the server which credentials [email] needs before showing the form's
  /// optional fields. Pure read — touches no session state. Returns null when
  /// the precheck can't be answered (older server, offline, rate-limited);
  /// callers must fall back to showing every field. See
  /// [AuthService.precheck].
  Future<LoginPrecheck?> precheckLogin({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) => _auth.precheck(
    baseUrl: baseUrl,
    isHosted: isHosted,
    email: email,
    secret: secret,
  );

  /// Hot login. Calls `/api/v1/login`, persists everything, and primes
  /// [credentials] so subsequent API calls work.
  Future<void> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
    String? secret,
  }) async {
    final response = await _auth.login(
      baseUrl: baseUrl,
      isHosted: isHosted,
      email: email,
      password: password,
      oneTimePassword: oneTimePassword,
      secret: secret,
    );
    await _persistAndActivate(
      response: response,
      baseUrl: baseUrl,
      isHosted: isHosted,
    );
  }

  /// Bootstrap a session from a pre-issued API token instead of an
  /// email/password login. Calls `/api/v1/refresh` with the token, then runs
  /// the same `_persistAndActivate` tail as [login]. The server echoes the
  /// token in the envelope, so it is persisted unchanged — unlike a login
  /// session token it does not expire when the (demo) server resets its data.
  /// Used only by demo builds; see `Env.demoApiToken` and `main.dart`.
  Future<void> loginWithToken({
    required String baseUrl,
    required bool isHosted,
    required String token,
  }) async {
    final response = await _auth.refreshWithToken(
      baseUrl: baseUrl,
      isHosted: isHosted,
      token: token,
    );
    await _persistAndActivate(
      response: response,
      baseUrl: baseUrl,
      isHosted: isHosted,
    );
  }

  /// OAuth login (Sign in with Apple, etc). Calls `/api/v1/oauth_login`
  /// then activates the session — identical tail to [login].
  Future<void> oauthLogin({
    required String baseUrl,
    required bool isHosted,
    required String provider,
    String? idToken,
    String? authCode,
    String? accessToken,
    String? email,
  }) async {
    final response = await _auth.oauthLogin(
      baseUrl: baseUrl,
      isHosted: isHosted,
      provider: provider,
      idToken: idToken,
      authCode: authCode,
      accessToken: accessToken,
      email: email,
    );
    await _persistAndActivate(
      response: response,
      baseUrl: baseUrl,
      isHosted: isHosted,
    );
  }

  /// Native account creation. Calls `/api/v1/signup` then activates the
  /// session — identical tail to [login]. Hosted-only at the call site
  /// (self-hosted in-app signup is not a validated path).
  Future<void> signup({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String referralCode = '',
  }) async {
    final response = await _auth.signup(
      baseUrl: baseUrl,
      isHosted: isHosted,
      email: email,
      password: password,
      referralCode: referralCode,
    );
    await _persistAndActivate(
      response: response,
      baseUrl: baseUrl,
      isHosted: isHosted,
    );
  }

  /// Re-pull `/api/v1/refresh` and re-populate the session. Used by the
  /// Two-Factor screen after a successful enable/disable so the new
  /// `google_2fa_secret` / `verified_phone_number` flags propagate without a
  /// forced logout. Throws on transport/HTTP failures so the caller can
  /// surface a toast.
  /// Pass `fullSync: true` after a destructive local op (e.g. danger-zone
  /// purge/delete wiped this company's per-entity sync cursors) so the next
  /// pull re-seeds the full snapshot instead of an empty delta.
  Future<void> refreshSession({bool fullSync = false}) =>
      _refreshSession(fullSync: fullSync);

  /// In-memory short-circuit for the Two-Factor screen. Lets the UI react
  /// immediately after a successful enable/disable while a background
  /// [refreshSession] catches up the rest. No-op when there's no session.
  void markTwoFactorEnabled(bool enabled) {
    final s = _session.value;
    if (s == null) return;
    _session.value = s.copyWith(googleTwoFactorEnabled: enabled);
  }

  /// Same shape as [markTwoFactorEnabled] but for the SMS-verified flag.
  void markPhoneVerified({String? phone}) {
    final s = _session.value;
    if (s == null) return;
    _session.value = s.copyWith(verifiedPhoneNumber: true, userPhone: phone);
  }

  /// Merge user-level fields from a `PUT /users/{id}` response into the
  /// active session so the topbar / company picker re-render with the patched
  /// values immediately, without waiting for the next `/refresh`. No-op when
  /// there's no session or the response is for a different user (defensive —
  /// `UserRepository` only enqueues updates for the auth user, but a future
  /// User Management screen could share this code path).
  void applyUserUpdate(UserApi user) {
    final s = _session.value;
    if (s == null) return;
    if (user.id.isNotEmpty && user.id != s.userId) return;
    _session.value = s.copyWith(
      userFirstName: user.firstName,
      userLastName: user.lastName,
      userEmail: user.email,
      userPhone: user.phone,
      googleTwoFactorEnabled: user.google2faSecret,
      verifiedPhoneNumber: user.verifiedPhoneNumber,
    );
  }

  /// Forgot-password — the server emails the user. No session is created.
  Future<void> recoverPassword({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) => _auth.recoverPassword(
    baseUrl: baseUrl,
    isHosted: isHosted,
    email: email,
    secret: secret,
  );

  /// Switch the active company. Updates [credentials] so the next API call
  /// uses that company's token. Caller is responsible for any pending-outbox
  /// confirmation prompt before invoking this.
  ///
  /// Returns what actually happened — callers must not assume success. A
  /// company can be listed in the picker with no cached token (the roster is
  /// rebuilt from Drift, the token map from the login/refresh envelope), and
  /// this used to return silently in that case: the picker closed, the route
  /// reset, and the user stayed put with no error (issue #16).
  Future<SwitchCompanyResult> switchCompany(String companyId) async {
    final s = _session.value;
    if (s == null) return SwitchCompanyResult.noSession;
    var token = _tokensByCompany[companyId];
    // Empty strings slip past a `== null` check but produce a blank
    // `X-API-Token` header, which the server treats as unauthorized and
    // cascades into a forced logout. Treat empty as missing.
    if (token == null || token.isEmpty) {
      // One self-heal attempt before giving up. A *full* refresh re-pulls every
      // company-user in the envelope — the only call that can hand us a token
      // we don't already hold (a delta is scoped to the active company). Offline
      // or a still-token-less server response just falls through to `noToken`.
      _log.warning('switchCompany($companyId): no token cached; refreshing');
      try {
        await _refreshSession(
          preserveActiveCompanyId: s.currentCompanyId,
          fullSync: true,
        );
      } catch (e, st) {
        _log.warning('switchCompany($companyId): heal refresh failed', e, st);
      }
      // The refresh may have logged us out (401) or landed a fresh session —
      // re-read rather than reusing the pre-refresh snapshot.
      final healed = _session.value;
      if (healed == null) return SwitchCompanyResult.noSession;
      token = _tokensByCompany[companyId];
      if (token == null || token.isEmpty) {
        _log.warning('switchCompany($companyId): still no token after refresh');
        return SwitchCompanyResult.noToken;
      }
      return _activateCompany(healed, companyId, token);
    }
    return _activateCompany(s, companyId, token);
  }

  Future<SwitchCompanyResult> _activateCompany(
    AuthSession s,
    String companyId,
    String token,
  ) async {
    _session.value = s.copyWith(currentCompanyId: companyId);
    _credentials.value = ApiCredentials(
      baseUrl: s.baseUrl,
      token: token,
      apiSecret: '',
      isHosted: s.isHosted,
    );
    await _secure.write(kAuthCurrentCompanyIdKey, companyId);
    // Session + credentials have already flipped, so a throw out of the
    // activation fan-out (its synchronous prologue — settings reset, scheduler
    // start, sync resume, drain kick — is unguarded) would report a failed
    // switch that in fact half-happened. Log it and let the caller navigate.
    try {
      _fireActiveCompanyChanged(companyId);
    } catch (e, st) {
      _log.warning('onActiveCompanyChanged($companyId) threw', e, st);
    }
    return SwitchCompanyResult.ok;
  }

  /// Create a new company under the current account. Mirrors admin-portal's
  /// `addCompany` (auth_repository.dart:180-189 + auth_middleware.dart:360-387):
  /// POST is opaque; the client then re-pulls every company/token via
  /// `/api/v1/refresh` and switches into the newly-arrived one.
  ///
  /// The caller is responsible for any pending-outbox prompt before invoking
  /// this — same contract as [switchCompany].
  Future<void> addCompany() async {
    final s = _session.value;
    if (s == null) {
      throw StateError('addCompany called without an active session');
    }
    final before = s.companies.map((c) => c.id).toSet();
    final activeCompanyId = s.currentCompanyId;

    // 1. POST — server returns the created company; we ignore it and
    //    re-pull below to also pick up the per-company token.
    await _requireApi.postJson(
      '/api/v1/companies',
      body: const {'token_name': 'ios_client'},
    );

    // 2-3. Refresh re-pulls every company + token and re-persists, preserving
    //      the previously-active company so the user doesn't get bounced back
    //      to `account.defaultCompanyId`. Forced full: a delta is scoped to
    //      one company (`current_company=true`) and would never return the
    //      brand-new one, and its bundles need full seeding.
    await _refreshSession(
      preserveActiveCompanyId: activeCompanyId,
      fullSync: true,
    );

    // A logout raced this foreground add (very unlikely, but `_refreshSession`
    // now bails silently on a mid-flight logout instead of persisting, leaving
    // `_session.value` null). Nothing to switch into — return rather than throw
    // on the `!` below.
    if (_session.value == null) return;
    // 4. Identify the new company by id-set diff. Server order isn't
    //    guaranteed across the two calls; this is the only safe way.
    final after = _session.value!.companies.map((c) => c.id).toSet();
    final added = after.difference(before);
    // Both failure paths below are POST-succeeded-but-activation-failed: the
    // company is on the server either way, so they must NOT surface as "failed
    // to add company" or the user creates a duplicate.
    if (added.isEmpty) {
      throw const CompanyCreatedNotActivatedException(
        '',
        '/refresh did not return the newly-created company',
      );
    }
    // If multiple companies were added (e.g. another device created one
    // concurrently), pick any — the user can still switch via the picker.
    final result = await switchCompany(added.first);
    if (result != SwitchCompanyResult.ok) {
      // `_handleNewCompany` routes to Company Details on a clean return, which
      // would render the OLD company's settings under a "new company" banner —
      // throw so it surfaces the error path instead.
      throw CompanyCreatedNotActivatedException(added.first, result.name);
    }
  }

  /// Mark a company as the account's default — what new logins land on
  /// before any per-device override. Wraps `POST /api/v1/companies/{id}/default`
  /// then re-pulls `/refresh` so the local `Accounts.defaultCompanyId` and the
  /// session's `defaultCompanyId` snap to the new value. Throws on
  /// transport / HTTP / parse failure; UI surfaces a toast.
  ///
  /// Mirrors admin-portal `auth_repository.dart:172` (`setDefaultCompany`).
  Future<void> setDefaultCompany(String companyId) async {
    final activeCompanyId = _session.value?.currentCompanyId;
    await _requireApi.postJson(
      '/api/v1/companies/$companyId/default',
      body: const {},
    );
    await _refreshSession(preserveActiveCompanyId: activeCompanyId);
  }

  /// Server-side "end all sessions" — `POST /api/v1/logout` rotates every
  /// active token attached to the account. Used by Settings → Account
  /// Management → Security Settings to nuke other devices in one shot.
  ///
  /// No password gate: the server does not require `X-API-PASSWORD-BASE64` for
  /// this endpoint (React fires it bare in production), and gating it would
  /// lock out OAuth-only users who have no password. On success we run the
  /// local [logout] end-to-end so this device drops back to `/login`; the
  /// server's session invalidation would force the next request to 401 anyway,
  /// but pre-emptively logging out avoids a brief authenticated-with-revoked-
  /// token window.
  Future<void> endAllSessions() async {
    await _requireApi.postJson('/api/v1/logout', body: const {});
    await logout();
  }

  /// Self-hosted only: redeem a white-label / license key against
  /// `POST /api/v1/claim_license`. Server upgrades the account's plan;
  /// we refresh to pick up the new `plan`, `plan_expires`, and feature flags.
  /// Throws on transport / HTTP / parse failure; UI surfaces a toast.
  ///
  /// Mirrors admin-portal `account_management.dart:550` inline call.
  Future<void> applyLicense(String licenseKey) async {
    await _requireApi.postJson(
      '/api/v1/claim_license',
      query: {'license_key': licenseKey},
      body: const {},
    );
    // Plan / feature flags live on the account envelope, which the server
    // doesn't gate by `updated_at` — force a full snapshot so they refresh.
    await refresh(fullSync: true);
  }

  /// Pull `/api/v1/refresh` and re-persist the session. Used by [addCompany]
  /// (to pick up the newly-created company + token), [restore] (to heal stale
  /// per-(user,company) flags), and the foreground refresh scheduler.
  ///
  /// **Delta vs full.** Mirrors the legacy admin-portal: each company stores a
  /// `lastSyncAt` high-water mark; a refresh sends `updated_at=(lastSyncAt/1000
  /// - buffer)` so the server returns only records changed since then, scoped
  /// to the active company (`current_company=true`). A *full* refresh
  /// (`updated_at=0&first_load=true`) is forced when [fullSync] is set, when
  /// the company has never synced (`lastSyncAt==0`), or when its row is absent.
  /// The static catalog rides along only on a full refresh or when the cached
  /// blob is stale ([kStaticsStaleAfter]).
  ///
  /// Throws on transport, HTTP, or parse failures. Callers decide whether to
  /// surface them: [addCompany] re-throws so the UI shows an error;
  /// [restore]'s background heal swallows so an offline cold start still works.
  Future<void> _refreshSession({
    String? preserveActiveCompanyId,
    bool fullSync = false,
  }) async {
    final s = _session.value;
    if (s == null) {
      throw StateError('_refreshSession called without an active session');
    }
    // Snapshot the session epoch so we can detect a logout (or re-login) that
    // lands while the `/refresh` round-trip below is in flight.
    final generation = _sessionGeneration;

    final activeId = preserveActiveCompanyId?.isNotEmpty == true
        ? preserveActiveCompanyId!
        : s.currentCompanyId;
    final companyRow = activeId.isEmpty
        ? null
        : await _db.companiesDao.byId(activeId);
    final lastSync = companyRow?.lastSyncAt ?? 0;
    // A brand-new / never-synced / not-yet-persisted company must full-load:
    // a delta would only return rows changed since epoch-minus-buffer (≈
    // nothing) and never seed the bundle.
    final isFullSync = fullSync || companyRow == null || lastSync == 0;

    // Capture the watermark BEFORE the request, like v1. Storing the response
    // time instead would drop any write the server committed while the request
    // was in flight.
    final reqStartMs = _now().millisecondsSinceEpoch;

    final Map<String, String> query;
    if (isFullSync) {
      query = const {
        'current_company': 'false',
        'updated_at': '0',
        'first_load': 'true',
        'include_static': 'true',
        'einvoice': 'true',
      };
    } else {
      final updatedAtSecs = (((lastSync ~/ 1000) - kUpdatedAtBufferSeconds))
          .clamp(0, 1 << 62);
      final cachedStatics = await _db.staticsDao.read();
      final staticsStale =
          cachedStatics == null ||
          reqStartMs - cachedStatics.fetchedAt >
              kStaticsStaleAfter.inMilliseconds;
      query = {
        'current_company': 'true',
        'updated_at': '$updatedAtSecs',
        'einvoice': 'true',
        if (staticsStale) 'include_static': 'true',
      };
    }

    final raw = await _requireApi.postJson(
      '/api/v1/refresh',
      query: query,
      readOnly: true,
    );
    // A logout (or re-login) landed while the request was in flight. The
    // session this refresh was computed against is gone — parsing and
    // persisting now would re-activate credentials and log the user back in.
    // Abandon quietly.
    if (generation != _sessionGeneration) return;
    if (raw is! Map<String, dynamic>) {
      throw StateError(
        'Unexpected /refresh response shape: ${raw.runtimeType}',
      );
    }
    final response = LoginResponseApi.fromJson(raw);
    await _persistAndActivate(
      response: response,
      baseUrl: s.baseUrl,
      isHosted: s.isHosted,
      preserveActiveCompanyId: preserveActiveCompanyId ?? s.currentCompanyId,
      isFullSync: isFullSync,
      syncWatermarkMs: reqStartMs,
      expectedGeneration: generation,
      // Live id at request time — lets the commit detect (and yield to) a
      // company switch that lands while this refresh is in flight.
      activeCompanyIdAtRequest: s.currentCompanyId,
    );
  }

  /// Called by [ApiClient] when a 401 lands. Wipes everything and flips
  /// [credentials] back to null so the redirect to `/login` fires.
  ///
  /// [preserveLocalData] keeps the on-disk tokens + encrypted Drift database
  /// intact while still clearing the in-memory session (so the router still
  /// redirects to `/login`). Used by the idle session-timeout when the outbox
  /// still holds unsynced rows: wiping would silently destroy the user's
  /// offline edits, so instead the data survives to drain on the next login or
  /// cold-start [restore]. Default `false` = full destructive logout.
  Future<void> logout({bool preserveLocalData = false}) async {
    // Invalidate any refresh whose `/refresh` call is already in flight. Bump
    // BEFORE awaiting onBeforeLogout (which can take a while draining the
    // outbox) so a response landing during that await is rejected too — see
    // [_sessionGeneration] and the guards in [_refreshSession] /
    // [_persistAndActivate].
    _sessionGeneration++;
    // Let any in-flight outbox drain settle BEFORE we wipe the DB — without
    // this, a successful send racing logout could mutate server state on
    // behalf of the user who just logged out.
    final hook = onBeforeLogout;
    if (hook != null) {
      try {
        await hook();
      } catch (e, st) {
        _log.warning('onBeforeLogout failed', e, st);
      }
    }
    await _companiesSub?.cancel();
    _companiesSub = null;
    _session.value = null;
    _credentials.value = null;
    _requiresBiometricUnlock.value = false;
    _tokensByCompany = const {};
    // Re-arm the activation guard so a fresh login (even to the same company)
    // re-fires onActiveCompanyChanged and re-runs the sidebar prefetch.
    _lastActivatedCompanyId = null;
    _passwordCache.clear();
    // Reset app-lifetime per-session repo state (e.g. the calendar connection)
    // so the next user on this install starts unread. Synchronous + defensive.
    try {
      onSessionReset?.call();
    } catch (e, st) {
      _log.warning('onSessionReset failed', e, st);
    }
    if (preserveLocalData) {
      // Idle-timeout re-lock with unsynced work pending: the in-memory session
      // is already cleared above (so the router redirects to /login), but we
      // KEEP the on-disk tokens + encrypted DB so the queued outbox rows
      // survive to drain on the next login / cold-start restore. The data
      // stays encrypted at rest, exactly as it would across a normal app quit.
      //
      // Persist a lock flag so the next restore() does NOT silently re-enter:
      // it requires re-auth first (biometric if enabled, else a fresh sign-in)
      // — otherwise keeping the tokens would defeat the session-timeout's
      // security purpose on a shared/unattended device (esp. web, where
      // biometric is never available). Cleared on successful re-entry.
      await _secure.write(kAuthSessionLockedKey, 'true');
      return;
    }
    await _secure.delete(kAuthTokensKey);
    await _secure.delete(kAuthBaseUrlKey);
    await _secure.delete(kAuthIsHostedKey);
    await _secure.delete(kAuthCurrentCompanyIdKey);
    // A logged-out session has nothing left to unlock; leaving the flag on
    // disk would surface a lock prompt on next launch with no session behind
    // it. Clear it alongside the tokens.
    await _secure.delete(kAuthBiometricEnabledKey);
    // A full logout supersedes any pending re-lock gate.
    await _secure.delete(kAuthSessionLockedKey);
    await _db.wipe();
  }

  /// Persist the user's biometric preference and reflect it in the active
  /// session so the User Details toggle stays in sync without a `/refresh`.
  /// No-op when there's no active session — writing the flag without a token
  /// behind it would surface a lock screen on next launch with nothing to
  /// unlock.
  Future<void> setBiometricEnabled(bool enabled) async {
    final s = _session.value;
    if (s == null) return;
    if (enabled) {
      await _secure.write(kAuthBiometricEnabledKey, 'true');
    } else {
      await _secure.delete(kAuthBiometricEnabledKey);
    }
    _session.value = s.copyWith(biometricEnabled: enabled);
  }

  /// Called by the lock screen once the user passes the biometric prompt.
  /// Flipping the notifier fires the router's refresh listener, which then
  /// redirects out of `/lock` into the post-login destination.
  void completeBiometricUnlock() {
    if (_requiresBiometricUnlock.value) {
      _requiresBiometricUnlock.value = false;
    }
    // A successful biometric unlock is a re-auth — clear any idle-timeout
    // re-lock flag so a later cold start restores normally.
    unawaited(_secure.delete(kAuthSessionLockedKey));
  }

  /// Pull a fresh server snapshot for the active session. Same wire call
  /// as the post-login refresh: `POST /api/v1/refresh?first_load=true&...`,
  /// then `_persistAndActivate` writes the response across the
  /// `companies`, `users`, `user_settings`, and the bundled per-entity
  /// tables (task_statuses, company_gateways, …). Safe to call on demand
  /// — Settings > User Details fires it on open so the form reflects the
  /// latest profile fields without round-tripping the password-protected
  /// `GET /users/{id}` endpoint. No-op when there's no active session.
  /// [fullSync] forces a full snapshot (`updated_at=0`) instead of a delta —
  /// used after account-level changes the server doesn't gate by `updated_at`
  /// (license claim) or when the local cursors were wiped.
  Future<void> refresh({bool fullSync = false}) async {
    if (_session.value == null) return;
    await _refreshSession(fullSync: fullSync);
  }

  /// Read on app start: if we have a token cached, rebuild the session from
  /// Drift + secure storage so the user lands inside the shell immediately.
  Future<void> restore() async {
    // These five reads are independent platform round-trips (iOS Keychain
    // / Android Keystore). Issued sequentially they stacked ~5× the
    // single-read latency onto the cold-start path; `Future.wait` collapses
    // that to ~1×. The extra three reads in the rare not-logged-in case
    // (early return below) are cheap and still finish in one round-trip.
    final reads = await Future.wait([
      _secure.read(kAuthTokensKey),
      _secure.read(kAuthBaseUrlKey),
      _secure.read(kAuthIsHostedKey),
      _secure.read(kAuthCurrentCompanyIdKey),
      _secure.read(kAuthBiometricEnabledKey),
      _secure.read(kAuthSessionLockedKey),
    ]);
    final tokensRaw = reads[0];
    final baseUrl = reads[1];
    if (tokensRaw == null || baseUrl == null) return;
    final isHosted = reads[2] == 'true';
    final currentId = reads[3] ?? '';
    // Tolerate any value that isn't exactly `'true'` — a corrupt write
    // shouldn't lock the user out without their explicit opt-in.
    final biometricEnabled = reads[4] == 'true';
    final sessionLocked = reads[5] == 'true';
    // The idle session-timeout preserved this session's data but flagged it for
    // re-auth. With biometric ON, fall through — the normal path below sets
    // `_requiresBiometricUnlock` and the `/lock` screen gates entry. With
    // biometric OFF (the default; the only state on web), there is no in-app
    // unlock gate, so leave the session INACTIVE (router → `/login`) without
    // wiping: the kept tokens + DB let the preserved outbox drain after a fresh
    // sign-in, which clears the flag. Returning here also skips the stale-token
    // wipe path below, so the unsynced work survives the cold start.
    if (sessionLocked && !biometricEnabled) return;
    final tokensMap = (jsonDecode(tokensRaw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v.toString()),
    );
    if (tokensMap.isEmpty) return;

    final account = await _db.companiesDao.account();
    final companies = await _db.companiesDao.all();
    if (account == null || companies.isEmpty) {
      // Drift was reset (or never populated). Discard the stale token.
      await logout();
      return;
    }
    _tokensByCompany = tokensMap;
    // A handful of account-level fields aren't Drift columns — they live
    // inside the serialized `features_json` blob written by
    // `_persistAndActivate`. Decode lazily, tolerating a missing/corrupt
    // blob by defaulting each field to its zero value.
    var hostedCompanyCount = 0;
    var hostedClientCount = 0;
    var planExpires = '';
    var trialPlan = '';
    var trialStarted = '';
    var trialDaysLeft = -1;
    var hasIapPlan = false;
    var eInvoicingToken = '';
    var reportErrors = false;
    final featuresRaw = account.featuresJson;
    if (featuresRaw != null && featuresRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(featuresRaw);
        if (decoded is Map<String, dynamic>) {
          int asInt(Object? v) {
            if (v is int) return v;
            if (v is num) return v.toInt();
            return 0;
          }

          String asStr(Object? v) => v is String ? v : '';
          hostedCompanyCount = asInt(decoded['hosted_company_count']);
          hostedClientCount = asInt(decoded['hosted_client_count']);
          planExpires = asStr(decoded['plan_expires']);
          trialPlan = asStr(decoded['trial_plan']);
          trialStarted = asStr(decoded['trial_started']);
          // -1 sentinel = absent (fall back to client-clock estimate).
          trialDaysLeft = decoded.containsKey('trial_days_left')
              ? asInt(decoded['trial_days_left'])
              : -1;
          hasIapPlan = decoded['has_iap_plan'] == true;
          eInvoicingToken = asStr(decoded['e_invoicing_token']);
          reportErrors = decoded['report_errors'] == true;
        }
      } catch (_) {
        /* fall through to defaults */
      }
    }
    // Recover the auth user's identity from Drift so an OFFLINE restart
    // still has userId/userEmail/names — without this they stayed '' until
    // the unawaited network heal landed, so Settings → User Details refused
    // to load ("Missing session — please sign in again", which an offline
    // user cannot do) and the topbar identity rendered blank. The
    // `user_settings` row (written per company on every login/refresh)
    // carries the auth user's id; the matching `users` row has the profile.
    // With no persisted active company, land on one we hold a usable token for.
    // A bare `companies.first.id` could pick a token-less row, and the guard
    // further down force-logs-out on a missing token — wiping local data even
    // though a sibling company would have restored fine. Same "present AND
    // non-empty" rule as `_persistAndActivate`.
    final restoredCompanyId = currentId.isNotEmpty
        ? currentId
        : companies
              .map((c) => c.id)
              .firstWhere(
                (id) => (tokensMap[id] ?? '').isNotEmpty,
                orElse: () => companies.first.id,
              );
    var userId = '';
    var userEmail = '';
    var userFirstName = '';
    var userLastName = '';
    var userPhone = '';
    try {
      final settingsRow = await _db.userSettingsDao.get(restoredCompanyId);
      if (settingsRow != null && settingsRow.userId.isNotEmpty) {
        userId = settingsRow.userId;
        final userRow = await _db.userDao.getByCompanyAndId(
          companyId: restoredCompanyId,
          id: userId,
        );
        if (userRow != null) {
          userEmail = userRow.email;
          userFirstName = userRow.firstName;
          userLastName = userRow.lastName;
          userPhone = userRow.phone;
        }
      }
    } catch (e, st) {
      _log.warning('restore(): could not recover auth user from Drift', e, st);
    }
    final session = AuthSession(
      baseUrl: baseUrl,
      isHosted: isHosted,
      accountId: account.id,
      plan: account.plan,
      planExpires: planExpires,
      trialPlan: trialPlan,
      trialStarted: trialStarted,
      numTrialDays: account.numTrialDays,
      trialDaysLeft: trialDaysLeft,
      hasIapPlan: hasIapPlan,
      defaultCompanyId: account.defaultCompanyId ?? '',
      hostedClientCount: hostedClientCount,
      hostedCompanyCount: hostedCompanyCount,
      userId: userId,
      userEmail: userEmail,
      userFirstName: userFirstName,
      userLastName: userLastName,
      userPhone: userPhone,
      companies: companies
          .map((c) {
            Map<String, dynamic> settings = const {};
            try {
              final decoded = jsonDecode(c.settings);
              if (decoded is Map<String, dynamic>) settings = decoded;
            } catch (_) {}
            // Prefer the dedicated `logo_url` column. Fall back to the
            // settings blob for rows that pre-date the v7 migration / for
            // logs that survived a codegen mishap that truncated the JSON.
            final logoFromColumn = c.logoUrl;
            final rawLogo =
                (logoFromColumn != null && logoFromColumn.isNotEmpty)
                ? logoFromColumn
                : companyLogoUrl(settings);
            final logoUrl = cacheBustedLogoUrl(rawLogo, c.updatedAt);
            return AuthCompany(
              id: c.id,
              name: c.name,
              displayName: companyDisplayName(
                settings: settings,
                displayName: c.displayName ?? '',
                name: c.name,
              ),
              logoUrl: logoUrl,
              permissions: c.permissions,
              enabledModules: c.enabledModules,
              isAdmin: c.isAdmin,
              isOwner: c.isOwner,
            );
          })
          .toList(growable: false),
      currentCompanyId: restoredCompanyId,
      biometricEnabled: biometricEnabled,
      eInvoicingToken: eInvoicingToken,
      reportErrors: reportErrors,
    );
    final activeToken = tokensMap[session.currentCompanyId];
    if (activeToken == null || activeToken.isEmpty) {
      // The secure-storage token map is corrupt or out of sync with the
      // Drift `companies` table. Surface this loudly and bounce to login
      // rather than activate a credential-less session that would fail
      // every API call.
      _log.warning(
        'restore(): no token for currentCompanyId=${session.currentCompanyId}; '
        'forcing logout',
      );
      await logout();
      return;
    }
    _session.value = session;
    // Flip the gate BEFORE we hand credentials to the router. Setting
    // credentials triggers the router's refreshListenable; if the lock flag
    // weren't set yet the router would route straight into the shell and
    // race the lock screen. Order matters.
    if (biometricEnabled) {
      _requiresBiometricUnlock.value = true;
    }
    _credentials.value = ApiCredentials(
      baseUrl: baseUrl,
      token: activeToken,
      isHosted: isHosted,
    );
    _attachCompaniesWatcher();
    // If the user backgrounded the app with pending outbox rows and the
    // device went offline before the previous process exited, those rows
    // now need a kick — biometric-gated restore included (the drain will
    // only successfully dispatch once the credentials are honored, but
    // queuing it here is harmless because drainOnce is idempotent).
    _fireActiveCompanyChanged(session.currentCompanyId);

    // Best-effort: re-pull the session in the background so stale
    // per-(user,company) flags (`is_owner`, `is_admin`) and account-level
    // fields (`plan`, `hosted_company_count`) catch up with the server.
    // Older schema migrations added the local `is_owner` column with a
    // default of false and didn't backfill — without this, an account owner
    // who upgraded the app without re-logging in stays silently downgraded
    // (the company picker shows "Only the account owner can add companies"
    // even though they are). If we're offline / unauthorized / parse fails,
    // leave the restored session as-is.
    unawaited(_refreshSessionQuietly());
  }

  Future<void> _refreshSessionQuietly() async {
    try {
      // Force a FULL refresh. This heal's job is to repair stale
      // per-(user,company) `is_owner`/`is_admin` flags that older migrations
      // left at column defaults — for *every* company. A delta is scoped to
      // the active company (`current_company=true`), so it would leave
      // non-active companies' stale flags unhealed until the user switched
      // into them. Cold start was a full refresh before delta-sync existed,
      // so this is no perf regression; steady-state deltas are driven by the
      // foreground scheduler + on-demand callers instead.
      await _refreshSession(fullSync: true);
    } catch (e, st) {
      _log.fine('restore(): background refresh skipped', e, st);
    }
  }

  /// Invoke [onActiveCompanyChanged] only when the active company actually
  /// changes. `_persistAndActivate` runs on every /refresh — the background
  /// `_refreshSessionQuietly` right after [restore] (which already activated
  /// from the cached session) and the periodic delta pump both reach it — but
  /// the prefetch + settings reset hung off this callback are per-activation
  /// work, not per-refresh. Without this guard a warm load fires the full
  /// sidebar prefetch sweep twice. The drain is kicked independently
  /// (connectivity, app-resume, periodic, per-mutation), so suppressing a
  /// redundant same-company fire here strands nothing.
  void _fireActiveCompanyChanged(String companyId) {
    if (companyId == _lastActivatedCompanyId) return;
    _lastActivatedCompanyId = companyId;
    onActiveCompanyChanged?.call(companyId);
  }

  Future<void> _persistAndActivate({
    required LoginResponseApi response,
    required String baseUrl,
    required bool isHosted,
    String? preserveActiveCompanyId,
    // Login / OAuth and a forced/first refresh are full snapshots: the
    // response is the authoritative company set, so prune the rest. A delta
    // refresh (`current_company=true`) returns only the active company +
    // changed rows — prune nothing there, or other companies' rows, tokens
    // and `lastSyncAt` would be destroyed (PK upsert handles the rest).
    bool isFullSync = true,
    // Wall-clock at the start of the refresh request, stored as each
    // company's `lastSyncAt` so the next refresh asks for the delta since
    // then. Null on the login path → fall back to "now".
    int? syncWatermarkMs,
    // Set by the [_refreshSession] (refresh) path to the session epoch captured
    // before the network call. When it no longer matches [_sessionGeneration], a
    // logout raced this refresh — bail without committing rather than re-activate
    // a logged-out session. Null on the login/OAuth/signup/token paths, which
    // create a session from scratch and must always commit.
    int? expectedGeneration,
    // Also set by [_refreshSession]: the *live* active company id at the
    // moment the request went out. When the live id has moved away from this
    // snapshot by commit time, a `switchCompany` raced the refresh — the
    // commit then keeps the user's new selection instead of silently bouncing
    // them back (and persisting the stale id for the next restart). Distinct
    // from [preserveActiveCompanyId], which is a deliberate caller override
    // (e.g. addCompany teleporting into the freshly created company).
    String? activeCompanyIdAtRequest,
  }) async {
    if (response.data.isEmpty) {
      throw StateError('Login response had no companies');
    }
    // Merge, don't replace. /refresh?current_company=false has been observed
    // returning empty `token` fields for non-active companies; freezed's
    // `SessionTokenApi.token` defaults to `''`, which would silently wipe good cached
    // tokens and trip a 401 -> forced logout on the next company switch.
    // Only let a non-empty response value override the cached one, and (on a
    // *full* snapshot only) drop any cached entries for companies the server
    // no longer returns. A delta refresh is scoped to the active company
    // (`current_company=true`) so its `data` deliberately omits the others —
    // pruning on a delta would wipe every other company's token and bounce
    // the user to /login on the next switch.
    final liveIds = {for (final uc in response.data) uc.company.id};
    final tokens = <String, String>{
      for (final entry in _tokensByCompany.entries)
        if (!isFullSync || liveIds.contains(entry.key)) entry.key: entry.value,
      for (final uc in response.data)
        if (uc.token.token.isNotEmpty) uc.company.id: uc.token.token,
    };
    final missingTokenIds = [
      for (final uc in response.data)
        if (uc.token.token.isEmpty) uc.company.id,
    ];
    if (missingTokenIds.isNotEmpty) {
      _log.warning(
        'response had empty tokens for companies: ${missingTokenIds.join(', ')}',
      );
    }
    // "Usable" is present AND non-empty. `_tokensByCompany` is rehydrated from
    // secure storage, so a map written by an older build can carry an empty
    // string — a bare `containsKey` would call that usable and prime
    // `ApiCredentials` with a blank `X-API-Token`, which the server 401s into a
    // forced logout.
    bool hasUsableToken(String id) => (tokens[id] ?? '').isNotEmpty;
    // First company in response order we can actually authenticate as. Both
    // fallbacks below used to take `response.data.first.company.id` unchecked,
    // so a token-less company at the head of `data` was activated with an empty
    // token: signed in, then immediately bounced to /login. The server omits
    // the `is_system` token for a (company, user) pair it holds no row for
    // (BACKEND.md), which is the condition behind issue #16.
    final firstTokenedId = response.data
        .map((uc) => uc.company.id)
        .firstWhere(hasUsableToken, orElse: () => '');
    if (firstTokenedId.isEmpty) {
      // Nothing in this response can authenticate. Left as-is rather than
      // thrown: 401 -> logout is at least a defined path, and this is the most
      // safety-critical code in the app. Logged loudly so the diagnostics show
      // why the session dies instead of a bare 401.
      _log.severe(
        'no company in the login/refresh response has a usable token '
        '(${response.data.map((uc) => uc.company.id).join(', ')})',
      );
    }
    final nowMs = _now().millisecondsSinceEpoch;
    final syncMark = syncWatermarkMs ?? nowMs;
    final firstAccount = response.data.first.account;
    // Prefer the caller-supplied active company (used by refresh-on-create
    // so the user doesn't get silently teleported back to the account's
    // default company) when its token is still in the new response.
    // Non-final: the switch-raced-the-refresh override at the final commit
    // guard below may re-point it at the live selection.
    String currentId;
    if (preserveActiveCompanyId != null &&
        preserveActiveCompanyId.isNotEmpty &&
        hasUsableToken(preserveActiveCompanyId)) {
      currentId = preserveActiveCompanyId;
    } else if (isFullSync &&
        firstAccount.defaultCompanyId.isNotEmpty &&
        hasUsableToken(firstAccount.defaultCompanyId)) {
      // Only honor the account's default company when we actually hold a token
      // for it. The default can be stale (company deleted / user removed) or
      // carry an empty token in the response (see the `missingTokenIds` warning
      // above) — landing there would activate a company whose `tokens[currentId]`
      // is null, so the `:1137` credential fallback would hand it
      // `response.data.first`'s token (a *different* company) → wrong-company
      // data / 401. The sibling delta branch below guards the same way.
      currentId = firstAccount.defaultCompanyId;
    } else if (isFullSync) {
      // `data.first` only as a last resort — see [firstTokenedId].
      currentId = firstTokenedId.isNotEmpty
          ? firstTokenedId
          : response.data.first.company.id;
    } else {
      // Delta: `response.data` holds only the active company and
      // `defaultCompanyId` may point at a company the delta omitted —
      // landing there would activate a possibly-untokened company and 401.
      // Stay on the company the refresh was scoped to, but still prefer one we
      // can authenticate as (the branch above already took the preserved id
      // when it was usable, so reaching here means it wasn't).
      currentId = firstTokenedId.isNotEmpty
          ? firstTokenedId
          : ((preserveActiveCompanyId?.isNotEmpty ?? false)
                ? preserveActiveCompanyId!
                : response.data.first.company.id);
    }

    // A logout landed between the network return and here. Bail before the
    // prune/re-seed so we don't repopulate Drift that `logout()` just cleared.
    if (expectedGeneration != null &&
        expectedGeneration != _sessionGeneration) {
      return;
    }
    await _db.transaction(() async {
      // Full snapshot: the response is the authoritative company set, so prune
      // the ones the account no longer has (plus a stale account row). Delta:
      // prune nothing — the response carries only the active company, so it
      // would destroy every other company's token + `lastSyncAt` and trip a
      // 401→logout on the next company switch. Either way `upsertAll` below
      // updates the survivors in place by PK.
      //
      // Prune, never wipe. `upsertAll` only writes the columns present on the
      // companion, so a surviving row keeps the ~37 top-level columns
      // `CompanyEnvelopeApi` used to omit; deleting it first reset them to
      // table defaults, blanking the user's SMTP credentials (and the expense
      // / task-invoicing / payment-conversion flags) on every launch — issue
      // #29. Those columns now ride the envelope, but the prune is what keeps
      // any future envelope gap from being silently destructive.
      if (isFullSync) {
        await _db.companiesDao.pruneExcept(
          companyIds: liveIds,
          accountId: firstAccount.id,
        );
      }
      await _db.companiesDao.upsertAccount(
        AccountsCompanion.insert(
          id: firstAccount.id,
          email: '',
          plan: firstAccount.plan,
          numTrialDays: firstAccount.numTrialDays,
          isHosted: Value(isHosted),
          defaultCompanyId: Value(firstAccount.defaultCompanyId),
          featuresJson: Value(jsonEncode(firstAccount.toJson())),
          updatedAt: nowMs,
        ),
      );
      // Don't clobber a pending local edit. `updateCompany` writes the
      // companies row optimistically inside its enqueue transaction, so the
      // local row IS the user's not-yet-synced state; overwriting it with the
      // server's stale copy visibly reverts their settings edit while the
      // mutation is still queued — and the next save, seeded from the reverted
      // row, would then overwrite edit #1 on the server too. This table has no
      // `is_dirty` column, so the queued outbox row is the dirty marker (same
      // contract as the `user_settings` loop below).
      //
      // Applies to FULL syncs too, now that the branch above prunes instead of
      // wiping: the row survives, so skipping its write no longer leaves the
      // company row-less. Requiring the row to actually exist keeps that true
      // even if the two ever diverge — a company with no row must fall through
      // to the insert, or it silently vanishes from the picker on the next
      // cold start (`restore()` sources the list from this table, while a full
      // sync sources it from `response.data`).
      final skipCompanyIds = <String>{};
      for (final uc in response.data) {
        if (await _db.outboxDao.hasActiveRowsFor(
              companyId: uc.company.id,
              entityType: kCompanyWireName,
            ) &&
            await _db.companiesDao.byId(uc.company.id) != null) {
          skipCompanyIds.add(uc.company.id);
        }
      }
      // A skipped company still gets the columns the server owns outright:
      // the delta watermark (or every later /refresh re-requests an ever-wider
      // window for as long as the edit stays parked — a 409 parks a year out)
      // and the per-(user, company) flags this background refresh exists to
      // heal. Only the user-editable columns are actually withheld.
      for (final uc in response.data) {
        if (!skipCompanyIds.contains(uc.company.id)) continue;
        await _db.companiesDao.touchSessionColumns(
          companyId: uc.company.id,
          at: syncMark,
          permissions: uc.permissions,
          accountId: uc.account.id,
          isAdmin: uc.isAdmin,
          isOwner: uc.isOwner,
        );
      }
      await _db.companiesDao.upsertAll([
        for (final uc in response.data)
          if (!skipCompanyIds.contains(uc.company.id))
            CompaniesCompanion.insert(
              id: uc.company.id,
              name: uc.company.name,
              displayName: Value(
                companyDisplayName(
                  settings: uc.company.settings,
                  displayName: uc.company.displayName,
                  name: uc.company.name,
                ),
              ),
              logoUrl: Value(companyLogoUrl(uc.company.settings)),
              settings: jsonEncode(uc.company.settings),
              customFields: Value(jsonEncode(uc.company.customFields)),
              // Persist envelope-carried company documents so the Documents tab
              // survives the re-seed and renders offline (mirrors how
              // `applyUpdateResponse` writes this column on a settings save).
              documents: Value(
                jsonEncode(
                  uc.company.documents.map((d) => d.toJson()).toList(),
                ),
              ),
              sizeId: Value(uc.company.sizeId),
              industryId: Value(uc.company.industryId),
              firstMonthOfYear: Value(uc.company.firstMonthOfYear),
              firstDayOfWeek: Value(uc.company.firstDayOfWeek),
              useCommaAsDecimalPlace: Value(uc.company.useCommaAsDecimalPlace),
              legalEntityId: Value(uc.company.legalEntityId),
              enabledModules: Value(uc.company.enabledModules),
              googleAnalyticsKey: Value(uc.company.googleAnalyticsKey),
              matomoId: Value(uc.company.matomoId),
              matomoUrl: Value(uc.company.matomoUrl),
              sessionTimeout: Value(uc.company.sessionTimeout),
              defaultPasswordTimeout: Value(uc.company.defaultPasswordTimeout),
              oauthPasswordRequired: Value(uc.company.oauthPasswordRequired),
              isDisabled: Value(uc.company.isDisabled),
              markdownEnabled: Value(uc.company.markdownEnabled),
              markdownEmailEnabled: Value(uc.company.markdownEmailEnabled),
              reportIncludeDrafts: Value(uc.company.reportIncludeDrafts),
              reportIncludeDeleted: Value(uc.company.reportIncludeDeleted),
              quickbooksJson: Value(
                uc.company.quickbooks == null
                    ? null
                    : jsonEncode(uc.company.quickbooks),
              ),
              enabledTaxRates: Value(uc.company.enabledTaxRates),
              enabledItemTaxRates: Value(uc.company.enabledItemTaxRates),
              enabledExpenseTaxRates: Value(uc.company.enabledExpenseTaxRates),
              calculateTaxes: Value(uc.company.calculateTaxes),
              taxDataJson: Value(
                uc.company.taxData == null
                    ? null
                    : jsonEncode(uc.company.taxData!.toJson()),
              ),
              eInvoiceJson: Value(
                uc.company.eInvoice == null
                    ? null
                    : jsonEncode(uc.company.eInvoice),
              ),
              customSurchargeTaxes1: Value(uc.company.customSurchargeTaxes1),
              customSurchargeTaxes2: Value(uc.company.customSurchargeTaxes2),
              customSurchargeTaxes3: Value(uc.company.customSurchargeTaxes3),
              customSurchargeTaxes4: Value(uc.company.customSurchargeTaxes4),
              trackInventory: Value(uc.company.trackInventory),
              stockNotification: Value(uc.company.stockNotification),
              inventoryNotificationThreshold: Value(
                uc.company.inventoryNotificationThreshold,
              ),
              enableProductDiscount: Value(uc.company.enableProductDiscount),
              enableProductCost: Value(uc.company.enableProductCost),
              enableProductQuantity: Value(uc.company.enableProductQuantity),
              defaultQuantity: Value(uc.company.defaultQuantity),
              showProductDetails: Value(uc.company.showProductDetails),
              fillProducts: Value(uc.company.fillProducts),
              updateProducts: Value(uc.company.updateProducts),
              convertProducts: Value(uc.company.convertProducts),
              convertRateToClient: Value(uc.company.convertRateToClient),
              stopOnUnpaidRecurring: Value(uc.company.stopOnUnpaidRecurring),
              useQuoteTermsOnConversion: Value(
                uc.company.useQuoteTermsOnConversion,
              ),
              smtpHost: Value(uc.company.smtpHost),
              smtpPort: Value(uc.company.smtpPort),
              smtpEncryption: Value(uc.company.smtpEncryption),
              smtpUsername: Value(uc.company.smtpUsername),
              smtpPassword: Value(uc.company.smtpPassword),
              smtpLocalDomain: Value(uc.company.smtpLocalDomain),
              smtpVerifyPeer: Value(uc.company.smtpVerifyPeer),
              expenseMailbox: Value(uc.company.expenseMailbox),
              expenseMailboxActive: Value(uc.company.expenseMailboxActive),
              inboundMailboxAllowCompanyUsers: Value(
                uc.company.inboundMailboxAllowCompanyUsers,
              ),
              inboundMailboxAllowVendors: Value(
                uc.company.inboundMailboxAllowVendors,
              ),
              inboundMailboxAllowClients: Value(
                uc.company.inboundMailboxAllowClients,
              ),
              inboundMailboxAllowUnknown: Value(
                uc.company.inboundMailboxAllowUnknown,
              ),
              inboundMailboxWhitelist: Value(
                uc.company.inboundMailboxWhitelist,
              ),
              inboundMailboxBlacklist: Value(
                uc.company.inboundMailboxBlacklist,
              ),
              expenseInclusiveTaxes: Value(uc.company.expenseInclusiveTaxes),
              calculateExpenseTaxByAmount: Value(
                uc.company.calculateExpenseTaxByAmount,
              ),
              autoStartTasks: Value(uc.company.autoStartTasks),
              showTaskEndDate: Value(uc.company.showTaskEndDate),
              showTasksTable: Value(uc.company.showTasksTable),
              invoiceTaskDatelog: Value(uc.company.invoiceTaskDatelog),
              invoiceTaskTimelog: Value(uc.company.invoiceTaskTimelog),
              invoiceTaskHours: Value(uc.company.invoiceTaskHours),
              invoiceTaskItemDescription: Value(
                uc.company.invoiceTaskItemDescription,
              ),
              invoiceTaskProject: Value(uc.company.invoiceTaskProject),
              invoiceTaskProjectHeader: Value(
                uc.company.invoiceTaskProjectHeader,
              ),
              invoiceTaskLock: Value(uc.company.invoiceTaskLock),
              invoiceTaskDocuments: Value(uc.company.invoiceTaskDocuments),
              markExpensesInvoiceable: Value(
                uc.company.markExpensesInvoiceable,
              ),
              markExpensesPaid: Value(uc.company.markExpensesPaid),
              invoiceExpenseDocuments: Value(
                uc.company.invoiceExpenseDocuments,
              ),
              notifyVendorWhenPaid: Value(uc.company.notifyVendorWhenPaid),
              enableApplyingPayments: Value(uc.company.enableApplyingPayments),
              convertPaymentCurrency: Value(uc.company.convertPaymentCurrency),
              convertExpenseCurrency: Value(uc.company.convertExpenseCurrency),
              hasEInvoiceCertificate: Value(uc.company.hasEInvoiceCertificate),
              hasEInvoiceCertificatePassphrase: Value(
                uc.company.hasEInvoiceCertificatePassphrase,
              ),
              subdomain: Value(uc.company.subdomain),
              portalDomain: Value(uc.company.portalDomain),
              portalMode: Value(uc.company.portalMode),
              clientCanRegister: Value(uc.company.clientCanRegister),
              companyKey: Value(uc.company.companyKey),
              clientRegistrationFields: Value(
                jsonEncode(
                  uc.company.clientRegistrationFields
                      .map((f) => f.toJson())
                      .toList(),
                ),
              ),
              permissions: uc.permissions,
              accountId: uc.account.id,
              token: uc.token.token,
              isAdmin: Value(uc.isAdmin),
              isOwner: Value(uc.isOwner),
              // Mirror the server's `updated_at` (seconds), not local wall-clock
              // ms, so the derived `cacheBustedLogoUrl` `?v=` only changes when
              // the company actually changes. With `nowMs` every no-op /refresh
              // re-minted the logo URL — re-emitting the session (sidebar rebuild)
              // and re-fetching an identical logo every 5 min. Matches
              // CompanyRepository's persist (server seconds, now-seconds fallback);
              // `lastSyncAt` below is what tracks "last synced".
              updatedAt: uc.company.updatedAt > 0
                  ? uc.company.updatedAt
                  : nowMs ~/ 1000,
              lastSyncAt: Value(syncMark),
            ),
      ]);
      // Per-(user, company) settings — split `table_columns` out of the
      // generic settings blob so the picker can watch it directly. Keep
      // the rest under `extra_json` so the PUT we'll later send preserves
      // every field the new app doesn't yet model.
      for (final uc in response.data) {
        // Don't clobber a pending local edit: a `user_settings` PUT parked
        // in the outbox (offline, 412 password gate) still owns this row —
        // overwriting it with server data visually reverts the edit while
        // the mutation is still queued. This table has no `is_dirty`
        // column, so the queued outbox row IS the dirty marker. Mirrors
        // `upsertAllPreservingDirty`'s contract for entity tables.
        final pendingSettingsEdit = await _db.outboxDao.hasActiveRowsFor(
          companyId: uc.company.id,
          entityType: kUserSettingsWireName,
        );
        if (pendingSettingsEdit) continue;
        final settings = uc.settings;
        final tableColumns = settings['table_columns'];
        final extra = Map<String, dynamic>.from(settings)
          ..remove('table_columns');
        await _db.userSettingsDao.upsert(
          UserSettingsCompanion(
            companyId: Value(uc.company.id),
            userId: Value(uc.user.id),
            tableColumnsJson: Value(
              jsonEncode(
                tableColumns is Map ? tableColumns : <String, dynamic>{},
              ),
            ),
            extraJson: Value(jsonEncode(extra)),
            updatedAt: Value(nowMs),
          ),
        );
      }
      // Auth user record. /refresh's `data[N].user` carries the full
      // profile shape — first/last name, signature, language_id,
      // custom_value1..4 — so the User Details screen reads from Drift
      // without round-tripping `GET /users/{id}` (which the server gates
      // with a 412 password check). The `payload` blob is shaped like the
      // `GET /users/{id}` envelope so `UserRepository._fromRow` decodes
      // it unchanged; the nested `company_user.settings` mirrors what the
      // PUT path round-trips.
      for (final uc in response.data) {
        if (uc.user.id.isEmpty) continue;
        // Don't clobber a pending local profile edit. A dirty row's
        // PUT /users/{id} routinely parks in the outbox behind the 412
        // password sheet; until it drains, every refresh tick would
        // visually revert User Details to stale server values while the
        // edit is still queued (and re-typing it would enqueue a
        // duplicate). The row heals to server truth once the mutation
        // syncs. Mirrors `upsertAllPreservingDirty`.
        final existingUser = await _db.userDao.getByCompanyAndId(
          companyId: uc.company.id,
          id: uc.user.id,
        );
        if (existingUser?.isDirty == true) continue;
        final userPayload = <String, dynamic>{
          'id': uc.user.id,
          'first_name': uc.user.firstName,
          'last_name': uc.user.lastName,
          'email': uc.user.email,
          'phone': uc.user.phone,
          'signature': uc.user.signature,
          'language_id': uc.user.languageId,
          'custom_value1': uc.user.customValue1,
          'custom_value2': uc.user.customValue2,
          'custom_value3': uc.user.customValue3,
          'custom_value4': uc.user.customValue4,
          'oauth_provider_id': uc.user.oauthProviderId,
          'company_user': <String, dynamic>{
            'settings': uc.settings,
            'is_admin': uc.isAdmin,
            'is_owner': uc.isOwner,
            'permissions': uc.permissions,
          },
        };
        await _db.userDao.upsert(
          UsersCompanion(
            id: Value(uc.user.id),
            companyId: Value(uc.company.id),
            firstName: Value(uc.user.firstName),
            lastName: Value(uc.user.lastName),
            email: Value(uc.user.email),
            phone: Value(uc.user.phone),
            languageId: Value(uc.user.languageId),
            signature: Value(uc.user.signature),
            updatedAt: Value(nowMs),
            isDirty: const Value(false),
            payload: Value(jsonEncode(userPayload)),
          ),
        );
      }
    });
    // Seed any bundled per-entity arrays in `data[N].company.*` (today:
    // task_statuses, company_gateways, + ~11 more). Runs after the main
    // transaction commits. Each repo's `applyBundle` opens its own
    // `db.transaction`; wrapping the whole per-company fan-out in one
    // outer transaction collapses those ~13 inner transactions into
    // savepoints, so a login produces a single commit + a single
    // watch-fire wave per company instead of ~13. The try/catch stays
    // *outside* the transaction: a thrown bundle rolls back only that
    // company's bundle writes (all-or-nothing per company) while login
    // still completes — the session/credentials are already set above
    // and a partial-bundle response must not keep the user out.
    final bundlesHook = onPersistBundles;
    if (bundlesHook != null) {
      for (final uc in response.data) {
        try {
          await _db.transaction(
            () => bundlesHook(
              companyId: uc.company.id,
              company: uc.company,
              fullSync: isFullSync,
            ),
          );
        } catch (e, st) {
          _log.warning(
            'onPersistBundles failed for company ${uc.company.id}',
            e,
            st,
          );
        }
      }
    }

    // Seed the static catalog (currencies, countries, languages, …) straight
    // from the `/refresh` envelope's `static` blob instead of an independent
    // `GET /api/v1/statics` request — the server already includes it when
    // `include_static=true` was sent. Best-effort and outside the main
    // transaction (same contract as the bundle fan-out): a failure here must
    // not keep the user out, and `applyStatic` no-ops on the empty map a
    // login response or a delta refresh carries.
    final staticHook = onApplyStatic;
    if (staticHook != null) {
      try {
        await staticHook(response.staticData);
      } catch (e, st) {
        _log.warning('onApplyStatic failed', e, st);
      }
    }

    // Final guard before anything observable is committed. This sits ahead of
    // the secure-storage writes, the `_session`/`_credentials` assignments, AND
    // the `_attachCompaniesWatcher` / `_fireActiveCompanyChanged` tail below —
    // that tail fires `onActiveCompanyChanged`, which would otherwise restart
    // the refresh scheduler `logout()` just stopped. If a logout slipped in
    // during the Drift/bundle/static awaits above, stop here.
    if (expectedGeneration != null &&
        expectedGeneration != _sessionGeneration) {
      return;
    }
    // A `switchCompany` landed while this refresh was in flight (network
    // round-trip or the Drift/bundle persist above): the resolution chain
    // ran against the pre-request snapshot, so committing its id would
    // silently bounce the user back to the previous company — sidebar and
    // lists flip, the old company's activation sweep re-runs, and the stale
    // id is persisted so even a restart restores the wrong company. Keep the
    // user's live selection instead whenever it moved away from the
    // at-request snapshot and the merged token map still covers it. (A
    // deliberate caller override — addCompany's teleport into the freshly
    // created company — leaves the live id equal to the snapshot, so it is
    // unaffected.)
    final liveCompanyId = _session.value?.currentCompanyId;
    if (activeCompanyIdAtRequest != null &&
        liveCompanyId != null &&
        liveCompanyId.isNotEmpty &&
        liveCompanyId != activeCompanyIdAtRequest &&
        liveCompanyId != currentId &&
        tokens.containsKey(liveCompanyId)) {
      _log.info(
        'company switch raced /refresh; keeping live $liveCompanyId '
        'over snapshot $currentId',
      );
      currentId = liveCompanyId;
    }
    await _secure.write(kAuthTokensKey, jsonEncode(tokens));
    await _secure.write(kAuthBaseUrlKey, baseUrl);
    await _secure.write(kAuthIsHostedKey, isHosted ? 'true' : 'false');
    await _secure.write(kAuthCurrentCompanyIdKey, currentId);
    // A fresh sign-in / token activation is a re-auth — clear any idle-timeout
    // re-lock flag. (A no-op on a normal authenticated refresh, where it's
    // already absent.) Biometric-OFF locked sessions only reach here via an
    // explicit login; biometric-ON sessions stay gated by
    // `_requiresBiometricUnlock` regardless, so clearing here is safe.
    await _secure.delete(kAuthSessionLockedKey);

    // Preserve the user's biometric preference across `/refresh` calls.
    // Fresh logins see no value (logout cleared it) so this resolves to false;
    // a background `_refreshSessionQuietly` after `restore` reads whatever the
    // user set on a previous launch. Never touch `_requiresBiometricUnlock` —
    // that flag is owned by `restore` / `completeBiometricUnlock`.
    final biometricEnabled =
        (await _secure.read(kAuthBiometricEnabledKey)) == 'true';

    _tokensByCompany = tokens;
    final firstUser = response.data.first.user;
    // A full snapshot's `data` is the authoritative company set. A delta is
    // scoped to the active company, so its `data` omits the others — source
    // the picker list from the Drift table instead (still complete: a delta
    // prunes nothing and only upserts the active row).
    final List<AuthCompany> companiesList;
    if (isFullSync) {
      companiesList = response.data
          .map(
            (uc) => AuthCompany(
              id: uc.company.id,
              name: uc.company.name,
              displayName: companyDisplayName(
                settings: uc.company.settings,
                displayName: uc.company.displayName,
                name: uc.company.name,
              ),
              // Raw URL here: the login envelope carries no `updated_at`, and
              // this is the cold-start initial paint (empty image cache, so the
              // current logo loads correctly anyway). The reactive
              // `_onCompaniesChanged` path applies the `?v=` cache-bust on the
              // next Drift emission (and `restore()` does on cold start).
              logoUrl: companyLogoUrl(uc.company.settings),
              permissions: uc.permissions,
              enabledModules: uc.company.enabledModules,
              isAdmin: uc.isAdmin,
              isOwner: uc.isOwner,
            ),
          )
          .toList(growable: false);
    } else {
      companiesList = [
        for (final c in await _db.companiesDao.all()) _authCompanyFromRow(c),
      ];
    }
    _session.value = AuthSession(
      baseUrl: baseUrl,
      isHosted: isHosted,
      accountId: firstAccount.id,
      plan: firstAccount.plan,
      planExpires: firstAccount.planExpires,
      trialPlan: firstAccount.trialPlan,
      trialStarted: firstAccount.trialStarted,
      numTrialDays: firstAccount.numTrialDays,
      trialDaysLeft: firstAccount.trialDaysLeft,
      hasIapPlan: firstAccount.hasIapPlan,
      defaultCompanyId: firstAccount.defaultCompanyId,
      hostedClientCount: firstAccount.hostedClientCount,
      hostedCompanyCount: firstAccount.hostedCompanyCount,
      companies: companiesList,
      currentCompanyId: currentId,
      userId: firstUser.id,
      userEmail: firstUser.email,
      // The envelope DOES carry these (UserApi.first_name/last_name); omitting
      // them left the session identity name blank on every login/refresh, and
      // re-blanked the names restore() had recovered from Drift on the next
      // background refresh (L9).
      userFirstName: firstUser.firstName,
      userLastName: firstUser.lastName,
      userPhone: firstUser.phone,
      googleTwoFactorEnabled: firstUser.google2faSecret,
      verifiedPhoneNumber: firstUser.verifiedPhoneNumber,
      biometricEnabled: biometricEnabled,
      referralCode: firstUser.referralCode,
      referralMeta: firstUser.referralMeta,
      ninjaPortalUrl: response.data.first.ninjaPortalUrl,
      eInvoicingToken: firstAccount.eInvoicingToken,
      reportErrors: firstAccount.reportErrors,
    );
    _credentials.value = ApiCredentials(
      baseUrl: baseUrl,
      token: tokens[currentId] ?? response.data.first.token.token,
      isHosted: isHosted,
    );
    _attachCompaniesWatcher();
    _fireActiveCompanyChanged(currentId);
  }

  /// Subscribe to the Drift `companies` table once per repo lifetime so a
  /// settings-driven name/logo edit (or any other writer) flows back into
  /// `AuthSession.companies` and re-renders the sidebar picker without
  /// waiting for the next `/refresh`. Idempotent — repeated calls (login,
  /// /refresh, restore) reuse the existing subscription.
  void _attachCompaniesWatcher() {
    if (_companiesSub != null) return;
    _companiesSub = _db.companiesDao.watchAll().listen(_onCompaniesChanged);
  }

  /// Build an [AuthCompany] from a Drift row. Mirrors [restore]'s mapping
  /// (logo column wins, settings blob is the pre-v7 fallback); used to
  /// rebuild the picker list from the table after a delta refresh, whose
  /// `data` block omits non-active companies.
  AuthCompany _authCompanyFromRow(CompanyRow c) {
    Map<String, dynamic> settings = const {};
    try {
      final decoded = jsonDecode(c.settings);
      if (decoded is Map<String, dynamic>) settings = decoded;
    } catch (_) {}
    final logoFromColumn = c.logoUrl;
    final rawLogo = (logoFromColumn != null && logoFromColumn.isNotEmpty)
        ? logoFromColumn
        : companyLogoUrl(settings);
    final logoUrl = cacheBustedLogoUrl(rawLogo, c.updatedAt);
    return AuthCompany(
      id: c.id,
      name: c.name,
      displayName: companyDisplayName(
        settings: settings,
        displayName: c.displayName ?? '',
        name: c.name,
      ),
      logoUrl: logoUrl,
      permissions: c.permissions,
      enabledModules: c.enabledModules,
      isAdmin: c.isAdmin,
      isOwner: c.isOwner,
    );
  }

  void _onCompaniesChanged(List<CompanyRow> rows) {
    final s = _session.value;
    if (s == null) return;
    // Keep only rows that match an id already in the session — guards against
    // the brief mid-transaction state in `_persistAndActivate` (prune +
    // upsert) and any future writer that touches the table before the session
    // is re-assigned.
    final knownIds = {for (final c in s.companies) c.id};
    final byId = {
      for (final r in rows)
        if (knownIds.contains(r.id)) r.id: r,
    };
    if (byId.length != s.companies.length) return;
    final rebuilt = <AuthCompany>[];
    var changed = false;
    for (final existing in s.companies) {
      final row = byId[existing.id]!;
      Map<String, dynamic> settings = const {};
      if (row.settings.isNotEmpty) {
        try {
          final decoded = jsonDecode(row.settings);
          if (decoded is Map<String, dynamic>) settings = decoded;
        } catch (_) {}
      }
      // Mirror restore()'s logo precedence: dedicated column wins, settings
      // blob is the fallback for pre-v7 rows.
      final logoFromColumn = row.logoUrl;
      final rawLogo = (logoFromColumn != null && logoFromColumn.isNotEmpty)
          ? logoFromColumn
          : companyLogoUrl(settings);
      final logoUrl = cacheBustedLogoUrl(rawLogo, row.updatedAt);
      final displayName = companyDisplayName(
        settings: settings,
        displayName: row.displayName ?? '',
        name: row.name,
      );
      if (existing.name != row.name ||
          existing.displayName != displayName ||
          existing.logoUrl != logoUrl ||
          existing.permissions != row.permissions ||
          existing.enabledModules != row.enabledModules ||
          existing.isAdmin != row.isAdmin ||
          existing.isOwner != row.isOwner) {
        changed = true;
      }
      rebuilt.add(
        AuthCompany(
          id: existing.id,
          name: row.name,
          displayName: displayName,
          logoUrl: logoUrl,
          permissions: row.permissions,
          enabledModules: row.enabledModules,
          isAdmin: row.isAdmin,
          isOwner: row.isOwner,
        ),
      );
    }
    if (!changed) return;
    _session.value = s.copyWith(companies: rebuilt);
  }

  Future<void> dispose() async {
    await _companiesSub?.cancel();
    _companiesSub = null;
    _session.dispose();
    _credentials.dispose();
    _requiresBiometricUnlock.dispose();
  }
}
