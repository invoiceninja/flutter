import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_progress_math.dart';
import 'package:admin/utils/formatting.dart';

export 'package:admin/ui/features/projects/widgets/detail/project_progress_math.dart';

/// The project's hours over time: cumulative billable hours as a step line
/// against an ideal linear pace from `createdAt` to `dueDate`. Each step-up
/// sits on an activity day; a faded dashed tail runs from the last entry to a
/// vertical "today" marker when nothing has been logged since.
///
/// **A card in the profile, and only where there is room to read a chart.**
/// It used to lead the screen with a four-cell KPI strip over it; those
/// figures, the budget bar that stood in for the chart on a narrow pane and
/// the verdict pill are now the standing card (`ProjectDetailStanding`), which
/// reads the same arithmetic (`project_progress_math.dart`), so the two
/// cannot disagree.
///
/// Computed **locally** from the tasks handed in — it works offline and for a
/// user who may not open the server-computed Analytics tab.
///
/// [chartHeight] is fixed by the host on purpose: on a wide window the card
/// sits in an `IntrinsicHeight` row, and a chart sized by a `LayoutBuilder`
/// has no intrinsic height to report.
class ProjectProgressCard extends StatefulWidget {
  const ProjectProgressCard({
    super.key,
    required this.project,
    required this.tasks,
    required this.chartHeight,
    this.formatter,
  });

  final Project project;

  /// The project's tasks as held locally — the host already watches them for
  /// the standing card, so this does not watch them a second time.
  final List<Task> tasks;
  final double chartHeight;
  final Formatter? formatter;

  /// Whether there is a line to draw: at least one billable entry that has
  /// actually been worked. A chart of nothing but its own axes is not a card
  /// worth a column.
  static bool hasContent(List<Task>? tasks) =>
      tasks != null && buildCumulativeSeries(tasks, DateTime.now()).isNotEmpty;

  /// The chart's height when the card runs the full width of a stacked
  /// column, clamped so a wide column does not make it 500 px tall.
  static double heightFor(double width) => (width / 2.4).clamp(200.0, 300.0);

  @override
  State<ProjectProgressCard> createState() => _ProjectProgressCardState();
}

class _ProjectProgressCardState extends State<ProjectProgressCard> {
  // Drift only emits on row changes, so without a tick the chart's "today"
  // anchor and a running timer's last step would freeze on a screen left
  // open. A minute while a billable timer runs, half an hour otherwise.
  Timer? _ticker;
  bool _fast = false;
  DateTime _now = DateTime.now();

  bool get _hasRunning => widget.tasks.any(
    (t) => t.timeLog.any((TimeEntry e) => e.isRunning && e.billable),
  );

  @override
  void initState() {
    super.initState();
    _arm(fast: _hasRunning);
  }

