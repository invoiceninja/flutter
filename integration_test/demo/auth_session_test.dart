/// Live demo coverage — authentication & session lifecycle.
///
/// Real login UI flow, session refresh round-trip, and logout against
/// `https://demo.invoiceninja.com`. Shared infra is in
/// `../support/demo_harness.dart`. See that file's header for the
/// runner/network-gating/"don't run locally" rationale.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:admin/main.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/auth/views/login_screen.dart';
import 'package:admin/ui/features/dashboard/views/dashboard_screen.dart';

import 'package:admin/data/repositories/local_data_disposer.dart';
import '../support/demo_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerDemoReachabilityProbe();

  testWidgets('full login UI flow against the demo server lands in the app', (
    tester,
  ) async {
    if (skipIfUnreachable()) return;
    await useDesktopSurface(tester);

    final bag = buildLiveServices();
    registerLiveTeardown(tester, bag);
    await bag.services.auth.restore(); // no creds → boots to /login

    await tester.pumpWidget(
      InvoiceNinjaApp(
        services: bag.services,
        dbWasReset: false,
        initialLocation: '/login',
      ),
    );
    await pumpUntilFound(tester, find.byType(LoginScreen));
    expect(find.byType(LoginScreen), findsOneWidget);

    // Two-step login. Step 1: switch to self-hosted so the server-URL field
    // appears, fill URL + email, Continue (which asks `/login/precheck`).
    // Step 2: the password. Fields are found by key, never by position —
    // the precheck decides which optional fields step 2 shows.
    Finder input(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.byType(TextField),
    );
    await tester.tap(find.text('Self-Hosted'));
    await tester.pumpAndSettle();

    await pumpUntilFound(tester, input('login_url'));
    await tester.enterText(input('login_url'), kDemoBaseUrl);
    await tester.enterText(input('login_email'), kDemoEmail);
    await tester.tap(find.byKey(const ValueKey('login_continue')));

    await pumpUntilFound(tester, input('login_password'));
    await tester.enterText(input('login_password'), kDemoPassword);
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    // demo user is owner/admin with view_dashboard → /dashboard.
    await pumpUntilFound(tester, find.byType(DashboardScreen));
    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(DashboardScreen),
        matching: find.byType(ErrorView),
      ),
      findsNothing,
    );
  });

  testWidgets('session refresh against the demo server keeps us signed in', (
    tester,
  ) async {
    if (skipIfUnreachable()) return;

    final bag = buildLiveServices();
    registerLiveTeardown(tester, bag);
    await loginDemo(bag.services);
    expect(bag.services.auth.isAuthenticated, isTrue);

    // Real GET /api/v1/refresh round-trip — must not throw and must leave
    // the session intact.
    await bag.services.auth.refreshSession();
    expect(bag.services.auth.isAuthenticated, isTrue);
    expect(bag.services.auth.session.value, isNotNull);
  });

  testWidgets('logout from a live session returns to /login', (tester) async {
    if (skipIfUnreachable()) return;

    final services = await bootLoggedIn(tester, initialLocation: '/dashboard');
    await pumpUntilFound(tester, find.byType(DashboardScreen));
    expect(find.byType(DashboardScreen), findsOneWidget);

    await services.auth.logout(data: LocalDataPolicy.destroy);
    await pumpUntilFound(tester, find.byType(LoginScreen));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(services.auth.isAuthenticated, isFalse);
  });
}
