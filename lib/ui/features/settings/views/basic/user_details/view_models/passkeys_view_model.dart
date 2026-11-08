import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/app/env.dart';
import 'package:admin/data/repositories/passkey_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/passkey_api.dart';
import 'package:admin/data/services/passkey_readiness.dart';
import 'package:admin/data/services/passkey_failure.dart';

final _log = Logger('PasskeysViewModel');

/// The server's cap (`PasskeyService::MAX_CREDENTIALS_PER_USER`). Enforced
/// here too, so the user sees "Max: 10" instead of the server's untranslated
/// 422.
const int kMaxPasskeysPerUser = 10;

/// What an add or a remove came to, for the section to say. A null key with
/// a non-null message is server text shown as-is; both null is a dismissed OS
/// sheet — nothing to say.
typedef PasskeyActionResult = ({bool ok, String? errorKey, String? message});

/// The Passkeys section of Settings → User Details → Two-Factor
/// (docs/passkeys.md).
class PasskeysViewModel extends ChangeNotifier {
  PasskeysViewModel({
    required this.repo,
    required this.readiness,
    required this.apiBaseUrl,
    required this.isHosted,
  });

  final PasskeyRepository repo;
  final PasskeyReadiness readiness;
  final String apiBaseUrl;
  final bool isHosted;

  List<RegisteredPasskey> _passkeys = const [];
  List<RegisteredPasskey> get passkeys => _passkeys;

  bool _loading = true;
  bool get loading => _loading;

  /// False on a server whose passkey routes 404 / 405 (older than passkeys):
  /// the section is hidden.
  bool _serverSupported = true;
  bool get serverSupported => _serverSupported;

  /// The list could not be fetched for another reason; the section offers a
  /// retry.
  bool _loadFailed = false;
  bool get loadFailed => _loadFailed;

  /// Whether a passkey can be added from this device against this server —
  /// proven at runtime, so it stays false until the server and hosting
  /// changes it depends on are deployed.
  bool _canRegister = false;
  bool get canRegister => _canRegister && !Env.demoMode;

  bool _busy = false;
  bool get busy => _busy;

  bool get atLimit => _passkeys.length >= kMaxPasskeysPerUser;

  /// Whether the section has anything to show: rows to manage, or a passkey
  /// this device can add.
  bool get visible =>
      !Env.demoMode &&
      _serverSupported &&
      (_loading || _loadFailed || _passkeys.isNotEmpty || canRegister);

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Fetches the list and asks whether this device can register, together.
  Future<void> load() async {
    _loading = true;
    _loadFailed = false;
    _notify();
    final ready = readiness
        .isReady(apiBaseUrl: apiBaseUrl, isHosted: isHosted)
        .catchError((Object _) => false);
    try {
      _passkeys = await repo.list();
      _serverSupported = true;
    } on ServerException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        _serverSupported = false;
      } else {
        _loadFailed = true;
      }
    } on Object catch (_) {
      _loadFailed = true;
    }
    _canRegister = await ready;
    _loading = false;
    _notify();
  }

  /// Registers a passkey on this device under [name] (blank → the server's
  /// "Passkey" and a timestamp).
  Future<PasskeyActionResult> add(String? name) async {
    if (_busy || !canRegister || atLimit) {
      return (ok: false, errorKey: null, message: null);
    }
    _busy = true;
    _notify();
    try {
      await repo.add(
        name: name,
        beforeCeremony: (options) => readiness.allowsCeremony(
          apiBaseUrl: apiBaseUrl,
          isHosted: isHosted,
          options: options,
        ),
      );
      await _reload();
      return (ok: true, errorKey: null, message: null);
    } on PasskeyException catch (e) {
      if (e.failure == PasskeyFailure.failed) {
        _log.warning('Adding a passkey failed: ${e.message}');
      }
      return switch (e.failure) {
        PasskeyFailure.cancelled => (ok: false, errorKey: null, message: null),
        PasskeyFailure.alreadyRegistered => (
          ok: false,
          errorKey: 'passkey_already_registered',
          message: null,
        ),
        PasskeyFailure.notAssociated ||
        PasskeyFailure.noCredentials ||
        PasskeyFailure.unsupported => (
          ok: false,
          errorKey: 'passkeys_cannot_add_here',
          message: null,
        ),
        // The platform's text is for the log: on Windows it is an HRESULT.
        PasskeyFailure.failed => (
          ok: false,
          errorKey: 'an_error_occurred_try_again',
          message: null,
        ),
      };
    } on ApiException catch (e) {
      return (ok: false, errorKey: null, message: e.message);
    } on Object catch (e) {
      return (ok: false, errorKey: null, message: '$e');
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<PasskeyActionResult> remove(RegisteredPasskey passkey) async {
    if (_busy) return (ok: false, errorKey: null, message: null);
    _busy = true;
    _notify();
    try {
      await repo.remove(passkey.id);
      await _reload();
      return (ok: true, errorKey: null, message: null);
    } on ApiException catch (e) {
      return (ok: false, errorKey: null, message: e.message);
    } on Object catch (e) {
      return (ok: false, errorKey: null, message: '$e');
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// After a change: the server's list is the truth (a stored name, a removal
  /// another device made). A failed refetch keeps the old rows.
  Future<void> _reload() async {
    try {
      _passkeys = await repo.list();
    } on Object catch (_) {
      // Keep what is on screen; the next visit refetches.
    }
  }
}
