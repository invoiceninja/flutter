import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/quote_dao.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_factories.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/design_name_label.dart';
import 'package:admin/ui/core/widgets/invoice_name_label.dart';
import 'package:admin/ui/core/widgets/user_name_label.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/ui/features/quotes/widgets/quote_status_pill.dart';

typedef QuoteColumn = ColumnDefinition<Quote>;

const List<String> kDefaultQuoteColumns = <String>[
  QuoteFieldIds.status,
  QuoteFieldIds.number,
  QuoteFieldIds.clientId,
  QuoteFieldIds.amount,
  QuoteFieldIds.date,
  QuoteFieldIds.dueDate,
];

final List<QuoteColumn> kAllQuoteColumns = <QuoteColumn>[
  QuoteColumn(
    id: QuoteFieldIds.status,
    labelKey: 'status',
    width: 110,
    cellBuilder: (q, _) => QuoteStatusPill(
      statusId: q.calculatedStatusId,
      hasBounce: q.hasBouncedInvitation,
    ),
    valueBuilder: (q) => q.calculatedStatusId,
  ),
  QuoteColumn(
    id: QuoteFieldIds.number,
    labelKey: 'number',
    width: 130,
    cellBuilder: (q, ctx) => cellLink(
      ctx,
      q.number,
      bold: true,
      onTap: () => goEntityFullDetail(ctx, '/quotes', q.id),
    ),
    valueBuilder: (q) => cellNonZeroString(q.number),
  ),
  QuoteColumn(
    id: QuoteFieldIds.clientId,
    labelKey: 'client',
    width: 200,
    cellBuilder: (q, _) => q.clientId.isEmpty
        ? cellEmpty()
        : ClientNameLabel(clientId: q.clientId, link: true),
    valueBuilder: (q) => cellNonZeroString(q.clientId),
  ),
  QuoteColumn(
    id: QuoteFieldIds.date,
    labelKey: 'quote_date',
    width: 120,
    cellBuilder: (q, ctx) =>
        q.date == null ? cellEmpty() : cellDate(q.date!.toDateTime(), ctx),
    valueBuilder: (q) => q.date?.toIso(),
  ),
  QuoteColumn(
    id: QuoteFieldIds.dueDate,
    labelKey: 'valid_until',
    width: 120,
    cellBuilder: (q, ctx) => q.dueDate == null
        ? cellEmpty()
        : cellDate(q.dueDate!.toDateTime(), ctx),
    valueBuilder: (q) => q.dueDate?.toIso(),
  ),
  QuoteColumn(
    id: QuoteFieldIds.amount,
    labelKey: 'amount',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (q, context) =>
        cellPartyMoney(q.amount, context, clientId: q.clientId),
    valueBuilder: (q) => cellMoneyValue(q.amount),
  ),
  QuoteColumn(
    id: QuoteFieldIds.poNumber,
    labelKey: 'po_number',
    width: 130,
    cellBuilder: (q, _) =>
        q.poNumber.isEmpty ? cellEmpty() : cellText(q.poNumber),
    valueBuilder: (q) => cellNonZeroString(q.poNumber),
  ),
  QuoteColumn(
    id: QuoteFieldIds.designId,
    labelKey: 'design',
    width: 130,
    cellBuilder: (q, _) => q.designId.isEmpty
        ? cellEmpty()
        : DesignNameLabel(designId: q.designId),
    valueBuilder: (q) => cellNonZeroString(q.designId),
  ),
  QuoteColumn(
    id: QuoteFieldIds.projectId,
    labelKey: 'project',
    width: 160,
    cellBuilder: (q, _) => q.projectId.isEmpty
        ? cellEmpty()
        : ProjectNameLabel(projectId: q.projectId, link: true),
    valueBuilder: (q) => cellNonZeroString(q.projectId),
  ),
  QuoteColumn(
    id: QuoteFieldIds.assignedUserId,
    labelKey: 'assigned_user',
    width: 160,
    cellBuilder: (q, _) => q.assignedUserId.isEmpty
        ? cellEmpty()
        : UserNameLabel(userId: q.assignedUserId),
    valueBuilder: (q) => cellNonZeroString(q.assignedUserId),
  ),
  QuoteColumn(
    id: QuoteFieldIds.invoiceId,
    labelKey: 'invoice',
    width: 130,
    cellBuilder: (q, _) => q.invoiceId.isEmpty
        ? cellEmpty()
        : InvoiceNameLabel(invoiceId: q.invoiceId, link: true),
    valueBuilder: (q) => cellNonZeroString(q.invoiceId),
  ),
  QuoteColumn(
    id: QuoteFieldIds.publicNotes,
    labelKey: 'public_notes',
    sortable: false,
    width: 240,
    cellBuilder: (q, _) =>
        q.publicNotes.isEmpty ? cellEmpty() : cellText(q.publicNotes),
    valueBuilder: (q) => cellNonZeroString(q.publicNotes),
  ),
  colUpdatedAt<Quote>(QuoteFieldIds.updatedAt, (q) => q.updatedAt),
  // Billing docs can carry a vendor as well as a client. The id, the Drift
  // column and the DAO sort case all already existed — only the column was
  // missing. React and the legacy app both offer it.
  QuoteColumn(
    id: QuoteFieldIds.vendorId,
    labelKey: 'vendor',
    width: 160,
    cellBuilder: (q, _) => q.vendorId.isEmpty
        ? cellEmpty()
        : VendorNameLabel(vendorId: q.vendorId, link: true),
    valueBuilder: (q) => cellNonZeroString(q.vendorId),
  ),
  // Payload-only on this table, so display-only — lift the field into
  // the Drift table first if it ever needs to sort.
  colNotes<Quote>(
    QuoteFieldIds.privateNotes,
    (q) => q.privateNotes,
    labelKey: 'private_notes',
  ),
  // Quotes, credits, purchase orders and recurring invoices all read the
  // company's `invoice1..4` slots — there are no per-type definitions.
  // The configured labels, type-aware values and the hiding of
  // unconfigured slots come from `decorateCustomFieldColumns`.
  ...customFieldColumns<Quote>(
    prefix: 'invoice',
    ids: const [
      'custom_value1',
      'custom_value2',
      'custom_value3',
      'custom_value4',
    ],
    values: [
      (q) => q.customValue1,
      (q) => q.customValue2,
      (q) => q.customValue3,
      (q) => q.customValue4,
    ],
  ),
  // ── Standard record metadata ──────────────────────────────────────────
  // Shared across every entity list; see `column_factories.dart`. Created /
  // archived / deleted are real Drift columns and sort; state, documents and
  // the two user columns are derived or payload-only and don't.
  colCreatedAt<Quote>(QuoteFieldIds.createdAt, (q) => q.createdAt),
  colArchivedAt<Quote>(QuoteFieldIds.archivedAt, (q) => q.archivedAt),
  colEntityState<Quote>(
    QuoteFieldIds.entityState,
    archivedAt: (q) => q.archivedAt,
    isDeleted: (q) => q.isDeleted,
  ),
  colFlag<Quote>(
    QuoteFieldIds.isDeleted,
    (q) => q.isDeleted,
    labelKey: 'is_deleted',
  ),
  colDocumentsCount<Quote>(QuoteFieldIds.documents, (q) => q.documents.length),
  // Created by. `labelKey: 'user'` — NOT `created_by`, which is
  // "Created by :name" and would leak the raw placeholder.
  colUserName<Quote>(QuoteFieldIds.userId, (q) => q.userId, labelKey: 'user'),
  // Attached tags. Display-only (not a sortable Drift column).
  QuoteColumn(
    id: QuoteFieldIds.tagIds,
    labelKey: 'tags',
    sortable: false,
    width: 200,
    cellBuilder: (q, _) => q.tagIds.isEmpty
        ? cellEmpty()
        : EntityTagsView(entityType: 'quote', tagIds: q.tagIds),
    valueBuilder: (q) => '',
  ),
];

final Map<String, QuoteColumn> quoteColumnsById = {
  for (final c in kAllQuoteColumns) c.id: c,
};
