import 'package:flutter/material.dart';

import 'package:admin/ui/core/detail/kpi_strip_layout.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/detail/kpi_cell.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/tasks/widgets/inline_timer_toggle_button.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';
import 'package:admin/ui/features/tasks/widgets/task_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// KPI strip at the top of the task detail body. Surfaces the four facts
/// most users scan first — total logged time, hourly rate, number of time
/// entries, and status. Mirrors `ExpenseDetailKpiStrip`.
///
/// Layout switches at 1100 px: horizontal row with vertical dividers vs
/// 2×2 grid on narrow widths.
/// A KPI number with a small muted line under it — how the plan sits beside the
/// actual without buying a second row of cells. `KpiStripLayout` is two cells
/// per row below 1100 px, so a phone pays a whole extra row for a fifth cell;
/// stacking costs one 11-px line instead. `ProjectProgressCard._HeroStrip`
/// makes the same trade for the same reason.
class _StackedValue extends StatelessWidget {
  const _StackedValue({
    required String this.primaryText,
    required this.primaryColor,
    required this.secondary,
    required this.theme,
  }) : primaryWidget = null;

  const _StackedValue.widget({
    required Widget primary,
    required this.secondary,
    required this.theme,
  }) : primaryWidget = primary,
       primaryText = null,
       primaryColor = null;

  final String? primaryText;
  final Color? primaryColor;
  final Widget? primaryWidget;
  final ({String text, Color color})? secondary;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final sub = secondary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        primaryWidget ??
            Text(
              primaryText!,
              style: theme.textTheme.titleLarge?.copyWith(
                color: primaryColor,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        if (sub != null)
          Text(
            sub.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: sub.color,
            ),
          ),
      ],
    );
  }
}

class TaskDetailKpiStrip extends StatelessWidget {
  const TaskDetailKpiStrip({
    super.key,
    required this.task,
    required this.companyId,
    this.formatter,
  });

  final Task task;

  /// Active company id — threaded to the inline timer toggle rendered
  /// beside the Duration value on narrow panes.
  final String companyId;
  final Formatter? formatter;

  /// Below this body width the detail actions row buries Start/Stop in its
  /// ⋮ overflow, so the KPI shows its own 1-tap toggle. Set ~80px under the
  /// actions row's 600px `isWide` flip because this body is more inset than
  /// the AppBar title slot the actions row measures. The two gates read
  /// different widths (body-inner here vs title-slot there), so this cleanly
  /// separates genuine phones but is NOT an exact guarantee near ~600px
  /// panes — worst case there is a brief redundancy (both affordances show)
  /// or a 2-tap ⋮ fallback, never a broken state.
  static const double _kDetailToggleMaxWidth = 520;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final t = task;

    // `Task.loggedDuration()` is the canonical wall-clock total the app
    // shows (every entry, billable or not). If a running timer is active we
    // delegate to RunningDurationLabel so the cell ticks live.
    final runningEntry = (t.isRunning && t.timeLog.isNotEmpty)
        ? t.timeLog.last
        : null;
    // Tick live whenever an entry is running — billable or not — to match the
    // list tile / kanban card (which gate only on `isRunning`). Gating on
    // `billable` here would freeze the duration for a non-billable timer now
    // that the static value is the all-entries `loggedDuration`.
    final hasRunning = runningEntry?.start != null;
    // WORKED time, not `loggedDuration()`: a stopped entry that ends in the
    // future is a booking, and totalling it here would claim hours nobody has
    // put in — the display half of what `Task.billableDuration` now refuses to
    // invoice. Identical to `loggedDuration()` for a task with nothing booked,
    // which is almost all of them.
    final now = DateTime.now();
    final worked = t.workedTime(now);
    final booked = t.bookedTime(now);
    final durationText = formatDuration(worked, compactDays: true);

    final rateStyle = theme.textTheme.titleLarge
        ?.copyWith(
          color: t.rate.toDouble() == 0 ? tokens.ink3 : tokens.ink,
          fontWeight: FontWeight.w600,
        )
        .merge(moneyTextStyle());
    // The task rate is a per-client rate — resolve the client's currency so it
    // isn't rendered in the company currency (matches the list Rate column).
    final Widget rateValue = t.rate.toDouble() == 0
        ? Text('—', style: rateStyle)
        : PartyCurrencyBuilder(
            clientId: t.clientId,
            builder: (context, currencyId) => Text(
              formatter?.money(t.rate, clientCurrencyId: currencyId) ??
                  t.rate.toStringAsFixed(2),
              style: rateStyle,
            ),
          );

