import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/google_oauth.dart';
import 'package:admin/utils/local_network_host.dart';

/// Which credential flow the user picked. The paths share most state
/// (hosted toggle, base URL) but call different repository methods on submit.
enum LoginMethod { email, apple, google }

/// State machine for the login screen.
///
/// The view binds to this and surfaces:
///   * the hosted/self-hosted toggle,
///   * the email/Apple method toggle,
///   * the URL field (only when self-hosted),
///   * loading / error / success states.
///
/// The OTP field is always rendered in the view; we send it only when
/// non-empty, so there is no `requiresOtp` flag here.
class LoginViewModel extends ChangeNotifier {
  LoginViewModel({required this.auth}) {
    // Dev-machine credential pre-fill. Allowed in debug + profile builds so
    // perf testing with `flutter run --profile` keeps working, but blocked in
    // release so a stray `--dart-define-from-file=dev.json` at release build
    // time can never bake credentials into a shipped binary.
    if (!kReleaseMode) {
      if (Env.devEmail.isNotEmpty) email = Env.devEmail.trim();
      if (Env.devPassword.isNotEmpty) password = Env.devPassword;
    }
  }

  final AuthRepository auth;

  /// True = use `Env.hostedApiUrl`; false = use [urlOverride].
  bool isHosted = true;

  /// Which sign-in flow the user picked.
  LoginMethod method = LoginMethod.email;

  /// Whether to offer the Google segment. Android needs a configured
  /// `serverClientId`; iOS resolves its own. The view hides the segment when
  /// false so we never show a button that can't complete.
  bool get googleEnabled => GoogleOAuth.isEnabled;

