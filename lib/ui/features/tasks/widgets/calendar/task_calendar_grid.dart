import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/api/calendar_connection_api_model.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/tasks/view_models/calendar_connection_view_model.dart';
import 'package:admin/ui/features/tasks/view_models/task_calendar_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/task_calendar_day_cell.dart';
import 'package:admin/utils/formatting.dart';

/// Vertical chrome this widget spends before the week rows get any height: the
/// 16 px of its own padding, plus the weekday header strip (an 11 px label
/// inside 6 px of padding each side, ~27 px rendered).
const double _kGridChrome = 16 + 27;

/// The least height the month grid can take before its day cells begin clipping
/// the date itself — six week rows at [TaskCalendarDayCell.minHeight] plus this
/// widget's own chrome.
///
/// The grid never scrolls, so every pixel taken from it comes out of the week
/// rows, and the cells swallow the loss without throwing (see
/// [TaskCalendarDayCell.minHeight]). Anything insetting the grid clamps against
/// this instead of trusting an overflow to complain.
const double kTaskCalendarMinGridHeight =
    6 * TaskCalendarDayCell.minHeight + _kGridChrome;

/// How much bottom clearance the grid can afford in [availableHeight] without
/// dropping below [kTaskCalendarMinGridHeight], never more than [desired].
///
/// Continuous rather than a breakpoint: a phone in landscape gets 0 and a phone
/// in portrait the full amount, with everything between degrading smoothly
/// instead of snapping at some width nobody can see coming.
double taskCalendarFabClearance({
  required double availableHeight,
  required double desired,
}) => (availableHeight - kTaskCalendarMinGridHeight).clamp(0.0, desired);

/// The month grid: a 7-column weekday header + 6 equal-height week rows of day
/// cells. Tasks are grouped by day once per build; each cell renders its own
/// chips. The grid fills the available height so the layout never scrolls.
class TaskCalendarGrid extends StatelessWidget {
  const TaskCalendarGrid({super.key, this.formatter});

  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TaskCalendarViewModel>();
    final calVm = context.watch<CalendarConnectionViewModel>();
    final tokens = context.inTheme;
    final days = vm.gridDays;
    final byDay = vm.tasksByDayFiltered();
    final showEvents = calVm.isConnected && !calVm.hideEvents;
    final eventsByDay = showEvents
        ? calVm.eventsByDay
        : const <String, List<CalendarEvent>>{};
    final today = Date.today();
    final month = vm.month;
    final locale = formatter?.settings.locale;
    final localeArg = locale == null || locale.isEmpty ? null : locale;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      DateFormat('EEE', localeArg).format(days[i].toDateTime()),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: tokens.ink3,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Column(
              children: [
                for (var week = 0; week < 6; week++)
                  Expanded(
                    child: Row(
                      children: [
                        for (final day in days.sublist(week * 7, week * 7 + 7))
                          Expanded(
                            child: TaskCalendarDayCell(
                              day: day,
                              tasks: byDay[day] ?? const [],
                              events: eventsByDay[day.toIso()] ?? const [],
                              formatter: formatter,
                              inMonth:
                                  day.month == month.month &&
                                  day.year == month.year,
                              isToday: day == today,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
