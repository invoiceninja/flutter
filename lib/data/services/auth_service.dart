import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:admin/app/env.dart';
import 'package:admin/app/version.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/services/api_exception.dart';

/// Auth endpoints don't fit through [ApiClient] because they're called before
/// we have a token. This service speaks to `/api/v1/login` and
/// `/api/v1/reset_password` directly, with the standard non-token headers.
///
/// Mirrors `admin-portal/lib/redux/auth/auth_middleware.dart:102-120` for the
/// login response envelope and the headers we send.
class AuthService {
  AuthService({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// One transport seam for every auth POST. A connection failure (no
  /// network, DNS lookup on a typo'd self-hosted URL, refused socket) throws
  /// `http.ClientException` — and a stalled request `TimeoutException` —
  /// neither of which is an [ApiException], so without this mapping they
  /// escape every `on …Exception` catch in the login / signup / recover
  /// ViewModels and the user gets a spinner that just stops with no error
  /// at all. Mirrors `ApiClient`'s identical mapping for post-login calls.
  ///
  /// [timeout] bounds the request. It is applied *inside* the `try` so a stall
  /// surfaces as the same [NetworkException]; chaining `.timeout()` at a call
  /// site would let a raw [TimeoutException] escape. Production hands this
  /// service a plain `http.Client()` with no connect timeout of its own, so an
  /// unanswered self-hosted URL would otherwise spin for the OS timeout
  /// (~75 s on Apple platforms).
  Future<http.Response> _post(
    Uri url, {
    required Map<String, String> headers,
    Object? body,
    Duration? timeout,
  }) async {
    try {
      final request = _http.post(url, headers: headers, body: body);
      return await (timeout == null ? request : request.timeout(timeout));
    } on TimeoutException {
      // Not `e.message`: `Future.timeout` always sets it to "Future not
      // completed", which would reach the user verbatim.
      throw NetworkException(
        timeout == null
            ? 'Request timed out'
            : 'Request timed out after ${timeout.inSeconds}s',
      );
    } on http.ClientException catch (e) {
      throw NetworkException(e.message);
    } catch (e) {
      // Everything else `post` can throw is transport too: `IOClient` wraps
      // only `SocketException` / `HttpException`, so a TLS
      // `HandshakeException` (a self-hosted certificate the device doesn't
      // trust) would otherwise escape every `on ApiException` catch. Mirrors
      // `ApiClient`'s catch-all.
      throw NetworkException(e.toString());
    }
  }

  /// POST `/api/v1/login`. The request body matches the existing app:
  ///   { email, password, one_time_password? }
  ///
  /// Returns the parsed [LoginResponseApi]. Throws an [ApiException] subtype
  /// on non-2xx so the UI can surface the right error path.
  Future<LoginResponseApi> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
    String? secret,
  }) async {
    final response = await _post(
      Uri.parse(baseUrl).resolve('/api/v1/login'),
      headers: _headers(
        isHosted: isHosted,
        contentTypeJson: true,
        secret: secret,
      ),
      body: jsonEncode({
        'email': email,
        'password': password,
        if (oneTimePassword != null && oneTimePassword.isNotEmpty)
          'one_time_password': oneTimePassword,
      }),
    );
    _raiseIfError(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    // Every response this service parses is a full snapshot (the server sends
    // each company's whole dataset on a sign-in), so none of them types the
    // browsable entity arrays — see [LoginResponseApi.fromFullSnapshot].
    return LoginResponseApi.fromFullSnapshot(json);
  }

  /// Bound on the interactive pre-auth calls the login screen waits on with
  /// its controls locked — Continue ([precheck]), "Forgot your password?"
  /// ([recoverPassword]) and the SMS-reset dialogs — so a server that never
  /// answers fails with a [NetworkException] instead of spinning. `login`
  /// itself is deliberately unbounded, as it always was.
  static const Duration interactiveTimeout = Duration(seconds: 15);

  /// POST `/api/v1/login/precheck` — asks the server which credentials this
  /// email actually needs, so the login form's second step shows only the
  /// fields that apply.
  ///
  /// Body `{email}`; response `{methods: ['password'|'totp', …],
  /// secret_required: bool}`. The server pads the response to a constant time
  /// floor and returns a uniform payload for unknown accounts, so this leaks
  /// no account-existence signal.
  ///
  /// **Fails open, except for two answers that mean "fix step 1 first":**
  ///  * the server can't be reached (offline, a typo'd self-hosted URL, or no
  ///    answer within [interactiveTimeout]) → throws [NetworkException];
  ///  * the server rejects the address (422) → throws [ValidationException].
  ///
  /// Every other failure — an older server that 404s / 405s the route, a rate
  /// limit, a 5xx, a malformed body, a body without a `methods` list —
  /// returns null, and the caller falls back to showing every optional field.
  /// Self-hosted servers run any version, so an unanswerable precheck must
  /// never be able to block a login.
  ///
  /// Takes no API secret: the route sits outside `api_secret_check`.
  Future<LoginPrecheck?> precheck({
    required String baseUrl,
    required bool isHosted,
    required String email,
  }) async {
    final response = await _post(
      Uri.parse(baseUrl).resolve('/api/v1/login/precheck'),
      headers: _headers(isHosted: isHosted, contentTypeJson: true),
      body: jsonEncode({'email': email}),
      timeout: interactiveTimeout,
    );
    if (response.statusCode == 422) _raiseIfError(response);
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    try {
      final json = jsonDecode(response.body);
      if (json is! Map<String, dynamic>) return null;
      final methods = json['methods'];
      // No list = no answer. Reading it as "no methods" would hide the OTP
      // field for an account that has TOTP, and the answer is cached per
      // (server, email), so there would be no way back to the field.
      if (methods is! List) return null;
      return LoginPrecheck(
        methods: <String>{
          for (final m in methods)
            if (m is String) m,
        },
        secretRequired: json['secret_required'] == true,
      );
    } catch (_) {
      // A non-JSON body (an HTML error page from a proxy) is "no answer".
      return null;
    }
  }

  /// POST `/api/v1/sms_reset` — texts a 2FA reset code to the phone on file
  /// for [email]. Pre-auth (no token, no `api_secret_check` on the server),
  /// throttled `daily-verify`. Returns the server's message.
  ///
  /// This is the lost-authenticator path offered from the login screen; the
  /// settings screen's phone verification uses the same endpoint through the
  /// authenticated `TwoFactorApi` instead.
  Future<String?> sendTwoFactorResetCode({
    required String baseUrl,
    required bool isHosted,
    required String email,
  }) async {
    final response = await _post(
      Uri.parse(baseUrl).resolve('/api/v1/sms_reset'),
      headers: _headers(isHosted: isHosted, contentTypeJson: true),
      body: jsonEncode({'email': email}),
      timeout: interactiveTimeout,
    );
    _raiseIfError(response);
    return _messageOf(response);
  }

  /// POST `/api/v1/sms_reset/confirm` — verifies the texted code and, because
  /// no `validate_only` query is sent, **disables 2FA** on the account
  /// (`TwilioController::confirm2faResetCode` nulls `google_2fa_secret`).
  /// Returns the server's message.
  Future<String?> confirmTwoFactorReset({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String code,
  }) async {
    final response = await _post(
      Uri.parse(baseUrl).resolve('/api/v1/sms_reset/confirm'),
      headers: _headers(isHosted: isHosted, contentTypeJson: true),
      body: jsonEncode({'email': email, 'code': code}),
      timeout: interactiveTimeout,
    );
    _raiseIfError(response);
    return _messageOf(response);
  }

  String? _messageOf(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      if (json is Map<String, dynamic>) return json['message']?.toString();
    } catch (_) {
      /* non-JSON body */
    }
    return null;
  }

