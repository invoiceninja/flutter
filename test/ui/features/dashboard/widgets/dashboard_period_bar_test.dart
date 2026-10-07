import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_totals.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/dashboard_comparison.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/dashboard_period_bar.dart';
import 'package:admin/ui/features/dashboard/widgets/filters/date_range_picker_button.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';
import '../_fake_dashboard_repo.dart';

/// The controls that decide what the period figures and the chart cover,
/// sitting directly above them: the date range, the currency, and whether
/// drafts count.
///
/// They lived in the page's top bar — the range as a button, the other two
/// behind a cog labelled "Settings" — and on a phone as a funnel icon and that
/// same cog. A control that has to be opened to learn its state is one the
/// user forgets is set.
void main() {
  late AppDatabase db;
  late FakeDashboardRepo repo;
  late DashboardViewModel vm;

  // `CompanyFormatSettings.fallback` is in currency 1.
  final formatter = Formatter(
    settings: CompanyFormatSettings.fallback,
    currencies: const {},
    countries: const {},
    dateFormats: const {},
  );

  DashboardTotals totals(Map<String, String> currencies) =>
      DashboardTotals.fromJson({
        'currencies': currencies,
        for (final id in currencies.keys)
          id: {
            'invoices': {'invoiced_amount': '10', 'code': currencies[id]},
          },
      });

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
      // A filter change schedules a debounced nav_state write; the default
      // 500 ms outlives the pump and trips "a Timer is still pending".
      persistDebounce: const Duration(milliseconds: 1),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    double width = 1000,
    bool compact = false,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ListenableBuilder(
              // As the screen mounts it: the filter on the global notify, the
              // totals (a second currency) on their section's.
              listenable: Listenable.merge([vm, vm.kpiListenable]),
              builder: (context, _) => DashboardPeriodBar(
                vm: vm,
                formatter: formatter,
                compact: compact,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }

  String windows(DashboardComparison c, {required bool both}) {
    final previous = formatter.dateRange(
      c.previousStart.toIso(),
      c.previousEnd.toIso(),
    );
    if (!both) return 'vs $previous';
    final current = formatter.dateRange(
      c.currentStart.toIso(),
      c.currentEnd.toIso(),
    );
    return '$current vs $previous';
  }

  group('the date range', () {
    testWidgets('is a button that names the selected range', (tester) async {
      await vm.setDateRange(
        const DashboardPresetRange(DashboardDatePreset.lastQuarter),
      );
      await pumpBar(tester);

      expect(
        find.descendant(
          of: find.byType(DateRangePickerButton),
          matching: find.text('Last Quarter'),
        ),
        findsOneWidget,
      );
      // A calendar, not a funnel: it picks dates, it does not filter rows.
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
    });

    // flutter#37: a preset's name leaves its dates unsaid, and the header that
    // used to state them named only the window's last month. Both windows are
    // derived from the view model rather than hardcoded — a quarter boundary
    // depends on today, and CI runs in UTC while the dev machines do not.
    testWidgets('a preset states the days measured and the days compared', (
      tester,
    ) async {
      await vm.setDateRange(
        const DashboardPresetRange(DashboardDatePreset.lastQuarter),
      );
      await pumpBar(tester);

      expect(find.text(windows(vm.comparison!, both: true)), findsOneWidget);
    });

    testWidgets('a custom range prints its dates once, on the button', (
      tester,
    ) async {
      await vm.setDateRange(
        const DashboardCustomRange(
          start: Date(2026, 3, 5),
          end: Date(2026, 3, 12),
        ),
      );
      await pumpBar(tester);

      // The eight days before it, and only those — the range itself is
      // already on the button.
      final c = vm.comparison!;
      expect(c.previousStart, const Date(2026, 2, 25));
      expect(c.previousEnd, const Date(2026, 3, 4));
      expect(find.text(windows(c, both: false)), findsOneWidget);
      expect(find.text(windows(c, both: true)), findsNothing);
    });

    testWidgets('All Time has nothing to compare with, and says nothing', (
      tester,
    ) async {
      await vm.setDateRange(
        const DashboardPresetRange(DashboardDatePreset.allTime),
      );
      await pumpBar(tester);

      expect(vm.comparison, isNull);
      expect(find.text('All Time'), findsOneWidget);
      expect(find.textContaining('vs '), findsNothing);
    });
  });

  group('currency', () {
    testWidgets('is not offered to a single-currency company', (tester) async {
      repo.totals.add(totals({'1': 'USD'}));
      await pumpBar(tester);
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byIcon(Icons.payments_outlined), findsNothing);
    });

    // The old dropdown fell back to every currency in the catalogue until the
    // totals arrived.
    testWidgets('is not offered on the strength of totals not yet loaded', (
      tester,
    ) async {
      await pumpBar(tester);

      expect(find.byIcon(Icons.payments_outlined), findsNothing);
    });

    testWidgets('appears once the totals carry a second currency', (
      tester,
    ) async {
      await pumpBar(tester);
      repo.totals.add(totals({'1': 'USD', '3': 'EUR'}));
      await tester.pump(const Duration(milliseconds: 10));

      expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
      expect(find.text('All currencies'), findsOneWidget);
    });
  });

  group('include drafts', () {
    testWidgets('shows its state at rest and flips it in place', (
      tester,
    ) async {
      await pumpBar(tester);

      expect(find.text('Include Drafts'), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pump(const Duration(milliseconds: 10));

      expect(vm.filter.includeDrafts, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('its label is part of the target', (tester) async {
      await pumpBar(tester);

      await tester.tap(find.text('Include Drafts'));
      await tester.pump(const Duration(milliseconds: 10));

      expect(vm.filter.includeDrafts, isTrue);
    });

    testWidgets('is one switch to a screen reader, labelled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBar(tester);

      expect(
        tester.getSemantics(find.byType(Switch)),
        isSemantics(
          label: 'Include Drafts',
          hasToggledState: true,
          isToggled: false,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });
  });

  // On a phone each control with its note beside it is too wide to share a
  // row with the next, and the block came to three 44 px rows. Compact, the
  // controls share a wrapping row and what they resolve to is one caption.
  group('compact', () {
    testWidgets('the controls come first, their notes as one caption', (
      tester,
    ) async {
      // 700 rather than a phone's width: the test font's glyphs are a full em
      // wide, so what fits one row on a real phone needs more room here. The
      // 320 px case below is the overflow guard.
      await pumpBar(tester, width: 700, compact: true);

      final c = vm.comparison!;
      final caption = find.text(windows(c, both: true));
      expect(caption, findsOneWidget);
      // Under the controls, not between them.
      for (final control in [
        find.byType(DateRangePickerButton),
        find.byType(Switch),
      ]) {
        expect(
          tester.getBottomLeft(control).dy,
          lessThanOrEqualTo(tester.getTopLeft(caption).dy),
        );
      }
      // One row of controls on a single-currency company: range and switch.
      expect(
        (tester.getCenter(find.byType(DateRangePickerButton)).dy -
                tester.getCenter(find.byType(Switch)).dy)
            .abs(),
        lessThan(12),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('holds at 320 px with every control', (tester) async {
      repo.totals.add(totals({'1': 'USD', '3': 'EUR'}));
      await pumpBar(tester, width: 320, compact: true);
      await tester.pump(const Duration(milliseconds: 10));

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
      expect(find.textContaining(' vs '), findsOneWidget);
    });
  });

  group('fits', () {
    for (final width in const <double>[320, 390, 700, 1000]) {
      testWidgets('@ ${width.toInt()}px with every control', (tester) async {
        await vm.setDateRange(
          const DashboardCustomRange(
            start: Date(2026, 12, 28),
            end: Date(2027, 12, 31),
          ),
        );
        repo.totals.add(totals({'1': 'USD', '3': 'EUR'}));
        await pumpBar(tester, width: width);
        await tester.pump(const Duration(milliseconds: 10));

        // It wraps rather than overflowing — every control stays on screen.
        expect(tester.takeException(), isNull);
        expect(find.byType(DateRangePickerButton), findsOneWidget);
        expect(find.byIcon(Icons.payments_outlined), findsOneWidget);
        expect(find.byType(Switch), findsOneWidget);
      });
    }
  });
}
