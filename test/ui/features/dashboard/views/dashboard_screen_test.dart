import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/entity_modules.dart' show DisabledEntityDispatcher;
import 'package:admin/app/resync_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/features/dashboard/views/dashboard_screen.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_create_fab.dart';
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
/// **Two independent widths and a platform.** `wide` reads the screen's own
/// `LayoutBuilder` constraints while `globalNav` reads `MediaQuery` (the
/// window), so the harness sets them separately: `setSurfaceSize` for the
/// window, a `SizedBox` for the pane. That is exactly how the shell drives it —
/// content is inset by the rail via `Positioned.fill(left: railWidth)`. Since
/// flutter#51 there is a third input: `wide` also asks `Breakpoints.isPhone`,
/// which reads the window's `shortestSide` *and* `Env.isTouchPrimary` — hence
/// the `height` parameter below and the one platform override at the bottom.
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

  /// `_buildVm` hands the view model its completion signal. Never run: no test
  /// here is about Sync, and the inert runner keeps it that way.
  @override
  final ResyncController resync = ResyncController(
    runner: ({required companyId, onProgress, isCancelled}) async =>
        const <String>[],
  );

  /// Never completes, so `_formatter` stays null and the data body — the only
  /// part that touches Drift watch streams — is never built.
  @override
  Future<Formatter> formatterFor(String companyId) =>
      Completer<Formatter>().future;

  @override
  Formatter? formatterIfReady(String companyId) => null;

  /// Invoices and clients only: the dashboard offers to create what the
  /// registry can route to, so these two are all it ever offers here.
  @override
  final EntityRegistry entityRegistry = EntityRegistry({
    for (final (type, path) in const [
      (EntityType.client, '/clients'),
      (EntityType.invoice, '/invoices'),
    ])
      type: EntityHandlers(
        type: type,
        wireName: type.name,
        apiPath: '/api/v1$path',
        routePath: path,
        icon: Icons.circle,
        dispatcher: DisabledEntityDispatcher(type),
      ),
  });

  @override
  final UnsavedChangesGuard unsavedChangesGuard = UnsavedChangesGuard();

  /// Every `stageCreateDraft` call, as `(basePath, draft)`.
  final staged = <(String, Object?)>[];

  @override
  void stageCreateDraft(String basePath, Object? draft) =>
      staged.add((basePath, draft));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// An admin with no modules on unless told otherwise. Clients are always on,
/// so that admin may still create a client.
AuthSession _session({
  int enabledModules = 0,
  bool isAdmin = true,
  String permissions = '',
}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acct',
  companies: [
    AuthCompany(
      id: 'co',
      name: 'Acme Corporation',
      displayName: 'Acme Corporation',
      permissions: permissions,
      isAdmin: isAdmin,
      isOwner: isAdmin,
      enabledModules: enabledModules,
    ),
  ],
  currentCompanyId: 'co',
);

