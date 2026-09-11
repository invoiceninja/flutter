import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/configured_cards_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/dashboard/widgets/mobile_dashboard_body.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';
import '../../../../_responsive_helper.dart';
import '../_fake_dashboard_repo.dart';

/// flutter#37 was filed against the Android beta, and mobile was the worse
/// half of it: the AppBar carries a bare filter *icon*, so the selected window
/// appeared nowhere on the page. Every figure below was scoped to a range the
/// user could not see — "even more confusing when you start using filters like
/// `Last Year` or `Last Quarter` and that's what the app opens on".
///
/// The eyebrow now leads with the window. It displaces the company name and
/// the word "Dashboard", because one ellipsised 11 px line has no room for all
/// three. (It used to be justified by the AppBar title carrying the company;
/// flutter#50 retitled that bar to the page name, so the company now lives
/// only in the drawer's switcher. The assertion below is unchanged — the
/// eyebrow should not carry it either way.)
class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// `auth.session` and `tasks` are what `MobileDashboardBody` reaches for. Its
/// `enabledModules` mask gates the quick-action tiles and the trailing panels;
/// everything else falls through to [noSuchMethod].
///
/// The task repository is stubbed even though most cases here run at `mask = 0`
/// and never build the task-calendar panel: the moment a test enables the tasks
/// module it would otherwise hit `noSuchMethod` from inside a widget build,
/// which reads as a layout failure rather than a missing double.
class _FakeServices implements Services {
  _FakeServices(this.auth);
  @override
  final AuthRepository auth;
  @override
  final TaskRepository tasks = _FakeTaskRepo();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeTaskRepo implements TaskRepository {
  @override
  Stream<List<Task>> watchAllActive({
    required String companyId,
    states = const {},
  }) => Stream<List<Task>>.multi((c) {
    c.add(const <Task>[]);
    c.close();
  });

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    states = const {},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async => false;

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

/// [enabledModules] defaults to the `AuthCompany` default of 0 — every
/// module-gated tile and list card off — which is what most tests here want.
/// Pass a real mask only where the assertion depends on a gated widget
/// actually rendering, or a `findsNothing` proves nothing.
/// [permissions] / [isAdmin] matter only for the task-calendar panel, the one
/// kind whose gate is a module AND a permission. Admin short-circuits `can()`,
/// so a test proving the permission half must drop it.
AuthSession _session({
  int enabledModules = 0,
  String permissions = '',
  bool isAdmin = true,
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
  late FakeDashboardRepo repo;
  late DashboardViewModel vm;

  final formatter = Formatter(
    settings: CompanyFormatSettings.fallback,
    currencies: const {},
    countries: const {},
    dateFormats: const {'5': DatetimeFormat(id: '5', format: 'MMM d, yyyy')},
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    vm = DashboardViewModel(
      repo: repo,
      companyId: 'co',
      navStateDao: db.navStateDao,
      statics: StaticsRepository(
        db: db,
        service: StaticsService(dummyDashboardClient),
      ),
      // A range change schedules a debounced nav_state write; the default
      // 500 ms outlives the pump and trips "a Timer is still pending".
      persistDebounce: const Duration(milliseconds: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  /// [width] is the body's own extent and defaults to an iPhone-class portrait
  /// width. [surface] is the *window* behind it — they differ once the shell's
  /// rail takes its share, which is exactly the landscape-phone case flutter#51
  /// routes here. Setting it also moves `InSpacing.lg`, which reads the window
  /// rather than the box.
  Future<void> pumpBody(
    WidgetTester tester, {
    DashboardDateRange? range,
    double width = 390,
    Size? surface,
    int enabledModules = 0,
    String permissions = '',
    bool isAdmin = true,
  }) async {
    if (range != null) await vm.setDateRange(range);
    if (surface != null) {
      await tester.binding.setSurfaceSize(surface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(
          _FakeAuth(
            ValueNotifier(
              _session(
                enabledModules: enabledModules,
                permissions: permissions,
                isAdmin: isAdmin,
              ),
            ),
          ),
        ),
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          theme: buildInTheme(InTheme.light),
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: MobileDashboardBody(
                vm: vm,
                formatter: formatter,
                onOpenCard: (_) {},
                onPastDueInvoiceTap: (_) {},
                onAllInvoices: () {},
                onAllUpcomingInvoices: () {},
                onAddClient: () {},
                onLogExpense: () {},
                onReports: () {},
                onOutstandingTap: () {},
                onPaidTap: () {},
                onActivityTap: (_) {},
                onUpcomingInvoiceTap: (_) {},
                onPaymentTap: (_) {},
                onAllPayments: () {},
                onQuoteTap: (_) {},
                onAllQuotes: () {},
                onRecurringTap: (_) {},
                onAllRecurring: () {},
              ),
            ),
          ),
        ),
      ),
    );
    // Explicit durations, never pumpAndSettle — FreshnessTicker owns a 30 s
    // Timer.periodic and the VM holds a live watch subscription per section.
    await tester.pump(const Duration(milliseconds: 10));
  }

  String eyebrowText(WidgetTester tester) => tester
      .widget<Text>(
        find
            .descendant(
              of: find.byType(FreshnessTicker),
              matching: find.byType(Text),
            )
            .first,
      )
      .data!;

  testWidgets('the eyebrow states the active window', (tester) async {
    await pumpBody(
      tester,
      range: const DashboardCustomRange(
        start: Date(2026, 4, 1),
        end: Date(2026, 6, 30),
      ),
    );

    expect(
      eyebrowText(tester),
      startsWith('APR 1, 2026 — JUN 30, 2026 · UPDATED'),
    );
  });

  testWidgets('the window survives a range change', (tester) async {
    await pumpBody(
      tester,
      range: const DashboardPresetRange(DashboardDatePreset.thisMonth),
    );
    final monthly = eyebrowText(tester);

    await pumpBody(
      tester,
      range: const DashboardPresetRange(DashboardDatePreset.lastQuarter),
    );

    expect(
      eyebrowText(tester),
      isNot(monthly),
      reason: 'the eyebrow is the only place a phone shows the window',
    );
  });

  testWidgets('the eyebrow does not carry the company name', (tester) async {
    await pumpBody(tester);

    expect(eyebrowText(tester), isNot(contains('ACME CORPORATION')));
  });

  testWidgets('the hero sub-KPI reads "Paid", not "Paid this month"', (
    tester,
  ) async {
    await pumpBody(
      tester,
      range: const DashboardPresetRange(DashboardDatePreset.lastYear),
    );

    expect(find.text('PAID'), findsOneWidget);
    expect(find.textContaining('THIS MONTH'), findsNothing);
  });

  // flutter#51 routes a phone here in landscape too, so this body is laid out
  // past 600 px for the first time. The risk runs the opposite way to the rest
  // of the file, which guards against a layout that is too *narrow*. Both pane
  // widths a rotated handset produces: 890 − 232 with the rail expanded,
  // 890 − 64 collapsed.
  //
  // The cards are seeded deliberately. `ConfiguredCardsGrid` is the one thing
  // here that changes shape at this width — it tiers to two columns at 600
  // (`configured_cards_grid.dart`) — and the body mounts it only when
  // `vm.dashboardCards` is non-empty, so without a seed the sweep would render
  // a `SizedBox.shrink()` where the new layout is and quietly prove nothing.
  //
  // What it does not cover: the section streams stay empty, so the list cards
  // are skeletons rather than populated tables; and an ellipsised or clipped
  // `Text` throws nothing, so this catches overflow only.
  testWidgets('lays out on a landscape phone without overflowing', (
    tester,
  ) async {
    const a = DashboardCardConfig(
      field: 'invoices',
      period: CardPeriod.current,
      calculate: CardCalc.sum,
      format: CardFormat.money,
    );
    const b = DashboardCardConfig(
      field: 'logged_tasks',
      period: CardPeriod.total,
      calculate: CardCalc.count,
      format: CardFormat.money,
    );
    vm.addCard(a);
    vm.addCard(b);

    for (final width in const <double>[658, 826]) {
      await pumpBody(tester, width: width, surface: const Size(890, 412));

      expectNoOverflow(tester);
      expect(
        find.byType(ConfiguredCardsGrid),
        findsOneWidget,
        reason:
            'the seed must survive — an empty card list silently drops the '
            'only widget that reflows at this width',
      );
    }
  });

  // flutter#52: the quick-action row's first tile and `DashboardMobileAppBar`'s
  // pinned `+` both navigated to `/invoices/new` off the same module flag. The
  // tile is gone; the bar keeps the `+` (it survives scrolling, the row does
  // not).
  //
  // The mask is load-bearing. Every other test here runs at the `= 0` default,
  // where no module-gated tile renders at all — a bare `findsNothing` would
  // pass against the pre-fix code too and prove nothing.
  testWidgets('the quick-action row carries no New Invoice tile', (
    tester,
  ) async {
    await pumpBody(tester, enabledModules: EnabledModule.invoices.bitmask);

    expect(find.text('New Invoice'), findsNothing);
    // Positive control: `client` is always-on (`moduleForEntityType` returns
    // null for it), so this holds at any mask and proves the row itself
    // rendered rather than the whole body coming up empty.
    expect(find.text('New Client'), findsOneWidget);
  });

  // Everything above runs at `mask = 0`, so until this case the trailing-panel
  // path had no coverage at all — which is the path that was restructured when
  // a Drift-backed panel joined the five cache-backed ones (each builder now
  // returns its own already-wrapped widget instead of the loop wrapping them
  // all in `sectionListenable`).
  testWidgets('an enabled module renders its trailing panel', (tester) async {
    // A tall surface rather than a scroll: the trailing panels sit below the
    // hero, the quick actions, the chart and the activity feed, and a lazy
    // `ListView` simply never builds them at the harness's default 600 px.
    await pumpBody(
      tester,
      enabledModules: EnabledModule.quotes.bitmask,
      surface: const Size(390, 4000),
    );

    expect(find.text('Upcoming Quotes'), findsOneWidget);
    // Negative control at the same mask: a panel whose module is off stays off,
    // so this proves the gate still gates rather than the body rendering
    // everything.
    expect(find.text('Upcoming Invoices'), findsNothing);
  });

  // The task calendar is the one Drift-backed panel, so its `builders` entry is
  // the line that puts it on screen — and deleting that line, or registering it
  // under the wrong kind, is invisible to every other test here. This is the
  // half-ship `enabledPanelKinds` exists to prevent, on the body where it would
  // actually happen.
  testWidgets('the task calendar panel renders when tasks are available', (
    tester,
  ) async {
    await pumpBody(
      tester,
      enabledModules: EnabledModule.tasks.bitmask,
      permissions: 'view_task',
      isAdmin: false,
      surface: const Size(390, 4000),
    );

    expect(find.text('Task calendar'), findsOneWidget);
  });

  testWidgets('the task calendar panel is hidden without view_task', (
    tester,
  ) async {
    // Module on, permission missing: an ungated grid would paint every day
    // unbooked for a user whose Drift simply holds no tasks.
    await pumpBody(
      tester,
      enabledModules: EnabledModule.tasks.bitmask,
      isAdmin: false,
      surface: const Size(390, 4000),
    );

    expect(find.text('Task calendar'), findsNothing);
  });
}
