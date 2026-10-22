import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/project/project_burnup.dart';
import 'package:admin/data/services/project_charts_api.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/charts/chart_chrome.dart';
import 'package:admin/ui/features/projects/view_models/project_analytics_view_model.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/analytics_kit.dart';
import 'package:admin/utils/formatting.dart';

/// One line the burn-up can draw.
enum BurnupLine {
  logged('logged_hours'),
  billable('billable_hours'),
  invoiced('invoiced'),
  paid('paid'),
  outstanding('outstanding'),
  taskValue('task_value'),
  expenses('expenses'),
  netInvoiced('net_invoiced'),
  netPaid('net_paid');

  const BurnupLine(this.labelKey);
  final String labelKey;

  bool get isMoney => this != logged && this != billable;
}

/// The burn-up: cumulative hours, or money, against the ideal pace from the
/// project's start to its due date — React's Burn up tab, one scale at a
/// time.
///
/// **Hours or money, never both on one chart.** React draws both against two
/// axes; one plot with two scales invites reading where two lines cross as
/// meaning something. The switch shows one measure at a time.
///
/// **The window is the burn-up's own.** Its range control sits here, not at
/// the top of the tab: the analytics endpoint reads no dates, so a range
/// over the whole tab only ever changed this chart. By default the request
/// sends no dates and the server spans the project's life; the bucket is
/// chosen from the span (`BurnupBucket.forSpan`) until the user picks one.
class ProjectBurnupSection extends StatefulWidget {
  const ProjectBurnupSection({
    super.key,
    required this.vm,
    required this.burnup,
    this.formatter,
  });

  final ProjectAnalyticsViewModel vm;
  final ProjectBurnup burnup;
  final Formatter? formatter;

  @override
  State<ProjectBurnupSection> createState() => _ProjectBurnupSectionState();
}

class _ProjectBurnupSectionState extends State<ProjectBurnupSection> {
  // fl_chart compares its callbacks as part of its data and restarts its
  // tween on any change, so every callback is a method of this State
  // (docs/dashboard-panels.md § A chart's callbacks are State tear-offs).

  bool? _money;
  final Set<BurnupLine> _shown = {
    BurnupLine.logged,
    BurnupLine.billable,
    BurnupLine.invoiced,
    BurnupLine.paid,
  };

  ProjectBurnup get _b => widget.burnup;

  bool get _showMoney => (_money ?? _b.hasBillingSeries) && _b.hasMoneySeries;

  List<BurnupLine> get _lines => [
    for (final l in BurnupLine.values)
      if (l.isMoney == _showMoney)
        if (l != BurnupLine.netInvoiced && l != BurnupLine.netPaid ||
            _b.series.any((p) => p.cumulativeNetInvoiced != null))
          l,
  ];

  double _valueOf(BurnupLine line, ProjectBurnupPoint p) => switch (line) {
    BurnupLine.logged => p.cumulativeLoggedHours,
    BurnupLine.billable => p.cumulativeBillableHours,
    BurnupLine.invoiced => p.cumulativeInvoicedAmount.toDouble(),
    BurnupLine.paid => p.cumulativePaidToDate.toDouble(),
    BurnupLine.outstanding => p.cumulativeOutstandingAmount.toDouble(),
    BurnupLine.taskValue => p.cumulativeTaskValue.toDouble(),
    BurnupLine.expenses => p.cumulativeExpenseAmount.toDouble(),
    BurnupLine.netInvoiced =>
      (p.cumulativeNetInvoiced ?? Decimal.zero).toDouble(),
    BurnupLine.netPaid => (p.cumulativeNetPaid ?? Decimal.zero).toDouble(),
  };

  /// Colour follows the line, never its position among those shown, so
  /// switching one off repaints nothing else.
  Color _colorOf(BurnupLine line, InTheme tokens) {
    final s = tokens.series;
    return switch (line) {
      BurnupLine.logged || BurnupLine.invoiced => s[0],
      BurnupLine.billable || BurnupLine.paid => s[1],
      BurnupLine.outstanding => s[2],
      BurnupLine.taskValue => s[3],
      BurnupLine.expenses => s[4],
      BurnupLine.netInvoiced => s[5],
      BurnupLine.netPaid => s[6],
    };
  }

  /// A [line]'s value at [p] as text — a money line from the point's own
  /// Decimal, never back through the chart's double.
  String _lineText(BurnupLine line, ProjectBurnupPoint p) {
    final f = widget.formatter;
    final money = switch (line) {
      BurnupLine.logged || BurnupLine.billable => null,
      BurnupLine.invoiced => p.cumulativeInvoicedAmount,
      BurnupLine.paid => p.cumulativePaidToDate,
      BurnupLine.outstanding => p.cumulativeOutstandingAmount,
      BurnupLine.taskValue => p.cumulativeTaskValue,
      BurnupLine.expenses => p.cumulativeExpenseAmount,
      BurnupLine.netInvoiced => p.cumulativeNetInvoiced ?? Decimal.zero,
      BurnupLine.netPaid => p.cumulativeNetPaid ?? Decimal.zero,
    };
    if (money == null) return analyticsHours(f, _valueOf(line, p));
    return analyticsMoney(f, _b.currencyId)(money);
  }

