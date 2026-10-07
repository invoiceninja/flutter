import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/dashboard/dashboard_chart_series.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/dashboard/helpers/chart_series_math.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart'
    show ChartSeriesId, ChartGrouping;

DashboardChartPoint _p(String date, num total) => DashboardChartPoint(
  date: Date.tryParse(date),
  total: Decimal.parse(total.toString()),
  currency: '1',
);

/// Strictly increasing and de-duplicated by calendar day.
void _expectSortedUnique(List<Date> buckets) {
  for (var i = 1; i < buckets.length; i++) {
    expect(
      buckets[i - 1].compareTo(buckets[i]),
      lessThan(0),
      reason: 'buckets must be strictly increasing & unique: $buckets',
    );
  }
}

void main() {
  group('buildContinuousAxis — day', () {
    test('zero-fills a contiguous daily axis between start and end', () {
      final axis = buildContinuousAxis(
        pointsBySeries: {
          ChartSeriesId.expenses: [_p('2026-01-03', 100)],
          ChartSeriesId.invoices: const [],
          ChartSeriesId.payments: const [],
          ChartSeriesId.outstanding: const [],
        },
        startDate: const Date(2026, 1, 1),
        endDate: const Date(2026, 1, 5),
        grouping: ChartGrouping.day,
      );

      expect(axis.buckets, const [
        Date(2026, 1, 1),
        Date(2026, 1, 2),
        Date(2026, 1, 3),
        Date(2026, 1, 4),
        Date(2026, 1, 5),
      ]);
      expect(axis.values[ChartSeriesId.expenses], [0, 0, 100, 0, 0]);
      expect(axis.values[ChartSeriesId.invoices], [0, 0, 0, 0, 0]);
    });

    test('sums multiple points that fall on the same bucket', () {
      final axis = buildContinuousAxis(
        pointsBySeries: {
          ChartSeriesId.expenses: [_p('2026-01-02', 40), _p('2026-01-02', 60)],
        },
        startDate: const Date(2026, 1, 1),
        endDate: const Date(2026, 1, 3),
        grouping: ChartGrouping.day,
      );
      expect(axis.values[ChartSeriesId.expenses], [0, 100, 0]);
    });

    test('a sparse-but-equal series is no longer flat across the axis', () {
      final axis = buildContinuousAxis(
        pointsBySeries: {
          ChartSeriesId.expenses: [
            _p('2026-01-01', 222),
            _p('2026-01-15', 222),
            _p('2026-01-31', 222),
          ],
        },
        startDate: const Date(2026, 1, 1),
        endDate: const Date(2026, 1, 31),
        grouping: ChartGrouping.day,
      );
      final lane = axis.values[ChartSeriesId.expenses]!;
      expect(lane.toSet().length, greaterThan(1));
      expect(lane.where((v) => v == 222).length, 3);
      expect(lane.where((v) => v == 0).length, 28);
    });

    test('derives range from point dates when start/end are null', () {
      final axis = buildContinuousAxis(
        pointsBySeries: {
          ChartSeriesId.payments: [_p('2026-03-10', 5), _p('2026-03-12', 7)],
        },
        startDate: null,
        endDate: null,
        grouping: ChartGrouping.day,
      );
      expect(axis.buckets.first, const Date(2026, 3, 10));
      expect(axis.buckets.last, const Date(2026, 3, 12));
      expect(axis.values[ChartSeriesId.payments], [5, 0, 7]);
    });

    test('empty when there is nothing datable to plot', () {
      final axis = buildContinuousAxis(
        pointsBySeries: const {ChartSeriesId.invoices: []},
        startDate: null,
        endDate: null,
        grouping: ChartGrouping.day,
      );
      expect(axis.isEmpty, isTrue);
      expect(axis.buckets, isEmpty);
    });
  });

  group('buildContinuousAxis — month', () {
    test('partial-month-aware boundaries (Jan 15 → Mar 20)', () {
      final axis = buildContinuousAxis(
        pointsBySeries: {
          ChartSeriesId.expenses: [
            _p('2026-01-15', 1), // exactly on start
            _p('2026-02-10', 10), // mid-Feb → rolls into period-end bucket
          ],
        },
        startDate: const Date(2026, 1, 15),
        endDate: const Date(2026, 3, 20),
        grouping: ChartGrouping.month,
      );
      expect(axis.buckets, const [
        Date(2026, 1, 15),
        Date(2026, 1, 31),
        Date(2026, 2, 28),
        Date(2026, 3, 20),
      ]);
      _expectSortedUnique(axis.buckets);
      final lane = axis.values[ChartSeriesId.expenses]!;
      // start-exact stays in bucket 0; a strictly-inside point rolls to the
      // next boundary (period end) — React's getRecordIndex +1 rule.
      expect(lane[0], 1);
      expect(lane[2], 10);
      expect(lane.reduce((a, b) => a + b), 11);
    });

    test('full calendar year → 13 month-end boundaries', () {
      final axis = buildContinuousAxis(
        pointsBySeries: {
          ChartSeriesId.invoices: [_p('2026-06-15', 90)],
        },
        startDate: const Date(2026, 1, 1),
        endDate: const Date(2026, 12, 31),
        grouping: ChartGrouping.month,
      );
      expect(axis.buckets.length, 13);
      expect(axis.buckets.first, const Date(2026, 1, 1));
      expect(axis.buckets.last, const Date(2026, 12, 31));
      _expectSortedUnique(axis.buckets);
      // Total is preserved regardless of which June bucket it lands in.
      expect(axis.values[ChartSeriesId.invoices]!.reduce((a, b) => a + b), 90);
    });
  });

  group('buildContinuousAxis — week', () {
    test('weekly boundaries span start..end and capture points', () {
      final axis = buildContinuousAxis(
        pointsBySeries: {
          ChartSeriesId.payments: [
            _p('2026-01-01', 10), // exactly on start
            _p('2026-01-12', 7), // strictly inside the range
          ],
        },
        startDate: const Date(2026, 1, 1),
        endDate: const Date(2026, 1, 21),
        grouping: ChartGrouping.week,
      );
      expect(axis.buckets.first, const Date(2026, 1, 1));
      expect(axis.buckets.last, const Date(2026, 1, 21));
      expect(axis.buckets.length, greaterThan(2));
      _expectSortedUnique(axis.buckets);
      final lane = axis.values[ChartSeriesId.payments]!;
      // start-exact in bucket 0; both totals preserved across the axis.
      expect(lane[0], 10);
      expect(lane.reduce((a, b) => a + b), 17);
    });
  });

  group('buildContinuousAxis — render safety ceiling', () {
    test('a multi-year Day selection coarsens the rendered axis', () {
      final axis = buildContinuousAxis(
        pointsBySeries: {
          ChartSeriesId.expenses: [_p('2023-06-15', 50)],
        },
        startDate: const Date(2020, 1, 1),
        endDate: const Date(2026, 12, 31), // ~2557 days at Day granularity
        grouping: ChartGrouping.day,
      );
      // Coarsened well below a raw daily axis, and bounded.
      expect(axis.buckets.length, lessThanOrEqualTo(750));
      expect(axis.buckets.length, lessThan(2557));
      _expectSortedUnique(axis.buckets);
      expect(axis.values[ChartSeriesId.expenses]!.reduce((a, b) => a + b), 50);
    });
  });

  // The grouping the chart draws when the one asked for cannot show a shape.
  // Opt-in: the boundary rules above are a port of the web client's and stay
  // exactly as they are without the flag.
  group('refineShortRanges', () {
    Map<ChartSeriesId, List<DashboardChartPoint>> points() => {
      ChartSeriesId.invoices: [_p('2026-04-08', 100), _p('2026-04-22', 50)],
      ChartSeriesId.payments: const [],
      ChartSeriesId.outstanding: const [],
      ChartSeriesId.expenses: const [],
    };

    test('one month by month is two boundaries — a single straight line', () {
      final axis = buildContinuousAxis(
        pointsBySeries: points(),
        startDate: const Date(2026, 4, 1),
        endDate: const Date(2026, 4, 30),
        grouping: ChartGrouping.month,
      );

      expect(axis.buckets.length, lessThan(4));
      expect(axis.grouping, ChartGrouping.month);
    });

    test('with the flag it is drawn by week, and says so', () {
      final axis = buildContinuousAxis(
        pointsBySeries: points(),
        startDate: const Date(2026, 4, 1),
        endDate: const Date(2026, 4, 30),
        grouping: ChartGrouping.month,
        refineShortRanges: true,
      );

      expect(axis.grouping, ChartGrouping.week);
      expect(axis.buckets.length, greaterThanOrEqualTo(4));
      _expectSortedUnique(axis.buckets);
      // Nothing is lost in the regrouping.
      expect(axis.values[ChartSeriesId.invoices]!.reduce((a, b) => a + b), 150);
    });

    test('a week by month goes all the way down to days', () {
      final axis = buildContinuousAxis(
        pointsBySeries: points(),
        startDate: const Date(2026, 4, 6),
        endDate: const Date(2026, 4, 12),
        grouping: ChartGrouping.month,
        refineShortRanges: true,
      );

      expect(axis.grouping, ChartGrouping.day);
      expect(axis.buckets.length, 7);
    });

    test('a range the grouping can draw is left alone', () {
      final axis = buildContinuousAxis(
        pointsBySeries: points(),
        startDate: const Date(2026, 1, 1),
        endDate: const Date(2026, 12, 31),
        grouping: ChartGrouping.month,
        refineShortRanges: true,
      );

      expect(axis.grouping, ChartGrouping.month);
    });

    test('a single day cannot be refined past days', () {
      final axis = buildContinuousAxis(
        pointsBySeries: points(),
        startDate: const Date(2026, 4, 8),
        endDate: const Date(2026, 4, 8),
        grouping: ChartGrouping.month,
        refineShortRanges: true,
      );

      expect(axis.grouping, ChartGrouping.day);
      expect(axis.isEmpty, isFalse);
    });
  });

  group('chartGroupingFits', () {
    test('a month fits days and weeks, not months', () {
      const start = Date(2026, 4, 1);
      const end = Date(2026, 4, 30);
      expect(chartGroupingFits(start, end, ChartGrouping.day), isTrue);
      expect(chartGroupingFits(start, end, ChartGrouping.week), isTrue);
      expect(chartGroupingFits(start, end, ChartGrouping.month), isFalse);
    });

    test('fifty years fits months, not days', () {
      const start = Date(2000, 1, 1);
      const end = Date(2050, 1, 1);
      expect(chartGroupingFits(start, end, ChartGrouping.month), isTrue);
      expect(chartGroupingFits(start, end, ChartGrouping.day), isFalse);
    });

    test('an inverted window fits nothing', () {
      expect(
        chartGroupingFits(
          const Date(2026, 5, 1),
          const Date(2026, 4, 1),
          ChartGrouping.day,
        ),
        isFalse,
      );
    });
  });
}
