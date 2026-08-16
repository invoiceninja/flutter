import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_chart_series.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/dashboard/helpers/chart_series_math.dart';
import 'package:admin/ui/features/dashboard/helpers/converted_hint.dart';
import 'package:admin/ui/features/dashboard/helpers/totals_math.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/dashboard/widgets/delta_chip.dart';

/// "Revenue" hero chart: line + gradient area with a togglable series legend.
/// Subscribes to the top-bar date range via `vm.filter.range`.
class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.vm, required this.formatter});

  final DashboardViewModel vm;
  final Formatter formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final series = vm.chart.data;
    final currencyKey = selectedCurrencyKey(vm.filter.currencyId);
    final byCurrency = _selectCurrency(series, currencyKey);
    final convertedHint = convertedToBaseCaption(
      context,
      selectedCurrencyId: vm.filter.currencyId,
      totals: vm.totals.data,
      formatter: formatter,
    );

    final pointsBySeries = <ChartSeriesId, List<DashboardChartPoint>>{
      ChartSeriesId.invoices: byCurrency?.invoices ?? const [],
      ChartSeriesId.payments: byCurrency?.payments ?? const [],
      ChartSeriesId.outstanding: byCurrency?.outstanding ?? const [],
      ChartSeriesId.expenses: byCurrency?.expenses ?? const [],
    };
    final visibleEmpty = vm.visibleChartSeries.every(
      (id) => (pointsBySeries[id] ?? const []).isEmpty,
    );

    // The hero is the *paid revenue* figure (same source as the "Paid" KPI),
    // not a sum of the legend series — expenses must not leak in.
    final current = selectCurrencyTotals(vm.totals.data, currencyKey);
    final previous = selectCurrencyTotals(vm.totalsPrevious.data, currencyKey);
    final heroValueText = formatter.money(
      current?.revenuePaidToDate ?? Decimal.zero,
      currencyId: currencyKey,
    );

    return DashboardCardShell(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.md(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, tokens),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                heroValueText,
                style: moneyTextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                  color: tokens.ink,
                ),
              ),
              const SizedBox(width: 12),
              DeltaChip(
                percent: percentDelta(
                  current?.revenuePaidToDate,
                  previous?.revenuePaidToDate,
                ),
                goodDirection: GoodDirection.up,
                suffix: context.tr('vs_prior'),
              ),
            ],
          ),
          if (convertedHint != null) ...[
            const SizedBox(height: 2),
            Text(
              convertedHint,
              style: TextStyle(fontSize: 11, color: tokens.ink3),
            ),
          ],
          const SizedBox(height: 8),
          _legend(context, tokens),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 2.4,
            child: vm.chart.isLoading && series == null
                ? _loadingSkeleton(tokens)
                : (visibleEmpty
                      ? _disabledOverlay(
                          tokens,
                          vm.visibleChartSeries.isEmpty
                              ? context.tr('no_series_selected')
                              : context.tr('no_data_for_period'),
                        )
                      : _chart(context, tokens, pointsBySeries, currencyKey)),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, InTheme tokens) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.tr('revenue'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.ink,
                ),
              ),
              Text(
                context.tr('paid_invoices_only_caption'),
                style: TextStyle(fontSize: 11.5, color: tokens.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _groupingControl(context),
      ],
    );
  }

  Widget _groupingControl(BuildContext context) {
    ButtonSegment<ChartGrouping> seg(ChartGrouping g, String key) =>
        ButtonSegment<ChartGrouping>(
          value: g,
          label: Text(context.tr(key), style: const TextStyle(fontSize: 12)),
        );
    return SegmentedButton<ChartGrouping>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      segments: [
        seg(ChartGrouping.day, 'day'),
        seg(ChartGrouping.week, 'week'),
        seg(ChartGrouping.month, 'month'),
      ],
      selected: {vm.chartGrouping},
      onSelectionChanged: (s) => vm.setChartGrouping(s.first),
    );
  }

  /// Reads its colors from [_colorFor] rather than repeating them: the curve
  /// and the tooltip swatch both derive from that one mapping, so a second
  /// copy here could make the legend dot disagree with the line it labels.
  Widget _legend(BuildContext context, InTheme tokens) => Wrap(
    spacing: 12,
    runSpacing: 4,
    children: [
      for (final id in ChartSeriesId.values)
        _legendChip(_labelFor(context, id), _colorFor(tokens, id), id),
    ],
  );

  Widget _legendChip(String label, Color color, ChartSeriesId id) {
    return Builder(
      builder: (context) {
        final tokens = context.inTheme;
        final active = vm.visibleChartSeries.contains(id);
        return GestureDetector(
          onTap: () => vm.toggleChartSeries(id),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? color : color.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: active ? tokens.ink2 : tokens.ink3,
                  decoration: active ? null : TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loadingSkeleton(InTheme tokens) => Container(
    decoration: BoxDecoration(
      color: tokens.surfaceAlt,
      borderRadius: BorderRadius.circular(InRadii.r1),
    ),
  );

  Widget _disabledOverlay(InTheme tokens, String message) => Container(
    decoration: BoxDecoration(
      color: tokens.surfaceAlt,
      borderRadius: BorderRadius.circular(InRadii.r1),
    ),
    alignment: Alignment.center,
    child: Text(message, style: TextStyle(color: tokens.ink3, fontSize: 12)),
  );

  Widget _chart(
    BuildContext context,
    InTheme tokens,
    Map<ChartSeriesId, List<DashboardChartPoint>> pointsBySeries,
    String? currencyKey,
  ) {
    final visible = vm.visibleChartSeries;
    final series = vm.chart.data;
    // Zero-fill the sparse server points across a contiguous date axis so the
    // line follows the period (with gaps as zeros) instead of collapsing to a
    // flat run of equal sparse points. Mirrors the React dashboard.
    final axis = buildContinuousAxis(
      pointsBySeries: pointsBySeries,
      startDate: series?.startDate,
      endDate: series?.endDate,
      grouping: vm.chartGrouping,
      firstDayOfWeek: formatter.settings.firstDayOfWeek,
    );
    if (axis.isEmpty) {
      return _disabledOverlay(tokens, context.tr('no_data_for_period'));
    }
    final bars = <LineChartBarData>[];
    double maxY = 0;
    for (final id in ChartSeriesId.values) {
      if (!visible.contains(id)) continue;
      final lane = axis.values[id] ?? const <double>[];
      if (lane.isEmpty) continue;
      final color = _colorFor(tokens, id);
      final spots = <FlSpot>[];
      for (var i = 0; i < lane.length; i++) {
        final v = lane[i];
        if (v > maxY) maxY = v;
        spots.add(FlSpot(i.toDouble(), v));
      }
      bars.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          preventCurveOverShooting: true,
          color: color,
          barWidth: 2,
          dotData: const FlDotData(show: false),
          belowBarData: id == _primaryVisible(visible)
              ? BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      color.withValues(alpha: 0.18),
                      color.withValues(alpha: 0),
                    ],
                  ),
                )
              : null,
        ),
      );
    }
    if (bars.isEmpty) {
      return _disabledOverlay(tokens, context.tr('no_series_selected'));
    }
    return LineChart(
      LineChartData(
        lineBarsData: bars,
        clipData: const FlClipData.all(),
        minY: 0,
        maxY: maxY == 0 ? 1 : maxY * 1.1,
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
              reservedSize: 44,
              getTitlesWidget: (value, meta) => Text(
                formatter.money(
                  Decimal.parse(value.toStringAsFixed(0)),
                  currencyId: currencyKey,
                  compact: true,
                ),
                style: moneyTextStyle(fontSize: 10, color: tokens.ink3),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              interval: _labelStep(axis.buckets.length).toDouble(),
              getTitlesWidget: (value, meta) {
                final idx = value.round();
                if (idx < 0 ||
                    idx >= axis.buckets.length ||
                    idx % _labelStep(axis.buckets.length) != 0) {
                  return const SizedBox.shrink();
                }
                return Text(
                  formatter.date(axis.buckets[idx].toIso()),
                  style: TextStyle(fontSize: 10, color: tokens.ink3),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => tokens.ink,
            // One row per visible series, and fl_chart re-sorts them by value
            // on every pointer move — so with four series on by default, row
            // position carries no identity and a bare column of numbers can't
            // be read. The swatch carries the series color; the value stays on
            // `surface` because the series colors only reach ~3.3:1 against
            // the `ink` fill, below the small-text contrast floor.
            // The default 120 wraps a long amount, and the painter applies
            // the user's text scaler on top.
            maxContentWidth: 160,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) {
              // Must return exactly one entry per touched spot — fl_chart
              // throws on a length mismatch. Map 1:1, never filter.
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '● ',
                  TextStyle(
                    color: spot.bar.color ?? tokens.surface,
                    fontSize: 11.5,
                  ),
                  textAlign: TextAlign.left,
                  children: [
                    TextSpan(
                      text: formatter.money(
                        Decimal.parse(spot.y.toStringAsFixed(2)),
                        currencyId: currencyKey,
                      ),
                      style: moneyTextStyle(
                        color: tokens.surface,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
    );
  }

  /// Localized series label, paired with [_colorFor] by the legend.
  String _labelFor(BuildContext context, ChartSeriesId id) {
    switch (id) {
      case ChartSeriesId.invoices:
        return context.tr('invoices');
      case ChartSeriesId.payments:
        return context.tr('payments');
      case ChartSeriesId.outstanding:
        return context.tr('outstanding');
      case ChartSeriesId.expenses:
        return context.tr('expenses');
    }
  }

  Color _colorFor(InTheme tokens, ChartSeriesId id) {
    switch (id) {
      case ChartSeriesId.invoices:
        return tokens.accent;
      case ChartSeriesId.payments:
        return tokens.paid;
      case ChartSeriesId.outstanding:
        return tokens.overdue;
      case ChartSeriesId.expenses:
        return tokens.ink3;
    }
  }

  ChartSeriesId _primaryVisible(Set<ChartSeriesId> visible) {
    for (final id in ChartSeriesId.values) {
      if (visible.contains(id)) return id;
    }
    return ChartSeriesId.invoices;
  }

  DashboardCurrencyChart? _selectCurrency(
    DashboardChartSeries? series,
    String? key,
  ) {
    if (series == null || series.isEmpty) return null;
    if (key != null) return series.byCurrency[key];
    // "All" → server-converted base-currency bucket (id 999); single-currency
    // companies may omit it, so fall back to the sole currency.
    return series.byCurrency[kDashboardCurrencyAll.toString()] ??
        series.byCurrency.values.first;
  }

  /// Show ~6 evenly spaced x-axis labels regardless of bucket count, so a
  /// year of daily buckets doesn't render an unreadable label wall.
  int _labelStep(int bucketCount) =>
      bucketCount <= 6 ? 1 : (bucketCount / 6).ceil();
}
