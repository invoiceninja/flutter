import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// "Notes" card on the client edit screen — private + public notes.
class ClientEditNotesSection extends StatelessWidget {
  const ClientEditNotesSection({super.key, required this.vm});

  final ClientEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    return DashboardCardShell(
      title: context.tr('notes'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          EntityEditField(
            label: context.tr('private_notes'),
            initial: draft.privateNotes,
            onChanged: vm.setPrivateNotes,
            minLines: 3,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
          ),
          EntityEditField(
            label: context.tr('public_notes'),
            initial: draft.publicNotes,
            onChanged: vm.setPublicNotes,
            minLines: 3,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
