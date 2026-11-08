import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/services/native_passkeys.dart';
import 'package:admin/data/services/passkey_codec.dart';
import 'package:admin/data/services/passkey_failure.dart';

/// lbuchs/webauthn 2.2.0's `getGetArgs` as PasskeyService sends it (captured
/// from the vendored library, challenge and id shortened).
Map<String, dynamic> _getArgs() => {
  'timeout': 240000,
  'challenge': encodeBase64Url([1, 2, 3, 4]),
  'userVerification': 'preferred',
  'rpId': 'app.invoicing.co',
  'allowCredentials': [
    {
      'id': encodeBase64Url([9, 9, 9]),
      'type': 'public-key',
      'transports': ['usb', 'nfc', 'ble', 'hybrid', 'internal'],
    },
  ],
};

/// lbuchs/webauthn 2.2.0's `getCreateArgs` as PasskeyService sends it
/// (captured from the vendored library, key order kept): EdDSA first, since
/// the server has sodium; `indirect`, since it allows seven formats; one
/// existing passkey to exclude, as on a second registration.
Map<String, dynamic> _createArgs() => {
  'rp': {'name': 'Invoice Ninja', 'id': 'app.invoicing.co'},
  'authenticatorSelection': {
    'userVerification': 'required',
    'requireResidentKey': true,
    'residentKey': 'required',
  },
  'user': {
    'id': encodeBase64Url(utf8.encode('42')),
    'name': 'user@example.com',
    'displayName': 'User Example',
  },
  'pubKeyCredParams': [
    {'type': 'public-key', 'alg': -8},
    {'type': 'public-key', 'alg': -7},
    {'type': 'public-key', 'alg': -257},
  ],
  'attestation': 'indirect',
  'extensions': {'exts': true},
  'timeout': 240000,
  'challenge': encodeBase64Url([5, 6, 7, 8]),
  'excludeCredentials': [
    {
      'id': encodeBase64Url([7, 7]),
      'type': 'public-key',
      'transports': ['internal'],
    },
  ],
};

