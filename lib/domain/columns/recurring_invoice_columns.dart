import 'package:admin/app/router.dart';
import 'package:admin/data/db/dao/recurring_invoice_dao.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/domain/columns/column_cells.dart';
import 'package:admin/domain/columns/column_definition.dart';
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

final List<RecurringInvoiceColumn> kAllRecurringInvoiceColumns =
    <RecurringInvoiceColumn>[
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
                ctx.tr(
                  kRecurringFrequencyLabelKey[r.frequencyId] ?? r.frequencyId,
                ),
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
      RecurringInvoiceColumn(
        id: RecurringInvoiceFieldIds.updatedAt,
        labelKey: 'last_updated',
        width: 120,
        cellBuilder: (r, ctx) => cellDate(r.updatedAt, ctx),
        valueBuilder: (r) => r.updatedAt.toIso8601String(),
      ),
      for (var i = 1; i <= 4; i++)
        RecurringInvoiceColumn(
          id: 'custom_value$i',
          labelKey: 'custom_value$i',
          width: 140,
          cellBuilder: (r, _) {
            final v = switch (i) {
              1 => r.customValue1,
              2 => r.customValue2,
              3 => r.customValue3,
              _ => r.customValue4,
            };
            return v.isEmpty ? cellEmpty() : cellText(v);
          },
          valueBuilder: (r) {
            final v = switch (i) {
              1 => r.customValue1,
              2 => r.customValue2,
              3 => r.customValue3,
              _ => r.customValue4,
            };
            return cellNonZeroString(v);
          },
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
