import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/recurring_invoice_dao.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_factories.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/domain/recurring_frequency.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/design_name_label.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_status_pill.dart';

typedef RecurringInvoiceColumn = ColumnDefinition<RecurringInvoice>;

const List<String> kDefaultRecurringInvoiceColumns = <String>[
  RecurringInvoiceFieldIds.status,
  RecurringInvoiceFieldIds.number,
  RecurringInvoiceFieldIds.clientId,
  RecurringInvoiceFieldIds.amount,
  RecurringInvoiceFieldIds.nextSendDate,
];

final kAllRecurringInvoiceColumns = <RecurringInvoiceColumn>[
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.status,
    labelKey: 'status',
    width: 110,
    cellBuilder: (r, _) => RecurringInvoiceStatusPill(
      statusId: r.calculatedStatusId,
      hasBounce: r.hasBouncedInvitation,
    ),
    valueBuilder: (r) => r.calculatedStatusId,
  ),
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.number,
    labelKey: 'number',
    width: 130,
    cellBuilder: (r, ctx) => cellLink(
      ctx,
      r.number,
      bold: true,
      onTap: () => goEntityFullDetail(ctx, '/recurring_invoices', r.id),
    ),
    valueBuilder: (r) => cellNonZeroString(r.number),
  ),
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.clientId,
    labelKey: 'client',
    width: 200,
    cellBuilder: (r, _) => r.clientId.isEmpty
        ? cellEmpty()
        : ClientNameLabel(clientId: r.clientId, link: true),
    valueBuilder: (r) => cellNonZeroString(r.clientId),
  ),
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.amount,
    labelKey: 'amount',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (r, context) =>
        cellPartyMoney(r.amount, context, clientId: r.clientId),
    valueBuilder: (r) => cellMoneyValue(r.amount),
  ),
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.balance,
    labelKey: 'balance',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (r, context) =>
        cellPartyMoney(r.balance, context, clientId: r.clientId),
    valueBuilder: (r) => cellMoneyValue(r.balance),
  ),
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.nextSendDate,
    labelKey: 'next_send_date',
    width: 130,
    cellBuilder: (r, ctx) => r.nextSendDate == null
        ? cellEmpty()
        : cellDate(r.nextSendDate!.toDateTime(), ctx),
    valueBuilder: (r) => r.nextSendDate?.toIso(),
  ),
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.frequencyId,
    labelKey: 'frequency',
    width: 110,
    cellBuilder: (r, ctx) => r.frequencyId.isEmpty
        ? cellEmpty()
        : cellText(
            ctx.tr(kRecurringFrequencyLabelKey[r.frequencyId] ?? r.frequencyId),
          ),
    valueBuilder: (r) => cellNonZeroString(r.frequencyId),
  ),
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.remainingCycles,
    labelKey: 'remaining_cycles',
    width: 110,
    align: ColumnAlign.end,
    cellBuilder: (r, _) => cellText('${r.remainingCycles}'),
    valueBuilder: (r) => '${r.remainingCycles}',
  ),
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.poNumber,
    labelKey: 'po_number',
    width: 130,
    cellBuilder: (r, _) =>
        r.poNumber.isEmpty ? cellEmpty() : cellText(r.poNumber),
    valueBuilder: (r) => cellNonZeroString(r.poNumber),
  ),
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.designId,
    labelKey: 'design',
    width: 130,
    cellBuilder: (r, _) => r.designId.isEmpty
        ? cellEmpty()
        : DesignNameLabel(designId: r.designId),
    valueBuilder: (r) => cellNonZeroString(r.designId),
  ),
  colUpdatedAt<RecurringInvoice>(
    RecurringInvoiceFieldIds.updatedAt,
    (r) => r.updatedAt,
  ),
  // Project this document belongs to.
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.projectId,
    labelKey: 'project',
    width: 160,
    cellBuilder: (r, _) => r.projectId.isEmpty
        ? cellEmpty()
        : ProjectNameLabel(projectId: r.projectId, link: true),
    valueBuilder: (r) => cellNonZeroString(r.projectId),
  ),
  // Billing docs can carry a vendor as well as a client. The id, the Drift
  // column and the DAO sort case all already existed — only the column was
  // missing. React and the legacy app both offer it.
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.vendorId,
    labelKey: 'vendor',
    width: 160,
    cellBuilder: (r, _) => r.vendorId.isEmpty
        ? cellEmpty()
        : VendorNameLabel(vendorId: r.vendorId, link: true),
    valueBuilder: (r) => cellNonZeroString(r.vendorId),
  ),
  // Payload-only on this table, so display-only — lift the field into
  // the Drift table first if it ever needs to sort.
  colNotes<RecurringInvoice>(
    RecurringInvoiceFieldIds.publicNotes,
    (r) => r.publicNotes,
    labelKey: 'public_notes',
  ),
  colNotes<RecurringInvoice>(
    RecurringInvoiceFieldIds.privateNotes,
    (r) => r.privateNotes,
    labelKey: 'private_notes',
  ),
  // Quotes, credits, purchase orders and recurring invoices all read the
  // company's `invoice1..4` slots — there are no per-type definitions.
  // The configured labels, type-aware values and the hiding of
  // unconfigured slots come from `decorateCustomFieldColumns`.
  ...customFieldColumns<RecurringInvoice>(
    prefix: 'invoice',
    ids: const [
      'custom_value1',
      'custom_value2',
      'custom_value3',
      'custom_value4',
    ],
    values: [
      (r) => r.customValue1,
      (r) => r.customValue2,
      (r) => r.customValue3,
      (r) => r.customValue4,
    ],
  ),
  // ── Standard record metadata ──────────────────────────────────────────
  // Shared across every entity list; see `column_factories.dart`. Created /
  // archived / deleted are real Drift columns and sort; state, documents and
  // the two user columns are derived or payload-only and don't.
  colUserName<RecurringInvoice>(
    RecurringInvoiceFieldIds.assignedUserId,
    (r) => r.assignedUserId,
    labelKey: 'assigned_user',
    sortable: true,
  ),
  colCreatedAt<RecurringInvoice>(
    RecurringInvoiceFieldIds.createdAt,
    (r) => r.createdAt,
  ),
  colArchivedAt<RecurringInvoice>(
    RecurringInvoiceFieldIds.archivedAt,
    (r) => r.archivedAt,
  ),
  colEntityState<RecurringInvoice>(
    RecurringInvoiceFieldIds.entityState,
    archivedAt: (r) => r.archivedAt,
    isDeleted: (r) => r.isDeleted,
  ),
  colFlag<RecurringInvoice>(
    RecurringInvoiceFieldIds.isDeleted,
    (r) => r.isDeleted,
    labelKey: 'is_deleted',
  ),
  colDocumentsCount<RecurringInvoice>(
    RecurringInvoiceFieldIds.documents,
    (r) => r.documents.length,
  ),
  // Created by. `labelKey: 'user'` — NOT `created_by`, which is
  // "Created by :name" and would leak the raw placeholder.
  colUserName<RecurringInvoice>(
    RecurringInvoiceFieldIds.userId,
    (r) => r.userId,
    labelKey: 'user',
  ),
  // Attached tags. Display-only (not a sortable Drift column).
  RecurringInvoiceColumn(
    id: RecurringInvoiceFieldIds.tagIds,
    labelKey: 'tags',
    sortable: false,
    width: 200,
    cellBuilder: (r, _) => r.tagIds.isEmpty
        ? cellEmpty()
        : EntityTagsView(entityType: 'recurring_invoice', tagIds: r.tagIds),
    valueBuilder: (r) => '',
  ),
];

final Map<String, RecurringInvoiceColumn> recurringInvoiceColumnsById = {
  for (final c in kAllRecurringInvoiceColumns) c.id: c,
};
