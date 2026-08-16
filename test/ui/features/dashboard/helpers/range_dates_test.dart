import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/datetime_format.dart';
import 'package:admin/ui/features/dashboard/helpers/range_dates.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

/// flutter#37: every dashboard figure is scoped to the selected window, but the
/// window itself was invisible on mobile and misreported on desktop (the top
/// bar named only the range's *end* month, so "Last quarter" read "June 2026").
/// This helper is the one place that turns the filter into the header string.
///
/// The calendar is pinned via the `today` seam rather than `Date.today()`, so
/// these expectations hold on a UTC CI box and a UTC+N laptop alike.
const _today = Date(2026, 8, 16);

Formatter _formatter() => Formatter(
  settings: CompanyFormatSettings.fallback,
  currencies: const {},
  countries: const {},
  dateFormats: const {'5': DatetimeFormat(id: '5', format: 'MMM d, yyyy')},
);

/// Pumps a throwaway tree just to get a localized `BuildContext`, and returns
/// what `dashboardRangeDates` produced.
Future<String> _dates(
  WidgetTester tester, {
  required DashboardDateRange range,
  Formatter? formatter,
  int firstMonthOfYear = 1,
  bool withFormatter = true,
}) async {
  late String result;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: Builder(
        builder: (context) {
          result = dashboardRangeDates(
            context,
            DashboardFilter(range: range, firstMonthOfYear: firstMonthOfYear),
            formatter: withFormatter ? (formatter ?? _formatter()) : null,
            today: _today,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return result;
}

Future<String> _preset(WidgetTester tester, DashboardDatePreset p) =>
    _dates(tester, range: DashboardPresetRange(p));

void main() {
  testWidgets('each preset renders its resolved window, not its name', (
    tester,
  ) async {
    // Anchored on Thu 16 Aug 2026 — Q3, so "last quarter" is Apr–Jun.
    expect(
      await _preset(tester, DashboardDatePreset.last7),
      'Aug 10, 2026 — Aug 16, 2026',
    );
    expect(
      await _preset(tester, DashboardDatePreset.last30),
      'Jul 18, 2026 — Aug 16, 2026',
    );
    expect(
      await _preset(tester, DashboardDatePreset.last365),
      'Aug 17, 2025 — Aug 16, 2026',
    );
    expect(
      await _preset(tester, DashboardDatePreset.thisMonth),
      'Aug 1, 2026 — Aug 31, 2026',
    );
    expect(
      await _preset(tester, DashboardDatePreset.lastMonth),
      'Jul 1, 2026 — Jul 31, 2026',
    );
    expect(
      await _preset(tester, DashboardDatePreset.thisQuarter),
      'Jul 1, 2026 — Sep 30, 2026',
    );
    expect(
      await _preset(tester, DashboardDatePreset.lastQuarter),
      'Apr 1, 2026 — Jun 30, 2026',
    );
    expect(
      await _preset(tester, DashboardDatePreset.thisYear),
      'Jan 1, 2026 — Dec 31, 2026',
    );
    expect(
      await _preset(tester, DashboardDatePreset.lastYear),
      'Jan 1, 2025 — Dec 31, 2025',
    );
  });

  testWidgets('"Last quarter" no longer reads as a single month', (
    tester,
  ) async {
    // The exact defect in the report: the header used to show the range's end
    // month alone, so a three-month window was indistinguishable from June.
    final text = await _preset(tester, DashboardDatePreset.lastQuarter);
    expect(text, contains('Apr'));
    expect(text, contains('Jun'));
  });

  testWidgets('allTime shows its name — a 50-year span is not context', (
    tester,
  ) async {
    expect(await _preset(tester, DashboardDatePreset.allTime), 'All Time');
  });

  testWidgets('a custom range shows the dates the user picked', (tester) async {
    expect(
      await _dates(
        tester,
        range: const DashboardCustomRange(
          start: Date(2026, 3, 5),
          end: Date(2026, 3, 12),
        ),
      ),
      'Mar 5, 2026 — Mar 12, 2026',
    );
  });

  testWidgets('a fiscal year start shifts thisYear / lastYear', (tester) async {
    // April fiscal year: "This year" is Apr 2026 – Mar 2027, and on 16 Aug 2026
    // "last year" is the Apr 2025 – Mar 2026 book.
    expect(
      await _dates(
        tester,
        range: const DashboardPresetRange(DashboardDatePreset.thisYear),
        firstMonthOfYear: 4,
      ),
      'Apr 1, 2026 — Mar 31, 2027',
    );
    expect(
      await _dates(
        tester,
        range: const DashboardPresetRange(DashboardDatePreset.lastYear),
        firstMonthOfYear: 4,
      ),
      'Apr 1, 2025 — Mar 31, 2026',
    );
  });

  testWidgets('the company date format is honoured, not a hardcoded pattern', (
    tester,
  ) async {
    final dmy = Formatter(
      settings: CompanyFormatSettings.fallback.copyWith(dateFormatId: '9'),
      currencies: const {},
      countries: const {},
      dateFormats: const {'9': DatetimeFormat(id: '9', format: 'd/M/yyyy')},
    );
    expect(
      await _dates(
        tester,
        range: const DashboardPresetRange(DashboardDatePreset.lastQuarter),
        formatter: dmy,
      ),
      '1/4/2026 — 30/6/2026',
    );
  });

  testWidgets('falls back to ISO before the per-company formatter resolves', (
    tester,
  ) async {
    // The dashboard paints its chrome before `Formatter` is built; the bar must
    // render something truthful rather than gate on it.
    expect(
      await _dates(
        tester,
        range: const DashboardPresetRange(DashboardDatePreset.lastQuarter),
        withFormatter: false,
      ),
      '2026-04-01 — 2026-06-30',
    );
  });
}
