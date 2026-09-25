import 'package:store_services/store_services.dart';

import 'package:admin/app/env.dart';

/// Google sign-in for the Invoice Ninja API (`/api/v1/oauth_login`).
///
/// Mirrors `admin-portal/lib/utils/oauth.dart` (the working Android/iOS
/// implementation) 1:1, with one deliberate change: the client IDs come from
/// [Env.googleServerClientId] / [Env.googleIosClientId] (per-build
/// dart-defines) instead of hardcoded constants — an iOS or Android client is
/// bound to one bundle / package id, and this app's (`com.invoiceninja.admin`)
/// is not admin-portal's (`com.invoiceninja.app`).
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

  static const _androidClientId = Env.googleServerClientId;
  static const _iosClientId = Env.googleIosClientId;

  /// Off unless this build carries the client ID for the running platform —
  /// see `docs/setup.md` § Google Sign-In client IDs.
  static bool get isEnabled => GoogleSignInClient.isSupported(
    androidServerClientId: _androidClientId,
    iosClientId: _iosClientId,
  );

  /// Interactive sign-in. Invokes [callback] with `(idToken, accessToken)`;
  /// `idToken` is always empty (see class doc — we ride the access-token
  /// path). Returns true when a non-empty access token was obtained.
  static Future<bool> signIn(
    void Function(String idToken, String accessToken) callback,
  ) async {
    final accessToken = await GoogleSignInClient.signIn(
      androidServerClientId: _androidClientId,
      iosClientId: _iosClientId,
    );
    callback('', accessToken);
    return accessToken.isNotEmpty;
  }

  /// Best effort: ends the SDK's session on sign-out. Never throws — a Google
  /// SDK hiccup must not block leaving the app.
  static Future<void> signOut() async {
    if (!isEnabled) return;
    try {
      await GoogleSignInClient.signOut(
        androidServerClientId: _androidClientId,
        iosClientId: _iosClientId,
      );
    } on Object catch (_) {}
  }

  /// Best effort: revokes the app's Google grant after the user unlinks
  /// Google from their account (admin-portal did the same). Never throws.
  static Future<void> disconnect() async {
    if (!isEnabled) return;
    try {
      await GoogleSignInClient.disconnect(
        androidServerClientId: _androidClientId,
        iosClientId: _iosClientId,
      );
    } on Object catch (_) {}
  }
}
