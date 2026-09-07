import 'package:flutter/widgets.dart';

import 'package:admin/ui/features/expenses/widgets/edit/expense_tax_section.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_edit_view_model.dart';

/// Amount + tax entry for the Recurring Expense edit screen. Thin wrapper that
/// feeds the shared [ExpenseTaxSection] from the ViewModel (the Expense edit
/// screen feeds the same widget from its own VM).
class RecurringExpenseEditAmountTaxSection extends StatelessWidget {
  const RecurringExpenseEditAmountTaxSection({super.key, required this.vm});
  final RecurringExpenseEditViewModel vm;

  @override
  Widget build(BuildContext context) {
    final d = vm.draft;
    return ExpenseTaxSection(
      companyId: vm.companyId,
      useCommaAsDecimalPlace: vm.useCommaAsDecimalPlace,
      amount: d.amount,
      amountError: vm.fieldErrorFor('amount'),
      taxNames: [d.taxName1, d.taxName2, d.taxName3],
      taxRates: [d.taxRate1, d.taxRate2, d.taxRate3],
      taxAmounts: [d.taxAmount1, d.taxAmount2, d.taxAmount3],
      usesInclusiveTaxes: d.usesInclusiveTaxes,
      calculateTaxByAmount: d.calculateTaxByAmount,
      onAmountChanged: vm.setAmount,
      onTaxNameChanged: (slot, v) =>
          _apply(slot, vm.setTaxName1, vm.setTaxName2, vm.setTaxName3, v),
      onTaxRateChanged: (slot, v) =>
          _apply(slot, vm.setTaxRate1, vm.setTaxRate2, vm.setTaxRate3, v),
      onTaxAmountChanged: (slot, v) =>
          _apply(slot, vm.setTaxAmount1, vm.setTaxAmount2, vm.setTaxAmount3, v),
      onUsesInclusiveTaxesChanged: vm.setUsesInclusiveTaxes,
      onCalculateByAmountChanged: vm.setCalculateTaxByAmount,
    );
  }
}

void _apply(
  int slot,
  ValueChanged<String> s1,
  ValueChanged<String> s2,
  ValueChanged<String> s3,
  String v,
) {
  if (slot == 1) {
    s1(v);
  } else if (slot == 2) {
    s2(v);
  } else {
    s3(v);
  }
}
