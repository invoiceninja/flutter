import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/data/db/dao/bank_transaction_dao.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/widgets/bank_account_name_label.dart';
import 'package:admin/ui/core/widgets/expense_name_label.dart';
import 'package:admin/ui/core/widgets/invoice_name_label.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_status_pill.dart';

typedef BankTransactionColumn = ColumnDefinition<BankTransaction>;

/// Column id constants. Most map 1:1 to `BankTransactionFieldIds`; the
/// `deposit` / `withdrawal` ids are display-only splits of `amount` driven
/// by `baseType`. They aren't sortable on their own — sort by `amount` to
/// order both columns numerically.
class BankTransactionColumnIds {
  static const String status = BankTransactionFieldIds.statusId;
  static const String deposit = 'deposit';
  static const String withdrawal = 'withdrawal';
  static const String date = BankTransactionFieldIds.date;
  static const String participantName = BankTransactionFieldIds.participantName;
  static const String description = BankTransactionFieldIds.description;
  static const String bankAccountId = 'bank_account_id';
  static const String invoices = 'invoices';
  static const String expenses = 'expenses';
  static const String currencyId = 'currency_id';
  static const String amount = BankTransactionFieldIds.amount;
  static const String updatedAt = BankTransactionFieldIds.updatedAt;
}

/// Default visible columns. Status pill leads, deposit + withdrawal split by
/// `baseType` so the two amount columns line up for an at-a-glance ledger
/// view, then date / description / linked-entity chips.
const List<String> kDefaultBankTransactionColumns = <String>[
  BankTransactionColumnIds.status,
  BankTransactionColumnIds.deposit,
  BankTransactionColumnIds.withdrawal,
  BankTransactionColumnIds.date,
  BankTransactionColumnIds.description,
  BankTransactionColumnIds.invoices,
  BankTransactionColumnIds.expenses,
];

/// Render a list of linked entity ids as resolved #number label(s): the first
/// via [label], plus a compact "+N" when a transaction matched several.
Widget _linkedNumbers(List<String> ids, Widget Function(String id) label) {
  if (ids.isEmpty) return cellEmpty();
  if (ids.length == 1) return label(ids.first);
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: label(ids.first)),
      Text(
        ' +${ids.length - 1}',
        maxLines: 1,
        style: const TextStyle(fontSize: 13),
      ),
    ],
  );
}