  /// An axis tick as text. A tick is a coordinate, not a point: the money
  /// one is rounded to whole units before it is formatted.
  String _tickText(double v) {
    final f = widget.formatter;
    if (!_showMoney) return analyticsHours(f, v);
    return analyticsMoney(f, _b.currencyId)(Decimal.fromInt(v.round()));
  }

  String _axisText(double v) {
    if (!_showMoney) return analyticsHours(widget.formatter, v);
    if (v.abs() < 1000) return _tickText(v);
    final k =
        widget.formatter?.decimal(v / 1000, maxDecimals: 1) ??
        (v / 1000).toStringAsFixed(1);
    return '${k}k';
  }

  String _dateText(int i) {
    final series = _b.series;
    if (i < 0 || i >= series.length) return '';
    final d = series[i].periodEnd;
    return d == null ? '' : analyticsDate(widget.formatter, d);
  }

  Widget _valueTitle(double value, TitleMeta meta) {
    if (value == meta.max && value != meta.min) return const SizedBox.shrink();
    return Text(
      _axisText(value),
      maxLines: 1,
      softWrap: false,
      style: chartAxisStyle(context.inTheme),
    );
  }

  int _maxLabels = 6;

  Widget _periodTitle(double value, TitleMeta meta) {
    final i = value.round();
    final n = _b.series.length;
    if (value != i.toDouble() ||
        i < 0 ||
        i >= n ||
        i % chartLabelStep(n, maxLabels: _maxLabels) != 0) {
      return const SizedBox.shrink();
    }
    return SideTitleWidget(
      meta: meta,
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
      child: Text(
        _dateText(i),
        maxLines: 1,
        style: chartAxisStyle(context.inTheme),
      ),
    );
  }

  FlLine _gridLine(double _) => chartGridLine(context.inTheme);

  Color _tooltipColor(Object _) => context.inTheme.ink;

  List<LineTooltipItem?> _tooltip(List<LineBarSpot> spots) {
    final tokens = context.inTheme;
    final plain = TextStyle(color: tokens.surface, fontSize: 11.5);
    final shown = _visible;
    return [
      for (var i = 0; i < spots.length; i++)
        i == 0
            ? LineTooltipItem(
                _dateText(spots[i].x.round()),
                plain.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.start,
                // fl_chart lays tooltip text out LTR unless told otherwise.
                textDirection: Directionality.of(context),
                children: [
                  for (final line in shown)
                    TextSpan(
                      text:
                          '\n${context.tr(line.labelKey)}  '
                          '${_lineText(line, _b.series[spots[i].x.round()])}',
                      style: plain,
                    ),
                ],
              )
            : null,
    ];
  }

  List<BurnupLine> get _visible => [
    for (final l in _lines)
      if (_shown.contains(l)) l,
  ];

