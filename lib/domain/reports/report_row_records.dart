import 'package:intl/intl.dart';

import 'package:admin/data/models/domain/report_definition.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
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

/// The columns of the server's task report that belong to one **time entry**
/// rather than to the task. `TaskExport::iterateLogs` writes a row per entry
/// and fills these from the entry; every other column repeats the task's own
/// value on each of its rows. What [collapsedToRecords] leaves out of its
/// "same task" comparison.
const Set<String> kTaskEntryColumnIds = {
  'task.start_date',
  'task.start_time',
  'task.end_date',
  'task.end_time',
  'task.time_log',
  'task.time_log_duration_words',
  'task.billable',
  'task.item_notes',
};

/// Of [kTaskEntryColumnIds], the ones a merged task row takes from its
/// **last** entry: a task ends when its last entry does. The start columns
/// keep the first row's — the earliest entry, since the server sorts a task's
/// log when it is saved (`TaskRepository::save`).
const Set<String> _kLastEntryColumnIds = {'task.end_date', 'task.end_time'};

/// [preview] with the rows of one record merged into one — see
/// [ReportDefinition.collapsesToRecord].
///
/// Rows group by [ReportRow.recordId]. A result that does not carry ids yet
/// (a report's very first run is a plain one, and the ids follow it) groups
/// **consecutive** rows instead, when every column outside
/// [kTaskEntryColumnIds] reads the same: the server writes a task's entries
/// one after another, so two neighbours that agree on number, description,
/// client and the task's own total are one task. Either way a result reads
/// the same before its ids land and after — the count and the totals must
/// not move when a row becomes a link.
///
/// The merged row is the group's first, with its end date and time taken
/// from the last row that has one.
ReportPreview collapsedToRecords(ReportPreview preview) {
  if (preview.rows.length < 2) return preview;
  final columns = preview.columns;
  final compared = [
    for (var i = 0; i < columns.length; i++)
      if (!kTaskEntryColumnIds.contains(columns[i].identifier)) i,
  ];
  final takeLast = [
    for (var i = 0; i < columns.length; i++)
      if (_kLastEntryColumnIds.contains(columns[i].identifier)) i,
  ];
  String signature(ReportRow row) => [
    for (final i in compared)
      i < row.cells.length ? (row.cells[i].displayValue ?? '') : '',
  ].join('\u001f');

  final groups = <List<ReportRow>>[];
  final byId = <String, List<ReportRow>>{};
  String? lastSignature;
  for (final row in preview.rows) {
    final id = row.recordId;
    if (id != null && id.isNotEmpty) {
      final group = byId[id];
      if (group != null) {
        group.add(row);
      } else {
        groups.add(byId[id] = [row]);
      }
      lastSignature = null;
      continue;
    }
    final sig = signature(row);
    if (sig == lastSignature && groups.isNotEmpty) {
      groups.last.add(row);
    } else {
      groups.add([row]);
    }
    lastSignature = sig;
  }
  if (groups.length == preview.rows.length) return preview;
  return ReportPreview(
    columns: columns,
    rows: [for (final group in groups) _merged(group, takeLast)],
  );
}

ReportRow _merged(List<ReportRow> group, List<int> takeLast) {
  final first = group.first;
  if (group.length == 1 || takeLast.isEmpty) return first;
  final cells = [...first.cells];
  for (final i in takeLast) {
    for (final row in group.reversed) {
      if (i >= row.cells.length) continue;
      final value = row.cells[i].displayValue;
      if (value != null && value.trim().isNotEmpty) {
        cells[i] = row.cells[i];
        break;
      }
    }
  }
  return first.copyWith(cells: cells);
}

/// [preview] without the columns named in [ids] — see
/// [ReportDefinition.hiddenColumnIds].
ReportPreview withoutColumns(ReportPreview preview, Set<String> ids) {
  if (ids.isEmpty) return preview;
  final keep = [
    for (var i = 0; i < preview.columns.length; i++)
      if (!ids.contains(preview.columns[i].identifier)) i,
  ];
  if (keep.length == preview.columns.length) return preview;
  return ReportPreview(
    columns: [for (final i in keep) preview.columns[i]],
    rows: [
      for (final row in preview.rows)
        row.copyWith(
          cells: [
            for (final i in keep)
              if (i < row.cells.length) row.cells[i],
          ],
        ),
    ],
  );
}

/// [preview] with each date cell the decoder could not read re-read in the
/// company's date format ([pattern], a Dart `DateFormat` pattern — the
/// statics' `format_dart` for the company's `date_format_id`).
///
/// The task report writes its dates that way (`TaskExport` formats
/// `task.start_date` with the company's format, not ISO), so on every
/// company but one using `Y-m-d` they arrived unreadable: "Start Date" sorted
/// nowhere and grouped into one blank bucket. Read with `en_US` because PHP's
/// `format()` writes English month and day names whatever the locale — and
/// never with plain `en`, which `intl` does not know until date formatting
/// has been initialised. A value that still does not parse keeps its text.
ReportPreview withCompanyDates(ReportPreview preview, String? pattern) {
  if (pattern == null || pattern.isEmpty) return preview;
  final at = [
    for (var i = 0; i < preview.columns.length; i++)
      if (preview.columns[i].type == ReportColumnType.date) i,
  ];
  if (at.isEmpty) return preview;
  final DateFormat format;
  try {
    format = DateFormat(pattern, 'en_US');
  } on Object {
    return preview;
  }
  var touched = false;
  final rows = [
    for (final row in preview.rows)
      () {
        List<ReportCell>? cells;
        for (final i in at) {
          if (i >= row.cells.length) continue;
          final cell = row.cells[i];
          if (cell is! ReportDateCell || cell.value != null) continue;
          final text = cell.displayValue?.trim() ?? '';
          if (text.isEmpty) continue;
          final DateTime parsed;
          try {
            parsed = format.parseStrict(text);
          } on Object {
            // Not just a FormatException: a value the pattern half-reads can
            // fail any way, and one cell must not take the report with it.
            continue;
          }
          cells ??= [...row.cells];
          cells[i] = ReportDateCell(
            value: Date(parsed.year, parsed.month, parsed.day),
            entityWire: cell.entityWire,
            entityId: cell.entityId,
            displayValue: cell.displayValue,
          );
        }
        if (cells == null) return row;
        touched = true;
        return row.copyWith(cells: cells);
      }(),
  ];
  return touched
      ? ReportPreview(columns: preview.columns, rows: rows)
      : preview;
}
