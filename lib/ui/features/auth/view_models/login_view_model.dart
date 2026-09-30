import 'package:flutter/foundation.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/apple_sign_in.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/google_oauth.dart';
import 'package:admin/ui/core/widgets/notify.dart' show formatNotifyError;
import 'package:admin/ui/features/auth/view_models/social_sign_in.dart';
import 'package:admin/utils/local_network_host.dart';

/// The two pages of the login form, mirroring React's `Login.tsx`: the email
/// (plus, here, the server) first, then only the credentials that account
/// needs.
enum LoginStep { email, credentials }

/// Which action is in flight, so the view spins only the button that was
/// pressed. [LoginViewModel.busy] is "any of them".
enum LoginAction { continueToCredentials, login, google, apple, recover }

/// Result of one step of the login screen's lost-authenticator (SMS) reset.
/// The dialog resolves [errorKey] via `context.tr(errorKey!, errorParams)`;
/// a null key with a non-null [errorMessage] is server text shown as-is.
/// [fieldErrors] carries a 422's per-field messages (the server's
/// `exists:users,email` rule puts the real reason there, not in `message`).
/// [unreachable] means the request may or may not have reached the server.
typedef TwoFactorResetResult = ({
  bool ok,
  String? errorKey,
  Map<String, String> errorParams,
  String? errorMessage,
  Map<String, List<String>> fieldErrors,
  bool unreachable,
});

