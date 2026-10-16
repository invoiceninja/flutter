import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/project/project_analytics.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/charts/bar_list.dart';
import 'package:admin/ui/core/charts/chart_chrome.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/analytics_figures.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/analytics_kit.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart'
    show ReportTimeChartStyle;
import 'package:admin/ui/features/reports/widgets/charts/report_series_plot.dart';
import 'package:admin/utils/formatting.dart';

/// What the project spent and on what — React's Expenses tab: the spend by
/// category, and labour and expenses summed to date. Mounted only for a user
/// who may see the money.
class ExpensesSection extends StatelessWidget {
  const ExpensesSection({
    super.key,
    required this.analytics,
    required this.formatter,
    required this.today,
  });

  final ProjectAnalytics analytics;
  final Formatter? formatter;
  final Date today;

  /// Whether there is any spend to show.
  static bool hasSpend(ProjectAnalytics a) =>
      a.expenseCategories.any((c) => c.amount > Decimal.zero) ||
      a.cumulativeSpend.any((p) => p.total > Decimal.zero);

  @override
  Widget build(BuildContext context) {
    final a = analytics;
    final currency =
        a.profitability?.currencyId ?? a.budgetVsActual?.currencyId ?? '';
    final money = analyticsMoney(formatter, currency);
    return AnalyticsSection(
      title: context.tr('expenses'),
      caption: a.includeDrafts ? context.tr('includes_drafts') : null,
      children: [
        if (a.expenseCategories.any((c) => c.amount > Decimal.zero))
          _Categories(categories: a.expenseCategories, money: money),
        if (a.cumulativeSpend.any((p) => p.total > Decimal.zero))
          _CumulativeSpend(
            points: a.cumulativeSpend,
            today: today,
            money: money,
            formatter: formatter,
          ),
      ],
    );
  }
}

/// Spend by category: a ring while there are few enough categories to tell
/// apart by colour, and always the list beside it — names, figures and
/// shares, which is the legend and the table at once.
class _Categories extends StatelessWidget {
  const _Categories({required this.categories, required this.money});

  final List<ProjectExpenseCategory> categories;
  final String Function(Decimal) money;

  /// Past this many slices the ring is a colour-matching exercise; the list
  /// alone says it better.
  static const _maxSlices = 6;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final rows = rankWithOther(categories, (c) => c.amount.toDouble());
    final total = rows.fold<double>(0, (s, r) => s + r.value);
    final top = rows.fold<double>(0, (m, r) => r.value > m ? r.value : m);
    final ring = rows.length <= _maxSlices;
    // Money as Decimal: a category's own amount, and "Other" summed from
    // the categories it stands for — never from the bar lengths.
    Decimal amountOf(RankedRow<ProjectExpenseCategory> r) => r.isOther
        ? r.folded.fold(Decimal.zero, (sum, c) => sum + c.amount)
        : r.item!.amount;
    Color colorOf(int i, RankedRow<ProjectExpenseCategory> r) => r.isOther
        ? tokens.seriesOther
        : tokens.series[i % tokens.series.length];
    String nameOf(RankedRow<ProjectExpenseCategory> r) {
      if (r.isOther) {
        return context.tr('other_count', {'count': '${r.foldedCount}'});
      }
      final c = r.item!;
      // The server names the no-category bucket in English.
      return c.categoryId == null || c.name.trim().isEmpty
          ? context.tr('uncategorized')
          : c.name;
    }

    final list = BarList(
      items: [
        for (var i = 0; i < rows.length; i++)
          BarListItem(
            label: nameOf(rows[i]),
            valueText: money(amountOf(rows[i])),
            shareText: total <= 0
                ? null
                : '${(rows[i].value / total * 100).round()}%',
            fraction: top <= 0 ? 0 : rows[i].value / top,
            color: ring ? colorOf(i, rows[i]) : null,
            muted: rows[i].isOther,
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnalyticsSubheading(context.tr('expense_categories')),
        if (ring) ...[
          Semantics(
            image: true,
            label: [
              for (final r in rows) '${nameOf(r)} ${money(amountOf(r))}',
            ].join(', '),
            child: ExcludeSemantics(
              child: SizedBox(
                height: 160,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 44,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(enabled: false),
                    sections: [
                      for (var i = 0; i < rows.length; i++)
                        PieChartSectionData(
                          value: rows[i].value,
                          color: colorOf(i, rows[i]),
                          radius: 28,
                          showTitle: false,
                        ),
                    ],
                  ),
                  duration: Duration.zero,
                ),
              ),
            ),
          ),
          SizedBox(height: InSpacing.md(context)),
        ],
        list,
      ],
    );
  }
}

/// Labour, expenses and their total, summed to date.
class _CumulativeSpend extends StatelessWidget {
  const _CumulativeSpend({
    required this.points,
    required this.today,
    required this.money,
    required this.formatter,
  });

  final List<ProjectSpendPoint> points;
  final Date today;
  final String Function(Decimal) money;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final (:buckets, weekly: _) = spendBuckets(points, today: today);
    if (buckets.isEmpty) return const SizedBox.shrink();
    final tokens = context.inTheme;
    // The plot's tooltip hands back a chart coordinate, not a point; they
    // come from amounts the server rounds to 2 places, so the 2-place parse
    // restores them exactly. Every other figure here is a point's Decimal.
    String fromCoordinate(double v) =>
        money(Decimal.parse(v.toStringAsFixed(2)));
    String compact(double v) {
      if (v.abs() < 1000) return fromCoordinate(v.roundToDouble());
      final k =
          formatter?.decimal(v / 1000, maxDecimals: 1) ??
          (v / 1000).toStringAsFixed(1);
      return '${k}k';
    }

    final series = [
      ReportPlotSeries(
        name: context.tr('labor'),
        color: tokens.series[0],
        values: [for (final b in buckets) b.labor.toDouble()],
      ),
      ReportPlotSeries(
        name: context.tr('expenses'),
        color: tokens.series[1],
        values: [for (final b in buckets) b.expenses.toDouble()],
      ),
      ReportPlotSeries(
        name: context.tr('actual_spend'),
        color: tokens.series[2],
        values: [for (final b in buckets) b.total.toDouble()],
      ),
    ];
    final labels = [for (final b in buckets) analyticsDate(formatter, b.start)];
    final last = buckets.last;
    final lastTotals = [last.labor, last.expenses, last.total];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnalyticsSubheading(context.tr('cumulative_spend')),
        Wrap(
          spacing: InSpacing.lg(context),
          runSpacing: 4,
          children: [
            for (final (i, s) in series.indexed)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChartSwatch(color: s.color),
                  const SizedBox(width: 6),
                  // Flexible: a Wrap hands a child the whole line, and a
                  // name plus a figure at 1.4x text is wider than a phone.
                  Flexible(
                    child: Text(
                      '${s.name} · ${money(lastTotals[i])}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: tokens.ink2),
                    ),
                  ),
                ],
              ),
          ],
        ),
        SizedBox(height: InSpacing.md(context)),
        ReportSeriesPlot(
          labels: labels,
          series: series,
          style: ReportTimeChartStyle.line,
          axisText: compact,
          valueText: fromCoordinate,
          semanticsLabel:
              '${context.tr('cumulative_spend')}: '
              '${context.tr('labor')} ${money(last.labor)}, '
              '${context.tr('expenses')} ${money(last.expenses)}, '
              '${context.tr('actual_spend')} ${money(last.total)}',
          height: 220,
        ),
      ],
    );
  }
}
