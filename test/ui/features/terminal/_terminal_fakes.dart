/// Fakes shared by the in-person payment tests (docs/in-person-payments.md).
library;

import 'dart:async';
import 'dart:collection';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/models/api/terminal_models.dart';
import 'package:admin/data/repositories/terminal_repository.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/terminal_platform.dart';
import 'package:decimal/decimal.dart';
import 'package:store_services/store_services.dart';

/// Same `FakeAuthService` shape as `auth_repository_test.dart` — duplicated
/// here rather than imported because the test files own their own test
/// doubles in this codebase (search for the comment block at the top of
/// each repo test).
class FakeAuthService implements AuthService {
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

LoginResponseApi fakeEnvelope() => const LoginResponseApi(
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

/// Answers queued per call; a queued Exception is thrown.
class Script<T> {
  final Queue<Object> _answers = Queue();
  void add(Object answer) => _answers.add(answer);
  bool get isEmpty => _answers.isEmpty;
  Future<T> next(String name) async {
    if (_answers.isEmpty) throw StateError('no answer queued for $name');
    final a = _answers.removeFirst();
    if (a is Completer<T>) return a.future;
    if (a is Exception || a is Error) throw a;
    return a as T;
  }
}

class FakeTerminalRepo implements TerminalRepository {
  final calls = <String>[];
  final creates = Script<TerminalIntent>();
  final finalizes = Script<TerminalFinalize>();
  final completes = Script<TerminalCompletion>();
  final cancels = Script<TerminalCompletion>();
  final createdCollectionIds = <String>[];

  @override
  Future<TerminalConfig> config(String companyId) async => TerminalConfig(
    enabled: true,
    planOk: true,
    gateways: [
      TerminalGatewayConfig(
        companyGatewayId: 'cg_1',
        label: 'Stripe',
        livemode: false,
        accountCountry: 'US',
        defaultCurrency: 'usd',
        cardPaymentsActive: true,
        surcharge: TerminalSurchargeConfig.fromJson(const {
          'allowed': true,
          'fee_percent': 3,
        }),
        locations: const [TerminalLocation(id: 'tml_1', displayName: 'Main')],
      ),
    ],
  );

  @override
  Future<String> connectionToken(
    String companyId, {
    required String companyGatewayId,
    required String locationId,
  }) async => 'pst_test_x';

  @override
  Future<TerminalQuote> quote(
    String companyId, {
    required String invoiceId,
    required String companyGatewayId,
    required Decimal amount,
    required bool applyFee,
  }) async {
    calls.add('quote:$amount:$applyFee');
    final fee = applyFee ? Decimal.fromInt(3) : Decimal.zero;
    return TerminalQuote(
      amount: amount,
      feeGross: fee,
      total: amount + fee,
      surchargeAllowed: true,
      reason: null,
    );
  }

  @override
  Future<TerminalIntent> createPaymentIntent(
    String companyId, {
    required String invoiceId,
    required String companyGatewayId,
    required Decimal amount,
    required bool applyFee,
    required String collectionId,
    required Decimal expectedTotal,
  }) {
    calls.add('create:$collectionId:$expectedTotal');
    createdCollectionIds.add(collectionId);
    return creates.next('create');
  }

  @override
  Future<TerminalFinalize> finalize(String companyId, String paymentIntentId) {
    calls.add('finalize');
    return finalizes.next('finalize');
  }

  @override
  Future<TerminalCompletion> complete(
    String companyId,
    String paymentIntentId, {
    required String invoiceId,
  }) {
    calls.add('complete');
    return completes.next('complete');
  }

  @override
  Future<TerminalCompletion> cancel(
    String companyId,
    String paymentIntentId, {
    required String invoiceId,
  }) {
    calls.add('cancel:$paymentIntentId');
    return cancels.next('cancel');
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class FakeSession implements TerminalPaymentSession {
  final reads = Script<TerminalCollected>();
  final confirms = Script<TerminalPaymentOutcome>();
  final calls = <String>[];
  bool finished = false;

  @override
  bool get isFinished => finished;

  @override
  bool get isCancelled => calls.contains('cancel');

  @override
  Future<TerminalCollected> collect() {
    calls.add('collect');
    return reads.next('collect');
  }

  @override
  Future<TerminalPaymentOutcome> confirm({
    required String paymentIntentId,
    required int amount,
  }) {
    calls.add('confirm:$paymentIntentId:$amount');
    return confirms.next('confirm');
  }

  @override
  void cancel() => calls.add('cancel');
}

class FakeTerminalPlatform implements TerminalPlatform {
  final session = FakeSession();
  TerminalPermission permission = TerminalPermission.granted;

  @override
  bool get isAvailable => true;

  @override
  Future<TerminalDeviceSupport> deviceSupport() async =>
      const TerminalDeviceSupport(tapToPay: true, bluetooth: true);

  @override
  Future<TerminalPermission> requestPermissions(
    TerminalReaderKind kind,
  ) async => permission;

  @override
  Future<void> initialize({
    required String account,
    required Future<String> Function() fetchToken,
  }) async {}

  @override
  Future<void> reset() async {}

  @override
  Stream<List<TerminalReader>> discover(
    TerminalReaderKind kind, {
    bool simulated = false,
  }) => Stream.value([
    TerminalReader(
      serialNumber: 'ttp',
      label: 'This phone',
      kind: kind,
      simulated: simulated,
      batteryLevel: -1,
      hasAvailableUpdate: false,
    ),
  ]);

  @override
  Future<TerminalReader> connect(
    TerminalReader reader, {
    required String locationId,
    required String merchantDisplayName,
    required bool tosAcceptancePermitted,
  }) async => reader;

  @override
  Future<TerminalReader?> connectedReader() async => null;

  @override
  TerminalPaymentSession beginPayment(String clientSecret) => session;

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

TerminalIntent fakeIntent([String pi = 'pi_1']) => TerminalIntent(
  collectionId: 'col',
  paymentIntentId: pi,
  clientSecret: '${pi}_secret_x',
  amount: Decimal.fromInt(100),
  feeGross: Decimal.zero,
  total: Decimal.fromInt(100),
  currency: 'usd',
  livemode: false,
);

TerminalFinalize fakeFinalize(int minor, {bool recollect = false}) =>
    TerminalFinalize(
      path: recollect ? 'recollect' : 'none',
      recollect: recollect,
      funding: 'credit',
      amount: Decimal.parse((minor / 100).toString()),
      amountMinor: minor,
      surcharge: Decimal.zero,
    );

TerminalCompletion fakeCompletion(String status) => TerminalCompletion(
  status: status,
  paymentId: status == 'recorded' ? 'pay_1' : '',
  applied: Decimal.zero,
  unapplied: Decimal.zero,
  invoiceBalance: null,
  brand: 'visa',
  last4: '4242',
  receiptUrl: '',
);

const fakeCard = TerminalCollected(
  paymentIntentId: 'pi_1',
  amount: 10000,
  currency: 'usd',
  method: 'card_present',
  funding: 'credit',
);
