import 'package:admin/data/models/value/dashboard_comparison.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:flutter_test/flutter_test.dart';

DashboardFilter _preset(DashboardDatePreset p, {int fiscal = 1}) =>
    DashboardFilter(range: DashboardPresetRange(p), firstMonthOfYear: fiscal);

void main() {
  group('a window still in progress compares like with like', () {
    test('this month on the 7th: the 1st–7th against the 1st–7th', () {
      final c = _preset(
        DashboardDatePreset.thisMonth,
      ).comparison(today: const Date(2026, 10, 7))!;
      expect(c.currentStart, const Date(2026, 10, 1));
      expect(c.currentEnd, const Date(2026, 10, 7));
      expect(c.previousStart, const Date(2026, 9, 1));
      expect(c.previousEnd, const Date(2026, 9, 7));
    });

    test('never runs past the end of a shorter month before it', () {
      // 30 days into March is the whole of February, not a window that runs
      // on into March itself.
      final c = _preset(
        DashboardDatePreset.thisMonth,
      ).comparison(today: const Date(2026, 3, 30))!;
      expect(c.previousStart, const Date(2026, 2, 1));
      expect(c.previousEnd, const Date(2026, 2, 28));
    });

    test('this month in January reaches back into December', () {
      final c = _preset(
        DashboardDatePreset.thisMonth,
      ).comparison(today: const Date(2026, 1, 10))!;
      expect(c.previousStart, const Date(2025, 12, 1));
      expect(c.previousEnd, const Date(2025, 12, 10));
    });

    test('this quarter: the same number of days into the quarter before', () {
      // Q4 starts Oct 1; Nov 14 is day 45.
      final c = _preset(
        DashboardDatePreset.thisQuarter,
      ).comparison(today: const Date(2026, 11, 14))!;
      expect(c.currentStart, const Date(2026, 10, 1));
      expect(c.currentEnd, const Date(2026, 11, 14));
      expect(c.previousStart, const Date(2026, 7, 1));
      expect(c.previousEnd, const Date(2026, 8, 14));
    });

    test('this quarter in Q1 reaches back into the year before', () {
      final c = _preset(
        DashboardDatePreset.thisQuarter,
      ).comparison(today: const Date(2026, 2, 3))!;
      expect(c.previousStart, const Date(2025, 10, 1));
      expect(c.previousEnd, const Date(2025, 11, 3));
    });

    test('this year follows the fiscal year', () {
      // April fiscal year: FY starts 2026-04-01; Oct 7 is day 190.
      final c = _preset(
        DashboardDatePreset.thisYear,
        fiscal: 4,
      ).comparison(today: const Date(2026, 10, 7))!;
      expect(c.currentStart, const Date(2026, 4, 1));
      expect(c.currentEnd, const Date(2026, 10, 7));
      expect(c.previousStart, const Date(2025, 4, 1));
      expect(c.previousEnd, const Date(2025, 10, 7));
    });

    test('a custom range that has not ended yet', () {
      const filter = DashboardFilter(
        range: DashboardCustomRange(
          start: Date(2026, 10, 1),
          end: Date(2026, 10, 20),
        ),
      );
      final c = filter.comparison(today: const Date(2026, 10, 5))!;
      // 20 days back from Oct 1, then the same five days.
      expect(c.previousStart, const Date(2026, 9, 11));
      expect(c.previousEnd, const Date(2026, 9, 15));
    });

    test('on the last day of the window the whole window is compared', () {
      final c = _preset(
        DashboardDatePreset.thisMonth,
      ).comparison(today: const Date(2026, 9, 30))!;
      expect(c.currentEnd, const Date(2026, 9, 30));
      expect(c.previousStart, const Date(2026, 8, 1));
      expect(c.previousEnd, const Date(2026, 8, 31));
    });
  });

  group('a finished window compares with the whole period before', () {
    test('last month is the calendar month before, not 30 days back', () {
      // September shifted back by its own 30 days starts on August 2nd.
      final c = _preset(
        DashboardDatePreset.lastMonth,
      ).comparison(today: const Date(2026, 10, 7))!;
      expect(c.currentStart, const Date(2026, 9, 1));
      expect(c.currentEnd, const Date(2026, 9, 30));
      expect(c.previousStart, const Date(2026, 8, 1));
      expect(c.previousEnd, const Date(2026, 8, 31));
    });

    test('last quarter is the quarter before it', () {
      final c = _preset(
        DashboardDatePreset.lastQuarter,
      ).comparison(today: const Date(2026, 10, 7))!;
      expect(c.currentStart, const Date(2026, 7, 1));
      expect(c.currentEnd, const Date(2026, 9, 30));
      expect(c.previousStart, const Date(2026, 4, 1));
      expect(c.previousEnd, const Date(2026, 6, 30));
    });

    test('last year is the fiscal year before it', () {
      final c = _preset(
        DashboardDatePreset.lastYear,
      ).comparison(today: const Date(2026, 10, 7))!;
      expect(c.currentStart, const Date(2025, 1, 1));
      expect(c.currentEnd, const Date(2025, 12, 31));
      expect(c.previousStart, const Date(2024, 1, 1));
      expect(c.previousEnd, const Date(2024, 12, 31));
    });

    test('a rolling window steps back by its own length', () {
      final c = _preset(
        DashboardDatePreset.last7,
      ).comparison(today: const Date(2026, 10, 7))!;
      expect(c.currentStart, const Date(2026, 10, 1));
      expect(c.currentEnd, const Date(2026, 10, 7));
      expect(c.previousStart, const Date(2026, 9, 24));
      expect(c.previousEnd, const Date(2026, 9, 30));
    });

    test('a finished custom range steps back by its own length', () {
      const filter = DashboardFilter(
        range: DashboardCustomRange(
          start: Date(2026, 9, 10),
          end: Date(2026, 9, 19),
        ),
      );
      final c = filter.comparison(today: const Date(2026, 10, 7))!;
      expect(c.previousStart, const Date(2026, 8, 31));
      expect(c.previousEnd, const Date(2026, 9, 9));
    });
  });

  test('all time has nothing before it to compare with', () {
    expect(
      _preset(
        DashboardDatePreset.allTime,
      ).comparison(today: const Date(2026, 10, 7)),
      isNull,
    );
  });

  test('the two windows never overlap', () {
    for (final preset in DashboardDatePreset.values) {
      for (final day in const [1, 7, 15, 28]) {
        final c = _preset(preset).comparison(today: Date(2026, 10, day));
        if (c == null) continue;
        expect(
          c.previousEnd.compareTo(c.currentStart) < 0,
          isTrue,
          reason: '$preset on the ${day}th: $c',
        );
        expect(
          c.previousStart.compareTo(c.previousEnd) <= 0,
          isTrue,
          reason: '$preset on the ${day}th: $c',
        );
      }
    }
  });
}
