import 'dart:async';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/ui/features/auth/view_models/login_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Self-hosted URL validation. Without this, the login VM accepts any string
/// as a base URL and posts the user's password to it. Hosted builds short-
/// circuit (URL is a compile-time const) so we only exercise the self-hosted
/// branch here.

class _FakeAuthService implements AuthService {
  @override
  Future<LoginResponseApi> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
    String? secret,
  }) async {
    // If this is ever hit, the URL validation let something through that
    // shouldn't have made it to the network layer.
    fail('login should not be called when URL validation rejects');
  }

  @override
  Future<void> recoverPassword({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) async {
    fail('recover should not be called when URL validation rejects');
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Records the base URL the VM resolved, then throws to stop before
/// [AuthRepository._persistAndActivate] runs (so no full login round-trip /
/// DB writes). Used to assert scheme normalization at the service boundary.
class _CapturingAuthService implements AuthService {
  String? capturedBaseUrl;
  String? capturedSecret;

  @override
  Future<LoginResponseApi> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
    String? secret,
  }) async {
    capturedBaseUrl = baseUrl;
    capturedSecret = secret;
    throw const NetworkException('captured');
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Scripted service for the two-step flow: a canned `/login/precheck` answer
/// (or error), optionally held open by [gate] so a test can act while the
/// request is still in flight; a `login` that records what it was sent and
/// then throws [loginError] (never succeeding, so no `_persistAndActivate`);
/// and the SMS-reset pair.
class _ScriptedAuthService implements AuthService {
  _ScriptedAuthService({
    this.result,
    this.precheckError,
    this.gate,
    this.loginGate,
    this.loginError = const NetworkException('captured'),
    this.resetError,
  });

  final LoginPrecheck? result;
  final Object? precheckError;
  final Completer<void>? gate;
  final Completer<void>? loginGate;
  final Object loginError;

  /// Thrown by both SMS-reset calls when set.
  final Object? resetError;

  /// Set mid-test to make later SMS-reset calls throw.
  Object? resetErrorOverride;

  int calls = 0;
  int loginCalls = 0;
  int recoverCalls = 0;
  String? loginOtp;
  String? loginSecret;
  final resetEmails = <String>[];

  @override
  Future<LoginPrecheck?> precheck({
    required String baseUrl,
    required bool isHosted,
    required String email,
  }) async {
    calls++;
    if (gate != null) await gate!.future;
    if (precheckError != null) throw precheckError!;
    return result;
  }

  @override
  Future<LoginResponseApi> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
    String? secret,
  }) async {
    loginCalls++;
    loginOtp = oneTimePassword;
    loginSecret = secret;
    if (loginGate != null) await loginGate!.future;
    throw loginError;
  }

  @override
  Future<void> recoverPassword({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) async {
    recoverCalls++;
  }

  @override
  Future<String?> sendTwoFactorResetCode({
    required String baseUrl,
    required bool isHosted,
    required String email,
  }) async {
    resetEmails.add(email);
    final error = resetErrorOverride ?? resetError;
    if (error != null) throw error;
    return 'Code sent.';
  }

  @override
  Future<String?> confirmTwoFactorReset({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String code,
  }) async {
    resetEmails.add(email);
    final error = resetErrorOverride ?? resetError;
    if (error != null) throw error;
    return 'SMS verified, 2FA disabled.';
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late AuthRepository auth;
  late LoginViewModel vm;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    auth = AuthRepository(
      db: db,
      authService: _FakeAuthService(),
      tokenStorage: InMemoryTokenStorage(),
      passwordCache: PasswordCache(),
    );
    vm = LoginViewModel(auth: auth);
    vm.setHosted(false);
    vm.setEmail('a@b.test');
    vm.setPassword('pw');
  });
  tearDown(() async {
    await db.close();
  });

  group('self-hosted base URL validation', () {
    test('rejects empty URL', () async {
      vm.setUrlOverride('');
      expect(await vm.submit(), isFalse);
      expect(vm.errorKey, 'invalid_url');
    });

    test('rejects URL with embedded credentials', () async {
      vm.setUrlOverride('https://user:pw@host.example');
      expect(await vm.submit(), isFalse);
      expect(vm.errorKey, 'invalid_url');
    });

    test('rejects URL with empty host', () async {
      vm.setUrlOverride('https://');
      expect(await vm.submit(), isFalse);
      expect(vm.errorKey, 'invalid_url');
    });

    test('rejects garbage that does not parse as a URL', () async {
      vm.setUrlOverride('::: not a url :::');
      expect(await vm.submit(), isFalse);
      expect(vm.errorKey, 'invalid_url');
    });

    test('recover() applies the same validation', () async {
      vm.setUrlOverride('');
      expect(await vm.recover(), isFalse);
      expect(vm.errorKey, 'invalid_url');
    });
  });

  group('self-hosted base URL normalization', () {
    // Build a VM whose AuthRepository talks to a capturing service, so we can
    // assert the exact base URL the VM resolved (post scheme-normalization).
    LoginViewModel vmWith(_CapturingAuthService svc) {
      final repo = AuthRepository(
        db: db,
        authService: svc,
        tokenStorage: InMemoryTokenStorage(),
        passwordCache: PasswordCache(),
      );
      return LoginViewModel(auth: repo)
        ..setHosted(false)
        ..setEmail('a@b.test')
        ..setPassword('pw');
    }

    test('prepends https:// to a bare host', () async {
      final svc = _CapturingAuthService();
      final vm = vmWith(svc)..setUrlOverride('demo.invoiceninja.com');
      await vm.submit();
      expect(svc.capturedBaseUrl, 'https://demo.invoiceninja.com');
    });

    test('prepends https:// to a bare host:port', () async {
      final svc = _CapturingAuthService();
      final vm = vmWith(svc)..setUrlOverride('localhost:8000');
      await vm.submit();
      expect(svc.capturedBaseUrl, 'https://localhost:8000');
    });

    test('leaves an explicit https:// URL unchanged', () async {
      final svc = _CapturingAuthService();
      final vm = vmWith(svc)..setUrlOverride('https://demo.invoiceninja.com');
      await vm.submit();
      expect(svc.capturedBaseUrl, 'https://demo.invoiceninja.com');
    });

    test(
      'leaves an explicit http:// URL unchanged (debug allows http)',
      () async {
        final svc = _CapturingAuthService();
        final vm = vmWith(svc)..setUrlOverride('http://localhost:8000');
        await vm.submit();
        expect(svc.capturedBaseUrl, 'http://localhost:8000');
      },
    );

    test('forwards a typed API secret to the service', () async {
      final svc = _CapturingAuthService();
      final vm = vmWith(svc)
        ..setUrlOverride('https://self.hosted.test')
        ..setSecret('sek-123');
      await vm.submit();
      expect(svc.capturedSecret, 'sek-123');
    });

    test('sends no secret when the field is left blank', () async {
      final svc = _CapturingAuthService();
      final vm = vmWith(svc)..setUrlOverride('https://self.hosted.test');
      await vm.submit();
      expect(svc.capturedSecret, isNull);
    });
  });

  // kDebugMode is always true under `flutter test`, so the live VM can only
  // exercise the debug branch. Drive the pure policy function directly with the
  // dev escape-hatch off to assert the *release* behavior.
  group('resolveSelfHostedBaseUrl — release policy (http local-only)', () {
    ({String? url, String? errorKey}) check(String input) =>
        resolveSelfHostedBaseUrl(input, allowInsecureHttpAnywhere: false);

    test('allows http to local network addresses', () {
      expect(check('http://192.168.1.50:8080').url, 'http://192.168.1.50:8080');
      expect(check('http://10.0.0.5').url, 'http://10.0.0.5');
      expect(check('http://localhost:8000').url, 'http://localhost:8000');
      expect(check('http://nas.local:8000').url, 'http://nas.local:8000');
    });

    test('rejects http to a public host with a dedicated message', () {
      final r = check('http://example.com');
      expect(r.url, isNull);
      expect(r.errorKey, 'insecure_url_use_https');
    });

    test('https is always allowed; a bare host gets https://', () {
      expect(
        check('https://demo.invoiceninja.com').url,
        'https://demo.invoiceninja.com',
      );
      expect(
        check('demo.invoiceninja.com').url,
        'https://demo.invoiceninja.com',
      );
    });

    test('malformed input still reports invalid_url', () {
      expect(check('').errorKey, 'invalid_url');
      expect(check('https://').errorKey, 'invalid_url');
      expect(check('https://user:pw@host.example').errorKey, 'invalid_url');
    });
  });

  group('resolveSelfHostedBaseUrl — debug policy (http anywhere)', () {
    test('allows http to any host for local dev parity', () {
      final r = resolveSelfHostedBaseUrl(
        'http://example.com',
        allowInsecureHttpAnywhere: true,
      );
      expect(r.url, 'http://example.com');
      expect(r.errorKey, isNull);
    });
  });

  group('appleEnabled platform gate', () {
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('offered only where the native flow exists: iOS + macOS', () {
      for (final (platform, expected) in [
        (TargetPlatform.iOS, true),
        (TargetPlatform.macOS, true),
        // Android lacks webAuthenticationOptions wiring (plugin throws a
        // bare Exception); Windows/Linux are NotSupported by the plugin.
        (TargetPlatform.android, false),
        (TargetPlatform.windows, false),
        (TargetPlatform.linux, false),
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        expect(vm.appleEnabled, expected, reason: '$platform');
      }
    });

    test('submitApple is a no-op where the segment is hidden', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(await vm.submitApple(), isFalse);
    });
  });

  group('two-step flow', () {
    // Step 2 hides its optional TOTP / API-secret fields based on the
    // precheck, so the load-bearing rule is: only ever hide a field the server
    // has positively told us is unnecessary. No answer — an older server, a
    // rate limit — moves on with both visible. Only an unreachable server and
    // a rejected address keep the user on step 1.
    LoginViewModel vmWith(_ScriptedAuthService svc) {
      final repo = AuthRepository(
        db: db,
        authService: svc,
        tokenStorage: InMemoryTokenStorage(),
        passwordCache: PasswordCache(),
      );
      return LoginViewModel(auth: repo)
        ..setHosted(false)
        ..setUrlOverride('https://ninja.example.com')
        ..setEmail('a@b.test')
        ..setPassword('pw');
    }

    const passwordOnly = LoginPrecheck(
      methods: {'password'},
      secretRequired: false,
    );
    const totpAndSecret = LoginPrecheck(
      methods: {'password', 'totp'},
      secretRequired: true,
    );

    test('starts on the email step with every optional field assumed', () {
      final vm = vmWith(_ScriptedAuthService());
      expect(vm.step, LoginStep.email);
      expect(vm.showOtpField, isTrue);
      expect(vm.showSecretField, isTrue);
      expect(vm.otpConfirmed, isFalse);
      expect(vm.secretIsRequired, isFalse);
    });

    test(
      'an empty or @-less email is rejected inline, asking nothing',
      () async {
        final svc = _ScriptedAuthService(result: passwordOnly);
        for (final bad in ['', 'not-an-email']) {
          final vm = vmWith(svc)..setEmail(bad);
          expect(await vm.continueToCredentials(), isFalse);
          expect(vm.emailErrorKey, 'email_is_invalid');
          expect(vm.hasRequestError, isFalse, reason: 'inline, not a toast');
          expect(vm.step, LoginStep.email);
        }
        expect(svc.calls, 0);
      },
    );

    test('an invalid server URL is rejected inline, asking nothing', () async {
      final svc = _ScriptedAuthService(result: passwordOnly);
      final vm = vmWith(svc)..setUrlOverride('');
      expect(await vm.continueToCredentials(), isFalse);
      expect(vm.urlErrorKey, 'invalid_url');
      expect(vm.hasRequestError, isFalse);
      expect(svc.calls, 0);
      // Editing the URL clears it.
      vm.setUrlOverride('https://ninja.example.com');
      expect(vm.urlErrorKey, isNull);
    });

    test('no answer (older server) moves on with both fields', () async {
      final vm = vmWith(_ScriptedAuthService());
      expect(await vm.continueToCredentials(), isTrue);
      expect(vm.step, LoginStep.credentials);
      expect(vm.showOtpField, isTrue);
      expect(vm.showSecretField, isTrue);
      expect(vm.otpConfirmed, isFalse);
      expect(vm.secretIsRequired, isFalse);
    });

    test('a password-only account hides the OTP and secret fields', () async {
      final vm = vmWith(_ScriptedAuthService(result: passwordOnly));
      await vm.continueToCredentials();
      expect(vm.showOtpField, isFalse);
      expect(vm.showSecretField, isFalse);
    });

    test('totp + secret_required confirms both as required', () async {
      final vm = vmWith(_ScriptedAuthService(result: totpAndSecret));
      await vm.continueToCredentials();
      expect(vm.showOtpField, isTrue);
      expect(vm.otpConfirmed, isTrue);
      expect(vm.showSecretField, isTrue);
      expect(vm.secretIsRequired, isTrue);
    });

    test('a typed secret survives being hidden', () async {
      // A stale secret is ignored by a server with no API_SECRET
      // (ApiSecretCheck short-circuits); keeping it means switching back to a
      // secret-requiring URL restores the value.
      final vm = vmWith(_ScriptedAuthService(result: passwordOnly));
      vm.setSecret('s3cret');
      await vm.continueToCredentials();
      expect(vm.showSecretField, isFalse);
      expect(vm.secret, 's3cret');
    });

    test('an unreachable server stays on step 1 and is asked again', () async {
      final svc = _ScriptedAuthService(
        precheckError: const NetworkException('no route to host'),
      );
      final vm = vmWith(svc);
      expect(await vm.continueToCredentials(), isFalse);
      expect(vm.step, LoginStep.email);
      expect(vm.errorKey, 'network_error_with_message');
      // Not cached: a typo'd URL fixed in place must be re-asked.
      await vm.continueToCredentials();
      expect(svc.calls, 2);
    });

    test(
      'a 422 without an email error shows its message on the field',
      () async {
        final vm = vmWith(
          _ScriptedAuthService(
            precheckError: const ValidationException('Blocked domain', {}),
          ),
        );
        expect(await vm.continueToCredentials(), isFalse);
        expect(vm.step, LoginStep.email);
        expect(vm.fieldErrors['email'], ['Blocked domain']);
        expect(vm.hasRequestError, isFalse);
      },
    );

    test('a 422 with an email error keeps the server wording', () async {
      final vm = vmWith(
        _ScriptedAuthService(
          precheckError: const ValidationException('Invalid', {
            'email': ['The email must be a valid email address.'],
          }),
        ),
      );
      await vm.continueToCredentials();
      expect(vm.fieldErrors['email'], [
        'The email must be a valid email address.',
      ]);
    });

    test('an unexpected throw is caught and stays on step 1', () async {
      final vm = vmWith(_ScriptedAuthService(precheckError: StateError('x')));
      expect(await vm.continueToCredentials(), isFalse);
      expect(vm.step, LoginStep.email);
      expect(vm.hasRequestError, isTrue);
      expect(vm.busy, isFalse);
    });

    test(
      'Change keeps the email and secret, clears password and OTP',
      () async {
        final vm = vmWith(_ScriptedAuthService(result: totpAndSecret))
          ..setSecret('s3cret');
        await vm.continueToCredentials();
        vm
          ..setPassword('pw2')
          ..setOneTimePassword('123456');
        vm.backToEmail();
        expect(vm.step, LoginStep.email);
        expect(vm.email, 'a@b.test');
        expect(vm.secret, 's3cret');
        expect(vm.password, isEmpty);
        expect(vm.oneTimePassword, isEmpty);
      },
    );

    test(
      'Change → Continue on the same (server, email) is not re-asked',
      () async {
        // Hosted throttles /login/precheck at 4/min per IP.
        final svc = _ScriptedAuthService(result: passwordOnly);
        final vm = vmWith(svc);
        await vm.continueToCredentials();
        vm.backToEmail();
        expect(await vm.continueToCredentials(), isTrue);
        expect(svc.calls, 1);
        expect(vm.showOtpField, isFalse, reason: 'the cached answer applies');
      },
    );

    test('no answer is never cached — it may have been a 429', () async {
      // Hosted throttles the precheck at 4/min per IP. Caching that "no
      // answer" would keep this address on the optional-OTP fallback (and
      // hide Disable 2FA) until the user edited it.
      final svc = _ScriptedAuthService();
      final vm = vmWith(svc);
      await vm.continueToCredentials();
      vm.backToEmail();
      await vm.continueToCredentials();
      expect(svc.calls, 2);
    });

    // The answer is per (server, email): a stale one from a host with no
    // API_SECRET would hide the secret field of one that has it, leaving
    // nowhere to type the secret.
    test('editing the email, the URL or the platform re-asks', () async {
      final svc = _ScriptedAuthService(result: passwordOnly);
      final vm = vmWith(svc);
      await vm.continueToCredentials();

      vm
        ..backToEmail()
        ..setEmail('other@b.test');
      expect(vm.showOtpField, isTrue, reason: 'answer was for the old email');
      await vm.continueToCredentials();

      vm
        ..backToEmail()
        ..setUrlOverride('https://other.example.com');
      expect(vm.showSecretField, isTrue, reason: 'answer was for the old URL');
      await vm.continueToCredentials();

      vm
        ..backToEmail()
        ..setHosted(true)
        ..setHosted(false);
      await vm.continueToCredentials();
      expect(svc.calls, 4);
    });

    test(
      'an answer for a server switched away mid-flight is dropped',
      () async {
        final gate = Completer<void>();
        final svc = _ScriptedAuthService(result: passwordOnly, gate: gate);
        final vm = vmWith(svc);
        final pending = vm.continueToCredentials();
        vm.setUrlOverride('https://other.example.com');
        gate.complete();
        expect(await pending, isFalse);
        expect(vm.step, LoginStep.email);
        expect(vm.precheck, isNull);
        expect(vm.hasRequestError, isFalse, reason: 'nothing went wrong');
      },
    );

    test('Change does nothing while a login is in flight', () async {
      final loginGate = Completer<void>();
      final vm = vmWith(
        _ScriptedAuthService(result: passwordOnly, loginGate: loginGate),
      );
      await vm.continueToCredentials();
      final pending = vm.submit();
      expect(vm.busy, isTrue);

      vm.backToEmail();
      expect(
        vm.step,
        LoginStep.credentials,
        reason: 'a login landing after the user left step 2 would be lost',
      );

      loginGate.complete();
      await pending;
      vm.backToEmail();
      expect(vm.step, LoginStep.email);
    });

    test('disposing mid-flight does not notify a disposed notifier', () async {
      // The server pads its response to a 250 ms floor; the screen can be torn
      // down first. Notifying past dispose throws debugAssertNotDisposed.
      final gate = Completer<void>();
      final vm = vmWith(_ScriptedAuthService(result: passwordOnly, gate: gate));
      final pending = vm.continueToCredentials();
      vm.dispose();
      gate.complete();
      await expectLater(pending, completes);
    });

    group('required fields', () {
      test('an empty confirmed TOTP code is caught inline, not sent', () async {
        // The server answers a missing code with a 400 toast and spends one
        // of hosted's four login attempts a minute.
        final svc = _ScriptedAuthService(result: totpAndSecret);
        final vm = vmWith(svc);
        await vm.continueToCredentials();

        expect(await vm.submit(), isFalse);
        expect(vm.otpErrorKey, 'please_enter_a_value');
        expect(vm.hasRequestError, isFalse, reason: 'no toast on top');
        expect(svc.loginCalls, 0);

        vm.setOneTimePassword('123456');
        expect(vm.otpErrorKey, isNull, reason: 'typing answers the error');
        await vm.submit();
        expect(svc.loginCalls, 1);
        expect(svc.loginOtp, '123456');
      });

      test('an optional (unanswered) code never blocks', () async {
        final svc = _ScriptedAuthService();
        final vm = vmWith(svc);
        await vm.continueToCredentials();
        await vm.submit();
        expect(svc.loginCalls, 1);
        expect(vm.otpErrorKey, isNull);
      });

      test('a "required" secret is sent without one — never blocked', () async {
        // `secret_required` mirrors `config('ninja.api_secret')`, but
        // `ApiSecretCheck` is skipped in hosted mode: a hosted server reached
        // through the Self-Hosted toggle reports a secret it never checks.
        final svc = _ScriptedAuthService(
          result: const LoginPrecheck(
            methods: {'password'},
            secretRequired: true,
          ),
        );
        final vm = vmWith(svc);
        await vm.continueToCredentials();
        expect(vm.secretIsRequired, isTrue);

        await vm.submit();
        expect(svc.loginCalls, 1);
        expect(svc.loginSecret, isNull);
        await vm.recover();
        expect(svc.recoverCalls, 1);
      });

      test('retyping the password clears its server error', () async {
        final vm = vmWith(
          _ScriptedAuthService(
            result: passwordOnly,
            loginError: const ValidationException('Invalid', {
              'password': ['Too long.'],
            }),
          ),
        );
        await vm.continueToCredentials();
        await vm.submit();
        expect(vm.fieldErrors['password'], isNotNull);
        vm.setPassword('shorter');
        expect(vm.fieldErrors['password'], isNull);
      });
    });

    group('where a login 422 shows', () {
      test('a field-less 422 lands on the visible OTP field', () async {
        // `LoginController::verifyTwoFactor` answers a wrong code with a 422
        // carrying a message and no `errors` object.
        final vm = vmWith(
          _ScriptedAuthService(
            result: const LoginPrecheck(
              methods: {'password', 'totp'},
              secretRequired: false,
            ),
            loginError: const ValidationException(
              'Invalid one time password',
              {},
            ),
          ),
        );
        await vm.continueToCredentials();
        vm.setOneTimePassword('000000');
        expect(await vm.submit(), isFalse);
        expect(vm.fieldErrors['one_time_password'], [
          'Invalid one time password',
        ]);
        expect(vm.hasRequestError, isFalse);

        vm.setOneTimePassword('123456');
        expect(
          vm.fieldErrors['one_time_password'],
          isNull,
          reason: 'retyping the code clears it',
        );
      });

      test('a one_time_password field error is toasted, not lost', () async {
        // The server never keys one by this name (LoginRequest has no OTP
        // rule); if it ever did, nothing on screen would render it.
        final vm = vmWith(
          _ScriptedAuthService(
            result: passwordOnly,
            loginError: const ValidationException('Bad code', {
              'one_time_password': ['Bad code'],
            }),
          ),
        );
        await vm.continueToCredentials();
        await vm.submit();
        expect(vm.errorMessage, 'Bad code');
      });

      test('field errors this form renders stay inline', () async {
        final vm = vmWith(
          _ScriptedAuthService(
            result: passwordOnly,
            loginError: const ValidationException('Invalid', {
              'password': ['Too long.'],
            }),
          ),
        );
        await vm.continueToCredentials();
        await vm.submit();
        expect(vm.fieldErrors['password'], ['Too long.']);
        expect(vm.hasRequestError, isFalse);
      });

      test('field errors it does not render are toasted', () async {
        final vm = vmWith(
          _ScriptedAuthService(
            result: passwordOnly,
            loginError: const ValidationException('Something else', {
              'company': ['Nope.'],
            }),
          ),
        );
        await vm.continueToCredentials();
        await vm.submit();
        expect(vm.errorMessage, 'Something else');
      });
    });

    group('SMS 2FA reset', () {
      test('drops totp when it is this form\'s account', () async {
        final vm = vmWith(_ScriptedAuthService(result: totpAndSecret));
        await vm.continueToCredentials();
        vm.setOneTimePassword('123456');

        final result = await vm.confirmTwoFactorReset('a@b.test', '654321');

        expect(result.ok, isTrue);
        expect(vm.otpConfirmed, isFalse);
        expect(vm.showOtpField, isFalse);
        expect(vm.oneTimePassword, isEmpty);
        expect(vm.secretIsRequired, isTrue, reason: 'secret flag untouched');
      });

      test('leaves this form alone when another address was reset', () async {
        final vm = vmWith(_ScriptedAuthService(result: totpAndSecret));
        await vm.continueToCredentials();

        final result = await vm.confirmTwoFactorReset('other@b.test', '1');

        expect(result.ok, isTrue);
        expect(vm.otpConfirmed, isTrue);
      });

      test('matches this form\'s address case-insensitively', () async {
        // The server looks the address up case-insensitively.
        final vm = vmWith(_ScriptedAuthService(result: totpAndSecret));
        await vm.continueToCredentials();

        await vm.confirmTwoFactorReset(' A@B.TEST ', '1');

        expect(vm.otpConfirmed, isFalse);
      });

      test('an unreachable confirm makes the TOTP answer unknown', () async {
        // The server may already have disabled 2FA; a cached "has TOTP" would
        // then block a login that no longer needs a code.
        final svc = _ScriptedAuthService(result: totpAndSecret);
        final vm = vmWith(svc);
        await vm.continueToCredentials();
        vm.setOneTimePassword('123456');
        svc.resetErrorOverride = const NetworkException('timed out');

        final result = await vm.confirmTwoFactorReset('a@b.test', '1');

        expect(result.ok, isFalse);
        expect(result.unreachable, isTrue);
        expect(vm.otpConfirmed, isFalse);
        expect(vm.showOtpField, isTrue, reason: 'optional, not hidden');
        // The field is still on screen showing the code, so it is still sent
        // (an account whose 2FA did go off ignores it).
        expect(vm.oneTimePassword, '123456');
        await vm.submit();
        expect(svc.loginCalls, 1);
        expect(svc.loginOtp, '123456');
      });

      test('an unreachable confirm with no code never blocks', () async {
        final svc = _ScriptedAuthService(result: totpAndSecret);
        final vm = vmWith(svc);
        await vm.continueToCredentials();
        svc.resetErrorOverride = const NetworkException('timed out');

        await vm.confirmTwoFactorReset('a@b.test', '1');
        await vm.submit();

        expect(svc.loginCalls, 1, reason: 'no longer blocked on the code');
        expect(vm.otpErrorKey, isNull);
      });

      test('a rejected confirm leaves the TOTP answer alone', () async {
        final svc = _ScriptedAuthService(result: totpAndSecret);
        final vm = vmWith(svc);
        await vm.continueToCredentials();
        svc.resetErrorOverride = const ServerException(
          400,
          'SMS not verified.',
        );

        final result = await vm.confirmTwoFactorReset('a@b.test', '1');

        expect(result.unreachable, isFalse);
        expect(result.errorMessage, 'SMS not verified.');
        expect(vm.otpConfirmed, isTrue);
      });

      test('a 422 on send carries the field errors', () async {
        final vm = vmWith(
          _ScriptedAuthService(
            resetError: const ValidationException(
              'The given data was invalid.',
              {
                'email': ['The selected email is invalid.'],
              },
            ),
          ),
        );

        final result = await vm.sendTwoFactorResetCode('nobody@b.test');

        expect(result.ok, isFalse);
        expect(result.fieldErrors['email'], ['The selected email is invalid.']);
      });

      test('send uses the address it is given', () async {
        final svc = _ScriptedAuthService(result: totpAndSecret);
        final vm = vmWith(svc);
        final result = await vm.sendTwoFactorResetCode('edited@b.test');
        expect(result.ok, isTrue);
        expect(svc.resetEmails, ['edited@b.test']);
      });
    });
  });
}
