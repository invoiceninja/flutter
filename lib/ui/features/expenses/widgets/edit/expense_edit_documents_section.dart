import 'package:flutter/material.dart';

import 'package:admin/ui/core/edit/create_form_documents.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';

/// New Expense's Documents card: the shared create-form card
/// ([CreateFormDocumentsCard], docs/attaching-documents.md) plus a Read
/// receipt button on each file (docs/receipt-ocr.md) — offered while the form
/// can read one, the file hasn't been read, and nothing else is being read; a
/// spinner while this one is.
class ExpenseEditDocumentsSection extends StatelessWidget {
  const ExpenseEditDocumentsSection({super.key, required this.vm});

  final ExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) => CreateFormDocumentsCard(
    vm: vm,
    receipt: (
      reading: vm.readingReceipt,
      onReadFor: (source) =>
          vm.canReadReceipt &&
              !vm.isReadingReceipt &&
              !vm.receiptWasRead(source)
          ? () => vm.readReceipt(source)
          : null,
    ),
  );
}
