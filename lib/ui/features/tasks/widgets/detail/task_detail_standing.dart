import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_rate_context.dart';
import 'package:admin/ui/features/tasks/widgets/task_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// Where a task stands: the time worked on it, and what that time comes to.
///
/// It replaces the four-cell KPI strip that lived in the Overview tab — one
/// tab away from the header, behind whichever tab the user had last opened.
///
/// * **Duration** is time *worked* (`Task.workedTime`), never the time
///   booked: a booking is a plan, and totalling it here would claim hours
///   nobody has put in (`docs/task-scheduling.md`). It ticks while a timer
///   runs, in the accent, so the running state reads at a glance.
/// * **Amount** is the billable part of that time at the rate the task
///   actually bills at — the task → project → client → group → company
///   cascade (`TaskRateContext`), in the client's currency. The strip used to
///   print the task's *own* rate, which is zero on every task that inherits
///   one. Both always print: `0:00:00` and `$0.00` are answers.
/// * **Rate** and **Booked** are secondary, each drawn only when there is
///   one.
/// * The line under the figures is the task's status, whether it has been
///   invoiced, and — only where the company uses estimates — the estimate and
///   what is left of it. A labelled dash under "Estimated" would read as
///   "budgeted at nothing". Remaining goes negative, in red, once the
///   estimate is overrun: an anomaly is exactly the figure not to tidy away.
///
/// Duration opens the Time Log tab, which lists what it adds up.
class TaskDetailStanding extends StatefulWidget {
  const TaskDetailStanding({
    super.key,
    required this.task,
    required this.companyId,
    required this.formatter,
    required this.onOpenTab,
  });

  final Task task;
  final String companyId;

  /// Null while it loads — the money figures are blank until it arrives.
  final Formatter? formatter;
  final ValueChanged<String> onOpenTab;

  @override
  State<TaskDetailStanding> createState() => _TaskDetailStandingState();
}

class _TaskDetailStandingState extends State<TaskDetailStanding> {
  /// Once a second while a timer runs; not at all otherwise, so a stopped
  /// task costs no frames.
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(TaskDetailStanding oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new record is a new fact about *now* too — a timer that just stopped
    // must be totalled to the moment it stopped, not to the last tick.
    _now = DateTime.now();
    _sync();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _sync() {
    final running = widget.task.isRunning;
    if (running == (_ticker != null)) return;
    _ticker?.cancel();
    _ticker = running
        ? Timer.periodic(const Duration(seconds: 1), (_) {
            if (mounted) setState(() => _now = DateTime.now());
          })
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final tokens = context.inTheme;
    final worked = t.workedTime(_now);
    final booked = t.bookedTime(_now);
    String short(Duration d) =>
        formatDuration(d, compactDays: true, showSeconds: false);

    return TaskRateContextBuilder(
      companyId: widget.companyId,
      clientId: t.clientId,
      projectId: t.projectId,
      builder: (context, rates) => PartyCurrencyBuilder(
        clientId: t.clientId,
        builder: (context, currencyId) {
          String money(Decimal amount) =>
              widget.formatter?.money(amount, clientCurrencyId: currencyId) ??
              '';
          final rate = rates.rateFor(t);
          return StandingCard(
            primary: [
              StandingFigure(
                label: context.tr('duration'),
                value: formatDuration(worked, compactDays: true),
                valueColor: t.isRunning ? tokens.accent : null,
                onTap: () => widget.onOpenTab(DetailTabIds.timeLog),
                semanticsHint: context.tr('time_log'),
              ),
              StandingFigure(
                label: context.tr('amount'),
                value: money(rates.amountFor(t, _now)),
              ),
            ],
            secondary: [
              if (rate != Decimal.zero)
                StandingFigure(label: context.tr('rate'), value: money(rate)),
              if (booked != Duration.zero)
                StandingFigure(
                  label: context.tr('booked'),
                  value: short(booked),
                ),
            ],
            footnote:
                t.statusId.isEmpty && !t.isInvoiced && t.estimatedSeconds <= 0
                ? null
                : _StatusLine(task: t, worked: worked),
          );
        },
      ),
    );
  }
}

/// The task's status, an Invoiced pill once it has been billed, and the
/// estimate with what is left of it. **Owns its leading gap** — see
/// `StandingCard.footnote`.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.task, required this.worked});

  final Task task;
  final Duration worked;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: tokens.ink2);
    // The two pills on one line have to be one size: `TaskStatusPill` defaults
    // to the 13 px it wears in a list row, `StatusPill` to this.
    final pillText = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: tokens.ink,
      letterSpacing: 0.2,
    );
    String short(Duration d) =>
        formatDuration(d, compactDays: true, showSeconds: false);
    final estimate = Duration(seconds: task.estimatedSeconds);
    final hasEstimate = task.estimatedSeconds > 0;
    // Nothing worked yet: "remaining" would only restate the estimate.
    final showRemaining =
        hasEstimate && worked != Duration.zero && worked != estimate;
    final over = worked > estimate;
    final facts = <Widget>[
      if (task.statusId.isNotEmpty)
        TaskStatusPill(
          statusId: task.statusId,
          dotSize: 5,
          textStyle: pillText,
        ),
      if (task.isInvoiced)
        StatusPill(
          label: context.tr('invoiced'),
          fgColor: tokens.paid,
          bgColor: tokens.paidSoft,
        ),
      // Label–value pairs, not a sentence: the bundles have no plural forms
      // and no word order a translation could not get wrong.
      if (hasEstimate)
        Text(
          '${context.tr('estimated_duration')}: ${short(estimate)}',
          style: muted,
        ),
      if (showRemaining)
        Text(
          over
              ? '${context.tr('remaining')}: -${short(worked - estimate)}'
              : '${context.tr('remaining')}: ${short(estimate - worked)}',
          style: over
              ? muted?.copyWith(
                  color: tokens.overdue,
                  fontWeight: FontWeight.w600,
                )
              : muted,
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: kStandingFootnoteGap + InSpacing.xs),
      child: Wrap(
        spacing: InSpacing.sm,
        runSpacing: InSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (var i = 0; i < facts.length; i++) ...[
            // A dot between two facts, not after a pill: the pill's own shape
            // already separates it.
            if (i > 0 && facts[i - 1] is Text) Text('·', style: muted),
            facts[i],
          ],
        ],
      ),
    );
  }
}