Uint8List _b(List<int> bytes) => Uint8List.fromList(bytes);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(NativePasskeys.kChannel);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;

  void answer(Object? Function(MethodCall call) reply) {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
  }

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Map<Object?, Object?> args() => calls.single.arguments as Map;

  group('Android passes the WebAuthn JSON through', () {
    const passkeys = NativePasskeys(platform: TargetPlatform.android);

    test('authenticate sends the options and returns the response', () async {
      final response = {
        'id': 'abc',
        'rawId': 'abc',
        'type': 'public-key',
        'response': {'clientDataJSON': 'x'},
      };
      answer((_) => {'responseJson': jsonEncode(response)});

      final credential = await passkeys.authenticate(_getArgs());

      expect(calls.single.method, 'authenticate');
      expect(jsonDecode(args()['requestJson']! as String), _getArgs());
      expect(credential, response);
    });

    test('register drops lbuchs\' placeholder extensions', () async {
      answer((_) => {'responseJson': '{"id":"abc"}'});

      await passkeys.register(_createArgs());

      final sent =
          jsonDecode(args()['requestJson']! as String) as Map<String, dynamic>;
      expect(sent.containsKey('extensions'), isFalse);
      expect(sent, _createArgs()..remove('extensions'));
    });

    test('a reply that is not a credential is a failure', () async {
      answer((_) => {'responseJson': '[]'});
      await expectLater(
        passkeys.authenticate(_getArgs()),
        throwsA(
          isA<PasskeyException>().having(
            (e) => e.failure,
            'failure',
            PasskeyFailure.failed,
          ),
        ),
      );
    });
  });

  group('Apple sends bytes and builds the JSON', () {
    const passkeys = NativePasskeys(platform: TargetPlatform.iOS);

    test('authenticate', () async {
      answer(
        (_) => {
          'credentialId': _b([9, 9, 9]),
          'clientDataJSON': _b(utf8.encode('{"type":"webauthn.get"}')),
          'authenticatorData': _b([1]),
          'signature': _b([2]),
          'userHandle': _b(utf8.encode('42')),
        },
      );

      final credential = await passkeys.authenticate(_getArgs());

      expect(args()['rpId'], 'app.invoicing.co');
      expect(args()['challenge'], _b([1, 2, 3, 4]));
      expect(args()['allowCredentials'], [
        _b([9, 9, 9]),
      ]);
      expect(args()['userVerification'], 'preferred');
      expect(args().containsKey('clientDataJSON'), isFalse);
      expect(credential, {
        'id': encodeBase64Url([9, 9, 9]),
        'rawId': encodeBase64Url([9, 9, 9]),
        'type': 'public-key',
        'response': {
          'clientDataJSON': encodeBase64Url(
            utf8.encode('{"type":"webauthn.get"}'),
          ),
          'authenticatorData': encodeBase64Url([1]),
          'signature': encodeBase64Url([2]),
          'userHandle': encodeBase64Url(utf8.encode('42')),
        },
      });
    });

    test('an empty user handle is left out', () async {
      answer(
        (_) => {
          'credentialId': _b([9]),
          'clientDataJSON': _b([1]),
          'authenticatorData': _b([1]),
          'signature': _b([2]),
          'userHandle': Uint8List(0),
        },
      );
      final credential = await passkeys.authenticate(_getArgs());
      expect((credential['response'] as Map).containsKey('userHandle'), false);
    });

    test('register', () async {
      answer(
        (_) => {
          'credentialId': _b([3, 3]),
          'clientDataJSON': _b([4]),
          'attestationObject': _b([5]),
        },
      );

      final credential = await passkeys.register(_createArgs());

      expect(args()['rpId'], 'app.invoicing.co');
      expect(args()['challenge'], _b([5, 6, 7, 8]));
      expect(args()['userId'], _b(utf8.encode('42')));
      expect(args()['userName'], 'user@example.com');
      expect(args()['excludeCredentials'], [
        _b([7, 7]),
      ]);
      expect(args()['userVerification'], 'required');
      expect(credential, {
        'id': encodeBase64Url([3, 3]),
        'rawId': encodeBase64Url([3, 3]),
        'type': 'public-key',
        'response': {
          'clientDataJSON': encodeBase64Url([4]),
          'attestationObject': encodeBase64Url([5]),
        },
      });
    });
  });

  group('Windows takes clientDataJSON from the caller', () {
    const passkeys = NativePasskeys(platform: TargetPlatform.windows);

    test('authenticate builds a browser-shaped clientDataJSON', () async {
      answer(
        (_) => {
          'credentialId': _b([9, 9, 9]),
          'authenticatorData': _b([1]),
          'signature': _b([2]),
        },
      );

      final credential = await passkeys.authenticate(_getArgs());

      final clientData = args()['clientDataJSON']! as Uint8List;
      expect(jsonDecode(utf8.decode(clientData)), {
        'type': 'webauthn.get',
        'challenge': encodeBase64Url([1, 2, 3, 4]),
        'origin': 'https://app.invoicing.co',
        'crossOrigin': false,
      });
      expect(args().containsKey('challenge'), isFalse);
      expect(args()['timeoutMs'], 240000);
      final response = credential['response'] as Map;
      expect(response['clientDataJSON'], encodeBase64Url(clientData));
      expect(response.containsKey('userHandle'), isFalse);
    });

    test('register sends the RP, the user and the algorithms', () async {
      answer(
        (_) => {
          'credentialId': _b([3]),
          'attestationObject': _b([5]),
        },
      );

      final credential = await passkeys.register(_createArgs());

      expect(args()['rpName'], 'Invoice Ninja');
      expect(args()['userDisplayName'], 'User Example');
      expect(args()['algorithms'], [-8, -7, -257]);
      final clientData = args()['clientDataJSON']! as Uint8List;
      expect(
        (jsonDecode(utf8.decode(clientData)) as Map)['type'],
        'webauthn.create',
      );
      expect(
        (credential['response'] as Map)['clientDataJSON'],
        encodeBase64Url(clientData),
      );
    });
  });

  group('failures', () {
    const passkeys = NativePasskeys(platform: TargetPlatform.macOS);

    for (final (code, failure) in [
      ('cancelled', PasskeyFailure.cancelled),
      ('not-associated', PasskeyFailure.notAssociated),
      ('no-credentials', PasskeyFailure.noCredentials),
      ('already-registered', PasskeyFailure.alreadyRegistered),
      ('unsupported', PasskeyFailure.unsupported),
      ('failed', PasskeyFailure.failed),
      ('something-new', PasskeyFailure.failed),
    ]) {
      test('$code → $failure', () async {
        answer((_) => throw PlatformException(code: code));
        await expectLater(
          passkeys.authenticate(_getArgs()),
          throwsA(
            isA<PasskeyException>().having(
              (e) => e.failure,
              'failure',
              failure,
            ),
          ),
        );
      });
    }

    test('options missing a field fail before the channel', () async {
      answer((_) => null);
      await expectLater(
        passkeys.authenticate(_getArgs()..remove('challenge')),
        throwsA(
          isA<PasskeyException>().having(
            (e) => e.failure,
            'failure',
            PasskeyFailure.failed,
          ),
        ),
      );
      expect(calls, isEmpty);
    });

    test('no plugin is unsupported (the F-Droid build)', () async {
      // No handler: the channel throws MissingPluginException.
      await expectLater(
        const NativePasskeys(
          platform: TargetPlatform.android,
        ).register(_createArgs()),
        throwsA(
          isA<PasskeyException>().having(
            (e) => e.failure,
            'failure',
            PasskeyFailure.unsupported,
          ),
        ),
      );
    });
  });

  group('isAvailable', () {
    test('asks the plugin', () async {
      answer((_) => true);
      expect(
        await const NativePasskeys(
          platform: TargetPlatform.windows,
        ).isAvailable(),
        isTrue,
      );
    });

    test('is false with no plugin', () async {
      expect(
        await const NativePasskeys(
          platform: TargetPlatform.android,
        ).isAvailable(),
        isFalse,
      );
    });

    test('is false on Linux without asking', () async {
      answer((_) => true);
      expect(
        await const NativePasskeys(
          platform: TargetPlatform.linux,
        ).isAvailable(),
        isFalse,
      );
      expect(calls, isEmpty);
    });
  });
}
