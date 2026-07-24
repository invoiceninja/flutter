import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/project/project_burnup.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// Server-computed burn-up: cumulative money (or hours) against the ideal
/// pace line, bucketed daily / weekly / monthly.
///
/// Deliberately narrow in scope — `ProjectProgressCard` on the detail body
/// already owns the *local* hours-vs-pace view and works offline. What this
/// adds is the money side, which needs invoice and payment aggregation the
/// client doesn't do. When the series carries no money at all (a time-only
/// project) it falls back to the hours view so the card is never a flat zero
/// line.
///
/// Chart idiom (clamped height, dashed grid, right-side value axis, hidden
/// left axis) mirrors `ProjectProgressCard._ChartPart` so the two read as one
/// design.
class ProjectBurnupChart extends StatelessWidget {
  const ProjectBurnupChart({super.key, required this.burnup, this.formatter});

  final ProjectBurnup burnup;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final showMoney = burnup.hasMoneySeries;
    return DashboardCardShell(
      title: context.tr('burnup'),
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: LayoutBuilder(
          builder: (context, constraints) => _Body(
            burnup: burnup,
            formatter: formatter,
            showMoney: showMoney,
            maxWidth: constraints.maxWidth,
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.burnup,
    required this.formatter,
    required this.showMoney,
    required this.maxWidth,
  });

  final ProjectBurnup burnup;
  final Formatter? formatter;
  final bool showMoney;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final scheme = Theme.of(context).colorScheme;
    final series = burnup.series;

    // X is the bucket index — buckets are already evenly spaced by the
    // server, so index avoids date-to-pixel math and keeps ticks aligned.
    double valueAt(ProjectBurnupPoint p) => showMoney
        ? p.cumulativeInvoicedAmount.toDouble()
        : p.cumulativeLoggedHours;
    double secondaryAt(ProjectBurnupPoint p) => showMoney
        ? p.cumulativePaidToDate.toDouble()
        : p.cumulativeBillableHours;
    double idealAt(ProjectBurnupPoint p) =>
        showMoney ? p.idealAmount.toDouble() : p.idealHours;

    final actual = <FlSpot>[
      for (var i = 0; i < series.length; i++)
        FlSpot(i.toDouble(), valueAt(series[i])),
    ];
    final secondary = <FlSpot>[
      for (var i = 0; i < series.length; i++)
        FlSpot(i.toDouble(), secondaryAt(series[i])),
    ];
    final ideal = <FlSpot>[
      for (var i = 0; i < series.length; i++)
        FlSpot(i.toDouble(), idealAt(series[i])),
    ];
    final hasIdeal = ideal.any((s) => s.y > 0);

    final budgetLine = showMoney
        ? burnup.budgetedAmount.toDouble()
        : burnup.budgetedHours;

    final maxY = [
      ...actual.map((s) => s.y),
      ...secondary.map((s) => s.y),
      ...ideal.map((s) => s.y),
      budgetLine,
    ].fold<double>(0, (a, b) => b > a ? b : a);

    final bars = <LineChartBarData>[
      if (hasIdeal)
        LineChartBarData(
          spots: ideal,
          isCurved: false,
          barWidth: 1.5,
          color: tokens.ink3,
          dashArray: const [5, 4],
          dotData: const FlDotData(show: false),
        ),
      LineChartBarData(
        spots: secondary,
        isCurved: false,
        barWidth: 2,
        color: scheme.tertiary,
        dotData: const FlDotData(show: false),
      ),
      LineChartBarData(
        spots: actual,
        isCurved: false,
        barWidth: 2.5,
        color: scheme.primary,
        dotData: const FlDotData(show: false),
      ),
    ];

    // Same clamp rationale as ProjectProgressCard: an unbounded AspectRatio
    // would push the rest of the page below the fold on a wide window.
    final height = (maxWidth / 2.4).clamp(200.0, 300.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Legend(
          showMoney: showMoney,
          hasIdeal: hasIdeal,
          primary: scheme.primary,
          secondaryColor: scheme.tertiary,
          idealColor: tokens.ink3,
        ),
        SizedBox(height: InSpacing.md(context)),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              lineBarsData: bars,
              minY: 0,
              maxY: maxY <= 0 ? 1 : maxY * 1.05,
              minX: 0,
              maxX: series.length <= 1 ? 1 : (series.length - 1).toDouble(),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  if (budgetLine > 0)
                    HorizontalLine(
                      y: budgetLine,
                      color: tokens.ink2.withValues(alpha: 0.5),
                      strokeWidth: 1,
                      dashArray: const [3, 3],
                    ),
                ],
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: tokens.border,
                  strokeWidth: 1,
                  dashArray: const [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (value, meta) => Text(
                      _axisLabel(value),
                      style: TextStyle(fontSize: 10, color: tokens.ink3),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 18,
                    interval: _tickInterval(series.length),
                    getTitlesWidget: (value, meta) {
                      final i = value.round();
                      if (i < 0 || i >= series.length) {
                        return const SizedBox.shrink();
                      }
                      final d = series[i].periodEnd;
                      if (d == null) return const SizedBox.shrink();
                      return Text(
                        '${d.month}/${d.day}',
                        style: TextStyle(fontSize: 10, color: tokens.ink3),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: const LineTouchData(enabled: true),
            ),
          ),
        ),
      ],
    );
  }

  String _axisLabel(double value) {
    if (!showMoney) return '${value.toStringAsFixed(0)} h';
    final f = formatter;
    if (f == null) return value.toStringAsFixed(0);
    // Compact so the reserved axis width holds — full precision lives in the
    // KPI cards below the chart.
    if (value.abs() >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return f.money(
      Decimal.parse(value.toStringAsFixed(2)),
      clientCurrencyId: burnup.currencyId.isEmpty ? null : burnup.currencyId,
    );
  }

  /// Keep bottom ticks readable — at most ~6 labels regardless of bucket count.
  double _tickInterval(int length) {
    if (length <= 6) return 1;
    return (length / 6).ceilToDouble();
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.showMoney,
    required this.hasIdeal,
    required this.primary,
    required this.secondaryColor,
    required this.idealColor,
  });

  final bool showMoney;
  final bool hasIdeal;
  final Color primary;
  final Color secondaryColor;
  final Color idealColor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: InSpacing.lg(context),
      runSpacing: 4,
      children: [
        _LegendItem(
          color: primary,
          label: showMoney
              ? context.tr('invoiced')
              : context.tr('logged_hours'),
        ),
        _LegendItem(
          color: secondaryColor,
          label: showMoney ? context.tr('paid') : context.tr('billable'),
        ),
        if (hasIdeal)
          _LegendItem(
            color: idealColor,
            label: context.tr('ideal_pace'),
            dashed: true,
          ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.dashed = false,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: dashed ? color.withValues(alpha: 0.6) : color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: InSpacing.sm),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink2),
        ),
      ],
    );
  }
}
