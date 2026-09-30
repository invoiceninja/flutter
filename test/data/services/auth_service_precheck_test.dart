import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';

/// Pins the `POST /api/v1/login/precheck` contract and its **fail-open**
/// guarantee.
///
/// The login screen's Continue asks this before showing step 2, and step 2
/// hides the TOTP / API-secret fields based on the answer. Self-hosted
/// servers run any version, so every "the server can't answer" path — an
/// older server that 404s the route, a rate limit, a 5xx, a malformed body —
/// must surface as `null`, which the ViewModel reads as "show everything".
///
/// Exactly two answers are *not* fail-open, because both mean "fix step 1
/// first" and a login would fail the same way: an unreachable server
/// ([NetworkException], including no answer within
/// [AuthService.interactiveTimeout]) and a rejected address
/// ([ValidationException]).
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

  group('AuthService.precheck — fails open (returns null)', () {
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

    test('405 from a server whose router only knows GET there', () async {
      final svc = serviceReturning(
        (_) => http.Response('Method Not Allowed', 405),
      );
      expect(await run(svc), isNull);
    });

    test('a 200 without a methods list is no answer', () async {
      // Reading it as "no methods" would hide the OTP field of an account
      // that has TOTP — and the answer is cached per (server, email).
      final svc = serviceReturning((_) => json({'secret_required': true}));
      expect(await run(svc), isNull);
    });
  });

  group('AuthService.precheck — the two answers that keep step 1', () {
    test('transport failure (offline / bad host) → NetworkException', () {
      final svc = AuthService(
        httpClient: MockClient(
          (_) async => throw http.ClientException('no route to host'),
        ),
      );
      expect(run(svc), throwsA(isA<NetworkException>()));
    });

    testWidgets('no answer within the timeout → NetworkException', (
      tester,
    ) async {
      // Production builds AuthService on a plain `http.Client()` with no
      // connect timeout, so without this an unanswered self-hosted URL spins
      // Continue for the OS timeout (~75 s on Apple platforms).
      final never = Completer<http.Response>();
      final svc = AuthService(httpClient: MockClient((_) => never.future));
      Object? error;
      unawaited(run(svc).then<void>((_) {}, onError: (Object e) => error = e));

      await tester.pump(
        AuthService.interactiveTimeout - const Duration(seconds: 1),
      );
      expect(error, isNull);
      await tester.pump(const Duration(seconds: 2));
      // Not `TimeoutException.message`, which `Future.timeout` always sets to
      // "Future not completed" — that would reach the user verbatim.
      expect(
        error,
        isA<NetworkException>().having(
          (e) => e.message,
          'message',
          'Request timed out after ${AuthService.interactiveTimeout.inSeconds}s',
        ),
      );
    });

    test('any other transport throw (TLS handshake) → NetworkException', () {
      // `IOClient` wraps only SocketException / HttpException, so a
      // `HandshakeException` (an untrusted self-hosted certificate) arrives
      // raw. It must still read as "can't reach the server".
      final svc = AuthService(
        httpClient: MockClient(
          (_) async =>
              throw Exception('HandshakeException: CERTIFICATE_VERIFY_FAILED'),
        ),
      );
      expect(
        run(svc),
        throwsA(
          isA<NetworkException>().having(
            (e) => e.message,
            'message',
            contains('CERTIFICATE_VERIFY_FAILED'),
          ),
        ),
      );
    });

    test('422 → ValidationException carrying the field errors', () {
      final svc = serviceReturning(
        (_) => json({
          'message': 'The email is invalid.',
          'errors': {
            'email': ['The email is invalid.'],
          },
        }, 422),
      );
      expect(
        run(svc),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors['email'],
            'fieldErrors[email]',
            ['The email is invalid.'],
          ),
        ),
      );
    });
  });

  group('AuthService.precheck — tolerant decoding', () {
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

  test('withoutOtp drops only totp and keeps the secret flag', () {
    const answer = LoginPrecheck(
      methods: {'password', 'totp'},
      secretRequired: true,
    );
    final after = answer.withoutOtp();
    expect(after.methods, {'password'});
    expect(after.requiresOtp, isFalse);
    expect(after.secretRequired, isTrue);
  });
}
