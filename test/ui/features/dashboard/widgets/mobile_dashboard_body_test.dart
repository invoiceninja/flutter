import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/hide_empty_panels_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_card_config.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_list_rows.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/repositories/invoice_repository.dart';
import 'package:admin/data/repositories/quote_repository.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/widgets/error_view.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/billing_pipeline_card.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/chart_card.dart';
import 'package:admin/ui/features/dashboard/widgets/configured_cards_grid.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/dashboard/widgets/list_card_skeleton.dart';
import 'package:admin/ui/features/dashboard/widgets/mobile_dashboard_body.dart';
import 'package:admin/ui/features/dashboard/widgets/task_calendar_card.dart';
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

/// `auth.session`, `tasks` and `hideEmptyPanels` are what
/// `MobileDashboardBody` reaches for. Its `enabledModules` mask gates the
/// pinned past-due card and the trailing panels; everything else falls through
/// to [noSuchMethod].
///
/// The task repository is stubbed even though most cases here run at `mask = 0`
/// and never build the task-calendar panel: the moment a test enables the tasks
/// module it would otherwise hit `noSuchMethod` from inside a widget build,
/// which reads as a layout failure rather than a missing double.
class _FakeServices implements Services {
  _FakeServices(this.auth, this.hideEmptyPanels);
  @override
  final AuthRepository auth;

  /// A real controller over the test database. Tests steer it through
  /// `value` rather than `set()`: awaiting a Drift write inside a widget test's
  /// fake-async zone can hang, and `set()` assigns `value` before it writes.
  @override
  final HideEmptyPanelsController hideEmptyPanels;
  @override
  final TaskRepository tasks = _FakeTaskRepo();

  // The Invoices & Quotes panel is the second Drift-backed one, and it renders
  // for either billing module — so these are reached by every test here that
  // enables invoices or quotes, not just the one that names the panel.
  @override
  final InvoiceRepository invoices = _FakeInvoiceRepo();
  @override
  final QuoteRepository quotes = _FakeQuoteRepo();

  // The panel builds its tab set from the two entities' own `badgeModes`, and
  // resolves a row tap through the registry's route paths.
  @override
  final EntityRegistry entityRegistry = EntityRegistry(const {});

  @override
  Stream<int> watchEntityCount(
    EntityType type,
    String companyId, {
    String modeId = 'total',
  }) => Stream<int>.multi((c) {
    c.add(0);
    c.close();
  });

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeInvoiceRepo implements InvoiceRepository {
  @override
  Stream<List<Invoice>> watchRecent({
    required String companyId,
    required int limit,
    String? badgeModeId,
    Set<EntityState> states = const {EntityState.active},
  }) => Stream<List<Invoice>>.multi((c) {
    c.add(const <Invoice>[]);
    c.close();
  });

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async => false;

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeQuoteRepo implements QuoteRepository {
  @override
  Stream<List<Quote>> watchRecent({
    required String companyId,
    required int limit,
    String? badgeModeId,
    Set<EntityState> states = const {EntityState.active},
  }) => Stream<List<Quote>>.multi((c) {
    c.add(const <Quote>[]);
    c.close();
  });

  @override
  Future<bool> ensurePageLoaded({
    required String companyId,
    required int page,
    String? search,
    Set<EntityState> states = const {EntityState.active},
    Map<String, Set<String>> extraFilters = const {},
    bool ignoreCursor = false,
  }) async => false;

  @override
  Object? noSuchMethod(Invocation i) => throw UnimplementedError();
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
/// module-gated list card off — which is what most tests here want.
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
  late HideEmptyPanelsController pref;

  final formatter = Formatter(
    settings: CompanyFormatSettings.fallback,
    currencies: const {},
    countries: const {},
    dateFormats: const {'5': DatetimeFormat(id: '5', format: 'MMM d, yyyy')},
  );

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = FakeDashboardRepo(db);
    // Automatic — the state every device starts in.
    pref = HideEmptyPanelsController(db: db);
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
    pref.dispose();
    await db.close();
  });

