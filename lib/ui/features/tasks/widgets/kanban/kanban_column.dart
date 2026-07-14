import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart'
    show emptyTask;
import 'package:admin/ui/features/tasks/widgets/kanban/kanban_board.dart'
    show kKanbanCardWidth;
import 'package:admin/ui/features/tasks/widgets/kanban/kanban_card.dart';
import 'package:admin/ui/features/tasks/widgets/task_status_pill.dart'
    show parseStatusColor;

/// How long the user must hold on a drag handle before the drag begins.
/// Down from Flutter's `kLongPressTimeout` (≈500ms) — fast enough that
/// the drag feels responsive on desktop but still distinguishable from a
/// short tap so the underlying tap-to-detail / vertical-scroll gestures
/// aren't accidentally captured.
const _kDragStartDelay = Duration(milliseconds: 200);

/// One column on the kanban board. Renders the status header + a scrollable
/// list of [KanbanCard]s, wrapped in DragTargets so cards can be dropped
/// onto cards (insert above) or onto the empty area below (append).
///
/// Both card drag and column-header drag use a visible handle icon
/// (`Icons.drag_indicator`) so the affordance is obvious. The rest of
/// the card stays tap-only — taps navigate to the task detail screen.
class KanbanColumn extends StatelessWidget {
  const KanbanColumn({
    super.key,
    required this.status,
    required this.tasks,
    required this.companyId,
    required this.onAcceptTask,
    this.onAcceptStatus,
    this.canEdit = true,
  });

  final TaskStatus status;
  final List<Task> tasks;

  /// Active company id — threaded by value into each card's inline timer
  /// toggle (drag-feedback cards render in the Overlay, outside the
  /// KanbanViewModel Provider, so it can't be read from context there).
  final String companyId;

  /// Called when the user drops [task] onto this column. [beforeTaskId] is
  /// the id of the card the dragged task should appear *above*, or null
  /// to append at the bottom.
  final void Function(Task task, String? beforeTaskId) onAcceptTask;

  /// Called when the user drops [droppedStatus]'s column header onto this
  /// column. The board reorders the column set so [droppedStatus] lands
  /// where this column currently sits. Null disables column reorder.
  final void Function(TaskStatus droppedStatus)? onAcceptStatus;

  /// Whether the active user can mutate tasks. When false, drag handles
  /// are hidden and drops are no-ops — read-only users can't initiate a
  /// drop the server would reject anyway.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final dot = parseStatusColor(status.color, fallback: tokens.ink3);

    // Column header: dot · name · count · drag handle. The handle is the
    // only draggable region; the rest of the header is non-interactive
    // (tap does nothing). The whole header is still a DragTarget so a
    // dropped column lands on it.
    final headerDragHandle = (canEdit && onAcceptStatus != null)
        ? _DragHandle<TaskStatus>(
            data: status,
            feedback: SizedBox(
              width: kKanbanCardWidth,
              child: _ColumnHeader(
                status: status,
                taskCount: tasks.length,
                dot: dot,
                tokens: tokens,
              ),
            ),
            tokens: tokens,
            tooltipKey: 'drag_to_reorder',
          )
        : null;

    final header = _ColumnHeader(
      status: status,
      taskCount: tasks.length,
      dot: dot,
      tokens: tokens,
      dragHandle: headerDragHandle,
    );

