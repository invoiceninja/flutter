import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/markdown_notes_section.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_edit_view_model.dart';

/// "Notes" card on the vendor edit screen — private + public notes. Mirror
/// of `ClientEditNotesSection`, including why these are markdown fields and
/// not plain text (invoiceninja/flutter#159).
class VendorEditNotesSection extends StatelessWidget {
  const VendorEditNotesSection({super.key, required this.vm});

  final VendorEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: DashboardCardShell(
        title: context.tr('notes'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            MarkdownNotesField(
              label: context.tr('private_notes'),
              value: draft.privateNotes,
              onChanged: vm.setPrivateNotes,
              registerBeforeSaveHook: vm.addBeforeSaveHook,
              height: 120,
            ),
            SizedBox(height: InSpacing.md(context)),
            MarkdownNotesField(
              label: context.tr('public_notes'),
              value: draft.publicNotes,
              onChanged: vm.setPublicNotes,
              registerBeforeSaveHook: vm.addBeforeSaveHook,
              height: 120,
            ),
          ],
        ),
      ),
    );
  }
}
