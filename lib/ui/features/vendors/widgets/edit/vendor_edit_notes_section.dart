import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_edit_view_model.dart';

/// "Notes" card on the vendor edit screen — private + public notes. Mirror
/// of `ClientEditNotesSection`.
class VendorEditNotesSection extends StatelessWidget {
  const VendorEditNotesSection({super.key, required this.vm});

  final VendorEditViewModel vm;

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
