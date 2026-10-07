import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/record_profile_layout.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_linked_names.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_profile_cards.dart';
import 'package:admin/utils/formatting.dart';

/// An expense's reference fields. Always shown, between the comments card and
/// the tabs.
///
/// In order: Details, Invoicing, Payment, Taxes — the sections of the edit
/// form, so a field is found where it was entered — then Notes. On a wide
/// window the first four share level rows of equal cards; below that they
/// stack. Who was paid, the client and the category are not here: they are
/// the line under the number.
///
/// **A card exists only when it has a row.** Each is built from the list it
/// draws, so there is no second predicate to drift from it — the screen this
/// replaced kept `_hasPaymentInfo`, `_hasAnyTax` and `_hasAnyCustomValue`
/// beside the cards they guarded, and the last of those counted a custom
/// value with no configured label, which the card then did not draw.
///
/// It replaces up to twelve cards under an Overview tab, six of them a whole
/// card holding one linked name.
class ExpenseDetailProfile extends StatelessWidget {
  const ExpenseDetailProfile({
    super.key,
    required this.expense,
    required this.company,
    required this.names,
    this.formatter,
  });

  final Expense expense;

  /// For the custom-field labels. Null while it loads.
  final Company? company;

  /// The records this expense points at — see `ExpenseLinkedNamesBuilder`.
  final ExpenseLinkedNames names;

  /// For amounts and dates. Null (still loading) leaves the dates out.
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    final details = expenseDetailsRows(
      context,
      number: e.number,
      projectId: e.projectId,
      projectName: names.project,
      recurringExpenseId: e.recurringExpenseId,
      recurringExpenseNumber: names.recurringExpense,
      assignedUserId: e.assignedUserId,
      currencyId: e.currencyId,
      customValues: [
        e.customValue1,
        e.customValue2,
        e.customValue3,
        e.customValue4,
      ],
      company: company,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
      formatter: formatter,
    );
    final invoicing = expenseInvoicingRows(
      context,
      invoiceId: e.invoiceId,
      invoiceNumber: names.invoice,
      shouldBeInvoiced: e.shouldBeInvoiced,
      invoiceDocuments: e.invoiceDocuments,
      invoiceCurrencyId: e.invoiceCurrencyId,
      exchangeRate: e.effectiveExchangeRate,
      formatter: formatter,
    );
    final payment = expensePaymentRows(
      context,
      paymentDate: e.paymentDate,
      paymentTypeId: e.paymentTypeId,
      transactionReference: e.transactionReference,
      transactionId: e.transactionId,
      transactionName: names.transaction,
      formatter: formatter,
    );
    final taxes = expenseTaxRows(
      context,
      tiers: [
        (name: e.taxName1, rate: e.taxRate1, amount: e.taxAmount1Computed),
        (name: e.taxName2, rate: e.taxRate2, amount: e.taxAmount2Computed),
        (name: e.taxName3, rate: e.taxRate3, amount: e.taxAmount3Computed),
      ],
      byAmount: e.calculateTaxByAmount,
      inclusive: e.usesInclusiveTaxes,
      money: (amount) =>
          formatter?.money(amount, clientCurrencyId: e.currencyId) ?? '',
    );
    return RecordProfileLayout(
      lead: [
        if (details.isNotEmpty)
          ExpenseRowsCard(title: context.tr('details'), rows: details),
        if (invoicing.isNotEmpty)
          ExpenseRowsCard(title: context.tr('invoicing'), rows: invoicing),
        if (payment.isNotEmpty)
          ExpenseRowsCard(title: context.tr('payment'), rows: payment),
        if (taxes.isNotEmpty)
          ExpenseRowsCard(title: context.tr('taxes'), rows: taxes),
      ],
      tail: [
        if (ExpenseNotesCard.hasContent(
          privateNotes: e.privateNotes,
          publicNotes: e.publicNotes,
        ))
          ExpenseNotesCard(
            privateNotes: e.privateNotes,
            publicNotes: e.publicNotes,
          ),
      ],
    );
  }
}
