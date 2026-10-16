import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/data/models/domain/project/project_burnup.dart';
import 'package:admin/data/models/value/date.dart';

/// Decoder tests for the two per-project chart payloads
/// (`charts/project_analytics/{id}`, `charts/project_burnup/{id}`, server
/// 5.13.27+).
///
/// The shapes are transcribed from the server source
/// (`ProjectAnalyticsService::generate` / `ProjectBurnUpService::buildResponse`).
/// The decoders are tolerant, and these tests pin that tolerance: a renamed
/// or missing block must degrade to a hidden section, never an exception.
void main() {
  group('ProjectAnalytics — server-shaped payload', () {
    // Transcribed from ProjectAnalyticsService: every block is a LIST of
    // per-project rows; the project-scoped route returns exactly one.
    final payload = <String, dynamic>{
      'budget_summary': [
        {
          'project_id': 'abc',
          'project_name': 'Q1 work',
          'budgeted_hours': 40.0,
          'current_hours': 12.5,
          'task_rate': 100.0,
          'due_date': '2026-09-30',
          'total_tasks': 6,
          'invoiced_tasks': 2,
          'uninvoiced_tasks': 3,
          'running_tasks': 1,
          'utilization': 0.3125,
          'hours_remaining': 27.5,
          'budgeted_amount': 4000.0,
          'actual_amount': 1250.0,
          'remaining_budget': 2750.0,
          'budget_utilization': 0.3125,
          'currency_id': '1',
        },
      ],
      'budget_vs_actual': [
        {
          'budgeted_amount': 4000.0,
          'actual_amount': 1250.0,
          'labor_value': 1000.0,
          'expense_amount': 250.0,
          'remaining_budget': 2750.0,
          'budget_utilization': 0.3125,
          'currency_id': '1',
        },
      ],
      'invoice_progress': [
        {
          'completion_percentage': 31.25,
          'work_value': 1000.0,
          'invoiced_amount': 600.0,
          'paid_amount': 400.0,
          'outstanding_amount': 200.0,
          'unbilled_amount': 400.0,
          'invoice_progress': 0.6,
          'paid_progress': 0.6667,
          'currency_id': '1',
        },
      ],
      'profitability': [
        {
          'invoiced_amount': 600.0,
          'expense_amount': 250.0,
          'net_margin': 350.0,
          'margin_ratio': 0.5833,
          'currency_id': '1',
        },
      ],
      'project_health': [
        {
          'health_score': 72.5,
          'health_status': 'amber',
          'indicators': {
            'budget_utilization': 0.3125,
            'schedule_variance_days': -4,
            'margin_ratio': 0.5833,
            'unbilled_ratio': 0.4,
            'outstanding_ratio': 0.3333,
          },
        },
      ],
      'forecast_completion': [
        {
          'average_daily_velocity': 2.5,
          'remaining_hours': 27.5,
          'forecast_finish_date': '2026-10-27',
          'due_date': '2026-09-30',
          'schedule_variance_days': -27,
        },
      ],
      'timeline_variance': [
        {
          'completion_percentage': 31.25,
          'ideal_progress_percentage': 55.5,
          'schedule_variance_days': -27,
        },
      ],
      'estimated_vs_logged_hours': [
        {
          'estimated_hours': 40.0,
          'logged_hours': 12.5,
          'billable_hours': 10.0,
          'remaining_hours': 27.5,
        },
      ],
      'unbilled_hours': [
        {
          'unbilled_hours': 4.0,
          'unbilled_amount': 400.0,
          'uninvoiced_tasks': 3,
          'currency_id': '1',
        },
      ],
      'team_contribution': [
        {
          'project_id': 'abc',
          'team_contribution': [
            {
              'user_id': 'u1',
              'user_name': 'Ada',
              'logged_hours': 8.0,
              'billable_hours': 7.0,
              'billable_value': 700.0,
              'task_count': 2,
            },
          ],
        },
      ],
      'time_distribution': [
        {
          'time_distribution': [
            {
              'task_id': 't1',
              'task_number': '0007',
              'description': 'Design',
              'status_name': 'Done',
              'logged_hours': 5.5,
              'billable_hours': 5.0,
              'billable_value': 550.0,
              'is_completed': true,
              'is_invoiced': false,
            },
          ],
        },
      ],
      'velocity_trend': [
        {
          'velocity_trend': [
            {'period': '2026-08-03', 'hours': 3.0, 'billable_hours': 2.0},
            {'period': 'not a date', 'hours': 1.0},
          ],
        },
      ],
      'expense_breakdown': [
        {
          'expense_breakdown': [
            {
              'category_id': null,
              'category_name': 'Uncategorized',
              'expense_count': 1,
              'expense_amount': 250.0,
            },
          ],
        },
      ],
      'cumulative_spend': [
        {
          'cumulative_spend': [
            {
              'period': '2026-08-03',
              'cumulative_labor_value': 300.0,
              'cumulative_expense_amount': 250.0,
              'cumulative_actual_amount': 550.0,
            },
          ],
        },
      ],
      'metadata': {
        'project_count': 1,
        'include_drafts': true,
        'can_view_financials': true,
      },
    };

    test('flattens each single-row block', () {
      final a = ProjectAnalytics.fromJson(payload);

      expect(a.budgetSummary!.budgetedHours, 40.0);
      expect(a.budgetSummary!.taskRate, Decimal.parse('100'));
      expect(a.budgetSummary!.currentHours, 12.5);
      expect(a.budgetSummary!.budgetedAmount, Decimal.parse('4000'));
      expect(a.budgetSummary!.totalTasks, 6);
      expect(a.budgetSummary!.dueDate, const Date(2026, 9, 30));
      expect(a.budgetVsActual!.laborValue, Decimal.parse('1000'));
      expect(a.budgetVsActual!.expenseAmount, Decimal.parse('250'));
      expect(a.invoiceProgress!.workValue, Decimal.parse('1000'));
      expect(a.invoiceProgress!.paidProgress, closeTo(0.6667, 1e-9));
      expect(a.profitability!.netMargin, Decimal.parse('350'));
      expect(a.health!.score, 72.5);
      expect(a.health!.status, ProjectHealthStatus.fair);
      expect(a.health!.scheduleVarianceDays, -4);
      expect(a.health!.unbilledRatio, 0.4);
      expect(a.forecast!.forecastFinishDate, const Date(2026, 10, 27));
      expect(a.forecast!.scheduleVarianceDays, -27);
      expect(a.forecast!.averageDailyVelocity, 2.5);
      expect(a.timeline!.idealProgressPercentage, 55.5);
      expect(
        a.hours!.budgetedHours,
        40.0,
        reason:
            'the wire calls it '
            'estimated_hours, and it is the BUDGET',
      );
      expect(a.hours!.billableHours, 10.0);
      expect(a.unbilled!.amount, Decimal.parse('400'));
      expect(a.includeDrafts, isTrue);
      expect(a.canViewFinancials, isTrue);
    });

    test('the series blocks nest their rows one level down', () {
      final a = ProjectAnalytics.fromJson(payload);
      expect(a.team.single.userName, 'Ada');
      expect(a.team.single.billableValue, Decimal.parse('700'));
      expect(a.tasks.single.number, '0007');
      expect(a.tasks.single.isCompleted, isTrue);
      expect(
        a.velocity.map((d) => d.day),
        [const Date(2026, 8, 3)],
        reason: 'a row with no readable date is dropped',
      );
      expect(a.expenseCategories.single.categoryId, isNull);
      expect(a.cumulativeSpend.single.total, Decimal.parse('550'));
    });

    test('health statuses are the server\'s colours', () {
      expect(ProjectHealthStatus.parse('green'), ProjectHealthStatus.good);
      expect(ProjectHealthStatus.parse('amber'), ProjectHealthStatus.fair);
      expect(ProjectHealthStatus.parse('red'), ProjectHealthStatus.poor);
      expect(ProjectHealthStatus.parse('at_risk'), ProjectHealthStatus.unknown);
    });

    test('a user who may not see the money gets the forecast alone', () {
      final a = ProjectAnalytics.fromJson({
        'budget_summary': <Object>[],
        'forecast_completion': payload['forecast_completion'],
        'project_health': <Object>[],
        'metadata': {'can_view_financials': false},
      });
      expect(a.canViewFinancials, isFalse);
      expect(a.forecast, isNotNull);
      expect(a.budgetSummary, isNull);
      expect(a.health, isNull);
    });

    test('no metadata (a 5.13.27 server) reads as may see the money', () {
      expect(
        ProjectAnalytics.fromJson(const {}).canViewFinancials,
        isTrue,
        reason: 'that server gates the whole endpoint on view_dashboard',
      );
    });

    test('money decodes to Decimal, never double', () {
      final a = ProjectAnalytics.fromJson(payload);
      expect(a.budgetSummary!.budgetedAmount, isA<Decimal>());
      expect(a.profitability!.netMargin, isA<Decimal>());
    });
  });

  group('ProjectAnalytics — degrades instead of throwing', () {
    test('empty object yields an all-null result', () {
      final a = ProjectAnalytics.fromJson(<String, dynamic>{});
      expect(a.budgetSummary, isNull);
      expect(a.health, isNull);
      expect(a.team, isEmpty);
    });

    test('empty lists are treated as absent blocks', () {
      final a = ProjectAnalytics.fromJson({
        'budget_summary': <Object>[],
        'project_health': <Object>[],
        'team_contribution': <Object>[],
      });
      expect(a.budgetSummary, isNull);
      expect(a.health, isNull);
      expect(a.team, isEmpty);
    });

    test('a block that is not a list is ignored', () {
      final a = ProjectAnalytics.fromJson({
        'budget_summary': {'budgeted_hours': 10},
      });
      expect(a.budgetSummary, isNull);
    });

    test('missing keys inside a row fall back to zero/null', () {
      final a = ProjectAnalytics.fromJson({
        'budget_summary': [<String, dynamic>{}],
      });
      expect(a.budgetSummary, isNotNull);
      expect(a.budgetSummary!.budgetedHours, 0);
      expect(a.budgetSummary!.budgetedAmount, Decimal.zero);
      expect(a.budgetSummary!.dueDate, isNull);
      expect(a.budgetSummary!.currencyId, '');
    });

    test('money arriving as a string still decodes', () {
      final a = ProjectAnalytics.fromJson({
        'profitability': [
          {'net_margin': '350.75', 'invoiced_amount': '600'},
        ],
      });
      expect(a.profitability!.netMargin, Decimal.parse('350.75'));
      expect(a.profitability!.invoicedAmount, Decimal.parse('600'));
    });

    test('unparseable money falls back to zero rather than throwing', () {
      final a = ProjectAnalytics.fromJson({
        'profitability': [
          {'net_margin': 'n/a'},
        ],
      });
      expect(a.profitability!.netMargin, Decimal.zero);
    });

    test('a health row with no indicators reads as unknowns, not zeros', () {
      final a = ProjectAnalytics.fromJson({
        'project_health': [
          {'health_score': 40},
        ],
      });
      expect(a.health!.status, ProjectHealthStatus.unknown);
      expect(a.health!.scheduleVarianceDays, isNull);
    });
  });

  group('ProjectBurnup — server-shaped payload', () {
    final payload = <String, dynamic>{
      'start_date': '2026-01-01',
      'end_date': '2026-03-31',
      'bucket_type': 'monthly',
      'project': {
        'id': 'abc',
        'name': 'Q1 work',
        'budgeted_hours': 40.0,
        'task_rate': 100.0,
        'budgeted_amount': 4000.0,
        'currency_id': '1',
      },
      'markers': {
        'due_date': '2026-03-31',
        'budgeted_hours': 40.0,
        'budgeted_amount': 4000.0,
      },
      'series': [
        {
          'period_end': '2026-01-31',
          'cumulative_logged_hours': 5.0,
          'cumulative_billable_hours': 4.0,
          'cumulative_task_value': 500.0,
          'cumulative_invoiced_amount': 300.0,
          'cumulative_paid_to_date': 100.0,
          'cumulative_outstanding_amount': 200.0,
          'cumulative_expense_amount': 50.0,
          'ideal_hours': 13.3,
          'ideal_amount': 1330.0,
        },
        {
          'period_end': '2026-02-28',
          'cumulative_logged_hours': 12.5,
          'cumulative_billable_hours': 11.0,
          'cumulative_task_value': 1250.0,
          'cumulative_invoiced_amount': 600.0,
          'cumulative_paid_to_date': 400.0,
          'cumulative_outstanding_amount': 200.0,
          'cumulative_expense_amount': 250.0,
          'ideal_hours': 26.6,
          'ideal_amount': 2660.0,
        },
      ],
    };

    test('decodes markers, currency and the cumulative series', () {
      final b = ProjectBurnup.fromJson(payload);

      expect(b.isEmpty, isFalse);
      expect(b.bucketType, 'monthly');
      expect(b.currencyId, '1');
      expect(b.budgetedHours, 40.0);
      expect(b.budgetedAmount, Decimal.parse('4000'));
      expect(b.dueDate, const Date(2026, 3, 31));
      expect(b.series, hasLength(2));
      expect(b.series.last.cumulativeLoggedHours, 12.5);
      expect(b.series.last.cumulativeInvoicedAmount, Decimal.parse('600'));
      expect(b.series.last.idealAmount, Decimal.parse('2660'));
      expect(b.series.first.periodEnd, const Date(2026, 1, 31));
    });

    test('hasMoneySeries is true when any money is non-zero', () {
      expect(ProjectBurnup.fromJson(payload).hasMoneySeries, isTrue);
    });

    test('hasMoneySeries is false for a time-only project', () {
      // Drives the chart's fallback to the hours view — otherwise it would
      // render a flat zero money line.
      final b = ProjectBurnup.fromJson({
        'series': [
          {'period_end': '2026-01-31', 'cumulative_logged_hours': 5.0},
        ],
      });
      expect(b.hasMoneySeries, isFalse);
      expect(b.series.single.cumulativeLoggedHours, 5.0);
    });

    test('spend with nothing billed offers money but does not open on it', () {
      // The money view's default lines are invoiced and paid. Opening a
      // project with spend but nothing invoiced on them showed two flat zero
      // lines and hid the hours it does have; its expense line is one switch
      // away instead.
      final b = ProjectBurnup.fromJson({
        'series': [
          {
            'period_end': '2026-01-31',
            'cumulative_logged_hours': 8.0,
            'cumulative_expense_amount': 2400.0,
          },
        ],
      });
      expect(b.series.single.cumulativeExpenseAmount, Decimal.parse('2400'));
      expect(b.hasMoneySeries, isTrue);
      expect(b.hasBillingSeries, isFalse);
    });

    test('a user who may not see the money has no money view', () {
      final b = ProjectBurnup.fromJson({
        ...payload,
        'metadata': {'can_view_financials': false},
      });
      expect(b.hasMoneySeries, isFalse);
      expect(b.hasBillingSeries, isFalse);
    });

    test('net series are null on a server that does not send them', () {
      final b = ProjectBurnup.fromJson(payload);
      expect(b.series.first.cumulativeNetInvoiced, isNull);
      final withNet = ProjectBurnup.fromJson({
        'series': [
          {'period_end': '2026-01-31', 'cumulative_net_invoiced_amount': 250.0},
        ],
      });
      expect(withNet.series.single.cumulativeNetInvoiced, Decimal.parse('250'));
    });

    test('falls back to project.* when markers is absent', () {
      final b = ProjectBurnup.fromJson({
        'project': {'budgeted_hours': 20.0, 'budgeted_amount': 2000.0},
        'series': <Object>[],
      });
      expect(b.budgetedHours, 20.0);
      expect(b.budgetedAmount, Decimal.parse('2000'));
    });

    test('missing series yields an empty, non-throwing result', () {
      final b = ProjectBurnup.fromJson(<String, dynamic>{});
      expect(b.isEmpty, isTrue);
      expect(b.hasMoneySeries, isFalse);
      expect(b.budgetedAmount, Decimal.zero);
      expect(b.dueDate, isNull);
    });

    test('non-map entries in series are skipped', () {
      final b = ProjectBurnup.fromJson({
        'series': [
          'garbage',
          {'period_end': '2026-01-31', 'cumulative_logged_hours': 3.0},
          42,
        ],
      });
      expect(b.series, hasLength(1));
      expect(b.series.single.cumulativeLoggedHours, 3.0);
    });
  });

  // React #3380 — task estimates.
  group('task estimates', () {
    test('estimated_vs_logged_hours parses the task-estimate half', () {
      final a = ProjectAnalytics.fromJson({
        'estimated_vs_logged_hours': [
          {
            'task_estimated_hours': 40.0,
            'logged_hours': 12.5,
            'remaining_estimated_hours': 30.0,
            'unestimated_active_task_count': 3,
            'active_tasks_over_estimate_count': 1,
          },
        ],
      });
      final e = a.estimates!;
      expect(e.estimatedHours, 40.0);
      expect(e.loggedHours, 12.5);
      expect(e.remainingEstimatedHours, 30.0);
      expect(e.unestimatedTasks, 3);
      expect(e.tasksOverEstimate, 1);
    });

    test('nothing estimated, or an older server, is no card at all', () {
      final none = ProjectAnalytics.fromJson({
        'estimated_vs_logged_hours': [
          {'task_estimated_hours': 0, 'logged_hours': 5.0},
        ],
      });
      expect(none.estimates, isNull);
      final older = ProjectAnalytics.fromJson({
        'estimated_vs_logged_hours': [
          {'estimated_hours': 10.0, 'logged_hours': 5.0},
        ],
      });
      expect(older.estimates, isNull);
    });

    test('burn-up reads the estimate marker and the unestimated count', () {
      final b = ProjectBurnup.fromJson({
        'markers': {'task_estimated_hours': 24.0},
        'metadata': {'unestimated_task_count': 2},
        'series': <Object>[],
      });
      expect(b.taskEstimatedHours, 24.0);
      expect(b.unestimatedTaskCount, 2);
      expect(ProjectBurnup.fromJson(const {}).taskEstimatedHours, 0);
    });
  });
}
