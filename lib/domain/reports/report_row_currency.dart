import 'package:admin/data/models/domain/report_preview.dart';

/// Index of the column that names each row's currency, or -1 when the report
/// has none.
///
/// The server puts no currency on a cell. It puts an ISO code in a column of
/// the row, and which column depends on the report: `client.currency_id` on
/// the client report and on every document that belongs to a client,
/// `expense.currency_id`, `purchase_order.currency_id`, `payment.currency`,
/// `vendor.currency` (`BaseExport`'s `*_report_keys` maps). All of them are in
/// the report's default column set, so a plain run always carries one.
///
/// Matched on the exact tail, so the expense report's second currency column
/// — `expense.invoice_currency_id`, the currency the expense was *invoiced*
/// in, which says nothing about the row's own amounts — is never taken for it.
/// The task and product reports have no currency column at all.
int reportCurrencyColumnIndex(List<ReportColumn> columns) {
  var fallback = -1;
  for (var i = 0; i < columns.length; i++) {
    final id = columns[i].identifier.toLowerCase();
    final tail = id.contains('.') ? id.split('.').last : id;
    if (tail == 'currency_id') return i;
    if (tail == 'currency' && fallback < 0) fallback = i;
  }
  return fallback;
}

/// [preview] with every row's [ReportRow.currencyId] set from the report's
/// currency column — each ISO code resolved through [currencyIdByCode] — or
/// to [fallbackCurrencyId] where the report has no such column or the row's
/// code is blank or unknown.
///
/// Without this every amount in a report lands in one bucket and the totals
/// add euros to dollars. Returns [preview] itself when there is nothing to
/// set.
ReportPreview withRowCurrencies(
  ReportPreview preview, {
  required Map<String, String> currencyIdByCode,
  String? fallbackCurrencyId,
}) {
  final index = reportCurrencyColumnIndex(preview.columns);
  if (index < 0 && fallbackCurrencyId == null) return preview;
  if (preview.rows.isEmpty) return preview;
  return ReportPreview(
    columns: preview.columns,
    rows: [
      for (final row in preview.rows)
        _withCurrency(row, index, currencyIdByCode, fallbackCurrencyId),
    ],
  );
}

ReportRow _withCurrency(
  ReportRow row,
  int index,
  Map<String, String> currencyIdByCode,
  String? fallbackCurrencyId,
) {
  String? id;
  if (index >= 0 && index < row.cells.length) {
    final cell = row.cells[index];
    final code = cell is ReportStringCell
        ? (cell.value ?? cell.displayValue)
        : cell.displayValue;
    if (code != null) id = currencyIdByCode[code.trim().toUpperCase()];
  }
  id ??= fallbackCurrencyId;
  if (id == null || id == row.currencyId) return row;
  return row.copyWith(currencyId: id);
}
