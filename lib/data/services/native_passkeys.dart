import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:admin/data/services/passkey_codec.dart';
import 'package:admin/data/services/passkey_failure.dart';

/// The OS passkey sheet on Android, iOS, macOS and Windows over the
/// `invoice_ninja/passkeys` channel (docs/passkeys.md): WebAuthn JSON in, the
/// `PublicKeyCredential` as WebAuthn JSON out, every failure a
/// [PasskeyException].
///
/// Our own native code, not the `passkeys_*` plugins (whose Darwin build
/// needs macOS 13.5 and whose Windows one links webauthn.dll at load time):
/// - **Android** (`PasskeysPlugin.kt` in `packages/store_services`, because
///   Play Services is the provider below Android 14): Credential Manager
///   takes and returns the WebAuthn JSON itself. The F-Droid build has no
///   such plugin, so [isAvailable] is false there.
/// - **iOS / macOS** (`packages/passkeys_native`, AuthenticationServices):
///   the fields travel as bytes and this class builds the JSON. The OS makes
///   `clientDataJSON` from the challenge.
/// - **Windows** (`packages/passkeys_native`, webauthn.dll): as Apple, except
///   that the caller makes `clientDataJSON`, so this class does.
class NativePasskeys {
  const NativePasskeys({
    MethodChannel channel = const MethodChannel(kChannel),
    TargetPlatform? platform,
  }) : _channel = channel,
       _platform = platform;

  /// Same name as `PasskeysPlugin.CHANNEL` and the native plugins' channel.
  static const kChannel = 'invoice_ninja/passkeys';

  final MethodChannel _channel;
  final TargetPlatform? _platform;

  TargetPlatform get _os => _platform ?? defaultTargetPlatform;

  bool get _isApple => _os == TargetPlatform.iOS || _os == TargetPlatform.macOS;

