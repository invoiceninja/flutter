import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/edit/entity_edit_field.dart';
import 'package:admin/ui/core/widgets/link_text.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';

/// Banking section — bank_id + transaction_id + transaction_reference. When an
/// expense is linked to a bank transaction the bank/transaction ids are shown
/// read-only, with a "View" link through to the transaction record.
class ExpenseEditBankingSection extends StatelessWidget {
  const ExpenseEditBankingSection({super.key, required this.vm});
  final ExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final linked =
        vm.draft.bankId.isNotEmpty || vm.draft.transactionId.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        EntityEditField(
          label: context.tr('bank_id'),
          initial: vm.draft.bankId,
          onChanged: vm.setBankId,
          readOnly: linked,
          autocorrect: false,
        ),
        EntityEditField(
          label: context.tr('transaction_id'),
          initial: vm.draft.transactionId,
          onChanged: vm.setTransactionId,
          readOnly: linked,
          autocorrect: false,
        ),
        if (vm.draft.transactionId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              top: InSpacing.sm,
              bottom: InSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: LinkText(
                label: context.tr('view'),
                style: const TextStyle(fontWeight: FontWeight.w500),
                onTap: () => goEntityFullDetail(
                  context,
                  '/transactions',
                  vm.draft.transactionId,
                ),
              ),
            ),
          ),
        EntityEditField(
          label: context.tr('transaction_reference'),
          initial: vm.draft.transactionReference,
          onChanged: vm.setTransactionReference,
          autocorrect: false,
        ),
      ],
    );
  }
}
