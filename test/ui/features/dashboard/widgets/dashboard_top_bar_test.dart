import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_refresh_button.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_top_bar.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';

import '../../../../_localization_helper.dart';
import '../_fake_dashboard_repo.dart';

/// #26 — the freshness stamp and Refresh moved out of the bottom of the
/// dashboard scroll and into the always-visible top bar. Both live in the
/// header now, and the header has to survive the extra width without crushing
/// the company name (the old `Expanded(title) + non-flex Wrap(actions)` split
/// gave the Wrap unbounded width, so it took its natural size first).
///
/// The old footers are gone by construction: `dashboard_screen.dart` no longer
/// imports `freshness.dart` at all, so a re-added desktop footer wouldn't
/// compile without someone deliberately restoring the import.
void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late DashboardViewModel vm;

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
      // Changing the range in a test schedules a debounced nav_state write;
      // the default 500 ms outlives the pump and trips the binding's
      // "a Timer is still pending" invariant.
      persistDebounce: const Duration(milliseconds: 1),
    );
    // Let _init() (hydrate + subscribeAll + refresh) settle. FakeDashboardRepo
    // returns no errors, so `lastRefreshed` is stamped by the time we pump.
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  /// Width is varied with a `SizedBox` on the default 800x600 surface rather
  /// than `tester.view.physicalSize` — the latter needs a matching
  /// `devicePixelRatio` and a `reset` teardown or it leaks into the next test.
  ///
  /// `theme: buildInTheme(...)` is mandatory, not decoration: `context.inTheme`
  /// is `Theme.of(this).extension<InTheme>()!`, so without it every widget in
  /// the bar throws a null-check on first build.
  Future<void> pumpBar(
    WidgetTester tester, {
    required double width,
    VoidCallback? onRefresh,
    DashboardDateRange? range,
  }) async {
    if (range != null) await vm.setDateRange(range);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: SizedBox(
            width: width,
            // The screen mounts the bar inside its own narrowly-scoped
            // ListenableBuilder (dashboard_screen.dart) — mirror that, or the
            // bar never rebuilds when the VM's refresh state flips.
            child: ListenableBuilder(
              listenable: vm,
              builder: (context, _) => DashboardTopBar(
                vm: vm,
                companyName: 'Acme Corporation',
                onRefresh: onRefresh ?? () {},
                onNewInvoice: () {},
              ),
            ),
          ),
        ),
      ),
    );
    // Explicit durations, never pumpAndSettle — FreshnessTicker owns a 30 s
    // Timer.periodic.
    await tester.pump(const Duration(milliseconds: 10));
  }

  testWidgets('renders the refresh button and the freshness stamp in the '
      'header', (tester) async {
    await pumpBar(tester, width: 1400);

    expect(
      find.descendant(
        of: find.byType(DashboardTopBar),
        matching: find.byType(DashboardRefreshButton),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DashboardTopBar),
        matching: find.byType(FreshnessTicker),
      ),
      findsOneWidget,
      reason: 'exactly one freshness stamp — never a header + footer pair',
    );
    // Stamped by _init()'s refresh; `formatRelativeTime` reports anything under
    // a minute as "just now".
    expect(find.textContaining('Updated just now'), findsOneWidget);
  });

  testWidgets('narrow header wraps instead of crushing the company name', (
    tester,
  ) async {
    // 600 is the minimum width that still renders the wide branch, and the
    // actions are far wider than the ~340 px they look — this is the case that
    // used to squeeze the title to an ellipsis (and, with a custom date range,
    // overflow the Row outright).
    await pumpBar(tester, width: 600);

    expect(tester.takeException(), isNull);
    expect(find.text('Acme Corporation'), findsOneWidget);
    expect(find.byType(DashboardRefreshButton), findsOneWidget);

    final titleWidth = tester.getSize(find.text('Acme Corporation')).width;
    expect(
      titleWidth,
      greaterThan(80),
      reason: 'title must keep a readable slice, not collapse to "A…"',
    );
  });

  testWidgets('wide header renders without overflow', (tester) async {
    await pumpBar(tester, width: 1400);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a custom date range at the minimum wide width still fits', (
    tester,
  ) async {
    // The widest the action cluster ever gets: a custom range renders two full
    // dates instead of a short preset word. Before the Row was restructured
    // this combination overflowed at 600 — the Wrap was a non-flex child, so it
    // took its full natural width and left the title nothing.
    await pumpBar(
      tester,
      width: 600,
      range: const DashboardCustomRange(
        start: Date(2026, 8, 1),
        end: Date(2026, 8, 31),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Acme Corporation'), findsOneWidget);
    expect(find.byType(DashboardRefreshButton), findsOneWidget);
  });

  testWidgets('tapping refresh fires the callback', (tester) async {
    var taps = 0;
    await pumpBar(tester, width: 1400, onRefresh: () => taps++);

    await tester.tap(find.byType(DashboardRefreshButton));
    await tester.pump(const Duration(milliseconds: 10));

    expect(taps, 1);
  });

  testWidgets('refresh button is disabled while a pass is in flight', (
    tester,
  ) async {
    // Drive the real in-flight state rather than poking the VM's fields:
    // refresh() raises isAnyRefreshing and notifies before awaiting the repo,
    // and the gate holds the repo call open across the pump.
    final gate = Completer<void>();
    repo.refreshAllGate = gate;
    final pass = vm.refresh();
    await pumpBar(tester, width: 1400);

    final button = tester.widget<TextButton>(
      find.descendant(
        of: find.byType(DashboardRefreshButton),
        matching: find.byType(TextButton),
      ),
    );
    expect(button.onPressed, isNull);
    // The label never changes — only the glyph — so the button's width can't
    // reflow the header mid-click.
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    gate.complete();
    await pass;
    await tester.pump(const Duration(milliseconds: 10));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a partial failure leaves the stamp unchanged so the caller can '
      'report it', (tester) async {
    await pumpBar(tester, width: 1400);
    final before = vm.lastRefreshed;

    repo.refreshAllErrors = {DashboardKind.pastDue: Exception('boom')};
    expect(await vm.refresh(), isFalse);

    expect(vm.lastRefreshed, before, reason: 'a failed pass must not stamp');
    expect(vm.globalError, isNotNull, reason: 'globalError must not stay null');
  });
}
