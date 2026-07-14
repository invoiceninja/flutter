import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/tasks/widgets/inline_timer_toggle_button.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';
import 'package:admin/ui/features/tasks/widgets/task_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// KPI strip at the top of the task detail body. Surfaces the four facts
/// most users scan first — total logged time, hourly rate, number of time
/// entries, and status. Mirrors `ExpenseDetailKpiStrip`.
///
/// Layout switches at 1100 px: horizontal row with vertical dividers vs
/// 2×2 grid on narrow widths.
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

  static const double _wideBreakpoint = 1100;

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
    final durationText = formatDuration(t.loggedDuration(), compactDays: true);

    final rateText = t.rate.toDouble() == 0
        ? '—'
        : (formatter?.money(t.rate) ?? t.rate.toStringAsFixed(2));

    final entryCount = t.timeLog.length;
    final entryCountText = entryCount == 0 ? '—' : '$entryCount';

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
              color: t.loggedDuration() == Duration.zero
                  ? tokens.ink3
                  : tokens.ink,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );

    final restCells = <Widget>[
      _KpiCell(
        label: context.tr('rate'),
        value: Text(
          rateText,
          style: theme.textTheme.titleLarge
              ?.copyWith(
                color: rateText == '—' ? tokens.ink3 : tokens.ink,
                fontWeight: FontWeight.w600,
              )
              .merge(moneyTextStyle()),
        ),
        tokens: tokens,
      ),
      _KpiCell(
        label: context.tr('entries'),
        value: Text(
          entryCountText,
          style: theme.textTheme.titleLarge?.copyWith(
            color: entryCountText == '—' ? tokens.ink3 : tokens.ink,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        tokens: tokens,
      ),
      _KpiCell(
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
          final durationCell = _KpiCell(
            label: context.tr('duration'),
            value: showToggle
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: durationValue),
                      const SizedBox(width: InSpacing.sm),
                      InlineTimerToggleButton(task: t, companyId: companyId),
                    ],
                  )
                : durationValue,
            tokens: tokens,
          );
          final cells = <Widget>[durationCell, ...restCells];
          if (constraints.maxWidth >= _wideBreakpoint) {
            return _HorizontalStrip(cells: cells, tokens: tokens);
          }
          return _Grid2x2(cells: cells);
        },
      ),
    );
  }
}

class _HorizontalStrip extends StatelessWidget {
  const _HorizontalStrip({required this.cells, required this.tokens});
  final List<Widget> cells;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: InSpacing.lg(context)),
            child: SizedBox(
              width: 1,
              height: 36,
              child: ColoredBox(color: tokens.border),
            ),
          ),
        );
      }
      children.add(Expanded(child: cells[i]));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

class _Grid2x2 extends StatelessWidget {
  const _Grid2x2({required this.cells});
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[0]),
            SizedBox(width: InSpacing.md(context)),
            Expanded(child: cells[1]),
          ],
        ),
        SizedBox(height: InSpacing.md(context)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[2]),
            SizedBox(width: InSpacing.md(context)),
            Expanded(child: cells[3]),
          ],
        ),
      ],
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.label,
    required this.value,
    required this.tokens,
  });

  final String label;
  final Widget value;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        value,
      ],
    );
  }
}
