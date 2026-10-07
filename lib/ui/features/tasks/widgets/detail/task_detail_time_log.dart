import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';
import 'package:admin/utils/formatting.dart';

/// The Time Log tab on the task screen: every entry, newest first.
///
/// The one thing the old Overview tab held that is content rather than
/// reference — a task can carry fifty of these — so it kept a tab when the
/// rest of that tab moved up into the standing card and the profile.
///
/// Read-only. Entries are edited on the task's edit screen, where the server's
/// rules about overlapping and running entries are enforced as you type.
class TaskDetailTimeLog extends StatelessWidget {
  const TaskDetailTimeLog({super.key, required this.task, this.formatter});

  final Task task;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final entries = task.timeLog.reversed.toList(growable: false);
    // One non-billable entry gives every row the marker's slot, so the
    // durations stay in one column instead of that row's stepping left.
    final markNonBillable = entries.any((e) => !e.billable);
    return Padding(
      padding: EdgeInsets.only(top: InSpacing.md(context)),
      child: DashboardCardShell(
        child: entries.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
                child: Text(
                  context.tr('no_entries'),
                  style: TextStyle(color: tokens.ink2),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < entries.length; i++) ...[
                    if (i > 0) const DetailRowDivider(),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: _TimeEntryRow(
                        entry: entries[i],
                        formatter: formatter,
                        reserveMarker: markNonBillable,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _TimeEntryRow extends StatelessWidget {
  const _TimeEntryRow({
    required this.entry,
    required this.reserveMarker,
    this.formatter,
  });

  final TimeEntry entry;
  final Formatter? formatter;

  /// Keep the non-billable marker's slot even on a billable row.
  final bool reserveMarker;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final start = entry.start;
    final stop = entry.stop;

    // A booking — a stopped entry that ends in the future — is a plan, not
    // logged time. This is where the difference is most visible, and the two
    // used to render identically: the same date line, the same duration, the
    // same weight, one above the other. It is also the row that
    // `Task.billableDuration` refuses to invoice, so leaving it
    // indistinguishable would make the totals look wrong rather than right.
    final booked =
        stop != null && !entry.isRunning && stop.isAfter(DateTime.now());
    final when = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            _when(start, stop),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: booked ? tokens.ink3 : tokens.ink2,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        if (booked) ...[
          const SizedBox(width: 6),
          Text(
            context.tr('booked'),
            style: TextStyle(
              color: tokens.ink3,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
    // Most entries carry no description, and the slot has no label: blank,
    // not a dash (`docs/row-actions-and-values.md`).
    final hasDescription = entry.description.trim().isNotEmpty;
    final description = Text(
      entry.description.trim(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: tokens.ink, fontSize: 13),
    );
    final duration = entry.isRunning && start != null
        ? RunningDurationLabel(
            start: start,
            precision: const Duration(seconds: 1),
          )
        : Text(
            formatDuration(
              stop == null || start == null
                  ? Duration.zero
                  : stop.difference(start),
              compactDays: true,
            ),
            style: TextStyle(
              color: booked ? tokens.ink3 : tokens.ink,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
    final tail = <Widget>[
      const SizedBox(width: 12),
      duration,
      if (reserveMarker) ...[
        const SizedBox(width: 8),
        SizedBox(
          width: 14,
          child: entry.billable
              ? null
              : Tooltip(
                  message: context.tr('non_billable'),
                  child: Icon(
                    Icons.money_off_outlined,
                    size: 14,
                    color: tokens.ink2,
                  ),
                ),
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 440) {
          // Pane / phone: when on its own line above the description, so a
          // fixed column for it does not squeeze the description to nothing —
          // and on one line with the duration when there is no description
          // to put under it.
          if (!hasDescription) {
            return Row(
              children: [
                Expanded(child: when),
                ...tail,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              when,
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(child: description),
                  ...tail,
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: 240, child: when),
            const SizedBox(width: 12),
            Expanded(child: description),
            ...tail,
          ],
        );
      },
    );
  }

  /// "14 May 2026 09:00 – 11:30" — the day the entry started, and the window.
  /// A running entry has no end yet; one that ends on another day keeps the
  /// start alone rather than implying it ended the day it began.
  String _when(DateTime? start, DateTime? stop) {
    if (start == null) return '—';
    final from = start.toLocal();
    final day = _date(from);
    final to = stop?.toLocal();
    if (to == null || !DateUtils.isSameDay(from, to)) {
      return '$day ${_time(from)}';
    }
    return '$day ${_time(from)} – ${_time(to)}';
  }

  // [d] is already local; honor military time without a further conversion.
  String _time(DateTime d) => formatTimeOfDay(
    d.hour,
    d.minute,
    military: formatter?.settings.enableMilitaryTime ?? true,
  );

  String _date(DateTime d) {
    final iso =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    // Blank until the formatter is here, never the raw ISO string.
    return formatter?.date(iso) ?? '';
  }
}
