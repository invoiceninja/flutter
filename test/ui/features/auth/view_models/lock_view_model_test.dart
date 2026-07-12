import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/ui/features/auth/view_models/lock_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../_support/fake_biometric_service.dart';

/// Stand-in for AuthService — restore() doesn't touch it, and no test path
/// here calls login()/recoverPassword(), so both throw to make accidental
/// reuse loud.
class _UnusedAuthService implements AuthService {
  @override
  Future<LoginResponseApi> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
    String? secret,
  }) async => throw UnimplementedError();

  @override
  Future<void> recoverPassword({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) async => throw UnimplementedError();

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late InMemoryTokenStorage storage;
  late AuthRepository auth;
  late FakeBiometricService biometric;

  Future<void> seedLockedSession() async {
    // Mirror restore() behavior by hand: pre-populate Drift + storage so the
    // second AuthRepository can restore and flip the gate.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    await db.companiesDao.upsertAccount(
      AccountsCompanion.insert(
        id: 'acct_1',
        email: '',
        plan: 'pro',
        numTrialDays: 14,
        updatedAt: nowMs,
      ),
    );
    await db.companiesDao.upsertAll([
      CompaniesCompanion.insert(
        id: 'co_a',
        name: 'Acme',
        settings: '{}',
        permissions: '',
        accountId: 'acct_1',
        token: 'tok_a',
        updatedAt: nowMs,
      ),
    ]);
    await storage.write('invoiceninja.tokens.v1', '{"co_a":"tok_a"}');
    await storage.write('invoiceninja.base_url.v1', 'https://test');
    await storage.write('invoiceninja.is_hosted.v1', 'false');
    await storage.write('invoiceninja.current_company.v1', 'co_a');
    await storage.write('invoiceninja.biometric_enabled.v1', 'true');
    await auth.restore();
  }

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    storage = InMemoryTokenStorage();
    auth = AuthRepository(
      db: db,
      authService: _UnusedAuthService(),
      tokenStorage: storage,
      passwordCache: PasswordCache(),
    );
    biometric = FakeBiometricService();
  });
  tearDown(() async {
    await db.close();
  });

  test('successful unlock flips the gate and notifies', () async {
    await seedLockedSession();
    expect(auth.requiresBiometricUnlock.value, isTrue);

    final vm = LockViewModel(auth: auth, biometric: biometric);
    biometric.outcomes.add(true);
    await vm.unlock('reason');

    expect(biometric.reasons, ['reason']);
    expect(auth.requiresBiometricUnlock.value, isFalse);
    expect(vm.busy, isFalse);
    vm.dispose();
  });

  test('cancelled unlock leaves the gate up', () async {
    await seedLockedSession();
    final vm = LockViewModel(auth: auth, biometric: biometric);
    biometric.outcomes.add(false);
    await vm.unlock('reason');

    expect(auth.requiresBiometricUnlock.value, isTrue);
    expect(vm.busy, isFalse);
    vm.dispose();
  });

  test('signOut clears the session', () async {
    await seedLockedSession();
    final vm = LockViewModel(auth: auth, biometric: biometric);

    await vm.signOut();

    expect(auth.isAuthenticated, isFalse);
    expect(auth.requiresBiometricUnlock.value, isFalse);
    expect(await storage.read('invoiceninja.biometric_enabled.v1'), isNull);
    vm.dispose();
  });

  test('double-tap during prompt is a no-op', () async {
    await seedLockedSession();
    final vm = LockViewModel(auth: auth, biometric: biometric);
    biometric.outcomes.add(true);

    final first = vm.unlock('reason');
    // Second call while first is in flight should not call authenticate again.
    final second = vm.unlock('reason');
    await Future.wait([first, second]);

    expect(biometric.reasons.length, 1);
    vm.dispose();
  });
}
