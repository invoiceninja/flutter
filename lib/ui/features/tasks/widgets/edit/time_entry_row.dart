import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/tasks/task_schedule.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';
import 'package:admin/utils/formatting.dart';

/// Summary row for a single `TimeEntry`. Tapping anywhere opens the full
/// `TimeEntryEditorSheet`. Running entries show the pulsing accent dot +
/// live-ticking duration; stopped entries show a static duration.
class TimeEntryRow extends StatelessWidget {
  const TimeEntryRow({
    super.key,
    required this.entry,
    this.dueDate,
    required this.onTap,
    required this.onRemove,
    this.enabled = true,
    this.formatter,
  });

  final TimeEntry entry;

  /// The task's own due date — the anchor that tells a booking from an
  /// ordinary forward-looking entry. See `task_schedule.dart`.
  final Date? dueDate;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  final bool enabled;

  /// Resolved company `Formatter`. Used so the date portion of the
  /// entry's timestamps honors `company.settings.date_format_id`
  /// (CLAUDE.md mandates dates render via `Formatter.date`). Falls back
  /// to ISO `YYYY-MM-DD` when null (e.g. unit-test contexts).
  final Formatter? formatter;

  /// Below this width the single-row layout (fixed 220px date column +
  /// duration + non-billable icon + delete button) overflows the smallest
  /// phones, so the row stacks the description under a
  /// [date · duration · actions] header instead.
  static const double _narrowWidth = 400;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final start = entry.start;
    final stop = entry.stop;
    // A booking is a plan, not logged time — and since `loggedDuration` now
    // excludes it, an unmarked row here would sit under a total that doesn't
    // add up. The detail screen's Time Log card marks it the same way.
    final booked = isTimeEntryBooking(
      entry,
      now: DateTime.now(),
      dueDate: dueDate,
    );
    final dateLabel = start == null
        ? '—'
        : '${_formatDate(start.toLocal())} '
              '${_hhmm(start.toLocal())}'
              '${stop == null ? '' : ' – ${_hhmm(stop.toLocal())}'}'
              '${booked ? ' · ${context.tr('booked')}' : ''}';

    Widget durationWidget() => entry.isRunning && entry.start != null
        ? RunningDurationLabel(start: entry.start!)
        : Text(
            formatDuration(
              start != null && stop != null
                  ? stop.difference(start)
                  : Duration.zero,
              compactDays: true,
            ),
            style: TextStyle(
              color: tokens.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );

    final billableIcon = entry.billable
        ? null
        : Tooltip(
            message: context.tr('non_billable'),
            child: Icon(Icons.money_off_outlined, size: 14, color: tokens.ink3),
          );

    final deleteButton = enabled
        ? IconButton(
            tooltip: context.tr('remove'),
            icon: const Icon(Icons.close, size: 16),
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          )
        : null;

    final description = Text(
      entry.description.isEmpty ? '—' : entry.description,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: tokens.ink, fontSize: 13),
    );

    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.md(context),
          vertical: InSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: entry.isRunning
              ? tokens.accentSoft.withValues(alpha: 0.3)
              : null,
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < _narrowWidth) {
              // Phone: [date · duration · actions] then description below.
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: tokens.ink2, fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 8),
                      durationWidget(),
                      if (billableIcon != null) ...[
                        const SizedBox(width: 6),
                        billableIcon,
                      ],
                      if (deleteButton != null) ...[
                        const SizedBox(width: 4),
                        deleteButton,
                      ],
                    ],
                  ),
                  if (entry.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    description,
                  ],
                ],
              );
            }
            return Row(
              children: [
                SizedBox(
                  width: 220,
                  child: Text(
                    dateLabel,
                    style: TextStyle(color: tokens.ink2, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: description),
                const SizedBox(width: 12),
                durationWidget(),
                if (billableIcon != null) ...[
                  const SizedBox(width: 6),
                  billableIcon,
                ],
                if (deleteButton != null) ...[
                  const SizedBox(width: 6),
                  deleteButton,
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  // [d] is already local wall-clock (callers pass `.toLocal()`), so format the
  // fields directly — honoring military time, no further tz conversion.
  String _hhmm(DateTime d) => formatTimeOfDay(
    d.hour,
    d.minute,
    military: formatter?.settings.enableMilitaryTime ?? true,
  );

  String _formatDate(DateTime d) {
    final iso =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final f = formatter;
    return f == null ? iso : f.date(iso);
  }
}
