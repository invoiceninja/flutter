import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/ui/features/dashboard/view_models/billing_pipeline_view_model.dart';
import 'package:admin/ui/features/dashboard/widgets/entity_table.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_status_pill.dart';
import 'package:admin/ui/features/quotes/widgets/quote_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// Wide renderer for the consolidated Invoices & Quotes panel.
///
/// `Type | Number | Client | Status | Date | Amount`, with the **Type column
/// present only on a mixed tab**. On `All` and `Draft` both entities
/// participate and their rows are otherwise indistinguishable — the two status
/// pills map `'1'` to the same colour and the same word for both, and a number
/// is user-configurable and commonly a bare `0001` — so the row has to name its
/// source record (`docs/comments-and-activity.md` § *A client's comment feed is
/// mixed*). On the five single-entity tabs the footer's single link already
/// says which, and a sixth column there would be dead weight in a budget that
/// is already tight.
///
/// It carries a **word, not an icon**: two thin outline document glyphs at
/// 14 px are not reliably distinguishable, and a word localises.
class BillingPipelineTable extends StatelessWidget {
  const BillingPipelineTable({
    super.key,
    required this.rows,
    required this.formatter,
    required this.showType,
    required this.onOpen,
  });

  final List<BillingPipelineRow> rows;
  final Formatter formatter;

  /// True on a tab where both entities participate.
  final bool showType;

  final void Function(BillingPipelineRow) onOpen;

  @override
  Widget build(BuildContext context) {
    return DashboardEntityTable(
      // 10 rather than the default 16: six columns at 32 px of gutter each
      // spends a third of a ~570 px card before a glyph is drawn, and
      // `RenderTable` takes the deficit out of the non-flex columns — so the
      // status pill ellipsises mid-word and the client name, the column users
      // actually scan, collapses.
      cellPadding: 10,
      columnWidths: {
        if (showType) 0: const IntrinsicColumnWidth(),
        (showType ? 1 : 0): const IntrinsicColumnWidth(),
        (showType ? 2 : 1): const FlexColumnWidth(2),
        (showType ? 3 : 2): const IntrinsicColumnWidth(),
        (showType ? 4 : 3): const IntrinsicColumnWidth(),
        (showType ? 5 : 4): const IntrinsicColumnWidth(),
      },
      cellAlignments: {(showType ? 5 : 4): Alignment.centerRight},
      headers: [
        // Not `document`: in this app that word means *attachment* (the tab on
        // every billing doc), so it would be misread.
        if (showType) context.tr('type'),
        context.tr('number'),
        context.tr('client'),
        context.tr('status'),
        context.tr('date'),
        context.tr('amount'),
      ],
      rows: [for (final row in rows) _row(context, row)],
    );
  }

  DashboardEntityTableRow _row(BuildContext context, BillingPipelineRow row) {
    final tokens = context.inTheme;
    final isInvoice = row.type == EntityType.invoice;
    final typeLabel = context.tr(isInvoice ? 'invoice' : 'quote');
    final dateText = row.date is Date
        ? formatter.date((row.date! as Date).toIso())
        : '—';

    void open() => onOpen(row);

    final cells = <Widget>[
      if (showType)
        Text(
          typeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12.5, color: tokens.ink2),
        ),
      Text(
        row.number.isEmpty ? '—' : row.number,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
      ),
      // `link: false` — `no_list_tile_name_link_test` scans all of
      // `lib/ui/features/**`, and the whole row is one destination here, so a
      // second link inside it would steal the tap as well as fail the lint.
      ClientNameLabel(
        clientId: row.clientId,
        style: const TextStyle(fontSize: 13),
      ),
      isInvoice
          ? InvoiceStatusPill(
              statusId: row.statusId,
              dotSize: 6,
              textStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
              hasBounce: row.hasBounce,
            )
          : QuoteStatusPill(
              statusId: row.statusId,
              dotSize: 6,
              textStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
              hasBounce: row.hasBounce,
            ),
      // `maxLines` on the date and the amount too — the table this is modelled
      // on omits them, and squeezed they wrap to two or three lines, which is
      // exactly what breaks the card's reserved body height.
      Text(
        dateText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, color: tokens.ink2),
      ),
      PartyCurrencyBuilder(
        clientId: row.clientId,
        builder: (context, currencyId) => Text(
          formatter.money(row.amount as Decimal, clientCurrencyId: currencyId),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: moneyTextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tokens.ink,
          ),
        ),
      ),
    ];

    return DashboardEntityTableRow(
      // Every cell routes to the same record — this is one target, not six.
      // The per-cell split its sibling tables use earns its keep only where a
      // cell goes somewhere else (the client name on `DashboardInvoiceTable`).
      cellTaps: [for (var i = 0; i < cells.length; i++) open],
      semanticsLabel: [
        if (showType) typeLabel,
        if (row.number.isNotEmpty) row.number,
        dateText,
      ].join(', '),
      cells: cells,
    );
  }
}
