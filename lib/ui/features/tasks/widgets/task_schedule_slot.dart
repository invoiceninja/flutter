import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/domain/tasks/task_schedule.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/formatter_scope.dart';
import 'package:admin/utils/formatting.dart';

/// What a task row shows in place of a duration when the task is booked but
/// not yet started (invoiceninja/flutter#149).
///
/// Returns null when there is nothing booked — the caller then renders the
/// duration exactly as before, so a task nobody has scheduled is untouched.
///
/// This **replaces** the numeric slot rather than adding a chip beside it. An
/// unstarted booking's `workedDuration` is `0:00`, a number that tells the
/// user nothing, while the narrow row's identity column is already the most
/// truncated thing on it (`task_list_tile.dart` records "422: Unproc…"). A
/// `09:00 – 11:00` window costs 62–93 px depending on the company's clock
/// format; the start alone costs ~28, three pixels *less* than the `0:00` it
/// displaces. The full window belongs on Daily and the detail screen, which
/// have the room.
///
/// The string carries the state, never the colour alone — `warning` and
/// `overdue` are both user-overridable presets, and this row is read at arm's
/// length in daylight.
({String text, Color color})? taskScheduleSlot(
  BuildContext context,
  Task task, {
  Formatter? formatter,
  DateTime? now,
}) {
  final asOf = now ?? DateTime.now();
  final tokens = context.inTheme;
  // The inherited formatter is the fallback, so a surface that doesn't thread
  // one still renders the company's clock format rather than defaulting to
  // 12-hour — otherwise the same booking reads `14:00` in the list and
  // `2:00 PM` on the kanban board, one tab apart.
  final clock = formatter ?? FormatterScope.maybeOf(context);
  final state = task.scheduleStateAt(asOf);
  switch (state) {
    case TaskScheduleState.none:
      return null;
    case TaskScheduleState.dueNow:
      // The one state that needs a word rather than a time: "11:00" on a job
      // whose window opened an hour ago reads as a plan, not as "you are
      // expected on site".
      return (text: context.tr('now'), color: tokens.warning);
    case TaskScheduleState.upcoming:
      final start = _bookedStart(task, asOf);
      return (
        text: formatTimeOfDay(
          start.hour,
          start.minute,
          military: clock?.settings.enableMilitaryTime ?? false,
        ),
        color: tokens.ink2,
      );
    case TaskScheduleState.late:
      final by = task.lateByAt(asOf)!;
      // Signed, because an unsigned `2:10` in a column of durations reads as
      // time logged — the opposite of what it means.
      return (
        text: '+${formatDuration(by, compactDays: true, showSeconds: false)}',
        color: tokens.overdue,
      );
  }
}

/// Local wall-clock start of the booking the row is reporting on.
DateTime _bookedStart(Task task, DateTime now) => sortTimeLog(
  task.timeLog,
).firstWhere((e) => !e.isRunning && e.stop!.isAfter(now)).start!.toLocal();
