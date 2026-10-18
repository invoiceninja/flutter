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
      if (column.timeOnly) {
        return formatter?.date(
              iso,
              showDate: false,
              showTime: true,
              showSeconds: false,
            ) ??
            iso;
      }
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
      return reportDurationText(
        seconds,
        formatter,
        hoursMinutes: ReportHoursFormat.of(context),
      );
  }
}

/// A quantity of [column] as text — one cell's value, or a total of them.
///
/// Money is formatted in [currencyId] (the company's currency when null or
/// empty), and reads `—` while the [formatter] is still loading rather than
/// flashing a bare `Decimal`. A duration column's quantity is seconds, read
/// in hours as [hoursMinutes] says — see [ReportHoursFormat].
String reportValueText(
  Decimal value, {
  required ReportColumn column,
  required Formatter? formatter,
  String? currencyId,
  bool hoursMinutes = false,
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
      return reportDurationText(
        value.toBigInt().toInt(),
        formatter,
        hoursMinutes: hoursMinutes,
      );
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

/// [seconds] of worked time as the weekly timesheet prints it — decimal hours
/// to two places (`37.5`) or `H:MM` (`37:30`), as the device's hours-format
/// preference says
/// — never a day count, which read a week's 37.5 hours as "1d 13h 30m". Zero
/// is a zero, where the timesheet leaves a cell blank: a report's total of
/// nothing is still a figure.
String reportDurationText(
  int seconds,
  Formatter? formatter, {
  bool hoursMinutes = false,
}) {
  if (seconds <= 0) {
    return hoursMinutes ? '0:00' : (formatter?.decimal(0) ?? '0');
  }
  if (hoursMinutes) return hoursMinutesText(seconds);
  // Two places, where the timesheet keeps five: a report is read, not
  // edited, and a 13:42 entry is "0.23", not "0.22833".
  final hours = seconds / 3600.0;
  return formatter?.decimal(hours, maxDecimals: 2) ?? hours.toStringAsFixed(2);
}

/// Whether the reports read durations as `H:MM` rather than decimal hours —
/// the device's hours-format preference (`HoursFormatController`), the one
/// the weekly timesheet's Total row switches. Put above the reports by
/// `ReportsHost`; absent, durations read as decimal hours, the preference's
/// default.
class ReportHoursFormat extends InheritedWidget {
  const ReportHoursFormat({
    super.key,
    required this.hoursMinutes,
    required super.child,
  });

  final bool hoursMinutes;

  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ReportHoursFormat>()
          ?.hoursMinutes ??
      false;

  @override
  bool updateShouldNotify(ReportHoursFormat oldWidget) =>
      oldWidget.hoursMinutes != hoursMinutes;
}

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
