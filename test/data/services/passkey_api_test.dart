import 'dart:convert';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/passkey_api.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// What Credential Manager's `registrationResponseJson` looks like: WebAuthn
/// JSON plus Android's extras (`authenticatorAttachment`,
/// `clientExtensionResults`, and the response's `publicKey` /
/// `publicKeyAlgorithm` / `authenticatorData`).
const _androidRegistration = {
  'rawId': 'Y3JlZA',
  'authenticatorAttachment': 'platform',
  'type': 'public-key',
  'id': 'Y3JlZA',
  'response': {
    'clientDataJSON': 'Y2xpZW50',
    'attestationObject': 'YXR0',
    'transports': ['internal', 'hybrid', ''],
    'authenticatorData': 'YXV0aA',
    'publicKeyAlgorithm': -7,
    'publicKey': 'cGs',
  },
  'clientExtensionResults': {
    'credProps': {'rk': true},
  },
};

/// What Credential Manager's `authenticationResponseJson` looks like.
const _androidAssertion = {
  'rawId': 'Y3JlZA',
  'authenticatorAttachment': 'platform',
  'type': 'public-key',
  'id': 'Y3JlZA',
  'response': {
    'clientDataJSON': 'Y2xpZW50',
    'authenticatorData': 'YXV0aA',
    'signature': 'c2ln',
    'userHandle': 'NDI',
  },
  'clientExtensionResults': <String, Object?>{},
};

/// The bodies the server's passkey routes read (PasskeyController::store's
/// rules; LoginRequest's `passkey_authentication.*`), built from what the
/// native halves really return. A wrong shape on store is a 422 after the OS
/// has saved the passkey, which orphans it.
void main() {
  late List<http.Request> captured;

  PasskeyApi api() {
    captured = [];
    return PasskeyApi(
      ApiClient(
        credentials: ValueNotifier<ApiCredentials?>(
          const ApiCredentials(baseUrl: 'https://test', token: 't'),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: MockClient((request) async {
          captured.add(request);
          return http.Response('{"data":{}}', 200);
        }),
      ),
    );
  }

  test(
    'store sends only what the server reads, from Android\'s JSON',
    () async {
      await api().store(
        challengeToken: 'token-1',
        credential: _androidRegistration,
        name: '  Pixel  ',
      );

      expect(captured.single.url.path, '/api/v1/settings/passkeys');
      expect(jsonDecode(captured.single.body), {
        'challenge_token': 'token-1',
        'credential': {
          'clientDataJSON': 'Y2xpZW50',
          'attestationObject': 'YXR0',
          'transports': ['internal', 'hybrid'],
        },
        'name': 'Pixel',
      });
    },
  );

  test('store from Apple or Windows, which report no transports', () async {
    await api().store(
      challengeToken: 'token-1',
      credential: {
        'id': 'Y3JlZA',
        'rawId': 'Y3JlZA',
        'type': 'public-key',
        'response': {'clientDataJSON': 'Y2xpZW50', 'attestationObject': 'YXR0'},
      },
    );

    expect(jsonDecode(captured.single.body), {
      'challenge_token': 'token-1',
      'credential': {'clientDataJSON': 'Y2xpZW50', 'attestationObject': 'YXR0'},
    });
  });

  test('a sign-in is flattened with Android\'s top-level extras dropped', () {
    expect(flattenPasskeyCredential(_androidAssertion), {
      'id': 'Y3JlZA',
      'rawId': 'Y3JlZA',
      'type': 'public-key',
      'clientDataJSON': 'Y2xpZW50',
      'authenticatorData': 'YXV0aA',
      'signature': 'c2ln',
      'userHandle': 'NDI',
    });
  });
}
