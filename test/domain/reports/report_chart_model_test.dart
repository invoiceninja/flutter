import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/reports/report_chart_model.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_measures.dart';

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

ReportRow _row(String client, String amount, [Date? date]) => ReportRow(
  cells: [
    ReportStringCell(value: client, displayValue: client),
    ReportNumberCell(value: d(amount), isMoney: true),
    ReportDateCell(value: date),
  ],
);

const _engine = ReportEngine();

ReportView _view(List<ReportRow> rows, ReportUiState ui) => _engine.compute(
  preview: ReportPreview(columns: const [_client, _amount, _date], rows: rows),
  ui: ui,
  exchangeRates: const {},
  companyCurrencyId: '1',
);

List<String> _months(String a, String b) =>
    _engine.dateBucketSpan(a, b, ReportSubgroup.month);

void main() {
  test('a date grouping is a time series with its gaps filled', () {
    final view = _view(
      [
        _row('Acme', '300', Date(2026, 1, 5)),
        _row('Acme', '200', Date(2026, 3, 9)),
      ],
      const ReportUiState(
        group: 'invoice.date',
        subgroup: ReportSubgroup.month,
      ),
    );
    final chart =
        ReportChartModels.build(
              view: view,
              measureId: 'invoice.amount',
              currencyId: '',
              groupColumn: _date,
              splitByPeriod: false,
              fillSpan: _months,
            )
            as ReportTimeSeriesChart;
    expect(chart.points.map((p) => p.key), [
      '2026-01-01',
      '2026-02-01',
      '2026-03-01',
    ]);
    expect(chart.points.map((p) => p.value), [d('300'), d('0'), d('200')]);
    // February was invented by the fill: nothing to drill into.
    expect(chart.points.map((p) => p.hasRows), [true, false, true]);
    expect(chart.peakIndex, 0);
    expect(chart.latestIndex, 2);
  });

  test('cumulative is a running total', () {
    final view = _view(
      [
        _row('Acme', '300', Date(2026, 1, 5)),
        _row('Acme', '200', Date(2026, 2, 9)),
      ],
      const ReportUiState(
        group: 'invoice.date',
        subgroup: ReportSubgroup.month,
      ),
    );
    final chart =
        ReportChartModels.build(
              view: view,
              measureId: 'invoice.amount',
              currencyId: '',
              groupColumn: _date,
              splitByPeriod: false,
              cumulative: true,
            )
            as ReportTimeSeriesChart;
    expect(chart.points.map((p) => p.value), [d('300'), d('500')]);
    expect(chart.peakIndex, -1);
  });

  test('a category grouping is ranked, with the tail folded into Other', () {
    final view = _view([
      for (var i = 1; i <= 12; i++) _row('C$i', '${i * 10}'),
    ], const ReportUiState(group: 'client.name'));
    final chart =
        ReportChartModels.build(
              view: view,
              measureId: 'invoice.amount',
              currencyId: '',
              groupColumn: _client,
              splitByPeriod: false,
              rankedLimit: 10,
            )
            as ReportRankedChart;
    expect(chart.items, hasLength(11));
    expect(chart.items.first.key, 'C12');
    expect(chart.items.first.value, d('120'));
    final other = chart.items.last;
    expect(other.isOther, isTrue);
    expect(other.count, 2);
    expect(other.value, d('30'));
    expect(chart.total, d('780'));
    final shares = chart.items.fold<double>(0, (a, i) => a + (i.share ?? 0));
    expect(shares, closeTo(1, 1e-9));
  });

  test('the count measure ranks by rows', () {
    final view = _view([
      _row('Acme', '1'),
      _row('Birch', '1'),
      _row('Birch', '1'),
    ], const ReportUiState(group: 'client.name'));
    final chart =
        ReportChartModels.build(
              view: view,
              measureId: kReportCountSeriesId,
              currencyId: '',
              groupColumn: _client,
              splitByPeriod: false,
            )
            as ReportRankedChart;
    expect(chart.items.map((i) => (i.key, i.value)), [
      ('Birch', d('2')),
      ('Acme', d('1')),
    ]);
  });

  test('an ungrouped report ranks its own rows, and folds nothing', () {
    final view = _view([
      for (var i = 1; i <= 12; i++) _row('C$i', '${i * 10}'),
    ], const ReportUiState());
    final chart =
        ReportChartModels.build(
              view: view,
              measureId: 'invoice.amount',
              currencyId: '',
              groupColumn: null,
              splitByPeriod: false,
            )
            as ReportRankedChart;
    expect(chart.fromRows, isTrue);
    expect(chart.items, hasLength(10));
    expect(chart.items.any((i) => i.isOther), isFalse);
    expect(chart.items.first.row, isNotNull);
    expect(chart.labelCellIndex, 0);
  });

  test('split by period: the largest groups are series; colours stick', () {
    final rows = [
      _row('Acme', '10', Date(2026, 1, 5)),
      _row('Acme', '20', Date(2026, 3, 5)),
      _row('Birch', '500', Date(2026, 1, 9)),
      _row('Cedar', '5', Date(2026, 3, 9)),
    ];
    const ui = ReportUiState(
      group: 'client.name',
      periodColumn: 'invoice.date',
      subgroup: ReportSubgroup.month,
    );
    final slots = <String, int>{};
    final chart =
        ReportChartModels.build(
              view: _view(rows, ui),
              measureId: 'invoice.amount',
              currencyId: '',
              groupColumn: _client,
              splitByPeriod: true,
              fillSpan: _months,
              seriesLimit: 2,
              slots: slots,
            )
            as ReportPivotChart;
    expect(chart.periods, ['2026-01-01', '2026-02-01', '2026-03-01']);
    expect(chart.series.map((s) => s.key), ['Birch', 'Acme', '']);
    expect(chart.series[0].values, [d('500'), d('0'), d('0')]);
    expect(chart.series[1].values, [d('10'), d('0'), d('20')]);
    expect(chart.series[2].isOther, isTrue);
    expect(chart.series[2].slot, -1);
    expect(slots, {'Birch': 0, 'Acme': 1});

    // Birch filtered away: Acme keeps its colour instead of taking Birch's.
    final narrowed =
        ReportChartModels.build(
              view: _view(rows.where((r) => r != rows[2]).toList(), ui),
              measureId: 'invoice.amount',
              currencyId: '',
              groupColumn: _client,
              splitByPeriod: true,
              seriesLimit: 2,
              slots: slots,
            )
            as ReportPivotChart;
    expect(narrowed.series.map((s) => (s.key, s.slot)), [
      ('Acme', 1),
      ('Cedar', 0),
    ]);
  });

  group('compared with the period before', () {
    const byMonth = ReportUiState(
      group: 'invoice.date',
      subgroup: ReportSubgroup.month,
    );

    // The counterpart of a 2026 month is the same month of 2025.
    String? yearBefore(String key) {
      final date = Date.tryParse(key);
      return date == null ? null : Date(date.year - 1, date.month, 1).toIso();
    }

    test('each point is paired with its place in the earlier period, not '
        'with whatever sits at the same index', () {
      // This year's rows start in March; last year's in January. By index,
      // March would be set against January.
      final current = _view([
        _row('Acme', '300', Date(2026, 3, 5)),
        _row('Acme', '500', Date(2026, 4, 9)),
      ], byMonth);
      final previous = _view([
        _row('Acme', '90', Date(2025, 1, 5)),
        _row('Acme', '100', Date(2025, 3, 5)),
        _row('Acme', '250', Date(2025, 4, 9)),
      ], byMonth);
      final chart =
          ReportChartModels.build(
                view: current,
                measureId: 'invoice.amount',
                currencyId: '',
                groupColumn: _date,
                splitByPeriod: false,
                fillSpan: _months,
                previous: previous,
                previousPeriodOf: yearBefore,
              )
              as ReportTimeSeriesChart;
      expect(chart.points.map((p) => p.key), ['2026-03-01', '2026-04-01']);
      expect(chart.previous, [d('100'), d('250')]);
      expect(chart.hasPrevious, isTrue);
    });

    test('an earlier month with no rows is a real zero; a month with no '
        'counterpart is nothing', () {
      final current = _view([
        _row('Acme', '300', Date(2026, 1, 5)),
        _row('Acme', '500', Date(2026, 2, 9)),
        _row('Acme', '700', Date(2026, 3, 9)),
      ], byMonth);
      final previous = _view([_row('Acme', '90', Date(2025, 1, 5))], byMonth);
      final chart =
          ReportChartModels.build(
                view: current,
                measureId: 'invoice.amount',
                currencyId: '',
                groupColumn: _date,
                splitByPeriod: false,
                fillSpan: _months,
                previous: previous,
                // The earlier window ended in February: March has no
                // counterpart at all.
                previousPeriodOf: (key) =>
                    key == '2026-03-01' ? null : yearBefore(key),
              )
              as ReportTimeSeriesChart;
      expect(chart.previous, [d('90'), Decimal.zero, null]);
    });

    test('without a comparison there is no earlier series', () {
      final current = _view([_row('Acme', '300', Date(2026, 1, 5))], byMonth);
      final chart =
          ReportChartModels.build(
                view: current,
                measureId: 'invoice.amount',
                currencyId: '',
                groupColumn: _date,
                splitByPeriod: false,
                fillSpan: _months,
              )
              as ReportTimeSeriesChart;
      expect(chart.previous, isEmpty);
      expect(chart.hasPrevious, isFalse);
    });

    test(
      'a ranked group carries what it came to before; a new one, nothing',
      () {
        const byClient = ReportUiState(group: 'client.name');
        final current = _view([
          _row('Acme', '300'),
          _row('Birch', '120'),
        ], byClient);
        final previous = _view([_row('Acme', '200')], byClient);
        final chart =
            ReportChartModels.build(
                  view: current,
                  measureId: 'invoice.amount',
                  currencyId: '',
                  groupColumn: _client,
                  splitByPeriod: false,
                  previous: previous,
                )
                as ReportRankedChart;
        final byKey = {for (final i in chart.items) i.key: i.previous};
        expect(byKey['Acme'], d('200'));
        // Not zero: there is no "+∞%" for a client that did not exist.
        expect(byKey['Birch'], isNull);
      },
    );
  });
}
