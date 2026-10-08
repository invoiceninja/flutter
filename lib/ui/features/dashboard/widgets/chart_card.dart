import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_chart_series.dart';
import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/charts/chart_chrome.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/ui/features/dashboard/helpers/chart_series_math.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/ui/features/dashboard/helpers/totals_math.dart';
import 'package:admin/ui/features/dashboard/view_models/async_section.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart';

/// Floor of the plot's height when it fills its card rather than keeping an
/// aspect ratio — what the card asks for when the row's other card is shorter.
const double kChartMinPlotHeight = 220;

/// "Overview" — the period's invoices, payments, unpaid and expenses over
/// time, with a legend that switches each line on and off.
///
/// **It has no headline figure.** It used to lead with the period's paid
/// revenue, the same number as the Payments figure directly above it, under a
/// title ("Revenue — paid invoices only") that described that number and not
/// the four lines beneath it.
///
/// **Beside the activity feed it fills the row's height** ([fillHeight]), so
/// the two cards end on one line with their contents, not just their borders:
/// the plot had a fixed aspect ratio and the feed a fixed five rows, and which
/// of them was the shorter changed with the window. Stacked, it keeps its own
/// proportions.
///
/// **Its states are the figures' states** (`ValueSectionState`): a skeleton
/// until the series has answered, a retry when the fetch failed with nothing
/// cached, and "no data" only for a series that loaded and is empty. Nothing
/// ever put the chart section into a loading status, so the skeleton here was
/// unreachable and a chart that had not loaded read "No data for period".
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.vm,
    required this.formatter,
    this.fillHeight = false,
  });

  final DashboardViewModel vm;
  final Formatter formatter;

  /// Take the height the parent gives (it must be bounded) instead of sizing
  /// the plot by aspect ratio.
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final series = vm.chart.data;
    final currencyKey = selectedCurrencyKey(vm.filter.currencyId);
    final byCurrency = _selectCurrency(series, currencyKey);

    final pointsBySeries = <ChartSeriesId, List<DashboardChartPoint>>{
      ChartSeriesId.invoices: byCurrency?.invoices ?? const [],
      ChartSeriesId.payments: byCurrency?.payments ?? const [],
      ChartSeriesId.outstanding: byCurrency?.outstanding ?? const [],
      ChartSeriesId.expenses: byCurrency?.expenses ?? const [],
    };
    final axis = buildContinuousAxis(
      pointsBySeries: pointsBySeries,
      startDate: series?.startDate,
      endDate: series?.endDate,
      grouping: vm.chartGrouping,
      firstDayOfWeek: formatter.settings.firstDayOfWeek,
      refineShortRanges: true,
    );

    final Widget plot = switch (vm.chart.valueState) {
      ValueSectionState.loading => _loadingSkeleton(tokens),
      ValueSectionState.failed => _failed(context, tokens),
      ValueSectionState.stale || ValueSectionState.ready => _chart(
        context,
        tokens,
        axis,
        currencyKey,
        // The axis is zero-filled across the whole window, so "nothing
        // happened" has to be read off the points, not the lanes — or a quiet
        // period draws four flat lines along the floor instead of saying so.
        hasPoints: vm.visibleChartSeries.any(
          (id) => (pointsBySeries[id] ?? const []).isNotEmpty,
        ),
      ),
    };

    final body = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.md(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
        children: [
          _legend(context, tokens),
          const SizedBox(height: 8),
          if (fillHeight)
            // The plot is a POSITIONED child, and that is load-bearing. The
            // host lays this card out beside the activity feed with
            // `IntrinsicHeight`, and fl_chart's plot is a `LayoutBuilder`,
            // which cannot answer an intrinsic-size query — asked, it throws
            // and the whole row paints nothing. A `Stack` measures only its
            // non-positioned children, so the row sees the floor below and the
            // plot is never asked; it then fills whatever height the row
            // settles on. (The fixed aspect ratio this replaces hid the same
            // problem by never asking its child either.)
            Expanded(
              child: Stack(
                children: [
                  const SizedBox(
                    height: kChartMinPlotHeight,
                    width: double.infinity,
                  ),
                  Positioned.fill(child: plot),
                ],
              ),
            )
          else
            AspectRatio(aspectRatio: 2.4, child: plot),
        ],
      ),
    );

    // The card's own frame rather than `DashboardCardShell`: that shell lays
    // its child out at the child's own height, so nothing inside it can fill
    // a taller row. The decoration and header band are the shell's, so the
    // chart and the Activity card beside it read as one pair.
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
        boxShadow: tokens.shadow1,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _header(context, tokens, series, axis),
            Divider(height: 1, thickness: 1, color: tokens.border),
            if (fillHeight) Expanded(child: body) else body,
          ],
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    InTheme tokens,
    DashboardChartSeries? series,
    ChartAxis axis,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.md(context),
        InSpacing.lg(context),
        InSpacing.md(context),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.tr('overview'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: tokens.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _groupingControl(context, series, axis),
        ],
      ),
    );
  }

  /// Day / Week / Month, showing the grouping **in effect**.
  ///
  /// A grouping that cannot draw this range — a single month by month is one
  /// straight line; fifty years by day is tens of thousands of points — is
  /// disabled, and the plot uses the nearest that can. The control used to keep
  /// "Day" lit while the plot quietly drew weeks.
  Widget _groupingControl(
    BuildContext context,
    DashboardChartSeries? series,
    ChartAxis axis,
  ) {
    final start = series?.startDate;
    final end = series?.endDate;
    final known = start != null && end != null && !axis.isEmpty;
    final effective = known ? axis.grouping : vm.chartGrouping;
    bool fits(ChartGrouping g) =>
        !known ||
        g == effective ||
        chartGroupingFits(
          start,
          end,
          g,
          firstDayOfWeek: formatter.settings.firstDayOfWeek,
        );
    ButtonSegment<ChartGrouping> seg(ChartGrouping g, String key) =>
        ButtonSegment<ChartGrouping>(
          value: g,
          enabled: fits(g),
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
      selected: {effective},
      onSelectionChanged: (s) => vm.setChartGrouping(s.first),
    );
  }

  /// Reads its colors from [_colorFor] rather than repeating them: the curve
  /// and the tooltip swatch both derive from that one mapping, so a second
  /// copy here could make the legend dot disagree with the line it labels.
  Widget _legend(BuildContext context, InTheme tokens) => Wrap(
    spacing: 4,
    runSpacing: 0,
    children: [
      for (final id in ChartSeriesId.values)
        ChartLegendToggle(
          label: _labelFor(context, id),
          color: _colorFor(tokens, id),
          active: vm.visibleChartSeries.contains(id),
          onTap: () => vm.toggleChartSeries(id),
        ),
    ],
  );

  Widget _loadingSkeleton(InTheme tokens) => Container(
    decoration: BoxDecoration(
      // The border tone, not the alternate surface: against a card that one
      // is 1.04–1.22:1, a placeholder nobody could see.
      color: tokens.border.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(InRadii.r1),
    ),
  );

  Widget _disabledOverlay(InTheme tokens, String message) => Container(
    decoration: BoxDecoration(
      color: tokens.surfaceAlt,
      borderRadius: BorderRadius.circular(InRadii.r1),
    ),
    alignment: Alignment.center,
    child: Text(message, style: TextStyle(color: tokens.ink2, fontSize: 12)),
  );

  /// The fetch failed and nothing is cached: say so, and offer the retry.
  Widget _failed(BuildContext context, InTheme tokens) => Container(
    decoration: BoxDecoration(
      color: tokens.surfaceAlt,
      borderRadius: BorderRadius.circular(InRadii.r1),
    ),
    alignment: Alignment.center,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, size: 18, color: tokens.overdue),
        const SizedBox(width: InSpacing.sm),
        Text(
          context.tr('could_not_load_label'),
          style: TextStyle(color: tokens.ink2, fontSize: 13),
        ),
        const SizedBox(width: InSpacing.sm),
        TextButton(
          onPressed: () => vm.retry(DashboardKind.chart),
          child: Text(context.tr('retry')),
        ),
      ],
    ),
  );

  Widget _chart(
    BuildContext context,
    InTheme tokens,
    ChartAxis axis,
    String? currencyKey, {
    required bool hasPoints,
  }) {
    final visible = vm.visibleChartSeries;
    if (visible.isEmpty) {
      return _disabledOverlay(tokens, context.tr('no_series_selected'));
    }
    if (axis.isEmpty || !hasPoints) {
      return _disabledOverlay(tokens, context.tr('no_data_for_period'));
    }
    final bars = <LineChartBarData>[];
    final labels = <String>[];
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
      labels.add(_labelFor(context, id));
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
    return _RevenueLineChart(
      bars: bars,
      labels: labels,
      maxY: maxY,
      buckets: axis.buckets,
      tokens: tokens,
      formatter: formatter,
      currencyKey: currencyKey,
    );
  }

  /// Localized series label, paired with [_colorFor] by the legend.
  ///
  /// The third is "Unpaid", not "Outstanding": the series is what invoices
  /// *dated in this period* still owe, while the Outstanding figure above is
  /// everything owed today. One word for two different numbers on one screen
  /// is how they came to be read as contradicting each other.
  String _labelFor(BuildContext context, ChartSeriesId id) {
    switch (id) {
      case ChartSeriesId.invoices:
        return context.tr('invoices');
      case ChartSeriesId.payments:
        return context.tr('payments');
      case ChartSeriesId.outstanding:
        return context.tr('unpaid');
      case ChartSeriesId.expenses:
        return context.tr('expenses');
    }
  }

  /// Four tones that mean the same thing wherever the app uses them, and none
  /// that the user picks: the accent is their own choice, so a green or red
  /// one would have collided with Payments or read as "overdue". Invoices are
  /// the blue of the status pills' `partial` pair, payments the green of
  /// `paid`, and unpaid the amber of `sent` — not red: money that is merely
  /// outstanding is not an alarm.
  Color _colorFor(InTheme tokens, ChartSeriesId id) {
    switch (id) {
      case ChartSeriesId.invoices:
        return tokens.partial;
      case ChartSeriesId.payments:
        return tokens.paid;
      case ChartSeriesId.outstanding:
        return tokens.sent;
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
}

/// Label every [return]th bucket so at most [maxLabels] dates are drawn —
/// never more than six, so a year of daily buckets is not a wall of labels,
/// and never more than fit side by side (see `_RevenueLineChartState.build`).
int _labelStep(int bucketCount, {int maxLabels = 6}) =>
    chartLabelStep(bucketCount, maxLabels: maxLabels.clamp(2, 6));

/// The plot itself. A [StatefulWidget] for one reason: its fl_chart callbacks
/// are [State] methods, so they are the same objects from one build to the
/// next.
///
/// fl_chart includes every callback in `LineChartData`'s equality, and
/// `LineChart` is implicitly animated — it restarts its tween whenever the new
/// data is not equal to the old. Written as closures in `build`, the five
/// callbacks below were new objects each time, so the data never compared
/// equal and every rebuild of the card (a section landing, a session notify, a
/// refresh starting or ending) re-ran the 250 ms tween across all four series
/// with nothing different on screen. A tear-off of a method on one [State]
/// compares equal across builds, and reads its inputs live off `widget`.
///
/// See `docs/dashboard-panels.md` § A chart's callbacks are State tear-offs.
class _RevenueLineChart extends StatefulWidget {
  const _RevenueLineChart({
    required this.bars,
    required this.labels,
    required this.maxY,
    required this.buckets,
    required this.tokens,
    required this.formatter,
    required this.currencyKey,
  });

  final List<LineChartBarData> bars;

  /// The series name of each of [bars], by index.
  final List<String> labels;
  final double maxY;
  final List<Date> buckets;
  final InTheme tokens;
  final Formatter formatter;
  final String? currencyKey;

  @override
  State<_RevenueLineChart> createState() => _RevenueLineChartState();
}

class _RevenueLineChartState extends State<_RevenueLineChart> {
  /// How many date labels the axis has room for — set in [build] from the
  /// plot's width, read by [_dateTitle]. A field rather than a closure
  /// argument so the callback stays a tear-off (see the class comment).
  int _maxLabels = 6;

  /// Room one date label needs, in the company's own date format, at the
  /// user's text size: **one and a half times its width**. A label is centred
  /// on its tick, except the first and last, which are pushed inside the plot
  /// (`fitInside`) — so the first sits half a width closer to its neighbour
  /// than the ticks are. Budgeting a bare width plus a gap let those two
  /// touch at 140% text.
  double _labelWidth(BuildContext context) {
    final buckets = widget.buckets;
    if (buckets.isEmpty) return 80;
    final painter = TextPainter(
      text: TextSpan(
        text: widget.formatter.date(buckets.first.toIso()),
        style: const TextStyle(fontSize: 10),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width * 1.5;
  }

  FlLine _gridLine(double _) => chartGridLine(widget.tokens);

  Widget _valueTitle(double value, TitleMeta meta) {
    // fl_chart labels the axis's own maximum as well as its gridlines. The
    // maximum is the tallest point plus a tenth of headroom — "$14.7K", an
    // amount nothing on the chart is — and it sat a few pixels above the top
    // gridline's label, the two reading as one smudge.
    if (value == meta.max && value != meta.min) return const SizedBox.shrink();
    return Text(
      widget.formatter.money(
        Decimal.parse(value.toStringAsFixed(0)),
        currencyId: widget.currencyKey,
        compact: true,
      ),
      style: moneyTextStyle(fontSize: 10, color: widget.tokens.ink3),
    );
  }

  Widget _dateTitle(double value, TitleMeta meta) {
    final buckets = widget.buckets;
    final idx = value.round();
    if (idx < 0 ||
        idx >= buckets.length ||
        idx % _labelStep(buckets.length, maxLabels: _maxLabels) != 0) {
      return const SizedBox.shrink();
    }
    // `SideTitleWidget` + `fitInside`, not a bare `Text`: fl_chart centres each
    // label on its tick, so the first and last buckets sit half-outside the
    // plot. On a phone that clipped the opening date ("01/Aug/2026" rendered as
    // "1/Aug/2026") and pushed the closing one under the right-hand value axis.
    // `fromTitleMeta` clamps both back inside the axis box.
    return SideTitleWidget(
      meta: meta,
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
      child: Text(
        widget.formatter.date(buckets[idx].toIso()),
        style: TextStyle(fontSize: 10, color: widget.tokens.ink3),
      ),
    );
  }

  Color _tooltipColor(LineBarSpot _) => widget.tokens.ink;

  /// Must return exactly one entry per touched spot — fl_chart throws on a
  /// length mismatch. Map 1:1, never filter.
  ///
  /// Each row is a swatch, the series' name and its value; the first also
  /// leads with the bucket's date. The tooltip used to be a bare column of
  /// coloured dots and numbers — and fl_chart re-sorts the rows by value on
  /// every move, so a dot was all that said which number was which, and
  /// nothing said which day.
  List<LineTooltipItem> _tooltipItems(List<LineBarSpot> touchedSpots) {
    final tokens = widget.tokens;
    final buckets = widget.buckets;
    final labels = widget.labels;
    final plain = TextStyle(color: tokens.surface, fontSize: 11.5);
    return [
      for (var i = 0; i < touchedSpots.length; i++)
        () {
          final spot = touchedSpots[i];
          final at = spot.x.round();
          final name = spot.barIndex >= 0 && spot.barIndex < labels.length
              ? labels[spot.barIndex]
              : '';
          return LineTooltipItem(
            '',
            // The item's own colour is the series': the swatch inherits it.
            TextStyle(color: spot.bar.color ?? tokens.surface, fontSize: 11.5),
            textAlign: TextAlign.left,
            children: [
              if (i == 0 && at >= 0 && at < buckets.length)
                TextSpan(
                  text: '${widget.formatter.date(buckets[at].toIso())}\n',
                  style: plain.copyWith(fontWeight: FontWeight.w600),
                ),
              const TextSpan(text: '● '),
              if (name.isNotEmpty) TextSpan(text: '$name  ', style: plain),
              // On `surface`, not the series colour: those reach only ~3.3:1
              // against the `ink` fill, below the small-text contrast floor.
              TextSpan(
                text: widget.formatter.money(
                  Decimal.parse(spot.y.toStringAsFixed(2)),
                  currencyId: widget.currencyKey,
                ),
                style: moneyTextStyle(color: tokens.surface, fontSize: 11.5),
              ),
            ],
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Measured, because the room for dates is the plot's width and the dates
    // are the company's format: a phone drawing one month by week had six
    // "01/Oct/2026"-sized labels in 250 px, printed over one another. The
    // plot's host never asks this subtree for an intrinsic size (it sits under
    // an `AspectRatio` or a positioned `Stack` child), which is what makes a
    // `LayoutBuilder` legal here — fl_chart's own plot is one too.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Part of the width is the value axis on the right.
        final room = constraints.maxWidth - _valueAxisWidth(context);
        _maxLabels = room.isFinite ? (room / _labelWidth(context)).floor() : 6;
        return _plot(context);
      },
    );
  }

  /// The axes' reserved sizes follow the text size. They were a fixed 44 and
  /// 18 px, sized for 10 px labels at scale 1 — at 140% the dates lost their
  /// lower third to the card's edge.
  double _valueAxisWidth(BuildContext context) =>
      44 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
  double _dateAxisHeight(BuildContext context) =>
      18 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);

  Widget _plot(BuildContext context) {
    final tokens = widget.tokens;
    final maxY = widget.maxY;
    return LineChart(
      LineChartData(
        lineBarsData: widget.bars,
        clipData: const FlClipData.all(),
        minY: 0,
        maxY: maxY == 0 ? 1 : maxY * 1.1,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: _gridLine,
        ),
        // Not drawn (`show: false`), but compared: the grid colour now comes
        // from a callback fl_chart cannot see inside, so without the token
        // here a palette change that left every curve's colour alone would
        // compare equal and never repaint the grid.
        borderData: FlBorderData(
          show: false,
          border: Border.all(color: tokens.border),
        ),
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
              reservedSize: _valueAxisWidth(context),
              getTitlesWidget: _valueTitle,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _dateAxisHeight(context),
              interval: _labelStep(
                widget.buckets.length,
                maxLabels: _maxLabels,
              ).toDouble(),
              getTitlesWidget: _dateTitle,
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: _tooltipColor,
            // One row per visible series — see [_tooltipItems]. The default
            // 120 wraps a named amount, and the painter applies the user's
            // text scaler on top.
            maxContentWidth: 220,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: _tooltipItems,
          ),
        ),
      ),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
    );
  }
}
