import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/quickbooks_repository.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Same `_FakeAuthService` shape as `auth_repository_test.dart` — duplicated
/// here rather than imported because the test files own their own test
/// doubles in this codebase (search for the comment block at the top of
/// each repo test).
class _FakeAuthService implements AuthService {
  void queueLogin(LoginResponseApi response) => _outcomes.add(response);

  final List<Object> _outcomes = [];

  @override
  Future<LoginResponseApi> login({
    required String baseUrl,
    required bool isHosted,
    required String email,
    required String password,
    String? oneTimePassword,
    String? secret,
  }) async {
    if (_outcomes.isEmpty) {
      throw StateError('no login outcome queued');
    }
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

LoginResponseApi _envelope() => const LoginResponseApi(
  data: [
    UserCompanyApi(
      isAdmin: true,
      isOwner: true,
      permissions: '',
      company: CompanyEnvelopeApi(id: 'co_a', name: 'Acme'),
      token: SessionTokenApi(token: 'tok_a'),
      account: AccountEnvelopeApi(id: 'acct_1', plan: 'pro'),
    ),
  ],
);

void main() {
  late AppDatabase db;
  late AuthRepository auth;
  late InMemoryTokenStorage storage;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final authService = _FakeAuthService();
    storage = InMemoryTokenStorage();
    auth = AuthRepository(
      db: db,
      authService: authService,
      tokenStorage: storage,
      passwordCache: PasswordCache(),
    );
    authService.queueLogin(_envelope());
    await auth.login(
      baseUrl: 'https://test',
      isHosted: false,
      email: 'a',
      password: 'b',
    );
  });
  tearDown(() async {
    await db.close();
  });

  group('QuickbooksRepository.buildAuthorizeUrl', () {
    test('POSTs `context: quickbooks` to one_time_token and returns the '
        'baseUrl-relative authorize URL with the returned hash', () async {
      http.Request? captured;
      String? capturedBody;
      final fakeHttp = MockClient((req) async {
        captured = req;
        capturedBody = req.body;
        if (req.method == 'POST' && req.url.path == '/api/v1/one_time_token') {
          return http.Response(
            jsonEncode({
              'data': {'hash': 'short_lived_token_abc'},
            }),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      final apiClient = ApiClient(
        credentials: auth.credentials,
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fakeHttp,
      );
      auth.apiClient = apiClient;

      final quickbooks = QuickbooksRepository(apiClient: apiClient, auth: auth);
      final url = await quickbooks.buildAuthorizeUrl();

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v1/one_time_token');
      expect(jsonDecode(capturedBody!), {'context': 'quickbooks'});
      expect(
        url.toString(),
        'https://test/quickbooks/authorize/short_lived_token_abc',
      );
    });

    test('throws StateError when the response is missing the hash', () async {
      final apiClient = ApiClient(
        credentials: auth.credentials,
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: MockClient(
          (req) async =>
              http.Response(jsonEncode({'data': <String, dynamic>{}}), 200),
        ),
      );
      auth.apiClient = apiClient;
      final quickbooks = QuickbooksRepository(apiClient: apiClient, auth: auth);
      await expectLater(quickbooks.buildAuthorizeUrl(), throwsStateError);
    });
  });

  group('QuickbooksRepository.disconnect', () {
    test('POSTs to /quickbooks/disconnect and refreshes the session', () async {
      http.BaseRequest? disconnectReq;
      http.BaseRequest? refreshReq;
      final fakeHttp = MockClient((req) async {
        if (req.method == 'POST' &&
            req.url.path == '/api/v1/quickbooks/disconnect') {
          disconnectReq = req;
          return http.Response('{}', 200);
        }
        if (req.method == 'POST' && req.url.path == '/api/v1/refresh') {
          refreshReq = req;
          return http.Response(jsonEncode(_envelope().toJson()), 200);
        }
        return http.Response('not found', 404);
      });
      final apiClient = ApiClient(
        credentials: auth.credentials,
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fakeHttp,
      );
      auth.apiClient = apiClient;
      final quickbooks = QuickbooksRepository(apiClient: apiClient, auth: auth);

      await quickbooks.disconnect();

      expect(disconnectReq, isNotNull);
      expect(refreshReq, isNotNull);
      // Disconnect doesn't ride the password header; the server tears down
      // the OAuth grant without re-auth.
      expect(disconnectReq!.headers['X-API-PASSWORD-BASE64'], isNull);
    });
  });

  group('QuickbooksRepository.reconnectUrl', () {
    test(
      'POSTs /quickbooks/reconnect_url and returns the parsed url',
      () async {
        http.Request? captured;
        final fakeHttp = MockClient((req) async {
          captured = req;
          if (req.method == 'POST' &&
              req.url.path == '/api/v1/quickbooks/reconnect_url') {
            return http.Response(
              jsonEncode({
                'data': {'reconnect_url': 'https://qb.example/reauth/xyz'},
              }),
              200,
            );
          }
          return http.Response('not found', 404);
        });
        final apiClient = ApiClient(
          credentials: auth.credentials,
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fakeHttp,
        );
        auth.apiClient = apiClient;
        final quickbooks = QuickbooksRepository(
          apiClient: apiClient,
          auth: auth,
        );

        final url = await quickbooks.reconnectUrl();

        expect(captured!.method, 'POST');
        expect(captured!.url.path, '/api/v1/quickbooks/reconnect_url');
        expect(jsonDecode(captured!.body), <String, dynamic>{});
        expect(url.toString(), 'https://qb.example/reauth/xyz');
      },
    );

    test('tolerates a flat {reconnect_url}; throws when absent', () async {
      ApiClient mk(Object body) {
        final c = ApiClient(
          credentials: auth.credentials,
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: MockClient(
            (_) async => http.Response(jsonEncode(body), 200),
          ),
        );
        auth.apiClient = c;
        return c;
      }

      expect(
        (await QuickbooksRepository(
          apiClient: mk({'reconnect_url': 'https://flat/u'}),
          auth: auth,
        ).reconnectUrl()).toString(),
        'https://flat/u',
      );
      await expectLater(
        QuickbooksRepository(
          apiClient: mk({'data': <String, dynamic>{}}),
          auth: auth,
        ).reconnectUrl(),
        throwsStateError,
      );
    });
  });

  group('QuickbooksRepository.triggerImport', () {
    test('POSTs /quickbooks/sync with the per-entity booleans', () async {
      http.Request? captured;
      final fakeHttp = MockClient((req) async {
        captured = req;
        if (req.method == 'POST' && req.url.path == '/api/v1/quickbooks/sync') {
          return http.Response('{}', 200);
        }
        return http.Response('not found', 404);
      });
      final apiClient = ApiClient(
        credentials: auth.credentials,
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fakeHttp,
      );
      auth.apiClient = apiClient;

      await QuickbooksRepository(
        apiClient: apiClient,
        auth: auth,
      ).triggerImport(client: true, product: false, invoice: true);

      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v1/quickbooks/sync');
      expect(jsonDecode(captured!.body), {
        'client': true,
        'product': false,
        'invoice': true,
      });
    });
  });
}
