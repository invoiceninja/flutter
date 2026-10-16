import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/charts/bar_list.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/analytics_kit.dart';
import 'package:admin/utils/formatting.dart';

/// What the project has earned and cost — React's Money (Profit) tab: the
/// margin, budget against actual, and how far the work has been billed and
/// paid. Mounted only for a user who may see the money, and only when there
/// is some.
///
/// Horizontal bars with the figure at the end of each, not columns: the
/// lines are a handful of named amounts compared on one scale, and the names
/// have to be read.
class MoneySection extends StatelessWidget {
  const MoneySection({
    super.key,
    required this.analytics,
    required this.formatter,
  });

  final ProjectAnalytics analytics;
  final Formatter? formatter;

  /// Whether there is any money to show at all.
  static bool hasMoney(ProjectAnalytics a) {
    final values = [
      a.profitability?.invoicedAmount,
      a.profitability?.expenseAmount,
      a.budgetVsActual?.budgetedAmount,
      a.budgetVsActual?.actualAmount,
      a.invoiceProgress?.workValue,
    ];
    return values.any((v) => v != null && v != Decimal.zero);
  }

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final tokens = context.inTheme;
    final profit = a.profitability;
    final split = a.budgetVsActual;
    final progress = a.invoiceProgress;
    final currency =
        profit?.currencyId ?? split?.currencyId ?? progress?.currencyId ?? '';
    final money = analyticsMoney(formatter, currency);

    List<BarListItem> bars(List<(String, Decimal)> lines) {
      final top = lines
          .map((l) => l.$2.toDouble())
          .fold<double>(0, (m, v) => v > m ? v : m);
      return [
        for (final (label, value) in lines)
          BarListItem(
            label: label,
            valueText: money(value),
            fraction: top <= 0 ? 0 : (value.toDouble() / top).clamp(0.0, 1.0),
          ),
      ];
    }

    final children = <Widget>[
      if (profit != null)
        KpiWrap(
          cells: [
            Kpi(context.tr('invoiced'), money(profit.invoicedAmount)),
            Kpi(context.tr('expenses'), money(profit.expenseAmount)),
            Kpi(
              context.tr('net_margin'),
              money(profit.netMargin),
              valueColor: profit.netMargin < Decimal.zero
                  ? tokens.overdue
                  : null,
            ),
            // Margin over nothing invoiced is not 0% — the server's ratio()
            // answers 0 for a zero denominator.
            Kpi(
              context.tr('margin'),
              profit.invoicedAmount == Decimal.zero
                  ? null
                  : analyticsPercent(formatter, profit.marginRatio),
              valueColor: profit.marginRatio < 0 ? tokens.overdue : null,
            ),
          ],
        ),
      if (split != null &&
          (split.budgetedAmount > Decimal.zero ||
              split.actualAmount > Decimal.zero)) ...[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnalyticsSubheading(context.tr('budget_vs_actual')),
            BarList(
              items: bars([
                if (split.budgetedAmount > Decimal.zero)
                  (context.tr('budgeted_amount'), split.budgetedAmount),
                (context.tr('actual_spend'), split.actualAmount),
                (context.tr('labor'), split.laborValue),
                (context.tr('expenses'), split.expenseAmount),
              ]),
            ),
          ],
        ),
      ],
      if (progress != null &&
          (progress.workValue > Decimal.zero ||
              progress.invoicedAmount > Decimal.zero))
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnalyticsSubheading(context.tr('billing_progress')),
            BarList(
              items: bars([
                (context.tr('work'), progress.workValue),
                (context.tr('invoiced'), progress.invoicedAmount),
                (context.tr('paid'), progress.paidAmount),
                (context.tr('outstanding'), progress.outstandingAmount),
                (context.tr('unbilled'), progress.unbilledAmount),
              ]),
            ),
          ],
        ),
    ];

    return AnalyticsSection(
      title: context.tr('money'),
      caption: a.includeDrafts ? context.tr('includes_drafts') : null,
      children: children,
    );
  }
}
