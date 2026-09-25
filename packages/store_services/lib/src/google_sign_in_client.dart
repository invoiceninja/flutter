import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google sign-in, reduced to the one value the app needs: an OAuth access
/// token for `/api/v1/oauth_login`.
///
/// The app-facing wrapper (and the reasoning behind riding v7's access-token
/// path rather than its id-token path) is `lib/data/services/google_oauth.dart`.
/// `androidServerClientId` is passed on every call because this package can't
/// read the app's dart-defines.
class GoogleSignInClient {
  GoogleSignInClient._();

  static bool _initialized = false;

  /// Android needs a configured server client ID (Credential Manager can't
  /// resolve it from `google-services.json`); iOS resolves its own from
  /// `Info.plist`/`GoogleService-Info.plist`, so it's enabled there
  /// regardless. Web/desktop are out of scope (login is hosted-only).
  static bool isSupported({required String androidServerClientId}) {
    if (kIsWeb) return false;
    if (Platform.isIOS) return true;
    if (Platform.isAndroid) return androidServerClientId.isNotEmpty;
    return false;
  }

  static Future<void> _init(String androidServerClientId) async {
    if (_initialized) {
      return;
    }
    if (!kIsWeb && Platform.isAndroid) {
      await GoogleSignIn.instance.initialize(
        serverClientId: androidServerClientId,
      );
    } else {
      await GoogleSignIn.instance.initialize();
    }
    _initialized = true;
  }

  /// Interactive sign-in. Returns the access token, or `''` when the user
  /// cancelled or no token could be obtained.
  static Future<String> signIn({required String androidServerClientId}) async {
    await _init(androidServerClientId);

    final account = await _interactiveAuthenticate();
    if (account == null) {
      return '';
    }
    return _resolveAccessToken(account);
  }

  static Future<void> signOut({required String androidServerClientId}) async {
    await _init(androidServerClientId);
    await GoogleSignIn.instance.signOut();
  }

  static Future<void> disconnect({
    required String androidServerClientId,
  }) async {
    await _init(androidServerClientId);
    await GoogleSignIn.instance.disconnect();
  }

  static const _scopes = ['email', 'profile'];

  static Future<GoogleSignInAccount?> _interactiveAuthenticate() async {
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      debugPrint('## authenticate() not supported on this platform');
      return null;
    }
    try {
      return await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      debugPrint('## authenticate failed: ${e.code}');
      return null;
    }
  }

  static Future<String> _resolveAccessToken(GoogleSignInAccount account) async {
    final silent = await account.authorizationClient.authorizationForScopes(
      _scopes,
    );
    if (silent != null) {
      return silent.accessToken;
    }

    try {
      final interactive = await account.authorizationClient.authorizeScopes(
        _scopes,
      );
      return interactive.accessToken;
    } on GoogleSignInException catch (e) {
      debugPrint('## authorizeScopes failed: ${e.code}');
      return '';
    }
  }
}
