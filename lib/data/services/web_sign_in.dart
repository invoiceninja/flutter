import 'package:flutter/foundation.dart';

import 'package:admin/app/serving_server_parse.dart';
import 'package:admin/data/services/web_oauth.dart';

/// Which providers the web build signs in with, and the client IDs and
/// return addresses they use (docs/web-deploy.md § Web sign-in).
///
/// All of it comes from the page an Invoice Ninja server served
/// ([ServingServer]), never from a dart-define: one build serves both the
/// hosted page and every self-hosted server. Hosted offers Google, Microsoft
/// and Apple (each when `tools/web_deploy/hosted_sign_in.json` names its ID);
/// a self-hosted server offers Microsoft when it sets `MICROSOFT_CLIENT_ID`,
/// as admin-portal's web app did, and nothing else. A page no server served
/// (the demo, `flutter run -d chrome`) offers none.
///
/// Set once at boot by `main.dart` ([configure]); static because
/// `GoogleOAuth` and `AppleSignIn`, which read it, are.
class WebSignIn {
  WebSignIn._();

  static ServingServer? _served;
  static String _pageOrigin = '';
  static bool _secure = false;

  @visibleForTesting
  static bool? debugIsWeb;

  /// `kIsWeb`, overridable so the web paths of `GoogleOAuth` and
  /// `AppleSignIn` can be tested on the VM.
  static bool get isWeb => debugIsWeb ?? kIsWeb;

  /// [pageOrigin] is the page's own `location.origin`; [secureContext] says
  /// the page is a secure context, which all three providers need (MSAL
  /// can't hash without `crypto.subtle`), so a self-hosted page on plain http
  /// offers none.
  static void configure(
    ServingServer? served, {
    required String pageOrigin,
    required bool secureContext,
  }) {
    _served = served;
    _pageOrigin = pageOrigin;
    _secure = secureContext;
  }

  @visibleForTesting
  static void reset() {
    _served = null;
    _pageOrigin = '';
    _secure = false;
    debugIsWeb = null;
    debugGoogleAccessToken = null;
    debugMicrosoftAccessToken = null;
  }

  static bool get _hosted => _served?.isHosted ?? false;

  static bool get _usable => isWeb && _secure;

  static String get googleClientId =>
      _usable && _hosted ? (_served?.googleClientId ?? '') : '';

  static String get microsoftClientId =>
      _usable ? (_served?.microsoftClientId ?? '') : '';

  static String get appleClientId =>
      _usable && _hosted ? (_served?.appleClientId ?? '') : '';

  static bool get googleEnabled => googleClientId.isNotEmpty;
  static bool get microsoftEnabled => microsoftClientId.isNotEmpty;
  static bool get appleEnabled => appleClientId.isNotEmpty;

  /// Where Microsoft returns the sign-in window. A self-hosted server's own
  /// URL, exactly as admin-portal sent it (`cleanApiUrl`), so the redirect URI
  /// its admin registered in Azure for the old app still matches; the hosted
  /// page's origin (`https://admin.invoicing.co`), which is not the API's.
  static String get microsoftRedirectUri =>
      _hosted ? _pageOrigin : (_served?.apiUrl ?? '');

  /// Where Apple returns its sign-in window: the hosted page's origin, which
  /// the Services ID must list.
  static String get appleRedirectUri => _pageOrigin;

  /// Gets the next tap's sign-in ready ([prepareWebOAuth]). `main.dart`
  /// calls it at boot, so a restored session's "Confirm with Microsoft" works
  /// on the first tap; the login and signup screens call it again (a no-op
  /// once started).
  static void prepare() {
    if (!microsoftEnabled) return;
    prepareWebOAuth(
      googleClientId: googleClientId,
      microsoftClientId: microsoftClientId,
      microsoftRedirectUri: microsoftRedirectUri,
    );
  }

  /// Google's access token, or null when the user closed the window. Throws
  /// [WebOAuthException]. Call it straight from the tap (see `web_oauth_web`).
  static Future<String?> googleAccessToken() =>
      debugGoogleAccessToken?.call() ?? webGoogleAccessToken(googleClientId);

  /// Microsoft's access token, as [googleAccessToken].
  static Future<String?> microsoftAccessToken() =>
      debugMicrosoftAccessToken?.call() ??
      webMicrosoftAccessToken(
        clientId: microsoftClientId,
        redirectUri: microsoftRedirectUri,
      );

  @visibleForTesting
  static Future<String?> Function()? debugGoogleAccessToken;

  @visibleForTesting
  static Future<String?> Function()? debugMicrosoftAccessToken;
}
