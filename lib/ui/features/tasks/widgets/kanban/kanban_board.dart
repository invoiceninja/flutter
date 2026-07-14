import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/tasks/view_models/kanban_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/kanban/kanban_column.dart';

/// The horizontal board: one column per [TaskStatus], cards inside drag
/// between columns. Reads [KanbanViewModel] off the ambient `Provider`.
///
/// Drop semantics:
///   * Drop a [Task] on a column → that task's `status_id` becomes the
///     column's id; the column's `task_ids` array appends the task at
///     the bottom.
///   * Drop a [Task] on another card → that task lands above the target
///     card in the same column.
///   * Within-column moves are detected by `task.statusId == target.id`.
///
/// The board only ever calls `commitReorder` once per drop, with the
/// **entire** board layout — so changes that span columns write to both
/// the source and target columns transactionally.
/// Visible width of a kanban column. Shared so the drag-feedback widget
/// in [KanbanColumn] doesn't shrink the card mid-drag.
const double kKanbanColumnWidth = 320;

/// Inner card width — the column's content area after its inner padding
/// (`InSpacing.sm * 2`). Used by the drag-feedback widget so the floating
/// preview matches the resting card's footprint.
const double kKanbanCardWidth = kKanbanColumnWidth - InSpacing.sm * 2;

class KanbanBoard extends StatelessWidget {
  const KanbanBoard({super.key});

  static const double _columnGap = 12;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KanbanViewModel>();

    if (vm.isResolving && vm.statuses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.statuses.isEmpty) {
      // Surface the "Create a status" CTA inline so users discover the
      // settings screen from the kanban itself. Hidden for non-admins
      // (statuses are an admin-ish surface; non-edit users don't have
      // access to Settings → Task Statuses anyway).
      final me = context.read<Services>().auth.session.value?.currentCompany;
      final canEdit = me?.can('edit_task') ?? false;
      return EmptyState(
        icon: Icons.label_outline,
        title: context.tr('no_task_statuses'),
        subtitle: context.tr('no_task_statuses_hint'),
        action: !canEdit
            ? null
            : FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                icon: const Icon(Icons.add),
                label: Text(context.tr('new_task_status')),
                onPressed: () => context.go('/settings/task_statuses/new'),
              ),
      );
    }

    final me = context.read<Services>().auth.session.value?.currentCompany;
    final canEdit = me?.can('edit_task') ?? false;

    return Padding(
      // Horizontal 24 to match `EntityListScreenScaffold`'s table-card
      // padding so the kanban content's right edge sits flush with the
      // List|Kanban toggle's right edge — switching views no longer
      // visually shifts the toggle relative to the body below.
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: 24,
        vertical: InSpacing.md(context),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: vm.statuses.length,
        separatorBuilder: (_, _) => const SizedBox(width: _columnGap),
        itemBuilder: (context, i) {
          final status = vm.statuses[i];
          return SizedBox(
            width: kKanbanColumnWidth,
            child: KanbanColumn(
              status: status,
              tasks: vm.tasksFor(status.id),
              companyId: vm.companyId,
              // Reordering is disabled while a filter is active: the board
              // shows a partial set, so a persisted reorder would drop the
              // hidden tasks from this status's order.
              canEdit: canEdit && !vm.filtersActive,
              onAcceptTask: (task, beforeTaskId) =>
                  _onAccept(vm, status, task, beforeTaskId),
              onAcceptStatus: (canEdit && !vm.filtersActive)
                  ? (dropped) => _onAcceptStatus(vm, status, dropped)
                  : null,
            ),
          );
        },
      ),
    );
  }

  /// Drop a column on top of another column → reorder the status set so
  /// the dropped status lands at the target column's current position.
  /// Calls [KanbanViewModel.commitStatusReorder] with the new id list.
  void _onAcceptStatus(
    KanbanViewModel vm,
    TaskStatus targetStatus,
    TaskStatus droppedStatus,
  ) {
    if (droppedStatus.id == targetStatus.id) return;
    final ordered = vm.statuses.map((s) => s.id).toList(growable: true)
      ..removeWhere((id) => id == droppedStatus.id);
    final targetIndex = ordered.indexWhere((id) => id == targetStatus.id);
    if (targetIndex < 0) {
      ordered.add(droppedStatus.id);
    } else {
      ordered.insert(targetIndex, droppedStatus.id);
    }
    vm.commitStatusReorder(ordered);
  }

  void _onAccept(
    KanbanViewModel vm,
    TaskStatus targetStatus,
    Task draggedTask,
    String? beforeTaskId,
  ) {
    // Build the next full layout from the current `tasksByStatus`,
    // removing the dragged task from its source column and inserting it
    // at the right position in the target column.
    final next = <String, List<Task>>{
      for (final s in vm.statuses)
        s.id: List<Task>.from(vm.tasksFor(s.id))
          ..removeWhere((t) => t.id == draggedTask.id),
    };
    final targetList = next[targetStatus.id] ?? <Task>[];
    final moved = draggedTask.copyWith(statusId: targetStatus.id);
    if (beforeTaskId == null) {
      targetList.add(moved);
    } else {
      final idx = targetList.indexWhere((t) => t.id == beforeTaskId);
      targetList.insert(idx < 0 ? targetList.length : idx, moved);
    }
    next[targetStatus.id] = targetList;
    vm.commitReorder(orderedByStatus: next);
  }
}
