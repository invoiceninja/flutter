import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';

Decimal d(String s) => Decimal.parse(s);

const _client = ReportColumn(
  identifier: 'client.name',
  displayLabel: 'Client',
  type: ReportColumnType.string,
);
const _status = ReportColumn(
  identifier: 'invoice.status',
  displayLabel: 'Status',
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
  displayLabel: 'Rate',
  type: ReportColumnType.number,
);

ReportRow _row(
  String client,
  String status,
  String amount, {
  Date? date,
  String? currency,
}) => ReportRow(
  currencyId: currency,
  cells: [
    ReportStringCell(value: client, displayValue: client),
    ReportStringCell(value: status, displayValue: status),
    ReportNumberCell(value: d(amount), isMoney: true, displayValue: amount),
    ReportDateCell(value: date),
    ReportNumberCell(value: d('7.5')),
  ],
);

ReportPreview _preview(List<ReportRow> rows) => ReportPreview(
  columns: const [_client, _status, _amount, _date, _rate],
  rows: rows,
);

ReportView _compute(ReportPreview preview, ReportUiState ui) =>
    const ReportEngine().compute(
      preview: preview,
      ui: ui,
      exchangeRates: const {},
      companyCurrencyId: '1',
    );

List<String> _clients(ReportView v) => [
  for (final r in v.rows) (r.cells[0] as ReportStringCell).value!,
];

