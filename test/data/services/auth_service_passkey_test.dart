import 'dart:convert';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/passkey_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The passkey half of `/api/v1/login` and its options route, against the
/// server's contract (PasskeyController::loginOptions, LoginRequest):
/// `passkey_authentication` flattened as React sends it, and never a password —
/// a request carrying one is a password login on the server.
void main() {
  late http.Request captured;

  AuthService service(int status, Object body) => AuthService(
    httpClient: MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode(body), status);
    }),
  );

  const options = {
    'data': {
      'publicKey': {'rpId': 'app.invoicing.co', 'challenge': 'Y2g'},
      'challenge_token': 'token-1',
      'android_origins': [
        'android:apk-key-hash:u7yL-3JO8lZ3MDGxySLAUdNd7j_OvVk69xEvq0Z96Ig',
      ],
    },
  };

  test('options: the email, the secret, and what comes back', () async {
    final result = await service(200, options).passkeyLoginOptions(
      baseUrl: 'https://billing.example.com',
      isHosted: false,
      email: 'jane@example.com',
      secret: 's3cret',
    );

    expect(captured.url.path, '/api/v1/passkeys/login/options');
    expect(jsonDecode(captured.body), {'email': 'jane@example.com'});
    expect(captured.headers['X-API-SECRET'], 's3cret');
    expect(result.challengeToken, 'token-1');
    expect(result.relyingPartyId, 'app.invoicing.co');
    expect(result.androidOrigins, hasLength(1));
  });

  test(
    'options from a server without native passkeys list no app origin',
    () async {
      final result =
          await service(200, {
            'data': {
              'publicKey': {'rpId': 'app.invoicing.co'},
              'challenge_token': 't',
            },
          }).passkeyLoginOptions(
            baseUrl: 'https://invoicing.co',
            isHosted: true,
            email: 'jane@example.com',
          );

      expect(result.androidOrigins, isEmpty);
    },
  );

  test('an email without passkeys is a 400 ServerException', () async {
    await expectLater(
      service(400, {'message': 'Invalid credentials'}).passkeyLoginOptions(
        baseUrl: 'https://invoicing.co',
        isHosted: true,
        email: 'nobody@example.com',
      ),
      throwsA(
        isA<ServerException>().having((e) => e.statusCode, 'status', 400),
      ),
    );
  });

  test('half an answer is refused before any ceremony', () async {
    await expectLater(
      service(200, {
        'data': {'challenge_token': 't'},
      }).passkeyLoginOptions(
        baseUrl: 'https://invoicing.co',
        isHosted: true,
        email: 'jane@example.com',
      ),
      throwsA(isA<ServerException>()),
    );
  });

  test('login sends the flattened assertion and no password', () async {
    // Fails after the request is captured: a 400 is the rejected assertion.
    await expectLater(
      service(400, {'message': 'Invalid credentials'}).loginWithPasskey(
        baseUrl: 'https://invoicing.co',
        isHosted: true,
        email: 'jane@example.com',
        challengeToken: 'token-1',
        credential: const {
          'id': 'Y3JlZA',
          'rawId': 'Y3JlZA',
          'type': 'public-key',
          'response': {
            'clientDataJSON': 'Y2Q',
            'authenticatorData': 'YWQ',
            'signature': 'c2ln',
            'userHandle': 'MTIz',
          },
        },
      ),
      throwsA(isA<ServerException>()),
    );

    expect(captured.url.path, '/api/v1/login');
    expect(jsonDecode(captured.body), {
      'email': 'jane@example.com',
      'passkey_challenge_token': 'token-1',
      'passkey_authentication': {
        'id': 'Y3JlZA',
        'rawId': 'Y3JlZA',
        'type': 'public-key',
        'clientDataJSON': 'Y2Q',
        'authenticatorData': 'YWQ',
        'signature': 'c2ln',
        'userHandle': 'MTIz',
      },
    });
  });

  test('a listed passkey reads both date shapes the server sends', () {
    final passkey = RegisteredPasskey.fromJson(const {
      'id': 'Wpmbk5ezJn',
      'name': 'Pixel',
      'created_at': '2026-11-01T09:30:00.000000Z',
      'last_used_at': 1762508400,
    });

    expect(passkey.createdAt, DateTime.utc(2026, 11, 1, 9, 30));
    expect(
      passkey.lastUsedAt,
      DateTime.fromMillisecondsSinceEpoch(1762508400000, isUtc: true),
    );
    expect(
      RegisteredPasskey.fromJson(const {
        'id': 'x',
        'name': '',
        'last_used_at': null,
      }).lastUsedAt,
      isNull,
      reason: 'never used',
    );
  });
}
