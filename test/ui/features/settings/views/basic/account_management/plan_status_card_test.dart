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
import 'package:admin/data/repositories/auth/auth_session.dart';
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
  String baseUrl = 'https://example.test',
}) => AuthSession(
  baseUrl: baseUrl,
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

  // --- White Label card (issue #41) --------------------------------------
  //
  // The Plan tab used to render one line of text and nothing else on a
  // self-hosted install, because `_HostedActionsCard` is gated on `isHosted`.
  // The Purchase / Apply License pair moved here from the Overview tab so the
  // default tab has something to do, matching React's `Plan.tsx:70`.

  String daysFromNow(int days) =>
      DateTime.now().add(Duration(days: days)).toIso8601String();

  testWidgets('unlicensed self-host is offered a license', (tester) async {
    await _pump(tester, _session(isHosted: false));

    expect(find.text('White Label'), findsOneWidget);
    expect(find.text('Purchase White Label'), findsOneWidget);
    expect(find.text('Apply License'), findsOneWidget);
    // Nothing about renewing something they never had.
    expect(find.text('Renew License'), findsNothing);
  });

  testWidgets('a licensed self-host can re-apply but has nothing to buy', (
    tester,
  ) async {
    await _pump(
      tester,
      _session(
        isHosted: false,
        plan: 'white_label',
        planExpires: daysFromNow(200),
        trialDaysLeft: 0,
      ),
    );

    expect(find.text('Apply License'), findsOneWidget);
    expect(find.text('Purchase White Label'), findsNothing);
    expect(find.text('Renew License'), findsNothing);
  });

  testWidgets('a lapsed license offers a renewal, not a first purchase', (
    tester,
  ) async {
    // What the server actually sends after a license runs out: the slug is
    // blanked by `Account::getPlan()` but `plan_expires` still arrives raw.
    await _pump(
      tester,
      _session(isHosted: false, planExpires: daysFromNow(-30)),
    );

    expect(find.text('Renew License'), findsOneWidget);
    expect(find.text('Apply License'), findsOneWidget);
    expect(find.text('Purchase White Label'), findsNothing);
    expect(
      find.textContaining('white label license has expired'),
      findsOneWidget,
    );
  });

  testWidgets('a legacy zero-date reads as never-licensed, not expired', (
    tester,
  ) async {
    // `plan_expires` is a nullable DATE that can hold a MySQL zero-date or a
    // migrated-v4 sentinel, and `DateTime.tryParse('0000-00-00')` returns
    // year -1 rather than null — so a bare parse tells someone who never had
    // a license that theirs expired, beside a Renew button to a paid
    // checkout. React applies a `year() > 2000` test for the same reason.
    await _pump(tester, _session(isHosted: false, planExpires: '0000-00-00'));

    expect(find.text('Purchase White Label'), findsOneWidget);
    expect(find.text('Renew License'), findsNothing);
    expect(find.textContaining('has expired'), findsNothing);
  });

  testWidgets('hosted sees no license card at all', (tester) async {
    await _pump(tester, _session(isHosted: true, plan: 'pro'));

    expect(find.text('White Label'), findsNothing);
    expect(find.text('Purchase White Label'), findsNothing);
    expect(find.text('Apply License'), findsNothing);
  });

  testWidgets('a HOSTED white_label account gets no self-hosted card', (
    tester,
  ) async {
    // `white_label` is a hosted slug too, not just the self-hosted license
    // state: it sits in `_kProSlugs`/`_kEnterpriseSlugs`, `planHeadlineKey`
    // has a dedicated hosted case, and hosted billing sells it
    // (`BillingPortalPurchasev2`: `product_key == 'whitelabel'`). Gating the
    // card on a bare `isWhiteLabeled` therefore leaked it onto hosted, next
    // to the hosted upgrade card — and its Apply License would POST
    // `claim_license`, which is hard-gated to self-host and 400s.
    await _pump(tester, _session(isHosted: true, plan: 'white_label'));

    // The plan *headline* still reads "White Label" — `planHeadlineKey`
    // passes a hosted slug straight through, which `plan_headline_test`
    // pins. What must not appear is a second one as the card's title, or
    // either of its actions.
    expect(find.text('White Label'), findsOneWidget);
    expect(find.text('Apply License'), findsNothing);
    expect(find.text('Purchase White Label'), findsNothing);
  });

  testWidgets('the demo server never advertises a checkout', (tester) async {
    // The demo bootstrap logs in with `isHosted: false`, so without the demo
    // clause in `canPurchaseWhiteLabel` the public build would carry a live
    // purchase link.
    await _pump(tester, _session(isHosted: false, baseUrl: kDemoBaseUrl));

    expect(find.text('White Label'), findsNothing);
    expect(find.text('Purchase White Label'), findsNothing);
  });

  testWidgets('Apply License opens the key prompt', (tester) async {
    // Smoke-covers `_promptLicenseKey`, which moved files with the card.
    // Purchase is deliberately never tapped in a widget test — `canLaunchUrl`
    // hits a platform channel; the URL is pinned in `white_label_test.dart`.
    await _pump(tester, _session(isHosted: false));

    await tester.tap(find.text('Apply License'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
  });

  testWidgets('the license buttons survive a narrow phone without overflow', (
    tester,
  ) async {
    // The tightest horizontal case on this tab, and a real trap: the test
    // font is one em per glyph, so "Purchase White Label" measures ~2x its
    // real Inter Tight width — which is roughly what a longer translation
    // costs anyway. The button labels therefore ellipsize rather than assume
    // English fits; drop `overflow: TextOverflow.ellipsis` and this fails
    // with an 88 px RenderFlex overflow.
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pump(tester, _session(isHosted: false));

    expect(find.text('Purchase White Label'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
