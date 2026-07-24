import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/recurring_expense_dao.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/ui/core/widgets/category_name_label.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/invoice_name_label.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_status_pill.dart';

typedef RecurringExpenseColumn = ColumnDefinition<RecurringExpense>;

/// Default visible columns for the Recurring Expenses list. UX-spec
/// preference: status + identity + cadence info up front (frequency +
/// next send date + remaining cycles) ahead of money and notes.
const List<String> kDefaultRecurringExpenseColumns = <String>[
  RecurringExpenseFieldIds.status,
  RecurringExpenseFieldIds.number,
  RecurringExpenseFieldIds.vendorId,
  RecurringExpenseFieldIds.clientId,
  RecurringExpenseFieldIds.date,
  RecurringExpenseFieldIds.frequency,
  RecurringExpenseFieldIds.nextSendDate,
  RecurringExpenseFieldIds.remainingCycles,
  RecurringExpenseFieldIds.amount,
  RecurringExpenseFieldIds.publicNotes,
];

final List<RecurringExpenseColumn> kAllRecurringExpenseColumns =
    <RecurringExpenseColumn>[
      // Display-only column. `calculated_status_id` is a domain getter, not a
      // denormalized Drift column — do not add it to the list screen's
      // `sortOptions` or `RecurringExpenseDao._sortExpression` will throw.
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.status,
        labelKey: 'status',
        width: 110,
        cellBuilder: (e, _) =>
            RecurringExpenseStatusPill(statusId: e.calculatedStatusId),
        valueBuilder: (e) => e.calculatedStatusId,
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.number,
        labelKey: 'number',
        width: 120,
        cellBuilder: (e, ctx) => cellLink(
          ctx,
          e.number,
          bold: true,
          onTap: () => goEntityFullDetail(ctx, '/recurring_expenses', e.id),
        ),
        valueBuilder: (e) => cellNonZeroString(e.number),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.vendorId,
        labelKey: 'vendor',
        width: 180,
        cellBuilder: (e, _) => e.vendorId.isEmpty
            ? cellEmpty()
            : VendorNameLabel(vendorId: e.vendorId, link: true),
        valueBuilder: (e) => cellNonZeroString(e.vendorId),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.clientId,
        labelKey: 'client',
        width: 180,
        cellBuilder: (e, _) => e.clientId.isEmpty
            ? cellEmpty()
            : ClientNameLabel(clientId: e.clientId, link: true),
        valueBuilder: (e) => cellNonZeroString(e.clientId),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.projectId,
        labelKey: 'project',
        width: 160,
        cellBuilder: (e, _) => e.projectId.isEmpty
            ? cellEmpty()
            : ProjectNameLabel(projectId: e.projectId, link: true),
        valueBuilder: (e) => cellNonZeroString(e.projectId),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.categoryId,
        labelKey: 'category',
        width: 160,
        cellBuilder: (e, _) => e.categoryId.isEmpty
            ? cellEmpty()
            : CategoryNameLabel(categoryId: e.categoryId, link: true),
        valueBuilder: (e) => cellNonZeroString(e.categoryId),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.date,
        labelKey: 'date',
        width: 120,
        cellBuilder: (e, ctx) =>
            e.date == null ? cellEmpty() : cellDate(e.date!.toDateTime(), ctx),
        valueBuilder: (e) => e.date?.toIso(),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.frequency,
        labelKey: 'frequency',
        width: 140,
        cellBuilder: (e, _) {
          final key = kRecurringFrequencyLabelKey[e.frequencyId];
          return cellText(key ?? e.frequencyId);
        },
        valueBuilder: (e) => kRecurringFrequencyLabelKey[e.frequencyId],
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.nextSendDate,
        labelKey: 'next_send_date',
        width: 130,
        cellBuilder: (e, ctx) => e.nextSendDate == null
            ? cellEmpty()
            : cellDate(e.nextSendDate!.toDateTime(), ctx),
        valueBuilder: (e) => e.nextSendDate?.toIso(),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.lastSentDate,
        labelKey: 'last_sent_date',
        width: 130,
        cellBuilder: (e, ctx) => e.lastSentDate == null
            ? cellEmpty()
            : cellDate(e.lastSentDate!.toDateTime(), ctx),
        valueBuilder: (e) => e.lastSentDate?.toIso(),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.remainingCycles,
        labelKey: 'remaining_cycles',
        width: 110,
        align: ColumnAlign.end,
        cellBuilder: (e, _) => cellText(
          e.remainingCycles == -1 ? 'endless' : '${e.remainingCycles}',
        ),
        valueBuilder: (e) =>
            e.remainingCycles == -1 ? 'endless' : '${e.remainingCycles}',
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.amount,
        labelKey: 'amount',
        width: 130,
        align: ColumnAlign.end,
        cellBuilder: (e, context) =>
            cellMoney(e.amount, context, currencyId: e.currencyId),
        valueBuilder: (e) => cellMoneyValue(e.amount),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.invoiceId,
        labelKey: 'invoice',
        width: 130,
        cellBuilder: (e, _) => e.invoiceId.isEmpty
            ? cellEmpty()
            : InvoiceNameLabel(invoiceId: e.invoiceId, link: true),
        valueBuilder: (e) => cellNonZeroString(e.invoiceId),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.currencyId,
        labelKey: 'currency',
        width: 100,
        cellBuilder: (e, ctx) => cellCurrency(ctx, e.currencyId),
        valueBuilder: (e) => cellNonZeroString(e.currencyId),
      ),
      // Display-only columns. `public_notes` / `private_notes` live only in the
      // `payload` JSON — they aren't denormalized Drift columns. Adding them to
      // the list screen's `sortOptions` would make
      // `RecurringExpenseDao._sortExpression` throw.
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.publicNotes,
        labelKey: 'public_notes',
        width: 240,
        cellBuilder: (e, _) =>
            e.publicNotes.isEmpty ? cellEmpty() : cellText(e.publicNotes),
        valueBuilder: (e) => cellNonZeroString(e.publicNotes),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.privateNotes,
        labelKey: 'private_notes',
        width: 240,
        cellBuilder: (e, _) =>
            e.privateNotes.isEmpty ? cellEmpty() : cellText(e.privateNotes),
        valueBuilder: (e) => cellNonZeroString(e.privateNotes),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.updatedAt,
        labelKey: 'last_updated',
        width: 120,
        cellBuilder: (e, ctx) => cellDate(e.updatedAt, ctx),
        valueBuilder: (e) => e.updatedAt.toIso8601String(),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.customValue1,
        labelKey: 'custom_value1',
        width: 140,
        cellBuilder: (e, _) =>
            e.customValue1.isEmpty ? cellEmpty() : cellText(e.customValue1),
        valueBuilder: (e) => cellNonZeroString(e.customValue1),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.customValue2,
        labelKey: 'custom_value2',
        width: 140,
        cellBuilder: (e, _) =>
            e.customValue2.isEmpty ? cellEmpty() : cellText(e.customValue2),
        valueBuilder: (e) => cellNonZeroString(e.customValue2),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.customValue3,
        labelKey: 'custom_value3',
        width: 140,
        cellBuilder: (e, _) =>
            e.customValue3.isEmpty ? cellEmpty() : cellText(e.customValue3),
        valueBuilder: (e) => cellNonZeroString(e.customValue3),
      ),
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.customValue4,
        labelKey: 'custom_value4',
        width: 140,
        cellBuilder: (e, _) =>
            e.customValue4.isEmpty ? cellEmpty() : cellText(e.customValue4),
        valueBuilder: (e) => cellNonZeroString(e.customValue4),
      ),
      // Attached tags. Display-only (not a sortable Drift column).
      RecurringExpenseColumn(
        id: RecurringExpenseFieldIds.tagIds,
        labelKey: 'tags',
        width: 200,
        cellBuilder: (e, _) => e.tagIds.isEmpty
            ? cellEmpty()
            : EntityTagsView(entityType: 'recurring_expense', tagIds: e.tagIds),
        valueBuilder: (e) => '',
      ),
    ];

final Map<String, RecurringExpenseColumn> recurringExpenseColumnsById = {
  for (final c in kAllRecurringExpenseColumns) c.id: c,
};
