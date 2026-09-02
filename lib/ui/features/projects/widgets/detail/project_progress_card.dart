import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/ui/core/detail/kpi_strip_layout.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// Top-of-body progress card on the project detail screen.
///
/// Anchors the page with a hero KPI strip (Logged / Budgeted / Remaining /
/// Projected at current pace) plus a time-series step chart of cumulative
/// hours against an ideal linear pace from `createdAt` to `dueDate`. Each
/// step-up sits on an activity day; a faded dashed tail extends from the
/// last entry to a vertical "today" marker when there's been no recent
/// logging. On narrow widths (<600 px) the chart collapses to a stacked
/// progress bar with a "today should be here" tick. Hidden entirely when
/// the active user lacks `view_task` — the chart aggregates time logs.
class ProjectProgressCard extends StatefulWidget {
  const ProjectProgressCard({
    super.key,
    required this.project,
    required this.companyId,
    this.formatter,
  });

  final Project project;
  final String companyId;
  final Formatter? formatter;

  @override
  State<ProjectProgressCard> createState() => _ProjectProgressCardState();
}

class _ProjectProgressCardState extends State<ProjectProgressCard> {
  // The ticker always runs — 1 minute when a billable timer is active, 30
  // minutes otherwise. Drift only emits on row changes, so without the slow
  // ticker the chart's "today" anchor, elapsed-days math, and projection
  // would freeze on a long-idle screen with no live timer.
  Timer? _ticker;
  bool _tickerFast = false;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _arm(fast: false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _arm({required bool fast}) {
    _tickerFast = fast;
    _ticker?.cancel();
    final period = fast
        ? const Duration(minutes: 1)
        : const Duration(minutes: 30);
    _ticker = Timer.periodic(period, (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  void _syncTicker(List<Task> tasks) {
    if (!mounted) return;
    final hasRunning = tasks.any(
      (t) => t.timeLog.any((e) => e.isRunning && e.billable),
    );
    if (hasRunning == _tickerFast) return;
    _arm(fast: hasRunning);
  }

  @override
  Widget build(BuildContext context) {
    final services = context.watch<Services>();
    final company = services.auth.session.value?.currentCompany;
    if (company == null || !company.can('view_task')) {
      return const SizedBox.shrink();
    }
    return WatchBuilder<List<Task>>(
      cacheKey: (widget.companyId, widget.project.id),
      create: () => services.tasks.watchForProject(
        companyId: widget.companyId,
        projectId: widget.project.id,
      ),
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? const <Task>[];
        final hasRunning = tasks.any(
          (t) => t.timeLog.any((e) => e.isRunning && e.billable),
        );
        if (hasRunning != _tickerFast) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _syncTicker(tasks),
          );
        }
        return _CardBody(
          project: widget.project,
          tasks: tasks,
          formatter: widget.formatter,
          now: _now,
        );
      },
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.project,
    required this.tasks,
    required this.formatter,
    required this.now,
  });

  final Project project;
  final List<Task> tasks;
  final Formatter? formatter;
  final DateTime now;

  static const double _chartBreakpoint = 600;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Anchor the time axis in local time so the `createdAt`-relative geometry
    // lines up with the local-bucketed series (`buildCumulativeSeries` →
    // `.toLocal()`), the local `now`, and `dueDate.toDateTime()` (local
    // midnight). `project.createdAt` is stored UTC; mixing it with the local
    // anchors skewed the projection line / day-axis ticks by the viewer's UTC
    // offset. The pure helpers stay timezone-agnostic — we hand them a
    // consistent local set here.
    final createdAt = project.createdAt.toLocal();
    final series = buildCumulativeSeries(tasks, now);
    final logged = series.isEmpty ? 0.0 : series.last.hours;
    final budgeted = project.budgetedHours;
    final projected = computeProjected(logged, createdAt, project.dueDate, now);
    final status = deriveStatus(
      logged,
      budgeted,
      projected,
      dueDate: project.dueDate,
    );

    return DashboardCardShell(
      title: context.tr('progress'),
      trailing: _StatusPillForStatus(
        status: status,
        budgeted: budgeted,
        logged: logged,
        dueDate: project.dueDate,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HeroStrip(
            logged: logged,
            budgeted: budgeted,
            projected: projected,
            tokens: tokens,
          ),
          SizedBox(height: InSpacing.md(context)),
          if (tasks.isEmpty)
            _EmptyCta(projectId: project.id)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < _chartBreakpoint) {
                  return _ProgressBarPart(
                    logged: logged,
                    budgeted: budgeted,
                    createdAt: createdAt,
                    dueDate: project.dueDate,
                    now: now,
                    tokens: tokens,
                  );
                }
                return _ChartPart(
                  series: series,
                  logged: logged,
                  budgeted: budgeted,
                  projected: projected,
                  createdAt: createdAt,
                  dueDate: project.dueDate,
                  now: now,
                  maxWidth: constraints.maxWidth,
                  tokens: tokens,
                  formatter: formatter,
                );
              },
            ),
          // Hint only on narrow widths — wide screens already get the
          // StatusPill's "% / days left / No budget" fallback, and showing
          // both is redundant.
          if ((project.dueDate == null || budgeted == 0))
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= _chartBreakpoint) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: EdgeInsets.only(top: InSpacing.md(context)),
                  child: _MissingFieldsHint(project: project),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero KPI strip.