final List<BankTransactionColumn> kAllBankTransactionColumns =
    <BankTransactionColumn>[
      // Wide-mode column renders the colored TransactionStatusPill (dot +
      // localized label) so the visual vocabulary matches the narrow row
      // tile and the detail-screen header. `valueBuilder` still exposes the
      // raw `status_id` for clipboard copy + sort.
      BankTransactionColumn(
        id: BankTransactionColumnIds.status,
        labelKey: 'status',
        width: 130,
        cellBuilder: (t, _) => TransactionStatusPill(statusId: t.statusId),
        valueBuilder: (t) => t.statusId,
      ),
      // Deposits column — only populated for CREDIT rows (per the React UX).
      // Sort by `amount`, not `deposit` (the column id is display-only).
      BankTransactionColumn(
        id: BankTransactionColumnIds.deposit,
        labelKey: 'deposit',
        width: 130,
        align: ColumnAlign.end,
        cellBuilder: (t, context) => t.isDeposit
            ? cellMoney(t.amount, context, currencyId: t.currencyId)
            : cellEmpty(),
        valueBuilder: (t) => t.isDeposit ? cellMoneyValue(t.amount) : null,
      ),
      BankTransactionColumn(
        id: BankTransactionColumnIds.withdrawal,
        labelKey: 'withdrawal',
        width: 130,
        align: ColumnAlign.end,
        cellBuilder: (t, context) => t.isWithdrawal
            ? cellMoney(t.amount, context, currencyId: t.currencyId)
            : cellEmpty(),
        valueBuilder: (t) => t.isWithdrawal ? cellMoneyValue(t.amount) : null,
      ),
      BankTransactionColumn(
        id: BankTransactionColumnIds.amount,
        labelKey: 'amount',
        width: 130,
        align: ColumnAlign.end,
        cellBuilder: (t, context) =>
            cellMoney(t.amount, context, currencyId: t.currencyId),
        valueBuilder: (t) => cellMoneyValue(t.amount),
      ),
      BankTransactionColumn(
        id: BankTransactionColumnIds.date,
        labelKey: 'date',
        width: 120,
        cellBuilder: (t, ctx) =>
            t.date == null ? cellEmpty() : cellDate(t.date!.toDateTime(), ctx),
        valueBuilder: (t) => t.date?.toIso(),
      ),
      BankTransactionColumn(
        id: BankTransactionColumnIds.participantName,
        labelKey: 'participant_name',
        width: 200,
        cellBuilder: (t, _) => t.participantName.isEmpty
            ? cellEmpty()
            : cellText(t.participantName),
        valueBuilder: (t) => cellNonZeroString(t.participantName),
      ),
      BankTransactionColumn(
        id: BankTransactionColumnIds.description,
        labelKey: 'description',
        width: 240,
        cellBuilder: (t, _) =>
            t.description.isEmpty ? cellEmpty() : cellText(t.description),
        valueBuilder: (t) => cellNonZeroString(t.description),
      ),
      BankTransactionColumn(
        id: BankTransactionColumnIds.bankAccountId,
        labelKey: 'bank_account',
        width: 180,
        cellBuilder: (t, _) => t.bankAccountId.isEmpty
            ? cellEmpty()
            : BankAccountNameLabel(bankAccountId: t.bankAccountId, link: true),
        valueBuilder: (t) => cellNonZeroString(t.bankAccountId),
      ),
      BankTransactionColumn(
        id: BankTransactionColumnIds.invoices,
        labelKey: 'invoices',
        width: 160,
        // Resolve the hashed invoice ids to their #numbers (never render raw
        // ids); a transaction usually matches one invoice, so show the first
        // resolved number and a "+N" count for the rare multi-match.
        cellBuilder: (t, _) => _linkedNumbers(
          t.linkedInvoiceIds,
          (id) => InvoiceNameLabel(invoiceId: id, link: true),
        ),
        valueBuilder: (t) => cellNonZeroString(t.invoiceIds),
      ),
      BankTransactionColumn(
        id: BankTransactionColumnIds.expenses,
        labelKey: 'expense',
        width: 160,
        cellBuilder: (t, _) => _linkedNumbers(
          t.linkedExpenseIds,
          (id) => ExpenseNameLabel(expenseId: id, link: true),
        ),
        valueBuilder: (t) => cellNonZeroString(t.expenseId),
      ),
      BankTransactionColumn(
        id: BankTransactionColumnIds.currencyId,
        labelKey: 'currency',
        width: 100,
        cellBuilder: (t, ctx) => cellCurrency(ctx, t.currencyId),
        valueBuilder: (t) => cellNonZeroString(t.currencyId),
      ),
      BankTransactionColumn(
        id: BankTransactionColumnIds.updatedAt,
        labelKey: 'last_updated',
        width: 120,
        cellBuilder: (t, ctx) => cellDate(t.updatedAt, ctx),
        valueBuilder: (t) => t.updatedAt.toIso8601String(),
      ),
    ];

final Map<String, BankTransactionColumn> bankTransactionColumnsById = {
  for (final c in kAllBankTransactionColumns) c.id: c,
};

/// Sum of [amount] across [items] — used by the match panel's "calculate
/// total" affordance and by the multi-pick sheet's running summary.
Decimal sumTransactionAmounts(Iterable<BankTransaction> items) {
  var total = Decimal.zero;
  for (final t in items) {
    total += t.amount;
  }
  return total;
}
