import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/projects/view_models/project_edit_view_model.dart';

/// Public + private notes (multiline, no Enter-submit).
class ProjectEditNotesSection extends StatelessWidget {
  const ProjectEditNotesSection({super.key, required this.vm});
  final ProjectEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    return DashboardCardShell(
      title: context.tr('notes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          EntityEditField(
            label: context.tr('public_notes'),
            initial: vm.draft.publicNotes,
            onChanged: vm.setPublicNotes,
            minLines: 2,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
          ),
          EntityEditField(
            label: context.tr('private_notes'),
            initial: vm.draft.privateNotes,
            onChanged: vm.setPrivateNotes,
            minLines: 2,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
