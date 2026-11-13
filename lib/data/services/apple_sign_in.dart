import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:admin/data/services/web_oauth.dart';
import 'package:admin/data/services/web_sign_in.dart';

/// Sign in with Apple, reduced to what the app sends the server.
///
/// Login, sign-up and the password sheet's "Confirm with Apple" all share one
/// platform gate ([isSupported]) and one credential request, so they cannot
/// disagree about where Apple is offered.
class AppleSignIn {
  AppleSignIn._();

  /// iOS and macOS, matching admin-portal's `supportsAppleOAuth()`, and the
  /// hosted web page once it names Apple's Services ID ([WebSignIn],
  /// docs/web-deploy.md § Web sign-in): Apple's JS in a window, which the
  /// Services ID must list the page's domain and return URL for. Android:
  /// `sign_in_with_apple` requires
  /// `webAuthenticationOptions` (an Apple Services ID + server return URL we
  /// don't ship); without it the plugin throws a bare `Exception` that escapes
  /// every typed catch. Windows/Linux: the plugin is NotSupported.
  static bool get isSupported {
    if (WebSignIn.isWeb) return WebSignIn.appleEnabled;
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
  ///
  /// On web, a window the user closed is [SignInWithAppleAuthorizationException]
  /// `canceled` too: the plugin reports it as a generic credentials error
  /// naming Apple's code ([isWebCancel]). A blocked window, or Apple JS not
  /// loaded, is a [WebOAuthException], as for Google and Microsoft.
  static Future<AuthorizationCredentialAppleID> credential() async {
    // The plugin would fail with a cast error rather than say so.
    if (WebSignIn.isWeb && !webAppleLoaded()) {
      throw const WebOAuthException(WebOAuthFailure.notLoaded);
    }
    try {
      return await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        webAuthenticationOptions: WebSignIn.isWeb
            ? WebAuthenticationOptions(
                clientId: WebSignIn.appleClientId,
                redirectUri: Uri.parse(WebSignIn.appleRedirectUri),
              )
            : null,
      );
    } on SignInWithAppleCredentialsException catch (e) {
      if (WebSignIn.isWeb && isWebCancel(e.message)) {
        throw const SignInWithAppleAuthorizationException(
          code: AuthorizationErrorCode.canceled,
          message: 'closed',
        );
      }
      if (WebSignIn.isWeb && e.message.contains('popup_blocked_by_browser')) {
        throw const WebOAuthException(WebOAuthFailure.blocked);
      }
      rethrow;
    }
  }

  /// Apple JS's codes for a window the user closed
  /// (`SignInErrorI.error`), as `sign_in_with_apple_web` words them.
  @visibleForTesting
  static bool isWebCancel(String message) =>
      message.contains('popup_closed_by_user') ||
      message.contains('user_cancelled_authorize');

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