    // Duration value — accent while a timer runs so the running state reads
    // instantly; the cell still ticks live via RunningDurationLabel.
    final Widget durationValue = hasRunning
        ? RunningDurationLabel(
            // hasRunning guarantees runningEntry and its start are non-null.
            start: runningEntry!.start!,
            precision: const Duration(seconds: 1),
            style: theme.textTheme.titleLarge?.copyWith(
              color: tokens.accent,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          )
        : Text(
            durationText,
            style: theme.textTheme.titleLarge?.copyWith(
              color: worked == Duration.zero ? tokens.ink3 : tokens.ink,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );

    final restCells = <Widget>[
      // `Estimated` earns a cell only when the company uses it — the 2026-08-31
      // field is null on every task that predates it, and a labelled dash on
      // "Estimated" reads as "this job was budgeted at nothing" (the #113 rule:
      // the word is what gets read, not the value). It takes the slot the
      // entry COUNT used to hold, which the Time Log card one scroll down
      // states exactly, by listing them.
      if (t.estimatedSeconds > 0)
        KpiCell(
          label: context.tr('estimated_duration'),
          value: _StackedValue(
            primaryText: formatDuration(
              Duration(seconds: t.estimatedSeconds),
              compactDays: true,
              showSeconds: false,
            ),
            primaryColor: tokens.ink,
            secondary: _estimateDelta(
              context,
              tokens,
              worked,
              t.estimatedSeconds,
            ),
            theme: theme,
          ),
          tokens: tokens,
        ),
      KpiCell(label: context.tr('rate'), value: rateValue, tokens: tokens),
      KpiCell(
        label: context.tr('status'),
        value: t.statusId.isEmpty
            ? Text(
                '—',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: tokens.ink3,
                  fontWeight: FontWeight.w600,
                ),
              )
            : TaskStatusPill(
                statusId: t.statusId,
                textStyle: theme.textTheme.titleMedium?.copyWith(
                  color: tokens.ink,
                  fontWeight: FontWeight.w600,
                ),
                dotSize: 10,
              ),
        tokens: tokens,
      ),
    ];

    final Widget durationCellValue = booked == Duration.zero
        ? durationValue
        : _StackedValue.widget(
            primary: durationValue,
            secondary: (
              text:
                  '+${formatDuration(booked, compactDays: true, showSeconds: false)} '
                  '${context.tr('booked').toLowerCase()}',
              color: tokens.ink3,
            ),
            theme: theme,
          );

    return DashboardCardShell(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.lg(context),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Show the 1-tap toggle only when this pane is narrow enough that
          // the detail actions row buries Start/Stop in its ⋮ overflow (see
          // _kDetailToggleMaxWidth) — so exactly one affordance ever shows.
          final showToggle =
              constraints.maxWidth < _kDetailToggleMaxWidth &&
              TaskActions.canToggleTimer(t);
          final durationCell = KpiCell(
            label: context.tr('duration'),
            value: showToggle
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: durationCellValue),
                      const SizedBox(width: InSpacing.sm),
                      InlineTimerToggleButton(task: t, companyId: companyId),
                    ],
                  )
                : durationCellValue,
            tokens: tokens,
          );
          // Keeps its own LayoutBuilder — unlike the other strips, the first
          // cell's content depends on the width (the toggle above), so the
          // cells cannot be built before the branch. KpiStripLayout nests
          // inside it and re-reads the same constraints.
          return KpiStripLayout(cells: [durationCell, ...restCells]);
        },
      ),
    );
  }
}

/// Worked time measured against the estimate: what's left, or how far past.
///
/// Null when nothing has been worked yet — "3 h remaining" under an untouched
/// estimate just restates the estimate, and the strip is dense enough.
({String text, Color color})? _estimateDelta(
  BuildContext context,
  InTheme tokens,
  Duration worked,
  int estimatedSeconds,
) {
  if (worked == Duration.zero) return null;
  final estimate = Duration(seconds: estimatedSeconds);
  if (worked >= estimate) {
    final over = worked - estimate;
    if (over == Duration.zero) return null;
    return (
      text: '+${formatDuration(over, compactDays: true, showSeconds: false)}',
      color: tokens.overdue,
    );
  }
  return (
    text:
        '${formatDuration(estimate - worked, compactDays: true, showSeconds: false)} '
        '${context.tr('remaining').toLowerCase()}',
    color: tokens.ink3,
  );
}
