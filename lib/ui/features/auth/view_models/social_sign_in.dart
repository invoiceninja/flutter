import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/apple_sign_in.dart';
import 'package:admin/data/services/google_oauth.dart';
import 'package:admin/ui/core/widgets/notify.dart' show formatNotifyError;

/// Why a social sign-in failed, in the busy / error shape both auth view
/// models surface: a translation [key] + [params], or a server [message].
class SocialSignInFailure implements Exception {
  const SocialSignInFailure({this.key, this.params = const {}, this.message});

  final String? key;
  final Map<String, String> params;
  final String? message;
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
    throw SocialSignInFailure(
      key: 'apple_sign_in_unavailable_with_error',
      params: {'error': e.toString()},
    );
  } on Object catch (e) {
    throw _failureFrom(e);
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
    throw _failureFrom(e);
  }
}

SocialSignInFailure _failureFrom(Object e) {
  if (e is SocialSignInFailure) return e;
  if (e is NetworkException) {
    return SocialSignInFailure(
      key: 'network_error_with_message',
      params: {'message': e.message},
    );
  }
  if (e is ApiException) return SocialSignInFailure(message: e.message);
  // Login is the one screen a user cannot route around, and it was the one
  // screen with no catch-all: anything that isn't an `ApiException` subtype
  // escaped and the button simply un-spun and said nothing, forever. Real
  // throwers: `GoogleOAuth.signIn` is a platform channel (`PlatformException`
  // code 10 DEVELOPER_ERROR on a SHA-1 / client-id mismatch, or
  // `MissingPluginException`), `_persistAndActivate` writes to the keychain
  // and to Drift, and an unexpected response shape gives a `TypeError`.
  return SocialSignInFailure(message: formatNotifyError(e));
}
