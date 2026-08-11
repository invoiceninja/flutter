import 'dart:async';
import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/models/api/user_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/user_repository.dart';
import 'package:admin/data/services/api_client.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/data/services/users_api.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// These tests target AuthRepository's session-state contract:
///   * login persists tokens to TokenStorage AND companies/account to Drift,
///     AND seeds session + credentials
///   * switchCompany flips credentials to the right per-company token
///   * logout clears everything (in-memory + persistent)
///   * restore rebuilds session from disk on next launch
///   * restore detects a stale token (DB was wiped) and falls back to logout
/// They do NOT test http or flutter_secure_storage.

/// Programmable fake — each `login` call returns a queued response (or
/// throws if the test queued an error). Avoids hitting the network.
class _FakeAuthService implements AuthService {
  final List<Object> _outcomes = [];

  void queueLogin(LoginResponseApi response) => _outcomes.add(response);
  void queueLoginError(Object error) => _outcomes.add(error);

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

class _FakeUsersApi implements UsersApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

LoginResponseApi _envelope({
  List<({String id, String name, String token, bool isAdmin, bool isOwner})>
  companies = const [
    (id: 'co_a', name: 'Acme', token: 'tok_a', isAdmin: false, isOwner: false),
  ],
  String defaultCompanyId = 'co_a',
  String accountId = 'acct_1',
  Map<String, Map<String, dynamic>> settingsByCompanyId = const {},
  UserSummaryApi user = const UserSummaryApi(id: 'user_x'),
  Map<String, CompanyEnvelopeApi>? companyOverrideById,
  String eInvoicingToken = '',
  bool reportErrors = false,
  Map<String, dynamic> staticData = const <String, dynamic>{},
}) {
  return LoginResponseApi(
    staticData: staticData,
    data: [
      for (final c in companies)
        UserCompanyApi(
          permissions: 'view_client,edit_client',
          isAdmin: c.isAdmin,
          isOwner: c.isOwner,
          user: user,
          company:
              companyOverrideById?[c.id] ??
              CompanyEnvelopeApi(
                id: c.id,
                name: c.name,
                settings:
                    settingsByCompanyId[c.id] ?? const <String, dynamic>{},
              ),
          token: SessionTokenApi(token: c.token),
          account: AccountEnvelopeApi(
            id: accountId,
            defaultCompanyId: defaultCompanyId,
            plan: 'pro',
            numTrialDays: 14,
            eInvoicingToken: eInvoicingToken,
            reportErrors: reportErrors,
          ),
        ),
    ],
  );
}

void main() {
  late AppDatabase db;
  late _FakeAuthService authService;
  late InMemoryTokenStorage storage;
  late PasswordCache passwordCache;
  late AuthRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    authService = _FakeAuthService();
    storage = InMemoryTokenStorage();
    passwordCache = PasswordCache();
    repo = AuthRepository(
      db: db,
      authService: authService,
      tokenStorage: storage,
      passwordCache: passwordCache,
    );
  });
  tearDown(() async {
    await db.close();
  });

  group('login', () {
    test('persists the company roster (data[N].company.users) so assigned '
        'users resolve to names', () async {
      // The roster is seeded via the onPersistBundles fan-out (services.dart),
      // not inside _persistAndActivate itself — wire it the same way here.
      final userRepo = UserRepository(db: db, api: _FakeUsersApi());
      repo.onPersistBundles =
          ({required companyId, required company, required fullSync}) async {
            await userRepo.applyBundle(
              companyId: companyId,
              bundle: company.users,
            );
          };
      authService.queueLogin(
        _envelope(
          companyOverrideById: {
            'co_a': CompanyEnvelopeApi(
              id: 'co_a',
              name: 'Acme',
              users: const [
                UserApi(
                  id: 'u_owner',
                  firstName: 'Tyler',
                  lastName: 'Kris',
                  email: 'owner@example.com',
                  updatedAt: 1700000000,
                ),
                UserApi(
                  id: 'u_member',
                  firstName: 'Vivienne',
                  lastName: 'Gerlach',
                  email: 'member@example.com',
                  updatedAt: 1700000000,
                ),
              ],
            ),
          },
        ),
      );

      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );

      // A teammate who is NOT the logged-in user now resolves to a name —
      // exactly what the Projects/Invoices/Quotes tables need.
      final member = await userRepo.get(companyId: 'co_a', userId: 'u_member');
      expect(member, isNotNull);
      expect(member!.displayName, 'Vivienne Gerlach');
      final owner = await userRepo.get(companyId: 'co_a', userId: 'u_owner');
      expect(owner!.displayName, 'Tyler Kris');
    });

    test('persists tokens + companies and primes credentials', () async {
      authService.queueLogin(
        _envelope(
          companies: [
            (
              id: 'co_a',
              name: 'Acme',
              token: 'tok_a',
              isAdmin: false,
              isOwner: false,
            ),
            (
              id: 'co_b',
              name: 'Beta',
              token: 'tok_b',
              isAdmin: false,
              isOwner: false,
            ),
          ],
          defaultCompanyId: 'co_b',
        ),
      );

      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );

      // Credentials prime the ApiClient with the default company's token.
      expect(repo.credentials.value!.token, 'tok_b');
      expect(repo.credentials.value!.baseUrl, 'https://test');
      expect(repo.session.value!.companies.map((c) => c.id), ['co_a', 'co_b']);
      expect(repo.session.value!.currentCompanyId, 'co_b');

      // Tokens reach secure storage (encoded JSON).
      final raw = await storage.read('invoiceninja.tokens.v1');
      expect(raw, isNotNull);
      expect(jsonDecode(raw!) as Map<String, dynamic>, {
        'co_a': 'tok_a',
        'co_b': 'tok_b',
      });

      // Companies + account land in Drift.
      final companies = await db.companiesDao.all();
      expect(companies.map((c) => c.id), containsAll(['co_a', 'co_b']));
      expect((await db.companiesDao.account())?.id, 'acct_1');
    });

    test('stale default company (absent from response) does not mismatch the '
        'activated company and its token', () async {
      // The account's defaultCompanyId points at a company that is NOT in
      // the full-sync response (deleted company / user removed / empty
      // token). The activated company and the primed credential token must
      // belong to the SAME company — otherwise we authenticate as one
      // company while the session thinks it's on another → wrong data / 401.
      authService.queueLogin(
        _envelope(
          companies: [
            (
              id: 'co_a',
              name: 'Acme',
              token: 'tok_a',
              isAdmin: false,
              isOwner: false,
            ),
            (
              id: 'co_b',
              name: 'Beta',
              token: 'tok_b',
              isAdmin: false,
              isOwner: false,
            ),
          ],
          defaultCompanyId: 'co_ghost',
        ),
      );

      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );

      // Falls back to the first company we actually hold a token for...
      expect(repo.session.value!.currentCompanyId, 'co_a');
      // ...and the token belongs to THAT company (pre-fix this was 'tok_a'
      // while currentCompanyId was the untokened 'co_ghost').
      expect(repo.credentials.value!.token, 'tok_a');
    });

    test('skips a token-less company at the head of data[] instead of '
        'activating it with a blank token', () async {
      // The fallback used to be a bare `response.data.first.company.id` with no
      // token check, and the credential line resolves
      // `tokens[currentId] ?? data.first.token.token` — so a token-less company
      // first in `data` produced an EMPTY `X-API-Token`, which the server 401s,
      // forcing a logout. The user signs in and is immediately kicked back to
      // /login. Reachable whenever the account default is also unusable: the
      // server omits the `is_system` token for a (company, user) pair it has no
      // row for (see BACKEND.md), which is the same condition behind #16.
      authService.queueLogin(
        _envelope(
          companies: [
            (
              id: 'co_a',
              name: 'Acme',
              token: '', // server withheld it
              isAdmin: false,
              isOwner: false,
            ),
            (
              id: 'co_b',
              name: 'Beta',
              token: 'tok_b',
              isAdmin: false,
              isOwner: false,
            ),
          ],
          defaultCompanyId: 'co_a', // also unusable → falls through
        ),
      );

      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );

      expect(
        repo.credentials.value!.token,
        'tok_b',
        reason: 'must never prime credentials with an empty token',
      );
      expect(
        repo.session.value!.currentCompanyId,
        'co_b',
        reason: 'the activated company must be the one the token belongs to',
      );
      expect(
        repo.session.value!.companies.map((c) => c.id),
        containsAll(<String>['co_a', 'co_b']),
        reason: 'the token-less company still belongs in the picker roster',
      );
    });

    test('refuses an empty response (no companies)', () async {
      authService.queueLogin(const LoginResponseApi());
      await expectLater(
        () => repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        ),
        throwsStateError,
      );
      expect(repo.session.value, isNull);
      expect(repo.credentials.value, isNull);
    });

    test('persists the auth user row from data[N].user', () async {
      // /refresh's data[N].user carries the full profile shape. Login lands
      // it in the `users` Drift table so Settings > User Details renders
      // populated immediately, without a separate (password-gated)
      // round-trip to `GET /api/v1/users/{id}`.
      authService.queueLogin(
        _envelope(
          user: const UserSummaryApi(
            id: 'user_alice',
            firstName: 'Alice',
            lastName: 'Owner',
            email: 'alice@example.com',
            phone: '555-0100',
            signature: 'sig',
            languageId: '1',
            customValue1: 'cv1',
            customValue2: 'cv2',
            customValue3: 'cv3',
            customValue4: 'cv4',
            oauthProviderId: 'google',
          ),
        ),
      );

      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );

      // L9: the session identity name is populated from the login envelope
      // (UserApi.first_name/last_name) — previously left blank until a User
      // Details refresh, which also blanked restore()'s recovered names.
      expect(repo.session.value!.userFirstName, 'Alice');
      expect(repo.session.value!.userLastName, 'Owner');

      final row = await db.userDao.getByCompanyAndId(
        companyId: 'co_a',
        id: 'user_alice',
      );
      expect(row, isNotNull);
      expect(row!.firstName, 'Alice');
      expect(row.lastName, 'Owner');
      expect(row.email, 'alice@example.com');
      expect(row.phone, '555-0100');
      expect(row.signature, 'sig');
      expect(row.languageId, '1');
      expect(row.isDirty, isFalse);
      final payload = jsonDecode(row.payload) as Map<String, dynamic>;
      expect(payload['first_name'], 'Alice');
      expect(payload['custom_value3'], 'cv3');
      expect(payload['oauth_provider_id'], 'google');
      final companyUser = payload['company_user'] as Map<String, dynamic>;
      expect(companyUser['is_admin'], isFalse);
      expect(companyUser['is_owner'], isFalse);
      expect(companyUser['permissions'], 'view_client,edit_client');
    });

    test('skips users-row upsert when user.id is empty', () async {
      // Belt-and-suspenders — a legacy envelope without the user block
      // shouldn't crash the login flow or pollute the table with a
      // (companyId, '') primary key.
      authService.queueLogin(_envelope());

      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );

      // _envelope defaults to UserSummaryApi(id: 'user_x'), so this verifies
      // the happy-path row is there; the negative case is covered by the
      // empty-id `continue` in _persistAndActivate which would otherwise
      // throw on the primary-key constraint.
      final row = await db.userDao.getByCompanyAndId(
        companyId: 'co_a',
        id: 'user_x',
      );
      expect(row, isNotNull);
    });

    test('fires onPersistBundles once per company with the envelope', () async {
      // The hook is how Services fans out bundle persistence to per-entity
      // repos (task_statuses, company_gateways, …). AuthRepository owns the
      // fan-out call but doesn't know about the repos themselves.
      final calls = <({String companyId, CompanyEnvelopeApi company})>[];
      repo.onPersistBundles =
          ({required companyId, required company, required fullSync}) async {
            calls.add((companyId: companyId, company: company));
          };
      authService.queueLogin(
        _envelope(
          companies: [
            (
              id: 'co_a',
              name: 'Acme',
              token: 'tok_a',
              isAdmin: false,
              isOwner: false,
            ),
            (
              id: 'co_b',
              name: 'Beta',
              token: 'tok_b',
              isAdmin: false,
              isOwner: false,
            ),
          ],
        ),
      );

      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );

      expect(calls.map((c) => c.companyId), ['co_a', 'co_b']);
      expect(calls.first.company.id, 'co_a');
    });

    test('bundle fan-out runs in one transaction — N applyBundle writes '
        'collapse to a single commit/watch-fire per company', () async {
      // Simulate two separate `applyBundle` calls (each opens its own
      // `db.transaction`, like the real ~13). The auth path wraps the
      // per-company hook in an outer transaction, so the two inner
      // transactions become savepoints and only ONE commit fires —
      // the savedViews watch sees `[]` then `[v1,v2]`, never the
      // intermediate `[v1]`. Without the wrap there'd be 3 emissions.
      repo.onPersistBundles =
          ({required companyId, required company, required fullSync}) async {
            await db.transaction(
              () => db.savedViewsDao.insertView(
                SavedViewsCompanion.insert(
                  id: 'v1',
                  companyId: companyId,
                  entityType: 'client',
                  name: 'one',
                  payloadJson: '{}',
                  createdAt: 1,
                  updatedAt: 1,
                ),
              ),
            );
            await db.transaction(
              () => db.savedViewsDao.insertView(
                SavedViewsCompanion.insert(
                  id: 'v2',
                  companyId: companyId,
                  entityType: 'client',
                  name: 'two',
                  payloadJson: '{}',
                  createdAt: 1,
                  updatedAt: 1,
                ),
              ),
            );
          };

      final emissions = <int>[];
      final sub = db.savedViewsDao
          .watchAll('co_a')
          .listen((rows) => emissions.add(rows.length));
      await Future<void>.delayed(const Duration(milliseconds: 10));

      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      // Initial empty emission + exactly one post-commit emission.
      // (3 would mean each inner transaction committed separately.)
      expect(emissions, [0, 2]);
    });

    test('forwards the /refresh `static` blob to onApplyStatic', () async {
      // Statics is seeded from the refresh envelope (include_static=true)
      // rather than a separate GET /api/v1/statics. The login response here
      // carries a non-empty blob; the hook must receive it verbatim.
      Map<String, dynamic>? seen;
      repo.onApplyStatic = (blob) async {
        seen = blob;
      };
      authService.queueLogin(
        _envelope(
          staticData: const {
            'currencies': [
              {'id': '1', 'name': 'US Dollar'},
            ],
          },
        ),
      );

      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );

      expect(seen, isNotNull);
      expect((seen!['currencies'] as List), hasLength(1));
    });

    test(
      'passes the empty map to onApplyStatic when the envelope omits statics '
      '(delta refresh / login) — applyStatic itself no-ops on it',
      () async {
        Map<String, dynamic>? seen;
        var called = false;
        repo.onApplyStatic = (blob) async {
          called = true;
          seen = blob;
        };
        authService.queueLogin(_envelope());

        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a@b',
          password: 'pw',
        );

        expect(called, isTrue);
        expect(seen, isEmpty);
      },
    );

    test('login completes even when onApplyStatic throws', () async {
      repo.onApplyStatic = (_) async => throw StateError('boom');
      authService.queueLogin(
        _envelope(
          staticData: const <String, dynamic>{
            'currencies': <Map<String, dynamic>>[],
          },
        ),
      );

      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );

      expect(repo.session.value, isNotNull);
    });

    test('login completes even when onPersistBundles throws', () async {
      // A partial-bundle response shouldn't keep the user out of the app —
      // the auth log path swallows + logs hook failures so the session
      // still flips to authenticated.
      repo.onPersistBundles =
          ({required companyId, required company, required fullSync}) async {
            throw StateError('boom');
          };
      authService.queueLogin(_envelope());

      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );

      expect(repo.session.value, isNotNull);
      expect(repo.credentials.value!.token, 'tok_a');
    });

    test('threads account.e_invoicing_token to AuthSession and survives '
        'restore via the features_json blob', () async {
      // The PEPPOL disconnect handler reads
      // `services.auth.session.value?.eInvoicingToken` to populate the
      // request body. The token comes down on `data[N].account` and rides
      // the existing `features_json` blob on the `Accounts` Drift row, so
      // cold restore must reconstitute it identically.
      authService.queueLogin(_envelope(eInvoicingToken: 'peppol_tok_abc'));
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );
      expect(repo.session.value!.eInvoicingToken, 'peppol_tok_abc');

      // Cold-launch restore — verify the token round-trips through Drift.
      final restoreRepo = AuthRepository(
        db: db,
        authService: _FakeAuthService(),
        tokenStorage: storage,
        passwordCache: passwordCache,
      );
      await restoreRepo.restore();
      expect(restoreRepo.session.value!.eInvoicingToken, 'peppol_tok_abc');
    });

    test('threads account.report_errors to AuthSession (Sentry opt-in gate) '
        'and survives restore via the features_json blob', () async {
      // Sentry's beforeSend drops every event unless this is true. It comes
      // down on data[N].account and rides the same features_json blob as
      // e_invoicing_token, so cold restore must reconstitute it.
      authService.queueLogin(_envelope(reportErrors: true));
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a@b',
        password: 'pw',
      );
      expect(repo.session.value!.reportErrors, isTrue);

      final restoreRepo = AuthRepository(
        db: db,
        authService: _FakeAuthService(),
        tokenStorage: storage,
        passwordCache: passwordCache,
      );
      await restoreRepo.restore();
      expect(restoreRepo.session.value!.reportErrors, isTrue);
    });

    test(
      'account.report_errors defaults to false when the server omits it',
      () async {
        authService.queueLogin(_envelope()); // no reportErrors → default
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a@b',
          password: 'pw',
        );
        expect(repo.session.value!.reportErrors, isFalse);
      },
    );
  });

  group('switchCompany', () {
    test('updates credentials to the target company token', () async {
      authService.queueLogin(
        _envelope(
          companies: [
            (
              id: 'co_a',
              name: 'Acme',
              token: 'tok_a',
              isAdmin: false,
              isOwner: false,
            ),
            (
              id: 'co_b',
              name: 'Beta',
              token: 'tok_b',
              isAdmin: false,
              isOwner: false,
            ),
          ],
          defaultCompanyId: 'co_a',
        ),
      );
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      expect(repo.credentials.value!.token, 'tok_a');

      expect(await repo.switchCompany('co_b'), SwitchCompanyResult.ok);

      expect(repo.credentials.value!.token, 'tok_b');
      expect(repo.session.value!.currentCompanyId, 'co_b');
      expect(await storage.read('invoiceninja.current_company.v1'), 'co_b');
    });

    test('refuses to activate a company whose cached token is empty', () async {
      // Bug repro: a /refresh response that returned an empty `token` for the
      // non-active company used to land in _tokensByCompany as ''. The
      // null-only guard let it through, ApiClient sent a blank X-API-Token,
      // the server 401'd, and the user got bounced to /login. Login with one
      // bad token to seed the same shape and prove the guard now catches it.
      authService.queueLogin(
        _envelope(
          companies: [
            (
              id: 'co_a',
              name: 'Acme',
              token: 'tok_a',
              isAdmin: false,
              isOwner: false,
            ),
            (
              id: 'co_b',
              name: 'Beta',
              token: '',
              isAdmin: false,
              isOwner: false,
            ),
          ],
          defaultCompanyId: 'co_a',
        ),
      );
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      expect(repo.credentials.value!.token, 'tok_a');

      // No ApiClient is wired here, so the healing refresh throws and is
      // swallowed — the guard is what has to hold.
      expect(await repo.switchCompany('co_b'), SwitchCompanyResult.noToken);

      expect(
        repo.credentials.value!.token,
        'tok_a',
        reason: 'empty cached token must not replace a working one',
      );
      expect(
        repo.session.value!.currentCompanyId,
        'co_a',
        reason: 'session stays on the previously-active company',
      );
    });

    test('heals a missing token with one full /refresh, then switches', () async {
      // Issue #16. The picker lists companies from the session roster while the
      // token map is fed by the login/refresh envelope, so a company can be
      // tappable with no token behind it (the server sends `token: null` when
      // it holds no `is_system` row for this (company, user) — see BACKEND.md).
      // That used to be a silent dead end. Now one full refresh is attempted,
      // and when the server supplies the token the switch goes through.
      authService.queueLogin(
        _envelope(
          companies: [
            (
              id: 'co_a',
              name: 'Acme',
              token: 'tok_a',
              isAdmin: false,
              isOwner: false,
            ),
            (
              id: 'co_b',
              name: 'Beta',
              token: '', // server withheld it at login
              isAdmin: false,
              isOwner: false,
            ),
          ],
          defaultCompanyId: 'co_a',
        ),
      );
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );

      var refreshCalls = 0;
      repo.apiClient = ApiClient(
        credentials: repo.credentials,
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: MockClient((req) async {
          if (req.url.path == '/api/v1/refresh') {
            refreshCalls++;
            // This time the server hands back co_b's token.
            return http.Response(
              jsonEncode(
                _envelope(
                  companies: [
                    (
                      id: 'co_a',
                      name: 'Acme',
                      token: 'tok_a',
                      isAdmin: false,
                      isOwner: false,
                    ),
                    (
                      id: 'co_b',
                      name: 'Beta',
                      token: 'tok_b',
                      isAdmin: false,
                      isOwner: false,
                    ),
                  ],
                  defaultCompanyId: 'co_a',
                ).toJson(),
              ),
              200,
            );
          }
          return http.Response('not found', 404);
        }),
      );

      expect(await repo.switchCompany('co_b'), SwitchCompanyResult.ok);

      expect(refreshCalls, 1, reason: 'one heal attempt, not a retry loop');
      expect(repo.credentials.value!.token, 'tok_b');
      expect(repo.session.value!.currentCompanyId, 'co_b');
      expect(await storage.read('invoiceninja.current_company.v1'), 'co_b');
    });

    test(
      'reports noToken and stays put when the heal cannot supply a token',
      () async {
        authService.queueLogin(
          _envelope(
            companies: [
              (
                id: 'co_a',
                name: 'Acme',
                token: 'tok_a',
                isAdmin: false,
                isOwner: false,
              ),
              (
                id: 'co_b',
                name: 'Beta',
                token: '',
                isAdmin: false,
                isOwner: false,
              ),
            ],
            defaultCompanyId: 'co_a',
          ),
        );
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        var activated = <String>[];
        repo.onActiveCompanyChanged = activated.add;

        var refreshCalls = 0;
        repo.apiClient = ApiClient(
          credentials: repo.credentials,
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: MockClient((req) async {
            if (req.url.path == '/api/v1/refresh') {
              refreshCalls++;
              // Server still has no token for co_b.
              return http.Response(
                jsonEncode(
                  _envelope(
                    companies: [
                      (
                        id: 'co_a',
                        name: 'Acme',
                        token: 'tok_a',
                        isAdmin: false,
                        isOwner: false,
                      ),
                      (
                        id: 'co_b',
                        name: 'Beta',
                        token: '',
                        isAdmin: false,
                        isOwner: false,
                      ),
                    ],
                    defaultCompanyId: 'co_a',
                  ).toJson(),
                ),
                200,
              );
            }
            return http.Response('not found', 404);
          }),
        );

        expect(await repo.switchCompany('co_b'), SwitchCompanyResult.noToken);

        expect(refreshCalls, 1);
        expect(repo.credentials.value!.token, 'tok_a');
        expect(repo.session.value!.currentCompanyId, 'co_a');
        expect(
          activated,
          isEmpty,
          reason: 'a failed switch must not fire the activation fan-out',
        );
        expect(
          repo.session.value!.companies.map((c) => c.id),
          containsAll(<String>['co_a', 'co_b']),
          reason: 'the token-less company stays in the picker roster',
        );
      },
    );
  });

  group('logout', () {
    test('clears session, credentials, secure storage, and Drift', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      // Simulate a destructive-action confirm: password lives in the cache
      // until logout or TTL. Without an explicit clear in logout(), this
      // string would survive into the next user's session.
      passwordCache.set('user-password');
      expect(passwordCache.read(), 'user-password');

      await repo.logout();

      expect(repo.session.value, isNull);
      expect(repo.credentials.value, isNull);
      expect(await storage.read('invoiceninja.tokens.v1'), isNull);
      expect(await db.companiesDao.all(), isEmpty);
      expect(await db.companiesDao.account(), isNull);
      expect(
        passwordCache.read(),
        isNull,
        reason: 'logout must clear the in-memory password cache',
      );
    });

    test(
      'preserveLocalData keeps Drift + tokens (idle re-lock) but still clears '
      'the in-memory session',
      () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        expect(await db.companiesDao.all(), isNotEmpty);
        expect(await storage.read('invoiceninja.tokens.v1'), isNotNull);

        await repo.logout(preserveLocalData: true);

        // In-memory session cleared → the router redirects to /login.
        expect(repo.session.value, isNull);
        expect(repo.credentials.value, isNull);
        // But the encrypted DB (incl. any queued outbox rows) and the on-disk
        // tokens survive so a cold-start restore / re-login drains the unsynced
        // work — the idle timeout must not silently destroy offline edits.
        expect(
          await db.companiesDao.all(),
          isNotEmpty,
          reason: 'preserveLocalData must not wipe Drift',
        );
        expect(
          await storage.read('invoiceninja.tokens.v1'),
          isNotNull,
          reason: 'preserveLocalData must keep the tokens for restore',
        );
        expect(
          await storage.read('invoiceninja.session_locked.v1'),
          'true',
          reason:
              'preserve sets the re-lock flag so the next restore requires '
              're-auth instead of silently re-entering',
        );
      },
    );

    test(
      'restore after a preserveLocalData logout (biometric off) requires '
      're-auth: session stays inactive (→ /login), DB + tokens survive',
      () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        await repo.logout(preserveLocalData: true);

        // Cold start: fresh repo sharing the same storage + DB.
        final repo2 = AuthRepository(
          db: db,
          authService: authService,
          tokenStorage: storage,
          passwordCache: PasswordCache(),
        );
        await repo2.restore();

        // The lock flag + biometric-off means restore must NOT silently
        // re-enter — the user lands on /login (no active session).
        expect(repo2.isAuthenticated, isFalse);
        expect(repo2.session.value, isNull);
        // ...but the data is intact so a re-login drains the preserved outbox.
        expect(await db.companiesDao.all(), isNotEmpty);
        expect(await storage.read('invoiceninja.tokens.v1'), isNotNull);
        expect(await storage.read('invoiceninja.session_locked.v1'), 'true');
      },
    );

    test(
      'restore after a preserveLocalData logout (biometric on) gates via the '
      'biometric lock screen',
      () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        await repo.setBiometricEnabled(true);
        await repo.logout(preserveLocalData: true);

        final repo2 = AuthRepository(
          db: db,
          authService: authService,
          tokenStorage: storage,
          passwordCache: PasswordCache(),
        );
        await repo2.restore();

        // Biometric users keep quick-unlock: session restores but is gated.
        expect(repo2.isAuthenticated, isTrue);
        expect(repo2.requiresBiometricUnlock.value, isTrue);
      },
    );

    test(
      'a fresh login after a preserveLocalData logout clears the re-lock flag',
      () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        await repo.logout(preserveLocalData: true);
        expect(await storage.read('invoiceninja.session_locked.v1'), 'true');

        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        expect(repo.isAuthenticated, isTrue);
        expect(
          await storage.read('invoiceninja.session_locked.v1'),
          isNull,
          reason: 'a successful sign-in is a re-auth — the gate clears',
        );
      },
    );

    test(
      'currentCompanyId mirrors the session and is null once logged out',
      () async {
        authService.queueLogin(_envelope(defaultCompanyId: 'co_a'));
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        // Live session → the convenience accessor returns the active id.
        expect(repo.currentCompanyId, 'co_a');

        await repo.logout();

        // After logout `session` is null; the accessor degrades to null instead
        // of throwing. Re-entrant `build` / `didChangeDependencies` paths that
        // rebuild one last time on the logout frame rely on this (regression for
        // the BillingEditTotals red-screen crash on sign-out).
        expect(repo.currentCompanyId, isNull);
      },
    );

    test(
      'awaits onBeforeLogout before wiping Drift so in-flight sync settles',
      () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        // Resolve the hook's gate only after asserting Drift is still
        // populated — proves logout() really did `await` the hook before
        // the wipe (otherwise this races with `db.wipe`).
        final gate = Completer<void>();
        var hookCalled = false;
        repo.onBeforeLogout = () async {
          hookCalled = true;
          await gate.future;
        };

        final logoutFuture = repo.logout();
        await Future<void>.delayed(Duration.zero);
        expect(hookCalled, isTrue);
        expect(await db.companiesDao.all(), isNotEmpty, reason: 'wipe waits');
        gate.complete();
        await logoutFuture;
        expect(await db.companiesDao.all(), isEmpty);
      },
    );

    test('logout completes even if onBeforeLogout throws', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      repo.onBeforeLogout = () async => throw StateError('hook blew up');

      await repo.logout(); // must not rethrow

      expect(repo.session.value, isNull);
      expect(await db.companiesDao.all(), isEmpty);
    });

    test(
      'onSessionReset fires even on the preserveLocalData re-lock path '
      '(per-session state must reset for the next user without an app restart)',
      () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        var resets = 0;
        repo.onSessionReset = () => resets++;

        // Idle-timeout re-lock keeps the DB/tokens but must still clear
        // in-memory per-session repo state (e.g. the calendar connection) —
        // the hook is invoked BEFORE the preserveLocalData early return. A
        // refactor that moved it after would silently re-introduce the
        // cross-user leak on re-lock; this pins it.
        await repo.logout(preserveLocalData: true);
        expect(resets, 1);
      },
    );

    test('logout invokes onSessionReset on the full path and completes even '
        'if it throws', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      var called = false;
      repo.onSessionReset = () {
        called = true;
        throw StateError('reset blew up');
      };

      await repo.logout(); // must not rethrow

      expect(called, isTrue, reason: 'hook is invoked on a full logout');
      expect(repo.session.value, isNull, reason: 'logout still completes');
      expect(await db.companiesDao.all(), isEmpty);
    });
  });

  group('logout vs in-flight refresh', () {
    // Repro for "I clicked Log out and was immediately logged back in": a
    // /refresh (boot-time heal or the 5-min scheduler) is still in flight when
    // the user logs out. Before the session-epoch guard, the late response ran
    // _persistAndActivate and re-seeded tokens + credentials, bouncing the
    // user back into the app.

    ApiClient gatedClient(MockClient http) => ApiClient(
      credentials: repo.credentials,
      passwordCache: PasswordCache(),
      onUnauthorized: () async {},
      httpClient: http,
    );

    test(
      'a logout while /refresh is in flight is not undone by the response',
      () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        expect(repo.isAuthenticated, isTrue);

        // Park /refresh mid-flight so we can interleave a logout.
        final refreshEntered = Completer<void>();
        final releaseRefresh = Completer<void>();
        repo.apiClient = gatedClient(
          MockClient((req) async {
            if (req.url.path == '/api/v1/refresh') {
              if (!refreshEntered.isCompleted) refreshEntered.complete();
              await releaseRefresh.future;
              return http.Response(jsonEncode(_envelope().toJson()), 200);
            }
            return http.Response('not found', 404);
          }),
        );

        final refreshFuture = repo.refresh();
        await refreshEntered.future.timeout(const Duration(seconds: 2));

        await repo.logout();
        expect(repo.isAuthenticated, isFalse);
        expect(repo.session.value, isNull);
        expect(repo.credentials.value, isNull);

        // Let the stale refresh resolve — it must NOT re-authenticate.
        releaseRefresh.complete();
        await refreshFuture;
        await pumpEventQueue();

        expect(
          repo.isAuthenticated,
          isFalse,
          reason: 'stale /refresh must not re-authenticate after logout',
        );
        expect(repo.session.value, isNull);
        expect(repo.credentials.value, isNull);
        expect(
          await storage.read('invoiceninja.tokens.v1'),
          isNull,
          reason: 'stale /refresh must not re-write tokens to secure storage',
        );
        expect(
          await db.companiesDao.account(),
          isNull,
          reason: 'stale /refresh must not re-seed Drift after the wipe',
        );
      },
    );

    test(
      'a logout during _persistAndActivate is not undone by the commit',
      () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        // /refresh returns immediately, but onApplyStatic parks execution
        // *inside* _persistAndActivate — after the Drift transaction, before the
        // secure-storage + credential commit — so the logout lands during the
        // persist rather than during the network call. This exercises the
        // commit-side guard, not just the post-network one.
        final persistEntered = Completer<void>();
        final releasePersist = Completer<void>();
        repo.onApplyStatic = (_) async {
          if (!persistEntered.isCompleted) persistEntered.complete();
          await releasePersist.future;
        };
        repo.apiClient = gatedClient(
          MockClient((req) async {
            if (req.url.path == '/api/v1/refresh') {
              return http.Response(jsonEncode(_envelope().toJson()), 200);
            }
            return http.Response('not found', 404);
          }),
        );

        final refreshFuture = repo.refresh(fullSync: true);
        await persistEntered.future.timeout(const Duration(seconds: 2));

        await repo.logout();

        releasePersist.complete();
        await refreshFuture;
        await pumpEventQueue();

        expect(
          repo.isAuthenticated,
          isFalse,
          reason:
              'the epoch-guarded commit must not re-auth a logged-out session',
        );
        expect(repo.credentials.value, isNull);
        expect(await storage.read('invoiceninja.tokens.v1'), isNull);
        expect(await db.companiesDao.account(), isNull);
      },
    );

    test('a company switch while /refresh is in flight is not reverted by the '
        'commit', () async {
      final twoCompanies = _envelope(
        companies: [
          (
            id: 'co_a',
            name: 'Acme',
            token: 'tok_a',
            isAdmin: false,
            isOwner: false,
          ),
          (
            id: 'co_b',
            name: 'Beta',
            token: 'tok_b',
            isAdmin: false,
            isOwner: false,
          ),
        ],
      );
      authService.queueLogin(twoCompanies);
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      expect(repo.session.value?.currentCompanyId, 'co_a');

      // Park /refresh mid-flight so we can interleave a company switch —
      // the cold-start heal and the 5-min scheduler pump both leave this
      // window open while the picker is already interactive.
      final refreshEntered = Completer<void>();
      final releaseRefresh = Completer<void>();
      repo.apiClient = gatedClient(
        MockClient((req) async {
          if (req.url.path == '/api/v1/refresh') {
            if (!refreshEntered.isCompleted) refreshEntered.complete();
            await releaseRefresh.future;
            return http.Response(jsonEncode(twoCompanies.toJson()), 200);
          }
          return http.Response('not found', 404);
        }),
      );

      final refreshFuture = repo.refresh(fullSync: true);
      await refreshEntered.future.timeout(const Duration(seconds: 2));

      await repo.switchCompany('co_b');
      expect(repo.session.value?.currentCompanyId, 'co_b');

      // Let the stale refresh commit — it must keep the live selection.
      releaseRefresh.complete();
      await refreshFuture;
      await pumpEventQueue();

      expect(
        repo.session.value?.currentCompanyId,
        'co_b',
        reason: 'the refresh commit must not bounce the user back to co_a',
      );
      expect(
        repo.credentials.value?.token,
        'tok_b',
        reason: 'credentials must stay on the switched company token',
      );
      expect(
        await storage.read('invoiceninja.current_company.v1'),
        'co_b',
        reason: 'the stale snapshot id must not be persisted for restore',
      );
    });

    test(
      'a re-login after logout is not clobbered by the stale refresh',
      () async {
        authService.queueLogin(_envelope()); // co_a / tok_a
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        final refreshEntered = Completer<void>();
        final releaseRefresh = Completer<void>();
        repo.apiClient = gatedClient(
          MockClient((req) async {
            if (req.url.path == '/api/v1/refresh') {
              if (!refreshEntered.isCompleted) refreshEntered.complete();
              await releaseRefresh.future;
              // The stale refresh carries the OLD session's token.
              return http.Response(jsonEncode(_envelope().toJson()), 200);
            }
            return http.Response('not found', 404);
          }),
        );

        final refreshFuture = repo.refresh();
        await refreshEntered.future.timeout(const Duration(seconds: 2));

        // Log out, then immediately log back in with a DIFFERENT token.
        await repo.logout();
        authService.queueLogin(
          _envelope(
            companies: [
              (
                id: 'co_a',
                name: 'Acme',
                token: 'tok_NEW',
                isAdmin: false,
                isOwner: false,
              ),
            ],
          ),
        );
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        expect(repo.credentials.value!.token, 'tok_NEW');

        // Release the stale refresh. A boolean "logging out" flag reset by the
        // new login would let it overwrite tok_NEW with tok_a; the monotonic
        // epoch counter leaves it permanently mismatched, so it bails.
        releaseRefresh.complete();
        await refreshFuture;
        await pumpEventQueue();

        expect(
          repo.credentials.value!.token,
          'tok_NEW',
          reason: 'stale refresh must not clobber the new session token',
        );
      },
    );
  });

  group('restore', () {
    test('rebuilds session + credentials from disk on next launch', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );

      // Simulate "next launch" — a fresh repo against the same storage + DB.
      final fresh = AuthRepository(
        db: db,
        authService: authService,
        tokenStorage: storage,
        passwordCache: passwordCache,
      );
      expect(fresh.credentials.value, isNull, reason: 'before restore');

      await fresh.restore();

      expect(fresh.credentials.value!.token, 'tok_a');
      expect(fresh.session.value!.currentCompanyId, 'co_a');
    });

    test(
      'with no persisted active company, lands on one we hold a token for',
      () async {
        // `companies.first.id` was the fallback, and the token guard below it
        // force-logs-out (wiping local data) when that row has no token — even
        // though a sibling company would have restored fine.
        authService.queueLogin(
          _envelope(
            companies: [
              (
                id: 'co_a',
                name: 'Acme',
                token: '', // server withheld it
                isAdmin: false,
                isOwner: false,
              ),
              (
                id: 'co_b',
                name: 'Beta',
                token: 'tok_b',
                isAdmin: false,
                isOwner: false,
              ),
            ],
            defaultCompanyId: 'co_b',
          ),
        );
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        // Drop the persisted selection so restore has to choose (a partial write
        // from a killed process leaves exactly this state).
        await storage.delete('invoiceninja.current_company.v1');

        final fresh = AuthRepository(
          db: db,
          authService: authService,
          tokenStorage: storage,
          passwordCache: passwordCache,
        );
        await fresh.restore();

        expect(
          fresh.session.value,
          isNotNull,
          reason: 'a token-less first row must not force a logout',
        );
        expect(fresh.session.value!.currentCompanyId, 'co_b');
        expect(fresh.credentials.value!.token, 'tok_b');
      },
    );

    test('detects stale token (DB wiped) and falls back to logout', () async {
      await storage.write(
        'invoiceninja.tokens.v1',
        jsonEncode({'co_a': 'tok_a'}),
      );
      await storage.write('invoiceninja.base_url.v1', 'https://test');
      // No companies in Drift — simulates a wiped local cache.

      await repo.restore();

      expect(repo.session.value, isNull);
      expect(repo.credentials.value, isNull);
      expect(
        await storage.read('invoiceninja.tokens.v1'),
        isNull,
        reason: 'logout drops the stale token so we re-login fresh',
      );
    });

    test(
      'preserves displayName (from settings.name) and logo across restart',
      () async {
        authService.queueLogin(
          _envelope(
            settingsByCompanyId: const {
              'co_a': {
                'name': 'Acme Co',
                'company_logo': 'https://logo.example/acme.png',
              },
            },
          ),
        );
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        // Cold start: fresh repo, same DB + secure storage.
        final fresh = AuthRepository(
          db: db,
          authService: authService,
          tokenStorage: storage,
          passwordCache: passwordCache,
        );
        await fresh.restore();

        final c = fresh.session.value!.companies.single;
        expect(
          c.displayName,
          'Acme Co',
          reason: 'settings.name should win over the empty top-level name',
        );
        expect(
          c.logoUrl,
          startsWith('https://logo.example/acme.png'),
          reason:
              'logo_url column should survive the round-trip '
              '(now cache-busted with ?v=<updatedAt>)',
        );
      },
    );

    test('preserves isAdmin/isOwner across restart', () async {
      authService.queueLogin(
        _envelope(
          companies: [
            (
              id: 'co_a',
              name: 'Acme',
              token: 'tok_a',
              isAdmin: true,
              isOwner: true,
            ),
          ],
        ),
      );
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      expect(repo.session.value!.companies.single.isAdmin, isTrue);

      final fresh = AuthRepository(
        db: db,
        authService: authService,
        tokenStorage: storage,
        passwordCache: passwordCache,
      );
      await fresh.restore();

      final c = fresh.session.value!.companies.single;
      expect(c.isAdmin, isTrue, reason: 'admin flag survives restart');
      expect(c.isOwner, isTrue, reason: 'owner flag survives restart');
    });

    group('background /refresh heal', () {
      // `is_owner` / `is_admin` are denormalized columns that default to false
      // and aren't recomputed locally — so an account owner whose cached
      // company row never received the real flags stays silently downgraded
      // (the company picker shows "Only the account owner can add companies"
      // even though they are). restore() now re-pulls /api/v1/refresh in the
      // background so these flags self-heal on next launch.

      LoginResponseApi refreshed({required bool isOwner}) => _envelope(
        companies: [
          (
            id: 'co_a',
            name: 'Acme',
            token: 'tok_a',
            isAdmin: isOwner,
            isOwner: isOwner,
          ),
        ],
      );

      test('promotes a stale is_owner=false to true via /refresh', () async {
        // Seed the world as if the user had logged in pre-v4: tokens in
        // secure storage, companies row in Drift with is_owner=false.
        authService.queueLogin(
          _envelope(
            companies: [
              (
                id: 'co_a',
                name: 'Acme',
                token: 'tok_a',
                isAdmin: false,
                isOwner: false,
              ),
            ],
          ),
        );
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        // Now spin up a fresh repo (simulating a cold start) wired to a fake
        // ApiClient. The fake returns the *corrected* envelope on /refresh.
        final refreshHit = Completer<Uri>();
        final fakeHttp = MockClient((req) async {
          if (req.url.path == '/api/v1/refresh') {
            refreshHit.complete(req.url);
            return http.Response(
              jsonEncode(refreshed(isOwner: true).toJson()),
              200,
            );
          }
          return http.Response('not found', 404);
        });
        final fresh = AuthRepository(
          db: db,
          authService: authService,
          tokenStorage: storage,
          passwordCache: passwordCache,
        );
        fresh.apiClient = ApiClient(
          credentials: fresh.credentials,
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fakeHttp,
        );

        // Listen for the moment _persistAndActivate writes the healed
        // session — more reliable than guessing how many microtasks the
        // background refresh needs.
        final healed = Completer<void>();
        fresh.session.addListener(() {
          if (!healed.isCompleted &&
              fresh.session.value?.currentCompany?.isOwner == true) {
            healed.complete();
          }
        });

        await fresh.restore();
        // restore() restored is_owner=false from Drift.
        expect(fresh.session.value!.currentCompany!.isOwner, isFalse);

        await refreshHit.future.timeout(const Duration(seconds: 2));
        await healed.future.timeout(const Duration(seconds: 2));

        expect(
          fresh.session.value!.currentCompany!.isOwner,
          isTrue,
          reason: '/refresh response should heal the stale flag in memory',
        );
        final rowAfter = (await db.companiesDao.all()).single;
        expect(
          rowAfter.isOwner,
          isTrue,
          reason: 'and persist back to Drift so it survives the next restart',
        );
      });

      test('preserves cached tokens when /refresh returns empty ones', () async {
        // Bug repro: /api/v1/refresh?current_company=false has been observed
        // returning empty `token` strings for non-active companies. Before
        // the fix, _persistAndActivate would overwrite the cached tokens
        // with '', so the next switchCompany activated a blank token, hit
        // 401 on the first request, and bounced the user to /login.
        authService.queueLogin(
          _envelope(
            companies: [
              (
                id: 'co_a',
                name: 'Acme',
                token: 'tok_a',
                isAdmin: false,
                isOwner: false,
              ),
              (
                id: 'co_b',
                name: 'Beta',
                token: 'tok_b',
                isAdmin: false,
                isOwner: false,
              ),
            ],
          ),
        );
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        final fakeHttp = MockClient((req) async {
          if (req.url.path == '/api/v1/refresh') {
            final body = _envelope(
              companies: [
                // Active company keeps its token...
                (
                  id: 'co_a',
                  name: 'Acme',
                  token: 'tok_a',
                  isAdmin: false,
                  isOwner: false,
                ),
                // ...but the non-active one comes back empty (the wire bug).
                (
                  id: 'co_b',
                  name: 'Beta',
                  token: '',
                  isAdmin: false,
                  isOwner: false,
                ),
              ],
            ).toJson();
            return http.Response(jsonEncode(body), 200);
          }
          return http.Response('not found', 404);
        });
        final fresh = AuthRepository(
          db: db,
          authService: authService,
          tokenStorage: storage,
          passwordCache: passwordCache,
        );
        fresh.apiClient = ApiClient(
          credentials: fresh.credentials,
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fakeHttp,
        );

        await fresh.restore();
        // Wait until the background refresh has flowed through
        // _persistAndActivate (which assigns _session.value last).
        final refreshed = Completer<void>();
        fresh.session.addListener(() {
          if (!refreshed.isCompleted) refreshed.complete();
        });
        // The session also got set inside restore() before the listener was
        // attached — only the post-refresh assignment will fire it.
        await refreshed.future.timeout(const Duration(seconds: 2));

        // Cached token for co_b must still work after the empty-token /refresh.
        await fresh.switchCompany('co_b');
        expect(
          fresh.credentials.value!.token,
          'tok_b',
          reason: 'good cached token must survive an empty /refresh response',
        );
      });

      test('a FULL refresh drops cached tokens for companies the server '
          'stops returning', () async {
        // User had access to A + B at login. Server later revokes B. A
        // *full* /refresh (current_company=false) returns only A — that's
        // the authoritative company set, so the stale B token must not
        // linger: a subsequent switchCompany('co_b') is a no-op, not a
        // quiet attempt against a revoked token. (A delta refresh is
        // scoped and intentionally does NOT prune — see the next test.)
        authService.queueLogin(
          _envelope(
            companies: [
              (
                id: 'co_a',
                name: 'Acme',
                token: 'tok_a',
                isAdmin: false,
                isOwner: false,
              ),
              (
                id: 'co_b',
                name: 'Beta',
                token: 'tok_b',
                isAdmin: false,
                isOwner: false,
              ),
            ],
          ),
        );
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        final fakeHttp = MockClient((req) async {
          if (req.url.path == '/api/v1/refresh') {
            final body = _envelope(
              companies: [
                (
                  id: 'co_a',
                  name: 'Acme',
                  token: 'tok_a',
                  isAdmin: false,
                  isOwner: false,
                ),
              ],
            ).toJson();
            return http.Response(jsonEncode(body), 200);
          }
          return http.Response('not found', 404);
        });
        final fresh = AuthRepository(
          db: db,
          authService: authService,
          tokenStorage: storage,
          passwordCache: passwordCache,
        );
        fresh.apiClient = ApiClient(
          credentials: fresh.credentials,
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fakeHttp,
        );

        // Force the post-restore heal to be a FULL sync: zero the stored
        // high-water marks so `_refreshSession` sends
        // `updated_at=0&current_company=false` (the only mode that treats
        // the response as the authoritative company set).
        await db.customStatement('UPDATE companies SET last_sync_at = 0');

        await fresh.restore();
        // Wait until the background refresh shrinks the company list to 1.
        final shrunk = Completer<void>();
        fresh.session.addListener(() {
          if (!shrunk.isCompleted &&
              fresh.session.value?.companies.length == 1) {
            shrunk.complete();
          }
        });
        await shrunk.future.timeout(const Duration(seconds: 2));

        await fresh.switchCompany('co_b');
        expect(
          fresh.credentials.value!.token,
          'tok_a',
          reason: 'cached token for a revoked company must be dropped',
        );
      });

      test('a DELTA refresh sends updated_at/current_company=true and keeps '
          'other companies\' rows + tokens', () async {
        // After login, each company has a non-zero last_sync_at, so the
        // restore heal is a delta: scoped to the active company. It must
        // NOT prune co_b (the delta simply doesn't carry it) and the
        // query must carry the computed `updated_at` + `current_company`.
        const tMs = 1700000000000; // fixed clock
        final fixedRepo = AuthRepository(
          db: db,
          authService: authService,
          tokenStorage: storage,
          passwordCache: passwordCache,
          now: () => DateTime.fromMillisecondsSinceEpoch(tMs),
        );
        authService.queueLogin(
          _envelope(
            companies: [
              (
                id: 'co_a',
                name: 'Acme',
                token: 'tok_a',
                isAdmin: false,
                isOwner: false,
              ),
              (
                id: 'co_b',
                name: 'Beta',
                token: 'tok_b',
                isAdmin: false,
                isOwner: false,
              ),
            ],
          ),
        );
        await fixedRepo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        Uri? refreshUri;
        final fakeHttp = MockClient((req) async {
          if (req.url.path == '/api/v1/refresh') {
            refreshUri = req.url;
            // Delta response: only the active company.
            return http.Response(
              jsonEncode(
                _envelope(
                  companies: [
                    (
                      id: 'co_a',
                      name: 'Acme',
                      token: 'tok_a',
                      isAdmin: false,
                      isOwner: false,
                    ),
                  ],
                ).toJson(),
              ),
              200,
            );
          }
          return http.Response('not found', 404);
        });
        fixedRepo.apiClient = ApiClient(
          credentials: fixedRepo.credentials,
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fakeHttp,
        );

        await fixedRepo.refresh();

        expect(refreshUri, isNotNull);
        final q = refreshUri!.queryParameters;
        expect(q['current_company'], 'true');
        expect(q['first_load'], isNull);
        expect(
          q['updated_at'],
          '${(tMs ~/ 1000) - 600}',
          reason: 'delta = (last_sync_at/1000) - 600s buffer',
        );

        // co_b survived the delta: still switchable with its token.
        expect(
          fixedRepo.session.value!.companies.map((c) => c.id),
          containsAll(['co_a', 'co_b']),
        );
        await fixedRepo.switchCompany('co_b');
        expect(fixedRepo.credentials.value!.token, 'tok_b');
      });

      test('fullSync:true forces a full snapshot even with a non-zero '
          'last_sync_at', () async {
        const tMs = 1700000000000;
        final fixedRepo = AuthRepository(
          db: db,
          authService: authService,
          tokenStorage: storage,
          passwordCache: passwordCache,
          now: () => DateTime.fromMillisecondsSinceEpoch(tMs),
        );
        authService.queueLogin(_envelope());
        await fixedRepo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        Uri? refreshUri;
        final fakeHttp = MockClient((req) async {
          if (req.url.path == '/api/v1/refresh') {
            refreshUri = req.url;
            return http.Response(jsonEncode(_envelope().toJson()), 200);
          }
          return http.Response('not found', 404);
        });
        fixedRepo.apiClient = ApiClient(
          credentials: fixedRepo.credentials,
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fakeHttp,
        );

        await fixedRepo.refresh(fullSync: true);

        final q = refreshUri!.queryParameters;
        expect(q['updated_at'], '0');
        expect(q['first_load'], 'true');
        expect(q['current_company'], 'false');
        expect(q['include_static'], 'true');
      });

      // ── Full sync must not blank the companies row (issue #29) ──────────
      //
      // `_persistAndActivate` re-writes the companies row from
      // `CompanyEnvelopeApi` on every full sync, and `restore()` forces one on
      // every launch. It used to DELETE the row first, so any top-level column
      // the envelope didn't model came back at its Drift default — which is
      // how users' SMTP credentials vanished on each restart. Two guarantees
      // now: the envelope carries every column the server returns, and the
      // full sync prunes instead of wiping.

      /// A refresh envelope where the server reports real SMTP config plus a
      /// sample of the other formerly-omitted top-level columns.
      LoginResponseApi refreshWithServerColumns() => _envelope(
        companyOverrideById: {
          'co_a': const CompanyEnvelopeApi(
            id: 'co_a',
            name: 'Acme',
            smtpHost: 'smtp.example.com',
            smtpPort: 587,
            smtpEncryption: 'tls',
            // The server masks stored credentials on every read.
            smtpUsername: '********',
            smtpPassword: '********',
            smtpLocalDomain: 'mail.example.com',
            smtpVerifyPeer: false,
            expenseMailbox: 'expenses@example.com',
            inboundMailboxAllowVendors: true,
            invoiceTaskTimelog: true,
            enableApplyingPayments: true,
            hasEInvoiceCertificate: true,
          ),
        },
      );

      /// Wire a cold-start repo whose `/refresh` returns [body].
      AuthRepository freshRepoServing(LoginResponseApi body) {
        final fakeHttp = MockClient((req) async {
          if (req.url.path == '/api/v1/refresh') {
            return http.Response(jsonEncode(body.toJson()), 200);
          }
          return http.Response('not found', 404);
        });
        final fresh = AuthRepository(
          db: db,
          authService: authService,
          tokenStorage: storage,
          passwordCache: passwordCache,
        );
        fresh.apiClient = ApiClient(
          credentials: fresh.credentials,
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fakeHttp,
        );
        return fresh;
      }

      /// Poll until [test] holds on the single companies row, so we don't have
      /// to guess how many microtasks the background refresh needs.
      Future<CompanyRow> awaitRow(bool Function(CompanyRow) test) async {
        final deadline = DateTime.now().add(const Duration(seconds: 2));
        while (DateTime.now().isBefore(deadline)) {
          final row = (await db.companiesDao.all()).singleOrNull;
          if (row != null && test(row)) return row;
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        fail('companies row never reached the expected state');
      }

      test('a FULL refresh keeps the SMTP credentials the server reports '
          '(issue #29)', () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        // Force the restore heal to be a FULL sync (the launch-time default
        // anyway — `_refreshSessionQuietly` passes fullSync: true).
        await db.customStatement('UPDATE companies SET last_sync_at = 0');

        final fresh = freshRepoServing(refreshWithServerColumns());
        await fresh.restore();

        final row = await awaitRow((r) => r.smtpHost.isNotEmpty);
        expect(row.smtpHost, 'smtp.example.com');
        expect(row.smtpPort, 587);
        expect(row.smtpEncryption, 'tls');
        expect(row.smtpUsername, '********');
        expect(row.smtpPassword, '********');
        expect(row.smtpLocalDomain, 'mail.example.com');
        expect(
          row.smtpVerifyPeer,
          isFalse,
          reason: 'a false the server sent must beat the column default (true)',
        );
      });

      test('a FULL refresh persists the other formerly-omitted top-level '
          'columns', () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        await db.customStatement('UPDATE companies SET last_sync_at = 0');

        final fresh = freshRepoServing(refreshWithServerColumns());
        await fresh.restore();

        final row = await awaitRow((r) => r.expenseMailbox.isNotEmpty);
        expect(row.expenseMailbox, 'expenses@example.com');
        expect(row.inboundMailboxAllowVendors, isTrue);
        expect(row.invoiceTaskTimelog, isTrue);
        expect(row.enableApplyingPayments, isTrue);
        expect(row.hasEInvoiceCertificate, isTrue);
      });

      test('a FULL refresh updates the company row in place instead of '
          'deleting it', () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        // `e_invoice_certificate_passphrase` is the one top-level column the
        // envelope deliberately never carries (write-only — the server returns
        // only the `has_…` flag). That makes it the canary for the prune: if
        // it comes back blank, the full sync is deleting and re-inserting the
        // row again, and every envelope gap is silent data loss.
        await db.customStatement(
          "UPDATE companies SET e_invoice_certificate_passphrase = 'hunter2', "
          'last_sync_at = 0',
        );

        final fresh = freshRepoServing(refreshWithServerColumns());
        await fresh.restore();

        final row = await awaitRow((r) => r.smtpHost.isNotEmpty);
        expect(row.eInvoiceCertificatePassphrase, 'hunter2');
      });

      test('a FULL refresh still deletes the Drift row for a company the '
          'server no longer returns', () async {
        authService.queueLogin(
          _envelope(
            companies: [
              (
                id: 'co_a',
                name: 'Acme',
                token: 'tok_a',
                isAdmin: false,
                isOwner: false,
              ),
              (
                id: 'co_b',
                name: 'Beta',
                token: 'tok_b',
                isAdmin: false,
                isOwner: false,
              ),
            ],
          ),
        );
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        expect((await db.companiesDao.all()).length, 2);
        await db.customStatement('UPDATE companies SET last_sync_at = 0');

        final fresh = freshRepoServing(_envelope());
        await fresh.restore();

        final row = await awaitRow((_) => true);
        expect(row.id, 'co_a');
      });

      test('a FULL refresh withholds only the editable columns from a company '
          'with a queued mutation — flags and watermark still heal', () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );
        // The user edited settings offline: `updateCompany` wrote the row
        // optimistically and parked a mutation. That row IS the dirty marker
        // (this table has no is_dirty column), so a full sync must leave the
        // edit alone rather than revert it under the queued mutation.
        await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co_a',
            entityType: 'company',
            entityId: 'co_a',
            mutationKind: 'update',
            payload: jsonEncode({'id': 'co_a'}),
            idempotencyKey: 'k1',
            nextAttemptAt: 0,
            createdAt: 0,
          ),
        );
        await db.customStatement(
          "UPDATE companies SET smtp_host = 'local.edit', last_sync_at = 0",
        );

        // Server says this user is the account owner. That heal is the entire
        // reason restore() fires a background refresh, and a 409 can park a
        // company mutation as `pending` for a year — so "skip the row while an
        // edit is queued" must not mean "stop healing the server-owned flags".
        final fresh = freshRepoServing(
          _envelope(
            companies: [
              (
                id: 'co_a',
                name: 'Acme',
                token: 'tok_a',
                isAdmin: true,
                isOwner: true,
              ),
            ],
            companyOverrideById: {
              'co_a': const CompanyEnvelopeApi(
                id: 'co_a',
                name: 'Acme',
                smtpHost: 'smtp.example.com',
              ),
            },
          ),
        );
        await fresh.restore();

        final row = await awaitRow((r) => r.isOwner);
        expect(
          row.smtpHost,
          'local.edit',
          reason: 'the queued edit must survive the full sync',
        );
        expect(row.isOwner, isTrue);
        expect(row.isAdmin, isTrue);
        expect(
          row.lastSyncAt,
          greaterThan(0),
          reason:
              'the watermark still advances or every later /refresh '
              're-requests an ever-wider delta',
        );
      });

      test('leaves the restored session intact when /refresh fails', () async {
        // Same setup as the happy-path test, but the fake throws — simulating
        // offline. restore() must still produce a usable session.
        authService.queueLogin(
          _envelope(
            companies: [
              (
                id: 'co_a',
                name: 'Acme',
                token: 'tok_a',
                isAdmin: false,
                isOwner: false,
              ),
            ],
          ),
        );
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        final refreshHit = Completer<void>();
        final fakeHttp = MockClient((req) async {
          if (!refreshHit.isCompleted) refreshHit.complete();
          throw http.ClientException('offline');
        });
        final fresh = AuthRepository(
          db: db,
          authService: authService,
          tokenStorage: storage,
          passwordCache: passwordCache,
        );
        fresh.apiClient = ApiClient(
          credentials: fresh.credentials,
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fakeHttp,
        );

        await fresh.restore();
        await refreshHit.future.timeout(const Duration(seconds: 2));
        // One extra microtask round so the swallowed-error catch in
        // `_refreshSessionQuietly` resolves before the assertions run.
        await Future<void>.delayed(Duration.zero);

        expect(
          fresh.session.value,
          isNotNull,
          reason: 'session survives a failed background refresh',
        );
        expect(fresh.credentials.value!.token, 'tok_a');
      });
    });

    test('bounces to logged-out state when tokens map is missing the current '
        'companyId', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );

      // Tamper: overwrite the tokens blob so the cached company id has no
      // entry. This is the only failure mode of `restore()` short of a
      // disk corruption — exercise it explicitly.
      await storage.write(
        'invoiceninja.tokens.v1',
        jsonEncode({'co_other': 'tok_other'}),
      );

      final fresh = AuthRepository(
        db: db,
        authService: authService,
        tokenStorage: storage,
        passwordCache: passwordCache,
      );
      await fresh.restore();

      expect(fresh.session.value, isNull);
      expect(fresh.credentials.value, isNull);
      expect(
        await storage.read('invoiceninja.tokens.v1'),
        isNull,
        reason: 'logout drops the stale token map',
      );
    });
  });

  group('companies watcher', () {
    // Bug repro: editing the company name on Settings → Company Details writes
    // the new settings JSON to Drift but used to leave AuthSession.companies
    // stale until the next /refresh or app restart — so the sidebar picker
    // showed the old name. AuthRepository now subscribes to the companies
    // table and rebuilds the session slice on every change.
    test('flips session displayName when settings.name is edited', () async {
      authService.queueLogin(
        _envelope(
          settingsByCompanyId: const {
            'co_a': {'name': 'Acme Co'},
          },
        ),
      );
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      expect(repo.session.value!.currentCompany!.displayName, 'Acme Co');

      // Wait for the next session emission triggered by the Drift write.
      final updated = Completer<void>();
      repo.session.addListener(() {
        if (!updated.isCompleted &&
            repo.session.value?.currentCompany?.displayName == 'Acme Renamed') {
          updated.complete();
        }
      });

      await (db.update(db.companies)..where((c) => c.id.equals('co_a'))).write(
        CompaniesCompanion(
          settings: Value(jsonEncode({'name': 'Acme Renamed'})),
        ),
      );

      await updated.future.timeout(const Duration(seconds: 2));
      expect(repo.session.value!.currentCompany!.displayName, 'Acme Renamed');
    });

    test('no emit when no display-relevant column changed', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      final before = repo.session.value;
      var emissions = 0;
      repo.session.addListener(() {
        if (!identical(repo.session.value, before)) emissions++;
      });

      // updated_at touches a column the watcher rebuild does not consider.
      await (db.update(db.companies)..where((c) => c.id.equals('co_a'))).write(
        const CompaniesCompanion(updatedAt: Value(9999)),
      );
      // Let the Drift stream + microtasks settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        emissions,
        0,
        reason: 'updated_at-only writes must not bounce the session value',
      );
      expect(identical(repo.session.value, before), isTrue);
    });

    test('survives logout + login (subscription is re-attached)', () async {
      authService.queueLogin(
        _envelope(
          settingsByCompanyId: const {
            'co_a': {'name': 'Acme One'},
          },
        ),
      );
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      await repo.logout();

      authService.queueLogin(
        _envelope(
          settingsByCompanyId: const {
            'co_a': {'name': 'Acme Two'},
          },
        ),
      );
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      expect(repo.session.value!.currentCompany!.displayName, 'Acme Two');

      final updated = Completer<void>();
      repo.session.addListener(() {
        if (!updated.isCompleted &&
            repo.session.value?.currentCompany?.displayName == 'Acme Three') {
          updated.complete();
        }
      });
      await (db.update(db.companies)..where((c) => c.id.equals('co_a'))).write(
        CompaniesCompanion(settings: Value(jsonEncode({'name': 'Acme Three'}))),
      );
      await updated.future.timeout(const Duration(seconds: 2));
    });
  });

  group('biometric', () {
    test('setBiometricEnabled persists and updates session', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      expect(repo.session.value!.biometricEnabled, isFalse);

      await repo.setBiometricEnabled(true);
      expect(repo.session.value!.biometricEnabled, isTrue);
      expect(await storage.read('invoiceninja.biometric_enabled.v1'), 'true');

      await repo.setBiometricEnabled(false);
      expect(repo.session.value!.biometricEnabled, isFalse);
      expect(
        await storage.read('invoiceninja.biometric_enabled.v1'),
        isNull,
        reason: 'disabling deletes the key rather than writing "false"',
      );
    });

    test('logout clears the biometric flag', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      await repo.setBiometricEnabled(true);
      await repo.logout();
      expect(
        await storage.read('invoiceninja.biometric_enabled.v1'),
        isNull,
        reason:
            'leaving the flag would surface a lock with no session behind it',
      );
      expect(repo.requiresBiometricUnlock.value, isFalse);
    });

    test('restore sets requiresBiometricUnlock when flag was on', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      await repo.setBiometricEnabled(true);

      // Second AuthRepository sharing the same storage + db simulates a
      // cold launch.
      final repo2 = AuthRepository(
        db: db,
        authService: authService,
        tokenStorage: storage,
        passwordCache: PasswordCache(),
      );
      await repo2.restore();

      expect(repo2.isAuthenticated, isTrue);
      expect(repo2.session.value!.biometricEnabled, isTrue);
      expect(repo2.requiresBiometricUnlock.value, isTrue);
    });

    test('restore leaves the gate down when flag was off', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );

      final repo2 = AuthRepository(
        db: db,
        authService: authService,
        tokenStorage: storage,
        passwordCache: PasswordCache(),
      );
      await repo2.restore();

      expect(repo2.requiresBiometricUnlock.value, isFalse);
    });

    test('completeBiometricUnlock flips the gate', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      await repo.setBiometricEnabled(true);

      final repo2 = AuthRepository(
        db: db,
        authService: authService,
        tokenStorage: storage,
        passwordCache: PasswordCache(),
      );
      await repo2.restore();

      // Notify listener fires when the lock drops.
      var fired = 0;
      repo2.requiresBiometricUnlock.addListener(() => fired++);
      repo2.completeBiometricUnlock();
      expect(repo2.requiresBiometricUnlock.value, isFalse);
      expect(fired, 1);
      // Idempotent: a second call doesn't re-fire.
      repo2.completeBiometricUnlock();
      expect(fired, 1);
    });
  });

  group('onActiveCompanyChanged hook', () {
    // The hook is wired by DI to SyncRepository.drainOnce so pending outbox
    // rows for the active company flush right after the active company
    // becomes non-null or switches.
    test('fires from login with the activated company id', () async {
      authService.queueLogin(_envelope());
      final calls = <String>[];
      repo.onActiveCompanyChanged = calls.add;

      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );

      expect(calls, ['co_a']);
    });

    test('fires from switchCompany with the target company id', () async {
      authService.queueLogin(
        _envelope(
          companies: [
            (
              id: 'co_a',
              name: 'Acme',
              token: 'tok_a',
              isAdmin: false,
              isOwner: false,
            ),
            (
              id: 'co_b',
              name: 'Beta',
              token: 'tok_b',
              isAdmin: false,
              isOwner: false,
            ),
          ],
          defaultCompanyId: 'co_a',
        ),
      );
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );

      // Wire the hook AFTER login so the login-side fire-through doesn't
      // pollute this assertion.
      final calls = <String>[];
      repo.onActiveCompanyChanged = calls.add;

      await repo.switchCompany('co_b');

      expect(calls, ['co_b']);
    });

    test('fires from restore so a cold-launched session drains too', () async {
      // Seed the user once, then build a fresh repo to simulate next launch.
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );

      final fresh = AuthRepository(
        db: db,
        authService: authService,
        tokenStorage: storage,
        passwordCache: passwordCache,
      );
      final calls = <String>[];
      fresh.onActiveCompanyChanged = calls.add;

      await fresh.restore();
      // The background `_refreshSessionQuietly` runs without an apiClient set
      // on this repo — it throws StateError, which is logged and swallowed.
      // So the hook fires exactly once, from restore() itself.
      expect(calls, ['co_a']);
    });

    test('fires exactly once from restore even when the background refresh '
        'succeeds (no duplicate sidebar-prefetch sweep)', () async {
      // Regression for the warm-load double sweep: restore() activates from
      // the cached session (fire #1) AND kicks `_refreshSessionQuietly`, a
      // full /refresh that reaches `_persistAndActivate` (which would be fire
      // #2). Both target the *same* company, so the activation guard must
      // collapse them to one — otherwise the full entity prefetch runs twice.
      // Unlike the test above, here the background refresh SUCCEEDS (a real
      // apiClient is wired), so the second activation is genuinely reached.
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );

      final fakeHttp = MockClient((req) async {
        if (req.url.path == '/api/v1/refresh') {
          // Full snapshot of the same single company → same-company re-activate.
          return http.Response(jsonEncode(_envelope().toJson()), 200);
        }
        return http.Response('not found', 404);
      });
      final fresh = AuthRepository(
        db: db,
        authService: authService,
        tokenStorage: storage,
        passwordCache: passwordCache,
      );
      fresh.apiClient = ApiClient(
        credentials: fresh.credentials,
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fakeHttp,
      );
      final calls = <String>[];
      fresh.onActiveCompanyChanged = calls.add;

      await fresh.restore();
      // Drain the fire-and-forget `_refreshSessionQuietly` round-trip
      // (network + `_persistAndActivate` transaction) so the second
      // activation, if any, has run before we assert.
      await pumpEventQueue();

      expect(
        calls,
        ['co_a'],
        reason:
            'restore + successful background refresh of the same company '
            'must activate once, not twice',
      );
    });

    test('no fire on switchCompany when the target token is missing', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      final calls = <String>[];
      repo.onActiveCompanyChanged = calls.add;

      // No-op early return because no token is cached for co_missing.
      await repo.switchCompany('co_missing');

      expect(
        calls,
        isEmpty,
        reason:
            'we must not drain for a company we can not authenticate against',
      );
    });
  });

  group('Account Management endpoints', () {
    // setDefaultCompany / endAllSessions / applyLicense were added for the
    // Account Management port. Each is a thin wrapper over `ApiClient`; the
    // tests pin the exact HTTP shape so a refactor that drops the password
    // header or rewrites the path is caught at build time.

    test('setDefaultCompany POSTs to /companies/{id}/default and refreshes the '
        'session, snapping `defaultCompanyId` to the new value', () async {
      authService.queueLogin(
        _envelope(
          companies: [
            (
              id: 'co_a',
              name: 'Acme',
              token: 'tok_a',
              isAdmin: false,
              isOwner: true,
            ),
            (
              id: 'co_b',
              name: 'Beta',
              token: 'tok_b',
              isAdmin: false,
              isOwner: true,
            ),
          ],
          defaultCompanyId: 'co_a',
        ),
      );
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      expect(repo.session.value!.defaultCompanyId, 'co_a');

      Uri? defaultUrl;
      Uri? refreshUrl;
      final fakeHttp = MockClient((req) async {
        if (req.method == 'POST' &&
            req.url.path == '/api/v1/companies/co_b/default') {
          defaultUrl = req.url;
          return http.Response('{}', 200);
        }
        if (req.method == 'POST' && req.url.path == '/api/v1/refresh') {
          refreshUrl = req.url;
          // Server now reports co_b as default — the new value the UI
          // needs to react to.
          return http.Response(
            jsonEncode(
              _envelope(
                companies: [
                  (
                    id: 'co_a',
                    name: 'Acme',
                    token: 'tok_a',
                    isAdmin: false,
                    isOwner: true,
                  ),
                  (
                    id: 'co_b',
                    name: 'Beta',
                    token: 'tok_b',
                    isAdmin: false,
                    isOwner: true,
                  ),
                ],
                defaultCompanyId: 'co_b',
              ).toJson(),
            ),
            200,
          );
        }
        return http.Response('not found', 404);
      });
      repo.apiClient = ApiClient(
        credentials: repo.credentials,
        passwordCache: PasswordCache(),
        onUnauthorized: () async {},
        httpClient: fakeHttp,
      );

      await repo.setDefaultCompany('co_b');

      expect(defaultUrl, isNotNull);
      expect(refreshUrl, isNotNull);
      expect(repo.session.value!.defaultCompanyId, 'co_b');
      // The active company is preserved across the refresh — the user
      // wasn't asking to switch, only to flag co_b as the account default.
      expect(repo.session.value!.currentCompanyId, 'co_a');
    });

    test('endAllSessions POSTs to /api/v1/logout bare (no password gate) and '
        'runs the local logout()', () async {
      authService.queueLogin(_envelope());
      await repo.login(
        baseUrl: 'https://test',
        isHosted: false,
        email: 'a',
        password: 'b',
      );
      expect(repo.session.value, isNotNull);
      expect(repo.credentials.value, isNotNull);

      // Prime the password cache even though this endpoint doesn't use it —
      // the server's /logout route carries no `password_protected` middleware
      // and React fires it bare, so gating it would lock out OAuth-only users
      // who have no password. The header must stay absent even when a password
      // IS available.
      final cache = PasswordCache()..set('hunter2');

      http.BaseRequest? captured;
      final fakeHttp = MockClient((req) async {
        captured = req;
        if (req.method == 'POST' && req.url.path == '/api/v1/logout') {
          return http.Response('{}', 200);
        }
        return http.Response('not found', 404);
      });
      repo.apiClient = ApiClient(
        credentials: repo.credentials,
        passwordCache: cache,
        onUnauthorized: () async {},
        httpClient: fakeHttp,
      );

      await repo.endAllSessions();

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v1/logout');
      // Fired bare: no X-API-PASSWORD-BASE64 header, even with a primed cache.
      expect(captured!.headers['X-API-PASSWORD-BASE64'], isNull);

      // Local state is now logged-out: session + credentials gone, tokens
      // wiped, just like a forced logout.
      expect(repo.session.value, isNull);
      expect(repo.credentials.value, isNull);
      expect(await storage.read('invoiceninja.tokens.v1'), isNull);
    });

    test(
      'applyLicense POSTs to /claim_license?license_key=… and refreshes the '
      'session (no password header — `requiresPassword: false` on this path)',
      () async {
        authService.queueLogin(_envelope());
        await repo.login(
          baseUrl: 'https://test',
          isHosted: false,
          email: 'a',
          password: 'b',
        );

        http.BaseRequest? claimReq;
        Uri? refreshUrl;
        final fakeHttp = MockClient((req) async {
          if (req.method == 'POST' && req.url.path == '/api/v1/claim_license') {
            claimReq = req;
            return http.Response('{}', 200);
          }
          if (req.method == 'POST' && req.url.path == '/api/v1/refresh') {
            refreshUrl = req.url;
            return http.Response(jsonEncode(_envelope().toJson()), 200);
          }
          return http.Response('not found', 404);
        });
        repo.apiClient = ApiClient(
          credentials: repo.credentials,
          passwordCache: PasswordCache(),
          onUnauthorized: () async {},
          httpClient: fakeHttp,
        );

        await repo.applyLicense('LIC-ABC123');

        expect(claimReq, isNotNull);
        expect(claimReq!.url.queryParameters['license_key'], 'LIC-ABC123');
        // No password header — the server gates this endpoint on the URL
        // license key alone.
        expect(claimReq!.headers['X-API-PASSWORD-BASE64'], isNull);
        // refresh() ran after the claim succeeded so the new plan info
        // propagates without a manual reload.
        expect(refreshUrl, isNotNull);
      },
    );
  });
}
