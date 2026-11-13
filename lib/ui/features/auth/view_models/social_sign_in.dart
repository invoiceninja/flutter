import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/apple_sign_in.dart';
import 'package:admin/data/services/google_oauth.dart';
import 'package:admin/data/services/web_oauth.dart';
import 'package:admin/data/services/web_sign_in.dart';
import 'package:admin/ui/core/widgets/notify.dart' show formatNotifyError;

/// Why a social sign-in failed, in the busy / error shape both auth view
/// models surface: a translation [key] + [params], or a server [message].
class SocialSignInFailure implements Exception {
  const SocialSignInFailure({
    this.key,
    this.params = const {},
    this.message,
    this.detailKey,
  });

  final String? key;
  final Map<String, String> params;
  final String? message;

  /// A second line for the toast, as a localization key.
  final String? detailKey;
}

/// Sign in with Apple against `/api/v1/oauth_login`, shared by the login and
/// signup screens so the two can't drift apart.
///
/// Returns `true` once the session is active, `false` when the user dismissed
/// the Apple sheet (nothing to report); throws [SocialSignInFailure]
/// otherwise.
///
/// [create] is the signup screen's `?create=true` plus the terms consent. The
/// server creates an Apple account even without it
/// (`loginOrCreateFromSocialite`), which is why the name is sent from the
/// login screen too: Apple hands it over on the FIRST authorization only, and
/// the server reads `first_name` / `last_name` for Apple alone — without them
/// a new Apple account has no name, ever.
Future<bool> signInWithApple({
  required AuthRepository auth,
  required String baseUrl,
  required bool isHosted,
  bool create = false,
}) async {
  // Defence in depth: callers hide Apple where the native flow doesn't exist
  // — never let a stray call reach the platform channel there (Android's
  // would throw an untyped Exception).
  if (!AppleSignIn.isSupported) return false;
  try {
    final cred = await AppleSignIn.credential();
    await auth.oauthLogin(
      baseUrl: baseUrl,
      isHosted: isHosted,
      provider: 'apple',
      idToken: cred.identityToken,
      authCode: cred.authorizationCode,
      email: cred.email,
      firstName: cred.givenName,
      lastName: cred.familyName,
      create: create,
    );
    return true;
  } on SignInWithAppleAuthorizationException catch (e) {
    if (e.code == AuthorizationErrorCode.canceled) {
      return false; // sheet dismissed — no error to surface
    }
    throw SocialSignInFailure(
      key: 'apple_sign_in_failed_with_message',
      params: {'message': e.message},
    );
  } on SignInWithAppleException catch (e) {
    // Apple JS on web: the browser refused the window.
    if (e is SignInWithAppleCredentialsException &&
        e.message.contains('popup_blocked_by_browser')) {
      throw const SocialSignInFailure(key: 'web_sign_in_blocked');
    }
    throw SocialSignInFailure(
      key: 'apple_sign_in_unavailable_with_error',
      params: {'error': e.toString()},
    );
  } on Object catch (e) {
    throw _failureFrom(e, provider: 'apple', isHosted: isHosted);
  }
}

/// Sign in with Google against `/api/v1/oauth_login`. Same contract as
/// [signInWithApple].
///
/// Rides the access-token path: [GoogleOAuth.signIn] yields an access token
/// (no id_token) which the server exchanges via `harvestUser` — see
/// `google_oauth.dart` for why. Unlike Apple, the server creates a Google
/// account ONLY with [create] (`?create=true`); from the login screen an
/// unknown Google account is "User not found".
Future<bool> signInWithGoogle({
  required AuthRepository auth,
  required String baseUrl,
  required bool isHosted,
  bool create = false,
}) async {
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
      create: create,
    );
    return true;
  } on Object catch (e) {
    throw _failureFrom(e, provider: 'google', isHosted: isHosted);
  }
}