  @override
  void didUpdateWidget(ProjectProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _now = DateTime.now();
    final fast = _hasRunning;
    if (fast != _fast) _arm(fast: fast);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _arm({required bool fast}) {
    _fast = fast;
    _ticker?.cancel();
    _ticker = Timer.periodic(
      fast ? const Duration(minutes: 1) : const Duration(minutes: 30),
      (_) {
        if (mounted) setState(() => _now = DateTime.now());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    // Anchor the time axis in local time so the `createdAt`-relative geometry
    // lines up with the local-bucketed series (`buildCumulativeSeries` →
    // `.toLocal()`), the local `now`, and `dueDate.toDateTime()` (local
    // midnight). `project.createdAt` is stored UTC; mixing it with the local
    // anchors skewed the pace line and the day-axis ticks by the viewer's UTC
    // offset.
    final createdAt = project.createdAt.toLocal();
    final series = buildCumulativeSeries(widget.tasks, _now);
    final logged = series.isEmpty ? 0.0 : series.last.hours;
    return DashboardCardShell(
      title: context.tr('progress'),
      child: _ChartPart(
        series: series,
        logged: logged,
        budgeted: project.budgetedHours,
        projected: computeProjected(logged, createdAt, project.dueDate, _now),
        createdAt: createdAt,
        dueDate: project.dueDate,
        now: _now,
        height: widget.chartHeight,
        tokens: context.inTheme,
        formatter: widget.formatter,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time-series chart.
// ---------------------------------------------------------------------------

class _ChartPart extends StatelessWidget {
  const _ChartPart({
    required this.series,
    required this.logged,
    required this.budgeted,
    required this.projected,
    required this.createdAt,
    required this.dueDate,
    required this.now,
    required this.height,
    required this.tokens,
    this.formatter,
  });

  final List<({DateTime t, double hours})> series;
  final double logged;
  final double budgeted;
  final double? projected;
  final DateTime createdAt;
  final Date? dueDate;
  final DateTime now;
  final double height;
  final InTheme tokens;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final dueDt = dueDate?.toDateTime().add(const Duration(days: 1));
    final nowIndex = _dayIndex(now, createdAt);
    final dueIndex = dueDt == null ? null : _dayIndex(dueDt, createdAt);
    // Chart canvas spans at least to "now"; if past-due, the canvas still
    // extends to now so the actual line keeps going beyond the ideal.
    final maxX = math.max(nowIndex, math.max(0.0, dueIndex ?? 0));
    final maxLogged = series.isEmpty ? 0.0 : series.last.hours;
    final candidates = <double>[budgeted, maxLogged];
    if (projected != null) candidates.add(projected!);
    final rawMaxY = candidates.fold<double>(0, math.max);
    final maxY = rawMaxY == 0 ? 1.0 : rawMaxY * 1.1;

    // Back-dated entries (manual entries with a start before `createdAt`,
    // or data imports) produce negative day indices. Drop them from the
    // chart geometry so the step renderer keeps a monotonic x-sequence;
    // KPI math upstream still sees those hours.
    final actualSpots = <FlSpot>[
      const FlSpot(0, 0),
      for (final p in series)
        if (_dayIndex(p.t, createdAt) >= 0)
          FlSpot(_dayIndex(p.t, createdAt), p.hours),
    ];

    // Faded dashed segment from the last logged entry to "today". Communicates
    // "this is the current cumulative, nothing's been logged since" without
    // pretending the main step line kept growing.
    LineChartBarData? tailBar;
    if (series.isNotEmpty) {
      final last = series.last;
      final lastX = _dayIndex(last.t, createdAt);
      if (lastX >= 0 && lastX < nowIndex) {
        tailBar = LineChartBarData(
          spots: [FlSpot(lastX, last.hours), FlSpot(nowIndex, last.hours)],
          isCurved: false,
          color: tokens.accent.withValues(alpha: 0.35),
          barWidth: 1.5,
          dashArray: const [3, 3],
          dotData: const FlDotData(show: false),
        );
      }
    }

    final bars = <LineChartBarData>[
      if (dueIndex != null && budgeted > 0)
        LineChartBarData(
          spots: [
            const FlSpot(0, 0),
            FlSpot(dueIndex, budgeted),
            // Past-due: extend the budget ceiling as a horizontal line so the
            // visual cue is "you are over your time, here is where you should
            // have stopped logging" rather than the dashed line truncating.
            if (nowIndex > dueIndex) FlSpot(maxX, budgeted),
          ],
          isCurved: false,
          color: tokens.ink3,
          barWidth: 1.5,
          dashArray: const [4, 4],
          dotData: const FlDotData(show: false),
        ),
      if (tailBar != null) tailBar,
      LineChartBarData(
        spots: actualSpots,
        isStepLineChart: true,
        // Hold y across the gap, jump up at the next activity day. Cumulative
        // hours are step-shaped — a curve would invent values for idle days.
        lineChartStepData: const LineChartStepData(
          stepDirection: LineChartStepData.stepDirectionForward,
        ),
        color: tokens.accent,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          // Suppress the (0, 0) origin dot — it isn't a real data point.
          checkToShowDot: (spot, _) => spot.x > 0,
          getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
            radius: 2.5,
            color: tokens.accent,
            strokeWidth: 0,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tokens.accent.withValues(alpha: 0.18),
              tokens.accent.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    ];

    final hasLogged = series.isNotEmpty;
    final hasBudgetPace = dueIndex != null && budgeted > 0;
    final hasTail = tailBar != null;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChartLegend(
          hasLogged: hasLogged,
          hasBudgetPace: hasBudgetPace,
          hasTail: hasTail,
          tokens: tokens,
        ),
        SizedBox(height: InSpacing.md(context)),
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              lineBarsData: bars,
              minY: 0,
              maxY: maxY,
              minX: 0,
              maxX: maxX == 0 ? 1 : maxX,
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  VerticalLine(
                    x: nowIndex,
                    color: tokens.ink2.withValues(alpha: 0.5),
                    strokeWidth: 1,
                    dashArray: const [3, 3],
                    label: VerticalLineLabel(
                      show: true,
                      // topLeft keeps the label inside the plot area; topRight
                      // would push the text into the 36 px reserved by the
                      // right-axis tick labels.
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.only(right: 4, bottom: 2),
                      style: TextStyle(fontSize: 10, color: tokens.ink3),
                      labelResolver: (_) => context.tr('today'),
                    ),
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
                    reservedSize: 36,
                    // Not the two ends of the axis: fl_chart labels them on
                    // top of the interval ticks, so the top one sat against
                    // the budget's own tick and the bottom one ran into the
                    // last date under the plot.
                    getTitlesWidget: (value, meta) =>
                        value == meta.min || value == meta.max
                        ? const SizedBox.shrink()
                        : Text(
                            '${value.toStringAsFixed(0)} h',
                            style: TextStyle(fontSize: 10, color: tokens.ink3),
                          ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 18,
                    interval: _bottomTickInterval(maxX),
                    getTitlesWidget: (value, meta) {
                      final t = createdAt.add(
                        Duration(minutes: (value * 24 * 60).round()),
                      );
                      return Text(
                        '${t.month}/${t.day}',
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
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final t = createdAt.add(
                        Duration(minutes: (spot.x * 24 * 60).round()),
                      );
                      final iso = Date(t.year, t.month, t.day).toIso();
                      final formatted = formatter?.date(iso) ?? '';
                      final dateLabel = formatted.isEmpty
                          ? '${t.month}/${t.day}'
                          : formatted;
                      final pct = budgeted > 0
                          ? ((spot.y / budgeted) * 100).round()
                          : null;
                      final hours = '${fmtHours(spot.y)} h';
                      final label = pct == null
                          ? '$dateLabel · $hours'
                          : '$dateLabel · $hours · '
                                '${context.tr('pct_of_budget', {'pct': '$pct'})}';
                      return LineTooltipItem(
                        label,
                        TextStyle(color: tokens.surface, fontSize: 11.5),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 250),
          ),
        ),
      ],
    );
    // Opt the chart out of an ancestor SelectionArea (detail body) so its
    // drag-to-inspect tooltips aren't captured by text selection.
    return SelectionContainer.disabled(child: body);
  }
}

// ---------------------------------------------------------------------------
// Chart legend.
// ---------------------------------------------------------------------------

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({
    required this.hasLogged,
    required this.hasBudgetPace,
    required this.hasTail,
    required this.tokens,
  });

  final bool hasLogged;
  final bool hasBudgetPace;
  final bool hasTail;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 11.5, color: tokens.ink3);
    final chips = <Widget>[
      if (hasLogged)
        _chip(
          _LineSwatch(color: tokens.accent, strokeWidth: 2),
          context.tr('logged'),
          style,
        ),
      if (hasBudgetPace)
        _chip(
          _LineSwatch(
            color: tokens.ink3,
            strokeWidth: 1.5,
            dashArray: const [4, 4],
          ),
          context.tr('budget_pace'),
          style,
        ),
      if (hasTail)
        _chip(
          _LineSwatch(
            color: tokens.accent.withValues(alpha: 0.35),
            strokeWidth: 1.5,
            dashArray: const [3, 3],
          ),
          context.tr('no_activity_since'),
          style,
        ),
    ];
    return Wrap(spacing: 12, runSpacing: 4, children: chips);
  }

  static Widget _chip(Widget swatch, String label, TextStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch,
        const SizedBox(width: 6),
        Text(label, style: style),
      ],
    );
  }
}

class _LineSwatch extends StatelessWidget {
  const _LineSwatch({
    required this.color,
    required this.strokeWidth,
    this.dashArray,
  });

  final Color color;
  final double strokeWidth;
  final List<double>? dashArray;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(14, 2),
      painter: _LineSwatchPainter(
        color: color,
        strokeWidth: strokeWidth,
        dashArray: dashArray,
      ),
    );
  }
}

