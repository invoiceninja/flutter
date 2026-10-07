import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/record_profile_layout.dart';
import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_linked_names.dart';
import 'package:admin/ui/features/expenses/widgets/detail/expense_profile_cards.dart';
import 'package:admin/utils/formatting.dart';

/// A recurring expense's reference fields — the recurring twin of
/// `ExpenseDetailProfile`, built from the same rows
/// (`expense_profile_cards.dart`), so a field reads the same on the schedule
/// as on the expenses it makes.
///
/// In order: Details, Invoicing, Payment, Taxes, then Notes. There is no
/// Schedule card: how often is in the line under the number, when next and
/// how many are left are on the standing card, when it last ran is a Details
/// row, and the dates to come are the Schedule tab. The card this replaces
/// fetched those dates on every open to print three of them.
///
/// **A card exists only when it has a row** — each is built from the list it
/// draws.
class RecurringExpenseDetailProfile extends StatelessWidget {
  const RecurringExpenseDetailProfile({
    super.key,
    required this.recurringExpense,
    required this.company,
    required this.names,
    this.formatter,
  });

  final RecurringExpense recurringExpense;

  /// For the custom-field labels. Null while it loads.
  final Company? company;

  /// The records this one points at — see `ExpenseLinkedNamesBuilder`.
  final ExpenseLinkedNames names;

  /// For amounts and dates. Null (still loading) leaves the dates out.
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final e = recurringExpense;
    final f = formatter;
    final lastSent = e.lastSentDate;
    final details = expenseDetailsRows(
      context,
      number: e.number,
      projectId: e.projectId,
      projectName: names.project,
      assignedUserId: e.assignedUserId,
      currencyId: e.currencyId,
      scheduleRows: [
        // Never the raw ISO date: it waits for the company's format.
        if (lastSent != null && f != null)
          DetailInfoRow(
            label: context.tr('last_sent_date'),
            value: f.date(lastSent.toIso()),
            copyable: false,
          ),
      ],
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
    // A schedule is never itself on an invoice; these describe what happens
    // to each expense it makes.
    final invoicing = expenseInvoicingRows(
      context,
      invoiceId: '',
      invoiceNumber: '',
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
      transactionId: '',
      transactionName: '',
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