/// Sign in with Microsoft against `/api/v1/oauth_login`, on web only
/// ([WebSignIn.microsoftEnabled]: the hosted page, or a self-hosted server
/// that sets `MICROSOFT_CLIENT_ID`). Same contract as [signInWithApple].
///
/// The server takes MSAL's access token for Microsoft Graph (`user.read`) and
/// checks it was issued to its own `MICROSOFT_CLIENT_ID`. Like Google, it
/// creates an account only with [create].
Future<bool> signInWithMicrosoft({
  required AuthRepository auth,
  required String baseUrl,
  required bool isHosted,
  bool create = false,
}) async {
  if (!WebSignIn.microsoftEnabled) return false;
  try {
    // No await in front of this: it opens the window.
    final accessToken = await WebSignIn.microsoftAccessToken();
    if (accessToken == null || accessToken.isEmpty) return false;
    await auth.oauthLogin(
      baseUrl: baseUrl,
      isHosted: isHosted,
      provider: 'microsoft',
      accessToken: accessToken,
      create: create,
    );
    return true;
  } on Object catch (e) {
    throw _failureFrom(e, provider: 'microsoft', isHosted: isHosted);
  }
}

/// The provider's name as the buttons write it.
String _providerName(String id) => switch (id.toLowerCase()) {
  'google' => 'Google',
  'microsoft' => 'Microsoft',
  'apple' => 'Apple',
  _ => id,
};

/// The server's `oauth_login` refusals that a user can act on, in plain
/// words (`LoginController::handleGoogleOauth` / `handleMicrosoftOauth`). The
/// server words them for a developer ("User not found. If you believe this is
/// an error, please send an email to contact@…"), and the first one is what
/// a new user meets on the login screen.
SocialSignInFailure? _refusal(
  String message,
  String provider, {
  required bool isHosted,
}) {
  if (message.startsWith('User not found')) {
    // Only hosted has a signup screen to point to.
    return SocialSignInFailure(
      key: isHosted ? 'oauth_user_not_found' : 'oauth_user_not_found_here',
      params: {'provider': _providerName(provider)},
    );
  }
  if (message.contains('use your email and password to login')) {
    return const SocialSignInFailure(key: 'oauth_email_uses_password');
  }
  final linked = RegExp(r'already linked to (\w+) sign-in').firstMatch(message);
  if (linked != null) {
    return SocialSignInFailure(
      key: 'oauth_email_uses_provider',
      params: {'provider': _providerName(linked.group(1)!)},
    );
  }
  return null;
}

SocialSignInFailure _failureFrom(
  Object e, {
  required String provider,
  required bool isHosted,
}) {
  if (e is SocialSignInFailure) return e;
  if (e is WebOAuthException) {
    return switch (e.failure) {
      WebOAuthFailure.blocked => const SocialSignInFailure(
        key: 'web_sign_in_blocked',
      ),
      WebOAuthFailure.notLoaded => const SocialSignInFailure(
        key: 'web_sign_in_loading',
      ),
      WebOAuthFailure.unavailable => const SocialSignInFailure(
        key: 'web_sign_in_unavailable',
      ),
      WebOAuthFailure.failed => SocialSignInFailure(
        message: e.message.isEmpty ? formatNotifyError(e) : e.message,
      ),
    };
  }
  // Social sign-in is hosted-only, and the hosted service's certificate is
  // never ours to overrule — explain it rather than toast the handshake.
  if (e is UntrustedCertificateException) {
    return SocialSignInFailure(
      key: 'untrusted_certificate_hosted',
      params: {'host': e.host},
      detailKey: 'untrusted_certificate_hosted_detail',
    );
  }
  if (e is NetworkException) {
    return SocialSignInFailure(
      key: 'network_error_with_message',
      params: {'message': e.message},
    );
  }
  if (e is ApiException) {
    return _refusal(e.message, provider, isHosted: isHosted) ??
        SocialSignInFailure(message: e.message);
  }
  // Login is the one screen a user cannot route around, and it was the one
  // screen with no catch-all: anything that isn't an `ApiException` subtype
  // escaped and the button simply un-spun and said nothing, forever. Real
  // throwers: `GoogleOAuth.signIn` is a platform channel (`PlatformException`
  // code 10 DEVELOPER_ERROR on a SHA-1 / client-id mismatch, or
  // `MissingPluginException`), `_persistAndActivate` writes to the keychain
  // and to Drift, and an unexpected response shape gives a `TypeError`.
  return SocialSignInFailure(message: formatNotifyError(e));
}