void main() {
  group('a further sort breaks the ties of the first', () {
    final preview = _preview([
      _row('Birch', 'Sent', '50'),
      _row('Acme', 'Paid', '10'),
      _row('Cedar', 'Sent', '20'),
      _row('Dune', 'Paid', '30'),
    ]);

    test('status, then amount descending', () {
      final view = _compute(
        preview,
        const ReportUiState(
          sortField: 'invoice.status',
          thenBy: [ReportSort('invoice.amount', ascending: false)],
        ),
      );
      expect(_clients(view), ['Dune', 'Acme', 'Birch', 'Cedar']);
    });

    test('an unknown or repeated key is ignored', () {
      final view = _compute(
        preview,
        const ReportUiState(
          sortField: 'invoice.status',
          thenBy: [
            ReportSort('no.such.column'),
            ReportSort('invoice.status', ascending: false),
            ReportSort('client.name'),
          ],
        ),
      );
      expect(_clients(view), ['Acme', 'Dune', 'Birch', 'Cedar']);
    });

    test('with no primary key the further ones still apply', () {
      final view = _compute(
        preview,
        const ReportUiState(thenBy: [ReportSort('client.name')]),
      );
      expect(_clients(view), ['Acme', 'Birch', 'Cedar', 'Dune']);
    });
  });

  group('row search', () {
    final preview = _preview([
      _row('Acme Ltd', 'Paid', '10'),
      _row('Birch', 'Sent', '1250'),
      _row('Cedar', 'Draft', '20'),
    ]);

    test('matches any cell, ignoring case', () {
      expect(_clients(_compute(preview, const ReportUiState(search: 'ACME'))), [
        'Acme Ltd',
      ]);
      expect(_clients(_compute(preview, const ReportUiState(search: 'sent'))), [
        'Birch',
      ]);
      // A number is searched as the text the server sent for it.
      expect(_clients(_compute(preview, const ReportUiState(search: '125'))), [
        'Birch',
      ]);
    });

    test('a hidden column is still searched', () {
      final view = _compute(
        preview,
        const ReportUiState(search: 'draft', visibleColumnIds: {'client.name'}),
      );
      expect(_clients(view), ['Cedar']);
    });

    test('blank searches nothing', () {
      expect(
        _compute(preview, const ReportUiState(search: '  ')).rows,
        hasLength(3),
      );
    });

    test('narrows the totals and the groups with the rows', () {
      final view = _compute(
        preview,
        const ReportUiState(search: 'birch', group: 'invoice.status'),
      );
      expect(view.groups.map((g) => g.key), ['Sent']);
      expect(view.grandTotalsByCurrency['invoice.amount'], {'': d('1250')});
      expect(view.totalRowCount, 1);
    });

    test('is part of the state the view is memoised on', () {
      expect(
        const ReportUiState(search: 'a') == const ReportUiState(search: 'b'),
        isFalse,
      );
      expect(
        const ReportUiState(search: 'a').hashCode,
        const ReportUiState(search: 'a').hashCode,
      );
    });
  });

  group('a one-of filter', () {
    final preview = _preview([
      _row('Acme', 'Paid', '10'),
      _row('Birch', 'Sent', '20'),
      _row('Cedar', 'Draft', '30'),
      _row('Dune', '', '40'),
    ]);

    test('keeps the rows showing one of the values', () {
      final view = _compute(
        preview,
        ReportUiState(
          columnFilters: {
            'invoice.status': reportOneOfFilter(['Paid', 'Draft']),
          },
        ),
      );
      expect(_clients(view), ['Acme', 'Cedar']);
    });

    test('matches the whole value, not a part of it', () {
      // A typed "Paid" would also match "Unpaid"; picking it must not.
      final p = _preview([
        _row('Acme', 'Paid', '10'),
        _row('Birch', 'Unpaid', '20'),
      ]);
      final view = _compute(
        p,
        ReportUiState(
          columnFilters: {
            'invoice.status': reportOneOfFilter(['Paid']),
          },
        ),
      );
      expect(_clients(view), ['Acme']);
    });

    test('a blank entry matches an empty cell', () {
      final view = _compute(
        preview,
        ReportUiState(
          columnFilters: {
            'invoice.status': reportOneOfFilter(['']),
          },
        ),
      );
      expect(_clients(view), ['Dune']);
    });

    test('round-trips its values', () {
      final filter = reportOneOfFilter(['A, B', 'C "quoted"', '']);
      expect(reportOneOfFilterValues(filter), {'A, B', 'C "quoted"', ''});
    });

    test('a value that is not one is plain text', () {
      expect(reportOneOfFilterValues('Paid'), isNull);
      expect(reportOneOfFilterValues('in:not json'), isNull);
      expect(reportOneOfFilterValues('in:{"a":1}'), isNull);
    });
  });

  group('groups follow the sort', () {
    final preview = _preview([
      _row('Acme', 'Paid', '10'),
      _row('Birch', 'Paid', '500'),
      _row('Birch', 'Sent', '25'),
      _row('Cedar', 'Sent', '60'),
    ]);

    List<String> keys(ReportUiState ui) => [
      for (final g in _compute(preview, ui).groups) g.key,
    ];

    test('alphabetical by default', () {
      expect(keys(const ReportUiState(group: 'client.name')), [
        'Acme',
        'Birch',
        'Cedar',
      ]);
    });

    test('by the sorted amount, in its direction', () {
      // It used to stay alphabetical while the header arrow sat on Amount.
      expect(
        keys(
          const ReportUiState(
            group: 'client.name',
            sortField: 'invoice.amount',
            sortAscending: false,
          ),
        ),
        ['Birch', 'Cedar', 'Acme'],
      );
      expect(
        keys(
          const ReportUiState(
            group: 'client.name',
            sortField: 'invoice.amount',
          ),
        ),
        ['Acme', 'Cedar', 'Birch'],
      );
    });

    test('by the group column itself, descending', () {
      expect(
        keys(
          const ReportUiState(
            group: 'client.name',
            sortField: 'client.name',
            sortAscending: false,
          ),
        ),
        ['Cedar', 'Birch', 'Acme'],
      );
    });

    test('a column that is not totalled does not reorder the groups', () {
      expect(
        keys(
          const ReportUiState(
            group: 'client.name',
            sortField: 'invoice.tax_rate1',
            sortAscending: false,
          ),
        ),
        ['Acme', 'Birch', 'Cedar'],
      );
    });

    test('ranks in the chosen currency; a group without it goes last', () {
      final p = _preview([
        _row('Acme', 'Paid', '10', currency: 'usd'),
        _row('Birch', 'Paid', '900', currency: 'eur'),
        _row('Cedar', 'Paid', '60', currency: 'usd'),
      ]);
      final view = _compute(
        p,
        const ReportUiState(
          group: 'client.name',
          sortField: 'invoice.amount',
          sortAscending: false,
          currencyId: 'usd',
        ),
      );
      expect(view.groups.map((g) => g.key), ['Cedar', 'Acme', 'Birch']);
    });

    test('split by period, whole groups are ranked and kept together', () {
      final p = _preview([
        _row('Acme', 'Paid', '10', date: Date(2026, 1, 5)),
        _row('Acme', 'Paid', '20', date: Date(2026, 2, 5)),
        _row('Birch', 'Paid', '500', date: Date(2026, 2, 9)),
        _row('Birch', 'Paid', '1', date: Date(2026, 1, 9)),
      ]);
      final view = _compute(
        p,
        const ReportUiState(
          group: 'client.name',
          periodColumn: 'invoice.date',
          subgroup: ReportSubgroup.month,
          sortField: 'invoice.amount',
          sortAscending: false,
        ),
      );
      // Birch (501) before Acme (30); each one's months stay chronological.
      expect(view.groups.map((g) => g.key), [
        'Birch${kReportGroupKeySeparator}2026-01-01',
        'Birch${kReportGroupKeySeparator}2026-02-01',
        'Acme${kReportGroupKeySeparator}2026-01-01',
        'Acme${kReportGroupKeySeparator}2026-02-01',
      ]);
    });

    test('a date grouping can run newest first', () {
      final p = _preview([
        _row('Acme', 'Paid', '10', date: Date(2026, 1, 5)),
        _row('Acme', 'Paid', '20', date: Date(2026, 3, 5)),
      ]);
      final view = _compute(
        p,
        const ReportUiState(
          group: 'invoice.date',
          subgroup: ReportSubgroup.month,
          sortField: 'invoice.date',
          sortAscending: false,
        ),
      );
      expect(view.groups.map((g) => g.key), ['2026-03-01', '2026-01-01']);
    });
  });
}
