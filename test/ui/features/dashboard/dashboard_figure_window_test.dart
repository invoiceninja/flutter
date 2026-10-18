// The Invoices and Paid figures' drill-downs used to open on the whole
// resolved window, while the figure itself (`DashboardApi.fetchTotals`) stops
// at today for a period in progress — so "This Month · Invoices" opened a list
// holding post-dated invoices the figure never counted. `dashboardFigureWindow`
// is the one place that picks the drill-down's window now. `today` is passed
// in rather than read from the clock, so these cases mean the same thing on
// every day of the year and in every time zone.

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/dashboard/views/dashboard_screen.dart';

void main() {
  // Mid-month, so "this month" is unmistakably in progress: its whole window
  // runs to the 31st, and the figure's to the 14th.
  const today = Date(2026, 5, 14);

  DashboardFilter filterFor(DashboardDatePreset preset) =>
      DashboardFilter(range: DashboardPresetRange(preset));

  group('dashboardFigureWindow', () {
    for (final wholeWindowOnAllTime in [false, true]) {
      final who = wholeWindowOnAllTime ? 'Paid' : 'Invoices';

      test('$who: this month, in progress, ends today — not on the 31st', () {
        expect(
          dashboardFigureWindow(
            filterFor(DashboardDatePreset.thisMonth),
            today: today,
            wholeWindowOnAllTime: wholeWindowOnAllTime,
          ),
          (const Date(2026, 5, 1), today),
        );
      });

      test('$who: last month, which is over, is the whole month', () {
        expect(
          dashboardFigureWindow(
            filterFor(DashboardDatePreset.lastMonth),
            today: today,
            wholeWindowOnAllTime: wholeWindowOnAllTime,
          ),
          (const Date(2026, 4, 1), const Date(2026, 4, 30)),
        );
      });
    }

    // "All time" has no comparison, so the two lists part ways there: the
    // Invoices list carries no window at all, the Paid list the resolved one.
    test('Invoices: all time has no window', () {
      expect(
        dashboardFigureWindow(
          filterFor(DashboardDatePreset.allTime),
          today: today,
          wholeWindowOnAllTime: false,
        ),
        isNull,
      );
    });

    test('Paid: all time is the resolved window', () {
      final filter = filterFor(DashboardDatePreset.allTime);
      expect(
        dashboardFigureWindow(filter, today: today, wholeWindowOnAllTime: true),
        filter.resolveDates(today: today),
      );
    });
  });
}
