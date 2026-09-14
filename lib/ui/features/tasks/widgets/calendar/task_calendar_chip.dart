import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/domain/tasks/task_schedule.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/tasks/task_day.dart';

/// One task chip in a calendar day cell. Rounded rectangle (never a pill); its
/// border colour signals running (accent) / invoiced (paid). The full
/// description shows on hover; tapping opens the task editor.
class TaskCalendarChip extends StatelessWidget {
  const TaskCalendarChip({super.key, required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Running wins, then "you are due on site now" — the two states worth
    // finding at a glance in a month grid. A booking further out keeps the
    // neutral border: on a calendar, *every* future chip is booked, so tinting
    // them all would say nothing.
    final dueNow =
        !task.isRunning &&
        task.scheduleStateAt(DateTime.now()) == TaskScheduleState.dueNow;
    final borderColor = task.isRunning
        ? tokens.accent
        : dueNow
        ? tokens.warning
        : (task.isInvoiced ? tokens.paid : tokens.border);
    return Tooltip(
      message: taskPrimaryLabel(task),
      waitDuration: const Duration(milliseconds: 300),
      child: InkWell(
        onTap: () => context.go('/tasks/${task.id}/edit'),
        borderRadius: BorderRadius.circular(InRadii.r1),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(InRadii.r1),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            taskPrimaryLabel(task, max: 40),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: tokens.ink),
          ),
        ),
      ),
    );
  }
}
