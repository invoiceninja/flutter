import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_edit_view_model.dart';

/// Public + private notes. Multiline — Enter inserts newlines.
class RecurringExpenseEditNotesSection extends StatelessWidget {
  const RecurringExpenseEditNotesSection({super.key, required this.vm});
  final RecurringExpenseEditViewModel vm;

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
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
          EntityEditField(
            label: context.tr('private_notes'),
            initial: vm.draft.privateNotes,
            onChanged: vm.setPrivateNotes,
            maxLines: 4,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }
}
