import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_registry.dart';
import 'package:admin/domain/reports/report_row_records.dart';

ReportColumn _col(String id) =>
    ReportColumn(identifier: id, displayLabel: id, type: inferColumnType(id));

ReportNumberCell _money(int v) =>
    ReportNumberCell(value: Decimal.fromInt(v), isMoney: true);

void main() {
  group('withRowRecords', () {
    final invoice = reportDefinitionFor('invoice');

    ReportPreview withId() => ReportPreview(
      columns: [
        _col('client.name'),
        _col('invoice.number'),
        _col('invoice.id'),
      ],
      rows: [
        ReportRow(
          currencyId: '3',
          cells: const [
            ReportStringCell(value: 'Zemlak', entityId: 'mxkazYeJ0P'),
            ReportStringCell(value: '0001'),
            ReportStringCell(value: 'VolejRejNm', displayValue: 'VolejRejNm'),
          ],
        ),
      ],
    );

    test('moves the id off the table and onto the row', () {
      final p = withRowRecords(withId(), invoice);
      expect(p.columns.map((c) => c.identifier), [
        'client.name',
        'invoice.number',
      ]);
      final row = p.rows.single;
      expect(row.cells, hasLength(2));
      expect(row.recordId, 'VolejRejNm');
      expect(row.recordWire, 'invoice');
      // What the row already knew is kept.
      expect(row.currencyId, '3');
      // And a related cell keeps its own id — the client's, not the row's.
      expect(row.cells.first.entityId, 'mxkazYeJ0P');
    });

    test('a blank id leaves the row with no record', () {
      // An export that does not know the key answers with an empty cell.
      final p = withRowRecords(
        ReportPreview(
          columns: [_col('invoice.number'), _col('invoice.id')],
          rows: const [
            ReportRow(
              cells: [
                ReportStringCell(value: '0001'),
                ReportStringCell(value: ''),
              ],
            ),
          ],
        ),
        invoice,
      );
      expect(p.rows.single.recordId, isNull);
      expect(p.rows.single.recordWire, isNull);
      expect(p.columns, hasLength(1));
    });

    test('a preview without the column is returned untouched', () {
      final p = ReportPreview(
        columns: [_col('invoice.number')],
        rows: const [
          ReportRow(cells: [ReportStringCell(value: '0001')]),
        ],
      );
      expect(identical(withRowRecords(p, invoice), p), isTrue);
    });

    test('a line-item row is its parent document', () {
      final p = withRowRecords(
        ReportPreview(
          columns: [_col('item.product_key'), _col('invoice.id')],
          rows: const [
            ReportRow(
              cells: [
                ReportStringCell(value: 'Widget'),
                ReportStringCell(value: 'inv25'),
              ],
            ),
          ],
        ),
        reportDefinitionFor('invoice_item'),
      );
      expect(p.rows.single.recordWire, 'invoice');
      expect(p.rows.single.recordId, 'inv25');
    });

    test('the product report asks for the hashed id by name', () {
      // `product.id` answers the raw integer primary key (probed live).
      expect(reportDefinitionFor('product').rowIdKey, 'product.hashed_id');
    });
  });

  group('withRowGrain', () {
    test('on a line-item report the document quantities count once', () {
      final p = withRowGrain(
        ReportPreview(
          columns: [
            _col('invoice.amount'),
            _col('invoice.balance'),
            _col('invoice.tax_rate1'),
            _col('invoice.number'),
            _col('item.line_total'),
            _col('item.quantity'),
            _col('item.cost'),
          ],
          rows: const [],
        ),
        reportDefinitionFor('invoice_item'),
      );
      final byId = {
        for (final c in p.columns) c.identifier: c.effectiveAggregation,
      };
      expect(byId, {
        'invoice.amount': ReportAggregation.oncePerRecord,
        'invoice.balance': ReportAggregation.oncePerRecord,
        // A rate was never totalled and still is not.
        'invoice.tax_rate1': ReportAggregation.none,
        'invoice.number': ReportAggregation.none,
        // The line's own figures are plain sums.
        'item.line_total': ReportAggregation.sum,
        'item.quantity': ReportAggregation.sum,
        'item.cost': ReportAggregation.none,
      });
    });

    test('every line-item report declares its line prefix', () {
      for (final id in const [
        'invoice_item',
        'quote_item',
        'purchase_order_item',
        'recurring_invoice_item',
      ]) {
        expect(reportDefinitionFor(id).lineItemPrefix, 'item', reason: id);
      }
    });

    test('a plain report is returned untouched', () {
      final p = ReportPreview(
        columns: [_col('invoice.amount')],
        rows: [
          ReportRow(cells: [_money(1)]),
        ],
      );
      expect(
        identical(withRowGrain(p, reportDefinitionFor('invoice')), p),
        isTrue,
      );
    });

    test('a row id key always comes with the record it names', () {
      for (final d in kReportDefinitions) {
        expect(
          d.rowIdKey == null,
          d.rowRecordWire == null,
          reason: '${d.identifier}: rowIdKey and rowRecordWire go together',
        );
      }
    });
  });

  group('collapsedToRecords', () {
    // The server's task report, as `TaskExport::iterateLogs` writes it: a row
    // per time entry, the task's own columns repeated on each — its whole
    // duration among them.
    final columns = [
      _col('task.number'),
      _col('client.name'),
      _col('task.duration'),
      _col('task.start_date'),
      _col('task.end_date'),
      _col('task.time_log'),
    ];
    ReportRow entry(
      String number,
      int total,
      String start,
      String end,
      int seconds, {
      String? id,
    }) => ReportRow(
      recordWire: id == null ? null : 'task',
      recordId: id,
      cells: [
        ReportStringCell(value: number, displayValue: number),
        const ReportStringCell(value: 'Acme', displayValue: 'Acme'),
        ReportDurationCell(seconds: total, displayValue: '$total'),
        ReportDateCell(displayValue: start),
        ReportDateCell(displayValue: end),
        ReportStringCell(value: '$seconds', displayValue: '$seconds'),
      ],
    );

    int totalOf(ReportPreview p) => p.rows.fold(
      0,
      (sum, r) => sum + ((r.cells[2] as ReportDurationCell).seconds ?? 0),
    );

    test('a three-entry task is one row, its duration counted once', () {
      // Regression: the Tasks headline summed 3 × 10800 for three hours.
      final p = collapsedToRecords(
        ReportPreview(
          columns: columns,
          rows: [
            entry('0001', 10800, '01/Oct', '01/Oct', 3600, id: 't1'),
            entry('0001', 10800, '02/Oct', '02/Oct', 3600, id: 't1'),
            entry('0001', 10800, '03/Oct', '04/Oct', 3600, id: 't1'),
            entry('0002', 1800, '05/Oct', '05/Oct', 1800, id: 't2'),
          ],
        ),
      );
      expect(p.rows, hasLength(2));
      expect(totalOf(p), 10800 + 1800);
      // Started with its first entry, ended with its last.
      expect(p.rows.first.cells[3].displayValue, '01/Oct');
      expect(p.rows.first.cells[4].displayValue, '04/Oct');
      expect(p.rows.first.recordId, 't1');
    });

    test('before the ids arrive, neighbours that agree are one task', () {
      final plain = collapsedToRecords(
        ReportPreview(
          columns: columns,
          rows: [
            entry('0001', 10800, '01/Oct', '01/Oct', 3600),
            entry('0001', 10800, '02/Oct', '02/Oct', 3600),
            entry('0001', 10800, '03/Oct', '04/Oct', 3600),
            entry('0002', 1800, '05/Oct', '05/Oct', 1800),
          ],
        ),
      );
      final withIds = collapsedToRecords(
        ReportPreview(
          columns: columns,
          rows: [
            entry('0001', 10800, '01/Oct', '01/Oct', 3600, id: 't1'),
            entry('0001', 10800, '02/Oct', '02/Oct', 3600, id: 't1'),
            entry('0001', 10800, '03/Oct', '04/Oct', 3600, id: 't1'),
            entry('0002', 1800, '05/Oct', '05/Oct', 1800, id: 't2'),
          ],
        ),
      );
      // The count and the total must not move when a row becomes a link.
      expect(plain.rows, hasLength(withIds.rows.length));
      expect(totalOf(plain), totalOf(withIds));
    });

    test('an end left blank on the last entry keeps an earlier one', () {
      final p = collapsedToRecords(
        ReportPreview(
          columns: columns,
          rows: [
            entry('0001', 7200, '01/Oct', '01/Oct', 3600, id: 't1'),
            entry('0001', 7200, '02/Oct', '', 3600, id: 't1'),
          ],
        ),
      );
      expect(p.rows.single.cells[4].displayValue, '01/Oct');
    });

    test('rows of different tasks are never merged', () {
      final p = ReportPreview(
        columns: columns,
        rows: [
          entry('0001', 3600, '01/Oct', '01/Oct', 3600),
          entry('0002', 3600, '01/Oct', '01/Oct', 3600),
        ],
      );
      expect(identical(collapsedToRecords(p), p), isTrue);
    });

    test('only the task report collapses', () {
      for (final d in kReportDefinitions) {
        expect(
          d.collapsesToRecord,
          d.identifier == 'task',
          reason: '${d.identifier}: a line-item report is a row per line',
        );
      }
    });
  });

  group('withoutColumns', () {
    test('drops the columns and their cells', () {
      final p = withoutColumns(
        ReportPreview(
          columns: [_col('task.number'), _col('task.time_log')],
          rows: const [
            ReportRow(
              cells: [
                ReportStringCell(value: '0001', displayValue: '0001'),
                ReportStringCell(value: '60', displayValue: '60'),
              ],
            ),
          ],
        ),
        reportDefinitionFor('task').hiddenColumnIds,
      );
      expect(p.columns.map((c) => c.identifier), ['task.number']);
      expect(p.rows.single.cells, hasLength(1));
    });
  });

  group('withCompanyDates', () {
    ReportPreview dates(String text) => ReportPreview(
      columns: [_col('task.start_date')],
      rows: [
        ReportRow(cells: [ReportDateCell(displayValue: text)]),
      ],
    );
    Date? read(String text, String pattern) =>
        (withCompanyDates(dates(text), pattern).rows.single.cells.single
                as ReportDateCell)
            .value;

    test('reads a date the task report wrote in the company format', () {
      // The fourteen seeded formats (`DateFormatsSeeder`: PHP `format` and
      // its `format_dart`), each as PHP writes 8 October 2026 — a day that
      // shows which of them pad it.
      const samples = {
        'dd/MMM/yyyy': '08/Oct/2026', // d/M/Y
        'dd-MMM-yyyy': '08-Oct-2026', // d-M-Y
        'dd/MMMM/yyyy': '08/October/2026', // d/F/Y
        'dd-MMMM-yyyy': '08-October-2026', // d-F-Y
        'MMM d, yyyy': 'Oct 8, 2026', // M j, Y
        'MMMM d, yyyy': 'October 8, 2026', // F j, Y
        'EEE MMM d, yyyy': 'Thu Oct 8, 2026', // D M j, Y
        'yyyy-MM-dd': '2026-10-08', // Y-m-d
        'dd-MM-yyyy': '08-10-2026', // d-m-Y
        'MM/dd/yyyy': '10/08/2026', // m/d/Y
        'dd.MM.yyyy': '08.10.2026', // d.m.Y
        'd. MMM. yyyy': '8. Oct. 2026', // j. M. Y
        'd. MMMM yyyy': '8. October 2026', // j. F Y
        'dd/MM/yyyy': '08/10/2026', // d/m/Y
      };
      for (final MapEntry(key: pattern, value: text) in samples.entries) {
        expect(read(text, pattern), Date(2026, 10, 8), reason: pattern);
      }
    });

    test('a value that does not parse keeps its text, and no pattern '
        'changes nothing', () {
      expect(read('not a date', 'dd/MM/yyyy'), isNull);
      final p = dates('18/10/2026');
      expect(identical(withCompanyDates(p, null), p), isTrue);
    });
  });
}
