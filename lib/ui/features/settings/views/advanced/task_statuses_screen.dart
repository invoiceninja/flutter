import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/task_status_colors.dart';
import 'package:admin/ui/core/widgets/unsynced_pill.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_list_scaffold.dart';

/// `/settings/task_statuses` — list every task status. Drag the handle on
/// a row to reorder (kanban columns follow this order). Tap a row to edit;
/// tap "+ New" to create.
class TaskStatusesScreen extends StatelessWidget {
  const TaskStatusesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.taskStatuses;

    return SettingsEntityListScaffold<TaskStatus>(
      titleKey: 'task_statuses',
      sectionTitleKey: 'task_statuses',
      newRoute: '/settings/task_statuses/new',
      newLabelKey: 'new_task_status',
      emptyIcon: Icons.label_outline,
      emptyTitleKey: 'no_task_statuses',
      emptyHintKey: 'no_task_statuses_hint',
      supportsArchive: true,
      refreshAll: () async {
        if (companyId.isEmpty) return;
        await repo.refreshAll(companyId: companyId);
      },
      streamKey: companyId,
      stream: () => repo.watchAllIncludingArchived(companyId: companyId),
      isArchivedOf: (s) => s.archivedAt != null,
      isDeletedOf: (s) => s.isDeleted,
      reorderableRowBuilder: (s, i) =>
          _TaskStatusRow(key: ValueKey(s.id), status: s, index: i),
      archivedRowBuilder: (s) =>
          _TaskStatusRow.archived(key: ValueKey(s.id), status: s),
      onReorder: (reordered) => repo.reorder(
        companyId: companyId,
        orderedStatusIds: reordered.map((s) => s.id).toList(growable: false),
      ),
    );
  }
}

class _TaskStatusRow extends StatelessWidget {
  const _TaskStatusRow({required this.status, required this.index, super.key})
    : _isArchived = false;

  /// Variant rendered inside the "Archived" section. Drops the drag
  /// handle (status_order is moot until restored) and renders a muted
  /// "Archived" pill on the trailing edge.
  const _TaskStatusRow.archived({required this.status, super.key})
    : index = -1,
      _isArchived = true;

  final TaskStatus status;
  final int index;
  final bool _isArchived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: taskStatusColors(
                context,
                name: status.name,
                color: status.color,
              ).fg,
              shape: BoxShape.circle,
            ),
          ),
          title: Text(
            status.name.isEmpty ? context.tr('untitled') : status.name,
          ),
          trailing: _isArchived
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.draftSoft,
                    borderRadius: BorderRadius.circular(InRadii.r1),
                  ),
                  child: Text(
                    context.tr('archived'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.draft,
                    ),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The drag handle is the only way to reorder
                    // (`buildDefaultDragHandles: false`), so it stays put and
                    // the pill sits beside it rather than replacing it.
                    if (status.isDirty) ...[
                      const UnsyncedPill(),
                      const SizedBox(width: 8),
                    ],
                    ReorderableDragStartListener(
                      index: index,
                      child: Tooltip(
                        message: context.tr('drag_to_reorder'),
                        child: const Icon(Icons.drag_handle),
                      ),
                    ),
                  ],
                ),
          onTap: () => context.go('/settings/task_statuses/${status.id}'),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
