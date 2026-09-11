import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';

void main() {
  group('ReportEngine.compute', () {
    const engine = ReportEngine();
    Decimal d(String s) => Decimal.parse(s);

    ReportPreview previewWith({
      List<List<ReportCell>> rows = const [],
      List<ReportColumn> columns = const [],
    }) {
      return ReportPreview(
        columns: columns,
        rows: [for (final cells in rows) ReportRow(cells: cells)],
      );
    }

    final clientCol = const ReportColumn(
      identifier: 'client.name',
      displayLabel: 'Client',
      type: ReportColumnType.string,
    );
    final amountCol = const ReportColumn(
      identifier: 'invoice.amount',
      displayLabel: 'Amount',
      type: ReportColumnType.money,
    );
    final dateCol = const ReportColumn(
      identifier: 'invoice.date',
      displayLabel: 'Date',
      type: ReportColumnType.date,
    );

    test('returns empty view for an empty preview', () {
      final view = engine.compute(
        preview: ReportPreview.empty,
        ui: const ReportUiState(),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      expect(view.rows, isEmpty);
      expect(view.groups, isEmpty);
    });

    test(
      'columnOrder reorders visible columns; unlisted keep server order',
      () {
        final preview = previewWith(
          columns: [clientCol, amountCol, dateCol],
          rows: [
            [
              ReportStringCell(value: 'Acme'),
              ReportNumberCell(value: d('100')),
              ReportDateCell(value: null),
            ],
          ],
        );
        final view = engine.compute(
          preview: preview,
          // Only date listed first; client/amount fall back to server order.
          ui: const ReportUiState(columnOrder: ['invoice.date']),
          exchangeRates: const {},
          companyCurrencyId: '1',
        );
        expect(view.visibleColumns.map((c) => c.identifier).toList(), [
          'invoice.date',
          'client.name',
          'invoice.amount',
        ]);
      },
    );

    test('group column stays pinned to index 0 despite columnOrder', () {
      final preview = previewWith(
        columns: [clientCol, amountCol],
        rows: [
          [ReportStringCell(value: 'Acme'), ReportNumberCell(value: d('100'))],
        ],
      );
      final view = engine.compute(
        preview: preview,
        ui: const ReportUiState(
          group: 'client.name',
          columnOrder: ['invoice.amount', 'client.name'],
        ),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      // User order would put amount first, but grouping pins the group
      // column to index 0.
      expect(view.visibleColumns.first.identifier, 'client.name');
    });

    test('sorts strings ascending by default, descending on flip', () {
      final preview = previewWith(
        columns: [clientCol],
        rows: [
          [ReportStringCell(value: 'Charlie')],
          [ReportStringCell(value: 'alpha')],
          [ReportStringCell(value: 'Bravo')],
        ],
      );
      final asc = engine.compute(
        preview: preview,
        ui: const ReportUiState(sortField: 'client.name'),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      expect(asc.rows.map((r) => (r.cells.first as ReportStringCell).value), [
        'alpha',
        'Bravo',
        'Charlie',
      ]);
      final desc = engine.compute(
        preview: preview,
        ui: const ReportUiState(sortField: 'client.name', sortAscending: false),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      expect(desc.rows.map((r) => (r.cells.first as ReportStringCell).value), [
        'Charlie',
        'Bravo',
        'alpha',
      ]);
    });

    test('sorts numbers using Decimal comparison, not string', () {
      final preview = previewWith(
        columns: [amountCol],
        rows: [
          [ReportNumberCell(value: d('100.00'), isMoney: true)],
          [ReportNumberCell(value: d('20.00'), isMoney: true)],
          [ReportNumberCell(value: d('3.00'), isMoney: true)],
        ],
      );
      final view = engine.compute(
        preview: preview,
        ui: const ReportUiState(sortField: 'invoice.amount'),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      final amounts = view.rows
          .map((r) => (r.cells.first as ReportNumberCell).value)
          .toList();
      expect(amounts, [d('3.00'), d('20.00'), d('100.00')]);
    });

    test('column substring filter applies (case-insensitive)', () {
      final preview = previewWith(
        columns: [clientCol],
        rows: [
          [ReportStringCell(value: 'ACME Corp', displayValue: 'ACME Corp')],
          [
            ReportStringCell(
              value: 'Foo Industries',
              displayValue: 'Foo Industries',
            ),
          ],
        ],
      );
      final view = engine.compute(
        preview: preview,
        ui: const ReportUiState(columnFilters: {'client.name': 'acme'}),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      expect(view.rows, hasLength(1));
      expect(
        (view.rows.first.cells.first as ReportStringCell).value,
        'ACME Corp',
      );
    });

    test('numeric range filter applies (min..max)', () {
      final preview = previewWith(
        columns: [amountCol],
        rows: [
          [ReportNumberCell(value: d('50'), isMoney: true)],
          [ReportNumberCell(value: d('150'), isMoney: true)],
          [ReportNumberCell(value: d('500'), isMoney: true)],
        ],
      );
      ReportView run(String filter) => engine.compute(
        preview: preview,
        ui: ReportUiState(columnFilters: {'invoice.amount': filter}),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );

      // Closed range.
      final ranged = run('100..400');
      expect(ranged.rows, hasLength(1));
      expect(
        (ranged.rows.first.cells.first as ReportNumberCell).value,
        d('150'),
      );

      // Open-ended bounds.
      expect(run('..100').rows, hasLength(1)); // only 50
      expect(run('200..').rows, hasLength(1)); // only 500

      // Bare number is a lower bound (>=), not exact-match.
      expect(run('150').rows, hasLength(2)); // 150 and 500
    });

    test('negative numeric bounds parse with the .. separator', () {
      final preview = previewWith(
        columns: [amountCol],
        rows: [
          [ReportNumberCell(value: d('-100'), isMoney: true)],
          [ReportNumberCell(value: d('-10'), isMoney: true)],
          [ReportNumberCell(value: d('80'), isMoney: true)],
        ],
      );
      final view = engine.compute(
        preview: preview,
        ui: const ReportUiState(columnFilters: {'invoice.amount': '-50..50'}),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      expect(view.rows, hasLength(1)); // only -10 is within [-50, 50]
      expect((view.rows.first.cells.first as ReportNumberCell).value, d('-10'));
    });

    test('groups by string column and counts members', () {
      final preview = previewWith(
        columns: [clientCol, amountCol],
        rows: [
          [
            ReportStringCell(value: 'ACME'),
            ReportNumberCell(value: d('100'), isMoney: true, currencyId: '1'),
          ],
          [
            ReportStringCell(value: 'ACME'),
            ReportNumberCell(value: d('200'), isMoney: true, currencyId: '1'),
          ],
          [
            ReportStringCell(value: 'Foo'),
            ReportNumberCell(value: d('50'), isMoney: true, currencyId: '1'),
          ],
        ],
      );
      final view = engine.compute(
        preview: preview,
        ui: const ReportUiState(group: 'client.name'),
        exchangeRates: {'1': Decimal.one},
        companyCurrencyId: '1',
      );
      expect(view.rows, isEmpty);
      expect(view.groups.map((g) => g.key), ['ACME', 'Foo']);
      expect(view.groups.first.count, 2);
      expect(view.groups.first.numericTotals['invoice.amount']!['1'], d('300'));
    });

    test('subgroup=month buckets dates correctly', () {
      final preview = previewWith(
        columns: [dateCol, amountCol],
        rows: [
          [
            ReportDateCell(value: Date.tryParse('2026-04-10')!),
            ReportNumberCell(value: d('10'), isMoney: true, currencyId: '1'),
          ],
          [
            ReportDateCell(value: Date.tryParse('2026-04-25')!),
            ReportNumberCell(value: d('15'), isMoney: true, currencyId: '1'),
          ],
          [
            ReportDateCell(value: Date.tryParse('2026-05-02')!),
            ReportNumberCell(value: d('20'), isMoney: true, currencyId: '1'),
          ],
        ],
      );
      final view = engine.compute(
        preview: preview,
        ui: const ReportUiState(
          group: 'invoice.date',
          subgroup: ReportSubgroup.month,
        ),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      expect(view.groups.map((g) => g.key), ['2026-04-01', '2026-05-01']);
      expect(view.groups.first.count, 2);
    });

    test('subgroup=year buckets on the fiscal year (firstMonthOfYear=4)', () {
      const fiscalEngine = ReportEngine(firstMonthOfYear: 4);
      final preview = previewWith(
        columns: [dateCol, amountCol],
        rows: [
          [
            ReportDateCell(value: Date.tryParse('2026-02-10')!), // before April
            ReportNumberCell(value: d('10'), isMoney: true, currencyId: '1'),
          ],
          [
            ReportDateCell(
              value: Date.tryParse('2026-05-02')!,
            ), // on/after April
            ReportNumberCell(value: d('20'), isMoney: true, currencyId: '1'),
          ],
        ],
      );
      final view = fiscalEngine.compute(
        preview: preview,
        ui: const ReportUiState(
          group: 'invoice.date',
          subgroup: ReportSubgroup.year,
        ),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      // Feb 2026 falls in the 2025-04 fiscal year; May 2026 in 2026-04.
      expect(view.groups.map((g) => g.key), ['2025-04-01', '2026-04-01']);
    });

    test('subgroup=week buckets on first_day_of_week (Monday)', () {
      const mondayEngine = ReportEngine(firstDayOfWeek: 1);
      final preview = previewWith(
        columns: [dateCol, amountCol],
        rows: [
          [
            ReportDateCell(value: Date.tryParse('2026-06-01')!), // Monday
            ReportNumberCell(value: d('10'), isMoney: true, currencyId: '1'),
          ],
          [
            ReportDateCell(value: Date.tryParse('2026-06-03')!), // Wednesday
            ReportNumberCell(value: d('20'), isMoney: true, currencyId: '1'),
          ],
        ],
      );
      final view = mondayEngine.compute(
        preview: preview,
        ui: const ReportUiState(
          group: 'invoice.date',
          subgroup: ReportSubgroup.week,
        ),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      // Both dates share the same Monday-started week → one bucket on Mon 6/1.
      expect(view.groups.map((g) => g.key), ['2026-06-01']);
      expect(view.groups.first.count, 2);
    });

    test(
      'drill-down filters to selectedGroup and composes with column filters',
      () {
        final preview = previewWith(
          columns: [clientCol, amountCol],
          rows: [
            [
              ReportStringCell(value: 'ACME', displayValue: 'ACME'),
              ReportNumberCell(value: d('100'), isMoney: true, currencyId: '1'),
            ],
            [
              ReportStringCell(value: 'ACME', displayValue: 'ACME'),
              ReportNumberCell(value: d('500'), isMoney: true, currencyId: '1'),
            ],
            [
              ReportStringCell(value: 'Foo', displayValue: 'Foo'),
              ReportNumberCell(value: d('200'), isMoney: true, currencyId: '1'),
            ],
          ],
        );
        // Drilled into ACME with no extra column filter — see 2 rows.
        final drilled = engine.compute(
          preview: preview,
          ui: const ReportUiState(group: 'client.name', selectedGroup: 'ACME'),
          exchangeRates: const {},
          companyCurrencyId: '1',
        );
        expect(drilled.rows, hasLength(2));
        expect(drilled.groups, isEmpty);
        // Drilled in AND a column filter on amount — composes.
        final composed = engine.compute(
          preview: preview,
          ui: const ReportUiState(
            group: 'client.name',
            selectedGroup: 'ACME',
            columnFilters: {'invoice.amount': '0..200'},
          ),
          exchangeRates: const {},
          companyCurrencyId: '1',
        );
        expect(composed.rows, hasLength(1));
        expect(
          (composed.rows.first.cells.first as ReportStringCell).value,
          'ACME',
        );
      },
    );

    test('per-currency totals bucket by currencyId', () {
      final preview = previewWith(
        columns: [amountCol],
        rows: [
          [ReportNumberCell(value: d('100'), isMoney: true, currencyId: '1')],
          [ReportNumberCell(value: d('200'), isMoney: true, currencyId: '1')],
          [ReportNumberCell(value: d('50'), isMoney: true, currencyId: '3')],
        ],
      );
      final view = engine.compute(
        preview: preview,
        ui: const ReportUiState(),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      final perCur = view.grandTotalsByCurrency['invoice.amount']!;
      expect(perCur['1'], d('300'));
      expect(perCur['3'], d('50'));
      expect(view.rowCountByCurrency['1'], 2);
      expect(view.rowCountByCurrency['3'], 1);
    });

    test(
      'converted totals require non-empty exchange rates AND a company currency',
      () {
        final preview = previewWith(
          columns: [amountCol],
          rows: [
            [ReportNumberCell(value: d('100'), isMoney: true, currencyId: '1')],
            [ReportNumberCell(value: d('100'), isMoney: true, currencyId: '3')],
          ],
        );
        // Cold launch — no rates yet → converted totals stay null.
        final cold = engine.compute(
          preview: preview,
          ui: const ReportUiState(convertCurrency: true),
          exchangeRates: const {},
          companyCurrencyId: '1',
        );
        expect(cold.convertedGrandTotals, isNull);
        expect(cold.exchangeRatesAvailable, isFalse);
        // Rates present → convert.
        final warm = engine.compute(
          preview: preview,
          ui: const ReportUiState(convertCurrency: true),
          exchangeRates: {'1': Decimal.one, '3': d('0.5')},
          companyCurrencyId: '1',
        );
        expect(warm.exchangeRatesAvailable, isTrue);
        // 100 USD stays 100; 100 EUR at rate 0.5 -> 200 USD; total 300.
        expect(warm.convertedGrandTotals!['invoice.amount'], d('300'));
      },
    );

    test('groups a numeric column in numeric (not lexicographic) order', () {
      const numCol = ReportColumn(
        identifier: 'invoice.count',
        displayLabel: 'Count',
        type: ReportColumnType.number,
      );
      final preview = previewWith(
        columns: const [numCol],
        rows: [
          [ReportNumberCell(value: d('9'), displayValue: '9')],
          [ReportNumberCell(value: d('100'), displayValue: '100')],
          [ReportNumberCell(value: d('10'), displayValue: '10')],
        ],
      );
      final view = engine.compute(
        preview: preview,
        ui: const ReportUiState(group: 'invoice.count'),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      // Display strings alone sort 10, 100, 9; numeric order is 9, 10, 100.
      expect(view.groups.map((g) => g.key), ['9', '10', '100']);
    });

    test('row sort is stable for equal keys (preserves input order)', () {
      const idCol = ReportColumn(
        identifier: 'invoice.number',
        displayLabel: 'Number',
        type: ReportColumnType.string,
      );
      // 50 rows so Dart's sort would otherwise switch off insertion sort and
      // could reorder equal-key rows; the engine's index tie-breaker prevents it.
      final preview = previewWith(
        columns: [clientCol, idCol],
        rows: [
          for (var i = 0; i < 50; i++)
            [
              const ReportStringCell(value: 'ACME', displayValue: 'ACME'),
              ReportStringCell(value: '$i', displayValue: '$i'),
            ],
        ],
      );
      final view = engine.compute(
        preview: preview,
        ui: const ReportUiState(sortField: 'client.name'),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );
      expect(view.rows.map((r) => (r.cells[1] as ReportStringCell).value), [
        for (var i = 0; i < 50; i++) '$i',
      ]);
    });

    final createdAtCol = const ReportColumn(
      identifier: 'client.created_at',
      displayLabel: 'Date Created',
      type: ReportColumnType.dateTime,
    );

    // invoiceninja/flutter#138. The Reports screen sets the group *before*
    // the run that fetches the optional date column, so `ui.group` can name a
    // column the preview doesn't carry yet. Without the existence check
    // `_bucket` returns `[]` while `renderedRows` is still forced to `[]` —
    // the view comes back with no rows AND no groups over a full preview,
    // which renders as "No results" for the length of the fetch and stays
    // there if the run is cancelled.
    test('a group naming an absent column falls back to ungrouped rows', () {
      final preview = previewWith(
        columns: [clientCol, amountCol],
        rows: [
          [
            const ReportStringCell(value: 'ACME', displayValue: 'ACME'),
            ReportNumberCell(value: d('100'), isMoney: true, currencyId: '1'),
          ],
          [
            const ReportStringCell(value: 'Foo', displayValue: 'Foo'),
            ReportNumberCell(value: d('200'), isMoney: true, currencyId: '1'),
          ],
        ],
      );
      final view = engine.compute(
        preview: preview,
        ui: const ReportUiState(
          group: 'client.created_at', // not in this preview
          subgroup: ReportSubgroup.month,
        ),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );

      expect(view.groups, isEmpty);
      expect(view.rows, hasLength(2));
      expect(view.totalRowCount, 2);
    });

    // An epoch-seconds `*_at` value is parsed `isUtc: true`, but the table
    // cell renders it through `Formatter.date(..., showTime: true)`, which
    // appends `Z` and calls `.toLocal()`. Reading the calendar fields off the
    // UTC instant counts a row in one month while its own cell displays a
    // date in another.
    //
    // This is the rare invariant **CI cannot check**: under `TZ=UTC` the
    // buggy and fixed code are behaviourally identical, because there is no
    // conversion to get wrong. The test says so out loud and returns rather
    // than asserting something vacuous — it bites on any developer machine
    // with a non-zero offset (verified failing against the pre-fix code under
    // `TZ=Asia/Jerusalem`).
    test('a dateTime buckets on the local day, not the UTC one', () {
      final instant = DateTime.utc(2026, 3, 1, 23, 30);
      final local = instant.toLocal();
      if (local.day == instant.day) return; // device is at UTC

      final view = engine.compute(
        preview: previewWith(
          columns: [createdAtCol, amountCol],
          rows: [
            [
              ReportDateTimeCell(value: instant),
              ReportNumberCell(value: d('10'), isMoney: true, currencyId: '1'),
            ],
          ],
        ),
        ui: const ReportUiState(
          group: 'client.created_at',
          subgroup: ReportSubgroup.day,
        ),
        exchangeRates: const {},
        companyCurrencyId: '1',
      );

      expect(
        view.groups.single.key,
        Date(local.year, local.month, local.day).toIso(),
      );
      expect(view.groups.single.key, isNot('2026-03-01'));
    });
  });

  group('ReportUiState value equality', () {
    test('identical-field instances compare equal and share hashCode', () {
      final a = ReportUiState(
        visibleColumnIds: {'client.name', 'invoice.amount'},
        columnFilters: const {
          'client.name': 'acme',
          'invoice.amount': '100..500',
        },
        sortField: 'invoice.amount',
        sortAscending: false,
        group: 'client.country',
        subgroup: ReportSubgroup.month,
        selectedGroup: 'USA',
        convertCurrency: true,
      );
      // Different set/map identities, same contents.
      final b = ReportUiState(
        visibleColumnIds: {'invoice.amount', 'client.name'},
        columnFilters: const {
          'invoice.amount': '100..500',
          'client.name': 'acme',
        },
        sortField: 'invoice.amount',
        sortAscending: false,
        group: 'client.country',
        subgroup: ReportSubgroup.month,
        selectedGroup: 'USA',
        convertCurrency: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('any field difference flips equality and hashCode', () {
      const base = ReportUiState(sortField: 'a', group: 'b');
      const sortDiff = ReportUiState(sortField: 'a2', group: 'b');
      const groupDiff = ReportUiState(sortField: 'a', group: 'b2');
      expect(base == sortDiff, isFalse);
      expect(base.hashCode == sortDiff.hashCode, isFalse);
      expect(base == groupDiff, isFalse);
      expect(base.hashCode == groupDiff.hashCode, isFalse);
    });
  });

  // `_bucket` only emits a bucket for a date that has rows, so a period
  // nobody was active in is absent rather than zero. A chart plotting buckets
  // by index then draws two non-adjacent periods as neighbours — this is the
  // span that lets it fill the gaps instead.
  group('ReportEngine.dateBucketSpan', () {
    const engine = ReportEngine();

    test('fills an interior month gap', () {
      expect(
        engine.dateBucketSpan('2026-01-01', '2026-04-01', ReportSubgroup.month),
        ['2026-01-01', '2026-02-01', '2026-03-01', '2026-04-01'],
      );
    });

    test('does not extend past either end', () {
      final span = engine.dateBucketSpan(
        '2026-02-01',
        '2026-03-01',
        ReportSubgroup.month,
      );
      expect(span, ['2026-02-01', '2026-03-01']);
    });

    test('a single bucket spans itself', () {
      expect(
        engine.dateBucketSpan('2026-02-01', '2026-02-01', ReportSubgroup.month),
        ['2026-02-01'],
      );
    });

    test('steps months across a year boundary', () {
      expect(
        engine.dateBucketSpan('2025-11-01', '2026-02-01', ReportSubgroup.month),
        ['2025-11-01', '2025-12-01', '2026-01-01', '2026-02-01'],
      );
    });

    test('quarter steps three months at a time', () {
      expect(
        engine.dateBucketSpan(
          '2026-01-01',
          '2026-10-01',
          ReportSubgroup.quarter,
        ),
        ['2026-01-01', '2026-04-01', '2026-07-01', '2026-10-01'],
      );
    });

    test('day steps one day at a time, across a month end', () {
      expect(
        engine.dateBucketSpan('2026-02-27', '2026-03-02', ReportSubgroup.day),
        ['2026-02-27', '2026-02-28', '2026-03-01', '2026-03-02'],
      );
    });

    test('week steps on the configured first day of week', () {
      const mondayEngine = ReportEngine(firstDayOfWeek: 1);
      expect(
        mondayEngine.dateBucketSpan(
          '2026-06-01',
          '2026-06-22',
          ReportSubgroup.week,
        ),
        ['2026-06-01', '2026-06-08', '2026-06-15', '2026-06-22'],
      );
    });

    test('year steps on the fiscal year, not the calendar year', () {
      const aprilEngine = ReportEngine(firstMonthOfYear: 4);
      expect(
        aprilEngine.dateBucketSpan(
          '2024-04-01',
          '2026-04-01',
          ReportSubgroup.year,
        ),
        ['2024-04-01', '2025-04-01', '2026-04-01'],
      );
    });

    test('refuses a span past the render cap', () {
      // ~6 years of days is well past kMaxReportChartBuckets. The caller reads
      // an empty result as "plot the raw buckets", so the refusal has to be
      // empty rather than truncated — a truncated span would silently drop
      // every bucket past the cap.
      expect(
        engine.dateBucketSpan('2020-01-01', '2026-01-01', ReportSubgroup.day),
        isEmpty,
      );
    });

    test('refuses inverted or unparsable bounds', () {
      expect(
        engine.dateBucketSpan('2026-04-01', '2026-01-01', ReportSubgroup.month),
        isEmpty,
      );
      // The engine's own bucket for a null date cell sorts first, so this is
      // the shape a nullable date column actually produces.
      expect(
        engine.dateBucketSpan('', '2026-01-01', ReportSubgroup.month),
        isEmpty,
      );
      expect(
        engine.dateBucketSpan('2026-01-01', 'nope', ReportSubgroup.month),
        isEmpty,
      );
    });

    test('re-canonicalizes a bound that is not a bucket start', () {
      expect(
        engine.dateBucketSpan('2026-01-17', '2026-03-09', ReportSubgroup.month),
        ['2026-01-01', '2026-02-01', '2026-03-01'],
      );
    });
  });
}
