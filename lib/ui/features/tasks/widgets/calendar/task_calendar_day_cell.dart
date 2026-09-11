import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/calendar_connection_api_model.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/tasks/view_models/calendar_connection_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/calendar_event_chip.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/convert_event_to_task_sheet.dart';
import 'package:admin/ui/features/tasks/widgets/calendar/task_calendar_chip.dart';
import 'package:admin/utils/formatting.dart';

/// One day in the month grid: the day number (today in a filled accent
/// circle), up to three task chips, then any calendar-event chips, each with a
/// "+N more" overflow line. Tapping the cell — or an overflow line — opens that
/// day's daily view; tapping an event chip opens the convert-to-task sheet.
class TaskCalendarDayCell extends StatelessWidget {
  const TaskCalendarDayCell({
    super.key,
    required this.day,
    required this.tasks,
    required this.inMonth,
    required this.isToday,
    this.events = const [],
    this.formatter,
  });

  final Date day;
  final List<Task> tasks;
  final List<CalendarEvent> events;
  final bool inMonth;
  final bool isToday;
  final Formatter? formatter;

  static const _maxChips = 3;
  static const _maxEventChips = 2;

  void _openDay(BuildContext context) =>
      context.go('/tasks?view=daily&date=${day.toIso()}');

  void _convert(BuildContext context, CalendarEvent event) {
    final services = context.read<Services>();
    showConvertEventSheet(
      context: context,
      event: event,
      companyId: services.auth.session.value?.currentCompanyId ?? '',
      calendarVm: context.read<CalendarConnectionViewModel>(),
      formatter: formatter,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final taskOverflow = tasks.length - _maxChips;
    final eventOverflow = events.length - _maxEventChips;

    return InkWell(
      onTap: () => _openDay(context),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.border, width: 0.5),
        ),
        padding: const EdgeInsets.all(4),
        child: Opacity(
          opacity: inMonth ? 1 : 0.45,
          // Whole cell content in one non-scrollable scroll view: clips
          // gracefully (no RenderFlex overflow) when a grid row is very short.
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _dayNumber(context, tokens),
                const SizedBox(height: 2),
                for (final task in tasks.take(_maxChips))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: TaskCalendarChip(task: task),
                  ),
                if (taskOverflow > 0) _overflow(context, tokens, taskOverflow),
                for (final event in events.take(_maxEventChips))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: CalendarEventChip(
                      event: event,
                      formatter: formatter,
                      onTap: () => _convert(context, event),
                    ),
                  ),
                if (eventOverflow > 0)
                  _overflow(context, tokens, eventOverflow),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _overflow(BuildContext context, InTheme tokens, int count) =>
      GestureDetector(
        onTap: () => _openDay(context),
        child: Padding(
          padding: const EdgeInsets.only(left: 4, top: 1),
          child: Text(
            '+$count ${context.tr('more')}',
            style: TextStyle(
              fontSize: 10,
              color: tokens.ink3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

  Widget _dayNumber(BuildContext context, InTheme tokens) {
    final text = '${day.day}';
    if (isToday) {
      return Align(
        alignment: Alignment.topLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: tokens.accent,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: tokens.onAccent,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: 3, top: 3),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(text, style: TextStyle(fontSize: 11, color: tokens.ink)),
      ),
    );
  }
}
