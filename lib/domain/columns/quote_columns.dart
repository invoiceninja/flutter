import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/quote_dao.dart';
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
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
    width: 240,
    cellBuilder: (q, _) =>
        q.publicNotes.isEmpty ? cellEmpty() : cellText(q.publicNotes),
    valueBuilder: (q) => cellNonZeroString(q.publicNotes),
  ),
  QuoteColumn(
    id: QuoteFieldIds.updatedAt,
    labelKey: 'last_updated',
    width: 120,
    cellBuilder: (q, ctx) => cellDate(q.updatedAt, ctx),
    valueBuilder: (q) => q.updatedAt.toIso8601String(),
  ),
  for (var i = 1; i <= 4; i++)
    QuoteColumn(
      id: 'custom_value$i',
      labelKey: 'custom_value$i',
      width: 140,
      cellBuilder: (q, _) {
        final v = switch (i) {
          1 => q.customValue1,
          2 => q.customValue2,
          3 => q.customValue3,
          _ => q.customValue4,
        };
        return v.isEmpty ? cellEmpty() : cellText(v);
      },
      valueBuilder: (q) {
        final v = switch (i) {
          1 => q.customValue1,
          2 => q.customValue2,
          3 => q.customValue3,
          _ => q.customValue4,
        };
        return cellNonZeroString(v);
      },
    ),
];

final Map<String, QuoteColumn> quoteColumnsById = {
  for (final c in kAllQuoteColumns) c.id: c,
};
