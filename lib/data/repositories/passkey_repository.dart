import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/passkey_api.dart';
import 'package:admin/data/services/passkey_authenticator.dart';
import 'package:admin/data/services/passkey_failure.dart';

/// The signed-in user's passkeys (Settings → User Details → Two-Factor).
///
/// An accepted exception to "every write goes through the outbox"
/// (CLAUDE.md § Strict rules), like [TwoFactorRepository] beside it: adding a
/// passkey is one synchronous ceremony — fetch a challenge the server holds
/// for five minutes, run the OS sheet, return the signed result — that cannot
/// be queued, and a removal is its settings-screen companion.
class PasskeyRepository {
  PasskeyRepository({
    required PasskeyApi api,
    PasskeyAuthenticator authenticator = const PlatformPasskeyAuthenticator(),
  }) : _api = api,
       _authenticator = authenticator;

  final PasskeyApi _api;
  final PasskeyAuthenticator _authenticator;

  Future<List<RegisteredPasskey>> list() => _api.list();

  /// Creates a passkey on this device and stores it under [name]. Throws a
  /// `PasskeyException` when the OS sheet ends without one, or an
  /// `ApiException` when the server refuses it.
  ///
  /// [beforeCeremony] sees the server's options before the OS sheet opens and
  /// can refuse them (`PasskeyReadiness.allowsCeremony`): once the OS has
  /// created the credential, a server that then rejects it leaves it orphaned
  /// in the user's password manager.
  Future<void> add({
    String? name,
    required Future<bool> Function(PasskeyLoginOptions options) beforeCeremony,
  }) async {
    final options = await _api.registrationOptions();
    if (!await beforeCeremony(options)) {
      throw const PasskeyException(PasskeyFailure.notAssociated);
    }
    final credential = await _authenticator.register(options.publicKey);
    await _api.store(
      challengeToken: options.challengeToken,
      credential: credential,
      name: name,
    );
  }

  Future<void> remove(String id) => _api.remove(id);
}
