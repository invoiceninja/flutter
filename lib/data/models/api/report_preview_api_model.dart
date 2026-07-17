import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/domain/reports/report_column_types.dart';

/// Decodes the report-preview JSON envelope returned by
/// `POST /api/v1/reports/preview/<hash>` into a typed [ReportPreview].
///
/// Server shape:
/// ```json
/// {
///   "columns": [{"identifier": "client.name", "display_value": "Client"}],
///   "0": [{"identifier":"client.name","value":"ACME","display_value":"ACME","entity":"client","id":"abc"}, ...],
///   "1": [...],
///   ...
/// }
/// ```
///
/// Rows are keyed by stringified integers (`"0"`, `"1"`, …) at the top level
/// alongside `columns`. We collect non-`columns` keys, sort numerically, and
/// map to [ReportRow]s. Column types are inferred via [inferColumnType] —
/// the server doesn't ship a column-type map.
ReportPreview decodeReportPreview(Object? raw) {
  if (raw is! Map) {
    throw const FormatException('Report preview must be a JSON object');
  }
  final colsRaw = raw['columns'];
  if (colsRaw is! List) {
    throw const FormatException('Report preview is missing `columns`');
  }
  final columns = <ReportColumn>[];
  for (final c in colsRaw) {
    if (c is! Map) continue;
    final identifier = c['identifier']?.toString() ?? '';
    if (identifier.isEmpty) continue;
    columns.add(
      ReportColumn(
        identifier: identifier,
        displayLabel: c['display_value']?.toString() ?? identifier,
        type: inferColumnType(identifier),
      ),
    );
  }

  // Collect numeric-keyed entries; PHP's json encoder may emit them as
  // string keys but we treat both interchangeably.
  final rowEntries = <(int, Object?)>[];
  raw.forEach((k, v) {
    if (k == 'columns') return;
    final asInt = int.tryParse(k.toString());
    if (asInt == null) return;
    rowEntries.add((asInt, v));
  });
  rowEntries.sort((a, b) => a.$1.compareTo(b.$1));

  final rows = <ReportRow>[];
  for (final (_, rowRaw) in rowEntries) {
    if (rowRaw is! List) continue;
    final cells = <ReportCell>[];
    for (var i = 0; i < columns.length; i++) {
      final cellRaw = i < rowRaw.length ? rowRaw[i] : null;
      cells.add(_parseCell(cellRaw, columns[i].type));
    }
    rows.add(ReportRow(cells: cells));
  }
  return ReportPreview(columns: columns, rows: rows);
}

ReportCell _parseCell(Object? cellRaw, ReportColumnType type) {
  Map<String, Object?>? cell;
  if (cellRaw is Map) {
    cell = cellRaw.map((k, v) => MapEntry(k.toString(), v));
  } else if (cellRaw != null) {
    // Some endpoints emit primitives directly when there's no entity ref.
    return _parseTyped(value: cellRaw, displayValue: null, type: type);
  }
  final value = cell?['value'];
  final displayValue = cell?['display_value']?.toString();
  final entityWire = cell?['entity']?.toString();
  final entityId = cell?['id']?.toString();
  return _parseTyped(
    value: value,
    displayValue: displayValue,
    type: type,
    entityWire: entityWire,
    entityId: entityId,
    currencyId: cell?['currency_id']?.toString(),
    exchangeRate: cell?['exchange_rate'],
  );
}

ReportCell _parseTyped({
  required Object? value,
  required String? displayValue,
  required ReportColumnType type,
  String? entityWire,
  String? entityId,
  String? currencyId,
  Object? exchangeRate,
}) {
  switch (type) {
    case ReportColumnType.money:
      return ReportNumberCell(
        // The export formats numeric cells with the currency's separators
        // ("3,238.00"); parseMoney would zero them. See parseFormattedMoney.
        value: value == null ? null : parseFormattedMoney(value),
        isMoney: true,
        currencyId: currencyId,
        exchangeRate: exchangeRate == null
            ? null
            : parseFormattedMoney(exchangeRate),
        entityWire: entityWire,
        entityId: entityId,
        displayValue: displayValue,
      );
    case ReportColumnType.number:
      return ReportNumberCell(
        value: value == null ? null : parseFormattedMoney(value),
        entityWire: entityWire,
        entityId: entityId,
        displayValue: displayValue,
      );
    case ReportColumnType.date:
      return ReportDateCell(
        value: value is String ? Date.tryParse(value) : null,
        entityWire: entityWire,
        entityId: entityId,
        displayValue: displayValue,
      );
    case ReportColumnType.dateTime:
      DateTime? dt;
      if (value is String && value.isNotEmpty) {
        dt = DateTime.tryParse(value);
      } else if (value is num) {
        // Server occasionally emits epoch seconds for *_at fields.
        dt = DateTime.fromMillisecondsSinceEpoch(
          (value.toInt()) * 1000,
          isUtc: true,
        );
      }
      return ReportDateTimeCell(
        value: dt,
        entityWire: entityWire,
        entityId: entityId,
        displayValue: displayValue,
      );
    case ReportColumnType.age:
      int? days;
      if (value is num) {
        days = value.toInt();
      } else if (value is String) {
        days = int.tryParse(value);
      }
      return ReportAgeCell(
        days: days,
        entityWire: entityWire,
        entityId: entityId,
        displayValue: displayValue,
      );
    case ReportColumnType.duration:
      int? secs;
      if (value is num) {
        secs = value.toInt();
      } else if (value is String) {
        secs = int.tryParse(value);
      }
      return ReportDurationCell(
        seconds: secs,
        entityWire: entityWire,
        entityId: entityId,
        displayValue: displayValue,
      );
    case ReportColumnType.boolean:
      // Unknown / empty string → leave as null so the UI renders as empty
      // rather than silently flipping to "No". Known wire shapes are bool,
      // 0/1, and the strings `'true'`/`'1'`/`'false'`/`'0'`.
      bool? b;
      if (value is bool) {
        b = value;
      } else if (value is num) {
        b = value != 0;
      } else if (value is String) {
        if (value == 'true' || value == '1') {
          b = true;
        } else if (value == 'false' || value == '0') {
          b = false;
        }
      }
      return ReportBoolCell(
        value: b,
        entityWire: entityWire,
        entityId: entityId,
        displayValue: displayValue,
      );
    case ReportColumnType.string:
      return ReportStringCell(
        value: value?.toString(),
        entityWire: entityWire,
        entityId: entityId,
        displayValue: displayValue,
      );
  }
}

/// Decode the per-currency exchange rates the server bundles into the static
/// data response. We hold this on the engine so the converted-totals math
/// doesn't depend on a stale `Decimal` snapshot — keyed by currency id.
Map<String, Decimal> exchangeRatesFrom(Map<String, dynamic>? currenciesRaw) {
  final out = <String, Decimal>{};
  if (currenciesRaw == null) return out;
  currenciesRaw.forEach((id, raw) {
    if (raw is Map && raw['exchange_rate'] != null) {
      out[id.toString()] = parseMoney(raw['exchange_rate']);
    }
  });
  return out;
}
