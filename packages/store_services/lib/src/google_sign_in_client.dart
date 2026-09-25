import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Google sign-in, reduced to the one value the app needs: an OAuth access
/// token for `/api/v1/oauth_login`.
///
/// The app-facing wrapper (and the reasoning behind riding v7's access-token
/// path rather than its id-token path) is `lib/data/services/google_oauth.dart`.
/// The client IDs are passed on every call because this package can't read
/// the app's dart-defines.
class GoogleSignInClient {
  GoogleSignInClient._();

  static bool _initialized = false;

  /// Each platform needs its own client ID, and an empty one means "not
  /// configured for this build" — so the button is hidden rather than shown
  /// and failing. Android: the Web/server client ID (Credential Manager can't
  /// resolve it from `google-services.json`). iOS: the iOS client ID, passed
  /// to `initialize(clientId:)` so no `GoogleService-Info.plist` is needed —
  /// though its reversed form must still be a registered URL scheme in
  /// `Info.plist`. Web/desktop are out of scope (login is hosted-only).
  static bool isSupported({
    required String androidServerClientId,
    required String iosClientId,
  }) {
    if (kIsWeb) return false;
    if (Platform.isIOS) return iosClientId.isNotEmpty;
    if (Platform.isAndroid) return androidServerClientId.isNotEmpty;
    return false;
  }

  static Future<void> _init(
    String androidServerClientId,
    String iosClientId,
  ) async {
    if (_initialized) {
      return;
    }
    if (!kIsWeb && Platform.isAndroid) {
      await GoogleSignIn.instance.initialize(
        serverClientId: androidServerClientId,
      );
    } else if (!kIsWeb && Platform.isIOS) {
      // Never `serverClientId` here: that asks Google for a server auth code
      // bound to another client, which this app doesn't use.
      await GoogleSignIn.instance.initialize(clientId: iosClientId);
    } else {
      await GoogleSignIn.instance.initialize();
    }
    _initialized = true;
  }

  /// Interactive sign-in. Returns the access token, or `''` when the user
  /// cancelled or no token could be obtained.
  ///
  /// Signs out first (best effort), as admin-portal did before every sign-in:
  /// otherwise the SDK quietly reuses the last account, and a user who picked
  /// the wrong one — or a second person on the device — never sees the
  /// chooser again.
  static Future<String> signIn({
    required String androidServerClientId,
    required String iosClientId,
  }) async {
    await _init(androidServerClientId, iosClientId);
    try {
      await GoogleSignIn.instance.signOut();
    } on Object catch (e) {
      debugPrint('## pre-sign-in signOut failed: $e');
    }

    final account = await _interactiveAuthenticate();
    if (account == null) {
      return '';
    }
    return _resolveAccessToken(account);
  }

  static Future<void> signOut({
    required String androidServerClientId,
    required String iosClientId,
  }) async {
    await _init(androidServerClientId, iosClientId);
    await GoogleSignIn.instance.signOut();
  }

  /// Revokes the app's grant, not just the local session — for when the
  /// user unlinks Google from their account.
  static Future<void> disconnect({
    required String androidServerClientId,
    required String iosClientId,
  }) async {
    await _init(androidServerClientId, iosClientId);
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