// ---------------------------------------------------------------------------

class _HeroStrip extends StatelessWidget {
  const _HeroStrip({
    required this.logged,
    required this.budgeted,
    required this.projected,
    required this.tokens,
  });

  final double logged;
  final double budgeted;
  final double? projected;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final hasBudget = budgeted > 0;
    final remaining = hasBudget ? math.max(0.0, budgeted - logged) : null;
    final remainingColor = (hasBudget && logged >= budgeted && logged > 0)
        ? tokens.overdue
        : null;
    final projectedColor = (projected != null && projected! > budgeted)
        ? tokens.overdue
        : null;
    final cells = <Widget>[
      _KpiCell(
        label: context.tr('logged'),
        value: '${fmtHours(logged)} h',
        tokens: tokens,
      ),
      _KpiCell(
        label: context.tr('budgeted'),
        value: hasBudget ? '${fmtHours(budgeted)} h' : '—',
        tokens: tokens,
      ),
      _KpiCell(
        label: context.tr('remaining'),
        value: remaining == null ? '—' : '${fmtHours(remaining)} h',
        valueColor: remainingColor,
        tokens: tokens,
      ),
      _KpiCell(
        label: context.tr('projected'),
        value: projected == null ? '—' : '${fmtHours(projected!)} h',
        // `valueColor` (red when projected > budgeted) carries the overrun
        // signal. No arrow — the conventional ↑ reads as "good/up-and-to-
        // the-right" in finance dashboards, the inverse of what overrun
        // means here.
        valueColor: projectedColor,
        tokens: tokens,
      ),
    ];
    return KpiStripLayout(cells: cells);
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.label,
    required this.value,
    required this.tokens,
    this.valueColor,
  });

  final String label;
  final String value;
  final InTheme tokens;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlaceholder = value == '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: tokens.ink3,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: isPlaceholder ? tokens.ink3 : (valueColor ?? tokens.ink),
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Status pill.
// ---------------------------------------------------------------------------

class _StatusPillForStatus extends StatelessWidget {
  const _StatusPillForStatus({
    required this.status,
    required this.budgeted,
    required this.logged,
    required this.dueDate,
  });

