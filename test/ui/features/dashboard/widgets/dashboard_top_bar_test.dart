import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_create_fab.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_create_strip.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_period_bar.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_refresh_button.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_top_bar.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/ui/features/dashboard/widgets/freshness.dart';
import 'package:admin/ui/features/dashboard/widgets/manage_dashboard_cards_sheet.dart';

import '../../../../_localization_helper.dart';
import '../_fake_dashboard_repo.dart';

QuickCreateOption _option(EntityType type) =>
    QuickCreateOption(type: type, icon: Icons.add);

/// Every create the bar can be asked to hold — far more than fit at 600 px.
final List<QuickCreateOption> _manyCreates = [
  _option(EntityType.invoice),
  _option(EntityType.quote),
  _option(EntityType.payment),
  _option(EntityType.client),
  _option(EntityType.expense),
  _option(EntityType.task),
  _option(EntityType.project),
  _option(EntityType.vendor),
];

/// #26 — the freshness stamp and Refresh moved out of the bottom of the
/// dashboard scroll and into the always-visible top bar. Both live in the
/// header now, and the header has to survive the extra width without crushing
/// the company name (the old `Expanded(title) + non-flex Wrap(actions)` split
/// gave the Wrap unbounded width, so it took its natural size first).
///
/// The old footers are gone by construction: `dashboard_screen.dart` no longer
/// imports `freshness.dart` at all, so a re-added desktop footer wouldn't
/// compile without someone deliberately restoring the import.
///
/// The bar has since traded its filters for the create buttons: the date
/// range, currency and include-drafts controls moved into the page, above the
/// figures they change (`dashboard_period_bar_test.dart`), and what the user
/// may create sits here so it is on screen however far the page is scrolled.
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

  /// The surface itself is sized (with its `devicePixelRatio` and a `reset`
  /// teardown, or it leaks into the next test), so 1400 means 1400.
  ///
  /// `theme: buildInTheme(...)` is mandatory, not decoration: `context.inTheme`
  /// is `Theme.of(this).extension<InTheme>()!`, so without it every widget in
  /// the bar throws a null-check on first build.
  Future<void> pumpBar(
    WidgetTester tester, {
    required double width,
    VoidCallback? onRefresh,
    DashboardDateRange? range,
    List<QuickCreateOption> creates = const [],
    ValueChanged<EntityType>? onCreate,
  }) async {
    if (range != null) await vm.setDateRange(range);
    // A real surface of this width: a `SizedBox` wider than the default
    // 800 px surface is clamped to it.
    tester.view.physicalSize = Size(width, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
                createOptions: creates,
                onCreate: onCreate ?? (_) {},
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

  testWidgets('a narrow header does not crush the company name', (
    tester,
  ) async {
    // 600 is the minimum width that still renders the wide branch — the case
    // that used to squeeze the title to an ellipsis.
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

  // ---------------------------------------------------------------------------
  // The create buttons.

  testWidgets('holds the create buttons, first one filled', (tester) async {
    final picked = <EntityType>[];
    await pumpBar(
      tester,
      width: 1400,
      creates: _manyCreates.take(3).toList(),
      onCreate: picked.add,
    );

    final strip = find.byType(DashboardCreateStrip);
    expect(strip, findsOneWidget);
    expect(
      find.descendant(of: strip, matching: find.byType(FilledButton)),
      findsOneWidget,
    );

    await tester.tap(find.descendant(of: strip, matching: find.text('Quote')));
    await tester.pump(const Duration(milliseconds: 10));
    expect(picked, [EntityType.quote]);
  });

  testWidgets('nothing creatable draws no create buttons', (tester) async {
    await pumpBar(tester, width: 1400);

    expect(find.byType(DashboardCreateStrip), findsNothing);
    expect(find.byType(DashboardRefreshButton), findsOneWidget);
  });

  // The strip is the flexible one. However many creates it is handed, the
  // fixed pair to its right keeps its place and the company keeps its name.
  for (final width in const <double>[600, 760, 1000, 1400]) {
    testWidgets('@ ${width.toInt()}px every create fits or folds into More', (
      tester,
    ) async {
      await pumpBar(tester, width: width, creates: _manyCreates);

      expect(tester.takeException(), isNull);
      final bar = tester.getRect(find.byType(DashboardTopBar));
      for (final type in [DashboardRefreshButton, DashboardCardsButton]) {
        final rect = tester.getRect(find.byType(type));
        expect(rect.right, lessThanOrEqualTo(bar.right), reason: '$type');
        expect(rect.width, greaterThan(0), reason: '$type');
      }
      expect(
        tester.getSize(find.text('Acme Corporation')).width,
        greaterThan(80),
        reason: 'the title must keep a readable slice, not collapse to "A…"',
      );
      // Whatever does not fit is one tap away, never gone: the buttons that
      // fit beside a More menu, or — in a slot too tight for a labelled
      // button — one `+` that opens them all. The wide layout has no FAB.
      final compact = find.byType(DashboardCreateMenuButton);
      if (compact.evaluate().isNotEmpty) {
        expect(find.byType(DashboardCreateStrip), findsNothing);
        await tester.tap(compact);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(MenuItemButton), findsNWidgets(_manyCreates.length));
      } else {
        expect(find.text('More'), findsOneWidget);
      }
    });
  }

  testWidgets('a long company name still leaves a create button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final picked = <EntityType>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: DashboardTopBar(
            vm: vm,
            companyName: 'Acme Corporation International Holdings Limited',
            onRefresh: () {},
            createOptions: _manyCreates,
            onCreate: picked.add,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));

    expect(tester.takeException(), isNull);
    await tester.tap(find.byType(DashboardCreateMenuButton));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('New Invoice'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(picked, [EntityType.invoice]);
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

  // ---------------------------------------------------------------------------
  // The subtitle is how fresh the data is, and nothing else. It used to lead
  // with the selected window (flutter#37); the window is stated beside the
  // control that changes it now, and repeating it up here would put one fact
  // in two places that can only disagree in how they phrase it.

  String subtitleText(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byType(FreshnessTicker),
          matching: find.byType(Text),
        ),
      )
      .data!;

  testWidgets('the subtitle is the freshness stamp alone', (tester) async {
    await pumpBar(
      tester,
      width: 1400,
      range: const DashboardPresetRange(DashboardDatePreset.lastQuarter),
    );

    expect(subtitleText(tester), 'Updated just now');
  });

  testWidgets('carries no date range, currency or drafts control', (
    tester,
  ) async {
    await pumpBar(tester, width: 1400, creates: _manyCreates);

    final bar = find.byType(DashboardTopBar);
    for (final type in [DateRangePickerButton, IncludeDraftsSwitch]) {
      expect(
        find.descendant(of: bar, matching: find.byType(type)),
        findsNothing,
        reason: '$type lives in the page, above the figures it changes',
      );
    }
    expect(find.byIcon(Icons.settings_outlined), findsNothing);
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
