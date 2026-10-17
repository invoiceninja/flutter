import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/document_record.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/edit/edit_action_filter.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/edit/entity_edit_screen_scaffold.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/widgets/centered_form_column.dart';
import 'package:admin/ui/core/widgets/labeled_switch_group.dart';
import 'package:admin/ui/features/documents/view_models/document_edit_view_model.dart';
import 'package:admin/ui/features/documents/widgets/document_actions.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';

/// Rename a file, or make it public or private — the two things
/// `PUT /documents/{id}` accepts. Opens as a slide-over beside the list
/// (`_kEditDefaultsToSlide`); there is no create route.
class DocumentEditScreen extends StatelessWidget {
  const DocumentEditScreen({required this.existingId, super.key});

  final String existingId;

  @override
  Widget build(BuildContext context) {
    return EntityEditScreenScaffold<DocumentRecord, DocumentEditViewModel>(
      existingId: existingId,
      entityTypeName: 'document',
      // A file never listed on this device (a shared edit link) is fetched
      // first, so the form opens on the real name.
      fetchExisting: (ctx, services, companyId, id) async {
        await services.documents.ensureLoaded(companyId: companyId, id: id);
        return services.documents.watch(companyId: companyId, id: id).first;
      },
      buildVm: (ctx, services, companyId, existing) => DocumentEditViewModel(
        repo: services.documents,
        companyId: companyId,
        // Never null: the scaffold shows "not found" itself for a missing
        // record and doesn't build a view model for it.
        existing: existing!,
        sync: services.sync,
        connectivity: services.connectivity,
      ),
      titleWhileLoading: (ctx) => ctx.tr('edit_document'),
      titleBuilder: (ctx, vm) => vm.draft.name.isNotEmpty
          ? '${ctx.tr('edit')} · ${vm.draft.name}'
          : ctx.tr('edit_document'),
      // A nameless file would list as its hash.
      canSave: (vm) =>
          !vm.isSaving && vm.isDirty && vm.draft.name.trim().isNotEmpty,
      bodyBuilder: (ctx, vm) => SingleChildScrollView(
        child: CenteredFormColumn(
          child: FormSection(
            title: ctx.tr('document'),
            children: [
              EntityEditField(
                label: ctx.tr('name'),
                initial: vm.draft.name,
                onChanged: vm.setName,
                errorText: vm.fieldErrorFor('name'),
                autofocus: true,
              ),
              LabeledSwitchGroup(
                items: [
                  LabeledSwitchItem(
                    label: ctx.tr('public'),
                    value: vm.draft.isPublic,
                    onChanged: vm.setPublic,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      resetToEmpty: (vm) => vm.reset(emptyDraft: vm.original ?? vm.draft),
      entityIdOf: (d) => d.id,
      actionsBuilder: (ctx, vm, onTap, saveButton) =>
          EntityOverflowActionBar<DocumentAction>(
            leading: saveButton,
            items: filterForEditScreen(
              DocumentActions.itemsFor(
                ctx,
                vm.draft,
                (a) => onTap(a),
              ).where((i) => i.kind != DocumentAction.edit).toList(),
              isCreate: false,
              isLifecycle: DocumentActions.isLifecycle,
            ),
          ),
      onAfterSaveAction: (ctx, saved, a) {
        final services = ctx.read<Services>();
        return DocumentActions.dispatch(
          ctx,
          services,
          services.auth.session.value!.currentCompanyId,
          saved,
          a as DocumentAction,
        );
      },
      onSaved: (ctx, vm, saved) => goAfterEntitySave(
        ctx,
        isCreate: false,
        basePath: '/documents',
        savedId: saved.id,
      ),
    );
  }
}
