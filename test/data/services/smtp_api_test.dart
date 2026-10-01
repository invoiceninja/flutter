import 'dart:convert';

import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/smtp_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SmtpApi.check', () {
    test('POSTs the SMTP payload to /api/v1/smtp/check', () async {
      http.Request? captured;
      final fake = MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'message': 'Successfully sent email'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = ApiClient(
        credentials: ValueNotifier<ApiCredentials?>(
          const ApiCredentials(baseUrl: 'https://test', token: 't'),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );

      final api = SmtpApi(client);
      final message = await api.check(
        payload: const {
          'smtp_host': 'smtp.example.com',
          'smtp_port': 587,
          'smtp_encryption': 'tls',
          'smtp_username': 'user',
          'smtp_password': 'pw',
          'smtp_local_domain': '',
          // Server reads `verify_peer`, not `smtp_verify_peer`.
          'verify_peer': true,
        },
      );

      expect(message, 'Successfully sent email');
      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v1/smtp/check');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['smtp_host'], 'smtp.example.com');
      expect(body['smtp_port'], 587);
      expect(body['smtp_encryption'], 'tls');
      expect(body['verify_peer'], true);
    });

    test(
      'returns empty string when the response has no message field',
      () async {
        final fake = MockClient(
          (_) async => http.Response(
            jsonEncode({}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        );
        final client = ApiClient(
          credentials: ValueNotifier<ApiCredentials?>(
            const ApiCredentials(baseUrl: 'https://test', token: 't'),
          ),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );
        final message = await SmtpApi(
          client,
        ).check(payload: const <String, dynamic>{});
        expect(message, isEmpty);
      },
    );
  });

  test('checkMailer POSTs the payload to /api/v1/mailer/check', () async {
    http.Request? captured;
    final client = ApiClient(
      credentials: ValueNotifier<ApiCredentials?>(
        const ApiCredentials(baseUrl: 'https://test', token: 't'),
      ),
      passwordCache: PasswordCache(),
      onUnauthorized: () async {},
      httpClient: MockClient((req) async {
        captured = req;
        return http.Response(
          jsonEncode({'message': 'Successfully sent email', 'mailer': 'gmail'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final message = await SmtpApi(
      client,
    ).checkMailer(payload: const {'mailer': 'gmail'});

    expect(message, 'Successfully sent email');
    expect(captured!.url.path, '/api/v1/mailer/check');
    expect(jsonDecode(captured!.body), {'mailer': 'gmail'});
  });
}
