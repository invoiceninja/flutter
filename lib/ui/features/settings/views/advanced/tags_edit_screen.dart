import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/tag.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/tag_pill.dart';
import 'package:admin/ui/features/settings/view_models/tag_edit_view_model.dart';
import 'package:admin/ui/features/settings/widgets/accent_swatch_grid.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_edit_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_text_field.dart';

/// `/settings/tags/new` (with `?entityType=task|project`) and
/// `/settings/tags/:id`. Create-or-edit a single Tag. Lifecycle + chrome are
/// owned by [SettingsEntityEditScaffold]; this declares the name + color
/// fields and a live pill preview. Admin/owner-gated (the server gates
/// create/update to admins).
class TagsEditScreen extends StatelessWidget {
  const TagsEditScreen({this.existingId, this.entityType = 'task', super.key});

  final String? existingId;

  /// Entity type for a new tag (`task` / `project`); ignored when editing
  /// (the loaded tag's type wins).
  final String entityType;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.tags;

    return SettingsEntityEditScaffold<Tag, TagEditViewModel>(
      existingId: existingId,
      backRoute: '/settings/tags',
      createTitleKey: 'new_tag',
      editTitleKey: 'edit_tag',
      wireName: 'tag',
      watchById: (id) => repo.watch(companyId: companyId, id: id),
      refreshAll: () => repo.refreshAll(companyId: companyId),
      onArchive: (id) => repo.archive(companyId: companyId, id: id),
      onRestore: (id) => repo.restore(companyId: companyId, id: id),
      onDelete: (id) => repo.delete(companyId: companyId, id: id),
      vmFactory: ({existing}) => TagEditViewModel(
        repo: repo,
        companyId: companyId,
        entityType: entityType,
        commasNotAllowedMessage: context.tr('commas_not_allowed'),
        existing: existing,
        sync: services.sync,
        connectivity: services.connectivity,
      ),
      isArchivedOf: (t) => t.archivedAt != null,
      isDeletedOf: (t) => t.isDeleted,
      canSave: (vm) =>
          !vm.isSaving && vm.isDirty && vm.draft.name.trim().isNotEmpty,
      bodyBuilder: (context, vm) => [
        FormSection(
          title: context.tr('tag'),
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
  final TagEditViewModel vm;

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
          Align(
            alignment: Alignment.centerLeft,
            child: TagPill(
              name: vm.draft.name.trim().isEmpty
                  ? context.tr('untitled')
                  : vm.draft.name,
              colorHex: vm.draft.color,
            ),
          ),
        ],
      ),
    );
  }
}
