import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/auth_service.dart';

/// Pins the `X-API-SECRET` wire behavior for self-hosted auth requests.
///
/// A self-hosted Invoice Ninja server that sets `API_SECRET` in its `.env`
/// requires the header on the pre-auth routes (`/login`, `/reset_password`,
/// …); see `~/Code/invoiceninja/app/Http/Middleware/ApiSecretCheck.php`. The
/// user enters that value in the self-hosted login form, and it flows through
/// `AuthService._headers`. Hosted builds ignore the field and fall back to the
/// build-time `Env.hostedApiSecret` (empty under `flutter test`).
///
/// auth_service-only import (like `auth_service_signup_test.dart`) — fast and
/// independent of any unrelated concurrent breakage.
void main() {
  Future<Map<String, String>> captureHeaders(
    Future<void> Function(AuthService svc) call,
  ) async {
    Map<String, String>? headers;
    final svc = AuthService(
      httpClient: MockClient((req) async {
        headers = req.headers;
        return http.Response(
          jsonEncode({'data': <Object>[]}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    await call(svc);
    return headers!;
  }

  group('AuthService X-API-SECRET wire behavior', () {
    test('self-hosted login with a secret sends X-API-SECRET', () async {
      Uri? url;
      Map<String, String>? headers;
      final svc = AuthService(
        httpClient: MockClient((req) async {
          url = req.url;
          headers = req.headers;
          return http.Response(
            jsonEncode({'data': <Object>[]}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );

      await svc.login(
        baseUrl: 'https://self.hosted.test',
        isHosted: false,
        email: 'a@b.test',
        password: 'pw123456',
        secret: 'sek-123',
      );

      expect(url!.path, '/api/v1/login');
      // http lowercases header keys in MockClient's req.headers.
      expect(headers!['x-api-secret'], 'sek-123');
    });

    test('self-hosted login without a secret omits X-API-SECRET', () async {
      final headers = await captureHeaders(
        (svc) => svc.login(
          baseUrl: 'https://self.hosted.test',
          isHosted: false,
          email: 'a@b.test',
          password: 'pw123456',
        ),
      );
      expect(headers.containsKey('x-api-secret'), isFalse);
    });

    test(
      'self-hosted reset_password with a secret sends X-API-SECRET',
      () async {
        Uri? url;
        Map<String, String>? headers;
        final svc = AuthService(
          httpClient: MockClient((req) async {
            url = req.url;
            headers = req.headers;
            return http.Response('', 200);
          }),
        );

        await svc.recoverPassword(
          baseUrl: 'https://self.hosted.test',
          isHosted: false,
          email: 'a@b.test',
          secret: 'sek-123',
        );

        expect(url!.path, '/api/v1/reset_password');
        expect(headers!['x-api-secret'], 'sek-123');
      },
    );

    test(
      'hosted login ignores the passed secret (uses Env, empty in tests)',
      () async {
        // Hosted must never send a user-entered self-hosted secret — it derives
        // the header from the build-time Env.hostedApiSecret, which is empty
        // under `flutter test`, so no header is sent.
        final headers = await captureHeaders(
          (svc) => svc.login(
            baseUrl: 'https://hosted.test',
            isHosted: true,
            email: 'a@b.test',
            password: 'pw123456',
            secret: 'should-be-ignored',
          ),
        );
        expect(headers.containsKey('x-api-secret'), isFalse);
      },
    );
  });
}
