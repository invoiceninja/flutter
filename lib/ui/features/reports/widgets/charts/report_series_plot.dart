import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/ui/core/charts/chart_chrome.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';

/// One series of a [ReportSeriesPlot]: a name, a colour, and a value for
/// each position on the category axis.
class ReportPlotSeries {
  const ReportPlotSeries({
    required this.name,
    required this.color,
    required this.values,
    this.context = false,
  });

  final String name;
  final Color color;
  final List<double> values;

  /// A series shown for comparison rather than as part of the measure — a
  /// previous period behind the current one. Drawn as a thin line whatever
  /// the style, and never stacked into the columns.
  final bool context;
}

/// One or more series over a shared axis of periods, as columns or lines.
///
/// A single series is a measure over time; several are groups over time,
/// stacked as columns (how the whole is made up, period by period) or drawn
/// as lines (how each one moved).
///
/// The reading aids are the dashboard chart's, on purpose: a value axis on
/// the right in compact figures, hairline gridlines, as many period labels
/// as fit and no more, and a tooltip that names every series at the period
/// under the pointer. A click drills; **hovering never does**, and on touch
/// a tap only opens the tooltip — a chart that changed the page under a
/// passing pointer was the bug this replaced.
class ReportSeriesPlot extends StatefulWidget {
  const ReportSeriesPlot({
    super.key,
    required this.labels,
    required this.series,
    required this.style,
    required this.axisText,
    required this.valueText,
    required this.semanticsLabel,
    this.axisLabels,
    this.onTapIndex,
    this.wholeNumbers = false,
    this.height = 240,
  });

  /// The period names in full, one per position — what the tooltip says.
  final List<String> labels;

  /// The same periods as the axis prints them: short ("Jan"), so that every
  /// one of a year's months has room. Null prints [labels].
  final List<String>? axisLabels;
  final List<ReportPlotSeries> series;
  final ReportTimeChartStyle style;

  /// A value as an axis label — compact (`$12.3K`).
  final String Function(double value) axisText;

  /// A value in full, for the tooltip.
  final String Function(double value) valueText;
  final String semanticsLabel;

  /// Drill into the period at this position. Null draws a chart that is
  /// only read.
  final ValueChanged<int>? onTapIndex;

  /// A count: the axis has no half rows.
  final bool wholeNumbers;
  final double height;

  @override
  State<ReportSeriesPlot> createState() => _ReportSeriesPlotState();
}

class _ReportSeriesPlotState extends State<ReportSeriesPlot> {
  // Everything fl_chart calls back is a method of this State, so it is the
  // same object from one build to the next: fl_chart compares its callbacks
  // as part of its data, and a closure made in `build` would never compare
  // equal — every rebuild of the page would replay the 250 ms tween with
  // nothing changed on screen. The methods read their inputs live off
  // `widget`. (docs/dashboard-panels.md § A chart's callbacks are State
  // tear-offs.)

  int _maxLabels = 6;
  int _lastShape = -1;

  InTheme get _tokens => context.inTheme;

  List<ReportPlotSeries> get _stacked => [
    for (final s in widget.series)
      if (!s.context) s,
  ];

  /// Columns need every bar to grow from one baseline; a series with a
  /// negative value (credits, refunds) cannot be stacked on it, so those
  /// are drawn as lines whatever was asked for.
  bool get _asColumns {
    if (widget.style != ReportTimeChartStyle.columns) return false;
    for (final s in _stacked) {
      for (final v in s.values) {
        if (v < 0) return false;
      }
    }
    return true;
  }

  (double, double) _range(bool columns) {
    var top = 0.0;
    var bottom = 0.0;
    final n = widget.labels.length;
    if (columns) {
      for (var i = 0; i < n; i++) {
        var sum = 0.0;
        for (final s in _stacked) {
          sum += i < s.values.length ? s.values[i] : 0;
        }
        top = math.max(top, sum);
      }
      for (final s in widget.series) {
        if (!s.context) continue;
        for (final v in s.values) {
          top = math.max(top, v);
        }
      }
    } else {
      for (final s in widget.series) {
        for (final v in s.values) {
          top = math.max(top, v);
          bottom = math.min(bottom, v);
        }
      }
    }
    if (top <= 0 && bottom >= 0) return (0, 1);
    final head = widget.wholeNumbers ? (top * 1.1).ceilToDouble() : top * 1.1;
    return (bottom < 0 ? bottom * 1.1 : 0, head <= 0 ? 1 : head);
  }

  FlLine _gridLine(double _) => chartGridLine(_tokens);

  Widget _valueTitle(double value, TitleMeta meta) {
    // The axis's own maximum is the tallest point plus headroom — a figure
    // nothing on the chart is — and it sat a few pixels above the top
    // gridline's label. A count shows no half rows.
    if (value == meta.max && value != meta.min) return const SizedBox.shrink();
    if (widget.wholeNumbers && value != value.roundToDouble()) {
      return const SizedBox.shrink();
    }
    return Text(
      widget.axisText(value),
      maxLines: 1,
      softWrap: false,
      style: moneyTextStyle(fontSize: 10, color: _tokens.ink3),
    );
  }

