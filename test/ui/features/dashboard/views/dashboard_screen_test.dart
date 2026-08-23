import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_mobile_app_bar.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_top_bar.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';
import '../_fake_dashboard_repo.dart';

/// Covers the three lines of `DashboardScreen` chrome wiring that no other test
/// reaches — which breakpoint picks the mobile bar, and whether the hamburger
/// agrees with the drawer it opens:
///
/// ```dart
/// drawer: globalNav ? null : const AppDrawer(),
/// appBar: wide ? null : _buildMobileAppBar(globalNav: globalNav),
/// showHamburger: !globalNav,
/// ```
///
/// Invert that negation and every `dashboard_mobile_app_bar_test` still passes
/// while a phone loses its hamburger — and the drawer is a phone's only route
/// to the rest of the app, so that is a navigation dead end, not a cosmetic
/// slip. `app_smoke_test.dart` can't catch it either: it runs at Flutter's
/// default 1600x1024, which takes the wide branch.
///
/// The screen was previously considered unpumpable because its VM constructor
/// runs `unawaited(_init())` into real Drift streams. It isn't: point
/// `formatterFor` at a future that never completes and `_formatter` stays null,
/// so the body renders a spinner and `MobileDashboardBody` — the part that
/// subscribes to those streams — is never built. Only the chrome under test
/// renders.
///
/// **Two independent widths.** `wide` reads the screen's own `LayoutBuilder`
/// constraints while `globalNav` reads `MediaQuery` (the window), so the
/// harness sets them separately: `setSurfaceSize` for the window, a `SizedBox`
/// for the pane. That is exactly how the shell drives it — content is inset by
/// the rail via `Positioned.fill(left: railWidth)`.
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
  _FakeServices({
    required this.auth,
    required this.dashboard,
    required this.db,
    required this.statics,
  });

  @override
  final AuthRepository auth;
  @override
  final DashboardRepository dashboard;
  @override
  final AppDatabase db;
  @override
  final StaticsRepository statics;

  /// Never completes, so `_formatter` stays null and the data body — the only
  /// part that touches Drift watch streams — is never built.
  @override
  Future<Formatter> formatterFor(String companyId) =>
      Completer<Formatter>().future;

  @override
  Formatter? formatterIfReady(String companyId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session() => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acct',
  companies: [
    const AuthCompany(
      id: 'co',
      name: 'Acme Corporation',
      displayName: 'Acme Corporation',
      permissions: '',
      isAdmin: true,
      isOwner: true,
    ),
  ],
  currentCompanyId: 'co',
);

void main() {
  late AppDatabase db;
  late _FakeServices services;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    services = _FakeServices(
      auth: _FakeAuth(ValueNotifier<AuthSession?>(_session())),
      dashboard: FakeDashboardRepo(db),
      db: db,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
    );
  });

  tearDown(() async => db.close());

  /// [window] drives `globalNav` (MediaQuery); [pane] drives `wide` (the
  /// screen's LayoutBuilder). The shell makes them differ by insetting content
  /// behind the 232 px rail, so `pane` defaults to the full window.
  Future<void> pumpScreen(
    WidgetTester tester, {
    required double window,
    double? pane,
  }) async {
    await tester.binding.setSurfaceSize(Size(window, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          theme: buildInTheme(InTheme.light),
          // `setSurfaceSize` gives the render surface its extent but does NOT
          // change what `MediaQuery.fromView` reports, so `globalNav` would
          // read the default 800 px at every width — and the rail-band test
          // would pass for the wrong reason. Override it here rather than
          // around `home`: `WidgetsApp` inserts its own `MediaQuery.fromView`
          // *inside* `MaterialApp`, so an outer one never reaches the child.
          // Same reason `_responsive_helper.dart` uses `builder:` for text
          // scale.
          builder: (context, inner) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: Size(window, 900)),
            child: inner!,
          ),
          home: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: pane ?? window,
              child: const DashboardScreen(),
            ),
          ),
        ),
      ),
    );
    // Never pumpAndSettle: the VM's _init() is in flight and the body would
    // spin forever.
    await tester.pump(const Duration(milliseconds: 10));
  }

  ScaffoldState scaffold(WidgetTester tester) =>
      tester.state<ScaffoldState>(find.byType(Scaffold).last);

  testWidgets('phone: mobile bar, hamburger, and a drawer to open', (
    tester,
  ) async {
    await pumpScreen(tester, window: 400);

    expect(find.byType(DashboardMobileAppBar), findsOneWidget);
    expect(find.byType(DashboardTopBar), findsNothing);
    expect(find.byType(DrawerHamburger), findsOneWidget);
    expect(
      scaffold(tester).hasDrawer,
      isTrue,
      reason: 'a hamburger with no drawer behind it is a dead end',
    );
  });

  // Window 700 with the rail expanded leaves the pane 468 — under the 600
  // breakpoint, so the mobile bar renders even though the global nav is up.
  // This is a real handset configuration: a 360x800 phone in landscape.
  testWidgets('rail band: mobile bar, but no hamburger and no drawer', (
    tester,
  ) async {
    await pumpScreen(tester, window: 700, pane: 468);

    expect(find.byType(DashboardMobileAppBar), findsOneWidget);
    expect(find.byType(DrawerHamburger), findsNothing);
    expect(
      scaffold(tester).hasDrawer,
      isFalse,
      reason: 'the rail is already on screen; a drawer would duplicate it',
    );
    expect(
      tester.getTopLeft(find.text('Dashboard')).dx,
      greaterThan(tester.getTopLeft(find.byType(DashboardMobileAppBar)).dx),
      reason: 'the title must not sit flush against the sidebar',
    );
  });

  testWidgets('wide: the bespoke top bar, no mobile bar at all', (
    tester,
  ) async {
    await pumpScreen(tester, window: 1200);

    expect(find.byType(DashboardTopBar), findsOneWidget);
    expect(find.byType(DashboardMobileAppBar), findsNothing);
    expect(
      find.text('Acme Corporation'),
      findsOneWidget,
      reason: 'flutter#50 changed the mobile bar only',
    );
  });
}
