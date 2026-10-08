import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_preview.dart';
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

    test('the task report counts the estimate once per task', () {
      // `TaskExport` emits a row per time-log entry, each with the task's
      // own estimate on it.
      final p = withRowGrain(
        ReportPreview(
          columns: [_col('task.duration'), _col('task.estimated_duration')],
          rows: const [],
        ),
        reportDefinitionFor('task'),
      );
      expect(p.columns[0].effectiveAggregation, ReportAggregation.sum);
      expect(
        p.columns[1].effectiveAggregation,
        ReportAggregation.oncePerRecord,
      );
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
}