  List<String> get _axisLabels => widget.axisLabels ?? widget.labels;

  Widget _periodTitle(double value, TitleMeta meta) {
    final labels = _axisLabels;
    final i = value.round();
    if (value != i.toDouble() ||
        i < 0 ||
        i >= labels.length ||
        i % chartLabelStep(labels.length, maxLabels: _maxLabels) != 0) {
      return const SizedBox.shrink();
    }
    // `fitInside`: the first and last labels are centred on ticks at the
    // plot's very edges, and would otherwise hang half outside it.
    return SideTitleWidget(
      meta: meta,
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
      child: Text(labels[i], maxLines: 1, style: chartAxisStyle(_tokens)),
    );
  }

  Color _tooltipColor(Object _) => _tokens.ink;

  /// The tooltip's lines for the period at [index]: its name, then every
  /// series that has a value there — name second, figure last and in the
  /// tooltip's own ink, because here the reader has the series and wants the
  /// number.
  List<TextSpan> _tooltipLines(int index) {
    final tokens = _tokens;
    final plain = TextStyle(color: tokens.surface, fontSize: 11.5);
    final many = widget.series.length > 1;
    return [
      TextSpan(
        text: index >= 0 && index < widget.labels.length
            ? widget.labels[index]
            : '',
        style: plain.copyWith(fontWeight: FontWeight.w600),
      ),
      for (final s in widget.series)
        if (index < s.values.length && (!many || s.values[index] != 0)) ...[
          const TextSpan(text: '\n'),
          if (many) ...[
            TextSpan(
              text: '● ',
              style: TextStyle(color: s.color, fontSize: 11.5),
            ),
            TextSpan(text: '${s.name}  ', style: plain),
          ],
          TextSpan(
            text: widget.valueText(s.values[index]),
            style: moneyTextStyle(color: tokens.surface, fontSize: 11.5),
          ),
        ],
    ];
  }

  BarTooltipItem? _barTooltip(
    BarChartGroupData group,
    int groupIndex,
    BarChartRodData rod,
    int rodIndex,
  ) => BarTooltipItem(
    '',
    const TextStyle(fontSize: 11.5),
    textAlign: TextAlign.start,
    children: _tooltipLines(group.x),
  );

  /// One entry per touched spot — fl_chart throws on a length mismatch — with
  /// the whole readout on the first and nothing on the rest.
  List<LineTooltipItem?> _lineTooltip(List<LineBarSpot> spots) => [
    for (var i = 0; i < spots.length; i++)
      i == 0
          ? LineTooltipItem(
              '',
              const TextStyle(fontSize: 11.5),
              textAlign: TextAlign.start,
              children: _tooltipLines(spots[i].x.round()),
            )
          : null,
  ];

  bool _isDrill(FlTouchEvent event) =>
      // A completed click, with a pointer. `isInterestedForInteractions` —
      // the obvious test — is true for a hover too.
      event is FlTapUpEvent && !Env.isTouchPrimary;

  void _onBarTouch(FlTouchEvent event, BarTouchResponse? response) {
    final onTap = widget.onTapIndex;
    if (onTap == null || !_isDrill(event)) return;
    final index = response?.spot?.touchedBarGroupIndex;
    if (index != null && index >= 0 && index < widget.labels.length) {
      onTap(index);
    }
  }

  void _onLineTouch(FlTouchEvent event, LineTouchResponse? response) {
    final onTap = widget.onTapIndex;
    if (onTap == null || !_isDrill(event)) return;
    final spots = response?.lineBarSpots;
    if (spots == null || spots.isEmpty) return;
    final index = spots.first.x.round();
    if (index >= 0 && index < widget.labels.length) onTap(index);
  }

