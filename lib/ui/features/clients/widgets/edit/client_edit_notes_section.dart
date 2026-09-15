import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/billing_shared/markdown_notes_section.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';

/// "Notes" card on the client edit screen — private + public notes.
///
/// Both fields are HTML on the wire, exactly like a billing document's notes:
/// the React client edits them with its rich editor and every consumer renders
/// the stored string as markup. So they use the same editor the billing screens
/// do, which folds inbound HTML to markdown and writes HTML back out. As plain
/// text fields they lost every line break the moment the record was opened on
/// the web (invoiceninja/flutter#159), and painted React's `<strong>` at the
/// user as raw tags.
class ClientEditNotesSection extends StatelessWidget {
  const ClientEditNotesSection({super.key, required this.vm});

  final ClientEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final draft = vm.draft;
    return FocusTraversalGroup(
      // Two editors in a scroll view: the reading-order policy calls
      // `FocusNode.rect` on the markdown hosts before they are laid out. Same
      // guard the billing Notes tabs carry.
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
