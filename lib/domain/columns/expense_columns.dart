import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/expense_dao.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/category_name_label.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/invoice_name_label.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/ui/features/expenses/widgets/expense_status_pill.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';

typedef ExpenseColumn = ColumnDefinition<Expense>;

/// Default visible columns for the Expense list. Mirrors the React admin
/// client's default column registry: status, number, vendor, client, date,
/// amount, public notes.
const List<String> kDefaultExpenseColumns = <String>[
  ExpenseFieldIds.status,
  ExpenseFieldIds.number,
  ExpenseFieldIds.vendorId,
  ExpenseFieldIds.clientId,
  ExpenseFieldIds.date,
  ExpenseFieldIds.amount,
  ExpenseFieldIds.publicNotes,
];

final List<ExpenseColumn> kAllExpenseColumns = <ExpenseColumn>[
  // Display-only column. `calculated_status_id` is a domain getter, not a
  // denormalized Drift column — do not add it to the list screen's
  // `sortOptions` or `ExpenseDao._sortExpression` will throw.
  ExpenseColumn(
    id: ExpenseFieldIds.status,
    labelKey: 'status',
    sortable: false,
    width: 110,
    cellBuilder: (e, _) => ExpenseStatusPill(statusId: e.calculatedStatusId),
    valueBuilder: (e) => e.calculatedStatusId,
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.number,
    labelKey: 'number',
    width: 120,
    cellBuilder: (e, ctx) => cellLink(
      ctx,
      e.number,
      bold: true,
      onTap: () => goEntityFullDetail(ctx, '/expenses', e.id),
    ),
    valueBuilder: (e) => cellNonZeroString(e.number),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.vendorId,
    labelKey: 'vendor',
    width: 180,
    cellBuilder: (e, _) => e.vendorId.isEmpty
        ? cellEmpty()
        : VendorNameLabel(vendorId: e.vendorId, link: true),
    valueBuilder: (e) => cellNonZeroString(e.vendorId),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.clientId,
    labelKey: 'client',
    width: 180,
    cellBuilder: (e, _) => e.clientId.isEmpty
        ? cellEmpty()
        : ClientNameLabel(clientId: e.clientId, link: true),
    valueBuilder: (e) => cellNonZeroString(e.clientId),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.projectId,
    labelKey: 'project',
    width: 160,
    cellBuilder: (e, _) => e.projectId.isEmpty
        ? cellEmpty()
        : ProjectNameLabel(projectId: e.projectId, link: true),
    valueBuilder: (e) => cellNonZeroString(e.projectId),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.categoryId,
    labelKey: 'category',
    width: 160,
    cellBuilder: (e, _) => e.categoryId.isEmpty
        ? cellEmpty()
        : CategoryNameLabel(categoryId: e.categoryId, link: true),
    valueBuilder: (e) => cellNonZeroString(e.categoryId),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.date,
    labelKey: 'date',
    width: 120,
    cellBuilder: (e, ctx) =>
        e.date == null ? cellEmpty() : cellDate(e.date!.toDateTime(), ctx),
    valueBuilder: (e) => e.date?.toIso(),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.paymentDate,
    labelKey: 'payment_date',
    width: 130,
    cellBuilder: (e, ctx) => e.paymentDate == null
        ? cellEmpty()
        : cellDate(e.paymentDate!.toDateTime(), ctx),
    valueBuilder: (e) => e.paymentDate?.toIso(),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.amount,
    labelKey: 'amount',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (e, context) =>
        cellMoney(e.amount, context, currencyId: e.currencyId),
    valueBuilder: (e) => cellMoneyValue(e.amount),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.invoiceId,
    labelKey: 'invoice',
    width: 130,
    cellBuilder: (e, _) => e.invoiceId.isEmpty
        ? cellEmpty()
        : InvoiceNameLabel(invoiceId: e.invoiceId, link: true),
    valueBuilder: (e) => cellNonZeroString(e.invoiceId),
  ),
  // Link to the source bank transaction. Display-only (not a Drift column /
  // sort option) — renders a "View" link, matching the React admin client.
  ExpenseColumn(
    id: ExpenseFieldIds.transactionId,
    labelKey: 'transaction',
    sortable: false,
    width: 110,
    cellBuilder: (e, ctx) => e.transactionId.isEmpty
        ? cellEmpty()
        : cellLink(
            ctx,
            ctx.tr('view'),
            onTap: () =>
                goEntityFullDetail(ctx, '/transactions', e.transactionId),
          ),
    valueBuilder: (e) => cellNonZeroString(e.transactionId),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.currencyId,
    labelKey: 'currency',
    width: 100,
    cellBuilder: (e, ctx) => cellCurrency(ctx, e.currencyId),
    valueBuilder: (e) => cellNonZeroString(e.currencyId),
  ),
  // Display-only columns. `public_notes` / `private_notes` live only in the
  // `payload` JSON — they aren't denormalized Drift columns. Adding them to
  // the list screen's `sortOptions` would make `ExpenseDao._sortExpression`
  // throw. Lift them into `expenses_table.dart` first if sorting is needed.
  ExpenseColumn(
    id: ExpenseFieldIds.publicNotes,
    labelKey: 'public_notes',
    sortable: false,
    width: 240,
    cellBuilder: (e, _) =>
        e.publicNotes.isEmpty ? cellEmpty() : cellText(e.publicNotes),
    valueBuilder: (e) => cellNonZeroString(e.publicNotes),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.privateNotes,
    labelKey: 'private_notes',
    sortable: false,
    width: 240,
    cellBuilder: (e, _) =>
        e.privateNotes.isEmpty ? cellEmpty() : cellText(e.privateNotes),
    valueBuilder: (e) => cellNonZeroString(e.privateNotes),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.updatedAt,
    labelKey: 'last_updated',
    width: 120,
    cellBuilder: (e, ctx) => cellDate(e.updatedAt, ctx),
    valueBuilder: (e) => e.updatedAt.toIso8601String(),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.customValue1,
    labelKey: 'custom_value1',
    width: 140,
    cellBuilder: (e, _) =>
        e.customValue1.isEmpty ? cellEmpty() : cellText(e.customValue1),
    valueBuilder: (e) => cellNonZeroString(e.customValue1),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.customValue2,
    labelKey: 'custom_value2',
    width: 140,
    cellBuilder: (e, _) =>
        e.customValue2.isEmpty ? cellEmpty() : cellText(e.customValue2),
    valueBuilder: (e) => cellNonZeroString(e.customValue2),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.customValue3,
    labelKey: 'custom_value3',
    width: 140,
    cellBuilder: (e, _) =>
        e.customValue3.isEmpty ? cellEmpty() : cellText(e.customValue3),
    valueBuilder: (e) => cellNonZeroString(e.customValue3),
  ),
  ExpenseColumn(
    id: ExpenseFieldIds.customValue4,
    labelKey: 'custom_value4',
    width: 140,
    cellBuilder: (e, _) =>
        e.customValue4.isEmpty ? cellEmpty() : cellText(e.customValue4),
    valueBuilder: (e) => cellNonZeroString(e.customValue4),
  ),
  // Attached tags. Display-only (not a sortable Drift column).
  ExpenseColumn(
    id: ExpenseFieldIds.tagIds,
    labelKey: 'tags',
    sortable: false,
    width: 200,
    cellBuilder: (e, _) => e.tagIds.isEmpty
        ? cellEmpty()
        : EntityTagsView(entityType: 'expense', tagIds: e.tagIds),
    valueBuilder: (e) => '',
  ),
];

final Map<String, ExpenseColumn> expenseColumnsById = {
  for (final c in kAllExpenseColumns) c.id: c,
};
