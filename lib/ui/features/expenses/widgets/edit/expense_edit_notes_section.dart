import 'package:flutter/material.dart';

import 'package:admin/domain/expenses/receipt_fill.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/ui/features/expenses/widgets/edit/receipt_read_banner.dart';

/// Public + private notes. Multiline; Enter inserts newlines (not submit)
/// — `EntityEditField` only wires Enter-to-save on single-line fields.
class ExpenseEditNotesSection extends StatelessWidget {
  const ExpenseEditNotesSection({super.key, required this.vm});
  final ExpenseEditViewModel vm;

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
          ReceiptFieldFocus(
            vm: vm,
            fields: const [ReceiptFillField.notes],
            child: EntityEditField(
              label: context.tr('private_notes'),
              initial: vm.draft.privateNotes,
              onChanged: vm.setPrivateNotes,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              // A receipt's number lands here (docs/receipt-ocr.md).
              helper: ReceiptFieldMarker.of(vm, ReceiptFillField.notes),
            ),
          ),
        ],
      ),
    );
  }
}
