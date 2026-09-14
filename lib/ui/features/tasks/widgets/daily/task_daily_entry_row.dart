import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/domain/tasks/task_day.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/ui/features/tasks/widgets/daily/task_daily_actions.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';
import 'package:admin/utils/formatting.dart';

/// One time-entry row in the daily timeline: task identity + project/client and
/// time range, the entry duration, and a Start/Stop button. Tapping the row
/// opens the task editor.
class TaskDailyEntryRow extends StatelessWidget {
  const TaskDailyEntryRow({
    super.key,
    required this.task,
    required this.entry,
    required this.companyId,
    this.formatter,
  });

  final Task task;
  final TimeEntry entry;
  final String companyId;
  final Formatter? formatter;

  String _clock(DateTime? utc, bool military) {
    if (utc == null) return '';
    final local = utc.toLocal();
    return formatTimeOfDay(local.hour, local.minute, military: military);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final services = context.read<Services>();
    final military = formatter?.settings.enableMilitaryTime ?? true;
    // Per-entry running state drives the duration label / time-range text only.
    final running = entry.isRunning;
    // The toggle button reflects the TASK's running state, because
    // TaskDailyActions.toggleTimer keys off task.isRunning (the last entry).
    // Driving the button off the per-entry flag inverted it on a stopped row
    // of a running task: a Play/"Start" button that actually stops the timer.
    final taskRunning = task.isRunning;
    final secondaryStyle = TextStyle(fontSize: 12, color: tokens.ink3);

    final timeRange = running
        ? '${_clock(entry.start, military)} · ${context.tr('running')}'
        : '${_clock(entry.start, military)} – ${_clock(entry.stop, military)}';

    // The shared gate, not a fourth hand-rolled copy: this one was missing
    // `isDeleted`, so a soft-deleted task's row still offered a timer that
    // `TaskRepository.startTimer` then refuses — a button that does nothing.
    final canToggle = TaskActions.canToggleTimer(task);

    return InkWell(
      onTap: () => context.go('/tasks/${task.id}/edit'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    taskPrimaryLabel(task),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (task.projectId.isNotEmpty)
                        Flexible(
                          child: ProjectNameLabel(
                            projectId: task.projectId,
                            style: secondaryStyle,
                          ),
                        )
                      else if (task.clientId.isNotEmpty)
                        Flexible(
                          child: ClientNameLabel(
                            clientId: task.clientId,
                            style: secondaryStyle,
                          ),
                        ),
                      if (task.projectId.isNotEmpty || task.clientId.isNotEmpty)
                        Text('  ·  ', style: secondaryStyle),
                      Text(timeRange, style: secondaryStyle),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            running
                ? RunningDurationLabel(
                    start: entry.start!,
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                : Text(
                    formatDuration(
                      entry.durationUpTo(DateTime.now()),
                      showSeconds: false,
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.ink2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
            if (canToggle)
              IconButton(
                tooltip: context.tr(taskRunning ? 'stop' : 'start'),
                icon: Icon(
                  taskRunning
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle_outlined,
                ),
                onPressed: () => TaskDailyActions.toggleTimer(
                  context,
                  services,
                  companyId,
                  task,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