  final ProgressStatus status;
  final double budgeted;
  final double logged;
  final Date? dueDate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    switch (status) {
      case ProgressStatus.overBudget:
        return StatusPill(
          label: context.tr('over_budget'),
          fgColor: tokens.overdue,
          bgColor: tokens.overdueSoft,
        );
      case ProgressStatus.offPace:
        return StatusPill(
          label: context.tr('trending_over'),
          fgColor: tokens.sent,
          bgColor: tokens.sentSoft,
        );
      case ProgressStatus.onTrack:
        return StatusPill(
          label: context.tr('on_track'),
          fgColor: tokens.paid,
          bgColor: tokens.paidSoft,
        );
      case ProgressStatus.unknown:
        // Fallback "states" are facts, not statuses — render as plain text
        // so the visual hierarchy doesn't claim authority that isn't there.
        final due = dueDate;
        String? label;
        Color color = tokens.ink2;
        if (budgeted > 0) {
          final pct = ((logged / budgeted) * 100).round();
          label = '$pct%';
        } else if (due != null) {
          // Date-space (UTC) day diff — mixing a date-only due date with the
          // wall-clock `now` and `.inDays` flipped "past due" a day late
          // (afternoon truncation) plus a DST shift (L4).
          final days = due.differenceInDays(Date.today());
          if (days < 0) {
            label = context.tr('past_due');
            color = tokens.overdue;
          } else {
            label = context.tr('days_remaining', {'count': '$days'});
          }
        } else {
          label = context.tr('no_budget');
          color = tokens.ink3;
        }
        return Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Time-series chart (wide screens).
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
    required this.maxWidth,
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
  final double maxWidth;
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
    // Clamp instead of letting an AspectRatio scale unboundedly: on a wide
    // window the chart would otherwise be 500+ px tall and push the tabs
    // below the fold. Above ~768 px the height saturates at 320 px.
    final height = (maxWidth / 2.4).clamp(220.0, 320.0);
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
                    getTitlesWidget: (value, meta) => Text(
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
// Chart legend (only shown alongside the wide-mode chart).
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
  return 30;
}

// ---------------------------------------------------------------------------
// Mobile / narrow stacked progress bar fallback.
// ---------------------------------------------------------------------------

class _ProgressBarPart extends StatelessWidget {
  const _ProgressBarPart({
    required this.logged,
    required this.budgeted,
    required this.createdAt,
    required this.dueDate,
    required this.now,
    required this.tokens,
  });

  final double logged;
  final double budgeted;
  final DateTime createdAt;
  final Date? dueDate;
  final DateTime now;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    if (budgeted <= 0) {
      // No reference to compare against — just a single-line caption.
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          context.tr('hours_logged_count', {'hours': fmtHours(logged)}),
          style: TextStyle(fontSize: 12, color: tokens.ink2),
        ),
      );
    }
    // Bar segments are scaled against `total = max(budgeted, logged)` so the
    // blue (logged-up-to-budget) and red (overrun) pieces both fit inside the
    // track. When logged <= budgeted, total == budgeted and the bar reads as
    // "X% of budget consumed." When logged > budgeted, total == logged and
    // the bar reads as "of everything spent so far, this much was overrun."
    final total = math.max(budgeted, logged);
    final blueFrac = total == 0 ? 0.0 : math.min(budgeted, logged) / total;
    final redFrac = total == 0 ? 0.0 : math.max(0.0, logged - budgeted) / total;
    final dueDt = dueDate?.toDateTime().add(const Duration(days: 1));
    final elapsedFrac = dueDt == null
        ? null
        : _safeFraction(
            now.difference(createdAt).inSeconds.toDouble(),
            dueDt.difference(createdAt).inSeconds.toDouble(),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 18,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // Bars sit inside a clip so corner radii match the track.
                  Positioned.fill(
                    top: 2,
                    bottom: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(InRadii.r1),
                      child: Stack(
                        children: [
                          Container(color: tokens.surfaceAlt),
                          if (blueFrac > 0)
                            FractionallySizedBox(
                              widthFactor: blueFrac,
                              child: Container(color: tokens.accent),
                            ),
                          if (redFrac > 0)
                            Positioned(
                              left: w * blueFrac,
                              width: w * redFrac,
                              top: 0,
                              bottom: 0,
                              child: Container(color: tokens.overdue),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // "today" tick lives outside the clip so it can extend a
                  // touch above and below the track for legibility.
                  if (elapsedFrac != null &&
                      elapsedFrac >= 0 &&
                      elapsedFrac <= 1)
                    Positioned(
                      left: (w * elapsedFrac).clamp(0.0, w - 2),
                      top: 0,
                      bottom: 0,
                      child: Container(width: 2, color: tokens.ink2),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              context.tr('hours_logged_count', {'hours': fmtHours(logged)}),
              style: TextStyle(fontSize: 11.5, color: tokens.ink2),
            ),
            const Spacer(),
            if (elapsedFrac != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  context.tr('today_marker'),
                  style: TextStyle(fontSize: 11, color: tokens.ink3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

double _safeFraction(double numerator, double denominator) {
  if (denominator <= 0) return 0;
  final v = numerator / denominator;
  if (v.isNaN || v.isInfinite) return 0;
  return v;
}

// ---------------------------------------------------------------------------
// Empty-state CTA.
// ---------------------------------------------------------------------------

class _EmptyCta extends StatelessWidget {
  const _EmptyCta({required this.projectId});
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr('no_time_logged_cta'),
            style: TextStyle(fontSize: 13, color: tokens.ink3),
          ),
        ),
        DashboardCardFooterLink(
          label: context.tr('add_task'),
          onTap: () => context.go('/tasks/new?project=$projectId'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Caption shown when due_date or budget aren't set — link to project edit so
// the user can fix it without leaving the screen.
// ---------------------------------------------------------------------------

class _MissingFieldsHint extends StatelessWidget {
  const _MissingFieldsHint({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final noDueDate = project.dueDate == null;
    final noBudget = project.budgetedHours <= 0;
    final key = noDueDate && noBudget
        ? 'set_due_date_and_budget'
        : (noDueDate ? 'set_due_date_for_pace' : 'set_budget_for_pace');
    return Row(
      children: [
        Expanded(
          child: Text(
            context.tr(key),
            style: TextStyle(fontSize: 12, color: tokens.ink3),
          ),
        ),
        DashboardCardFooterLink(
          label: context.tr('edit'),
          onTap: () => context.go('/projects/${project.id}/edit'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pure helpers (testable).
// ---------------------------------------------------------------------------

enum ProgressStatus { onTrack, offPace, overBudget, unknown }

/// Flatten every billable time entry across [tasks] into a day-bucketed
/// cumulative-hours series sorted ascending in time. Each emitted record is
/// `(day, cumulativeHours)` where `day` is the local-time midnight of the
/// bucket. For long projects (>60 days of activity) buckets widen to weekly
/// so the chart stays readable.
///
/// Running entries contribute `(start..now)` to the bucket of `now`. Closed
/// entries contribute `(start..stop)` to the bucket of `stop`.
@visibleForTesting
List<({DateTime t, double hours})> buildCumulativeSeries(
  List<Task> tasks,
  DateTime now,
) {
  final byDay = <DateTime, double>{};
  for (final task in tasks) {
    for (final entry in task.timeLog) {
      if (!entry.billable || entry.start == null) continue;
      final duration = entry.durationUpTo(now);
      if (duration <= Duration.zero) continue;
      // `TimeEntry.start/stop` come from `epochSecondsToUtc` so they're UTC.
      // Bucket by the user's local calendar day to match every other time
      // call site in the app (e.g. `_TaskRow`, `time_entry_row.dart`).
      final end = (entry.stop ?? now).toLocal();
      final day = DateTime(end.year, end.month, end.day);
      byDay[day] = (byDay[day] ?? 0) + duration.inSeconds / 3600.0;
    }
  }
  if (byDay.isEmpty) return const <({DateTime t, double hours})>[];

  final days = byDay.keys.toList()..sort();
  final useWeekly = days.length > 60;
  if (!useWeekly) {
    final out = <({DateTime t, double hours})>[];
    var cumulative = 0.0;
    for (final day in days) {
      cumulative += byDay[day]!;
      out.add((t: day, hours: cumulative));
    }
    return out;
  }

  // Weekly re-bucket anchored on the first observed day.
  final anchor = days.first;
  final byWeek = <DateTime, double>{};
  for (final day in days) {
    final daysSince = day.difference(anchor).inDays;
    final weekStart = anchor.add(Duration(days: (daysSince ~/ 7) * 7));
    byWeek[weekStart] = (byWeek[weekStart] ?? 0) + byDay[day]!;
  }
  final weeks = byWeek.keys.toList()..sort();
  final out = <({DateTime t, double hours})>[];
  var cumulative = 0.0;
  for (final w in weeks) {
    cumulative += byWeek[w]!;
    out.add((t: w, hours: cumulative));
  }
  return out;
}

/// Linearly extrapolate total hours at project finish, given current burn
/// rate. Returns null when there isn't enough signal to extrapolate (no due
/// date, no hours logged, or less than a day elapsed).
@visibleForTesting
double? computeProjected(
  double logged,
  DateTime createdAt,
  Date? dueDate,
  DateTime now,
) {
  if (dueDate == null || logged <= 0) return null;
  final dueDt = dueDate.toDateTime().add(const Duration(days: 1));
  final totalDays = dueDt.difference(createdAt).inMinutes / (60.0 * 24.0);
  final elapsedDays = now.difference(createdAt).inMinutes / (60.0 * 24.0);
  if (elapsedDays < 1.0 || totalDays <= 0) return null;
  return logged * (totalDays / elapsedDays);
}

/// Three-state pace status from logged vs budgeted vs projected. Returns
/// `unknown` when there's no budget to compare against, or when there's no
/// due date to define "on schedule" against — the pill renders a contextual
/// fallback in either case.
@visibleForTesting
ProgressStatus deriveStatus(
  double logged,
  double budgeted,
  double? projected, {
  required Date? dueDate,
}) {
  if (budgeted <= 0) return ProgressStatus.unknown;
  if (logged >= budgeted) return ProgressStatus.overBudget;
  if (dueDate == null) return ProgressStatus.unknown;
  if (projected != null && projected > budgeted) return ProgressStatus.offPace;
  return ProgressStatus.onTrack;
}

/// Day offset of [t] from [origin] in fractional days (positive = after).
double _dayIndex(DateTime t, DateTime origin) =>
    t.difference(origin).inMinutes / (60.0 * 24.0);

/// Compact hour formatter. Whole numbers render as ints, fractions trim to
/// one decimal.
@visibleForTesting
String fmtHours(double h) {
  if (h.truncate().toDouble() == h) return h.toInt().toString();
  return h.toStringAsFixed(1);
}