  /// Whether to offer the Apple segment — iOS and macOS only, matching
  /// admin-portal's `supportsAppleOAuth()`. Web: no in-app OAuth callback
  /// handler (locked decision — web is email/password only; see plan).
  /// Android: `sign_in_with_apple` requires `webAuthenticationOptions`
  /// (an Apple Services ID + server return URL we don't ship); without it
  /// the plugin throws a bare `Exception` that escapes every typed catch in
  /// [submitApple]. Windows/Linux: the plugin is NotSupported — the button
  /// always errored after a tap.
  bool get appleEnabled {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  String urlOverride = '';
  String email = '';
  String password = '';
  String oneTimePassword = '';

  /// Optional `X-API-SECRET` for self-hosted servers that set `API_SECRET`.
  /// Sent only on the self-hosted login / recover requests; never persisted
  /// (the server enforces it only on the pre-auth routes). Ignored when hosted
  /// — the field is hidden and the service falls back to `Env.hostedApiSecret`.
  String secret = '';

  bool _busy = false;
  bool get busy => _busy;

  /// Set in [dispose] so the fire-and-forget [runPrecheck] can bail instead of
  /// notifying a dead notifier. Mirrors the guard on `GenericListViewModel` /
  /// `GenericDetailViewModel`.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ── Login precheck ─────────────────────────────────────────────────
  // `POST /login/precheck` tells us whether this email needs a TOTP code and
  // whether the server enforces an API secret, so the form can hide the
  // fields that don't apply instead of labelling them "(optional)" and making
  // the user guess. Null = not asked yet, or the ask failed — either way the
  // form shows everything, so a missing/older/unreachable endpoint degrades
  // to exactly the pre-precheck behavior.
  LoginPrecheck? _precheck;
  LoginPrecheck? get precheck => _precheck;

  /// Email address we have already **asked** about, under the current server
  /// config — so a repeated blur on an unchanged field doesn't re-hit
  /// `/login/precheck` (the server registers it under `throttle:precheck`).
  ///
  /// Set on every completed attempt, including one that came back null: a
  /// server that 404s the route would otherwise be re-hit on every single
  /// blur. [_invalidatePrecheck] clears it whenever the server or the email
  /// changes, which is what re-arms the ask.
  String _precheckedEmail = '';

  /// Show the TOTP field unless the server has told us this account has no
  /// TOTP. Optimistic on purpose — never hide a field we aren't sure about.
  bool get showOtpField => _precheck?.requiresOtp ?? true;

  /// Show the self-hosted API-secret field unless the server has told us it
  /// isn't configured. Same optimistic rule as [showOtpField].
  bool get showSecretField => _precheck?.secretRequired ?? true;

  /// True once the server has answered for the current email — lets the view
  /// label the secret field "required" rather than "(optional)".
  bool get secretIsRequired => _precheck?.secretRequired ?? false;

  /// Ask the server what this email needs. Safe to call repeatedly: it
  /// no-ops on a blank/unchanged email and swallows every failure (the
  /// service returns null rather than throwing), so it can never block the
  /// user from logging in. Call on email-field blur.
  Future<void> runPrecheck() async {
    final target = email;
    if (target.isEmpty || !target.contains('@')) return;
    // Deliberately does NOT also require a non-null `_precheck`: a failed
    // attempt still counts as asked (see [_precheckedEmail]).
    if (target == _precheckedEmail) return;
    // A bad self-hosted URL is surfaced by submit(), not here — silently skip.
    final baseUrl = isHosted ? Env.hostedApiUrl : _bestEffortBaseUrl();
    if (baseUrl == null) return;

    final result = await auth.precheckLogin(
      baseUrl: baseUrl,
      isHosted: isHosted,
      email: target,
      secret: secret.isEmpty ? null : secret,
    );
    // Disposed while in flight — this is fire-and-forget from the email
    // field's blur, so a fast submit can tear the screen down before the
    // 250 ms server-side time floor elapses. Notifying past dispose throws.
    if (_disposed) return;
    // The user may have edited the address while the request was in flight.
    if (target != email) return;
    _precheckedEmail = target;
    _precheck = result;
    // Drop a code the user can no longer see: `submit()` sends
    // `one_time_password` whenever it's non-empty, so a stale value left
    // behind by the now-hidden field would fail an otherwise-valid login.
    // (`secret` deliberately survives — a stale one is ignored by a server
    // with no `API_SECRET` configured, and keeping it means switching back to
    // a secret-requiring URL restores what was typed.)
    if (!showOtpField) oneTimePassword = '';
    notifyListeners();
  }

  /// Resolve the self-hosted URL without surfacing an error — the precheck is
  /// best-effort, so an unusable URL just means "don't ask".
  String? _bestEffortBaseUrl() => resolveSelfHostedBaseUrl(
    urlOverride,
    allowInsecureHttpAnywhere: kDebugMode,
  ).url;

  // Localization key for the current error message. When set, the view
  // resolves it via `context.tr(errorKey!, errorParams)`. A null `errorKey`
  // with a non-null `errorMessage` means the message came back from the
  // server pre-formatted (validation / API messages) and is shown as-is.
  String? _errorKey;
  String? get errorKey => _errorKey;
  Map<String, String> _errorParams = const {};
  Map<String, String> get errorParams => _errorParams;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _setError({String? key, Map<String, String>? params, String? message}) {
    _errorKey = key;
    _errorParams = params ?? const {};
    _errorMessage = message;
  }

  void _clearError() {
    _errorKey = null;
    _errorParams = const {};
    _errorMessage = null;
  }

  Map<String, List<String>> _fieldErrors = const {};
  Map<String, List<String>> get fieldErrors => _fieldErrors;

  /// Drop a precheck answer that no longer applies.
  ///
  /// The answer is per **(server, email)** — changing either invalidates it.
  /// Clearing [_precheckedEmail] is the part that lets [runPrecheck] ask again;
  /// without it the stale answer stands and, when the new server *does* set
  /// `API_SECRET`, the secret field never reappears and there is nowhere to
  /// type it. Notifies only when something visible actually changed.
  void _invalidatePrecheck() {
    _precheckedEmail = '';
    if (_precheck == null) return;
    _precheck = null;
    notifyListeners();
  }

  void setHosted(bool value) {
    if (isHosted == value) return;
    isHosted = value;
    // Self-hosted servers don't broker third-party OAuth — snap back to email.
    if (!value && method != LoginMethod.email) {
      method = LoginMethod.email;
    }
    // Different origin → the previous host's answer no longer applies.
    _invalidatePrecheck();
    notifyListeners();
  }

  void setMethod(LoginMethod value) {
    if (method == value) return;
    method = value;
    notifyListeners();
  }

  void setUrlOverride(String value) {
    final next = value.trim();
    if (next == urlOverride) return;
    urlOverride = next;
    // The answer belongs to the previous server.
    _invalidatePrecheck();
  }

  void setEmail(String value) {
    final next = value.trim();
    if (next == email) return;
    email = next;
    // The answer belongs to the previous address — drop it so the form falls
    // back to showing both optional fields until a fresh precheck lands.
    _invalidatePrecheck();
  }

  void setPassword(String value) {
    password = value;
  }

  void setOneTimePassword(String value) {
    oneTimePassword = value.trim();
  }

  void setSecret(String value) {
    secret = value.trim();
  }

  /// Validate the self-hosted URL before we POST credentials to it.
  /// Returns the resolved base URL on success, or sets an inline error and
  /// returns null. Hosted builds skip the check (URL is a compile-time const).
  ///
  /// Debug builds allow http to any host (local dev against an unencrypted
  /// server); release restricts http to local network addresses. The policy
  /// itself lives in the pure [resolveSelfHostedBaseUrl] so it stays testable.
  String? _checkedBaseUrl() {
    if (isHosted) return Env.hostedApiUrl;
    final result = resolveSelfHostedBaseUrl(
      urlOverride,
      allowInsecureHttpAnywhere: kDebugMode,
    );
    if (result.url == null) {
      _setError(key: result.errorKey);
      return null;
    }
    return result.url;
  }

  /// Email + password (+ optional OTP). Hot path.
  Future<bool> submit() async {
    if (_busy) return false;
    _busy = true;
    _clearError();
    _fieldErrors = const {};
    notifyListeners();
    final baseUrl = _checkedBaseUrl();
    if (baseUrl == null) {
      _busy = false;
      notifyListeners();
      return false;
    }
    try {
      await auth.login(
        baseUrl: baseUrl,
        isHosted: isHosted,
        email: email,
        password: password,
        oneTimePassword: oneTimePassword.isEmpty ? null : oneTimePassword,
        secret: (isHosted || secret.isEmpty) ? null : secret,
      );
      return true;
    } on ValidationException catch (e) {
      _fieldErrors = e.fieldErrors;
      _setError(message: e.message);
      return false;
    } on UnauthorizedException catch (e) {
      _setError(message: e.message);
      return false;
    } on NetworkException catch (e) {
      _setError(
        key: 'network_error_with_message',
        params: {'message': e.message},
      );
      return false;
    } on ApiException catch (e) {
      _setError(message: e.message);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Sign in with Apple. Returns false on cancellation without setting an
  /// error message (the user just dismissed the sheet, nothing to surface).
  Future<bool> submitApple() async {
    // Defence in depth: the Apple segment is hidden where the native flow
    // doesn't exist ([appleEnabled]) — never let a stray call reach the
    // platform channel there (Android's would throw an untyped Exception).
    if (!appleEnabled) return false;
    if (_busy) return false;
    _busy = true;
    _clearError();
    _fieldErrors = const {};
    notifyListeners();
    final baseUrl = _checkedBaseUrl();
    if (baseUrl == null) {
      _busy = false;
      notifyListeners();
      return false;
    }
    try {
      // The nonce + state needed to bind the Apple response to this request
      // are generated and validated inside the SignInWithApple SDK (iOS &
      // macOS); we don't pass them explicitly. The server verifies the JWT
      // signature on /api/v1/oauth_login — that's where replay protection
      // actually lives.
      final cred = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      await auth.oauthLogin(
        baseUrl: baseUrl,
        isHosted: isHosted,
        provider: 'apple',
        idToken: cred.identityToken,
        authCode: cred.authorizationCode,
        email: cred.email,
      );
      return true;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return false; // sheet dismissed — no error to surface
      }
      _setError(
        key: 'apple_sign_in_failed_with_message',
        params: {'message': e.message},
      );
      return false;
    } on SignInWithAppleException catch (e) {
      _setError(
        key: 'apple_sign_in_unavailable_with_error',
        params: {'error': e.toString()},
      );
      return false;
    } on UnauthorizedException catch (e) {
      _setError(message: e.message);
      return false;
    } on NetworkException catch (e) {
      _setError(
        key: 'network_error_with_message',
        params: {'message': e.message},
      );
      return false;
    } on ApiException catch (e) {
      _setError(message: e.message);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Sign in with Google. Returns false on cancellation without setting an
  /// error (the user dismissed the chooser — nothing to surface), mirroring
  /// [submitApple]. Rides the access-token path: [GoogleOAuth.signIn] yields
  /// an access token (no id_token) which the server exchanges via
  /// `harvestUser` — see `google_oauth.dart` for why.
  Future<bool> submitGoogle() async {
    if (_busy) return false;
    _busy = true;
    _clearError();
    _fieldErrors = const {};
    notifyListeners();
    final baseUrl = _checkedBaseUrl();
    if (baseUrl == null) {
      _busy = false;
      notifyListeners();
      return false;
    }
    try {
      String accessToken = '';
      final ok = await GoogleOAuth.signIn((_, token) {
        accessToken = token;
      });
      if (!ok || accessToken.isEmpty) {
        // Chooser dismissed / no token granted — no error to surface.
        return false;
      }
      await auth.oauthLogin(
        baseUrl: baseUrl,
        isHosted: isHosted,
        provider: 'google',
        accessToken: accessToken,
      );
      return true;
    } on UnauthorizedException catch (e) {
      _setError(message: e.message);
      return false;
    } on NetworkException catch (e) {
      _setError(
        key: 'network_error_with_message',
        params: {'message': e.message},
      );
      return false;
    } on ApiException catch (e) {
      _setError(message: e.message);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> recover() async {
    if (email.isEmpty) {
      _setError(key: 'enter_email_first');
      notifyListeners();
      return false;
    }
    _busy = true;
    _clearError();
    notifyListeners();
    final baseUrl = _checkedBaseUrl();
    if (baseUrl == null) {
      _busy = false;
      notifyListeners();
      return false;
    }
    try {
      await auth.recoverPassword(
        baseUrl: baseUrl,
        isHosted: isHosted,
        email: email,
        secret: (isHosted || secret.isEmpty) ? null : secret,
      );
      return true;
    } on ApiException catch (e) {
      _setError(message: e.message);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}

/// Normalizes and validates a user-entered self-hosted base URL.
///
/// Returns a record: `url` is the resolved base URL on success (scheme
/// preserved / normalized), or `null` with an `errorKey` localization key on
/// failure. Extracted from [LoginViewModel] as a pure function so the release
/// policy is unit-testable — `kDebugMode` is always true under `flutter test`,
/// so [allowInsecureHttpAnywhere] stands in for it.
///
/// Policy:
///  * a bare host (no scheme) is assumed `https://`;
///  * `https://` is always allowed;
///  * `http://` is allowed when [allowInsecureHttpAnywhere] (debug builds) or
///    when the host is a local network address ([isLocalNetworkHost]);
///  * everything else is rejected. Without this, `urlOverride` would accept any
///    string and the app could POST the user's password in cleartext to an
///    arbitrary public host.
({String? url, String? errorKey}) resolveSelfHostedBaseUrl(
  String input, {
  required bool allowInsecureHttpAnywhere,
}) {
  var raw = input.trim();
  // Let users type a bare host like `demo.invoiceninja.com`: prepend https://
  // when no scheme is present. A schemeless string parses with an empty host
  // and would otherwise be rejected below. Explicit schemes are left as typed.
  if (raw.isNotEmpty) {
    final lower = raw.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      raw = 'https://$raw';
    }
  }
  final uri = raw.isEmpty ? null : Uri.tryParse(raw);
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return (url: null, errorKey: 'invalid_url');
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'https') return (url: raw, errorKey: null);
  if (scheme == 'http' &&
      (allowInsecureHttpAnywhere || isLocalNetworkHost(uri.host))) {
    return (url: raw, errorKey: null);
  }
  // Reaching here means a well-formed http:// URL to a non-local host in a
  // release build: the prepend above forces every schemeless or non-http input
  // to https:// (which returns earlier), so the scheme is necessarily http.
  return (url: null, errorKey: 'insecure_url_use_https');
}
