import 'dart:async';

import 'package:admin/app/terminal_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/login_response_api_model.dart';
import 'package:admin/data/models/api/terminal_models.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/terminal_repository.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/data/services/auth_service.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/terminal_platform.dart';
import 'package:admin/data/services/token_storage.dart';
import 'package:admin/domain/terminal/terminal_eligibility.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_services/store_services.dart';

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

class _FakeRepo implements TerminalRepository {
  final List<String> calls = [];
  Object? configAnswer;

  @override
  Future<TerminalConfig> config(String companyId) async {
    calls.add('config:$companyId');
    final answer = configAnswer;
    if (answer is TerminalConfig) return answer;
    throw answer ?? const ServerException(404, 'Route does not exist');
  }

  @override
  Future<String> connectionToken(
    String companyId, {
    required String companyGatewayId,
    required String locationId,
  }) async {
    calls.add('token:$companyGatewayId/$locationId');
    return 'pst_test_x';
  }

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _FakePlatform implements TerminalPlatform {
  final List<String> calls = [];
  TerminalDeviceSupport support = const TerminalDeviceSupport(
    tapToPay: true,
    bluetooth: true,
  );
  Future<String> Function()? tokenSource;

  @override
  bool get isAvailable => true;

  @override
  Future<TerminalDeviceSupport> deviceSupport() async => support;

  @override
  Future<void> initialize({
    required String account,
    required Future<String> Function() fetchToken,
  }) async {
    calls.add('initialize:$account');
    tokenSource = fetchToken;
  }

  @override
  Future<void> reset() async => calls.add('reset');

  @override
  Stream<List<TerminalReader>> discover(
    TerminalReaderKind kind, {
    bool simulated = false,
  }) {
    calls.add('discover:${kind.name}:$simulated');
    return Stream.value([
      TerminalReader(
        serialNumber: 'ttp',
        label: 'This phone',
        kind: kind,
        simulated: simulated,
        batteryLevel: -1,
        hasAvailableUpdate: false,
      ),
    ]);
  }

  @override
  Future<TerminalReader> connect(
    TerminalReader reader, {
    required String locationId,
    required String merchantDisplayName,
    required bool tosAcceptancePermitted,
  }) async {
    calls.add(
      'connect:$locationId:$merchantDisplayName:$tosAcceptancePermitted',
    );
    return reader;
  }

  @override
  Future<TerminalReader?> connectedReader() async => null;

  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

TerminalGatewayConfig _gateway({
  bool livemode = false,
  String country = 'US',
}) => TerminalGatewayConfig(
  companyGatewayId: 'cg_1',
  label: 'Stripe',
  livemode: livemode,
  accountCountry: country,
  defaultCurrency: 'usd',
  cardPaymentsActive: true,
  surcharge: TerminalSurchargeConfig.fromJson(const {}),
  locations: const [TerminalLocation(id: 'tml_1', displayName: 'Main')],
);

TerminalConfig _config({bool planOk = true}) =>
    TerminalConfig(enabled: true, planOk: planOk, gateways: [_gateway()]);

void main() {
  late AppDatabase db;
  late AuthRepository auth;
  late DevicePrefsStore prefs;
  late _FakeRepo repo;
  late _FakePlatform platform;
  late TerminalController terminal;

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
    prefs = DevicePrefsStore(db);
    await prefs.load();
    repo = _FakeRepo();
    platform = _FakePlatform();
    terminal = TerminalController(
      repository: repo,
      platform: platform,
      auth: auth,
      prefs: prefs,
      platformReady: true,
    );
  });
  tearDown(() async {
    terminal.dispose();
    await db.close();
  });

  final invoice = emptyInvoice().copyWith(
    id: 'inv_1',
    statusId: InvoiceStatus.sent,
  );

  Future<void> settle() => pumpEventQueue();

  test('asks the server once per company, and offers the action once it '
      'answers', () async {
    repo.configAnswer = _config();
    expect(
      terminal.availabilityFor('co_a', invoice),
      TerminalAvailability.hidden,
    );
    terminal.ensureConfig('co_a');
    terminal.ensureConfig('co_a');
    await settle();
    expect(repo.calls, ['config:co_a']);
    expect(
      terminal.availabilityFor('co_a', invoice),
      TerminalAvailability.available,
    );
  });

  test('a server without the route is asked once and stays quiet', () async {
    terminal.ensureConfig('co_a');
    await settle();
    terminal.ensureConfig('co_a');
    await settle();
    expect(repo.calls, ['config:co_a']);
    expect(terminal.configFor('co_a'), isNull);
    expect(
      terminal.availabilityFor('co_a', invoice),
      TerminalAvailability.hidden,
    );
  });

  test('nothing is asked when the platform is not ready', () async {
    final off = TerminalController(
      repository: repo,
      platform: platform,
      auth: auth,
      prefs: prefs,
      platformReady: false,
    );
    off.ensureConfig('co_a');
    await settle();
    expect(repo.calls, isEmpty);
    off.dispose();
  });

  test(
    'a phone without Tap to Pay offers it only after a reader was used',
    () async {
      platform.support = const TerminalDeviceSupport(
        tapToPay: false,
        bluetooth: true,
      );
      repo.configAnswer = _config();
      terminal.ensureConfig('co_a');
      await settle();
      expect(
        terminal.availabilityFor('co_a', invoice),
        TerminalAvailability.hidden,
      );
      await terminal.noteReaderUsed();
      expect(
        terminal.availabilityFor('co_a', invoice),
        TerminalAvailability.available,
      );
      expect(prefs.read(DevicePrefKeys.cardReaderUsed), isTrue);
    },
  );

  test('the SDK session is per gateway and Location, and only an admin may '
      'accept Tap to Pay terms', () async {
    final gateway = _gateway();
    final location = gateway.locations.single;
    await terminal.prepare(
      companyId: 'co_a',
      gateway: gateway,
      location: location,
    );
    expect(platform.calls, ['initialize:co_a/cg_1/tml_1']);
    expect(await platform.tokenSource!(), 'pst_test_x');
    expect(repo.calls, ['token:cg_1/tml_1']);

    await terminal.connectTapToPay(
      gateway: gateway,
      location: location,
      merchantDisplayName: 'Acme',
      isAdmin: false,
    );
    expect(platform.calls.skip(1), [
      'discover:tapToPay:false',
      'connect:tml_1:Acme:false',
    ]);
  });

  test('the simulated reader is only used on a test-mode gateway', () async {
    terminal.simulated = true;
    final location = _gateway().locations.single;
    await terminal.connectTapToPay(
      gateway: _gateway(livemode: true),
      location: location,
      merchantDisplayName: 'Acme',
      isAdmin: true,
    );
    await terminal.connectTapToPay(
      gateway: _gateway(),
      location: location,
      merchantDisplayName: 'Acme',
      isAdmin: true,
    );
    expect(platform.calls.where((c) => c.startsWith('discover')), [
      'discover:tapToPay:false',
      'discover:tapToPay:true',
    ]);
  });

  test('reset waits for a charge in flight before resetting the SDK', () async {
    repo.configAnswer = _config();
    terminal.ensureConfig('co_a');
    await settle();
    final charge = Completer<String>();
    final guarded = terminal.guardCharge(() => charge.future);
    var resetDone = false;
    final reset = terminal.reset().then((_) => resetDone = true);
    await settle();
    expect(resetDone, isFalse);
    expect(platform.calls, isNot(contains('reset')));
    charge.complete('succeeded');
    expect(await guarded, 'succeeded');
    await reset;
    expect(platform.calls, contains('reset'));
    expect(terminal.configFor('co_a'), isNull);
  });
}
