import 'package:admin/data/services/passkey_failure.dart';

/// The native half of the [web_passkeys] seam: never used, since native
/// platforms go through `NativePasskeys`.
Future<bool> webPasskeysAvailable() async => false;

Future<bool> webPasskeysRelatedOrigins() async => false;

Future<Map<String, dynamic>> webPasskeyGet(Map<String, dynamic> publicKey) =>
    throw const PasskeyException(PasskeyFailure.unsupported);

Future<Map<String, dynamic>> webPasskeyCreate(Map<String, dynamic> publicKey) =>
    throw const PasskeyException(PasskeyFailure.unsupported);
