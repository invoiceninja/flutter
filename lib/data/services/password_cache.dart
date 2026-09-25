import 'package:flutter/widgets.dart';

/// Who a password-protected action is confirming, and so how it can be
/// confirmed. Mirrors the server's `PasswordProtection` middleware, which
/// accepts three things in order:
///
///  1. nothing at all from an OAuth user whose company leaves
///     `oauth_password_required` off ([isExempt]) — admin-portal never showed
///     these users a password prompt, and neither may we;
///  2. an OAuth re-authentication in `X-API-OAUTH-PASSWORD` — only Apple is
///     reachable from this app (Google's branch wants an `id_token` the v7
///     plugin does not give us, BACKEND.md);
///  3. the password in `X-API-PASSWORD-BASE64` — which an OAuth sign-up that
///     never set one ([hasPassword] false) cannot type.
@immutable
class PasswordSubject {
  const PasswordSubject({
    required this.oauthProvider,
    required this.hasPassword,
    required this.oauthPasswordRequired,
  });

  /// `google` / `microsoft` / `apple`, or `''` for an email/password user.
  final String oauthProvider;
  final bool hasPassword;

  /// The active company's `oauth_password_required`.
  final bool oauthPasswordRequired;

  /// The server's own test is `strlen(oauth_provider_id) > 2`.
  bool get isOAuth => oauthProvider.trim().length > 2;

  /// The server lets this user through without any credential.
  bool get isExempt => isOAuth && !oauthPasswordRequired;

  bool get isApple => oauthProvider.trim() == 'apple';
}

/// Short-lived in-memory cache for the credential a password-protected
/// endpoint wants — the user's password, or an OAuth re-authentication token.
///
/// Destructive server endpoints (delete, purge, password change) require
/// `X-API-PASSWORD-BASE64` per Invoice Ninja policy. The user supplies it via
/// `ConfirmPasswordSheet`; the password lives here for [ttl] so the user
/// isn't re-prompted on every following destructive action. An Apple user
/// with no password confirms with Apple instead ([setOAuthToken]), which
/// `ApiClient` sends as `X-API-OAUTH-PASSWORD`.
///
/// Cleared on logout, and on `AppLifecycleState.paused` if a
/// [PasswordCacheLifecycleObserver] is installed by the app shell. The cache
/// is in-memory only — never persisted.
class PasswordCache {
  PasswordCache({
    this.ttl = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration ttl;
  final DateTime Function() _now;

  /// The signed-in user, read at the moment a credential is needed. Wired by
  /// `Services` from the auth session; null (tests, signed out) means "ask
  /// for a password", today's behaviour.
  ValueGetter<PasswordSubject?>? subject;

  String? _value;
  bool _isOAuthToken = false;
  DateTime? _expiresAt;

  PasswordSubject? get currentSubject => subject?.call();

  /// The server will accept this user's protected request with no credential.
  bool get isExempt => currentSubject?.isExempt ?? false;

  /// A protected request can go out now without asking anybody anything.
  bool get isPrimed => isExempt || _live() != null;

  void set(String password) {
    _value = password;
    _isOAuthToken = false;
    _expiresAt = _now().add(ttl);
  }

  /// Caches an OAuth identity token (Apple's `identityToken`) in place of a
  /// password. The two are exclusive: whichever was set last is what's sent.
  void setOAuthToken(String token) {
    _value = token;
    _isOAuthToken = true;
    _expiresAt = _now().add(ttl);
  }

  /// The cached password, or null (none, expired, or an OAuth token instead).
  String? read() {
    final v = _live();
    return (v == null || _isOAuthToken) ? null : v;
  }

  /// The cached OAuth token, or null.
  String? readOAuthToken() {
    final v = _live();
    return (v == null || !_isOAuthToken) ? null : v;
  }

  String? _live() {
    final exp = _expiresAt;
    if (_value == null || exp == null) return null;
    if (_now().isAfter(exp)) {
      clear();
      return null;
    }
    return _value;
  }

  void clear() {
    _value = null;
    _isOAuthToken = false;
    _expiresAt = null;
  }
}

/// Drops [PasswordCache] contents when the app is backgrounded.
///
/// Without this, a user who deletes a client and then hands their phone over
/// (or it's briefly snatched) leaves a recoverable plaintext password in
/// memory for up to the cache's full [PasswordCache.ttl]. We hook
/// `AppLifecycleState.paused` only — `inactive` fires on iOS for transient
/// events like pulling down notification center, and clearing there would
/// force a re-prompt for normal UI gestures.
class PasswordCacheLifecycleObserver with WidgetsBindingObserver {
  PasswordCacheLifecycleObserver(this._cache);

  final PasswordCache _cache;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cache.clear();
    }
  }
}