  /// POST `/api/v1/refresh` authenticated by an explicit API token rather
  /// than an active session. Used by demo builds to bootstrap a session from
  /// a baked-in token (see `Env.demoApiToken`). The server echoes the
  /// supplied token back in `data[N].token`, so feeding the result through
  /// `AuthRepository._persistAndActivate` persists that token unchanged.
  Future<LoginResponseApi> refreshWithToken({
    required String baseUrl,
    required bool isHosted,
    required String token,
  }) async {
    final response = await _post(
      Uri.parse(
        baseUrl,
      ).resolve('/api/v1/refresh?first_load=true&include_static=true'),
      headers: {
        ..._headers(isHosted: isHosted, contentTypeJson: true),
        'X-API-Token': token,
      },
    );
    _raiseIfError(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponseApi.fromFullSnapshot(json);
  }

  /// POST `/api/v1/oauth_login`. Used by third-party OAuth flows (Sign in
  /// with Apple, etc.). The request body mirrors admin-portal's:
  ///   { provider, access_token, email, auth_code, id_token }
  ///
  /// Returns the same [LoginResponseApi] envelope as a regular login, so the
  /// caller can drop it into [AuthRepository] alongside `login()` with no
  /// extra plumbing.
  Future<LoginResponseApi> oauthLogin({
    required String baseUrl,
    required String provider,
    required bool isHosted,
    String? idToken,
    String? authCode,
    String? accessToken,
    String? email,
    String? firstName,
    String? lastName,
    bool create = false,
  }) async {
    // `?create=true` is the sign-up: the server's Google branch creates an
    // account ONLY with it (unknown account otherwise → "User not found"),
    // and the terms consent + token name ride along exactly as `signup()`
    // sends them. Mirrors admin-portal's `AuthRepository.oauthSignUp`.
    final path = create
        ? '/api/v1/oauth_login?create=true'
        : '/api/v1/oauth_login';
    final response = await _post(
      Uri.parse(baseUrl).resolve(path),
      headers: _headers(isHosted: isHosted, contentTypeJson: true),
      body: jsonEncode({
        'provider': provider,
        if (accessToken != null) 'access_token': accessToken,
        if (email != null) 'email': email,
        if (authCode != null) 'auth_code': authCode,
        // Send id_token only when populated. The server's Laravel
        // `request()->has('id_token')` returns true for an empty string too,
        // so an absent key is the only way to route the Google flow (which
        // carries access_token, no id_token) through the access-token branch
        // instead of the JWT branch. Mirrors admin-portal's auth_repository.
        if (idToken != null && idToken.isNotEmpty) 'id_token': idToken,
        // Read for Apple only (`LoginController::loginOrCreateFromSocialite`),
        // which hands the name over on the first authorization and never
        // again.
        if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
        if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
        if (create) ...{
          'terms_of_service': true,
          'privacy_policy': true,
          'token_name': '${Env.clientPlatform}_client',
          'platform': Env.clientPlatform,
        },
      }),
    );
    _raiseIfError(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponseApi.fromFullSnapshot(json);
  }

  /// POST `/api/v1/signup`. Native account creation. Mirrors admin-portal's
  /// `AuthRepository.signUp` — the native body carries no Cloudflare
  /// Turnstile token (that's a web-frontend bot mitigation; the API doesn't
  /// require it for native clients). Returns the same [LoginResponseApi]
  /// envelope as `login()`, so the caller drops it into [AuthRepository]
  /// alongside `login()` with no extra plumbing.
  Future<LoginResponseApi> signup({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String referralCode = '',
  }) async {
    final response = await _post(
      Uri.parse(baseUrl).resolve('/api/v1/signup?rc=$referralCode'),
      headers: _headers(isHosted: isHosted, contentTypeJson: true),
      body: jsonEncode({
        'email': email,
        'password': password,
        'terms_of_service': true,
        'privacy_policy': true,
        'token_name': '${Env.clientPlatform}_client',
        'platform': Env.clientPlatform,
      }),
    );
    _raiseIfError(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return LoginResponseApi.fromFullSnapshot(json);
  }

  /// POST `/api/v1/reset_password`. The server mails the user a reset link;
  /// the client only needs to know if the request was accepted.
  Future<void> recoverPassword({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) async {
    final response = await _post(
      Uri.parse(baseUrl).resolve('/api/v1/reset_password'),
      headers: _headers(
        isHosted: isHosted,
        contentTypeJson: true,
        secret: secret,
      ),
      body: jsonEncode({'email': email}),
      // The login screen's "Forgot your password?" link waits on this with
      // every other control disabled — bound it like the other interactive
      // pre-auth calls.
      timeout: interactiveTimeout,
    );
    _raiseIfError(response);
  }

  Map<String, String> _headers({
    required bool isHosted,
    bool contentTypeJson = false,
    String? secret,
  }) {
    // Hosted builds carry the build-time constant; self-hosted carries the
    // user-entered secret from the login form ([secret], empty unless the
    // server has API_SECRET set). The server's `api_secret_check` middleware
    // enforces X-API-SECRET only on the pre-auth routes (/login, /oauth_login,
    // /signup, /reset_password) and only for self-hosted servers with
    // API_SECRET configured — post-login calls authenticate by token instead,
    // so the secret is never persisted.
    final effectiveSecret = isHosted ? Env.hostedApiSecret : (secret ?? '');
    return {
      'Accept': 'application/json',
      if (contentTypeJson) 'Content-Type': 'application/json; charset=UTF-8',
      'X-CLIENT-PLATFORM': Env.clientPlatform,
      'X-CLIENT-VERSION': AppVersion.kClientVersion,
      'X-Requested-With': 'com.invoiceninja.admin',
      if (effectiveSecret.isNotEmpty) 'X-API-SECRET': effectiveSecret,
    };
  }

  void _raiseIfError(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      /* non-JSON body */
    }
    final message =
        json?['message']?.toString() ??
        response.reasonPhrase ??
        'HTTP ${response.statusCode}';
    switch (response.statusCode) {
      case 401:
      case 403:
        throw UnauthorizedException(message);
      case 422:
        final raw = json?['errors'];
        final fieldErrors = <String, List<String>>{};
        if (raw is Map<String, dynamic>) {
          for (final entry in raw.entries) {
            final v = entry.value;
            if (v is List) {
              fieldErrors[entry.key] = v.map((e) => e.toString()).toList();
            }
          }
        }
        throw ValidationException(message, fieldErrors);
      default:
        throw ServerException(response.statusCode, message);
    }
  }
}

/// Result of [AuthService.precheck] — what the server says this email needs.
///
/// A null result (never an instance with everything false) means the precheck
/// could not be answered; callers must treat that as "show everything", not
/// as "nothing required". See the fail-open contract on [AuthService.precheck].
class LoginPrecheck {
  const LoginPrecheck({required this.methods, required this.secretRequired});

  /// Auth methods the account supports, e.g. `{'password'}` or
  /// `{'password', 'totp'}`.
  final Set<String> methods;

  /// True when the server is configured with an `API_SECRET`, so the
  /// self-hosted `X-API-SECRET` field is mandatory rather than optional.
  final bool secretRequired;

  /// Whether the account has TOTP two-factor enabled.
  bool get requiresOtp => methods.contains('totp');

  /// The same answer with TOTP removed — after the login screen's SMS reset
  /// has disabled 2FA on the account.
  LoginPrecheck withoutOtp() => LoginPrecheck(
    methods: methods.difference(const {'totp'}),
    secretRequired: secretRequired,
  );
}
