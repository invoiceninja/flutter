import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';

/// The view as a CSV: exactly the rows on screen, in the order and with the
/// columns shown.
///
/// This is the one export that honours everything the reader did locally —
/// the column filters, the row search, the sort, the column selection — none
/// of which a server file can know about (the server is never told).
///
/// **Values are written for a spreadsheet, not for the eye.** A number is a
/// bare machine number (`1234.5`, never `$1,234.50` or `1.234,50`), a date is
/// ISO, a duration is `h:mm:ss` and a boolean `TRUE` / `FALSE`, so the file
/// sorts and sums when it is opened. Text is the cell's own.
///
/// With [summary], a grouped view is written as its groups instead — a line
/// per group with its row count and the total of every totalled column, in
/// [currencyId] — which is what the table shows while its groups are closed.
/// [groupLabel] turns a bucket key into the text the table prints for it.
///
/// [separator] is a comma for a file. A tab gives the form a spreadsheet
/// takes from the clipboard — there a field cannot be quoted, so a tab or a
/// line break inside one becomes a space.
String buildReportCsv({
  required ReportView view,
  required String Function(String groupKey) groupLabel,
  String currencyId = '',
  bool summary = false,
  String countLabel = 'Count',
  String separator = ',',
}) {
  final columns = view.visibleColumns;
  final out = StringBuffer();
  final quoted = separator == ',';
  String field(String value) =>
      quoted ? _escape(value) : value.replaceAll(RegExp(r'[\t\r\n]+'), ' ');
  void line(Iterable<String> cells) {
    out
      ..writeAll(cells.map(field), separator)
      ..write(quoted ? '\r\n' : '\n');
  }

  if (summary && view.groups.isNotEmpty) {
    final groupColumn = columns.isEmpty ? null : columns.first;
    final measures = [
      for (final c in columns.skip(1))
        if (c.effectiveAggregation != ReportAggregation.none) c,
    ];
    line([
      groupColumn?.displayLabel ?? '',
      countLabel,
      for (final c in measures) c.displayLabel,
    ]);
    for (final group in view.groups) {
      line([
        _text(groupLabel(group.key)),
        '${group.count}',
        for (final c in measures)
          _number(group.numericTotals[c.identifier]?[currencyId]),
      ]);
    }
    return out.toString();
  }

  line([for (final c in columns) c.displayLabel]);
  final indexes = [
    for (final c in columns) view.cellIndexByColumn[c.identifier] ?? -1,
  ];
  Iterable<ReportRow> rows() sync* {
    if (view.groups.isEmpty) {
      yield* view.rows;
    } else {
      for (final group in view.groups) {
        yield* group.rows;
      }
    }
  }

  for (final row in rows()) {
    line([
      for (final i in indexes)
        i < 0 || i >= row.cells.length ? '' : _cell(row.cells[i]),
    ]);
  }
  return out.toString();
}

/// [csv] as the bytes of a file: UTF-8 behind a byte-order mark. Without the
/// mark Excel opens a UTF-8 file as the system code page and every accented
/// client name arrives as two wrong characters.
Uint8List reportCsvBytes(String csv) =>
    Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);

String _cell(ReportCell cell) {
  switch (cell) {
    case ReportStringCell():
      return _text(cell.displayValue ?? cell.value ?? '');
    case ReportNumberCell():
      final value = cell.value;
      return value == null ? _text(cell.displayValue ?? '') : _number(value);
    case ReportDateCell():
      return cell.value?.toIso() ?? _text(cell.displayValue ?? '');
    case ReportDateTimeCell():
      final value = cell.value?.toLocal();
      if (value == null) return _text(cell.displayValue ?? '');
      String two(int n) => n.toString().padLeft(2, '0');
      return '${value.year}-${two(value.month)}-${two(value.day)} '
          '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
    case ReportAgeCell():
      // The "paid" sentinel is not an age.
      final days = cell.days;
      return days == null || days < 0 ? '' : '$days';
    case ReportBoolCell():
      final value = cell.value;
      return value == null ? '' : (value ? 'TRUE' : 'FALSE');
    case ReportDurationCell():
      final seconds = cell.seconds;
      if (seconds == null) return _text(cell.displayValue ?? '');
      String two(int n) => n.toString().padLeft(2, '0');
      return '${seconds ~/ 3600}:${two(seconds % 3600 ~/ 60)}:'
          '${two(seconds % 60)}';
  }
}

String _number(Decimal? value) => value == null ? '' : value.toString();

/// A text cell, made safe to open.
///
/// A spreadsheet evaluates any cell that begins with `=`, `+`, `-` or `@`
/// (and, in some, a tab or a carriage return) as a formula — so a client
/// named `=HYPERLINK(...)` is code the moment the file is opened. A leading
/// apostrophe is the conventional neutraliser: the cell is shown as text and
/// the apostrophe is not displayed. Applied to text only; a negative number
/// has to stay a number.
String _text(String value) {
  if (value.isEmpty) return value;
  const risky = {0x3D, 0x2B, 0x2D, 0x40, 0x09, 0x0D};
  return risky.contains(value.codeUnitAt(0)) ? "'$value" : value;
}

String _escape(String field) {
  final needsQuotes =
      field.contains(',') ||
      field.contains('"') ||
      field.contains('\n') ||
      field.contains('\r');
  if (!needsQuotes) return field;
  return '"${field.replaceAll('"', '""')}"';
}
