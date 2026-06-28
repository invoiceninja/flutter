import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/ui/features/auth/view_models/login_view_model.dart';
import 'package:drift/native.dart';
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

  @override
  Future<LoginResponseApi> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
  }) async {
    capturedBaseUrl = baseUrl;
    throw const NetworkException('captured');
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
}
