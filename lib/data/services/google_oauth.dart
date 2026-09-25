import 'package:store_services/store_services.dart';

import 'package:admin/app/env.dart';

/// Google sign-in for the Invoice Ninja API (`/api/v1/oauth_login`).
///
/// Mirrors `admin-portal/lib/utils/oauth.dart` (the working Android/iOS
/// implementation) 1:1, with one deliberate change: the Android
/// `serverClientId` comes from [Env.googleServerClientId] (a per-build
/// dart-define) instead of a hardcoded constant — a client ID is bound to a
/// specific OAuth project + app package/bundle, so it cannot be shared
/// across apps.
///
/// We deliberately ride v7's "access token" path instead of the new
/// "id token" path: the backend's `getTokenResponse(id_token)` route rejects
/// v7-issued JWTs, while `harvestUser(access_token)` (Google's userinfo
/// endpoint) keeps working unchanged. So this returns
/// `(idToken: '', accessToken)` and [AuthService.oauthLogin] omits the empty
/// `id_token` from the request body so Laravel's
/// `request()->has('id_token')` returns false and execution falls into the
/// access-token branch.
///
/// The SDK calls live in `package:store_services` ([GoogleSignInClient]) so
/// the F-Droid build can drop Play Services — there [isEnabled] is always
/// false and the Google buttons hide themselves (docs/fdroid.md).
class GoogleOAuth {
  GoogleOAuth._();

  static const _clientId = Env.googleServerClientId;

  static bool get isEnabled =>
      GoogleSignInClient.isSupported(androidServerClientId: _clientId);

  /// Interactive sign-in. Invokes [callback] with `(idToken, accessToken)`;
  /// `idToken` is always empty (see class doc — we ride the access-token
  /// path). Returns true when a non-empty access token was obtained.
  static Future<bool> signIn(
    void Function(String idToken, String accessToken) callback,
  ) async {
    final accessToken = await GoogleSignInClient.signIn(
      androidServerClientId: _clientId,
    );
    callback('', accessToken);
    return accessToken.isNotEmpty;
  }

  static Future<void> signOut() =>
      GoogleSignInClient.signOut(androidServerClientId: _clientId);

  static Future<void> disconnect() =>
      GoogleSignInClient.disconnect(androidServerClientId: _clientId);
}
