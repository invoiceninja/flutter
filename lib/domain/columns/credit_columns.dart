import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/credit_dao.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
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
  CreditColumn(
    id: CreditFieldIds.updatedAt,
    labelKey: 'last_updated',
    width: 120,
    cellBuilder: (c, ctx) => cellDate(c.updatedAt, ctx),
    valueBuilder: (c) => c.updatedAt.toIso8601String(),
  ),
  for (var i = 1; i <= 4; i++)
    CreditColumn(
      id: 'custom_value$i',
      labelKey: 'custom_value$i',
      width: 140,
      cellBuilder: (c, _) {
        final v = switch (i) {
          1 => c.customValue1,
          2 => c.customValue2,
          3 => c.customValue3,
          _ => c.customValue4,
        };
        return v.isEmpty ? cellEmpty() : cellText(v);
      },
      valueBuilder: (c) {
        final v = switch (i) {
          1 => c.customValue1,
          2 => c.customValue2,
          3 => c.customValue3,
          _ => c.customValue4,
        };
        return cellNonZeroString(v);
      },
    ),
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
