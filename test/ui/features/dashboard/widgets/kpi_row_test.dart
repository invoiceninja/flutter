import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_card.dart';
import 'package:admin/ui/features/dashboard/widgets/kpi_row.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';
import '../_fake_dashboard_repo.dart';

/// flutter#37 — the third KPI tile read "Paid this month" under *every* date
/// range, while its figure and its drill-through both tracked whatever range
/// was actually selected. Pick "Last quarter" and a quarter's revenue appeared
/// under a monthly heading.
///
/// The tile labels are now range-agnostic across the board, matching both
/// reference apps; the window is stated once in the page header instead (see
/// `dashboard_top_bar_test.dart` and `range_dates_test.dart`).
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

  /// 1400 px wide so the grid lays out all three tiles in one row.
  /// `theme: buildInTheme(...)` is mandatory — `context.inTheme` is a
  /// `Theme.of(this).extension<InTheme>()!` and null-checks without it.
  Future<void> pumpRow(WidgetTester tester, {DashboardDateRange? range}) async {
    if (range != null) await vm.setDateRange(range);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            child: ListenableBuilder(
              listenable: vm,
              builder: (context, _) => KpiRow(vm: vm, formatter: formatter),
            ),
          ),
        ),
      ),
    );
    // Explicit durations, never pumpAndSettle — the VM holds a live watch
    // subscription per section.
    await tester.pump(const Duration(milliseconds: 10));
  }

  List<String> labels(WidgetTester tester) => tester
      .widgetList<KpiCard>(find.byType(KpiCard))
      .map((c) => c.label)
      .toList();

  testWidgets('the paid tile is labelled "Paid", not "Paid this month"', (
    tester,
  ) async {
    await pumpRow(tester);

    expect(labels(tester), ['Outstanding', 'Unpaid', 'Paid']);
    expect(find.textContaining('this month'), findsNothing);
  });

  testWidgets('tile labels are identical under a non-month range', (
    tester,
  ) async {
    await pumpRow(
      tester,
      range: const DashboardPresetRange(DashboardDatePreset.thisMonth),
    );
    final monthly = labels(tester);

    await pumpRow(
      tester,
      range: const DashboardPresetRange(DashboardDatePreset.lastQuarter),
    );

    expect(
      labels(tester),
      monthly,
      reason:
          'a range-agnostic label cannot disagree with the figure beneath it',
    );
    expect(find.textContaining('month'), findsNothing);
  });

  testWidgets('a range-baked label never reaches the accessibility tree', (
    tester,
  ) async {
    // The semantics string is composed from the same label, so a regression
    // there would still read "Paid this month" to a screen reader.
    await pumpRow(
      tester,
      range: const DashboardPresetRange(DashboardDatePreset.lastYear),
    );

    final semantics = tester
        .widgetList<KpiCard>(find.byType(KpiCard))
        .map((c) => c.semanticsLabel ?? '')
        .join(' | ');
    expect(semantics, contains('Paid'));
    expect(semantics, isNot(contains('this month')));
  });

  testWidgets('the paid tile stays tappable for its drill-through', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: SizedBox(
            width: 1400,
            child: KpiRow(
              vm: vm,
              formatter: formatter,
              onPaidTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 10));

    await tester.tap(find.text('Paid'));
    await tester.pump(const Duration(milliseconds: 10));

    expect(taps, 1, reason: 'renaming the callback must not orphan the wire');
  });
}
