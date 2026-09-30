import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';

/// Pins the login screen's lost-authenticator reset — React's
/// `Disable2faModal`: `POST /api/v1/sms_reset` then `/sms_reset/confirm`.
///
/// The load-bearing detail is what the confirm call does **not** send: with
/// `?validate_only=true` the server's `TwilioController::confirm2faResetCode`
/// only marks the phone verified (the settings screen's phone check); without
/// it, it nulls `google_2fa_secret`, which is the whole point here.
void main() {
  late List<http.Request> requests;

  AuthService serviceReturning(http.Response response) {
    requests = [];
    return AuthService(
      httpClient: MockClient((req) async {
        requests.add(req);
        return response;
      }),
    );
  }

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: const {'content-type': 'application/json'},
  );

  group('sendTwoFactorResetCode', () {
    test(
      'posts {email} to /api/v1/sms_reset and returns the message',
      () async {
        final svc = serviceReturning(json({'message': 'Code sent.'}));

        final message = await svc.sendTwoFactorResetCode(
          baseUrl: 'https://ninja.example.com',
          isHosted: false,
          email: 'user@example.com',
        );

        expect(message, 'Code sent.');
        final req = requests.single;
        expect(
          req.url.toString(),
          'https://ninja.example.com/api/v1/sms_reset',
        );
        expect(jsonDecode(req.body), {'email': 'user@example.com'});
      },
    );

    test('a 400 (no phone on file) raises with the server message', () {
      final svc = serviceReturning(
        json({
          'message':
              'User found, but no valid phone number on file, please '
              'contact support.',
        }, 400),
      );
      expect(
        svc.sendTwoFactorResetCode(
          baseUrl: 'https://ninja.example.com',
          isHosted: false,
          email: 'user@example.com',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains('no valid phone number'),
          ),
        ),
      );
    });
  });

  group('confirmTwoFactorReset', () {
    test('posts {email, code} with NO validate_only query', () async {
      final svc = serviceReturning(
        json({'message': 'SMS verified, 2FA disabled.'}),
      );

      final message = await svc.confirmTwoFactorReset(
        baseUrl: 'https://ninja.example.com',
        isHosted: false,
        email: 'user@example.com',
        code: '123456',
      );

      expect(message, 'SMS verified, 2FA disabled.');
      final req = requests.single;
      expect(req.url.path, '/api/v1/sms_reset/confirm');
      expect(req.url.queryParameters, isEmpty);
      expect(jsonDecode(req.body), {
        'email': 'user@example.com',
        'code': '123456',
      });
    });

    test('an unapproved code (400) raises', () {
      final svc = serviceReturning(json({'message': 'SMS not verified.'}, 400));
      expect(
        svc.confirmTwoFactorReset(
          baseUrl: 'https://ninja.example.com',
          isHosted: false,
          email: 'user@example.com',
          code: '000000',
        ),
        throwsA(isA<ServerException>()),
      );
    });

    test('an unknown address (422) raises a ValidationException', () {
      final svc = serviceReturning(
        json({
          'message': 'The selected email is invalid.',
          'errors': {
            'email': ['The selected email is invalid.'],
          },
        }, 422),
      );
      expect(
        svc.confirmTwoFactorReset(
          baseUrl: 'https://ninja.example.com',
          isHosted: false,
          email: 'nobody@example.com',
          code: '123456',
        ),
        throwsA(isA<ValidationException>()),
      );
    });
  });

  // The login screen waits on these with every control locked, so each is
  // bounded — production's plain `http.Client()` has no timeout of its own.
  group('interactive timeouts', () {
    Future<void> expectTimesOut(
      WidgetTester tester,
      Future<Object?> Function(AuthService svc) call,
    ) async {
      final never = Completer<http.Response>();
      final svc = AuthService(httpClient: MockClient((_) => never.future));
      Object? error;
      unawaited(call(svc).then<void>((_) {}, onError: (Object e) => error = e));

      await tester.pump(
        AuthService.interactiveTimeout - const Duration(seconds: 1),
      );
      expect(error, isNull);
      await tester.pump(const Duration(seconds: 2));
      expect(
        error,
        isA<NetworkException>().having(
          (e) => e.message,
          'message',
          'Request timed out after ${AuthService.interactiveTimeout.inSeconds}s',
        ),
      );
    }

    testWidgets('recoverPassword ("Forgot your password?")', (tester) async {
      await expectTimesOut(
        tester,
        (svc) => svc.recoverPassword(
          baseUrl: 'https://ninja.example.com',
          isHosted: false,
          email: 'user@example.com',
        ),
      );
    });

    testWidgets('confirmTwoFactorReset', (tester) async {
      await expectTimesOut(
        tester,
        (svc) => svc.confirmTwoFactorReset(
          baseUrl: 'https://ninja.example.com',
          isHosted: false,
          email: 'user@example.com',
          code: '123456',
        ),
      );
    });
  });
}
