import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/purchase_order_dao.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_factories.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';
import 'package:admin/domain/columns/custom_field_columns.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/design_name_label.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_status_pill.dart';

typedef PurchaseOrderColumn = ColumnDefinition<PurchaseOrder>;

const List<String> kDefaultPurchaseOrderColumns = <String>[
  PurchaseOrderFieldIds.status,
  PurchaseOrderFieldIds.number,
  PurchaseOrderFieldIds.vendorId,
  PurchaseOrderFieldIds.amount,
  PurchaseOrderFieldIds.date,
];

final kAllPurchaseOrderColumns = <PurchaseOrderColumn>[
  PurchaseOrderColumn(
    id: PurchaseOrderFieldIds.status,
    labelKey: 'status',
    width: 110,
    cellBuilder: (p, _) => PurchaseOrderStatusPill(
      statusId: p.calculatedStatusId,
      hasBounce: p.hasBouncedInvitation,
    ),
    valueBuilder: (p) => p.calculatedStatusId,
  ),
  PurchaseOrderColumn(
    id: PurchaseOrderFieldIds.number,
    labelKey: 'number',
    width: 130,
    cellBuilder: (p, ctx) => cellLink(
      ctx,
      p.number,
      bold: true,
      onTap: () => goEntityFullDetail(ctx, '/purchase_orders', p.id),
    ),
    valueBuilder: (p) => cellNonZeroString(p.number),
  ),
  PurchaseOrderColumn(
    id: PurchaseOrderFieldIds.vendorId,
    labelKey: 'vendor',
    width: 200,
    cellBuilder: (p, _) => p.vendorId.isEmpty
        ? cellEmpty()
        : VendorNameLabel(vendorId: p.vendorId, link: true),
    valueBuilder: (p) => cellNonZeroString(p.vendorId),
  ),
  PurchaseOrderColumn(
    id: PurchaseOrderFieldIds.date,
    labelKey: 'date',
    width: 120,
    cellBuilder: (p, ctx) =>
        p.date == null ? cellEmpty() : cellDate(p.date!.toDateTime(), ctx),
    valueBuilder: (p) => p.date?.toIso(),
  ),
  PurchaseOrderColumn(
    id: PurchaseOrderFieldIds.dueDate,
    labelKey: 'due_date',
    width: 120,
    cellBuilder: (p, ctx) => p.dueDate == null
        ? cellEmpty()
        : cellDate(p.dueDate!.toDateTime(), ctx),
    valueBuilder: (p) => p.dueDate?.toIso(),
  ),
  PurchaseOrderColumn(
    id: PurchaseOrderFieldIds.amount,
    labelKey: 'amount',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (p, context) =>
        cellPartyMoney(p.amount, context, vendorId: p.vendorId),
    valueBuilder: (p) => cellMoneyValue(p.amount),
  ),
  PurchaseOrderColumn(
    id: PurchaseOrderFieldIds.balance,
    labelKey: 'balance',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (p, context) =>
        cellPartyMoney(p.balance, context, vendorId: p.vendorId),
    valueBuilder: (p) => cellMoneyValue(p.balance),
  ),
  PurchaseOrderColumn(
    id: PurchaseOrderFieldIds.poNumber,
    labelKey: 'po_number',
    width: 130,
    cellBuilder: (p, _) =>
        p.poNumber.isEmpty ? cellEmpty() : cellText(p.poNumber),
    valueBuilder: (p) => cellNonZeroString(p.poNumber),
  ),
  PurchaseOrderColumn(
    id: PurchaseOrderFieldIds.designId,
    labelKey: 'design',
    width: 130,
    cellBuilder: (p, _) => p.designId.isEmpty
        ? cellEmpty()
        : DesignNameLabel(designId: p.designId),
    valueBuilder: (p) => cellNonZeroString(p.designId),
  ),
  colUpdatedAt<PurchaseOrder>(
    PurchaseOrderFieldIds.updatedAt,
    (p) => p.updatedAt,
  ),
  // Project this document belongs to.
  PurchaseOrderColumn(
    id: PurchaseOrderFieldIds.projectId,
    labelKey: 'project',
    width: 160,
    cellBuilder: (p, _) => p.projectId.isEmpty
        ? cellEmpty()
        : ProjectNameLabel(projectId: p.projectId, link: true),
    valueBuilder: (p) => cellNonZeroString(p.projectId),
  ),
  // Payload-only on this table, so display-only — lift the field into
  // the Drift table first if it ever needs to sort.
  colNotes<PurchaseOrder>(
    PurchaseOrderFieldIds.publicNotes,
    (p) => p.publicNotes,
    labelKey: 'public_notes',
  ),
  colNotes<PurchaseOrder>(
    PurchaseOrderFieldIds.privateNotes,
    (p) => p.privateNotes,
    labelKey: 'private_notes',
  ),
  // Quotes, credits, purchase orders and recurring invoices all read the
  // company's `invoice1..4` slots — there are no per-type definitions.
  // The configured labels, type-aware values and the hiding of
  // unconfigured slots come from `decorateCustomFieldColumns`.
  ...customFieldColumns<PurchaseOrder>(
    prefix: 'invoice',
    ids: const [
      'custom_value1',
      'custom_value2',
      'custom_value3',
      'custom_value4',
    ],
    values: [
      (p) => p.customValue1,
      (p) => p.customValue2,
      (p) => p.customValue3,
      (p) => p.customValue4,
    ],
  ),
  // ── Standard record metadata ──────────────────────────────────────────
  // Shared across every entity list; see `column_factories.dart`. Created /
  // archived / deleted are real Drift columns and sort; state, documents and
  // the two user columns are derived or payload-only and don't.
  colUserName<PurchaseOrder>(
    PurchaseOrderFieldIds.assignedUserId,
    (p) => p.assignedUserId,
    labelKey: 'assigned_user',
    sortable: true,
  ),
  colCreatedAt<PurchaseOrder>(
    PurchaseOrderFieldIds.createdAt,
    (p) => p.createdAt,
  ),
  colArchivedAt<PurchaseOrder>(
    PurchaseOrderFieldIds.archivedAt,
    (p) => p.archivedAt,
  ),
  colEntityState<PurchaseOrder>(
    PurchaseOrderFieldIds.entityState,
    archivedAt: (p) => p.archivedAt,
    isDeleted: (p) => p.isDeleted,
  ),
  colFlag<PurchaseOrder>(
    PurchaseOrderFieldIds.isDeleted,
    (p) => p.isDeleted,
    labelKey: 'is_deleted',
  ),
  colDocumentsCount<PurchaseOrder>(
    PurchaseOrderFieldIds.documents,
    (p) => p.documents.length,
  ),
  // Created by. `labelKey: 'user'` — NOT `created_by`, which is
  // "Created by :name" and would leak the raw placeholder.
  colUserName<PurchaseOrder>(
    PurchaseOrderFieldIds.userId,
    (p) => p.userId,
    labelKey: 'user',
  ),
  // Attached tags. Display-only (not a sortable Drift column).
  PurchaseOrderColumn(
    id: PurchaseOrderFieldIds.tagIds,
    labelKey: 'tags',
    sortable: false,
    width: 200,
    cellBuilder: (o, _) => o.tagIds.isEmpty
        ? cellEmpty()
        : EntityTagsView(entityType: 'purchase_order', tagIds: o.tagIds),
    valueBuilder: (o) => '',
  ),
];

final Map<String, PurchaseOrderColumn> purchaseOrderColumnsById = {
  for (final c in kAllPurchaseOrderColumns) c.id: c,
};
