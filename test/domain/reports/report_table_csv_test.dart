import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_csv.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_table_model.dart';

Decimal d(String s) => Decimal.parse(s);

const _client = ReportColumn(
  identifier: 'client.name',
  displayLabel: 'Client',
  type: ReportColumnType.string,
);
const _amount = ReportColumn(
  identifier: 'invoice.amount',
  displayLabel: 'Amount',
  type: ReportColumnType.money,
);
const _date = ReportColumn(
  identifier: 'invoice.date',
  displayLabel: 'Date',
  type: ReportColumnType.date,
);
const _rate = ReportColumn(
  identifier: 'invoice.tax_rate1',
  displayLabel: 'Tax Rate',
  type: ReportColumnType.number,
);

ReportRow _row(String client, String amount, [Date? date]) => ReportRow(
  cells: [
    ReportStringCell(value: client, displayValue: client),
    ReportNumberCell(value: d(amount), isMoney: true, displayValue: 'x'),
    ReportDateCell(value: date),
    ReportNumberCell(value: d('7.5')),
  ],
);

ReportView _view(List<ReportRow> rows, [ReportUiState? ui]) =>
    const ReportEngine().compute(
      preview: ReportPreview(
        columns: const [_client, _amount, _date, _rate],
        rows: rows,
      ),
      ui: ui ?? const ReportUiState(),
      exchangeRates: const {},
      companyCurrencyId: '1',
    );

String _kind(ReportTableLine line) => switch (line) {
  ReportTableGroupLine() =>
    '${'  ' * line.depth}[${line.labelKey}] ${line.count}'
        '${line.expanded ? ' open' : ''}',
  ReportTableRowLine() =>
    '${'  ' * line.depth}${(line.row.cells[0] as ReportStringCell).value}',
};

void main() {
  group('table lines', () {
    final rows = [
      _row('Acme', '10', Date(2026, 1, 5)),
      _row('Acme', '20', Date(2026, 2, 5)),
      _row('Birch', '500', Date(2026, 1, 9)),
    ];

    test('ungrouped is the rows', () {
      expect(buildReportTableLines(_view(rows)).map(_kind), [
        'Acme',
        'Acme',
        'Birch',
      ]);
    });

    test('a group opens in place', () {
      final view = _view(rows, const ReportUiState(group: 'client.name'));
      expect(buildReportTableLines(view).map(_kind), ['[Acme] 2', '[Birch] 1']);
      expect(buildReportTableLines(view, expanded: {'Acme'}).map(_kind), [
        '[Acme] 2 open',
        '  Acme',
        '  Acme',
        '[Birch] 1',
      ]);
    });

    test('a grouping split by period nests group → period → rows', () {
      final view = _view(
        rows,
        const ReportUiState(
          group: 'client.name',
          periodColumn: 'invoice.date',
          subgroup: ReportSubgroup.month,
        ),
      );
      final closed = buildReportTableLines(view, splitByPeriod: true);
      expect(closed.map(_kind), ['[Acme] 2', '[Birch] 1']);
      // The parent adds its periods up…
      final acme = closed.first as ReportTableGroupLine;
      expect(acme.totals['invoice.amount'], {'': d('30')});
      // …and is no single bucket, so there is nothing to drill into.
      expect(acme.drillKey, isNull);

      final january = 'Acme${kReportGroupKeySeparator}2026-01-01';
      final open = buildReportTableLines(
        view,
        splitByPeriod: true,
        expanded: {reportTableParentId('Acme'), january},
      );
      expect(open.map(_kind), [
        '[Acme] 2 open',
        '  [2026-01-01] 1 open',
        '    Acme',
        '  [2026-02-01] 1',
        '[Birch] 1',
      ]);
      final period = open[1] as ReportTableGroupLine;
      expect(period.isPeriod, isTrue);
      expect(period.drillKey, january);
    });

    test('a parent id never collides with a bucket key', () {
      // "Acme" + separator + "" is the key of Acme's undated rows.
      expect(
        reportTableParentId('Acme'),
        isNot('Acme$kReportGroupKeySeparator'),
      );
      expect(reportTableParentId('Acme'), isNot('Acme'));
    });
  });

  group('csv', () {
    String label(String key) => key;

    test('writes the visible columns in order, values for a spreadsheet', () {
      final view = _view(
        [_row('Acme', '1234.5', Date(2026, 3, 3))],
        const ReportUiState(
          visibleColumnIds: {'invoice.amount', 'client.name', 'invoice.date'},
          columnOrder: ['invoice.date', 'client.name'],
        ),
      );
      expect(
        buildReportCsv(view: view, groupLabel: label),
        'Date,Client,Amount\r\n'
        '2026-03-03,Acme,1234.5\r\n',
      );
    });

    test('quotes what needs quoting', () {
      final view = _view([_row('Smith, "Bob"\nLtd', '1')]);
      final csv = buildReportCsv(view: view, groupLabel: label);
      expect(csv, contains('"Smith, ""Bob""\nLtd",1,,7.5'));
    });

    test('text that would run as a formula is neutralised', () {
      for (final name in ['=1+1', '+SUM(A1)', '-cmd', '@x']) {
        final csv = buildReportCsv(
          view: _view([_row(name, '-5')]),
          groupLabel: label,
        );
        expect(csv, contains("'$name,"), reason: name);
        // A negative amount is a number and stays one.
        expect(csv, contains(',-5,'), reason: name);
      }
    });

    test('grouped: every row, in group order', () {
      final view = _view([
        _row('Birch', '500'),
        _row('Acme', '10'),
        _row('Acme', '20'),
      ], const ReportUiState(group: 'client.name'));
      final lines = const LineSplitter().convert(
        buildReportCsv(view: view, groupLabel: label),
      );
      expect(lines.skip(1).map((l) => l.split(',').first), [
        'Acme',
        'Acme',
        'Birch',
      ]);
    });

    test('summary: a line per group with its count and totals', () {
      final view = _view([
        _row('Birch', '500'),
        _row('Acme', '10'),
        _row('Acme', '20'),
      ], const ReportUiState(group: 'client.name'));
      expect(
        buildReportCsv(
          view: view,
          groupLabel: (k) => 'Client $k',
          summary: true,
          countLabel: 'Rows',
        ),
        // The rate is not totalled, so it is not a column of the summary.
        'Client,Rows,Amount\r\n'
        'Client Acme,2,30\r\n'
        'Client Birch,1,500\r\n',
      );
    });

    test('other cell types', () {
      const cols = [
        ReportColumn(
          identifier: 'task.duration',
          displayLabel: 'Duration',
          type: ReportColumnType.duration,
        ),
        ReportColumn(
          identifier: 'invoice.is_amount_discount',
          displayLabel: 'Flag',
          type: ReportColumnType.boolean,
        ),
      ];
      final view = const ReportEngine().compute(
        preview: const ReportPreview(
          columns: cols,
          rows: [
            ReportRow(
              cells: [
                ReportDurationCell(seconds: 93784),
                ReportBoolCell(value: true),
              ],
            ),
          ],
        ),
        ui: const ReportUiState(),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      expect(
        buildReportCsv(view: view, groupLabel: label),
        'Duration,Flag\r\n26:03:04,TRUE\r\n',
      );
    });

    test('the file carries a byte-order mark', () {
      final bytes = reportCsvBytes('Ünïcode\r\n');
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.sublist(3)), 'Ünïcode\r\n');
    });
  });
}
