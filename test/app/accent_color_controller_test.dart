import 'package:admin/app/accent_color_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/data/services/users_api.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Targets the accent-color resolution contract:
///   * [setPreview] takes precedence over the persisted server value
///   * a watched user emission whose accent matches the preview clears it
///     (Save round-tripped — preview is no longer a draft)
///   * switching company / signing out clears the preview
///   * `value` falls through to the persisted server value when no preview

class _FakeAuthService implements AuthService {
  final List<Object> _outcomes = [];

  void queueLogin(LoginResponseApi response) => _outcomes.add(response);

  @override
  Future<LoginResponseApi> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
    String? secret,
  }) async {
    if (_outcomes.isEmpty) throw StateError('no login outcome queued');
    final next = _outcomes.removeAt(0);
    if (next is LoginResponseApi) return next;
    throw next;
  }

  @override
  Future<void> recoverPassword({
    required String baseUrl,
    required bool isHosted,
    required String email,
    String? secret,
  }) async {}

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

LoginResponseApi _envelope({
  required String userId,
  List<({String id, String name, String token})> companies = const [
    (id: 'co_a', name: 'Acme', token: 'tok_a'),
  ],
}) {
  return LoginResponseApi(
    data: [
      for (final c in companies)
        UserCompanyApi(
          permissions: 'view_client',
          isAdmin: true,
          isOwner: true,
          user: UserSummaryApi(id: userId),
          company: CompanyEnvelopeApi(id: c.id, name: c.name),
          token: SessionTokenApi(token: c.token),
          account: AccountEnvelopeApi(
            id: 'acct_1',
            defaultCompanyId: companies.first.id,
            plan: 'pro',
            numTrialDays: 14,
          ),
        ),
    ],
  );
}

Future<void> _upsertUser({
  required AppDatabase db,
  required String companyId,
  required String userId,
  required String accentHex,
}) async {
  final payload =
      '{"id":"$userId","first_name":"A","last_name":"B",'
      '"company_user":{"settings":{"accent_color":"$accentHex"}}}';
  await db.userDao.upsert(
    UsersCompanion(
      id: Value(userId),
      companyId: Value(companyId),
      firstName: const Value('A'),
      lastName: const Value('B'),
      email: const Value(''),
      phone: const Value(''),
      languageId: const Value(''),
      signature: const Value(''),
      updatedAt: const Value(0),
      isDirty: const Value(false),
      payload: Value(payload),
    ),
  );
}

void main() {
  late AppDatabase db;
  late _FakeAuthService authService;
  late AuthRepository auth;
  late UserRepository users;
  late AccentColorController controller;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    authService = _FakeAuthService();
    final apiClient = ApiClient(
      credentials: ValueNotifier<ApiCredentials?>(null),
      passwordCache: PasswordCache(),
      onUnauthorized: () async {},
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
    auth = AuthRepository(
      db: db,
      authService: authService,
      tokenStorage: InMemoryTokenStorage(),
      passwordCache: PasswordCache(),
    );
    users = UserRepository(db: db, api: UsersApi(apiClient));
    controller = AccentColorController(auth: auth, users: users);
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  Future<void> signIn({String userId = 'usr_1'}) async {
    authService.queueLogin(_envelope(userId: userId));
    await auth.login(
      baseUrl: 'https://example.test',
      isHosted: true,
      email: 'a@b',
      password: 'p',
    );
  }

  test('value is null with no session', () {
    expect(controller.value, isNull);
  });

  test('persisted accent emits after watched user upsert', () async {
    await signIn();
    expect(controller.value, isNull);

    await _upsertUser(
      db: db,
      companyId: 'co_a',
      userId: 'usr_1',
      accentHex: '#1F2937',
    );
    await pumpEventQueue();
    expect(controller.value, const Color(0xFF1F2937));
  });

  test('setPreview takes precedence over persisted value', () async {
    await signIn();
    await _upsertUser(
      db: db,
      companyId: 'co_a',
      userId: 'usr_1',
      accentHex: '#1F2937',
    );
    await pumpEventQueue();
    expect(controller.value, const Color(0xFF1F2937));

    controller.setPreview(const Color(0xFFEF4444));
    expect(controller.value, const Color(0xFFEF4444));

    controller.setPreview(null);
    expect(controller.value, const Color(0xFF1F2937));
  });

  test(
    'preview is cleared when persisted catches up to the same color',
    () async {
      await signIn();
      await pumpEventQueue();

      controller.setPreview(const Color(0xFFEF4444));
      expect(controller.value, const Color(0xFFEF4444));

      // Save round-trip: server-confirmed accent now matches the preview.
      await _upsertUser(
        db: db,
        companyId: 'co_a',
        userId: 'usr_1',
        accentHex: '#EF4444',
      );
      await pumpEventQueue();

      expect(controller.value, const Color(0xFFEF4444));

      // The preview must be dropped now — a subsequent server change should
      // take effect without a setPreview(null) call.
      await _upsertUser(
        db: db,
        companyId: 'co_a',
        userId: 'usr_1',
        accentHex: '#16A34A',
      );
      await pumpEventQueue();
      expect(controller.value, const Color(0xFF16A34A));
    },
  );

  test('logout clears the preview', () async {
    await signIn();
    controller.setPreview(const Color(0xFFEF4444));
    expect(controller.value, const Color(0xFFEF4444));

    await auth.logout();
    await pumpEventQueue();
    expect(controller.value, isNull);
  });

  test('notifies once when setPreview changes the resolved value', () async {
    await signIn();
    await pumpEventQueue();

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.setPreview(const Color(0xFFEF4444));
    controller.setPreview(const Color(0xFFEF4444)); // no-op
    expect(notifications, 1);

    controller.setPreview(null);
    expect(notifications, 2);
  });
}
