import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/analytics_figures.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/analytics_kit.dart';
import 'package:admin/utils/formatting.dart';

/// When the project will be done, at the pace it is going — React's
/// `ForecastSummary`, and the one section every user who can see the project
/// gets.
///
/// The server computes the pace and the date; this section decides whether
/// they mean anything ([forecastVerdict]): no forecast without an hours
/// budget, "over budget by" instead of "finishes today" once the budget is
/// spent, and no forecast before any time is logged.
///
/// For a user who may not see the money the server builds the forecast from
/// their own time logs only, so the section says so, and leaves out days
/// ahead or behind: a pace that counts one person's hours against the whole
/// project's remaining budget shows a slip that is not there.
class ForecastSection extends StatelessWidget {
  const ForecastSection({
    super.key,
    required this.analytics,
    required this.projectBudgetedHours,
    required this.projectLoggedHours,
    required this.projectDueDate,
    required this.formatter,
  });

  final ProjectAnalytics? analytics;

  /// The local project row's figures, for when the analytics answer has no
  /// hours block (a user who may not see the budget, or a failed fetch).
  final double projectBudgetedHours;
  final double projectLoggedHours;
  final Date? projectDueDate;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final tokens = context.inTheme;
    final financial = a?.canViewFinancials ?? true;
    final budgeted =
        a?.hours?.budgetedHours ??
        a?.budgetSummary?.budgetedHours ??
        projectBudgetedHours;
    final logged =
        a?.hours?.loggedHours ??
        a?.budgetSummary?.currentHours ??
        projectLoggedHours;
    final due = a?.forecast?.dueDate ?? projectDueDate;
    final verdict = forecastVerdict(
      forecast: a?.forecast,
      budgetedHours: budgeted,
      loggedHours: logged,
    );
    String hours(double h) => analyticsHours(formatter, h);
    String? date(Date? d) => d == null ? null : analyticsDate(formatter, d);

    final headline = <Widget>[
      ...switch (verdict) {
        ForecastNeedsBudget() => [
          AnalyticsNote(
            context.tr('forecast_needs_budget'),
            icon: Icons.info_outline,
          ),
        ],
        ForecastNeedsTime() => [
          AnalyticsNote(
            context.tr('forecast_needs_time'),
            icon: Icons.info_outline,
          ),
        ],
        ForecastOverBudget(:final overBy) => [
          KpiWrap(
            cells: [
              Kpi(
                context.tr('over_budget'),
                '+${hours(overBy)}',
                valueColor: tokens.overdue,
              ),
              Kpi(context.tr('logged_hours'), hours(logged)),
              Kpi(context.tr('budgeted_hours'), hours(budgeted)),
              Kpi(context.tr('due_date'), date(due)),
            ],
          ),
        ],
        ForecastPace(
          :final finish,
          :final varianceDays,
          :final velocity,
          :final remainingHours,
        ) =>
          [
            KpiWrap(
              cells: [
                Kpi(context.tr('forecast_finish'), date(finish)),
                Kpi(context.tr('due_date'), date(due)),
                if (financial && varianceDays != null)
                  Kpi(
                    context.tr(varianceDays < 0 ? 'days_behind' : 'days_ahead'),
                    formatter?.integer(varianceDays.abs()) ??
                        '${varianceDays.abs()}',
                    valueColor: varianceDays < 0 ? tokens.overdue : tokens.paid,
                  ),
                Kpi(context.tr('daily_velocity'), hours(velocity)),
                Kpi(context.tr('remaining_hours'), hours(remainingHours)),
              ],
            ),
          ],
      },
    ];

    final timeline = a?.timeline;
    final ideal = timeline?.idealProgressPercentage;
    final summary = a?.budgetSummary;
    final unbilled = a?.unbilled;
    final estimates = a?.estimates;
    final details = <Widget>[
      if (financial && (summary != null || unbilled != null || ideal != null))
        KpiWrap(
          cells: [
            // Logged against budget, or tasks done when there is no budget —
            // beside how much of the calendar has gone. Only with a due date:
            // without one "expected by now" has nothing to be.
            if (timeline != null && ideal != null) ...[
              Kpi(
                context.tr('completion'),
                analyticsPercent(
                  formatter,
                  timeline.completionPercentage / 100,
                ),
              ),
              Kpi(
                context.tr('expected_by_now'),
                analyticsPercent(formatter, ideal / 100),
              ),
            ],
            if (summary != null) ...[
              Kpi(
                context.tr('task_rate'),
                summary.taskRate == Decimal.zero
                    ? null
                    : analyticsMoney(formatter, summary.currencyId)(
                        summary.taskRate,
                      ),
              ),
              Kpi(
                context.tr('total_tasks'),
                formatter?.integer(summary.totalTasks) ??
                    '${summary.totalTasks}',
              ),
            ],
            if (unbilled != null)
              Kpi(
                context.tr('unbilled_work'),
                unbilled.hours <= 0
                    ? null
                    : '${analyticsMoney(formatter, unbilled.currencyId)(unbilled.amount)}'
                          ' · ${hours(unbilled.hours)}',
              ),
          ],
        ),
      if (estimates != null) ...[
        KpiWrap(
          cells: [
            Kpi(context.tr('estimated_hours'), hours(estimates.estimatedHours)),
            Kpi(
              context.tr('remaining_estimated_hours'),
              hours(estimates.remainingEstimatedHours),
            ),
            Kpi(
              context.tr('tasks_over_estimate'),
              formatter?.integer(estimates.tasksOverEstimate) ??
                  '${estimates.tasksOverEstimate}',
              valueColor: estimates.tasksOverEstimate > 0
                  ? tokens.overdue
                  : null,
            ),
          ],
        ),
        // The caveat on every figure above: these tasks aren't counted.
        if (estimates.unestimatedTasks > 0)
          AnalyticsNote(
            context.tr('unestimated_tasks_count', {
              'count': '${estimates.unestimatedTasks}',
            }),
          ),
      ],
    ];

    return AnalyticsSection(
      title: context.tr('forecast'),
      caption: financial ? null : context.tr('based_on_your_time'),
      children: [...headline, ...details],
    );
  }
}
