import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/passkey_authenticator.dart';
import 'package:admin/data/services/passkey_readiness.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/ui/features/auth/view_models/login_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin/data/services/passkey_failure.dart';

/// "Login with a Passkey" (docs/passkeys.md). A rejected passkey sign-in
/// counts toward the server's per-email lockout, so these pin that the
/// ceremony starts only when it can succeed, that nothing retries, and that
/// the password is never sent alongside the assertion.
const _options = PasskeyLoginOptions(
  publicKey: {'rpId': 'app.invoicing.co', 'challenge': 'Y2hhbGxlbmdl'},
  challengeToken: 'token-1',
  androidOrigins: ['android:apk-key-hash:u7yL'],
);

const _credential = <String, dynamic>{
  'id': 'Y3JlZA',
  'rawId': 'Y3JlZA',
  'type': 'public-key',
  'response': {
    'clientDataJSON': 'Y2Q',
    'authenticatorData': 'YWQ',
    'signature': 'c2ln',
  },
};

class _ScriptedAuthService implements AuthService {
  _ScriptedAuthService({this.optionsError});

  final Object? optionsError;

  int optionsCalls = 0;
  int loginCalls = 0;
  String? optionsSecret;
  String? loginSecret;
  String? loginChallengeToken;
  Map<String, dynamic>? loginCredential;

  @override
  Future<LoginPrecheck?> precheck({
    required String baseUrl,
    required bool isHosted,
    required String email,
  }) async =>
      const LoginPrecheck(methods: {'password', 'totp'}, secretRequired: false);

  @override
  Future<PasskeyLoginOptions> passkeyLoginOptions({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) async {
    optionsCalls++;
    optionsSecret = secret;
    if (optionsError != null) throw optionsError!;
    return _options;
  }

  @override
  Future<LoginResponseApi> loginWithPasskey({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String challengeToken,
    required Map<String, dynamic> credential,
    String? secret,
  }) async {
    loginCalls++;
    loginSecret = secret;
    loginChallengeToken = challengeToken;
    loginCredential = credential;
    // Never succeeds: a session would need a full login snapshot.
    throw const ServerException(400, 'Invalid credentials');
  }

  @override
  Future<LoginResponseApi> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
    String? secret,
  }) async => fail('a passkey sign-in must never be a password login');

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakeReadiness extends PasskeyReadiness {
  _FakeReadiness({this.ready = true, this.allows = true});

  bool ready;
  bool allows;
  PasskeyLoginOptions? checkedOptions;

  @override
  Future<bool> isReady({
    required String apiBaseUrl,
    required bool isHosted,
    String? rpId,
  }) async => ready;

  @override
  Future<bool> allowsCeremony({
    required String apiBaseUrl,
    required bool isHosted,
    required PasskeyLoginOptions options,
  }) async {
    checkedOptions = options;
    return allows;
  }
}

class _FakeAuthenticator implements PasskeyAuthenticator {
  _FakeAuthenticator({this.error});

  final PasskeyException? error;
  int calls = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, dynamic>> authenticate(
    Map<String, dynamic> publicKey,
  ) async {
    calls++;
    if (error != null) throw error!;
    return _credential;
  }

  @override
  Future<Map<String, dynamic>> register(Map<String, dynamic> publicKey) =>
      throw UnimplementedError();
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<LoginViewModel> onCredentialsStep(
    _ScriptedAuthService service, {
    _FakeReadiness? readiness,
    _FakeAuthenticator? authenticator,
    bool hosted = true,
  }) async {
    final vm = LoginViewModel(
      auth: AuthRepository(
        db: db,
        authService: service,
        tokenStorage: InMemoryTokenStorage(),
        passwordCache: PasswordCache(),
      ),
      passkeyReadiness: readiness ?? _FakeReadiness(),
      passkeyAuthenticator: authenticator ?? _FakeAuthenticator(),
    );
    addTearDown(vm.dispose);
    vm.setHosted(hosted);
    if (!hosted) vm.setUrlOverride('https://billing.example.com');
    vm.setEmail('jane@example.com');
    expect(await vm.continueToCredentials(), isTrue);
    // The readiness answer lands asynchronously.
    await Future<void>.delayed(Duration.zero);
    return vm;
  }

