import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';

/// [preview] with its row-id column ([ReportDefinition.rowIdKey]) taken out
/// of the table and onto the rows, as [ReportRow.recordId] /
/// [ReportRow.recordWire].
///
/// The id is fetched as an ordinary column because that is the only way the
/// export will send it, but it is not one: it must not be offered in the
/// column picker, grouped by, searched, exported or totalled. Removing it
/// here — the one place a preview lands — is what keeps it out of all of
/// those at once, rather than each of them remembering to skip it.
///
/// A row whose id cell is blank keeps no record (the server answers a key it
/// does not know with an empty string). Returns [preview] itself when the
/// report declares no key or the answer does not carry the column.
ReportPreview withRowRecords(
  ReportPreview preview,
  ReportDefinition definition,
) {
  final key = definition.rowIdKey;
  if (key == null) return preview;
  final index = preview.columns.indexWhere((c) => c.identifier == key);
  if (index < 0) return preview;
  final wire = definition.rowRecordWire;
  return ReportPreview(
    columns: [
      for (var i = 0; i < preview.columns.length; i++)
        if (i != index) preview.columns[i],
    ],
    rows: [for (final row in preview.rows) _withRecord(row, index, wire)],
  );
}

ReportRow _withRecord(ReportRow row, int index, String? wire) {
  String? id;
  if (index < row.cells.length) {
    final cell = row.cells[index];
    final raw = cell is ReportStringCell
        ? (cell.value ?? cell.displayValue)
        : cell.displayValue;
    final trimmed = raw?.trim();
    if (trimmed != null && trimmed.isNotEmpty) id = trimmed;
  }
  return ReportRow(
    cells: [
      for (var i = 0; i < row.cells.length; i++)
        if (i != index) row.cells[i],
    ],
    recordWire: id == null ? null : wire,
    recordId: id,
    currencyId: row.currencyId,
  );
}

/// [preview] with each column's aggregation set from the report's row grain:
/// a quantity that belongs to the row's parent record, and so repeats on
/// every one of that record's rows, becomes
/// [ReportAggregation.oncePerRecord].
///
/// On a line-item report ([ReportDefinition.lineItemPrefix]) that is every
/// quantity not on the line itself — the invoice's amount, balance, taxes —
/// plus anything in [ReportDefinition.oncePerRecordColumnIds]. A column that
/// is not totalled at all (a rate) stays that way, and an explicit
/// aggregation already on a column is left alone.
ReportPreview withRowGrain(ReportPreview preview, ReportDefinition definition) {
  final linePrefix = definition.lineItemPrefix;
  final explicit = definition.oncePerRecordColumnIds;
  if (linePrefix == null && explicit.isEmpty) return preview;
  var touched = false;
  final columns = [
    for (final column in preview.columns)
      if (column.aggregation == null &&
          column.effectiveAggregation == ReportAggregation.sum &&
          _repeatsPerRecord(column.identifier, linePrefix, explicit))
        () {
          touched = true;
          return column.copyWith(aggregation: ReportAggregation.oncePerRecord);
        }()
      else
        column,
  ];
  if (!touched) return preview;
  return ReportPreview(columns: columns, rows: preview.rows);
}

bool _repeatsPerRecord(
  String identifier,
  String? linePrefix,
  Set<String> explicit,
) {
  if (explicit.contains(identifier)) return true;
  if (linePrefix == null) return false;
  final dot = identifier.indexOf('.');
  // An unprefixed key belongs to the row's own entity.
  if (dot < 0) return false;
  return identifier.substring(0, dot) != linePrefix;
}

/// [preview] with the columns named in [ids] turned to plain text: the
/// column's type becomes a string and each of its cells the string the
/// server wrote. See [ReportDefinition.textColumnIds].
ReportPreview withTextColumns(ReportPreview preview, Set<String> ids) {
  if (ids.isEmpty) return preview;
  final at = <int>[
    for (var i = 0; i < preview.columns.length; i++)
      if (ids.contains(preview.columns[i].identifier) &&
          preview.columns[i].type != ReportColumnType.string)
        i,
  ];
  if (at.isEmpty) return preview;
  return ReportPreview(
    columns: [
      for (var i = 0; i < preview.columns.length; i++)
        at.contains(i)
            ? preview.columns[i].copyWith(type: ReportColumnType.string)
            : preview.columns[i],
    ],
    rows: [
      for (final row in preview.rows)
        row.copyWith(
          cells: [
            for (var i = 0; i < row.cells.length; i++)
              at.contains(i)
                  ? ReportStringCell(
                      value: row.cells[i].displayValue,
                      displayValue: row.cells[i].displayValue,
                      entityWire: row.cells[i].entityWire,
                      entityId: row.cells[i].entityId,
                    )
                  : row.cells[i],
          ],
        ),
    ],
  );
}
