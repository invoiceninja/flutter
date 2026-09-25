import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Sign in with Apple, reduced to what the app sends the server.
///
/// Login, sign-up and the password sheet's "Confirm with Apple" all share one
/// platform gate ([isSupported]) and one credential request, so they cannot
/// disagree about where Apple is offered.
class AppleSignIn {
  AppleSignIn._();

  /// iOS and macOS only, matching admin-portal's `supportsAppleOAuth()`.
  /// Web: no in-app OAuth callback handler (locked decision — web is
  /// email/password only). Android: `sign_in_with_apple` requires
  /// `webAuthenticationOptions` (an Apple Services ID + server return URL we
  /// don't ship); without it the plugin throws a bare `Exception` that escapes
  /// every typed catch. Windows/Linux: the plugin is NotSupported.
  static bool get isSupported {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Runs the Apple sheet. Throws [SignInWithAppleAuthorizationException]
  /// (code `canceled` when the user dismissed it) or
  /// [SignInWithAppleException].
  ///
  /// The nonce + state that bind the Apple response to this request are
  /// generated and validated inside the SDK (iOS & macOS); the server verifies
  /// the JWT signature — that's where replay protection actually lives.
  ///
  /// Apple returns the name and email only on the FIRST authorization for
  /// this app; every later credential carries neither.
  static Future<AuthorizationCredentialAppleID> credential() =>
      SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

  /// The identity token for a re-authentication (`X-API-OAUTH-PASSWORD`), or
  /// null when the user cancelled or Apple issued none.
  static Future<String?> identityToken() async {
    try {
      final cred = await credential();
      final token = cred.identityToken;
      return (token == null || token.isEmpty) ? null : token;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      rethrow;
    }
  }
}
