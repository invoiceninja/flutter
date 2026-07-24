import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/auth_service.dart';

/// Pins the `POST /api/v1/login/precheck` contract and — more importantly —
/// its **fail-open** guarantee.
///
/// The login form hides its optional TOTP / API-secret fields based on this
/// answer, so a precheck that threw, or that reported "nothing required" when
/// it actually failed, would hide a field the user needs and lock them out.
/// Every failure path must therefore surface as `null`, which the ViewModel
/// reads as "show everything".
///
/// Shape verified live against `demo.invoiceninja.com` (2026-07-24):
/// `{"methods":["password"],"secret_required":false}`. Server side:
/// `LoginController::precheck` + `PrecheckLoginRequest`.
///
/// auth_service-only import (like `auth_service_login_test.dart`) — fast and
/// independent of any unrelated concurrent breakage.
void main() {
  AuthService serviceReturning(http.Response Function(http.Request) handler) =>
      AuthService(httpClient: MockClient((req) async => handler(req)));

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json'},
  );

  Future<LoginPrecheck?> run(AuthService svc) => svc.precheck(
    baseUrl: 'https://ninja.example.com',
    isHosted: false,
    email: 'user@example.com',
  );

  group('AuthService.precheck — happy path', () {
    test('posts {email} to /api/v1/login/precheck', () async {
      Uri? url;
      String? body;
      final svc = serviceReturning((req) {
        url = req.url;
        body = req.body;
        return json({
          'methods': <String>['password'],
          'secret_required': false,
        });
      });

      await run(svc);

      expect(url.toString(), 'https://ninja.example.com/api/v1/login/precheck');
      expect(jsonDecode(body!), {'email': 'user@example.com'});
    });

    test('password-only account needs neither OTP nor secret', () async {
      final svc = serviceReturning(
        (_) => json({
          'methods': <String>['password'],
          'secret_required': false,
        }),
      );

      final result = await run(svc);

      expect(result, isNotNull);
      expect(result!.requiresOtp, isFalse);
      expect(result.secretRequired, isFalse);
    });

    test('totp in methods sets requiresOtp', () async {
      final svc = serviceReturning(
        (_) => json({
          'methods': <String>['password', 'totp'],
          'secret_required': true,
        }),
      );

      final result = await run(svc);

      expect(result!.requiresOtp, isTrue);
      expect(result.secretRequired, isTrue);
    });
  });

  group('AuthService.precheck — fails open (returns null, never throws)', () {
    test('404 from a server without the endpoint', () async {
      final svc = serviceReturning((_) => json({'message': 'Not found'}, 404));
      expect(await run(svc), isNull);
    });

    test('429 rate limit', () async {
      final svc = serviceReturning((_) => json({'message': 'slow down'}, 429));
      expect(await run(svc), isNull);
    });

    test('500 server error', () async {
      final svc = serviceReturning((_) => json({'message': 'boom'}, 500));
      expect(await run(svc), isNull);
    });

    test('non-JSON body', () async {
      final svc = serviceReturning((_) => http.Response('<html>nope', 200));
      expect(await run(svc), isNull);
    });

    test('JSON that is not an object', () async {
      final svc = serviceReturning((_) => json(<String>['unexpected']));
      expect(await run(svc), isNull);
    });

    test('transport failure (offline / bad host)', () async {
      final svc = AuthService(
        httpClient: MockClient(
          (_) async => throw http.ClientException('no route to host'),
        ),
      );
      expect(await run(svc), isNull);
    });
  });

  group('AuthService.precheck — tolerant decoding', () {
    test(
      'missing methods key yields no OTP requirement, not a throw',
      () async {
        final svc = serviceReturning((_) => json({'secret_required': true}));

        final result = await run(svc);

        expect(result, isNotNull);
        expect(result!.methods, isEmpty);
        expect(result.requiresOtp, isFalse);
        expect(result.secretRequired, isTrue);
      },
    );

    test('non-string entries in methods are skipped', () async {
      final svc = serviceReturning(
        (_) => json({
          'methods': <Object?>['password', 42, null, 'totp'],
          'secret_required': false,
        }),
      );

      final result = await run(svc);

      expect(result!.methods, {'password', 'totp'});
    });

    test('secret_required only counts when literally true', () async {
      // Guards against a truthy-string ("1"/"true") being read as a bool.
      final svc = serviceReturning(
        (_) => json({
          'methods': <String>['password'],
          'secret_required': 'yes',
        }),
      );

      expect((await run(svc))!.secretRequired, isFalse);
    });
  });
}