class _LineSwatchPainter extends CustomPainter {
  _LineSwatchPainter({
    required this.color,
    required this.strokeWidth,
    this.dashArray,
  });

  final Color color;
  final double strokeWidth;
  final List<double>? dashArray;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    final dash = dashArray;
    if (dash == null || dash.isEmpty) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      return;
    }
    var x = 0.0;
    var i = 0;
    var drawing = true;
    while (x < size.width) {
      final segment = dash[i % dash.length];
      final end = math.min(size.width, x + segment);
      if (drawing) {
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      }
      x = end;
      drawing = !drawing;
      i++;
    }
  }

  @override
  bool shouldRepaint(_LineSwatchPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      !listEquals(old.dashArray, dashArray);
}

double _bottomTickInterval(double maxX) {
  if (maxX <= 0) return 1;
  // Roughly 5-7 labels across the X axis regardless of project length.
  if (maxX <= 7) return 1;
  if (maxX <= 30) return 5;
  if (maxX <= 90) return 14;
  if (maxX <= 180) return 30;
  // A fixed step stops being "5-7 labels" once the axis runs to years: a due
  // date a decade out asked the chart to lay out a label a month, and one
  // typed as 2999 asked for twelve thousand — seconds of layout for an axis
  // nobody can read. Scale the step with the span instead.
  return (maxX / 6).ceilToDouble();
}

/// Day offset of [t] from [origin] in fractional days (positive = after).
double _dayIndex(DateTime t, DateTime origin) =>
    t.difference(origin).inMinutes / (60.0 * 24.0);
