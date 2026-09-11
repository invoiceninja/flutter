import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/widgets/reports_chart_card.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

/// Returns the supplied preview on the first Run. The chart-card tests
/// need `vm.run.preview` populated so `numericChartColumns()` reads the
/// chart-eligible columns from the same place the production VM does.
class _SeededRepo implements ReportsRepository {
  _SeededRepo(this._preview);
  final ReportPreview _preview;

  @override
  Future<ReportPreview> runPreview({
    required String reportIdentifier,
    required String endpoint,
    required ReportPayload payload,
    List<String> reportKeys = const [],
    int maxRetries = ReportsApi.defaultPreviewRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async => _preview;

  @override
  Future<ReportPreview> continuePreview({
    required String hash,
    int maxRetries = ReportsApi.defaultPreviewRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async => _preview;

  @override
  Future<void> sendEmail({
    required String reportIdentifier,
    required String endpoint,
    required ReportPayload payload,
    List<String> reportKeys = const [],
    String? groupBy,
  }) async {}

  @override
  Future<ReportExportResult> runExport({
    required String reportIdentifier,
    required String endpoint,
    required ReportPayload payload,
    required ReportExportFormat format,
    List<String> reportKeys = const [],
    String? groupBy,
    int maxRetries = ReportsApi.defaultExportRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async => throw UnimplementedError();

  @override
  Future<ReportExportResult> continueExport({
    required String hash,
    required ReportExportFormat format,
    int maxRetries = ReportsApi.defaultExportRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async => throw UnimplementedError();

  @override
  ReportsApi get api => throw UnsupportedError('not used by tests');
}

class _NullStaticsService implements StaticsService {
  @override
  Future<Map<String, dynamic>> fetch({
    bool includeStatic = true,
    bool? includeData,
  }) async => const <String, dynamic>{};

  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

const _clientCol = ReportColumn(
  identifier: 'invoice.client',
  displayLabel: 'Client',
  type: ReportColumnType.string,
);
const _amountCol = ReportColumn(
  identifier: 'invoice.amount',
  displayLabel: 'Amount',
  type: ReportColumnType.money,
);
const _countCol = ReportColumn(
  identifier: 'invoice.count',
  displayLabel: 'Count',
  type: ReportColumnType.number,
);
const _dateCol = ReportColumn(
  identifier: 'invoice.date',
  displayLabel: 'Date',
  type: ReportColumnType.date,
);

ReportView _viewWith({
  required List<GroupTotals> groups,
  List<ReportColumn> visibleColumns = const [_clientCol, _amountCol, _countCol],
}) {
  return ReportView(
    visibleColumns: visibleColumns,
    rows: const [],
    groups: groups,
    grandTotalsByCurrency: const {},
    convertedGrandTotals: null,
    rowCountByCurrency: const {},
    totalRowCount: groups.fold<int>(0, (a, g) => a + g.count),
    exchangeRatesAvailable: false,
    cellIndexByColumn: const {},
  );
}

GroupTotals _group(
  String key,
  Map<String, Map<String, Decimal>> totals, {
  int rowCount = 1,
}) {
  return GroupTotals(
    key: key,
    rows: [for (var i = 0; i < rowCount; i++) const ReportRow(cells: [])],
    numericTotals: totals,
  );
}

/// Build a VM seeded with the supplied preview. Runs an in-memory repo
/// once so `vm.run.preview` is populated, then sets the active group
/// (callers always group by `invoice.client` in these tests).
Future<ReportsViewModel> _seedVm(
  WidgetTester tester,
  ReportPreview preview, {
  String activeGroupId = 'invoice.client',
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final statics = StaticsRepository(db: db, service: _NullStaticsService());
  final vm = ReportsViewModel(repo: _SeededRepo(preview), statics: statics);
  await vm.runReport();
  vm.setGroup(activeGroupId);
  return vm;
}

Formatter _testFormatter() => Formatter(
  settings: CompanyFormatSettings.fallback,
  currencies: const {},
  countries: const {},
  dateFormats: const {},
);

Future<void> _pump(
  WidgetTester tester, {
  required ReportsViewModel vm,
  required ReportView view,
  Formatter? formatter,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: ChangeNotifierProvider<ReportsViewModel>.value(
        value: vm,
        child: Scaffold(
          body: ReportsChartCard(view: view, formatter: formatter),
        ),
      ),
    ),
  );
  // Initial paint, then the post-frame auto-pick callback fires + the
  // VM's notifyListeners rebuilds the card.
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders a bar chart with one bar per group, '
      'sorted by value descending', (tester) async {
    final vm = await _seedVm(
      tester,
      const ReportPreview(
        columns: [_clientCol, _amountCol, _countCol],
        rows: [],
      ),
    );

    final view = _viewWith(
      groups: [
        _group('Acme', {
          'invoice.amount': {'1': Decimal.fromInt(50)},
        }),
        _group('Beta', {
          'invoice.amount': {'1': Decimal.fromInt(200)},
        }),
        _group('Gamma', {
          'invoice.amount': {'1': Decimal.fromInt(120)},
        }),
      ],
    );
    await _pump(tester, vm: vm, view: view, formatter: _testFormatter());

    expect(find.byType(BarChart), findsOneWidget);
    // Auto-pick fired → chartColumn is the first numeric column (amount).
    expect(vm.chartColumn, 'invoice.amount');

    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final groups = chart.data.barGroups;
    expect(groups.length, 3);
    // Bars sorted descending: Beta (200), Gamma (120), Acme (50).
    expect(groups[0].barRods.first.toY, 200);
    expect(groups[1].barRods.first.toY, 120);
    expect(groups[2].barRods.first.toY, 50);
  });

  testWidgets('empty-state hint renders when all bars are zero', (
    tester,
  ) async {
    final vm = await _seedVm(
      tester,
      const ReportPreview(columns: [_clientCol, _amountCol], rows: []),
    );

    final view = _viewWith(
      groups: [
        _group('Acme', {
          'invoice.amount': {'1': Decimal.zero},
        }),
      ],
    );
    await _pump(tester, vm: vm, view: view, formatter: _testFormatter());

    expect(find.byType(BarChart), findsNothing);
    expect(
      find.text('No numeric values to chart — pick a different column.'),
      findsOneWidget,
    );
  });

  testWidgets('close button calls setChartVisible(false)', (tester) async {
    final vm = await _seedVm(
      tester,
      const ReportPreview(columns: [_clientCol, _amountCol], rows: []),
    );

    final view = _viewWith(
      groups: [
        _group('Acme', {
          'invoice.amount': {'1': Decimal.fromInt(10)},
        }),
      ],
    );
    await _pump(tester, vm: vm, view: view, formatter: _testFormatter());

    expect(vm.chartVisible, isTrue);
    await tester.tap(find.byTooltip('Hide chart'));
    await tester.pump();
    expect(vm.chartVisible, isFalse);
  });

  testWidgets('currency picker hidden when only one currency is present', (
    tester,
  ) async {
    final vm = await _seedVm(
      tester,
      const ReportPreview(columns: [_clientCol, _amountCol], rows: []),
    );

    final view = _viewWith(
      groups: [
        _group('Acme', {
          'invoice.amount': {'1': Decimal.fromInt(10)},
        }),
        _group('Beta', {
          'invoice.amount': {'1': Decimal.fromInt(20)},
        }),
      ],
    );
    await _pump(tester, vm: vm, view: view, formatter: _testFormatter());

    // One currency → no currency picker. The series picker is always there
    // now: Count rides alongside every numeric column, so a report with one
    // money column still has two series to choose between.
    expect(find.byKey(const Key('report-chart-currency')), findsNothing);
    expect(find.byKey(const Key('report-chart-series')), findsOneWidget);
    expect(
      find.textContaining('Switch above to see other currencies'),
      findsNothing,
    );
  });

  testWidgets('currency picker + mixed-currency hint appear with '
      'multi-currency data', (tester) async {
    final vm = await _seedVm(
      tester,
      const ReportPreview(columns: [_clientCol, _amountCol], rows: []),
    );

    final view = _viewWith(
      groups: [
        _group('Acme', {
          'invoice.amount': {
            '1': Decimal.fromInt(10),
            '2': Decimal.fromInt(50),
          },
        }),
        _group('Beta', {
          'invoice.amount': {'1': Decimal.fromInt(20)},
        }),
      ],
    );
    await _pump(tester, vm: vm, view: view, formatter: _testFormatter());

    // Currency dropdown visible.
    expect(find.byType(DropdownButton<String>), findsWidgets);
    // Mixed-currency hint shown until the user picks one explicitly.
    expect(
      find.textContaining('Switch above to see other currencies'),
      findsOneWidget,
    );
  });

  testWidgets('column picker shows only numeric columns (string columns '
      'are filtered out)', (tester) async {
    final vm = await _seedVm(
      tester,
      const ReportPreview(
        columns: [_clientCol, _amountCol, _countCol],
        rows: [],
      ),
    );

    final view = _viewWith(
      groups: [
        _group('Acme', {
          'invoice.amount': {'1': Decimal.fromInt(10)},
          'invoice.count': {'1': Decimal.fromInt(2)},
        }),
      ],
    );
    await _pump(tester, vm: vm, view: view, formatter: _testFormatter());

    // Two numeric columns → picker exists. Open it and verify the menu
    // shows only numeric column labels. The card title also says
    // "Client" (the group column's label), so scope the assertion to
    // `DropdownMenuItem<String>` to look at picker contents only.
    final picker = find.byType(DropdownButton<String>).first;
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(DropdownMenuItem<String>),
        matching: find.text('Amount'),
      ),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: find.byType(DropdownMenuItem<String>),
        matching: find.text('Count'),
      ),
      findsWidgets,
    );
    // String column never appears as a menu item.
    expect(
      find.descendant(
        of: find.byType(DropdownMenuItem<String>),
        matching: find.text('Client'),
      ),
      findsNothing,
    );
  });

  testWidgets('date grouping renders a chronological line chart, not bars', (
    tester,
  ) async {
    final vm = await _seedVm(
      tester,
      const ReportPreview(columns: [_dateCol, _amountCol], rows: []),
      activeGroupId: 'invoice.date',
    );

    // Groups keyed by ISO date buckets, deliberately NOT in value order, to
    // prove the line follows chronological (group) order rather than the
    // bar chart's value-descending sort.
    final view = _viewWith(
      visibleColumns: const [_dateCol, _amountCol],
      groups: [
        _group('2026-01-01', {
          'invoice.amount': {'1': Decimal.fromInt(300)},
        }),
        _group('2026-02-01', {
          'invoice.amount': {'1': Decimal.fromInt(100)},
        }),
        _group('2026-03-01', {
          'invoice.amount': {'1': Decimal.fromInt(200)},
        }),
      ],
    );
    await _pump(tester, vm: vm, view: view, formatter: _testFormatter());

    expect(find.byType(LineChart), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);

    final chart = tester.widget<LineChart>(find.byType(LineChart));
    final spots = chart.data.lineBarsData.first.spots;
    // Chronological order preserved (300, 100, 200) — NOT value-sorted.
    expect(spots.map((s) => s.y).toList(), [300.0, 100.0, 200.0]);
  });

  // invoiceninja/flutter#138. `GroupTotals.count` has always been there and
  // the table's group rows have always printed it — only the chart couldn't
  // draw it, which on a report grouped by a date is the one series worth
  // drawing ("how many new clients this month").
  group('count series', () {
    testWidgets('rides alongside the numeric columns in the picker', (
      tester,
    ) async {
      final vm = await _seedVm(
        tester,
        const ReportPreview(columns: [_clientCol, _amountCol], rows: []),
      );
      final view = _viewWith(
        visibleColumns: const [_clientCol, _amountCol],
        groups: [
          _group('Acme', {
            'invoice.amount': {'1': Decimal.fromInt(50)},
          }, rowCount: 3),
          _group('Beta', {
            'invoice.amount': {'1': Decimal.fromInt(20)},
          }, rowCount: 1),
        ],
      );
      await _pump(tester, vm: vm, view: view, formatter: _testFormatter());

      final picker = tester.widget<DropdownButton<String>>(
        find.byKey(const Key('report-chart-series')),
      );
      expect(picker.items!.map((i) => i.value), [
        'group.count',
        'invoice.amount',
      ]);
      // A money report keeps charting money until the user says otherwise.
      expect(vm.chartColumn, 'invoice.amount');
    });

    testWidgets('plots row counts, not totals, once picked', (tester) async {
      final vm = await _seedVm(
        tester,
        const ReportPreview(columns: [_clientCol, _amountCol], rows: []),
      );
      final view = _viewWith(
        visibleColumns: const [_clientCol, _amountCol],
        groups: [
          _group('Acme', {
            'invoice.amount': {'1': Decimal.fromInt(50)},
          }, rowCount: 3),
          _group('Beta', {
            'invoice.amount': {'1': Decimal.fromInt(20)},
          }, rowCount: 7),
        ],
      );
      await _pump(tester, vm: vm, view: view, formatter: _testFormatter());
      vm.setChartColumn('group.count');
      await tester.pump();

      final chart = tester.widget<BarChart>(find.byType(BarChart));
      // Value-descending, like every other bar series: Beta (7), Acme (3).
      expect(chart.data.barGroups.map((g) => g.barRods.first.toY), [7.0, 3.0]);
      // A count has no currency, so no currency picker can appear for it.
      expect(find.byKey(const Key('report-chart-currency')), findsNothing);
    });

    // This used to be the `no_numeric_values_to_chart` dead end: a report
    // with nothing to sum drew nothing at all, even though every group knew
    // how many rows it held.
    testWidgets('is auto-picked when there is nothing numeric to chart', (
      tester,
    ) async {
      final vm = await _seedVm(
        tester,
        const ReportPreview(columns: [_clientCol], rows: []),
      );
      final view = _viewWith(
        visibleColumns: const [_clientCol],
        groups: [
          _group('Acme', const {}, rowCount: 3),
          _group('Beta', const {}, rowCount: 5),
        ],
      );
      await _pump(tester, vm: vm, view: view, formatter: _testFormatter());

      expect(vm.chartColumn, 'group.count');
      expect(find.byType(BarChart), findsOneWidget);
      expect(
        tester
            .widget<BarChart>(find.byType(BarChart))
            .data
            .barGroups
            .map((g) => g.barRods.first.toY),
        [5.0, 3.0],
      );
    });
  });

  // A period nobody signed up in has no bucket at all — `_bucket` only emits
  // one for a date that has rows — so plotting by index draws January next
  // to March as though they were consecutive months.
  group('date-series gaps', () {
    Future<ReportsViewModel> seedMonthly(WidgetTester tester) async {
      final vm = await _seedVm(
        tester,
        const ReportPreview(columns: [_dateCol, _amountCol], rows: []),
        activeGroupId: 'invoice.date',
      );
      vm.setSubgroup(ReportSubgroup.month);
      return vm;
    }

    ReportView gappedView() => _viewWith(
      visibleColumns: const [_dateCol, _amountCol],
      groups: [
        _group('2026-01-01', {
          'invoice.amount': {'1': Decimal.fromInt(300)},
        }, rowCount: 3),
        // February is missing — nobody was invoiced.
        _group('2026-03-01', {
          'invoice.amount': {'1': Decimal.fromInt(200)},
        }, rowCount: 2),
      ],
    );

    testWidgets('an empty month plots a zero instead of closing up', (
      tester,
    ) async {
      final vm = await seedMonthly(tester);
      await _pump(
        tester,
        vm: vm,
        view: gappedView(),
        formatter: _testFormatter(),
      );

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.data.lineBarsData.first.spots.map((s) => s.y), [
        300.0,
        0.0,
        200.0,
      ]);
    });

    // A filled bucket belongs to no group, so drilling into it would filter
    // to zero rows and strand the user on "No results" with the chart gone.
    // Easy to hit by accident: fl_chart's `isInterestedForInteractions` does
    // not exclude `FlPointerHoverEvent`, so on desktop and web the drill
    // callbacks fire on mouse-over, not just on tap.
    testWidgets('a filled-in zero bucket is not drillable', (tester) async {
      final vm = await seedMonthly(tester);
      await _pump(
        tester,
        vm: vm,
        view: gappedView(),
        formatter: _testFormatter(),
      );

      final chart = tester.widget<LineChart>(find.byType(LineChart));
      final touch = chart.data.lineTouchData.touchCallback!;
      final spots = chart.data.lineBarsData.first.spots;

      FlPointerHoverEvent hover() =>
          FlPointerHoverEvent(const PointerHoverEvent());
      LineTouchResponse at(int i) => LineTouchResponse(
        touchLocation: Offset.zero,
        touchChartCoordinate: Offset.zero,
        lineBarSpots: [
          TouchLineBarSpot(
            chart.data.lineBarsData.first,
            0,
            spots[i],
            spots[i].y,
          ),
        ],
      );

      // Index 1 is February — invented by the gap fill, no rows behind it.
      touch(hover(), at(1));
      await tester.pump();
      expect(vm.selectedGroup, isNull);

      // Index 0 is January, a real bucket — still drillable.
      touch(hover(), at(0));
      await tester.pump();
      expect(vm.selectedGroup, '2026-01-01');
    });

    testWidgets('the filled bucket is labelled, not left as a raw ISO date', (
      tester,
    ) async {
      final vm = await seedMonthly(tester);
      vm.setChartColumn('group.count');
      await _pump(
        tester,
        vm: vm,
        view: gappedView(),
        formatter: _testFormatter(),
      );

      // Bucket keys stay ISO (they are identity — drill-down matches on
      // them); only the axis label is formatted.
      expect(find.text('February 2026'), findsOneWidget);
      expect(find.text('2026-02-01'), findsNothing);
    });
  });
}
