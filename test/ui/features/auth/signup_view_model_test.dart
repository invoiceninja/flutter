import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/ui/features/auth/view_models/signup_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Local validation gates the network call: an obviously-bad signup must
/// never reach the wire. If `signup` is hit, validation let something
/// through that shouldn't have.
class _GuardAuthService implements AuthService {
  /// Recorded rather than `fail()`ed: `SignupViewModel.submit` now has a
  /// catch-all (so an unexpected failure can't leave the button silently
  /// un-spun), which would swallow a `TestFailure` thrown from here and turn
  /// "the service was reached" into an indistinguishable `false`. Counting the
  /// calls asserts the same thing without depending on an exception escaping.
  int calls = 0;

  @override
  Future<LoginResponseApi> signup({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String referralCode = '',
  }) async {
    calls++;
    throw const NetworkException('offline');
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Stands in for a keychain write, a platform channel, or a cast on an
/// unexpected response shape — none of which are `ApiException`s.
class _ThrowingAuthService implements AuthService {
  @override
  Future<LoginResponseApi> signup({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String referralCode = '',
  }) async => throw StateError('keychain unavailable');

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late AuthRepository auth;
  late SignupViewModel vm;
  late _GuardAuthService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = _GuardAuthService();
    auth = AuthRepository(
      db: db,
      authService: service,
      tokenStorage: InMemoryTokenStorage(),
      passwordCache: PasswordCache(),
    );
    vm = SignupViewModel(auth: auth);
  });
  tearDown(() async {
    await db.close();
  });

  group('SignupViewModel local validation (no network)', () {
    test('empty email or password → please_fill_out_all_fields', () async {
      vm.setPassword('pw');
      vm.setConfirmPassword('pw');
      vm.setAcceptedTerms(true);
      expect(await vm.submit(), isFalse);
      expect(vm.errorKey, 'please_fill_out_all_fields');

      vm.setEmail('a@b.test');
      vm.setPassword('');
      expect(await vm.submit(), isFalse);
      expect(vm.errorKey, 'please_fill_out_all_fields');
    });

    test('password mismatch → passwords_do_not_match', () async {
      vm.setEmail('a@b.test');
      vm.setPassword('pw123456');
      vm.setConfirmPassword('different');
      vm.setAcceptedTerms(true);
      expect(await vm.submit(), isFalse);
      expect(vm.errorKey, 'passwords_do_not_match');
    });

    test('terms not accepted → accept_terms_to_continue', () async {
      vm.setEmail('a@b.test');
      vm.setPassword('pw123456');
      vm.setConfirmPassword('pw123456');
      // acceptedTerms defaults false
      expect(await vm.submit(), isFalse);
      expect(vm.errorKey, 'accept_terms_to_continue');
    });

    test('valid input passes local gates and reaches the service', () async {
      vm.setEmail('a@b.test');
      vm.setPassword('pw123456');
      vm.setConfirmPassword('pw123456');
      vm.setAcceptedTerms(true);

      expect(await vm.submit(), isFalse, reason: 'the fake service is offline');
      expect(service.calls, 1, reason: 'no local gate rejected it early');
      expect(vm.errorKey, 'network_error_with_message');
    });

    test(
      'an unexpected (non-ApiException) failure still surfaces a message',
      () async {
        // Regression: the auth VMs caught only `ApiException` subtypes, so a
        // keychain / platform-channel / TypeError failure escaped, `finally`
        // cleared `busy`, and the view — which has no try/catch either — turned
        // it into an unhandled zone error. The user saw the button un-spin and
        // nothing else, forever.
        final throwing = _ThrowingAuthService();
        final vm2 = SignupViewModel(
          auth: AuthRepository(
            db: db,
            authService: throwing,
            tokenStorage: InMemoryTokenStorage(),
            passwordCache: PasswordCache(),
          ),
        );
        vm2.setEmail('a@b.test');
        vm2.setPassword('pw123456');
        vm2.setConfirmPassword('pw123456');
        vm2.setAcceptedTerms(true);

        expect(await vm2.submit(), isFalse);
        expect(vm2.busy, isFalse);
        expect(
          vm2.errorMessage ?? vm2.errorKey,
          isNotNull,
          reason: 'the user must be told something',
        );
      },
    );
  });
}
