// Pins the Plan card's hosted-vs-self-hosted split on the *trial* chrome.
//
// The load-bearing case is a self-hosted white-label license inside its last
// fortnight. The server sends
// `trial_days_left = isSelfHost() ? getTrialDays() : 0` (AccountTransformer)
// and `Account::getTrialDays()` returns the days remaining until `plan_expires`
// whenever that is within 14 — so on self-hosted the field is a *license*
// countdown, and `AuthSession.isTrial` flips true for a perfectly valid
// license. Rendering that as a free trial (and, worse, suppressing the renewal
// date behind `!isTrial`) hid the expiry in exactly the window where renewing
// is the actionable thing.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/plan_screen.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../../../_localization_helper.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices({required this.auth});
  @override
  final AuthRepository auth;

  // No warmed formatter — `_expiryDisplay` falls back to the raw date prefix,
  // which keeps the assertion independent of company date-format settings.
  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session({
  required bool isHosted,
  String plan = '',
  String planExpires = '',
  int trialDaysLeft = -1,
}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: isHosted,
  accountId: 'acct',
  companies: const [],
  currentCompanyId: '',
  plan: plan,
  planExpires: planExpires,
  trialDaysLeft: trialDaysLeft,
);

Future<void> _pump(WidgetTester tester, AuthSession session) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Provider<Services>.value(
        value: _FakeServices(auth: _FakeAuth(ValueNotifier(session))),
        child: const Scaffold(body: AccountManagementPlanScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('self-hosted license in its last fortnight keeps the expiry and '
      'is never called a trial', (tester) async {
    await _pump(
      tester,
      _session(
        isHosted: false,
        plan: 'white_label',
        planExpires: '2026-09-01',
        // What the server actually sends for a license 7 days out.
        trialDaysLeft: 7,
      ),
    );

    expect(find.text('Self Hosted (White labeled)'), findsOneWidget);
    expect(find.textContaining('Free Trial'), findsNothing);
    expect(find.textContaining('days left'), findsNothing);
    expect(find.textContaining('2026-09-01'), findsOneWidget);
  });

  testWidgets('self-hosted license comfortably in date shows the expiry', (
    tester,
  ) async {
    await _pump(
      tester,
      // > 14 days out, so the server reports 0 and isTrial is already false.
      _session(
        isHosted: false,
        plan: 'white_label',
        planExpires: '2027-06-01',
        trialDaysLeft: 0,
      ),
    );

    expect(find.text('Self Hosted (White labeled)'), findsOneWidget);
    expect(find.textContaining('2027-06-01'), findsOneWidget);
  });

  testWidgets('unlicensed self-host reads as Self Hosted (Free), no expiry', (
    tester,
  ) async {
    await _pump(tester, _session(isHosted: false));

    expect(find.text('Self Hosted (Free)'), findsOneWidget);
    expect(find.textContaining('Expires On'), findsNothing);
  });

  testWidgets('hosted trial still renders the trial suffix and countdown', (
    tester,
  ) async {
    await _pump(tester, _session(isHosted: true, trialDaysLeft: 5));

    expect(find.textContaining('Free Trial'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('hosted paid plan shows the slug label and its renewal date', (
    tester,
  ) async {
    await _pump(
      tester,
      _session(
        isHosted: true,
        plan: 'pro',
        planExpires: '2026-12-31',
        trialDaysLeft: 0,
      ),
    );

    expect(find.textContaining('Free Trial'), findsNothing);
    expect(find.textContaining('2026-12-31'), findsOneWidget);
  });
}
