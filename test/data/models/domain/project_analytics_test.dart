import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/data/models/domain/project/project_burnup.dart';
import 'package:admin/data/models/value/date.dart';

/// Decoder tests for the two per-project chart payloads
/// (`charts/project_analytics/{id}`, `charts/project_burnup/{id}`, both added
/// server-side 2026-06-30).
///
/// These matter more than usual: the endpoints **404 on `demo.invoiceninja.com`**
/// (verified 2026-07-24 — the demo host runs an older build than
/// `v5-develop`), so the shapes below are transcribed from the server source
/// (`ProjectAnalyticsService::generate` / `ProjectBurnUpService::buildResponse`)
/// rather than captured from a live response. The decoders are therefore
/// written to be tolerant, and these tests pin that tolerance: a renamed or
/// missing block must degrade to a hidden card, never an exception.
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
          'health_score': 72,
          'health_status': 'at_risk',
          'indicators': ['over_budget', 'past_due'],
        },
      ],
      'metadata': {'project_count': 1, 'include_drafts': false},
    };

    test('flattens each single-row block', () {
      final a = ProjectAnalytics.fromJson(payload);

      expect(a.isEmpty, isFalse);
      expect(a.budgetSummary!.budgetedHours, 40.0);
      expect(a.budgetSummary!.currentHours, 12.5);
      expect(a.budgetSummary!.budgetedAmount, Decimal.parse('4000'));
      expect(a.budgetSummary!.totalTasks, 6);
      expect(a.budgetSummary!.dueDate, const Date(2026, 9, 30));
      expect(a.budgetVsActual!.laborValue, Decimal.parse('1000'));
      expect(a.budgetVsActual!.expenseAmount, Decimal.parse('250'));
      expect(a.invoiceProgress!.workValue, Decimal.parse('1000'));
      expect(a.invoiceProgress!.paidProgress, closeTo(0.6667, 1e-9));
      expect(a.profitability!.netMargin, Decimal.parse('350'));
      expect(a.health!.score, 72);
      expect(a.health!.status, 'at_risk');
      expect(a.health!.indicators, ['over_budget', 'past_due']);
    });

    test('money decodes to Decimal, never double', () {
      final a = ProjectAnalytics.fromJson(payload);
      expect(a.budgetSummary!.budgetedAmount, isA<Decimal>());
      expect(a.profitability!.netMargin, isA<Decimal>());
    });
  });

  group('ProjectAnalytics — degrades instead of throwing', () {
    test('empty object yields an all-null, isEmpty result', () {
      final a = ProjectAnalytics.fromJson(<String, dynamic>{});
      expect(a.isEmpty, isTrue);
      expect(a.budgetSummary, isNull);
      expect(a.health, isNull);
    });

    test('empty lists are treated as absent blocks', () {
      final a = ProjectAnalytics.fromJson({
        'budget_summary': <Object>[],
        'project_health': <Object>[],
      });
      expect(a.isEmpty, isTrue);
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

    test('health indicators sent as a keyed map flatten to active reasons', () {
      // The server type is loose here, so accept both shapes; a false flag is
      // not an active reason and must not become a bullet.
      final a = ProjectAnalytics.fromJson({
        'project_health': [
          {
            'health_score': 40,
            'indicators': {'over_budget': true, 'past_due': false},
          },
        ],
      });
      expect(a.health!.indicators, ['over_budget']);
    });

    test('health indicators of nested objects prefer a label field', () {
      final a = ProjectAnalytics.fromJson({
        'project_health': [
          {
            'indicators': [
              {'label': 'Over budget', 'severity': 'high'},
            ],
          },
        ],
      });
      expect(a.health!.indicators, ['Over budget']);
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

    test('hasMoneySeries ignores expenses — they are not a plotted series', () {
      // The chart plots cumulative INVOICED and PAID. Counting expenses here
      // flips a project with spend but nothing invoiced into the money view,
      // where both series are flat zero and the hours data it does have is
      // hidden — exactly the case this flag exists to avoid.
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
      expect(b.hasMoneySeries, isFalse);
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
}