    Widget headerSlot = header;
    if (canEdit && onAcceptStatus != null) {
      headerSlot = DragTarget<TaskStatus>(
        onWillAcceptWithDetails: (details) => details.data.id != status.id,
        onAcceptWithDetails: (details) => onAcceptStatus!(details.data),
        builder: (context, candidate, rejected) {
          if (candidate.isEmpty) return header;
          // Highlight the target header with a thin accent strip on top.
          return Stack(
            children: [
              header,
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(height: 3, color: tokens.accent),
              ),
            ],
          );
        },
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          headerSlot,
          Divider(height: 1, color: tokens.border),
          Expanded(
            child: DragTarget<Task>(
              onAcceptWithDetails: canEdit
                  ? (details) => onAcceptTask(details.data, null)
                  : null,
              builder: (context, candidate, rejected) {
                // Empty column + hovering card → paint a "drop here" hint
                // so the user sees that the empty body is a valid target.
                if (tasks.isEmpty && candidate.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(InSpacing.sm),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tokens.accentSoft,
                        border: Border.all(color: tokens.accent),
                        borderRadius: BorderRadius.circular(InRadii.r2),
                      ),
                      alignment: Alignment.center,
                      child: Padding(
                        padding: EdgeInsets.all(InSpacing.md(context)),
                        child: Icon(Icons.add, size: 20, color: tokens.accent),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(InSpacing.sm),
                  itemCount: tasks.length,
                  itemBuilder: (context, i) {
                    final t = tasks[i];
                    final cardBody = KanbanCard(task: t, companyId: companyId);
                    if (!canEdit) {
                      // Read-only — render the card without drag wiring.
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: cardBody,
                      );
                    }
                    return DragTarget<Task>(
                      onWillAcceptWithDetails: (details) =>
                          details.data.id != t.id,
                      onAcceptWithDetails: (details) {
                        onAcceptTask(details.data, t.id);
                      },
                      builder: (context, candidate, rejected) {
                        // Card with visible drag handle in the top-right.
                        // Tap anywhere else on the card → detail screen
                        // (KanbanCard's own InkWell). Hold the handle for
                        // ~200ms → drag begins.
                        final cardWithHandle = Stack(
                          children: [
                            cardBody,
                            Positioned(
                              top: 4,
                              right: 4,
                              child: _DragHandle<Task>(
                                data: t,
                                feedback: SizedBox(
                                  width: kKanbanCardWidth,
                                  // Drag ghost: no interactive timer button.
                                  child: KanbanCard(
                                    task: t,
                                    companyId: companyId,
                                    showTimerButton: false,
                                  ),
                                ),
                                tokens: tokens,
                                tooltipKey: 'drag_to_reorder',
                              ),
                            ),
                          ],
                        );
                        if (candidate.isNotEmpty) {
                          return Stack(
                            children: [
                              cardWithHandle,
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                child: Container(
                                  height: 3,
                                  color: tokens.accent,
                                ),
                              ),
                            ],
                          );
                        }
                        return cardWithHandle;
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Per-column quick-add (admin-portal parity): seeds the new task
          // with this column's status so it lands in the right column.
          if (canEdit) ...[
            Divider(height: 1, color: tokens.border),
            InkWell(
              onTap: () => goEntityCreateFullWidth(
                context,
                '/tasks',
                extra: emptyTask().copyWith(statusId: status.id),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(InRadii.r3),
              ),
              child: Padding(
                padding: EdgeInsets.all(InSpacing.md(context)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16, color: tokens.ink3),
                    const SizedBox(width: 6),
                    Text(
                      context.tr('new_task'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: tokens.ink3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A visible drag-handle icon that initiates a `LongPressDraggable<T>` on
/// hold. The handle itself is the only draggable region — wrap a tappable
/// parent around it and the parent's tap stays intact (gesture arena
/// hands the long-press to the draggable, the short-tap to the parent).
///
/// Shared between card and column-header drag so the affordance reads
/// consistently across the board.
class _DragHandle<T extends Object> extends StatelessWidget {
  const _DragHandle({
    required this.data,
    required this.feedback,
    required this.tokens,
    required this.tooltipKey,
  });

  final T data;

  /// The widget to render under the user's finger / cursor while
  /// dragging. The caller picks the size to match the source widget so
  /// the preview doesn't shrink.
  final Widget feedback;

  final InTheme tokens;
  final String tooltipKey;

  @override
  Widget build(BuildContext context) {
    final icon = MouseRegion(
      cursor: SystemMouseCursors.move,
      child: Tooltip(
        message: context.tr(tooltipKey),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(Icons.drag_indicator, size: 18, color: tokens.ink4),
        ),
      ),
    );
    return LongPressDraggable<T>(
      data: data,
      delay: _kDragStartDelay,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(opacity: 0.85, child: feedback),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: icon),
      child: icon,
    );
  }
}

/// The column's title bar: color dot · name · count · optional drag
/// handle. Pulled out so the `LongPressDraggable` feedback can render an
/// identical preview without rebuilding the rest of the column.
class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({
    required this.status,
    required this.taskCount,
    required this.dot,
    required this.tokens,
    this.dragHandle,
  });

  final TaskStatus status;
  final int taskCount;
  final Color dot;
  final InTheme tokens;

  /// Optional drag handle rendered to the right of the count. Null for
  /// read-only users (the column isn't draggable).
  final Widget? dragHandle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(InSpacing.md(context)),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status.name.isEmpty ? status.id : status.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
          ),
          Text(
            taskCount.toString(),
            style: TextStyle(fontSize: 12, color: tokens.ink3),
          ),
          if (dragHandle != null) ...[const SizedBox(width: 4), dragHandle!],
        ],
      ),
    );
  }
}
