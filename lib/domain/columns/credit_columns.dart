import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/credit_dao.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_factories.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/design_name_label.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/features/credits/widgets/credit_status_pill.dart';

typedef CreditColumn = ColumnDefinition<Credit>;

const List<String> kDefaultCreditColumns = <String>[
  CreditFieldIds.status,
  CreditFieldIds.number,
  CreditFieldIds.clientId,
  CreditFieldIds.amount,
  CreditFieldIds.balance,
  CreditFieldIds.date,
  CreditFieldIds.dueDate,
];

final List<CreditColumn> kAllCreditColumns = <CreditColumn>[
  CreditColumn(
    id: CreditFieldIds.status,
    labelKey: 'status',
    width: 110,
    cellBuilder: (c, _) => CreditStatusPill(
      statusId: c.calculatedStatusId,
      hasBounce: c.hasBouncedInvitation,
    ),
    valueBuilder: (c) => c.calculatedStatusId,
  ),
  CreditColumn(
    id: CreditFieldIds.number,
    labelKey: 'number',
    width: 130,
    cellBuilder: (c, ctx) => cellLink(
      ctx,
      c.number,
      bold: true,
      onTap: () => goEntityFullDetail(ctx, '/credits', c.id),
    ),
    valueBuilder: (c) => cellNonZeroString(c.number),
  ),
  CreditColumn(
    id: CreditFieldIds.clientId,
    labelKey: 'client',
    width: 200,
    cellBuilder: (c, _) => c.clientId.isEmpty
        ? cellEmpty()
        : ClientNameLabel(clientId: c.clientId, link: true),
    valueBuilder: (c) => cellNonZeroString(c.clientId),
  ),
  CreditColumn(
    id: CreditFieldIds.date,
    labelKey: 'credit_date',
    width: 120,
    cellBuilder: (c, ctx) =>
        c.date == null ? cellEmpty() : cellDate(c.date!.toDateTime(), ctx),
    valueBuilder: (c) => c.date?.toIso(),
  ),
  CreditColumn(
    id: CreditFieldIds.dueDate,
    labelKey: 'due_date',
    width: 120,
    cellBuilder: (c, ctx) => c.dueDate == null
        ? cellEmpty()
        : cellDate(c.dueDate!.toDateTime(), ctx),
    valueBuilder: (c) => c.dueDate?.toIso(),
  ),
  CreditColumn(
    id: CreditFieldIds.amount,
    labelKey: 'amount',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (c, context) =>
        cellPartyMoney(c.amount, context, clientId: c.clientId),
    valueBuilder: (c) => cellMoneyValue(c.amount),
  ),
  CreditColumn(
    id: CreditFieldIds.balance,
    labelKey: 'balance',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (c, context) =>
        cellPartyMoney(c.balance, context, clientId: c.clientId),
    valueBuilder: (c) => cellMoneyValue(c.balance),
  ),
  CreditColumn(
    id: CreditFieldIds.paidToDate,
    labelKey: 'applied',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (c, context) =>
        cellPartyMoney(c.paidToDate, context, clientId: c.clientId),
    valueBuilder: (c) => cellMoneyValue(c.paidToDate),
  ),
  CreditColumn(
    id: CreditFieldIds.poNumber,
    labelKey: 'po_number',
    width: 130,
    cellBuilder: (c, _) =>
        c.poNumber.isEmpty ? cellEmpty() : cellText(c.poNumber),
    valueBuilder: (c) => cellNonZeroString(c.poNumber),
  ),
  CreditColumn(
    id: CreditFieldIds.designId,
    labelKey: 'design',
    width: 130,
    cellBuilder: (c, _) => c.designId.isEmpty
        ? cellEmpty()
        : DesignNameLabel(designId: c.designId),
    valueBuilder: (c) => cellNonZeroString(c.designId),
  ),
  colUpdatedAt<Credit>(CreditFieldIds.updatedAt, (c) => c.updatedAt),
  // Project this document belongs to.
  CreditColumn(
    id: CreditFieldIds.projectId,
    labelKey: 'project',
    width: 160,
    cellBuilder: (c, _) => c.projectId.isEmpty
        ? cellEmpty()
        : ProjectNameLabel(projectId: c.projectId, link: true),
    valueBuilder: (c) => cellNonZeroString(c.projectId),
  ),
  // Billing docs can carry a vendor as well as a client. The id, the Drift
  // column and the DAO sort case all already existed — only the column was
  // missing. React and the legacy app both offer it.
  CreditColumn(
    id: CreditFieldIds.vendorId,
    labelKey: 'vendor',
    width: 160,
    cellBuilder: (c, _) => c.vendorId.isEmpty
        ? cellEmpty()
        : VendorNameLabel(vendorId: c.vendorId, link: true),
    valueBuilder: (c) => cellNonZeroString(c.vendorId),
  ),
  // Payload-only on this table, so display-only — lift the field into
  // the Drift table first if it ever needs to sort.
  colNotes<Credit>(
    CreditFieldIds.publicNotes,
    (c) => c.publicNotes,
    labelKey: 'public_notes',
  ),
  colNotes<Credit>(
    CreditFieldIds.privateNotes,
    (c) => c.privateNotes,
    labelKey: 'private_notes',
  ),
  // Quotes, credits, purchase orders and recurring invoices all read the
  // company's `invoice1..4` slots — there are no per-type definitions.
  // The configured labels, type-aware values and the hiding of
  // unconfigured slots come from `decorateCustomFieldColumns`.
  ...customFieldColumns<Credit>(
    prefix: 'invoice',
    ids: const [
      'custom_value1',
      'custom_value2',
      'custom_value3',
      'custom_value4',
    ],
    values: [
      (c) => c.customValue1,
      (c) => c.customValue2,
      (c) => c.customValue3,
      (c) => c.customValue4,
    ],
  ),
  // ── Standard record metadata ──────────────────────────────────────────
  // Shared across every entity list; see `column_factories.dart`. Created /
  // archived / deleted are real Drift columns and sort; state, documents and
  // the two user columns are derived or payload-only and don't.
  colUserName<Credit>(
    CreditFieldIds.assignedUserId,
    (c) => c.assignedUserId,
    labelKey: 'assigned_user',
    sortable: true,
  ),
  colCreatedAt<Credit>(CreditFieldIds.createdAt, (c) => c.createdAt),
  colArchivedAt<Credit>(CreditFieldIds.archivedAt, (c) => c.archivedAt),
  colEntityState<Credit>(
    CreditFieldIds.entityState,
    archivedAt: (c) => c.archivedAt,
    isDeleted: (c) => c.isDeleted,
  ),
  colFlag<Credit>(
    CreditFieldIds.isDeleted,
    (c) => c.isDeleted,
    labelKey: 'is_deleted',
  ),
  colDocumentsCount<Credit>(
    CreditFieldIds.documents,
    (c) => c.documents.length,
  ),
  // Created by. `labelKey: 'user'` — NOT `created_by`, which is
  // "Created by :name" and would leak the raw placeholder.
  colUserName<Credit>(CreditFieldIds.userId, (c) => c.userId, labelKey: 'user'),
  // Attached tags. Display-only (not a sortable Drift column).
  CreditColumn(
    id: CreditFieldIds.tagIds,
    labelKey: 'tags',
    sortable: false,
    width: 200,
    cellBuilder: (c, _) => c.tagIds.isEmpty
        ? cellEmpty()
        : EntityTagsView(entityType: 'credit', tagIds: c.tagIds),
    valueBuilder: (c) => '',
  ),
];

final Map<String, CreditColumn> creditColumnsById = {
  for (final c in kAllCreditColumns) c.id: c,
};
