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

    // invoiceninja/flutter#124. The card had never painted its fill, its
    // border or its tap ripple: it used `Ink(decoration:)`, which registers an
    // `InkDecoration` on the *nearest ancestor* `Material`, and a `Material`
    // draws its ink features BELOW its whole child subtree. In the app that
    // ancestor is the Scaffold's / the Drawer's, because `InSidebar` has no
    // `Material` of its own — so `InSidebar`'s opaque
    // `AnimatedContainer(color: tokens.surface)` covered the lot.
    //
    // The bug is invisible from inside this file's own harness, where the
    // Scaffold's Material sits directly above the widget with nothing opaque in
    // between and the card renders perfectly. So assert the *invariant* rather
    // than the appearance: the ink layer the card paints onto must be its own.
    testWidgets('paints onto its own Material, not an ancestor ink layer', (
      tester,
    ) async {
      await _pump(tester, _session(isHosted: false));

      final inkWell = find.descendant(
        of: find.byType(WhiteLabelFooter),
        matching: find.byType(InkWell),
      );
      expect(inkWell, findsOneWidget);

      Element? inkLayer;
      tester.element(inkWell).visitAncestorElements((e) {
        if (e.widget is Material) {
          inkLayer = e;
          return false;
        }
        return true;
      });

      expect(inkLayer, isNotNull);
      expect(
        inkLayer!.findAncestorWidgetOfExactType<WhiteLabelFooter>(),
        isNotNull,
        reason:
            'the nearest Material above the InkWell is outside the card, so '
            'its fill and ripple render under any opaque widget in between — '
            'in the sidebar, that is the rail background itself',
      );
      expect(
        (inkLayer!.widget as Material).color,
        InTheme.light.surfaceAlt,
        reason: 'the fill must ride on the Material, above its own ink layer',
      );
    });

    testWidgets('the card actually paints its fill, and nothing hides it', (
      tester,
    ) async {
      await _pump(tester, _session(isHosted: false));

      // The structural test above says the ink layer is the card's own. This
      // says the pixels arrive: pre-fix the fill was an `InkDecoration` painted
      // by an ANCESTOR's `_RenderInkFeatures`, so it did not appear in this
      // subtree's paint stream at all. `..path`, not `..rrect`, because a
      // `Material` with a shape goes through `RenderPhysicalShape`, which draws
      // with `canvas.drawPath`.
      expect(
        tester.renderObject(find.byType(WhiteLabelFooter)),
        paints..path(color: InTheme.light.surfaceAlt),
      );

      // ...and the load-bearing half the structural test can't see. The border
      // rides on a COLOURLESS Container inside the InkWell; giving it a `color`
      // — the obvious "one widget owns the box" simplification — would hide the
      // ripple under an opaque child again while leaving every other assertion
      // in this file green.
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(WhiteLabelFooter),
          matching: find.byType(Container),
        ),
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        isNull,
        reason: 'an opaque child inside the InkWell paints over the ripple',
      );
    });

    testWidgets('carries no top inset — the footer row above owns the gap', (
      tester,
    ) async {
      await _pump(tester, _session(isHosted: false));

      // `SidebarFooterActions` already ends with 8 px. A 12 here made it 20,
      // which with the misplaced safe-area inset was the 44 px gap #124 was
      // filed about.
      expect(
        tester
                .getRect(
                  find.descendant(
                    of: find.byType(WhiteLabelFooter),
                    matching: find.byType(InkWell),
                  ),
                )
                .top -
            tester.getRect(find.byType(WhiteLabelFooter)).top,
        0,
      );
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

    testWidgets('carries no top inset, like its slot-mate', (tester) async {
      // The two cards share a slot and must move together — the footer icon row
      // above already ends with 8 px, so a 12 here would reinstate half of the
      // #124 gap on whichever of the two happens to render.
      await _pump(tester, _session(isHosted: true, trialDaysLeft: 5));

      expect(
        tester.getRect(find.byType(Container).first).top -
            tester.getRect(find.byType(TrialFooter)).top,
        0,
      );
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