void main() {
  late AppDatabase db;
  late _FakeServices services;
  late ValueNotifier<AuthSession?> session;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    session = ValueNotifier<AuthSession?>(_session());
    services = _FakeServices(
      auth: _FakeAuth(session),
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
  ///
  /// [height] is load-bearing since flutter#51: `Breakpoints.isPhone` reads
  /// `shortestSide`, so a 890x412 window is a phone and a 890x820 one is not,
  /// at the same width and the same pane.
  Future<void> pumpScreen(
    WidgetTester tester, {
    required double window,
    double? pane,
    double height = 900,
  }) async {
    await tester.binding.setSurfaceSize(Size(window, height));
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
          // would pass for the wrong reason. Overridden in `builder`, above the
          // Navigator, so it reaches every route rather than `home` alone —
          // the placement `_responsive_helper.dart` uses for text scale.
          // (`tester.view.physicalSize` is the other way to move it.)
          builder: (context, inner) => MediaQuery(
            data: MediaQuery.of(context).copyWith(size: Size(window, height)),
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

  // ---------------------------------------------------------------------------
  // flutter#51 — a phone in landscape is a ~890 px *window*, so the rail is up
  // and its 232 px still leaves a ~658 px pane: wide by width alone, and the
  // desktop bar that earned it truncated the company name and wrapped its five
  // full-label buttons onto two runs of a 412 px-tall viewport. The branch now
  // also asks `Breakpoints.isPhone`, and both halves of that are pinned here:
  // the tablet case holds the pane byte-identical and moves only
  // `shortestSide`; the desktop case holds the whole geometry and moves only
  // the platform.

  testWidgets('landscape phone: narrow chrome even though the pane is wide', (
    tester,
  ) async {
    await pumpScreen(tester, window: 890, height: 412, pane: 658);

    expect(find.byType(DashboardMobileAppBar), findsOneWidget);
    expect(find.byType(DashboardTopBar), findsNothing);
    expect(
      find.text('Acme Corporation'),
      findsNothing,
      reason: 'the truncated company name is what flutter#51 was filed about',
    );
    // Same shape as the rail band above, reached by a different route: the
    // window is ≥ 600, so the global rail is already on screen and a drawer
    // would duplicate it.
    expect(find.byType(DrawerHamburger), findsNothing);
    expect(scaffold(tester).hasDrawer, isFalse);
  });

  testWidgets('a tablet at the same pane width keeps the wide bar', (
    tester,
  ) async {
    // Still the default android platform, so `Env.isTouchPrimary` is true and
    // only `shortestSide` (412 → 820) separates this from the case above. Drop
    // that half of the check and every tablet loses the rich layout while this
    // file stays green on the phone case alone.
    await pumpScreen(tester, window: 890, height: 820, pane: 658);

    expect(find.byType(DashboardTopBar), findsOneWidget);
    expect(find.byType(DashboardMobileAppBar), findsNothing);
  });

  testWidgets('a phone-shaped desktop window keeps the wide bar', (
    tester,
  ) async {
    // `flutter test` reports android, so without the `Env.isTouchPrimary` half
    // of the check every short desktop window — and 890x412 is an ordinary one
    // — would drop to the mobile chrome. Reset inside the body rather than via
    // addTearDown: the foundation-vars invariant check runs before teardowns,
    // so a lingering override fails the test (see copyable_value_test.dart).
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await pumpScreen(tester, window: 890, height: 412, pane: 658);

      expect(find.byType(DashboardTopBar), findsOneWidget);
      expect(find.byType(DashboardMobileAppBar), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // ---------------------------------------------------------------------------
  // flutter#164 — the narrow dashboard's `+` is a bottom-right FAB that opens a
  // choice of what to create. It replaced an app-bar icon that went straight
  // to New Invoice. The button and its sheet are covered by
  // `dashboard_create_fab_test.dart`. These tests cover what only the screen
  // decides: which layouts get the button, what it offers, and where a pick
  // goes.

  group('the create menu', () {
    Finder barPlus() => find.descendant(
      of: find.byType(DashboardMobileAppBar),
      matching: find.byIcon(Icons.add),
    );

    testWidgets('phone: a FAB, and no + in the bar', (tester) async {
      await pumpScreen(tester, window: 400);

      expect(find.byType(DashboardCreateFab), findsOneWidget);
      expect(barPlus(), findsNothing);
    });

    testWidgets('landscape phone: the FAB comes with the narrow chrome', (
      tester,
    ) async {
      await pumpScreen(tester, window: 890, height: 412, pane: 658);

      expect(find.byType(DashboardCreateFab), findsOneWidget);
    });

    testWidgets('rail band: the narrow pane gets it too', (tester) async {
      await pumpScreen(tester, window: 700, pane: 468);

      expect(find.byType(DashboardCreateFab), findsOneWidget);
    });

    testWidgets('wide: no FAB, the top bar keeps New Invoice', (tester) async {
      session.value = _session(enabledModules: EnabledModule.invoices.bitmask);
      await pumpScreen(tester, window: 1200);

      expect(find.byType(DashboardCreateFab), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DashboardTopBar),
          matching: find.text('New Invoice'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('it offers what the user may create, in menu order', (
      tester,
    ) async {
      session.value = _session(enabledModules: EnabledModule.invoices.bitmask);
      await pumpScreen(tester, window: 400);

      final fab = tester.widget<DashboardCreateFab>(
        find.byType(DashboardCreateFab),
      );
      expect(fab.options.map((o) => o.type), const [
        EntityType.invoice,
        EntityType.client,
      ]);
    });

    testWidgets('a user who may create nothing gets no FAB', (tester) async {
      session.value = _session(isAdmin: false, permissions: 'view_all');
      await pumpScreen(tester, window: 400);

      expect(find.byType(DashboardCreateFab), findsNothing);
    });

    // The session is rebuilt, company unchanged, when an admin grants a
    // permission or switches a module on. The screen used to rebuild only on a
    // company switch, which left the `+` as it was.
    testWidgets('a permission granted mid-session reaches the FAB', (
      tester,
    ) async {
      session.value = _session(isAdmin: false, permissions: 'view_all');
      await pumpScreen(tester, window: 400);
      expect(find.byType(DashboardCreateFab), findsNothing);

      session.value = _session(isAdmin: false, permissions: 'create_client');
      await tester.pump();

      expect(find.byType(DashboardCreateFab), findsOneWidget);
    });

    // The wide button used to check only the invoices module. So a user
    // without `create_invoice` was offered New Invoice and then refused when
    // saving. Both layouts now ask `_creatableEntities`.
    testWidgets('wide New Invoice needs create_invoice, not just the module', (
      tester,
    ) async {
      session.value = _session(
        enabledModules: EnabledModule.invoices.bitmask,
        isAdmin: false,
        permissions: 'view_all,edit_all',
      );
      await pumpScreen(tester, window: 1200);

      expect(find.byType(DashboardTopBar), findsOneWidget);
      expect(find.text('New Invoice'), findsNothing);
    });

    testWidgets('wide New Invoice shows for create_invoice', (tester) async {
      session.value = _session(
        enabledModules: EnabledModule.invoices.bitmask,
        isAdmin: false,
        permissions: 'create_invoice',
      );
      await pumpScreen(tester, window: 1200);

      expect(find.text('New Invoice'), findsOneWidget);
    });

    group('navigation', () {
      /// The screen under a real `GoRouter`, which `goToCreateRoute` needs.
      /// Each create route renders its own path, so a test can read where it
      /// landed.
      Future<void> pumpRouted(
        WidgetTester tester, {
        required double window,
      }) async {
        const height = 900.0;
        await tester.binding.setSurfaceSize(const Size(1600, height));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final router = GoRouter(
          initialLocation: '/dashboard',
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const DashboardScreen(),
            ),
            for (final path in const ['/clients/new', '/invoices/new'])
              GoRoute(path: path, builder: (_, _) => Text('route: $path')),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          Provider<Services>.value(
            value: services,
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: kTestLocalizationsDelegates,
              supportedLocales: kTestSupportedLocales,
              theme: buildInTheme(InTheme.light),
              builder: (context, inner) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(size: Size(window, height)),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(width: window, height: height, child: inner),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 10));
      }

      /// Explicit pumps: the body's spinner never settles.
      Future<void> tapAndWait(WidgetTester tester, Finder target) async {
        await tester.tap(target);
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      }

      testWidgets('a pick opens that entity\'s blank create screen', (
        tester,
      ) async {
        await pumpRouted(tester, window: 400);

        await tapAndWait(tester, find.byType(FloatingActionButton));
        await tapAndWait(tester, find.text('New Client'));

        expect(find.text('route: /clients/new'), findsOneWidget);
        expect(
          services.staged,
          const [('/clients', null)],
          reason:
              'goToCreateRoute stages a blank draft, which re-keys a create '
              'screen the branch left mounted; a bare go() reuses it',
        );
      });

      testWidgets('a dirty editor elsewhere is asked about first', (
        tester,
      ) async {
        final source = ValueNotifier(0);
        addTearDown(source.dispose);
        addTearDown(
          services.unsavedChangesGuard.register(
            isDirty: () => true,
            source: source,
          ),
        );
        await pumpRouted(tester, window: 400);

        await tapAndWait(tester, find.byType(FloatingActionButton));
        await tapAndWait(tester, find.text('New Client'));

        expect(find.text('Discard changes?'), findsOneWidget);
        await tapAndWait(tester, find.text('Keep editing'));

        expect(find.text('route: /clients/new'), findsNothing);
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(services.staged, isEmpty);
      });

      testWidgets('wide New Invoice goes the same way', (tester) async {
        session.value = _session(
          enabledModules: EnabledModule.invoices.bitmask,
        );
        await pumpRouted(tester, window: 1200);

        await tapAndWait(tester, find.text('New Invoice'));

        expect(find.text('route: /invoices/new'), findsOneWidget);
        expect(services.staged, const [('/invoices', null)]);
      });
    });
  });
}
