import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/tls/certificate_facts.dart';
import 'package:admin/data/services/tls/certificate_problems.dart';
import 'package:admin/data/services/tls/certificate_trust_store.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/ui/features/auth/view_models/login_view_model.dart';
import 'package:admin/ui/features/auth/view_models/signup_view_model.dart';

/// A refused server certificate on the login screen: explained, offered for
/// trust only on a self-hosted server, and — once trusted — the step runs
/// again (docs/trusting-a-self-hosted-certificate.md).

final _facts = CertificateFacts(
  sha256: 'cd' * 32,
  subject: '/CN=*.registrar-servers.com',
  issuer: '/C=GB/O=Sectigo Limited/CN=Sectigo DV R36',
  notBefore: DateTime.utc(2025, 11, 7, 12),
  notAfter: DateTime.utc(2099, 11, 17, 12),
  subjectAltNames: const ['*.registrar-servers.com'],
);

UntrustedCertificateException _refused([String host = 'ninja.example.com']) =>
    UntrustedCertificateException(
      host: host,
      port: 443,
      certificate: _facts,
      problems: const [CertificateProblem.nameMismatch],
    );

/// Each call takes the next scripted error; once they run out it answers.
class _Scripted implements AuthService {
  _Scripted({
    List<Object> precheck = const [],
    List<Object> login = const [],
    List<Object> recover = const [],
    List<Object> signup = const [],
  }) : _precheck = [...precheck],
       _login = [...login],
       _recover = [...recover],
       _signup = [...signup];

  final List<Object> _precheck;
  final List<Object> _login;
  final List<Object> _recover;
  final List<Object> _signup;
  int precheckCalls = 0;

  @override
  Future<LoginPrecheck?> precheck({
    required String baseUrl,
    required bool isHosted,
    required String email,
  }) async {
    precheckCalls++;
    if (_precheck.isNotEmpty) throw _precheck.removeAt(0);
    return const LoginPrecheck(methods: {'password'}, secretRequired: false);
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
    throw _login.isNotEmpty
        ? _login.removeAt(0)
        : const NetworkException('unscripted');
  }

  @override
  Future<void> recoverPassword({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) async {
    if (_recover.isNotEmpty) throw _recover.removeAt(0);
  }

  @override
  Future<LoginResponseApi> signup({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String referralCode = '',
  }) async {
    throw _signup.isNotEmpty
        ? _signup.removeAt(0)
        : const NetworkException('unscripted');
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late CertificateTrustStore trust;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    trust = CertificateTrustStore(prefs: DevicePrefsStore(null));
  });
  tearDown(() => db.close());

  AuthRepository repoWith(AuthService service) => AuthRepository(
    db: db,
    authService: service,
    tokenStorage: InMemoryTokenStorage(),
    passwordCache: PasswordCache(),
  );

  LoginViewModel selfHosted(
    _Scripted service, {
    bool withTrust = true,
    bool isWeb = false,
    String url = 'https://ninja.example.com',
  }) =>
      LoginViewModel(
          auth: repoWith(service),
          certificateTrust: withTrust ? trust : null,
          isWeb: isWeb,
        )
        ..setHosted(false)
        ..setUrlOverride(url)
        ..setEmail('a@b.test')
        ..setPassword('pw');

