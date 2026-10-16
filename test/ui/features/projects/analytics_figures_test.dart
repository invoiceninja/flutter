import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/analytics_figures.dart';

/// The decisions behind the Analytics tab's figures: which of the server's
/// numbers mean what they say, and how its sparse series are filled.
void main() {
  const today = Date(2026, 7, 24);

  ProjectForecast forecast({
    double velocity = 5,
    double remaining = 50,
    Date? finish = const Date(2026, 8, 3),
    int? variance = 58,
  }) => ProjectForecast(
    averageDailyVelocity: velocity,
    remainingHours: remaining,
    forecastFinishDate: finish,
    dueDate: const Date(2026, 9, 30),
    scheduleVarianceDays: variance,
  );

  group('forecastVerdict', () {
    test('a budget, hours to go and a pace: the server\'s forecast', () {
      final v = forecastVerdict(
        forecast: forecast(),
        budgetedHours: 100,
        loggedHours: 50,
      );
      expect(v, isA<ForecastPace>());
      expect((v as ForecastPace).varianceDays, 58);
    });

    test('no hours budget — the server would say "finishes today"', () {
      expect(
        forecastVerdict(
          forecast: forecast(remaining: 0, finish: today, variance: 68),
          budgetedHours: 0,
          loggedHours: 12,
        ),
        isA<ForecastNeedsBudget>(),
      );
    });

    test('over budget — the server would say "finishes today, ahead"', () {
      final v = forecastVerdict(
        forecast: forecast(remaining: 0, finish: today, variance: 68),
        budgetedHours: 100,
        loggedHours: 150,
      );
      expect(v, isA<ForecastOverBudget>());
      expect((v as ForecastOverBudget).overBy, 50);
    });

    test('nothing logged yet: no pace to forecast from', () {
      expect(
        forecastVerdict(
          forecast: forecast(velocity: 0, finish: null, variance: null),
          budgetedHours: 100,
          loggedHours: 0,
        ),
        isA<ForecastNeedsTime>(),
      );
      expect(
        forecastVerdict(forecast: null, budgetedHours: 100, loggedHours: 10),
        isA<ForecastNeedsTime>(),
        reason: 'no forecast block at all',
      );
    });
  });

  group('analyticsHasActivity', () {
    test('rows for every block, all zero, is no activity', () {
      // The server always sends one row per block — "no rows" never happens.
      final a = ProjectAnalytics.fromJson({
        'budget_summary': [
          {'budgeted_hours': 40.0},
        ],
        'project_health': [
          {'health_score': 100.0, 'health_status': 'green'},
        ],
      });
      expect(analyticsHasActivity(a), isFalse);
    });

    test('logged time, money or spend is activity', () {
      expect(
        analyticsHasActivity(
          ProjectAnalytics.fromJson({
            'estimated_vs_logged_hours': [
              {'logged_hours': 0.5},
            ],
          }),
        ),
        isTrue,
      );
      expect(
        analyticsHasActivity(
          ProjectAnalytics.fromJson({
            'profitability': [
              {'expense_amount': 10.0},
            ],
          }),
        ),
        isTrue,
      );
    });
  });

  group('rankWithOther', () {
    test('largest first, zeros dropped, the tail folded into Other', () {
      final values = [for (var i = 0; i < 12; i++) i.toDouble()];
      final rows = rankWithOther(values, (v) => v, keep: 3);
      expect([for (final r in rows.take(3)) r.item], [11.0, 10.0, 9.0]);
      expect(rows.last.isOther, isTrue);
      // 1..8 folded; the zero is gone.
      expect(rows.last.foldedCount, 8);
      expect(rows.last.value, 36);
      expect(rows.last.folded, [
        8.0,
        7.0,
        6.0,
        5.0,
        4.0,
        3.0,
        2.0,
        1.0,
      ], reason: 'kept, so a money "Other" is summed in Decimal');
    });

    test('one more than the cap is shown, not folded into an Other of one', () {
      final rows = rankWithOther([3.0, 2.0, 1.0, 4.0], (v) => v, keep: 3);
      expect(rows, hasLength(4));
      expect(rows.any((r) => r.isOther), isFalse);
    });
  });

  group('velocityBuckets', () {
    ProjectVelocityDay day(Date d, double h) =>
        ProjectVelocityDay(day: d, hours: h, billableHours: h);

    test('the days nobody logged anything are zeros, through today', () {
      final (:buckets, :weekly) = velocityBuckets([
        day(const Date(2026, 7, 20), 3),
        day(const Date(2026, 7, 22), 2),
      ], today: today);
      expect(weekly, isFalse);
      expect([for (final b in buckets) b.start.day], [20, 21, 22, 23, 24]);
      expect([for (final b in buckets) b.hours], [3, 0, 2, 0, 0]);
    });

    test('past the cap, weeks starting Monday', () {
      final (:buckets, :weekly) = velocityBuckets(
        [
          day(const Date(2026, 1, 7), 4), // a Wednesday
          day(const Date(2026, 1, 8), 1),
          day(const Date(2026, 7, 20), 2), // a Monday
        ],
        today: today,
        maxDailyBars: 60,
      );
      expect(weekly, isTrue);
      expect(buckets.first.start, const Date(2026, 1, 5));
      expect(buckets.first.hours, 5);
      expect(buckets.last.start, const Date(2026, 7, 20));
      expect(buckets.last.hours, 2);
      expect(
        buckets.where((b) => b.hours == 0),
        isNotEmpty,
        reason: 'the idle weeks are drawn',
      );
    });
  });

  group('spendBuckets', () {
    ProjectSpendPoint point(Date d, int labor, int expenses) =>
        ProjectSpendPoint(
          day: d,
          labor: Decimal.fromInt(labor),
          expenses: Decimal.fromInt(expenses),
          total: Decimal.fromInt(labor + expenses),
        );

    test('a total holds still between the days it moved', () {
      final (:buckets, weekly: _) = spendBuckets([
        point(const Date(2026, 7, 20), 100, 0),
        point(const Date(2026, 7, 23), 150, 50),
      ], today: today);
      expect(
        [for (final b in buckets) b.total],
        [
          for (final v in [100, 100, 100, 200, 200]) Decimal.fromInt(v),
        ],
      );
      expect(buckets.last.expenses, Decimal.fromInt(50));
    });
  });
}
