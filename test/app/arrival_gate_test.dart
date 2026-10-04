import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/arrival_gate.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_credentials.dart';

/// The gate `DeepLinkRouter` and `SharedFileIntake` hold arrivals behind.
/// `deep_link_router_test.dart` covers it through the router; this pins the
/// pieces the share intake leans on directly.

const _co = AuthCompany(
  id: 'co1',
  name: 'One',
  displayName: 'One',
  permissions: '',
  isAdmin: true,
  isOwner: true,
);

const _session = AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acc-1',
  companies: [_co],
  currentCompanyId: 'co1',
);

const _credentials = ApiCredentials(
  baseUrl: 'https://example.test',
  token: 'tok',
);

void main() {
  late ValueNotifier<AuthSession?> session;
  late ValueNotifier<ApiCredentials?> credentials;
  late ValueNotifier<bool> locked;
  late bool setupRequired;
  late ArrivalGate gate;

  setUp(() {
    session = ValueNotifier(null);
    credentials = ValueNotifier(null);
    locked = ValueNotifier(false);
    setupRequired = false;
    gate = ArrivalGate(
      session: session,
      credentials: credentials,
      requiresBiometricUnlock: locked,
      isSetupRequired: (_) => setupRequired,
    );
  });

  tearDown(() {
    gate.cancel();
    session.dispose();
    credentials.dispose();
    locked.dispose();
  });

  test('open only when signed in, materialised, unlocked and past setup', () {
    expect(gate.isOpen, isFalse);
    session.value = _session;
    expect(gate.isOpen, isFalse, reason: 'no credentials yet');
    credentials.value = _credentials;
    expect(gate.isOpen, isTrue);
    locked.value = true;
    expect(gate.isOpen, isFalse);
    locked.value = false;
    setupRequired = true;
    expect(gate.isOpen, isFalse);
  });

  testWidgets('wakes on the CREDENTIALS edge — AuthRepository assigns the '
      'session first, so a gate deaf to credentials would sleep through the '
      'sign-in', (tester) async {
    var fired = 0;
    gate.notifyWhenOpen(() => fired++);

    session.value = _session; // gate still shut: no credentials
    await tester.pump();
    expect(fired, 0);

    credentials.value = _credentials;
    expect(fired, 0, reason: 'replays after the frame, not synchronously');
    await tester.pump();
    expect(fired, 1);

    // One-shot: a later change doesn't fire it again.
    locked.value = true;
    locked.value = false;
    await tester.pump();
    expect(fired, 1);
  });

  testWidgets('re-checks the setup predicate on session changes', (
    tester,
  ) async {
    session.value = _session;
    credentials.value = _credentials;
    setupRequired = true;
    var fired = 0;
    gate.notifyWhenOpen(() => fired++);

    setupRequired = false;
    // The company was named: a new session (the router reads the same edge).
    session.value = const AuthSession(
      baseUrl: 'https://example.test',
      isHosted: false,
      accountId: 'acc-1',
      companies: [_co],
      currentCompanyId: 'co1',
      userId: 'named',
    );
    await tester.pump();
    expect(fired, 1);
  });

  testWidgets('cancel drops the pending callback', (tester) async {
    var fired = 0;
    gate.notifyWhenOpen(() => fired++);
    gate.cancel();
    session.value = _session;
    credentials.value = _credentials;
    await tester.pump();
    expect(fired, 0);
  });

  testWidgets('a later notifyWhenOpen replaces the earlier callback', (
    tester,
  ) async {
    final calls = <String>[];
    gate
      ..notifyWhenOpen(() => calls.add('first'))
      ..notifyWhenOpen(() => calls.add('second'));
    session.value = _session;
    credentials.value = _credentials;
    WidgetsBinding.instance.scheduleFrame();
    await tester.pump();
    expect(calls, ['second']);
  });
}