  FlTitlesData _titles(BuildContext context) => FlTitlesData(
    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: chartValueAxisWidth(context, base: 52),
        getTitlesWidget: _valueTitle,
      ),
    ),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: chartCategoryAxisHeight(context, base: 20),
        interval: 1,
        getTitlesWidget: _periodTitle,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final columns = _asColumns;
    // A change in how many series there are is a different picture, not a
    // movement of the same one: fl_chart tweens by index, and would
    // cross-fade one group's colour into another's.
    final shape = widget.series.length * 2 + (columns ? 1 : 0);
    final animate =
        _lastShape == shape && !MediaQuery.disableAnimationsOf(context);
    _lastShape = shape;
    final duration = animate
        ? const Duration(milliseconds: 250)
        : Duration.zero;

    return Semantics(
      label: widget.semanticsLabel,
      image: true,
      child: SizedBox(
        // The height includes the axis band: fl_chart draws the labels inside
        // the box it is given.
        height: widget.height,
        // Measured, because the room for period labels is the plot's width.
        // Legal here: nothing above this asks it for an intrinsic size.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final plotWidth =
                constraints.maxWidth - chartValueAxisWidth(context, base: 52);
            _maxLabels = chartLabelCapacity(
              context,
              plotWidth: plotWidth,
              sampleLabel: _typicalLabel,
            );
            return columns
                ? _bars(context, plotWidth, duration)
                : _lines(context, duration);
          },
        ),
      ),
    );
  }

  /// A label of the length most of them are — the upper-middle one, by
  /// length. Not the longest: the one label carrying the year ("Jan 2026"
  /// among eleven "Feb"s) would halve the number of months the axis thinks
  /// it has room for, and its extra width hangs into the empty slot beside
  /// the first tick, not into a neighbour.
  String get _typicalLabel {
    final labels = _axisLabels;
    if (labels.isEmpty) return '';
    final byLength = [...labels]..sort((a, b) => a.length.compareTo(b.length));
    return byLength[(byLength.length * 0.6).floor().clamp(
      0,
      byLength.length - 1,
    )];
  }

  Widget _bars(BuildContext context, double plotWidth, Duration duration) {
    final tokens = _tokens;
    final n = widget.labels.length;
    final stacked = _stacked;
    final comparisons = [
      for (final s in widget.series)
        if (s.context) s,
    ];
    final (minY, maxY) = _range(true);
    // Thin marks: half its slot and never wider than 32 px however few
    // there are; the rest is air.
    final share = comparisons.isEmpty ? 0.5 : 0.4;
    final rodWidth = n == 0
        ? 24.0
        : (plotWidth / n * share).clamp(3.0, 32.0).toDouble();
    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: _gridLine,
        ),
        // Not drawn, but compared: the grid's colour comes from a callback
        // fl_chart cannot see inside, so without the token here a palette
        // change would compare equal and never repaint the grid.
        borderData: FlBorderData(
          show: false,
          border: Border.all(color: tokens.border),
        ),
        titlesData: _titles(context),
        barTouchData: BarTouchData(
          enabled: true,
          touchCallback: _onBarTouch,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: _tooltipColor,
            maxContentWidth: 240,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: _barTooltip,
          ),
        ),
        barGroups: [
          for (var i = 0; i < n; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 2,
              barRods: [
                // A comparison stands just before what it is compared with,
                // thinner and in its neutral colour: the eye pairs them, and
                // the measure stays the mark that is read.
                for (final s in comparisons)
                  BarChartRodData(
                    toY: i < s.values.length ? s.values[i] : 0,
                    width: (rodWidth * 0.45).clamp(2.0, 12.0),
                    color: s.color,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(2),
                    ),
                  ),
                _rod(stacked, i, rodWidth, tokens),
              ],
            ),
        ],
      ),
      duration: duration,
    );
  }

  BarChartRodData _rod(
    List<ReportPlotSeries> stacked,
    int i,
    double width,
    InTheme tokens,
  ) {
    const radius = BorderRadius.vertical(top: Radius.circular(4));
    if (stacked.length == 1) {
      final value = i < stacked.single.values.length
          ? stacked.single.values[i]
          : 0.0;
      return BarChartRodData(
        toY: value,
        width: width,
        color: stacked.single.color,
        borderRadius: radius,
      );
    }
    var from = 0.0;
    final items = <BarChartRodStackItem>[];
    for (final s in stacked) {
      final value = i < s.values.length ? s.values[i] : 0.0;
      // A hairline of the surface between segments is what separates two
      // neighbours — not an outline drawn round each.
      items.add(
        BarChartRodStackItem(
          from,
          from + value,
          s.color,
          borderSide: BorderSide(color: tokens.surface, width: 1),
        ),
      );
      from += value;
    }
    return BarChartRodData(
      toY: from,
      width: width,
      color: Colors.transparent,
      borderRadius: radius,
      rodStackItems: items,
    );
  }

  Widget _lines(BuildContext context, Duration duration) {
    final tokens = _tokens;
    final n = widget.labels.length;
    final (minY, maxY) = _range(false);
    final single = widget.series.where((s) => !s.context).length == 1;
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: math.max(0, n - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: _gridLine,
        ),
        borderData: FlBorderData(
          show: false,
          border: Border.all(color: tokens.border),
        ),
        titlesData: _titles(context),
        lineTouchData: LineTouchData(
          enabled: true,
          touchCallback: _onLineTouch,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: _tooltipColor,
            maxContentWidth: 240,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: _lineTooltip,
          ),
        ),
        lineBarsData: [
          for (final s in widget.series)
            LineChartBarData(
              spots: [
                for (var i = 0; i < n; i++)
                  FlSpot(i.toDouble(), i < s.values.length ? s.values[i] : 0),
              ],
              color: s.color,
              barWidth: s.context ? 1.5 : 2,
              isCurved: false,
              // A point per period only while they are few enough to be
              // points rather than a dotted line.
              dotData: FlDotData(show: !s.context && n <= 24),
              belowBarData: BarAreaData(
                show: single && !s.context,
                color: s.color.withValues(alpha: 0.10),
              ),
            ),
        ],
      ),
      duration: duration,
    );
  }
}
