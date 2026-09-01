// Account Management → Overview's "New company" card (issue #104).
//
// Why it exists at all: `CompanyPicker`'s row was the ONLY route to
// `auth.addCompany()` in the app, and #104 moved that sheet's entry point into
// the drawer footer as a 24-px unlabelled icon. This card is the second route,
// and — unlike a row inside a sheet — a settings-search key can reach it.
//
// The flow itself (confirm → guards → busy dialog → error mapping) is
// `SettingsActions.addCompany`, covered from the other end by
// `company_picker_test.dart`. What is pinned here is the gating, which is the
// half that differs per surface.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/views/basic/account_management/overview_screen.dart';

import '../../../../shell/_shell_test_helpers.dart';

void main() {
  Future<void> pumpOverview(
    WidgetTester tester, {
    bool isOwner = true,
    String plan = 'pro',
    int hostedCompanyCount = 10,
  }) async {
    final fixture = await buildFixture(
      companies: [FakeCompany(id: 'c1', name: 'Acme Co', isOwner: isOwner)],
      currentCompanyId: 'c1',
      plan: plan,
      hostedCompanyCount: hostedCompanyCount,
    );
    // Dispose from the body, under real timers: `AppDatabase.close()` waits on
    // Drift stream teardown that resolves on `Timer.run`, and fake time stops
    // advancing once the body ends — an `addTearDown(fixture.dispose)` here
    // hangs the file with no output rather than failing.
    addTearDown(() => tester.runAsync(fixture.dispose));

    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // The card alone, not `AccountManagementOverviewScreen`: that screen opens
    // a `watchCompany` Drift stream, and its `StreamBuilder` schedules drift's
    // zero-duration close timer as it unmounts — after the last pump, where the
    // binding's `!timersPending` check has no way to let it fire. This card
    // owns no stream, which is what makes it pumpable at all.
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        SingleChildScrollView(
          child: NewCompanySection(
            session: fixture.services.auth.session.value!,
          ),
        ),
      ),
    );
    // Not pumpAndSettle: the fixture owns live Drift watch streams.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Finder newCompanyButton() =>
      find.widgetWithText(FilledButton, 'New Company').last;

  testWidgets('an owner gets an enabled button that opens the confirm dialog', (
    tester,
  ) async {
    await pumpOverview(tester);

    expect(newCompanyButton(), findsOneWidget);
    expect(
      tester.widget<FilledButton>(newCompanyButton()).onPressed,
      isNotNull,
    );

    await tester.tap(newCompanyButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // The same dialog the picker's row raises — one flow, two surfaces.
    expect(find.text('Add Company'), findsWidgets);
  });

  testWidgets('a non-owner gets a disabled button that says why', (
    tester,
  ) async {
    await pumpOverview(tester, isOwner: false);

    // Disabled, not hidden: a reason the user can read beats a missing card.
    expect(tester.widget<FilledButton>(newCompanyButton()).onPressed, isNull);
    expect(
      find.text('Only the account owner can add companies'),
      findsOneWidget,
    );
  });

  testWidgets('the hosted plan limit stays tappable and routes to upgrade', (
    tester,
  ) async {
    // A dead end is worse than an upsell: "you need a bigger plan" with no way
    // to buy one is the one blocked state that must keep its button live.
    await pumpOverview(tester, plan: '', hostedCompanyCount: 1);

    expect(
      tester.widget<FilledButton>(newCompanyButton()).onPressed,
      isNotNull,
    );
    expect(find.text('Upgrade your plan to add companies'), findsOneWidget);
  });
}
