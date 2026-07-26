import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/payment_dao.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
import 'package:admin/ui/core/widgets/entity_tags_view.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/company_gateway_name_label.dart';
import 'package:admin/ui/core/widgets/vendor_name_label.dart';
import 'package:admin/ui/features/payments/widgets/payment_status_pill.dart';
import 'package:admin/ui/features/projects/widgets/project_name_label.dart';

typedef PaymentColumn = ColumnDefinition<Payment>;

/// Default visible columns for the Payments list. Mirrors React's default
/// column registry: status, number, client, date, type, amount, transaction
/// reference.
const List<String> kDefaultPaymentColumns = <String>[
  PaymentFieldIds.statusId,
  PaymentFieldIds.number,
  PaymentFieldIds.clientId,
  PaymentFieldIds.date,
  PaymentFieldIds.typeId,
  PaymentFieldIds.amount,
  PaymentFieldIds.transactionReference,
];

final List<PaymentColumn> kAllPaymentColumns = <PaymentColumn>[
  // Display-only column. `calculated_status_id` is a domain getter, not a
  // denormalized Drift column — keep `PaymentFieldIds.statusId` as the
  // sort key when this column is used to sort.
  PaymentColumn(
    id: PaymentFieldIds.statusId,
    labelKey: 'status',
    width: 130,
    cellBuilder: (p, _) => PaymentStatusPill(statusId: p.calculatedStatusId),
    valueBuilder: (p) => p.calculatedStatusId,
  ),
  PaymentColumn(
    id: PaymentFieldIds.number,
    labelKey: 'number',
    width: 120,
    cellBuilder: (p, ctx) => cellLink(
      ctx,
      p.number,
      bold: true,
      onTap: () => goEntityFullDetail(ctx, '/payments', p.id),
    ),
    valueBuilder: (p) => cellNonZeroString(p.number),
  ),
  PaymentColumn(
    id: PaymentFieldIds.clientId,
    labelKey: 'client',
    width: 200,
    cellBuilder: (p, _) => p.clientId.isEmpty
        ? cellEmpty()
        : ClientNameLabel(clientId: p.clientId, link: true),
    valueBuilder: (p) => cellNonZeroString(p.clientId),
  ),
  PaymentColumn(
    id: PaymentFieldIds.date,
    labelKey: 'date',
    width: 120,
    cellBuilder: (p, ctx) =>
        p.date == null ? cellEmpty() : cellDate(p.date!.toDateTime(), ctx),
    valueBuilder: (p) => p.date?.toIso(),
  ),
  PaymentColumn(
    id: PaymentFieldIds.typeId,
    labelKey: 'type',
    width: 140,
    cellBuilder: (p, ctx) => cellPaymentType(ctx, p.typeId),
    valueBuilder: (p) => cellNonZeroString(p.typeId),
  ),
  PaymentColumn(
    id: PaymentFieldIds.amount,
    labelKey: 'amount',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (p, context) =>
        cellMoney(p.amount, context, currencyId: p.currencyId),
    valueBuilder: (p) => cellMoneyValue(p.amount),
  ),
  PaymentColumn(
    id: PaymentFieldIds.applied,
    labelKey: 'applied',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (p, context) =>
        cellMoney(p.applied, context, currencyId: p.currencyId),
    valueBuilder: (p) => cellMoneyValue(p.applied),
  ),
  PaymentColumn(
    id: PaymentFieldIds.refunded,
    labelKey: 'refunded',
    width: 130,
    align: ColumnAlign.end,
    cellBuilder: (p, context) =>
        cellMoney(p.refunded, context, currencyId: p.currencyId),
    valueBuilder: (p) => cellMoneyValue(p.refunded),
  ),
  PaymentColumn(
    id: PaymentFieldIds.transactionReference,
    labelKey: 'transaction_reference',
    width: 200,
    cellBuilder: (p, _) => p.transactionReference.isEmpty
        ? cellEmpty()
        : cellText(p.transactionReference),
    valueBuilder: (p) => cellNonZeroString(p.transactionReference),
  ),
  PaymentColumn(
    id: PaymentFieldIds.gatewayId,
    labelKey: 'gateway',
    width: 160,
    cellBuilder: (p, _) => p.companyGatewayId.isEmpty
        ? cellEmpty()
        : CompanyGatewayNameLabel(gatewayId: p.companyGatewayId),
    valueBuilder: (p) => cellNonZeroString(p.companyGatewayId),
  ),
  PaymentColumn(
    id: PaymentFieldIds.currencyId,
    labelKey: 'currency',
    width: 100,
    cellBuilder: (p, ctx) => cellCurrency(ctx, p.currencyId),
    valueBuilder: (p) => cellNonZeroString(p.currencyId),
  ),
  PaymentColumn(
    id: PaymentFieldIds.projectId,
    labelKey: 'project',
    width: 160,
    cellBuilder: (p, _) => p.projectId.isEmpty
        ? cellEmpty()
        : ProjectNameLabel(projectId: p.projectId, link: true),
    valueBuilder: (p) => cellNonZeroString(p.projectId),
  ),
  PaymentColumn(
    id: PaymentFieldIds.vendorId,
    labelKey: 'vendor',
    width: 180,
    cellBuilder: (p, _) => p.vendorId.isEmpty
        ? cellEmpty()
        : VendorNameLabel(vendorId: p.vendorId, link: true),
    valueBuilder: (p) => cellNonZeroString(p.vendorId),
  ),
  PaymentColumn(
    id: PaymentFieldIds.updatedAt,
    labelKey: 'last_updated',
    width: 120,
    cellBuilder: (p, ctx) => cellDate(p.updatedAt, ctx),
    valueBuilder: (p) => p.updatedAt.toIso8601String(),
  ),
  PaymentColumn(
    id: PaymentFieldIds.customValue1,
    labelKey: 'custom_value1',
    width: 140,
    cellBuilder: (p, _) =>
        p.customValue1.isEmpty ? cellEmpty() : cellText(p.customValue1),
    valueBuilder: (p) => cellNonZeroString(p.customValue1),
  ),
  PaymentColumn(
    id: PaymentFieldIds.customValue2,
    labelKey: 'custom_value2',
    width: 140,
    cellBuilder: (p, _) =>
        p.customValue2.isEmpty ? cellEmpty() : cellText(p.customValue2),
    valueBuilder: (p) => cellNonZeroString(p.customValue2),
  ),
  PaymentColumn(
    id: PaymentFieldIds.customValue3,
    labelKey: 'custom_value3',
    width: 140,
    cellBuilder: (p, _) =>
        p.customValue3.isEmpty ? cellEmpty() : cellText(p.customValue3),
    valueBuilder: (p) => cellNonZeroString(p.customValue3),
  ),
  PaymentColumn(
    id: PaymentFieldIds.customValue4,
    labelKey: 'custom_value4',
    width: 140,
    cellBuilder: (p, _) =>
        p.customValue4.isEmpty ? cellEmpty() : cellText(p.customValue4),
    valueBuilder: (p) => cellNonZeroString(p.customValue4),
  ),
  // Attached tags. Display-only (not a sortable Drift column).
  PaymentColumn(
    id: PaymentFieldIds.tagIds,
    labelKey: 'tags',
    sortable: false,
    width: 200,
    cellBuilder: (p, _) => p.tagIds.isEmpty
        ? cellEmpty()
        : EntityTagsView(entityType: 'payment', tagIds: p.tagIds),
    valueBuilder: (p) => '',
  ),
];

final Map<String, PaymentColumn> paymentColumnsById = {
  for (final c in kAllPaymentColumns) c.id: c,
};