/// State machine for the two-step login screen.
///
/// **Step 1** ([LoginStep.email]): hosted/self-hosted toggle, the server URL
/// (self-hosted), the email, and Continue — which asks `/login/precheck` what
/// this account needs. The social sign-in buttons live here too.
///
/// **Step 2** ([LoginStep.credentials]): the password, plus the TOTP field
/// and the self-hosted API secret only when the precheck says they apply (or
/// could not say — see [continueToCredentials]).
///
/// Errors come in two kinds. Request-level errors ([errorKey] /
/// [errorMessage]) are toasted by the view; field-level ones ([emailErrorKey],
/// [urlErrorKey], [otpErrorKey], [fieldErrors]) render under their field and
/// are never also toasted.
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

  LoginStep _step = LoginStep.email;
  LoginStep get step => _step;

  /// Whether to offer the Google button. Android needs a configured
  /// `serverClientId`; iOS resolves its own. The view hides the button when
  /// false so we never show one that can't complete.
  bool get googleEnabled => GoogleOAuth.isEnabled;

  /// Whether to offer the Apple button — see [AppleSignIn.isSupported].
  bool get appleEnabled => AppleSignIn.isSupported;

  String urlOverride = '';
  String email = '';
  String password = '';
  String oneTimePassword = '';

  /// Optional `X-API-SECRET` for self-hosted servers that set `API_SECRET`.
  /// Sent only on the self-hosted login / recover requests; never persisted
  /// (the server enforces it only on the pre-auth routes). Ignored when hosted
  /// — the field is hidden and the service falls back to `Env.hostedApiSecret`.
  String secret = '';

  LoginAction? _busyAction;
  LoginAction? get busyAction => _busyAction;
  bool get busy => _busyAction != null;

  /// Set in [dispose] so an in-flight request can bail instead of notifying a
  /// dead notifier. Mirrors the guard on `GenericListViewModel` /
  /// `GenericDetailViewModel`.
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Login precheck ─────────────────────────────────────────────────
  // `POST /login/precheck` tells us whether this email needs a TOTP code and
  // whether the server enforces an API secret, so step 2 shows only the
  // fields that apply. Null = not asked yet, or the server could not answer —
  // either way step 2 shows everything, so a missing/older endpoint degrades
  // to the one-page form's behavior.
  LoginPrecheck? _precheck;
  LoginPrecheck? get precheck => _precheck;

  /// Email address we already hold an answer for, under the current server
  /// config — so Change → Continue on an unchanged address doesn't re-hit
  /// `/login/precheck` (hosted throttles it at 4/min per IP).
  ///
  /// Set only when the server actually answered. A null answer is never
  /// cached: it is as often transient (hosted's 429, a 5xx) as permanent (an
  /// older server's 404), and caching a transient one would leave this
  /// address on the optional-OTP fallback — no Disable 2FA — until the user
  /// edits it. Re-asking an older server costs one request per Continue.
  /// [_invalidatePrecheck] clears it whenever the server or the email changes.
  String _precheckedEmail = '';

  /// Show the TOTP field unless the server has told us this account has no
  /// TOTP. Optimistic on purpose — never hide a field we aren't sure about.
  bool get showOtpField => _precheck?.requiresOtp ?? true;

  /// True only once the server has said this account uses TOTP — the view
  /// then labels the field as required and offers the SMS reset.
  bool get otpConfirmed => _precheck?.requiresOtp ?? false;

  /// Show the self-hosted API-secret field unless the server has told us it
  /// isn't configured. Same optimistic rule as [showOtpField].
  bool get showSecretField => _precheck?.secretRequired ?? true;

  /// True once the server has said it enforces an API secret — lets the view
  /// label the field "required" rather than "(optional)".
  bool get secretIsRequired => _precheck?.secretRequired ?? false;

  // ── Errors ─────────────────────────────────────────────────────────

  // Request-level error, toasted by the view. When [errorKey] is set the view
  // resolves it via `context.tr(errorKey!, errorParams)`; a null key with a
  // non-null [errorMessage] means the message came back from the server
  // pre-formatted and is shown as-is.
  String? _errorKey;
  String? get errorKey => _errorKey;
  Map<String, String> _errorParams = const {};
  Map<String, String> get errorParams => _errorParams;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  bool get hasRequestError => _errorKey != null || _errorMessage != null;

  // Client-side validation, rendered inline — localization keys.
  String? _emailErrorKey;
  String? get emailErrorKey => _emailErrorKey;
  String? _urlErrorKey;
  String? get urlErrorKey => _urlErrorKey;
  String? _otpErrorKey;
  String? get otpErrorKey => _otpErrorKey;

  /// Server validation (422) messages keyed by field, rendered inline. Only
  /// ever holds server text, never localization keys.
  Map<String, List<String>> _fieldErrors = const {};
  Map<String, List<String>> get fieldErrors => _fieldErrors;

  /// Field keys `LoginRequest` validates that the credentials step renders
  /// [fieldErrors] under. A 422 that names none of them is toasted instead, so
  /// it can never vanish. Not `one_time_password`: the server never keys a
  /// field error by it — a wrong code is the field-less 422 handled in
  /// [submit], which also checks the OTP field is actually on screen.
  static const _renderedFieldErrors = {'email', 'password'};

  void _setError({String? key, Map<String, String>? params, String? message}) {
    _errorKey = key;
    _errorParams = params ?? const {};
    _errorMessage = message;
  }

  void _clearErrors() {
    _errorKey = null;
    _errorParams = const {};
    _errorMessage = null;
    _emailErrorKey = null;
    _urlErrorKey = null;
    _otpErrorKey = null;
    _fieldErrors = const {};
  }

  /// Drop a precheck answer that no longer applies.
  ///
  /// The answer is per **(server, email)** — changing either invalidates it.
  /// Clearing [_precheckedEmail] is the part that makes the next Continue ask
  /// again; without it the stale answer stands and, when the new server
  /// *does* set `API_SECRET`, the secret field never appears and there is
  /// nowhere to type it.
  void _invalidatePrecheck() {
    _precheckedEmail = '';
    _precheck = null;
  }

  void setHosted(bool value) {
    if (isHosted == value) return;
    isHosted = value;
    _urlErrorKey = null;
    // Different origin → the previous host's answer no longer applies.
    _invalidatePrecheck();
    _notify();
  }

  void setUrlOverride(String value) {
    final next = value.trim();
    if (next == urlOverride) return;
    urlOverride = next;
    // The answer belongs to the previous server.
    _invalidatePrecheck();
    if (_urlErrorKey != null) {
      _urlErrorKey = null;
      _notify();
    }
  }

  void setEmail(String value) {
    final next = value.trim();
    if (next == email) return;
    email = next;
    // The answer belongs to the previous address.
    _invalidatePrecheck();
    if (_emailErrorKey != null || _fieldErrors.containsKey('email')) {
      _emailErrorKey = null;
      _fieldErrors = Map.of(_fieldErrors)..remove('email');
      _notify();
    }
  }

  void setPassword(String value) {
    password = value;
    // Retyping answers the error under the field.
    if (_fieldErrors.containsKey('password')) {
      _fieldErrors = Map.of(_fieldErrors)..remove('password');
      _notify();
    }
  }

  void setOneTimePassword(String value) {
    oneTimePassword = value.trim();
    if (_otpErrorKey != null || _fieldErrors.containsKey('one_time_password')) {
      _otpErrorKey = null;
      _fieldErrors = Map.of(_fieldErrors)..remove('one_time_password');
      _notify();
    }
  }

  void setSecret(String value) {
    secret = value.trim();
  }

  /// Step 1 → step 2. Validates the email and the server URL inline, then
  /// asks `/login/precheck` what this account needs.
  ///
  /// Unlike React — which only ever talks to the server that served it, and
  /// so stays on step 1 whenever the precheck fails — this client talks to
  /// self-hosted servers of any version. So only two failures keep the user
  /// here: an unreachable server (a toast; usually a typo'd URL) and a
  /// rejected address (inline). Anything else the server does — 404 on an
  /// older version, 429, 5xx, a malformed body — moves on with every
  /// optional field shown.
  Future<bool> continueToCredentials() async {
    if (busy) return false;
    _clearErrors();
    final target = email;
    if (target.isEmpty || !target.contains('@')) {
      _emailErrorKey = 'email_is_invalid';
      _notify();
      return false;
    }
    final resolved = _resolveBaseUrl();
    final baseUrl = resolved.url;
    if (baseUrl == null) {
      _urlErrorKey = resolved.errorKey;
      _notify();
      return false;
    }
    // Change → Continue on the same (server, email) reuses the answer —
    // React re-asks here; hosted's 4/min precheck throttle makes that costly.
    if (target == _precheckedEmail) {
      _step = LoginStep.credentials;
      _notify();
      return true;
    }
    final hosted = isHosted;
    final url = urlOverride;
    _busyAction = LoginAction.continueToCredentials;
    _notify();
    try {
      // No secret: `/login/precheck` sits outside `api_secret_check`, and a
      // header value `dart:io` rejects (a pasted non-ASCII secret) would
      // otherwise fail Continue with the secret echoed in the toast.
      final result = await auth.precheckLogin(
        baseUrl: baseUrl,
        isHosted: hosted,
        email: target,
      );
      if (_disposed) return false;
      // The user changed the address or the server while this was in flight:
      // the answer belongs to a question nobody is asking any more. Stay put
      // and say nothing — pressing Continue again asks the right one.
      if (target != email || hosted != isHosted || url != urlOverride) {
        return false;
      }
      _precheck = result;
      // Only a real answer is cached — see [_precheckedEmail].
      _precheckedEmail = result == null ? '' : target;
      _step = LoginStep.credentials;
      return true;
    } on NetworkException catch (e) {
      // Before `ApiException`, which it extends.
      _setError(
        key: 'network_error_with_message',
        params: {'message': e.message},
      );
      return false;
    } on ValidationException catch (e) {
      _fieldErrors = e.fieldErrors.containsKey('email')
          ? e.fieldErrors
          : {
              ...e.fieldErrors,
              'email': [e.message],
            };
      return false;
    } on ApiException catch (e) {
      _setError(message: e.message);
      return false;
    } on Object catch (e) {
      // Login is the one screen a user cannot route around — never let an
      // unexpected throw end on a spinner that silently stops.
      _setError(message: formatNotifyError(e));
      return false;
    } finally {
      _busyAction = null;
      _notify();
    }
  }

  /// Step 2 → step 1 (the "Change" link and Android back). Keeps the email
  /// (React's e2e test pins that), the secret, and the cached precheck answer
  /// — the answer still belongs to this (server, email), and asking again
  /// would spend hosted's precheck throttle for nothing. React clears it.
  void backToEmail() {
    if (busy || _step == LoginStep.email) return;
    _step = LoginStep.email;
    password = '';
    oneTimePassword = '';
    _clearErrors();
    _notify();
  }

  /// Resolve the base URL for a request. Hosted builds skip validation (the
  /// URL is a compile-time const).
  ///
  /// Debug builds allow http to any host (local dev against an unencrypted
  /// server); release restricts http to local network addresses. The policy
  /// itself lives in the pure [resolveSelfHostedBaseUrl] so it stays testable.
  ({String? url, String? errorKey}) _resolveBaseUrl() {
    if (isHosted) return (url: Env.hostedApiUrl, errorKey: null);
    return resolveSelfHostedBaseUrl(
      urlOverride,
      allowInsecureHttpAnywhere: kDebugMode,
    );
  }

  /// [_resolveBaseUrl] for a step-2 request. The URL field isn't on screen
  /// there (Continue already validated it), so a failure is request-level.
  String? _checkedBaseUrl() {
    final resolved = _resolveBaseUrl();
    if (resolved.url == null) _setError(key: resolved.errorKey);
    return resolved.url;
  }

  /// The server told us this account has TOTP, so `/login` without a code is
  /// a certain 400 — and one of hosted's four login attempts a minute. Say so
  /// under the field instead. Safe to block on: the answer comes from the
  /// server's own record for this user (and [confirmTwoFactorReset] drops it
  /// when a reset may have changed that record).
  ///
  /// Deliberately no equivalent for the API secret: `secret_required` is
  /// `(bool) config('ninja.api_secret')`, but `ApiSecretCheck` is skipped
  /// entirely in hosted mode, so a hosted server reached through the
  /// Self-Hosted toggle can report a secret it will never check (BACKEND.md).
  /// The secret field is labelled required and Enter moves to it; a wrong or
  /// missing one comes back from the server as a 403.
  bool _missingRequiredOtp() {
    if (!otpConfirmed || oneTimePassword.isNotEmpty) return false;
    _otpErrorKey = 'please_enter_a_value';
    return true;
  }

  /// Email + password (+ OTP / secret). Hot path.
  Future<bool> submit() async {
    if (busy) return false;
    _clearErrors();
    if (_missingRequiredOtp()) {
      _notify();
      return false;
    }
    final baseUrl = _checkedBaseUrl();
    if (baseUrl == null) {
      _notify();
      return false;
    }
    _busyAction = LoginAction.login;
    _notify();
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
      if (e.fieldErrors.keys.any(_renderedFieldErrors.contains)) {
        _fieldErrors = e.fieldErrors;
      } else if (e.fieldErrors.isEmpty && showOtpField) {
        // A wrong TOTP code is a 422 with a message and no `errors` object
        // (`LoginController::verifyTwoFactor`) — the only field-less 422 this
        // form can provoke, so put it where the fix is. A *missing* code is a
        // 400, indistinguishable from bad credentials, and stays a toast.
        _fieldErrors = {
          'one_time_password': [e.message],
        };
      } else {
        _setError(message: e.message);
      }
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
    } on Object catch (e) {
      // Login is the one screen a user cannot route around, and it was the one
      // screen with no catch-all: anything that isn't an `ApiException` subtype
      // escaped, `finally` cleared the busy flag, and the view (which has no
      // try/catch either) turned it into an unhandled zone error. In release
      // the button simply un-spun and said nothing, forever. Real throwers:
      // `GoogleOAuth.signIn` is a platform channel (`PlatformException` code 10
      // DEVELOPER_ERROR on a SHA-1 / client-id mismatch, or
      // `MissingPluginException`), `_persistAndActivate` writes to the keychain
      // and to Drift, and an unexpected response shape gives a `TypeError`.
      // Every other mutation in the app gets this net from
      // `runMutationWithNotify`.
      _setError(message: formatNotifyError(e));
      return false;
    } finally {
      _busyAction = null;
      _notify();
    }
  }

  /// Sign in with Apple. Returns false on cancellation without setting an
  /// error message (the user just dismissed the sheet, nothing to surface).
  Future<bool> submitApple() => _submitSocial(
    LoginAction.apple,
    (baseUrl) =>
        signInWithApple(auth: auth, baseUrl: baseUrl, isHosted: isHosted),
  );

  /// Sign in with Google. Returns false on cancellation without setting an
  /// error (the user dismissed the chooser — nothing to surface), mirroring
  /// [submitApple]. Rides the access-token path: [GoogleOAuth.signIn] yields
  /// an access token (no id_token) which the server exchanges via
  /// `harvestUser` — see `google_oauth.dart` for why.
  Future<bool> submitGoogle() => _submitSocial(
    LoginAction.google,
    (baseUrl) =>
        signInWithGoogle(auth: auth, baseUrl: baseUrl, isHosted: isHosted),
  );

  /// Busy / error bookkeeping around one social sign-in. `false` without an
  /// error means the user dismissed the provider's sheet.
  Future<bool> _submitSocial(
    LoginAction action,
    Future<bool> Function(String baseUrl) signIn,
  ) async {
    if (busy) return false;
    _clearErrors();
    final baseUrl = _checkedBaseUrl();
    if (baseUrl == null) {
      _notify();
      return false;
    }
    _busyAction = action;
    _notify();
    try {
      return await signIn(baseUrl);
    } on SocialSignInFailure catch (f) {
      _setError(key: f.key, params: f.params, message: f.message);
      return false;
    } finally {
      _busyAction = null;
      _notify();
    }
  }

  /// "Forgot your password?" — emails a reset link to the address on step 2.
  Future<bool> recover() async {
    if (busy) return false;
    _clearErrors();
    if (email.isEmpty) {
      _setError(key: 'enter_email_first');
      _notify();
      return false;
    }
    final baseUrl = _checkedBaseUrl();
    if (baseUrl == null) {
      _notify();
      return false;
    }
    _busyAction = LoginAction.recover;
    _notify();
    try {
      await auth.recoverPassword(
        baseUrl: baseUrl,
        isHosted: isHosted,
        email: email,
        secret: (isHosted || secret.isEmpty) ? null : secret,
      );
      return true;
    } on NetworkException catch (e) {
      _setError(
        key: 'network_error_with_message',
        params: {'message': e.message},
      );
      return false;
    } on ApiException catch (e) {
      _setError(message: e.message);
      return false;
    } on Object catch (e) {
      // Same catch-all as [submit]: never end on a silent spinner.
      _setError(message: formatNotifyError(e));
      return false;
    } finally {
      _busyAction = null;
      _notify();
    }
  }

  // ── Lost-authenticator reset (hosted) ──────────────────────────────
  // React's `Disable2faModal`: text a code to the phone on file, then verify
  // it, which turns 2FA off. The dialogs own their busy state; these only
  // make the calls and translate failures.

  /// Text a reset code to the phone on file for [targetEmail].
  Future<TwoFactorResetResult> sendTwoFactorResetCode(String targetEmail) =>
      _twoFactorReset(
        (baseUrl) => auth.sendTwoFactorResetCode(
          baseUrl: baseUrl,
          isHosted: isHosted,
          email: targetEmail,
        ),
      );

  /// Verify [code] for [targetEmail], disabling 2FA on that account. When it
  /// is the account on this form, the OTP field goes away with it — but only
  /// then: resetting some other address must not hide this one's field.
  ///
  /// When the call couldn't be completed (offline, timed out) the server may
  /// or may not have disabled 2FA already, so the cached "this account has
  /// TOTP" answer is dropped to *unknown*: the code field turns optional and
  /// [submit] stops requiring it, rather than blocking a login that may no
  /// longer need a code.
  Future<TwoFactorResetResult> confirmTwoFactorReset(
    String targetEmail,
    String code,
  ) async {
    final result = await _twoFactorReset(
      (baseUrl) => auth.confirmTwoFactorReset(
        baseUrl: baseUrl,
        isHosted: isHosted,
        email: targetEmail,
        code: code,
      ),
    );
    // The server looks the address up case-insensitively.
    final sameAccount = targetEmail.trim().toLowerCase() == email.toLowerCase();
    if (!sameAccount || _precheck == null) return result;
    if (result.ok) {
      // The code field goes away; drop what it held so `submit()` (which
      // sends any non-empty code) matches the screen.
      _precheck = _precheck!.withoutOtp();
      oneTimePassword = '';
    } else if (result.unreachable) {
      // The field stays, now optional, still showing what was typed — so
      // keep sending it. A code is ignored by an account with 2FA off.
      _invalidatePrecheck();
    } else {
      return result;
    }
    _otpErrorKey = null;
    _fieldErrors = Map.of(_fieldErrors)..remove('one_time_password');
    _notify();
    return result;
  }

  Future<TwoFactorResetResult> _twoFactorReset(
    Future<void> Function(String baseUrl) call,
  ) async {
    TwoFactorResetResult failure({
      String? key,
      Map<String, String> params = const {},
      String? message,
      Map<String, List<String>> fieldErrors = const {},
      bool unreachable = false,
    }) => (
      ok: false,
      errorKey: key,
      errorParams: params,
      errorMessage: message,
      fieldErrors: fieldErrors,
      unreachable: unreachable,
    );

    final resolved = _resolveBaseUrl();
    final baseUrl = resolved.url;
    if (baseUrl == null) return failure(key: resolved.errorKey);
    try {
      await call(baseUrl);
      return (
        ok: true,
        errorKey: null,
        errorParams: const <String, String>{},
        errorMessage: null,
        fieldErrors: const <String, List<String>>{},
        unreachable: false,
      );
    } on NetworkException catch (e) {
      return failure(
        key: 'network_error_with_message',
        params: {'message': e.message},
        unreachable: true,
      );
    } on ValidationException catch (e) {
      // 422 (an unknown address) — the reason is in `errors.email`; the
      // top-level message is Laravel's generic one.
      return failure(message: e.message, fieldErrors: e.fieldErrors);
    } on ApiException catch (e) {
      // 400 (no phone on file, code not approved), 429 (daily-verify
      // throttle), 5xx (Twilio throwing on an expired code).
      return failure(message: e.message);
    } on Object catch (e) {
      return failure(message: formatNotifyError(e));
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
