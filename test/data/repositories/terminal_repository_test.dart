import 'dart:convert';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/terminal_repository.dart';
import 'package:admin/data/models/api/terminal_models.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/terminal_server_error.dart';
import 'package:decimal/decimal.dart';
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

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    final authService = _FakeAuthService();
    auth = AuthRepository(
      db: db,
      authService: authService,
      tokenStorage: InMemoryTokenStorage(),
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

  final requests = <http.Request>[];
  final refreshed = <String>[];

  TerminalRepository repo(http.Response Function(http.Request req) respond) {
    requests.clear();
    refreshed.clear();
    final apiClient = ApiClient(
      credentials: auth.credentials,
      passwordCache: PasswordCache(),
      onUnauthorized: () async {},
      httpClient: MockClient((req) async {
        requests.add(req);
        return respond(req);
      }),
    );
    auth.apiClient = apiClient;
    return TerminalRepository(
      apiClient: apiClient,
      refreshInvoice: (companyId, id) async {
        refreshed.add('invoice:$id');
        return {'cl_1'};
      },
      refreshClients: (companyId, ids) async =>
          refreshed.add('clients:${ids.join(',')}'),
      refreshPayment: (companyId, id) async => refreshed.add('payment:$id'),
    );
  }

  http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  test('config reads the gateways the server offers', () async {
    final r = repo(
      (_) => json({
        'enabled': true,
        'plan_ok': true,
        'gateways': [
          {
            'company_gateway_id': 'cg_1',
            'label': 'Stripe',
            'livemode': false,
            'account_country': 'us',
            'default_currency': 'USD',
            'card_payments_active': true,
            'surcharge': {
              'allowed': false,
              'reason': 'not_acknowledged',
              'fee_percent': 3,
              'fee_amount': 0,
            },
            'locations': [
              {'id': 'tml_1', 'display_name': 'Main'},
            ],
          },
        ],
      }),
    );
    final config = await r.config('co_a');
    expect(requests.single.url.path, '/api/v1/terminal/config');
    final g = config.usableGateway!;
    expect(g.accountCountry, 'US');
    expect(g.defaultCurrency, 'usd');
    expect(g.surcharge.needsAcknowledgement, isTrue);
    expect(g.surcharge.feePercent, Decimal.fromInt(3));
    expect(g.locations.single.id, 'tml_1');
  });

  test('an older server without the route is a plain 404', () async {
    final r = repo((_) => json({'message': 'Route does not exist'}, 404));
    await expectLater(
      r.config('co_a'),
      throwsA(
        isA<ServerException>().having((e) => e.statusCode, 'status', 404),
      ),
    );
  });

  test('quote sends apply_fee as 1/0, which Laravel accepts', () async {
    final r = repo(
      (_) => json({
        'amount': 100,
        'fee_gross': 3,
        'fee_net': 3,
        'total': 103.00000000000001,
        'surcharge_allowed': true,
        'reason': null,
      }),
    );
    final quote = await r.quote(
      'co_a',
      invoiceId: 'inv_1',
      companyGatewayId: 'cg_1',
      amount: Decimal.parse('100'),
      applyFee: true,
    );
    final url = requests.single.url;
    expect(url.path, '/api/v1/invoices/inv_1/terminal/quote');
    expect(url.queryParameters, {
      'company_gateway_id': 'cg_1',
      'amount': '100',
      'apply_fee': '1',
    });
    expect(quote.surchargeAllowed, isTrue);
    expect(quote.feeGross, Decimal.fromInt(3));
  });

  test('createPaymentIntent posts the collection and keeps the secret out '
      'of toString', () async {
    final r = repo(
      (_) => json({
        'collection_id': 'col_1',
        'payment_intent_id': 'pi_1',
        'client_secret': 'pi_1_secret_abc',
        'amount': 100,
        'fee_gross': 0,
        'total': 100,
        'currency': 'USD',
        'livemode': false,
      }),
    );
    final intent = await r.createPaymentIntent(
      'co_a',
      invoiceId: 'inv_1',
      companyGatewayId: 'cg_1',
      amount: Decimal.parse('100'),
      applyFee: false,
      collectionId: 'col_1',
      expectedTotal: Decimal.parse('100'),
    );
    expect(jsonDecode(requests.single.body), {
      'company_gateway_id': 'cg_1',
      'amount': '100',
      'apply_fee': false,
      'collection_id': 'col_1',
      'expected_total': '100',
    });
    expect(intent.clientSecret, 'pi_1_secret_abc');
    expect(intent.currency, 'usd');
    expect('$intent', isNot(contains('secret')));
    // A draft is marked sent here, so the invoice is re-read.
    expect(refreshed, ['invoice:inv_1']);
  });

  test('a 409 collection_open names the open PaymentIntent, and the invoice '
      'is still re-read', () async {
    final r = repo(
      (_) => json({
        'message': 'Another card payment is open',
        'error_code': 'collection_open',
        'payment_intent_id': 'pi_old',
        'user': 'Sam',
        'age': 90,
      }, 409),
    );
    await expectLater(
      r.createPaymentIntent(
        'co_a',
        invoiceId: 'inv_1',
        companyGatewayId: 'cg_1',
        amount: Decimal.one,
        applyFee: false,
        collectionId: 'col_1',
        expectedTotal: Decimal.one,
      ),
      throwsA(
        isA<TerminalServerError>()
            .having((e) => e.code, 'code', TerminalServerError.collectionOpen)
            .having((e) => e.openPaymentIntentId, 'pi', 'pi_old')
            .having((e) => e.data['user'], 'user', 'Sam'),
      ),
    );
    expect(refreshed, ['invoice:inv_1']);
  });

  test('a 403 refusal and a 422 with an error_code are terminal errors; a '
      'plain 422 carries its first field message', () async {
    var reply = json({'message': 'Off', 'error_code': 'disabled'}, 403);
    final r = repo((_) => reply);
    await expectLater(
      r.connectionToken('co_a', companyGatewayId: 'cg_1', locationId: 'tml_1'),
      throwsA(
        isA<TerminalServerError>().having((e) => e.code, 'code', 'disabled'),
      ),
    );
    reply = json({
      'message': 'Add an address',
      'error_code': 'location_address_required',
      'missing': ['address1'],
    }, 422);
    await expectLater(
      r.createLocation('co_a', companyGatewayId: 'cg_1'),
      throwsA(
        isA<TerminalServerError>()
            .having((e) => e.code, 'code', 'location_address_required')
            .having((e) => e.data['missing'], 'missing', ['address1']),
      ),
    );
    reply = json({
      'message': 'The given data was invalid.',
      'errors': {
        'amount': ['The amount is more than the balance.'],
      },
    }, 422);
    await expectLater(
      r.quote(
        'co_a',
        invoiceId: 'inv_1',
        companyGatewayId: 'cg_1',
        amount: Decimal.fromInt(9999),
        applyFee: false,
      ),
      throwsA(
        isA<TerminalServerError>()
            .having((e) => e.code, 'code', TerminalServerError.fieldErrors)
            .having(
              (e) => e.message,
              'message',
              'The amount is more than the balance.',
            ),
      ),
    );
  });

  test('finalize reads amount_minor and has a short timeout', () async {
    final r = repo(
      (_) => json({
        'path': 'recollect',
        'recollect': true,
        'funding': 'credit',
        'amount': 103.00000000000001,
        'amount_minor': 10300,
        'surcharge': 3,
      }),
    );
    final f = await r.finalize('co_a', 'pi_1', invoiceId: 'inv_1');
    expect(
      requests.single.url.path,
      '/api/v1/invoices/inv_1/terminal/payment_intents/pi_1/finalize',
    );
    expect(f.recollect, isTrue);
    expect(f.amountMinor, 10300);
    expect(
      TerminalRepository.finalizeTimeout,
      lessThan(const Duration(seconds: 30)),
    );
  });

  test('complete refreshes the invoice, its client and the payment once '
      'recorded; only the invoice otherwise', () async {
    var reply = json({
      'status': 'recorded',
      'payment_id': 'pay_1',
      'applied': 100,
      'unapplied': 0,
      'invoice_balance': 0,
      'brand': 'visa',
      'last4': '4242',
      'receipt_url': 'https://pay.stripe.com/r',
    });
    final r = repo((_) => reply);
    final done = await r.complete('co_a', 'pi_1', invoiceId: 'inv_1');
    expect(done.isRecorded, isTrue);
    expect(refreshed, ['invoice:inv_1', 'clients:cl_1', 'payment:pay_1']);

    reply = json({'status': 'processing'});
    refreshed.clear();
    final pending = await r.cancel('co_a', 'pi_1', invoiceId: 'inv_1');
    expect(
      requests.last.url.path,
      '/api/v1/invoices/inv_1/terminal/payment_intents/pi_1/cancel',
    );
    expect(pending.status, 'processing');
    expect(pending.isRecorded, isFalse);
    expect(refreshed, ['invoice:inv_1']);
  });

  test('a finalize answer with no amount_minor matches no read', () {
    expect(TerminalFinalize.fromJson(const {}).amountMinor, -1);
  });
}
