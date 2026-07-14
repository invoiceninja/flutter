import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/features/tasks/widgets/inline_timer_toggle_button.dart';
import 'package:admin/ui/features/tasks/widgets/running_duration_label.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';
import 'package:admin/utils/formatting.dart';

/// One card in a kanban column. Compact summary of a Task; tapping
/// navigates to the detail screen. Drag is wrapped by the column's
/// `LongPressDraggable<Task>`.
class KanbanCard extends StatelessWidget {
  const KanbanCard({
    super.key,
    required this.task,
    required this.companyId,
    this.showTimerButton = true,
  });

  final Task task;

  /// Active company id for the inline timer toggle (threaded by value —
  /// see [KanbanColumn.companyId]).
  final String companyId;

  /// False on the drag-feedback ghost so an inert button doesn't ride along.
  final bool showTimerButton;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final identity = task.description.isEmpty
        ? (task.number.isEmpty ? '—' : '#${task.number}')
        : task.description;
    return InkWell(
      onTap: () => goEntityRecord(context, EntityType.task, task.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(InSpacing.md(context)),
        decoration: BoxDecoration(
          color: tokens.surface,
          // Invoiced uses `tokens.paid` — reserves accent for running
          // state so the two distinct signals stay visually distinct.
          border: Border.all(
            color: task.isInvoiced ? tokens.paid : tokens.border,
          ),
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    identity,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: tokens.ink,
                    ),
                  ),
                ),
                if (task.isInvoiced) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.attach_money, size: 14, color: tokens.paid),
                ],
              ],
            ),
            if (task.clientId.isNotEmpty) ...[
              const SizedBox(height: 4),
              ClientNameLabel(
                clientId: task.clientId,
                style: TextStyle(fontSize: 12, color: tokens.ink3),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (task.isRunning && task.timeLog.isNotEmpty)
                  RunningDurationLabel(
                    start: task.timeLog.last.start!,
                    precision: const Duration(minutes: 1),
                    dotSize: 6,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  )
                else
                  Text(
                    formatDuration(
                      task.loggedDuration(),
                      compactDays: true,
                      showSeconds: false,
                    ),
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.ink3,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                if (showTimerButton && TaskActions.canToggleTimer(task)) ...[
                  const Spacer(),
                  InlineTimerToggleButton(
                    task: task,
                    companyId: companyId,
                    iconSize: 16,
                    minTapTarget: 36,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
