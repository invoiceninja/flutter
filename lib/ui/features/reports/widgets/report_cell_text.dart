import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/utils/formatting.dart';

/// What a report cell shows.
///
/// **A typed cell is rendered from its typed value, never from the server's
/// string.** The export's `display_value` is not a display value: for almost
/// every cell it is the same string as `value` — the amount in the *company*
/// currency's number format with no symbol, a date as `2026-03-03` — and on
/// the client and credit reports the balance columns are worse than that.
/// `ClientExport::processMetaData` runs the already-formatted string back
/// through `Number::formatMoney`, PHP reads `"3,125.00"` as `3`, and the cell
/// arrives as `£3.00`. Printing it verbatim is how a client owing three
/// thousand pounds was shown as owing three.
///
/// So an amount goes through [Formatter.money] in the row's own currency
/// ([rowCurrencyId]), a date through the company's date format, a duration,
/// a boolean and an age through their own renderings. The server's string is
/// what a **text** cell shows, and the fallback for a typed cell whose value
/// could not be read at all (`payment.amount` is the word "Unpaid" on an
/// invoice nobody has paid).
String reportCellText(
  BuildContext context,
  ReportCell cell,
  ReportColumn column,
  Formatter? formatter, {
  String? rowCurrencyId,
}) {
  final fallback = cell.displayValue ?? '';
  switch (cell) {
    case ReportStringCell():
      return cell.displayValue ?? cell.value ?? '';
    case ReportNumberCell():
      final value = cell.value;
      if (value == null) return fallback;
      return reportValueText(
        value,
        column: column,
        formatter: formatter,
        currencyId: cell.currencyId ?? rowCurrencyId,
      );
    case ReportDateCell():
      final iso = cell.value?.toIso();
      if (iso == null) return fallback;
      return formatter?.date(iso) ?? iso;
    case ReportDateTimeCell():
      final iso = cell.value?.toIso8601String();
      if (iso == null) return fallback;
      return formatter?.date(iso, showTime: true) ?? iso;
    case ReportAgeCell():
      if (cell.isPaid) return context.tr('paid');
      final days = cell.days;
      return days == null ? fallback : '$days';
    case ReportBoolCell():
      final value = cell.value;
      if (value == null) return '';
      return value ? context.tr('yes') : context.tr('no');
    case ReportDurationCell():
      final seconds = cell.seconds;
      if (seconds == null) return fallback;
      return _durationText(seconds);
  }
}

/// A quantity of [column] as text — one cell's value, or a total of them.
///
/// Money is formatted in [currencyId] (the company's currency when null or
/// empty), and reads `—` while the [formatter] is still loading rather than
/// flashing a bare `Decimal`. A duration column's quantity is seconds.
String reportValueText(
  Decimal value, {
  required ReportColumn column,
  required Formatter? formatter,
  String? currencyId,
}) {
  switch (column.type) {
    case ReportColumnType.money:
      if (formatter == null) return '—';
      return formatter.money(
        value,
        currencyId: currencyId == null || currencyId.isEmpty
            ? null
            : currencyId,
      );
    case ReportColumnType.duration:
      return _durationText(value.toBigInt().toInt());
    case ReportColumnType.number:
    case ReportColumnType.string:
    case ReportColumnType.date:
    case ReportColumnType.dateTime:
    case ReportColumnType.age:
    case ReportColumnType.boolean:
      if (formatter == null) return value.toString();
      return formatter.decimal(value.toDouble());
  }
}

/// `0:13:42`, as the tasks time log writes it; a span of a day or more
/// compacts to `Xd HHh MMm`.
String _durationText(int seconds) =>
    formatDuration(Duration(seconds: seconds), compactDays: true);

/// Where a row's own record lives, or null when the row is not a link.
///
/// Null is the common answer and an honest one. A report row carries its
/// record id only when the report asked for it (`ReportDefinition.rowIdKey`)
/// — see [ReportRow.recordId] — and a line the app cannot name a destination
/// for must not be tappable: the previous code built a route from the cell's
/// *field name* and opened `/invoices/number`.
String? reportRowRoute(BuildContext context, ReportRow row) {
  final wire = row.recordWire;
  final id = row.recordId;
  if (wire == null || id == null || id.isEmpty) return null;
  final registry = context.read<Services>().entityRegistry;
  final handlers = resolveDrillTarget(registry, wire);
  if (handlers == null) return null;
  return '${handlers.routePath}/$id';
}