  group('self-hosted', () {
    test('a refused certificate is held for the dialog, not toasted', () async {
      final vm = selfHosted(_Scripted(precheck: [_refused()]));
      expect(await vm.continueToCredentials(), isFalse);
      expect(vm.hasRequestError, isFalse);
      expect(vm.untrustedCertificate?.certificate, _facts);
      expect(vm.canTrustCertificate, isTrue);
      expect(vm.step, LoginStep.email);
    });

    test('trusting it pins it, and the step then goes through', () async {
      final service = _Scripted(precheck: [_refused()]);
      final vm = selfHosted(service);
      await vm.continueToCredentials();

      expect(await vm.trustCertificate(), isTrue);
      expect(vm.untrustedCertificate, isNull);
      expect(trust.isTrusted('ninja.example.com', 443, _facts.sha256), isTrue);

      expect(await vm.continueToCredentials(), isTrue);
      expect(vm.step, LoginStep.credentials);
      expect(service.precheckCalls, 2);
    });

    test('dismissing it trusts nothing', () async {
      final vm = selfHosted(_Scripted(precheck: [_refused()]));
      await vm.continueToCredentials();
      vm.dismissUntrustedCertificate();
      expect(vm.untrustedCertificate, isNull);
      expect(trust.pins, isEmpty);
    });

    test('a certificate already trusted and still refused is a toast, '
        'never a second prompt', () async {
      await trust.trust('ninja.example.com', 443, _facts);
      final vm = selfHosted(_Scripted(precheck: [_refused()]));
      await vm.continueToCredentials();
      expect(vm.untrustedCertificate, isNull);
      expect(vm.errorKey, 'network_error_with_message');
    });

    test('without a store it is still explained, but not offered', () async {
      final vm = selfHosted(
        _Scripted(precheck: [_refused()]),
        withTrust: false,
      );
      await vm.continueToCredentials();
      expect(vm.untrustedCertificate, isNotNull);
      expect(vm.canTrustCertificate, isFalse);
      expect(await vm.trustCertificate(), isFalse);
    });

    test(
      'a self-hosted URL that is the hosted service is never offered',
      () async {
        final vm = selfHosted(
          _Scripted(precheck: [_refused('invoicing.co')]),
          url: 'https://invoicing.co',
        );
        await vm.continueToCredentials();
        expect(vm.untrustedCertificate, isNull);
        expect(vm.errorKey, 'untrusted_certificate_hosted');
        expect(vm.errorParams, {'host': 'invoicing.co'});
      },
    );

    test('the login and recover steps hold it too', () async {
      final login = selfHosted(_Scripted(login: [_refused()]));
      expect(await login.submit(), isFalse);
      expect(login.untrustedCertificate, isNotNull);

      final recover = selfHosted(_Scripted(recover: [_refused()]));
      expect(await recover.recover(), isFalse);
      expect(recover.untrustedCertificate, isNotNull);
    });

    test('the URL field says when its server has a trusted certificate, '
        'and Forget takes it back', () async {
      await trust.trust('ninja.example.com', 443, _facts);
      final vm = selfHosted(_Scripted());
      expect(vm.trustedCertificateForUrl?.host, 'ninja.example.com');

      vm.setUrlOverride('ninja.example.com:8443');
      expect(vm.trustedCertificateForUrl, isNull);
      vm.setUrlOverride('ninja.example.com');
      expect(vm.trustedCertificateForUrl, isNotNull);

      var notified = 0;
      vm.addListener(() => notified++);
      await vm.forgetTrustedCertificate();
      expect(vm.trustedCertificateForUrl, isNull);
      expect(trust.pins, isEmpty);
      expect(notified, greaterThan(0));
    });

    test('the line follows the URL as it is typed', () {
      trust.trust('ninja.example.com', 443, _facts);
      final vm = selfHosted(_Scripted(), url: 'https://other.example.com');
      var notified = 0;
      vm.addListener(() => notified++);
      vm.setUrlOverride('https://ninja.example.com');
      expect(notified, 1);
      // Typing on within the same server doesn't rebuild the screen.
      vm.setUrlOverride('https://ninja.example.com/');
      expect(notified, 1);
    });
  });

  group('hosted', () {
    test('explained as an intercepting network, never offered', () async {
      final vm = LoginViewModel(
        auth: repoWith(_Scripted(precheck: [_refused('invoicing.co')])),
        certificateTrust: trust,
      )..setEmail('a@b.test');
      await vm.continueToCredentials();
      expect(vm.untrustedCertificate, isNull);
      expect(vm.canTrustCertificate, isFalse);
      expect(vm.errorKey, 'untrusted_certificate_hosted');
      expect(vm.errorDetailKey, 'untrusted_certificate_hosted_detail');
    });

    test('signup says the same', () async {
      final vm =
          SignupViewModel(
              auth: repoWith(_Scripted(signup: [_refused('invoicing.co')])),
            )
            ..email = 'a@b.test'
            ..password = 'pw123456'
            ..confirmPassword = 'pw123456'
            ..acceptedTerms = true;
      expect(await vm.submit(), isFalse);
      expect(vm.errorKey, 'untrusted_certificate_hosted');
      expect(vm.errorDetailKey, 'untrusted_certificate_hosted_detail');
    });
  });

  group('web', () {
    test('a self-hosted network error suggests the certificate', () async {
      final vm = selfHosted(
        _Scripted(precheck: [const NetworkException('XMLHttpRequest error.')]),
        isWeb: true,
      );
      await vm.continueToCredentials();
      expect(vm.errorKey, 'network_error_with_message');
      expect(vm.errorDetailKey, 'web_certificate_hint');
      expect(vm.openServerUrl, 'https://ninja.example.com');
    });

    test('not on hosted, and not off the web', () async {
      final hosted = LoginViewModel(
        auth: repoWith(
          _Scripted(
            precheck: [const NetworkException('XMLHttpRequest error.')],
          ),
        ),
        isWeb: true,
      )..setEmail('a@b.test');
      await hosted.continueToCredentials();
      expect(hosted.errorDetailKey, isNull);
      expect(hosted.openServerUrl, isNull);

      final native = selfHosted(
        _Scripted(precheck: [const NetworkException('Connection refused')]),
      );
      await native.continueToCredentials();
      expect(native.errorDetailKey, isNull);
    });
  });
}