  void _toggle(BurnupLine line) => setState(() {
    if (!_shown.remove(line)) _shown.add(line);
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final vm = widget.vm;
    final series = _b.series;
    final visible = _visible;
    final idealOf = _showMoney
        ? (ProjectBurnupPoint p) => p.idealAmount.toDouble()
        : (ProjectBurnupPoint p) => p.idealHours;
    final hasIdeal = series.any((p) => idealOf(p) > 0);
    final budgetLine = _showMoney
        ? _b.budgetedAmount.toDouble()
        : _b.budgetedHours;
    // The tasks' summed estimates (React #3380) — hours, so only there.
    final estimateLine = _showMoney ? 0.0 : _b.taskEstimatedHours;

    // Where the due date falls: the first bucket ending on or after it.
    final due = _b.dueDate;
    int? dueIndex;
    if (due != null) {
      for (var i = 0; i < series.length; i++) {
        final end = series[i].periodEnd;
        if (end != null && end.compareTo(due) >= 0) {
          dueIndex = i;
          break;
        }
      }
    }

    final values = [
      for (final line in visible)
        for (final p in series) _valueOf(line, p),
      if (hasIdeal)
        for (final p in series) idealOf(p),
      budgetLine,
      estimateLine,
    ];
    final maxY = values.fold<double>(0, math.max);
    final minY = values.fold<double>(0, math.min);

    final start = _b.startDate;
    final end = _b.endDate;
    final window = start != null && end != null
        ? '${analyticsDate(widget.formatter, start)} – '
              '${analyticsDate(widget.formatter, end)}'
        : null;

    final controls = Wrap(
      spacing: InSpacing.md(context),
      runSpacing: InSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<ProjectBurnupRange>(
          segments: [
            for (final r in ProjectBurnupRange.values)
              ButtonSegment(value: r, label: Text(context.tr(r.labelKey))),
          ],
          selected: {vm.range},
          showSelectedIcon: false,
          onSelectionChanged: (s) => vm.setRange(s.first),
        ),
        SegmentedButton<BurnupBucket>(
          segments: [
            for (final b in BurnupBucket.values)
              ButtonSegment(
                value: b,
                label: Text(context.tr('bucket_${b.wireName}')),
              ),
          ],
          selected: {vm.bucket},
          showSelectedIcon: false,
          onSelectionChanged: (s) => vm.setBucket(s.first),
        ),
        if (_b.hasMoneySeries)
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text(context.tr('hours'))),
              ButtonSegment(value: true, label: Text(context.tr('money'))),
            ],
            selected: {_showMoney},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _money = s.first),
          ),
      ],
    );

    final legend = Wrap(
      spacing: InSpacing.sm,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final line in _lines)
          ChartLegendToggle(
            label: context.tr(line.labelKey),
            color: _colorOf(line, tokens),
            active: _shown.contains(line),
            onTap: () => _toggle(line),
          ),
        if (hasIdeal) _Marker(label: context.tr('ideal_pace'), dashed: true),
        if (budgetLine > 0)
          _Marker(
            label: context.tr(
              _showMoney ? 'budgeted_amount' : 'budgeted_hours',
            ),
            dashed: true,
          ),
        if (estimateLine > 0)
          _Marker(
            label: _b.unestimatedTaskCount > 0
                ? '${context.tr('estimated_hours')} · '
                      '${context.tr('unestimated_tasks_count', {'count': '${_b.unestimatedTaskCount}'})}'
                : context.tr('estimated_hours'),
            dashed: true,
          ),
        if (dueIndex != null) _Marker(label: context.tr('due_date')),
      ],
    );

    final lastPoint = series.isEmpty ? null : series.last;
    final semantics = [
      context.tr('burnup'),
      if (window != null) window,
      if (lastPoint != null)
        for (final line in visible)
          '${context.tr(line.labelKey)} ${_lineText(line, lastPoint)}',
    ].join(', ');

    return AnalyticsSection(
      title: context.tr('burnup'),
      caption: window == null
          ? null
          : '$window · ${context.tr('bucket_${vm.bucket.wireName}')}',
      children: [
        controls,
        legend,
        Semantics(
          image: true,
          label: semantics,
          child: ExcludeSemantics(
            child: SizedBox(
              height: 260,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final plotWidth =
                      constraints.maxWidth -
                      chartValueAxisWidth(context, base: 52);
                  _maxLabels = chartLabelCapacity(
                    context,
                    plotWidth: plotWidth,
                    sampleLabel: _dateText(series.length ~/ 2),
                  );
                  return LineChart(
                    LineChartData(
                      minX: 0,
                      maxX: series.length <= 1
                          ? 1
                          : (series.length - 1).toDouble(),
                      minY: minY < 0 ? minY * 1.1 : 0,
                      maxY: maxY <= 0 ? 1 : maxY * 1.1,
                      clipData: const FlClipData.all(),
                      lineBarsData: [
                        if (hasIdeal)
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < series.length; i++)
                                FlSpot(i.toDouble(), idealOf(series[i])),
                            ],
                            barWidth: 1.5,
                            color: tokens.ink3,
                            dashArray: const [5, 4],
                            dotData: const FlDotData(show: false),
                          ),
                        for (final line in visible)
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < series.length; i++)
                                FlSpot(i.toDouble(), _valueOf(line, series[i])),
                            ],
                            barWidth: 2,
                            color: _colorOf(line, tokens),
                            dotData: const FlDotData(show: false),
                          ),
                      ],
                      extraLinesData: ExtraLinesData(
                        horizontalLines: [
                          if (budgetLine > 0)
                            HorizontalLine(
                              y: budgetLine,
                              color: tokens.ink2,
                              strokeWidth: 1,
                              dashArray: const [3, 3],
                            ),
                          if (estimateLine > 0)
                            HorizontalLine(
                              y: estimateLine,
                              color: tokens.ink3,
                              strokeWidth: 1.5,
                              dashArray: const [6, 3],
                            ),
                        ],
                        verticalLines: [
                          if (dueIndex != null)
                            VerticalLine(
                              x: dueIndex.toDouble(),
                              color: tokens.overdue,
                              strokeWidth: 1,
                              dashArray: const [4, 3],
                            ),
                        ],
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: _gridLine,
                      ),
                      borderData: FlBorderData(
                        show: false,
                        border: Border.all(color: tokens.border),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: chartValueAxisWidth(
                              context,
                              base: 52,
                            ),
                            getTitlesWidget: _valueTitle,
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: chartCategoryAxisHeight(context),
                            interval: 1,
                            getTitlesWidget: _periodTitle,
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: _tooltipColor,
                          maxContentWidth: 240,
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          getTooltipItems: _tooltip,
                        ),
                      ),
                    ),
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A legend entry for a line that is not a series — the ideal pace, a
/// budget, the due date — so it cannot be switched off.
class _Marker extends StatelessWidget {
  const _Marker({required this.label, this.dashed = false});

  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 2,
            color: dashed ? tokens.ink3 : tokens.overdue,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: tokens.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
