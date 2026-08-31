import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/recurring_expense_dao.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_factories.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/category_name_label.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
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

final kAllRecurringExpenseColumns = <RecurringExpenseColumn>[
  // Display-only column. `calculated_status_id` is a domain getter, not a
  // denormalized Drift column — do not add it to the list screen's
  // `sortOptions` or `RecurringExpenseDao._sortExpression` will throw.
  RecurringExpenseColumn(
    id: RecurringExpenseFieldIds.status,
    labelKey: 'status',
    sortable: false,
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
    // `ctx`, not `_`: `kRecurringFrequencyLabelKey` maps to a LOCALIZATION
    // KEY (`'5' -> 'freq_monthly'`), so a cell builder that discards its
    // context painted `freq_monthly` straight into the column. Every
    // sibling gets this right (`recurring_invoice_columns.dart`).
    cellBuilder: (e, ctx) {
      final key = kRecurringFrequencyLabelKey[e.frequencyId];
      return cellText(key == null ? e.frequencyId : ctx.tr(key));
    },
    // `valueBuilder` feeds `CellCopyHover`, and it has no `BuildContext`,
    // so it cannot translate. Emit the raw id rather than the key — the
    // convention `recurring_invoice_columns.dart` already follows. (Neither
    // entity copies the *translated* label; that would need a context on
    // the valueBuilder contract, which is a change across every column
    // file.)
    valueBuilder: (e) => cellNonZeroString(e.frequencyId),
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
    // `endless` is a bundled Transifex key, not a display string — the
    // bare literal rendered lowercase and stayed English everywhere.
    cellBuilder: (e, ctx) => cellText(
      e.remainingCycles == -1 ? ctx.tr('endless') : '${e.remainingCycles}',
    ),
    // Raw value, not the `endless` localization key — see the frequency
    // column above.
    valueBuilder: (e) => '${e.remainingCycles}',
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
    sortable: false,
    width: 240,
    cellBuilder: (e, _) =>
        e.publicNotes.isEmpty ? cellEmpty() : cellText(e.publicNotes),
    valueBuilder: (e) => cellNonZeroString(e.publicNotes),
  ),
  RecurringExpenseColumn(
    id: RecurringExpenseFieldIds.privateNotes,
    labelKey: 'private_notes',
    sortable: false,
    width: 240,
    cellBuilder: (e, _) =>
        e.privateNotes.isEmpty ? cellEmpty() : cellText(e.privateNotes),
    valueBuilder: (e) => cellNonZeroString(e.privateNotes),
  ),
  colUpdatedAt<RecurringExpense>(
    RecurringExpenseFieldIds.updatedAt,
    (e) => e.updatedAt,
  ),
  // The company's own labels ('Region'), type-aware values and the
  // hiding of unconfigured slots are applied by
  // `decorateCustomFieldColumns` — see `custom_field_columns.dart`.
  ...customFieldColumns<RecurringExpense>(
    prefix: 'expense',
    ids: const [
      RecurringExpenseFieldIds.customValue1,
      RecurringExpenseFieldIds.customValue2,
      RecurringExpenseFieldIds.customValue3,
      RecurringExpenseFieldIds.customValue4,
    ],
    values: [
      (e) => e.customValue1,
      (e) => e.customValue2,
      (e) => e.customValue3,
      (e) => e.customValue4,
    ],
  ),
  // ── Standard record metadata ──────────────────────────────────────────
  // Shared across every entity list; see `column_factories.dart`. Created /
  // archived / deleted are real Drift columns and sort; state, documents and
  // the two user columns are derived or payload-only and don't.
  colUserName<RecurringExpense>(
    RecurringExpenseFieldIds.assignedUserId,
    (e) => e.assignedUserId,
    labelKey: 'assigned_user',
    sortable: false,
  ),
  colCreatedAt<RecurringExpense>(
    RecurringExpenseFieldIds.createdAt,
    (e) => e.createdAt,
  ),
  colArchivedAt<RecurringExpense>(
    RecurringExpenseFieldIds.archivedAt,
    (e) => e.archivedAt,
  ),
  colEntityState<RecurringExpense>(
    RecurringExpenseFieldIds.entityState,
    archivedAt: (e) => e.archivedAt,
    isDeleted: (e) => e.isDeleted,
  ),
  colFlag<RecurringExpense>(
    RecurringExpenseFieldIds.isDeleted,
    (e) => e.isDeleted,
    labelKey: 'is_deleted',
  ),
  colDocumentsCount<RecurringExpense>(
    RecurringExpenseFieldIds.documents,
    (e) => e.documents.length,
  ),
  // Created by. `labelKey: 'user'` — NOT `created_by`, which is
  // "Created by :name" and would leak the raw placeholder.
  colUserName<RecurringExpense>(
    RecurringExpenseFieldIds.userId,
    (e) => e.userId,
    labelKey: 'user',
  ),
  // Attached tags. Display-only (not a sortable Drift column).
  RecurringExpenseColumn(
    id: RecurringExpenseFieldIds.tagIds,
    labelKey: 'tags',
    sortable: false,
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
