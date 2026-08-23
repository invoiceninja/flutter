// Sidebar footer coverage for the two upsell cards, which share one slot.
//
// The load-bearing case is the TrialFooter regression at the bottom. The
// server sends `trial_days_left = isSelfHost() ? getTrialDays() : 0`
// (AccountTransformer), and `Account::getTrialDays()` counts down to
// `plan_expires` whenever that is within 14 — so on self-hosted the field is a
// *white-label license* countdown and `AuthSession.isTrial` flips true for the
// last fortnight of a perfectly valid license. TrialFooter had no `isHosted`
// guard, so it told a licensed self-hosted user their free trial was ending.
//
// Both widgets read only `services.auth.session`, so they take the light fake
// below rather than `_shell_test_helpers.dart`'s `buildFixture` — that fixture
// owns live Drift watch streams which never settle.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/features/shell/widgets/trial_footer.dart';
import 'package:admin/ui/features/shell/widgets/white_label_footer.dart';

import '../../../_localization_helper.dart';

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
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session({
  required bool isHosted,
  String plan = '',
  String planExpires = '',
  int trialDaysLeft = -1,
  String baseUrl = 'https://selfhost.example.test',
  bool isOwner = true,
}) => AuthSession(
  baseUrl: baseUrl,
  isHosted: isHosted,
  accountId: 'acct',
  companies: [
    AuthCompany(
      id: 'co-A',
      name: 'Co A',
      displayName: 'Co A',
      permissions: '',
      isAdmin: false,
      isOwner: isOwner,
    ),
  ],
  currentCompanyId: 'co-A',
  plan: plan,
  planExpires: planExpires,
  trialDaysLeft: trialDaysLeft,
);

Future<void> _pump(
  WidgetTester tester,
  AuthSession session, {
  bool compact = false,
  double? width,
}) async {
  if (width != null) {
    await tester.binding.setSurfaceSize(Size(width, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Provider<Services>.value(
        value: _FakeServices(auth: _FakeAuth(ValueNotifier(session))),
        child: Scaffold(
          body: SizedBox(
            width: width,
            child: Column(
              children: [
                TrialFooter(compact: compact),
                WhiteLabelFooter(compact: compact),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('WhiteLabelFooter', () {
    testWidgets('shown to an unlicensed self-hosted owner', (tester) async {
      await _pump(tester, _session(isHosted: false));
      expect(find.text('Purchase White Label'), findsOneWidget);
    });

    testWidgets('hidden once a license is applied', (tester) async {
      await _pump(tester, _session(isHosted: false, plan: 'white_label'));
      expect(find.text('Purchase White Label'), findsNothing);
    });

    testWidgets('hidden on hosted', (tester) async {
      await _pump(tester, _session(isHosted: true));
      expect(find.text('Purchase White Label'), findsNothing);
    });

    testWidgets('hidden on the demo server', (tester) async {
      await _pump(tester, _session(isHosted: false, baseUrl: kDemoBaseUrl));
      expect(find.text('Purchase White Label'), findsNothing);
    });

    testWidgets('hidden from a user who could not act on it', (tester) async {
      await _pump(tester, _session(isHosted: false, isOwner: false));
      expect(find.text('Purchase White Label'), findsNothing);
    });

    testWidgets('hidden on the collapsed rail', (tester) async {
      await _pump(tester, _session(isHosted: false), compact: true);
      expect(find.text('Purchase White Label'), findsNothing);
    });

    // The expanded rail (232) and the mobile drawer (280) are the two real
    // hosts, and the narrower of them is the tightest horizontal space in the
    // app. The test font is one em per glyph, so this over-states the label by
    // roughly what a long translation would cost — the card must soft-wrap
    // rather than overflow at either width.
    for (final width in const [232.0, 280.0]) {
      testWidgets('fits the ${width.toInt()} px sidebar without overflow', (
        tester,
      ) async {
        await _pump(tester, _session(isHosted: false), width: width);

        expect(find.text('Purchase White Label'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('TrialFooter', () {
    testWidgets('a valid self-hosted license is never called a free trial', (
      tester,
    ) async {
      // What the server really sends for a license 7 days out. Before the
      // `isHosted` guard this rendered "7 days left" plus the upgrade pitch.
      await _pump(
        tester,
        _session(
          isHosted: false,
          plan: 'white_label',
          planExpires: DateTime.now()
              .add(const Duration(days: 7))
              .toIso8601String(),
          trialDaysLeft: 7,
        ),
      );

      expect(find.textContaining('days left'), findsNothing);
    });

    testWidgets('a real hosted trial still gets its countdown', (tester) async {
      // The positive half of the guard above. Without this the `isHosted &&`
      // fix could be tightened into silencing the card everywhere and no test
      // would notice. NB this passes a `trialDaysLeft` the live hosted server
      // never sends (it hard-codes 0) — see the `isTrial` defect noted in
      // `trial_footer.dart`; the widget contract is what's pinned here.
      await _pump(tester, _session(isHosted: true, trialDaysLeft: 5));

      expect(find.textContaining('days left'), findsOneWidget);
      expect(find.textContaining('5'), findsOneWidget);
      expect(find.text('Purchase White Label'), findsNothing);
    });

    testWidgets('an unlicensed self-host gets the offer, not a trial nag', (
      tester,
    ) async {
      // The two footers share a slot; only one may ever speak.
      await _pump(tester, _session(isHosted: false, trialDaysLeft: 7));

      expect(find.textContaining('days left'), findsNothing);
      expect(find.text('Purchase White Label'), findsOneWidget);
    });
  });
}
