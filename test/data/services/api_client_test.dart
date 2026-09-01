import 'dart:async';
import 'dart:convert';

import 'package:admin/app/version.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:logging/logging.dart';

/// Helpers — these tests target ApiClient's behavioral contract, not http or
/// Drift. Each test exercises an invariant that other layers (sync engine,
/// UI, repositories) rely on.

ValueListenable<ApiCredentials?> _creds([ApiCredentials? c]) =>
    ValueNotifier<ApiCredentials?>(
      c ?? const ApiCredentials(baseUrl: 'https://test', token: 't'),
    );

void main() {
  group('ApiClient 401 handling', () {
    test(
      'single-flight: parallel 401s call onUnauthorized exactly once',
      () async {
        var unauthorizedCalls = 0;
        final fake = MockClient((_) async => http.Response('nope', 401));

        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {
            unauthorizedCalls++;
            // Simulate slow logout work (token wipe, navigation, etc.).
            await Future<void>.delayed(const Duration(milliseconds: 50));
          },
          httpClient: fake,
        );

        // Fire 5 parallel calls that will all 401.
        final results = await Future.wait([
          for (var i = 0; i < 5; i++)
            client.getOne('/api/v1/x').catchError((_) => null),
        ]);

        expect(results.length, 5);
        expect(
          unauthorizedCalls,
          1,
          reason: 'parallel 401s must coalesce into a single logout',
        );
      },
    );

    test('stale-credential 401 does not trigger logout', () async {
      // Regression: switching companies while a request is in-flight used
      // to drop the user back to /login. The request goes out under the
      // old company's token; if the server 401s, that 401 says nothing
      // about whether the *current* session is still valid.
      var unauthorizedCalls = 0;
      final credentials = ValueNotifier<ApiCredentials?>(
        const ApiCredentials(baseUrl: 'https://test', token: 'old-token'),
      );
      final client = ApiClient(
        credentials: credentials,
        passwordCache: PasswordCache(),
        onUnauthorized: () async => unauthorizedCalls++,
        httpClient: MockClient((_) async {
          // Simulate the company switch happening mid-flight: swap the
          // listenable to a different token before the 401 response is
          // processed.
          credentials.value = const ApiCredentials(
            baseUrl: 'https://test',
            token: 'new-token',
          );
          return http.Response('nope', 401);
        }),
      );

      await expectLater(
        client.getOne('/api/v1/x'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(
        unauthorizedCalls,
        0,
        reason: 'a 401 against a now-replaced token must not force logout',
      );
    });

    test(
      'logout cache resets so a second session can trigger a fresh logout',
      () async {
        // Regression: `_logoutFuture ??=` used to stick forever, swallowing
        // 401s in later sessions after re-login.
        var unauthorizedCalls = 0;
        final fake = MockClient((_) async => http.Response('nope', 401));
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async => unauthorizedCalls++,
          httpClient: fake,
        );

        // Session 1: 401 logs us out.
        await client.getOne('/api/v1/x').catchError((_) => null);
        // Simulate the user re-logging in (a new request after the logout
        // future has resolved). The next 401 must trigger onUnauthorized
        // again — it's a different session.
        await Future<void>.delayed(Duration.zero);
        await client.getOne('/api/v1/x').catchError((_) => null);

        expect(unauthorizedCalls, 2);
      },
    );
  });

  group('ApiClient 401 veto (onUnauthorizedCandidate)', () {
    // The company-switch remedy: a 401 under a token the user just switched
    // into must fail the SWITCH, not the session. `ApiClient` delegates that
    // call to the auth layer through the veto; these tests pin the seam.

    test('veto returning false suppresses logout but still throws', () async {
      var unauthorizedCalls = 0;
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async => unauthorizedCalls++,
        onUnauthorizedCandidate: (_) async => false,
        httpClient: MockClient((_) async => http.Response('nope', 401)),
      );

      // Still throws: the outbox drain relies on the exception to unwind and
      // clear its `_inFlight` slot (see the self-deadlock comment in
      // `_postFlight`), so absorbing the 401 must not swallow the throw.
      await expectLater(
        client.getOne('/api/v1/x'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(unauthorizedCalls, 0);
    });

    test('veto returning true still logs out', () async {
      var unauthorizedCalls = 0;
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async => unauthorizedCalls++,
        onUnauthorizedCandidate: (_) async => true,
        httpClient: MockClient((_) async => http.Response('nope', 401)),
      );

      await client.getOne('/api/v1/x').catchError((_) => null);
      expect(unauthorizedCalls, 1);
    });

    test('a null veto preserves the default behavior', () async {
      // Pins that the ~33 existing ApiClient construction sites are unaffected.
      var unauthorizedCalls = 0;
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async => unauthorizedCalls++,
        httpClient: MockClient((_) async => http.Response('nope', 401)),
      );

      await client.getOne('/api/v1/x').catchError((_) => null);
      expect(unauthorizedCalls, 1);
    });

    test('a throwing veto falls through to logout (fail-safe)', () async {
      // Absorbing a 401 must be an affirmative decision, never a side effect
      // of an error — otherwise a keychain write failure inside the remedy
      // would strand the app authenticated with a token the server rejects.
      var unauthorizedCalls = 0;
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async => unauthorizedCalls++,
        onUnauthorizedCandidate: (_) async => throw StateError('keychain'),
        httpClient: MockClient((_) async => http.Response('nope', 401)),
      );

      await client.getOne('/api/v1/x').catchError((_) => null);
      expect(unauthorizedCalls, 1);
    });

    test('parallel 401s consult the veto exactly once', () async {
      // Load-bearing, not an optimization: a rejected company token is
      // discovered by a ~14-request prefetch fan-out, so many 401s land within
      // milliseconds. If each re-entered the veto, the second would undo the
      // first one's rollback.
      var vetoCalls = 0;
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        onUnauthorizedCandidate: (_) async {
          vetoCalls++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return false;
        },
        httpClient: MockClient((_) async => http.Response('nope', 401)),
      );

      await Future.wait([
        for (var i = 0; i < 5; i++)
          client.getOne('/api/v1/x').catchError((_) => null),
      ]);

      expect(vetoCalls, 1);
    });

    test('the veto receives the requesting company id', () async {
      // Asserts `companyId` survives _send -> _postFlight -> _handleUnauthorized.
      String? seen;
      final client = ApiClient(
        credentials: _creds(
          const ApiCredentials(
            baseUrl: 'https://test',
            token: 't',
            companyId: 'co_b',
          ),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        onUnauthorizedCandidate: (creds) async {
          seen = creds.companyId;
          return false;
        },
        httpClient: MockClient((_) async => http.Response('nope', 401)),
      );

      await client.getOne('/api/v1/x').catchError((_) => null);
      expect(seen, 'co_b');
    });

    test('a 2xx reports the proven credentials', () async {
      // Backs `AuthRepository.markCredentialProven`, which retires probation.
      final proven = <String>[];
      final client = ApiClient(
        credentials: _creds(
          const ApiCredentials(
            baseUrl: 'https://test',
            token: 't',
            companyId: 'co_a',
          ),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        onAuthenticatedResponse: (creds) => proven.add(creds.companyId),
        httpClient: MockClient((_) async => http.Response('{"data":{}}', 200)),
      );

      await client.getOne('/api/v1/x');
      expect(proven, ['co_a']);
    });

    test('a 401 does not report proven credentials', () async {
      final proven = <String>[];
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        onAuthenticatedResponse: (creds) => proven.add(creds.companyId),
        httpClient: MockClient((_) async => http.Response('nope', 401)),
      );

      await client.getOne('/api/v1/x').catchError((_) => null);
      expect(proven, isEmpty);
    });
  });

  group('ApiClient 401 diagnostics', () {
    // The forced-logout branch used to log NOTHING, so the only involuntary
    // session-ending path in the app left no trace in the WARNING+ diagnostics
    // log — it surfaced only as the unattributable downstream failures of
    // whatever ran next. These pin the log line and its redaction.

    late List<LogRecord> records;
    late StreamSubscription<LogRecord> sub;

    setUp(() {
      records = [];
      sub = Logger.root.onRecord.listen(records.add);
    });

    tearDown(() => sub.cancel());

    test('a forced logout logs method, path and company at WARNING', () async {
      final client = ApiClient(
        credentials: _creds(
          const ApiCredentials(
            baseUrl: 'https://test',
            token: 'secret-token-value',
            companyId: 'co_a',
          ),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: MockClient(
          (_) async => http.Response('{"message":"Invalid token"}', 401),
        ),
      );

      await client.getOne('/api/v1/clients').catchError((_) => null);

      final warning = records.firstWhere(
        (r) => r.level >= Level.WARNING && r.message.contains('forced logout'),
      );
      expect(warning.message, contains('GET'));
      expect(warning.message, contains('/api/v1/clients'));
      expect(warning.message, contains('co_a'));
      expect(warning.message, contains('Invalid token'));
      // The token itself must never reach the log — only a fingerprint.
      expect(warning.message, isNot(contains('secret-token-value')));
    });

    test('a stale-credential 401 stays below WARNING', () async {
      // Deliberate: switch-race noise must stay off the on-disk log.
      final credentials = ValueNotifier<ApiCredentials?>(
        const ApiCredentials(baseUrl: 'https://test', token: 'old'),
      );
      final client = ApiClient(
        credentials: credentials,
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: MockClient((_) async {
          credentials.value = const ApiCredentials(
            baseUrl: 'https://test',
            token: 'new',
          );
          return http.Response('nope', 401);
        }),
      );

      await client.getOne('/api/v1/x').catchError((_) => null);

      expect(
        records.where((r) => r.level >= Level.WARNING),
        isEmpty,
        reason: 'a stale-credential 401 is an expected race, not a defect',
      );
    });
  });

  group('ApiClient mutation headers', () {
    test('mutate forwards the caller-supplied Idempotency-Key', () async {
      String? captured;
      final fake = MockClient((req) async {
        captured = req.headers['Idempotency-Key'];
        return http.Response('{}', 200);
      });
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );

      await client.mutate(
        method: 'POST',
        path: '/api/v1/clients',
        idempotencyKey: 'idem-abc',
        body: {'name': 'A'},
      );
      expect(captured, 'idem-abc');
    });

    test('hosted creds inject X-API-SECRET; self-hosted does not', () async {
      String? hostedSecret;
      String? selfHostedSecret;
      final fake = MockClient((req) async {
        if (req.url.host == 'hosted') {
          hostedSecret = req.headers['X-API-SECRET'];
        } else {
          selfHostedSecret = req.headers['X-API-SECRET'];
        }
        return http.Response('{}', 200);
      });

      final hosted = ApiClient(
        credentials: _creds(
          const ApiCredentials(
            baseUrl: 'https://hosted',
            token: 't',
            apiSecret: 'shh',
            isHosted: true,
          ),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      final selfHosted = ApiClient(
        credentials: _creds(
          const ApiCredentials(baseUrl: 'https://my-ninja', token: 't'),
        ),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );

      await hosted.getOne('/api/v1/x');
      await selfHosted.getOne('/api/v1/x');

      expect(hostedSecret, 'shh');
      expect(selfHostedSecret, isNull);
    });

    test(
      'X-API-PASSWORD-BASE64 is added when requiresPassword=true and cache is set',
      () async {
        String? captured;
        final fake = MockClient((req) async {
          captured = req.headers['X-API-PASSWORD-BASE64'];
          return http.Response('{}', 200);
        });
        final cache = PasswordCache()..set('hunter2');
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: cache,
          onUnauthorized: () async {},
          httpClient: fake,
        );

        await client.mutate(
          method: 'DELETE',
          path: '/api/v1/clients/a',
          idempotencyKey: 'k',
          requiresPassword: true,
        );
        expect(captured, base64Encode(utf8.encode('hunter2')));
      },
    );

    test(
      'requiresPassword + empty cache throws PasswordRequired before any HTTP call',
      () async {
        var calls = 0;
        final fake = MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        });
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );

        await expectLater(
          () => client.mutate(
            method: 'DELETE',
            path: '/api/v1/clients/a',
            idempotencyKey: 'k',
            requiresPassword: true,
          ),
          throwsA(isA<PasswordRequiredException>()),
        );
        expect(calls, 0, reason: 'must not hit the network without a password');
      },
    );
  });

  group('ApiClient error mapping', () {
    test('422 surfaces field-level errors for inline form display', () async {
      final fake = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'Validation failed',
            'errors': {
              'email': ['Must be unique'],
              'name': ['Required'],
            },
          }),
          422,
          headers: {'content-type': 'application/json'},
        ),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );

      try {
        await client.mutate(
          method: 'POST',
          path: '/api/v1/clients',
          idempotencyKey: 'k',
          body: {},
        );
        fail('expected ValidationException');
      } on ValidationException catch (e) {
        expect(e.fieldErrors['email'], ['Must be unique']);
        expect(e.fieldErrors['name'], ['Required']);
      }
    });

    test('429 with Retry-After header carries the wait duration', () async {
      final fake = MockClient(
        (_) async => http.Response('{}', 429, headers: {'retry-after': '7'}),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );

      try {
        await client.getOne('/api/v1/x');
        fail('expected RateLimitedException');
      } on RateLimitedException catch (e) {
        expect(e.retryAfter, const Duration(seconds: 7));
      }
    });

    test(
      '409 produces ConflictException so the sync engine can surface it',
      () async {
        final fake = MockClient((_) async => http.Response('{}', 409));
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );
        await expectLater(
          () => client.getOne('/api/v1/x'),
          throwsA(isA<ConflictException>()),
        );
      },
    );

    test('a 400 "No query results for model" produces NotFoundException — that '
        'is how Invoice Ninja reports a missing entity (Handler.php renders '
        'ModelNotFoundException as 400, not 404). Without this mapping the '
        'outbox row dies silently instead of reaching the '
        'ConflictResolutionSheet.', () async {
      final fake = MockClient(
        (_) async => http.Response(
          '{"message":"No query results for model '
          '[App\\\\Models\\\\Quote] 7Xk2"}',
          400,
        ),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      await expectLater(
        () => client.getOne('/api/v1/x'),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('a 400 "Record is deleted and cannot be edited" produces '
        'RecordDeletedException — the server refuses to edit a soft-deleted '
        'record and names the remedy (restore it), so the failure surface can '
        'show that instead of a Retry that fails forever.', () async {
      final fake = MockClient(
        (_) async => http.Response(
          '{"message":"Record is deleted and cannot be edited. Restore '
          'the record to enable editing"}',
          400,
        ),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      await expectLater(
        () => client.getOne('/api/v1/x'),
        throwsA(isA<RecordDeletedException>()),
      );
    });

    test('a plain 400 stays a ServerException — only the two recognised bodies '
        'get special treatment.', () async {
      final fake = MockClient(
        (_) async => http.Response('{"message":"Bad request"}', 400),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      await expectLater(
        () => client.getOne('/api/v1/x'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having(
                (e) => e,
                'not a conflict',
                isNot(isA<ConflictException>()),
              ),
        ),
      );
    });

    test(
      'a bare 404 is a plain ServerException, NOT NotFoundException. Invoice '
      'Ninja emits 404 only for "Route does not exist" / "Method not '
      'supported for this route" — i.e. the client built a bad URL or verb. '
      'Mapping that to "deleted server-side" told the user their record was '
      'gone and, on the sheet\'s only forward option, hard-deleted the local '
      'row (invoiceninja/flutter#36).',
      () async {
        final fake = MockClient(
          (_) async => http.Response('{"message":"Route does not exist"}', 404),
        );
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );
        await expectLater(
          () => client.getOne('/api/v1/x'),
          throwsA(
            isA<ServerException>()
                .having((e) => e.statusCode, 'statusCode', 404)
                .having(
                  (e) => e,
                  'not a conflict',
                  isNot(isA<ConflictException>()),
                ),
          ),
        );
      },
    );

    test(
      '3xx redirect is rejected as a server error — without this guard '
      'the default http.Client follows the Location header and resends '
      'the X-API-Token / X-API-PASSWORD-BASE64 headers to the redirect '
      'target, which is a token-leak vector if the target is hostile.',
      () async {
        var redirectFollowed = false;
        final fake = MockClient((req) async {
          if (req.url.host == 'attacker.example.com') {
            redirectFollowed = true;
            return http.Response('caught', 200);
          }
          return http.Response(
            '',
            302,
            headers: {'location': 'https://attacker.example.com/steal'},
          );
        });
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );
        await expectLater(
          () => client.getOne('/api/v1/x'),
          throwsA(isA<ServerException>()),
        );
        expect(
          redirectFollowed,
          isFalse,
          reason: 'must not chase the Location header',
        );
      },
    );

    test('412 produces PasswordRequiredException', () async {
      // The IN server signals password-protected routes with 412 +
      // {"message":"Invalid Password","errors":{}}. The sync engine and
      // shell pattern-match on PasswordRequiredException to open the
      // ConfirmPasswordSheet, so the mapping has to be exact regardless
      // of the response body's message wording.
      final fake = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'Invalid Password',
            'errors': <String, dynamic>{},
          }),
          412,
          headers: {'content-type': 'application/json'},
        ),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      await expectLater(
        () => client.getOne('/api/v1/users/abc'),
        throwsA(isA<PasswordRequiredException>()),
      );
    });

    test('402 Payment Required produces PlanRequiredException', () async {
      // RFC 7231 status code — the cleanest signal for plan-gated
      // endpoints. The sync engine pattern-matches on the typed
      // exception to mark dead (retrying won't upgrade the account).
      final fake = MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Upgrade to access this endpoint'}),
          402,
          headers: {'content-type': 'application/json'},
        ),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      await expectLater(
        () => client.getOne('/api/v1/reports/profitloss'),
        throwsA(isA<PlanRequiredException>()),
      );
    });

    test(
      '403 with error_type=plan_required produces PlanRequiredException',
      () async {
        // Parallel to the password sniff above: a structured signal in
        // the body lets the server distinguish "wrong plan tier" from
        // generic 403 without changing the status code.
        final fake = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'message': 'Premium feature',
              'error_type': 'plan_required',
            }),
            403,
            headers: {'content-type': 'application/json'},
          ),
        );
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );
        await expectLater(
          () => client.getOne('/api/v1/reports/profitloss'),
          throwsA(isA<PlanRequiredException>()),
        );
      },
    );

    test('403 with error_type=password still produces '
        'PasswordRequiredException (password sniff wins over the '
        'plan_required check)', () async {
      final fake = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'Password required',
            'error_type': 'password_protected',
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      await expectLater(
        () => client.getOne('/api/v1/users/abc'),
        throwsA(isA<PasswordRequiredException>()),
      );
    });

    test('401 with error_type=plan_required produces PlanRequiredException, '
        'not UnauthorizedException', () async {
      // Defensive: a 401 carrying the structured plan signal must NOT
      // trigger the unauthorized-logout machinery. Use matching active
      // credentials so the 401 isn't swallowed as a stale-credential
      // discard.
      const creds = ApiCredentials(
        baseUrl: 'https://test',
        token: 'plan-token',
      );
      final fake = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'Upgrade required',
            'error_type': 'plan_required',
          }),
          401,
          headers: {'content-type': 'application/json'},
        ),
      );
      var loggedOut = false;
      final client = ApiClient(
        credentials: _creds(creds),
        passwordCache: PasswordCache(),
        onUnauthorized: () async => loggedOut = true,
        httpClient: fake,
      );
      await expectLater(
        () => client.getOne('/api/v1/reports/profitloss'),
        throwsA(isA<PlanRequiredException>()),
      );
      // The plan-required path short-circuits before the unauthorized
      // handler fires — confirm we didn't trigger logout.
      expect(loggedOut, isFalse);
    });
  });

  group('ApiClient postRaw content-type validation', () {
    Future<void> expectAccepts(String contentType) async {
      final fake = MockClient(
        (_) async => http.Response.bytes(
          [1, 2, 3, 4],
          200,
          headers: {'content-type': contentType},
        ),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      final bytes = await client.postRaw('/api/v1/x', readOnly: true);
      expect(bytes, [1, 2, 3, 4]);
    }

    Future<void> expectRejects(String contentType) async {
      final fake = MockClient(
        (_) async => http.Response(
          'not a pdf',
          200,
          headers: {'content-type': contentType},
        ),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      await expectLater(
        () => client.postRaw('/api/v1/x', readOnly: true),
        throwsA(isA<ServerException>()),
      );
    }

    test(
      'accepts plain application/pdf',
      () => expectAccepts('application/pdf'),
    );
    test(
      'accepts application/pdf with charset parameter (legitimate server)',
      () => expectAccepts('application/pdf; charset=utf-8'),
    );
    test(
      'rejects application/pdf-forged — the old startsWith check passed this '
      'because the prefix matched, letting a hostile server label HTML/JS '
      'as a PDF and trick a downstream renderer.',
      () => expectRejects('application/pdf-forged'),
    );
    test('rejects text/html', () => expectRejects('text/html; charset=utf-8'));
    test('rejects missing content-type header', () async {
      // No headers at all — exercises the `?? ''` default in postRaw.
      final fake = MockClient((_) async => http.Response('not a pdf', 200));
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      await expectLater(
        () => client.postRaw('/api/v1/x', readOnly: true),
        throwsA(isA<ServerException>()),
      );
    });
  });

  group('ApiClient version negotiation', () {
    test(
      'x-minimum-client-version greater than ours throws ClientTooOldException',
      () async {
        final bumped = _bumpMinor(
          AppVersion.kClientVersion,
          by: 5,
        ); // > current
        final fake = MockClient(
          (_) async => http.Response(
            '{}',
            200,
            headers: {'x-minimum-client-version': bumped},
          ),
        );
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );

        await expectLater(
          () => client.getOne('/api/v1/x'),
          throwsA(isA<ClientTooOldException>()),
        );
      },
    );

    test(
      'onClientTooOld is invoked with min+current so the router can redirect',
      () async {
        final bumped = _bumpMinor(AppVersion.kClientVersion, by: 5);
        ({String minRequired, String current})? reported;
        final fake = MockClient(
          (_) async => http.Response(
            '{}',
            200,
            headers: {'x-minimum-client-version': bumped},
          ),
        );
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          onClientTooOld: (info) => reported = info,
          httpClient: fake,
        );

        await client.getOne('/api/v1/x').catchError((_) => null);
        expect(reported, isNotNull);
        expect(reported!.minRequired, bumped);
        expect(reported!.current, AppVersion.kClientVersion);
      },
    );

    test(
      'x-app-version is reported to onServerVersion for the diagnostics screen',
      () async {
        String? reported;
        final fake = MockClient(
          (_) async => http.Response(
            '{"data": {}}',
            200,
            headers: {'x-app-version': '5.12.34'},
          ),
        );
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          onServerVersion: (v) => reported = v,
          httpClient: fake,
        );

        await client.getOne('/api/v1/x');
        expect(reported, '5.12.34');
      },
    );
  });

  group('PasswordCache', () {
    test('expires after the configured TTL', () {
      var now = DateTime(2026, 1, 1, 12);
      final cache = PasswordCache(
        ttl: const Duration(minutes: 5),
        now: () => now,
      )..set('s3cret');
      expect(cache.read(), 's3cret');

      now = now.add(const Duration(minutes: 4));
      expect(cache.read(), 's3cret');

      now = now.add(const Duration(minutes: 2));
      expect(cache.read(), isNull, reason: 'TTL elapsed → cache must drop');
    });
  });

  group('ApiClient list cursor sanitisation', () {
    test(
      'far-future updated_at is dropped instead of poisoning the next page',
      () async {
        // Regression for H3: a malformed/malicious row could put `updated_at`
        // in year 9999, which the next list call would send as the cursor
        // and silently skip every subsequent row server-side.
        final fake = MockClient(
          (_) async => http.Response(
            jsonEncode({
              'data': [
                {'id': 'a', 'updated_at': 99999999999}, // ~year 5138
              ],
            }),
            200,
          ),
        );
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );

        final result = await client.getList('/api/v1/clients', page: 1);
        expect(result.cursorUpdatedAt, isNull);
        expect(
          result.cursorId,
          'a',
        ); // id still surfaces so caller can fall back
      },
    );

    test('negative updated_at is dropped', () async {
      final fake = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              {'id': 'a', 'updated_at': -1},
            ],
          }),
          200,
        ),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );

      final result = await client.getList('/api/v1/clients', page: 1);
      expect(result.cursorUpdatedAt, isNull);
    });

    test('valid updated_at passes through', () async {
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final fake = MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              {'id': 'a', 'updated_at': ts},
            ],
          }),
          200,
        ),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );

      final result = await client.getList('/api/v1/clients', page: 1);
      expect(result.cursorUpdatedAt, ts);
    });
  });

  group('ApiClient decode timeout', () {
    test(
      'a never-completing decode raises NetworkException via the timeout',
      () async {
        // Regression for H4: a pathological JSON payload (deeply nested,
        // multi-MB) used to be able to hang the worker isolate forever —
        // the calling list view spun with no signal to the user.
        final fake = MockClient(
          (_) async => http.Response('{"data": []}', 200),
        );
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
          decoder: (_) => Completer<dynamic>().future, // never completes
          decodeTimeout: const Duration(milliseconds: 20),
        );

        await expectLater(
          () => client.getOne('/api/v1/x'),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test(
      'a small body decodes inline via the default decoder (no isolate hop)',
      () async {
        // The sidebar-prefetch storm fix: small bodies skip the compute()
        // isolate when the default decoder is in use. Pin the functional
        // result so the inline `_decodeJson` branch stays correct. No
        // `decoder:` override → exercises `identical(_decoder, _default)`.
        final fake = MockClient(
          (_) async => http.Response('{"data": {"id": "abc"}}', 200),
        );
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
          // Tiny timeout: if the inline path were NOT taken this would have
          // to round-trip a real compute() isolate; the assertion that we
          // still get the parsed map proves the synchronous short-circuit.
          decodeTimeout: const Duration(milliseconds: 1),
        );

        final res = await client.getOne('/api/v1/x');
        expect((res as Map)['data'], {'id': 'abc'});
      },
    );
  });

  group('Phase 17 — 500 with non-JSON body surfaces in ServerException', () {
    test(
      'HTML / stack-trace body is sampled into ServerException.message',
      () async {
        const stackTrace =
            '<html><body>'
            'PHP Fatal Error: Call to undefined method '
            'DesignProcessor::renderBlocks() in '
            '/var/www/html/app/Services/DesignProcessor.php:142'
            '</body></html>';
        final fake = MockClient(
          (_) async => http.Response(
            stackTrace,
            500,
            headers: {'content-type': 'text/html; charset=utf-8'},
            reasonPhrase: 'Internal Server Error',
          ),
        );
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );
        try {
          await client.getOne('/api/v1/preview');
          fail('expected ServerException');
        } on ServerException catch (e) {
          expect(e.statusCode, 500);
          // Reason phrase prefix preserved.
          expect(e.message, contains('Internal Server Error'));
          // The PHP error inside the HTML body is surfaced inline.
          expect(e.message, contains('undefined method'));
          expect(e.message, contains('DesignProcessor::renderBlocks'));
        }
      },
    );

    test(
      'JSON {"message": "..."} 500 keeps the old behaviour (no body sample)',
      () async {
        final fake = MockClient(
          (_) async => http.Response(
            jsonEncode({'message': 'Database temporarily unavailable'}),
            500,
            headers: {'content-type': 'application/json'},
            reasonPhrase: 'Internal Server Error',
          ),
        );
        final client = ApiClient(
          credentials: _creds(),
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fake,
        );
        try {
          await client.getOne('/api/v1/x');
          fail('expected ServerException');
        } on ServerException catch (e) {
          expect(e.message, 'Database temporarily unavailable');
          // We don't append a HTML/body sample when JSON already carried
          // a clean message — banner stays concise.
          expect(e.message, isNot(contains('Internal Server Error')));
        }
      },
    );

    test('huge HTML body is truncated to ~240 chars in the message', () async {
      final huge = 'X' * 10000;
      final fake = MockClient(
        (_) async => http.Response(
          huge,
          500,
          headers: {'content-type': 'text/html'},
          reasonPhrase: 'Internal Server Error',
        ),
      );
      final client = ApiClient(
        credentials: _creds(),
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fake,
      );
      try {
        await client.getOne('/api/v1/x');
        fail('expected ServerException');
      } on ServerException catch (e) {
        // Reason phrase + " — " + first 240 chars + "…" = bounded length.
        // Anything under 500 keeps the banner usable.
        expect(e.message.length, lessThan(500));
        expect(e.message, endsWith('…'));
      }
    });
  });
}

/// Bump the minor version by [by] — used to fabricate a server-required
/// version that's strictly greater than our compile-time constant.
String _bumpMinor(String semver, {int by = 1}) {
  final parts = semver.split('-').first.split('.');
  final minor = int.parse(parts[1]) + by;
  return '${parts[0]}.$minor.0';
}
