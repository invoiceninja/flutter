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

/// Serves a canned `/login/precheck` answer, optionally held open by [gate] so
/// a test can dispose the VM while the request is still in flight.
class _PrecheckAuthService implements AuthService {
  _PrecheckAuthService({this.result, this.gate});

  final LoginPrecheck? result;
  final Completer<void>? gate;
  int calls = 0;

  @override
  Future<LoginPrecheck?> precheck({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) async {
    calls++;
    if (gate != null) await gate!.future;
    return result;
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

  group('login precheck', () {
    // The form hides its optional TOTP / API-secret fields based on this
    // answer, so the load-bearing rule is: only ever hide a field the server
    // has positively told us is unnecessary. Anything else — no answer yet,
    // an older server, offline — must leave both visible.
    LoginViewModel vmWithPrecheck(_PrecheckAuthService svc) {
      final repo = AuthRepository(
        db: db,
        authService: svc,
        tokenStorage: InMemoryTokenStorage(),
        passwordCache: PasswordCache(),
      );
      return LoginViewModel(auth: repo)
        ..setHosted(false)
        ..setUrlOverride('https://ninja.example.com')
        ..setEmail('a@b.test');
    }

    const passwordOnly = LoginPrecheck(
      methods: {'password'},
      secretRequired: false,
    );

    test('both optional fields stay visible until the server answers', () {
      final vm = vmWithPrecheck(_PrecheckAuthService());
      expect(vm.showOtpField, isTrue);
      expect(vm.showSecretField, isTrue);
      expect(vm.secretIsRequired, isFalse);
    });

    test('a null answer (older server / offline) keeps both fields', () async {
      final vm = vmWithPrecheck(_PrecheckAuthService());
      await vm.runPrecheck();
      expect(vm.showOtpField, isTrue);
      expect(vm.showSecretField, isTrue);
    });

    test('password-only account hides the OTP and secret fields', () async {
      final vm = vmWithPrecheck(_PrecheckAuthService(result: passwordOnly));
      await vm.runPrecheck();
      expect(vm.showOtpField, isFalse);
      expect(vm.showSecretField, isFalse);
    });

    test(
      'totp + secret_required keeps both and marks the secret required',
      () async {
        final vm = vmWithPrecheck(
          _PrecheckAuthService(
            result: const LoginPrecheck(
              methods: {'password', 'totp'},
              secretRequired: true,
            ),
          ),
        );
        await vm.runPrecheck();
        expect(vm.showOtpField, isTrue);
        expect(vm.showSecretField, isTrue);
        expect(vm.secretIsRequired, isTrue);
      },
    );

    test('hiding the OTP field clears a stale code', () async {
      // submit() sends one_time_password whenever it is non-empty, so a code
      // left behind by the now-hidden field would fail a valid login.
      final vm = vmWithPrecheck(_PrecheckAuthService(result: passwordOnly));
      vm.setOneTimePassword('123456');
      await vm.runPrecheck();
      expect(vm.showOtpField, isFalse);
      expect(vm.oneTimePassword, isEmpty);
    });

    test('a typed secret survives being hidden', () async {
      // Deliberate asymmetry with the OTP: a stale secret is ignored by a
      // server with no API_SECRET (ApiSecretCheck short-circuits), and keeping
      // it means switching back to a secret-requiring URL restores the value.
      final vm = vmWithPrecheck(_PrecheckAuthService(result: passwordOnly));
      vm.setSecret('s3cret');
      await vm.runPrecheck();
      expect(vm.showSecretField, isFalse);
      expect(vm.secret, 's3cret');
    });

    test('editing the email drops the previous answer', () async {
      final vm = vmWithPrecheck(_PrecheckAuthService(result: passwordOnly));
      await vm.runPrecheck();
      expect(vm.showOtpField, isFalse);
      vm.setEmail('other@b.test');
      expect(
        vm.showOtpField,
        isTrue,
        reason: 'answer belonged to the old email',
      );
    });

    test('does not re-ask for an unchanged email', () async {
      final svc = _PrecheckAuthService(result: passwordOnly);
      final vm = vmWithPrecheck(svc);
      await vm.runPrecheck();
      await vm.runPrecheck();
      expect(svc.calls, 1);
    });

    // The answer is per (server, email). Only `setEmail` used to drop it, so
    // pointing at a different server left the previous host's answer standing
    // — and if that host had no API_SECRET while the new one does, the secret
    // field stays hidden and there is nowhere to type the secret.
    test('changing the server URL drops the previous answer', () async {
      final vm = vmWithPrecheck(_PrecheckAuthService(result: passwordOnly));
      await vm.runPrecheck();
      expect(vm.showSecretField, isFalse);

      vm.setUrlOverride('https://other.example.com');
      expect(
        vm.showSecretField,
        isTrue,
        reason: 'the answer belonged to the previous server',
      );
    });

    test('toggling hosted drops the previous answer', () async {
      final vm = vmWithPrecheck(_PrecheckAuthService(result: passwordOnly));
      await vm.runPrecheck();
      expect(vm.showSecretField, isFalse);

      vm.setHosted(true);
      expect(
        vm.showSecretField,
        isTrue,
        reason: 'the answer belonged to the self-hosted server',
      );
    });

    test('re-asks after the server URL changes', () async {
      final svc = _PrecheckAuthService(result: passwordOnly);
      final vm = vmWithPrecheck(svc);
      await vm.runPrecheck();
      vm.setUrlOverride('https://other.example.com');
      await vm.runPrecheck();
      expect(svc.calls, 2);
    });

    // `/login/precheck` is registered under `throttle:precheck`. A failed
    // answer must still count as "asked", or every blur re-hits it.
    test('a failed answer is not retried on the next blur', () async {
      final svc = _PrecheckAuthService(); // null result = no answer
      final vm = vmWithPrecheck(svc);
      await vm.runPrecheck();
      await vm.runPrecheck();
      await vm.runPrecheck();
      expect(svc.calls, 1);
      // …and the form stays in its optimistic state, as before.
      expect(vm.showOtpField, isTrue);
      expect(vm.showSecretField, isTrue);
    });

    test('skips a blank or malformed email entirely', () async {
      final svc = _PrecheckAuthService(result: passwordOnly);
      final vm = vmWithPrecheck(svc)..setEmail('not-an-email');
      await vm.runPrecheck();
      expect(svc.calls, 0);
    });

    test('disposing mid-flight does not notify a disposed notifier', () async {
      // runPrecheck is fire-and-forget from the email field's blur, and the
      // server pads the response to a 250 ms floor, so a fast submit can tear
      // the screen down first. Notifying past dispose throws
      // debugAssertNotDisposed.
      final gate = Completer<void>();
      final vm = vmWithPrecheck(
        _PrecheckAuthService(result: passwordOnly, gate: gate),
      );
      final pending = vm.runPrecheck();
      vm.dispose();
      gate.complete();
      await expectLater(pending, completes);
    });
  });
}
