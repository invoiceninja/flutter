import 'package:admin/data/services/web_oauth_types.dart';

/// The native half of the [web_oauth] seam: never used, since native builds
/// sign in through the platform SDKs.
void prepareWebOAuth({
  String googleClientId = '',
  String microsoftClientId = '',
  String microsoftRedirectUri = '',
}) {}

/// Never: native builds have no browser sign-in.
bool webOAuthSecureContext() => false;

/// Never: native builds have no Apple JS.
bool webAppleLoaded() => false;

Future<String?> webGoogleAccessToken(String clientId) =>
    throw const WebOAuthException(WebOAuthFailure.notLoaded);

Future<String?> webMicrosoftAccessToken({
  required String clientId,
  required String redirectUri,
}) => throw const WebOAuthException(WebOAuthFailure.notLoaded);
