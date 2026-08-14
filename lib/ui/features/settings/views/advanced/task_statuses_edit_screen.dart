import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/task_status.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/task_status_colors.dart';
import 'package:admin/ui/features/settings/view_models/task_status_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/accent_swatch_grid.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';

/// `/settings/task_statuses/new` and `/settings/task_statuses/:id`.
///
/// Edit-or-create form for a single TaskStatus. Lifecycle, AppBar, and
/// the archive/restore/delete overflow are owned by
/// [SettingsEntityEditScaffold] — this widget just declares the name +
/// color fields and the kanban preview.
class TaskStatusesEditScreen extends StatelessWidget {
  const TaskStatusesEditScreen({this.existingId, super.key});

  final String? existingId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.taskStatuses;

    return SettingsEntityEditScaffold<TaskStatus, TaskStatusEditViewModel>(
      existingId: existingId,
      backRoute: '/settings/task_statuses',
      createTitleKey: 'new_task_status',
      editTitleKey: 'edit_task_status',
      wireName: 'task_status',
      watchById: (id) => repo.watch(companyId: companyId, id: id),
      refreshAll: () => repo.refreshAll(companyId: companyId),
      onArchive: (id) => repo.archive(companyId: companyId, id: id),
      onRestore: (id) => repo.restore(companyId: companyId, id: id),
      onDelete: (id) => repo.delete(companyId: companyId, id: id),
      vmFactory: ({existing}) => TaskStatusEditViewModel(
        repo: repo,
        companyId: companyId,
        existing: existing,
        sync: services.sync,
        connectivity: services.connectivity,
      ),
      isArchivedOf: (s) => s.archivedAt != null,
      isDeletedOf: (s) => s.isDeleted,
      // Block Save when name is empty — a nameless status would render as
      // its UUID on the kanban column header.
      canSave: (vm) =>
          !vm.isSaving && vm.isDirty && vm.draft.name.trim().isNotEmpty,
      bodyBuilder: (context, vm) => [
        FormSection(
          title: context.tr('task_status'),
          children: [
            SettingsTextField(
              initialValue: vm.draft.name,
              labelKey: 'name',
              onChanged: vm.setName,
              errorText: vm.fieldErrorFor('name'),
              externalSyncKey: vm.original?.id,
            ),
            _ColorField(vm: vm),
          ],
        ),
      ],
    );
  }
}

class _ColorField extends StatelessWidget {
  const _ColorField({required this.vm});
  final TaskStatusEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('color'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          AccentSwatchGrid(
            selected: vm.draft.color,
            onSelected: vm.setColor,
            palette: kStatusSwatches,
          ),
          SizedBox(height: InSpacing.md(context)),
          _StatusPreview(name: vm.draft.name, color: vm.draft.color),
        ],
      ),
    );
  }
}

/// Live preview of how the status will read on a kanban column header.
/// Updates as the user types into the name field or picks a different
/// swatch — exact rendering matches what `_ColumnHeader` does in the
/// kanban (color dot + name + token-styled label).
class _StatusPreview extends StatelessWidget {
  const _StatusPreview({required this.name, required this.color});

  final String name;
  final String color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Same resolver the list row and kanban header use, so a status the
    // server left colorless previews in its derived color rather than a
    // neutral the user never sees anywhere else.
    final parsed = taskStatusColors(context, name: name, color: color).fg;
    final displayName = name.trim().isEmpty ? context.tr('untitled') : name;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border.all(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.md(context),
        vertical: InSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: parsed, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
          ),
          Text('0', style: TextStyle(fontSize: 12, color: tokens.ink3)),
        ],
      ),
    );
  }
}