  /// Whether this device can show the OS passkey sheet at all. False on
  /// Linux, wherever no plugin answers (the F-Droid build), and whenever the
  /// platform cannot say.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    switch (_os) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        break;
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on Object catch (_) {
      return false;
    }
  }

  /// Signs in with a passkey. [publicKey] is the server's
  /// `PublicKeyCredentialRequestOptions` JSON; the result is the
  /// `PublicKeyCredential` (`id`, `rawId`, `type`, `response:
  /// {clientDataJSON, authenticatorData, signature, userHandle?}`).
  Future<Map<String, dynamic>> authenticate(Map<String, dynamic> publicKey) =>
      _guard(() async {
        if (_os == TargetPlatform.android) {
          return _android('authenticate', publicKey);
        }
        final rpId = _string(publicKey['rpId']);
        final challenge = _string(publicKey['challenge']);
        final args = <String, Object?>{
          'rpId': rpId,
          'allowCredentials': _ids(publicKey['allowCredentials']),
          'userVerification': publicKey['userVerification'] is String
              ? publicKey['userVerification']
              : 'preferred',
          'timeoutMs': _int(publicKey['timeout']),
        };
        final clientData = _clientData('webauthn.get', challenge, rpId);
        if (_isApple) {
          args['challenge'] = decodeBase64Url(challenge);
        } else {
          args['clientDataJSON'] = clientData;
        }
        final reply = await _invoke('authenticate', args);
        final credentialId = _bytes(reply['credentialId']);
        final userHandle = reply['userHandle'];
        return {
          'id': encodeBase64Url(credentialId),
          'rawId': encodeBase64Url(credentialId),
          'type': 'public-key',
          'response': {
            'clientDataJSON': encodeBase64Url(
              _isApple ? _bytes(reply['clientDataJSON']) : clientData,
            ),
            'authenticatorData': encodeBase64Url(
              _bytes(reply['authenticatorData']),
            ),
            'signature': encodeBase64Url(_bytes(reply['signature'])),
            if (userHandle is Uint8List && userHandle.isNotEmpty)
              'userHandle': encodeBase64Url(userHandle),
          },
        };
      });

  /// Creates a passkey. [publicKey] is the server's
  /// `PublicKeyCredentialCreationOptions` JSON; the result is the
  /// `PublicKeyCredential` (`response: {clientDataJSON, attestationObject,
  /// transports?}`).
  Future<Map<String, dynamic>> register(Map<String, dynamic> publicKey) =>
      _guard(() async {
        if (_os == TargetPlatform.android) {
          return _android('register', publicKey);
        }
        final rp = _map(publicKey['rp']);
        final user = _map(publicKey['user']);
        final selection = _map(publicKey['authenticatorSelection']);
        final rpId = _string(rp['id']);
        final challenge = _string(publicKey['challenge']);
        final args = <String, Object?>{
          'rpId': rpId,
          'rpName': rp['name'] is String ? rp['name'] : rpId,
          'userId': decodeBase64Url(_string(user['id'])),
          'userName': _string(user['name']),
          'userDisplayName': user['displayName'] is String
              ? user['displayName']
              : user['name'],
          'algorithms': [
            for (final param in _list(publicKey['pubKeyCredParams']))
              if (param is Map && param['alg'] is int) param['alg'],
          ],
          'excludeCredentials': _ids(publicKey['excludeCredentials']),
          'userVerification': selection['userVerification'] is String
              ? selection['userVerification']
              : 'preferred',
          'timeoutMs': _int(publicKey['timeout']),
        };
        final clientData = _clientData('webauthn.create', challenge, rpId);
        if (_isApple) {
          args['challenge'] = decodeBase64Url(challenge);
        } else {
          args['clientDataJSON'] = clientData;
        }
        final reply = await _invoke('register', args);
        final credentialId = _bytes(reply['credentialId']);
        return {
          'id': encodeBase64Url(credentialId),
          'rawId': encodeBase64Url(credentialId),
          'type': 'public-key',
          'response': {
            'clientDataJSON': encodeBase64Url(
              _isApple ? _bytes(reply['clientDataJSON']) : clientData,
            ),
            'attestationObject': encodeBase64Url(
              _bytes(reply['attestationObject']),
            ),
          },
        };
      });

  /// The channel's error codes, the same on every platform.
  @visibleForTesting
  static PasskeyFailure failureForCode(String code) => switch (code) {
    'cancelled' => PasskeyFailure.cancelled,
    'not-associated' => PasskeyFailure.notAssociated,
    'no-credentials' => PasskeyFailure.noCredentials,
    'already-registered' => PasskeyFailure.alreadyRegistered,
    'unsupported' => PasskeyFailure.unsupported,
    _ => PasskeyFailure.failed,
  };

  /// Credential Manager parses the WebAuthn JSON itself. `extensions` goes:
  /// the server's is lbuchs' placeholder `{exts: true}`, which is no
  /// extension at all.
  Future<Map<String, dynamic>> _android(
    String method,
    Map<String, dynamic> publicKey,
  ) async {
    final request = Map<String, dynamic>.of(publicKey)..remove('extensions');
    final reply = await _invoke(method, {'requestJson': jsonEncode(request)});
    final decoded = jsonDecode(_string(reply['responseJson']));
    if (decoded is! Map<String, dynamic>) {
      throw const PasskeyException(PasskeyFailure.failed, 'Not a credential');
    }
    return decoded;
  }

  Future<Map<Object?, Object?>> _invoke(
    String method,
    Map<String, Object?> args,
  ) async {
    final reply = await _channel.invokeMethod<Map<Object?, Object?>>(
      method,
      args,
    );
    if (reply == null) {
      throw const PasskeyException(PasskeyFailure.failed, 'No reply');
    }
    return reply;
  }

  /// Every failure, typed: a platform error by its code, a missing plugin as
  /// unsupported, and options or a reply that don't parse as failed — never
  /// an uncaught error under the sign-in button.
  Future<Map<String, dynamic>> _guard(
    Future<Map<String, dynamic>> Function() body,
  ) async {
    try {
      return await body();
    } on PasskeyException {
      rethrow;
    } on PlatformException catch (e) {
      throw PasskeyException(failureForCode(e.code), e.message);
    } on MissingPluginException catch (e) {
      throw PasskeyException(PasskeyFailure.unsupported, e.message);
    } on Object catch (e) {
      throw PasskeyException(PasskeyFailure.failed, '$e');
    }
  }

  /// The client data a browser would make (WebAuthn §5.8.1), for Windows,
  /// where the caller supplies it. The origin is the relying party's own:
  /// what the server accepts from a page on that host.
  static Uint8List _clientData(String type, String challenge, String rpId) =>
      utf8.encode(
        jsonEncode({
          'type': type,
          'challenge': challenge,
          'origin': 'https://$rpId',
          'crossOrigin': false,
        }),
      );

  static List<Uint8List> _ids(Object? list) => [
    for (final item in _list(list))
      if (item is Map && item['id'] is String)
        decodeBase64Url(item['id'] as String),
  ];

  static String _string(Object? value) {
    if (value is String && value.isNotEmpty) return value;
    throw const FormatException('Missing passkey option');
  }

  static int? _int(Object? value) => value is num ? value.toInt() : null;

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static List<Object?> _list(Object? value) => value is List ? value : const [];

  static Uint8List _bytes(Object? value) {
    if (value is Uint8List && value.isNotEmpty) return value;
    throw const FormatException('Missing passkey reply field');
  }
}