  /// [width] is the body's own extent and defaults to an iPhone-class portrait
  /// width. [surface] sizes the render surface behind it — they differ once the
  /// shell's rail takes its share, which is exactly the landscape-phone case
  /// flutter#51 routes here.
  ///
  /// [surface] does **not** move `MediaQuery`: `setSurfaceSize` replaces the
  /// render view's configuration, while `MediaQuery.fromView` keeps reporting
  /// the test view's default 800x600 (`dashboard_screen_test.dart` has the full
  /// story). [media] overrides it, and it is what `Breakpoints.isPhone` and
  /// `InSpacing.lg` read — so without it no test here is on a phone, and the
  /// "Hide empty panels" default (flutter#161) resolves to off.
  Future<void> pumpBody(
    WidgetTester tester, {
    DashboardDateRange? range,
    double width = 390,
    Size? surface,
    Size? media,
    int enabledModules = 0,
    String permissions = '',
    bool isAdmin = true,
    double fabClearance = 0,
    VoidCallback? onShowPanels,
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
          pref,
        ),
        child: MaterialApp(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          theme: buildInTheme(InTheme.light),
          // Via `builder`, above the Navigator, so a dialog opened from the
          // body would see the same window.
          builder: media == null
              ? null
              : (context, inner) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(size: media),
                  child: inner!,
                ),
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: MobileDashboardBody(
                vm: vm,
                formatter: formatter,
                fabClearance: fabClearance,
                onOpenCard: (_) {},
                onPastDueInvoiceTap: (_) {},
                onAllInvoices: () {},
                onAllUpcomingInvoices: () {},
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
                onShowPanels: onShowPanels ?? () {},
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

  // flutter#164: the row under the hero carried New Client, Enter Expense and
  // Reports. The two creates are entries in the screen's `+` sheet now, and
  // Reports is in the main menu. flutter#52 had already dropped a New Invoice
  // tile from the same row.
  //
  // The mask is load-bearing. Before this change, Enter Expense rendered only
  // with the expenses module on, and the old New Invoice tile only with
  // invoices on. At the harness's `= 0` default a `findsNothing` on either
  // would prove nothing.
  testWidgets('the body carries no create or Reports tiles', (tester) async {
    await pumpBody(
      tester,
      enabledModules:
          EnabledModule.invoices.bitmask | EnabledModule.expenses.bitmask,
    );

    for (final label in const [
      'New Client',
      'Enter Expense',
      'New Invoice',
      'Reports',
    ]) {
      expect(find.text(label), findsNothing, reason: label);
    }
    // Positive control: the hero sat directly above the row, so the body has
    // rendered past the point where the tiles used to be.
    expect(find.text('Outstanding'), findsWidgets);
  });

  // The FAB covers the bottom 72 px of the body. Without the padding, the
  // last panel could never scroll out from under it.
  testWidgets('fabClearance extends only the bottom padding', (tester) async {
    await pumpBody(tester, fabClearance: 72);

    final list = tester.widget<ListView>(
      find
          .descendant(
            of: find.byType(MobileDashboardBody),
            matching: find.byType(ListView),
          )
          .first,
    );
    final padding = list.padding! as EdgeInsets;
    expect(padding.bottom - padding.top, 72);
    expect(padding.left, padding.top, reason: 'the gutters are unchanged');
  });

  // Everything above runs at `mask = 0`, so until this case the trailing-panel
  // path had no coverage at all — which is the path that was restructured when
  // a Drift-backed panel joined the five cache-backed ones (each builder now
  // returns its own already-wrapped widget instead of the loop wrapping them
  // all in `sectionListenable`).
  testWidgets('an enabled module renders its trailing panel', (tester) async {
    // A tall surface rather than a scroll: the trailing panels sit below the
    // hero, the chart and the activity feed, and a lazy `ListView` simply
    // never builds them at the harness's default 600 px.
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

  // invoiceninja/flutter#161 — "Hide empty panels". Automatic (the state every
  // device starts in) means on for a phone, so each case says which window it
  // is on; `media` is what makes it a phone (see `pumpBody`).
  group('hide empty panels', () {
    const phone = Size(390, 844);
    const tall = Size(390, 4000);
    final recurring = EnabledModule.recurringInvoices.bitmask;

    DashboardRecurringInvoiceRow recurringRow() =>
        DashboardRecurringInvoiceRow.fromJson({
          'id': 'r1',
          'number': 'R-0001',
          'client': {'id': 'c1', 'name': 'Acme Recurring'},
        });

    // A section emission is delivered asynchronously; this is the same settle
    // `chart_card_test` uses.
    Future<void> settle(WidgetTester tester) =>
        tester.pump(const Duration(milliseconds: 10));

    testWidgets('a phone leaves out a panel that loaded empty', (tester) async {
      await pumpBody(
        tester,
        enabledModules: recurring,
        surface: tall,
        media: phone,
      );
      repo.upcomingRecurring.add(const []);
      await settle(tester);

      expect(find.text('Upcoming Recurring Invoices'), findsNothing);
      expect(find.text('No upcoming recurring invoices'), findsNothing);
    });

    // The rebuild trap: the panel list is built once, and a section emission
    // only notifies its own card. A filter evaluated at build time alone
    // would keep showing whatever the first frame saw.
    testWidgets('the list follows its sections after the first build', (
      tester,
    ) async {
      await pumpBody(
        tester,
        enabledModules: recurring,
        surface: tall,
        media: phone,
      );
      // Nothing loaded yet is not "empty": the card stays, as a skeleton.
      expect(find.text('Upcoming Recurring Invoices'), findsOneWidget);
      expect(find.byType(ListCardSkeleton), findsOneWidget);

      repo.upcomingRecurring.add(const []);
      await settle(tester);
      expect(find.text('Upcoming Recurring Invoices'), findsNothing);

      repo.upcomingRecurring.add([recurringRow()]);
      await settle(tester);
      expect(find.text('Upcoming Recurring Invoices'), findsOneWidget);
      expect(find.text('Acme Recurring'), findsOneWidget);
    });

    testWidgets('switching it off while mounted brings the panel back', (
      tester,
    ) async {
      await pumpBody(
        tester,
        enabledModules: recurring,
        surface: tall,
        media: phone,
      );
      repo.upcomingRecurring.add(const []);
      await settle(tester);
      expect(find.text('Upcoming Recurring Invoices'), findsNothing);

      // What the switch's `set(false)` does before it writes.
      pref.value = false;
      await settle(tester);

      expect(find.text('Upcoming Recurring Invoices'), findsOneWidget);
      expect(find.text('No upcoming recurring invoices'), findsOneWidget);
    });

    testWidgets('an explicit off keeps a phone showing empty panels', (
      tester,
    ) async {
      pref.value = false;
      await pumpBody(
        tester,
        enabledModules: recurring,
        surface: tall,
        media: phone,
      );
      repo.upcomingRecurring.add(const []);
      await settle(tester);

      expect(find.text('No upcoming recurring invoices'), findsOneWidget);
    });

    testWidgets('automatic shows empty panels on a tablet', (tester) async {
      // Still android, so touch-primary — only the short side (800) says this
      // is not a phone, which is the half of `isPhone` the issue turns on.
      await pumpBody(
        tester,
        enabledModules: recurring,
        surface: tall,
        media: const Size(800, 1280),
      );
      repo.upcomingRecurring.add(const []);
      await settle(tester);

      expect(find.text('No upcoming recurring invoices'), findsOneWidget);
    });

    testWidgets('automatic shows empty panels on a desktop; an explicit on '
        'hides them there too', (tester) async {
      // A phone-sized desktop window: `shortestSide` alone would call it a
      // phone. Reset inside the body — the foundation-vars invariant check
      // runs before teardowns (see dashboard_screen_test.dart).
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await pumpBody(
          tester,
          enabledModules: recurring,
          surface: tall,
          media: phone,
        );
        repo.upcomingRecurring.add(const []);
        await settle(tester);
        expect(find.text('No upcoming recurring invoices'), findsOneWidget);

        pref.value = true;
        await settle(tester);
        expect(find.text('Upcoming Recurring Invoices'), findsNothing);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('the pinned past-due card hides too — "All caught up" is '
        'still nothing to show', (tester) async {
      await pumpBody(
        tester,
        enabledModules: EnabledModule.invoices.bitmask,
        surface: tall,
        media: phone,
      );
      expect(find.text('Needs your attention'), findsOneWidget);

      repo.pastDue.add(const []);
      await settle(tester);

      expect(find.text('Needs your attention'), findsNothing);
      expect(find.text('All caught up'), findsNothing);
    });

    testWidgets('a section that has not loaded shows a skeleton, never its '
        'empty message', (tester) async {
      // Off, so the card renders whatever state it is in. This used to print
      // "No upcoming recurring invoices" before any data had arrived.
      pref.value = false;
      await pumpBody(tester, enabledModules: recurring, surface: tall);

      expect(find.text('Upcoming Recurring Invoices'), findsOneWidget);
      expect(find.byType(ListCardSkeleton), findsOneWidget);
      expect(find.text('No upcoming recurring invoices'), findsNothing);
    });

    testWidgets('a failed first fetch shows its error, even while hiding', (
      tester,
    ) async {
      await pumpBody(
        tester,
        enabledModules: recurring,
        surface: tall,
        media: phone,
      );
      repo.refreshAllErrors = {
        DashboardKind.upcomingRecurring: Exception('offline'),
      };
      await vm.refresh();
      await settle(tester);

      expect(
        find.text("Couldn't load upcoming recurring invoices. Tap to retry."),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextButton, 'Retry'), findsOneWidget);
      // Inline, not `ErrorView`: that needs ~240 px, and in the card's fixed
      // box it scrolled Retry out of sight.
      expect(find.byType(ErrorView), findsNothing);
      expect(find.text('No upcoming recurring invoices'), findsNothing);
    });

    testWidgets('a card that loads empty keeps its height', (tester) async {
      // Off, so the card stays: its loading placeholder is sized like its
      // empty message, and a phone column below it doesn't jump on load.
      pref.value = false;
      // Wide enough that the message stays on one line in the test font,
      // whose glyphs are a full em wide — the real font fits a phone.
      await pumpBody(
        tester,
        enabledModules: recurring,
        width: 800,
        surface: const Size(900, 4000),
      );
      Finder card() => find.ancestor(
        of: find.text('Upcoming Recurring Invoices'),
        matching: find.byType(DashboardCardShell),
      );
      final loading = tester.getSize(card()).height;

      repo.upcomingRecurring.add(const []);
      await settle(tester);
      expect(find.text('No upcoming recurring invoices'), findsOneWidget);
      final empty = tester.getSize(card()).height;

      expect((empty - loading).abs(), lessThanOrEqualTo(4));
    });

    testWidgets('the chart keeps its element when past-due empties out', (
      tester,
    ) async {
      // Past-due is one list child whether or not it shows; a slot that came
      // and went shifted every unkeyed child below it, rebuilding the chart.
      await pumpBody(
        tester,
        enabledModules: EnabledModule.invoices.bitmask,
        surface: tall,
        media: phone,
      );
      expect(find.text('Needs your attention'), findsOneWidget);
      final chart = tester.element(find.byType(ChartCard));

      repo.pastDue.add(const []);
      await settle(tester);

      expect(find.text('Needs your attention'), findsNothing);
      expect(tester.element(find.byType(ChartCard)), same(chart));
    });

    testWidgets('a phone says how many empty panels it is hiding', (
      tester,
    ) async {
      var opened = 0;
      await pumpBody(
        tester,
        enabledModules: recurring | EnabledModule.quotes.bitmask,
        surface: tall,
        media: phone,
        onShowPanels: () => opened++,
      );
      expect(find.textContaining('empty panel'), findsNothing);

      repo.upcomingRecurring.add(const []);
      await settle(tester);
      expect(find.text('1 empty panel hidden'), findsOneWidget);

      repo.upcomingQuotes.add(const []);
      repo.expiredQuotes.add(const []);
      await settle(tester);
      expect(find.text('3 empty panels hidden'), findsOneWidget);

      await tester.tap(find.text('3 empty panels hidden'));
      expect(opened, 1);
    });

    testWidgets('no hint while hiding is off, or for a switched-off panel', (
      tester,
    ) async {
      pref.value = false;
      await pumpBody(
        tester,
        enabledModules: recurring,
        surface: tall,
        media: phone,
      );
      repo.upcomingRecurring.add(const []);
      await settle(tester);
      expect(find.textContaining('empty panel'), findsNothing);

      // Back to automatic (on for a phone), but the user switched the panel
      // off: it is absent for its own reason, not hidden for being empty.
      vm.togglePanelVisibility(DashboardKind.upcomingRecurring);
      pref.value = null;
      await settle(tester);
      expect(find.text('Upcoming Recurring Invoices'), findsNothing);
      expect(find.textContaining('empty panel'), findsNothing);
    });

    // The two Drift-backed panels are never "empty" — their tabs and month
    // arrows lead elsewhere, and each runs the fetch that fills it. They must
    // also survive a neighbour leaving, or their view models are rebuilt.
    testWidgets('the Drift-backed panels stay, keep their state, and close '
        'the gap a hidden neighbour leaves', (tester) async {
      await pumpBody(
        tester,
        enabledModules:
            EnabledModule.tasks.bitmask | EnabledModule.quotes.bitmask,
        permissions: 'view_task,view_quote',
        isAdmin: false,
        surface: tall,
        media: phone,
      );
      expect(find.text('Upcoming Quotes'), findsOneWidget);
      final calendar = tester.state(find.byType(DashboardTaskCalendarCard));
      final pipeline = tester.state(find.byType(DashboardBillingPipelineCard));

      repo.upcomingQuotes.add(const []);
      repo.expiredQuotes.add(const []);
      await settle(tester);

      expect(find.text('Upcoming Quotes'), findsNothing);
      expect(find.text('Expired Quotes'), findsNothing);
      // The calendar renders over an empty tasks table — "nothing booked".
      expect(find.text('Task calendar'), findsOneWidget);
      expect(
        tester.state(find.byType(DashboardTaskCalendarCard)),
        same(calendar),
      );
      // The list keeps the Invoices & Quotes card too. (This harness's empty
      // registry gives it a lone `All` tab, which the card itself renders as
      // nothing — its own rule, unrelated to this one.)
      expect(
        tester.state(find.byType(DashboardBillingPipelineCard)),
        same(pipeline),
      );
      // The two quote panels sat between these; they took their gaps with
      // them, leaving exactly one (`InSpacing.lg` is 12 at phone width).
      final above = tester.getRect(find.byType(DashboardBillingPipelineCard));
      final below = tester.getRect(find.byType(DashboardTaskCalendarCard));
      expect(below.top - above.bottom, 12);
    });
  });
}
