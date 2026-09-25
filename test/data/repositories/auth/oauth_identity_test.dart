import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The session carries what a password-protected action needs to decide how
/// to confirm it (`PasswordSubject`): the user's OAuth provider, whether they
/// have a password at all, and the company's `oauth_password_required` — from
/// the login envelope, and again from Drift on a cold start.
String _envelope({required bool oauthPasswordRequired}) => jsonEncode({
  'data': [
    {
      'is_admin': true,
      'is_owner': true,
      'permissions': '',
      'user': {
        'id': 'user_1',
        'email': 'ada@example.com',
        'oauth_provider_id': 'apple',
        'has_password': false,
        'oauth_user_token': '***',
      },
      'company': {
        'id': 'co_1',
        'name': 'Acme',
        'oauth_password_required': oauthPasswordRequired,
      },
      'token': {'token': 'tok_1'},
      'account': {'id': 'acct_1', 'default_company_id': 'co_1'},
    },
  ],
});

void main() {
  late AppDatabase db;
  late InMemoryTokenStorage storage;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    storage = InMemoryTokenStorage();
  });
  tearDown(() async {
    await db.close();
  });

  AuthRepository repoFor(String envelope) => AuthRepository(
    db: db,
    authService: AuthService(
      httpClient: MockClient(
        (req) async => http.Response(
          envelope,
          200,
          headers: const {'content-type': 'application/json'},
        ),
      ),
    ),
    tokenStorage: storage,
    passwordCache: PasswordCache(),
  );

  Future<AuthRepository> signIn({required bool required}) async {
    final repo = repoFor(_envelope(oauthPasswordRequired: required));
    await repo.oauthLogin(
      baseUrl: 'https://test',
      isHosted: true,
      provider: 'apple',
      idToken: 'jwt',
    );
    return repo;
  }

  test('login puts the OAuth identity and the company setting on the '
      'session', () async {
    final repo = await signIn(required: true);
    final s = repo.session.value!;
    expect(s.userOauthProviderId, 'apple');
    expect(s.userHasPassword, isFalse);
    expect(s.currentCompany!.oauthPasswordRequired, isTrue);
    expect(s.passwordSubject.isExempt, isFalse);
    expect(s.passwordSubject.isApple, isTrue);
  });

  test('with the setting off, the OAuth user is exempt', () async {
    final repo = await signIn(required: false);
    expect(repo.session.value!.passwordSubject.isExempt, isTrue);
  });

  test(
    'the stored auth user keeps has_password and the mailer flag — both '
    'were once dropped, so Connect never offered "Disconnect mailer"',
    () async {
      await signIn(required: true);
      final row = await db.userDao.getByCompanyAndId(
        companyId: 'co_1',
        id: 'user_1',
      );
      final payload = jsonDecode(row!.payload) as Map<String, dynamic>;
      expect(payload['has_password'], isFalse);
      expect(payload['oauth_user_token'], '***');
    },
  );

  test('a cold start recovers all three from Drift', () async {
    await signIn(required: true);
    final restored = repoFor(_envelope(oauthPasswordRequired: true));
    await restored.restore();
    final s = restored.session.value!;
    expect(s.userOauthProviderId, 'apple');
    expect(s.userHasPassword, isFalse);
    expect(s.currentCompany!.oauthPasswordRequired, isTrue);
  });
}