  test('the button shows only once readiness is proven', () async {
    final notReady = await onCredentialsStep(
      _ScriptedAuthService(),
      readiness: _FakeReadiness(ready: false),
    );
    expect(notReady.passkeyEnabled, isFalse);
    expect(await notReady.submitPasskey(), isFalse);

    final ready = await onCredentialsStep(_ScriptedAuthService());
    expect(ready.passkeyEnabled, isTrue);
  });

  test(
    'signs in with the assertion, not the password, past a required OTP',
    () async {
      final service = _ScriptedAuthService();
      final authenticator = _FakeAuthenticator();
      final vm = await onCredentialsStep(service, authenticator: authenticator);
      vm.setPassword('typed but unused');
      expect(vm.otpConfirmed, isTrue, reason: 'the account has TOTP');

      await vm.submitPasskey();

      expect(vm.otpErrorKey, isNull, reason: 'the server skips TOTP for this');
      expect(authenticator.calls, 1);
      expect(service.loginCalls, 1);
      expect(service.loginChallengeToken, 'token-1');
      expect(service.loginCredential, _credential);
    },
  );

  test(
    'a rejected assertion shows the server message and is not retried',
    () async {
      final service = _ScriptedAuthService();
      final vm = await onCredentialsStep(service);

      expect(await vm.submitPasskey(), isFalse);

      expect(vm.errorMessage, 'Invalid credentials');
      expect(vm.errorKey, isNull);
      expect(service.loginCalls, 1);
    },
  );

  test('an email without passkeys points back to the password', () async {
    final authenticator = _FakeAuthenticator();
    final vm = await onCredentialsStep(
      _ScriptedAuthService(optionsError: const ServerException(400, 'nope')),
      authenticator: authenticator,
    );

    expect(await vm.submitPasskey(), isFalse);

    expect(vm.errorKey, 'no_passkeys_registered');
    expect(authenticator.calls, 0);
  });

  test('a server from before passkeys says so, and the button goes', () async {
    final vm = await onCredentialsStep(
      _ScriptedAuthService(
        optionsError: const ServerException(404, 'Not Found'),
      ),
    );

    await vm.submitPasskey();

    expect(vm.errorKey, 'passkeys_not_supported_by_server');
    expect(vm.passkeyEnabled, isFalse, reason: 'it cannot start working');
  });

  test('options this device cannot use never reach the OS sheet', () async {
    final readiness = _FakeReadiness(allows: false);
    final authenticator = _FakeAuthenticator();
    final service = _ScriptedAuthService();
    final vm = await onCredentialsStep(
      service,
      readiness: readiness,
      authenticator: authenticator,
    );

    expect(await vm.submitPasskey(), isFalse);

    expect(readiness.checkedOptions, same(_options));
    expect(vm.errorKey, 'passkey_unavailable');
    expect(authenticator.calls, 0);
    expect(service.loginCalls, 0, reason: 'no lockout strike');
  });

  test('a dismissed sheet says nothing', () async {
    final service = _ScriptedAuthService();
    final vm = await onCredentialsStep(
      service,
      authenticator: _FakeAuthenticator(
        error: const PasskeyException(PasskeyFailure.cancelled),
      ),
    );

    expect(await vm.submitPasskey(), isFalse);

    expect(vm.hasRequestError, isFalse);
    expect(service.loginCalls, 0);
  });

  test('a device without this passkey is "unavailable"', () async {
    for (final failure in [
      PasskeyFailure.notAssociated,
      PasskeyFailure.noCredentials,
      PasskeyFailure.unsupported,
    ]) {
      final vm = await onCredentialsStep(
        _ScriptedAuthService(),
        authenticator: _FakeAuthenticator(error: PasskeyException(failure)),
      );
      await vm.submitPasskey();
      expect(vm.errorKey, 'passkey_unavailable', reason: '$failure');
    }
  });

  test('the self-hosted secret travels with both requests', () async {
    final service = _ScriptedAuthService();
    final vm = await onCredentialsStep(service, hosted: false);
    vm.setSecret('s3cret');

    await vm.submitPasskey();

    expect(service.optionsSecret, 's3cret');
    expect(service.loginSecret, 's3cret');
  });

  test(
    'changing the server hides the button until it is checked again',
    () async {
      final vm = await onCredentialsStep(_ScriptedAuthService());
      expect(vm.passkeyEnabled, isTrue);

      vm.setHosted(false);

      expect(vm.passkeyEnabled, isFalse);
    },
  );
}
