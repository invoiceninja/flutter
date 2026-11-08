import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:admin/data/services/native_passkeys.dart';
import 'package:admin/data/services/passkey_failure.dart';
import 'package:admin/data/services/web_passkeys.dart';

/// The OS or browser passkey sheet, in WebAuthn JSON: the server's
/// `publicKey` options in, the `PublicKeyCredential` out. Every failure is a
/// [PasskeyException].
///
/// An interface so view models can be tested without a platform sheet.
abstract interface class PasskeyAuthenticator {
  /// Whether this device can show a passkey sheet at all. Says nothing about
  /// a particular server — that is [PasskeyReadiness].
  Future<bool> isAvailable();

  Future<Map<String, dynamic>> authenticate(Map<String, dynamic> publicKey);

  Future<Map<String, dynamic>> register(Map<String, dynamic> publicKey);
}

/// Native platforms through [NativePasskeys] (our own plugins; Android's
/// lives in `package:store_services`, since it pulls Play Services, so the
/// F-Droid build has none); web through the browser's own API.
class PlatformPasskeyAuthenticator implements PasskeyAuthenticator {
  const PlatformPasskeyAuthenticator({
    NativePasskeys native = const NativePasskeys(),
  }) : _native = native;

  final NativePasskeys _native;

  @override
  Future<bool> isAvailable() =>
      kIsWeb ? webPasskeysAvailable() : _native.isAvailable();

  @override
  Future<Map<String, dynamic>> authenticate(Map<String, dynamic> publicKey) =>
      kIsWeb ? webPasskeyGet(publicKey) : _native.authenticate(publicKey);

  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> publicKey) =>
      kIsWeb ? webPasskeyCreate(publicKey) : _native.register(publicKey);
}
