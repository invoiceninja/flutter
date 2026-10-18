import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/domain/reports/local_report_source.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';

/// Task Items is built on the device (`ReportDefinition.isLocal`): these pin
/// what the view model does differently for it — and that the server is
/// never asked for it.

class _NullStaticsService implements StaticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _duration = ReportColumn(
  identifier: 'task.duration',
  displayLabel: 'Duration',
  type: ReportColumnType.duration,
);

/// [n] time entries, all of task `t1`.
ReportPreview _entries(int n, {int seconds = 3600}) => ReportPreview(
  columns: const [_duration],
  rows: [
    for (var i = 0; i < n; i++)
      ReportRow(
        recordWire: 'task',
        recordId: 't1',
        cells: [ReportDurationCell(seconds: seconds)],
      ),
  ],
);

class _Source implements LocalReportSource {
  ReportPreview device = _entries(1);
  ReportPreview fetched = _entries(2);
  final List<ReportQuery> deviceReads = [];
  final List<ReportQuery> refreshes = [];
  Completer<void>? gate;
  ReportError? error;

  @override
  Future<ReportPreview> fromDevice(ReportQuery query) async {
    deviceReads.add(query);
    return device;
  }

  @override
  Future<ReportPreview> refresh(
    ReportQuery query, {
    bool Function()? isCancelled,
  }) async {
    refreshes.add(query);
    await gate?.future;
    final e = error;
    if (e != null) throw e;
    return fetched;
  }
}

/// The server, which a report built on the device must never reach.
class _Repo implements ReportsRepository {
  final List<String> asked = [];
  final List<List<String>> keys = [];
  ReportPreview answer = ReportPreview.empty;

  @override
  Future<ReportPreview> runPreview({
    required String reportIdentifier,
    required String endpoint,
    required ReportPayload payload,
    List<String> reportKeys = const [],
    FormattedNumberStyle? numberStyle,
    String? companyId,
    int maxRetries = ReportsApi.defaultPreviewRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async {
    asked.add('run $reportIdentifier');
    keys.add(reportKeys);
    return answer;
  }

  @override
  Future<({ReportPreview preview, DateTime fetchedAt})?> cachedPreview({
    required String companyId,
    required String reportIdentifier,
    required ReportPayload payload,
    FormattedNumberStyle? numberStyle,
  }) async {
    asked.add('cache $reportIdentifier');
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StaticsRepository statics;
  late _Repo repo;
  late _Source source;

  /// Thursday 15 October 2026, midday.
  final now = DateTime(2026, 10, 15, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    statics = StaticsRepository(db: db, service: _NullStaticsService());
    repo = _Repo();
    source = _Source();
  });

  tearDown(() async {
    await db.close();
  });

  ReportsViewModel vmFor({
    String report = 'task_item',
    bool Function()? canRun,
    Stream<bool>? online,
    Future<bool> Function(ReportQuery)? tasksCrossRange,
    bool wired = true,
    bool fetchRowIds = false,
    Future<ReportCompanyFormat> Function()? companyFormat,
  }) {
    final vm = ReportsViewModel(
      repo: repo,
      statics: statics,
      initialReport: report,
      companyId: 'co',
      fetchRowIds: fetchRowIds,
      companyCurrencyId: companyFormat == null ? null : () async => null,
      companyFormat: companyFormat,
      autoRun: true,
      autoRunDebounce: Duration.zero,
      canRun: canRun,
      online: online,
      now: () => now,
      localSourceFor: wired ? (id) => id == 'task_item' ? source : null : null,
      tasksCrossRange: tasksCrossRange,
    );
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  test('it is built from the source, never asked of the server', () async {
    final vm = vmFor();
    await vm.open('task_item');
    await settle();
    expect(source.refreshes, hasLength(1));
    expect(repo.asked, isEmpty);
    expect(vm.run.preview!.rows, hasLength(2));
    expect(vm.resultFromDevice, isFalse);
    expect(vm.resultFetchedAt, now);
  });

  test('the device rows show at once, then exactly one refresh replaces '
      'them', () async {
    source.gate = Completer<void>();
    final vm = vmFor();
    unawaited(vm.open('task_item'));
    await settle();
    // What the device held, marked as such — and not stamped as fetched, or
    // it would count as fresh and the refresh behind it never be made.
    expect(vm.run.preview!.rows, hasLength(1));
    expect(vm.resultFromDevice, isTrue);
    expect(vm.resultFetchedAt, isNull);
    expect(vm.run.isLoading, isTrue);
    source.gate!.complete();
    await settle();
    expect(source.refreshes, hasLength(1));
    expect(vm.run.preview!.rows, hasLength(2));
    expect(vm.resultFromDevice, isFalse);
  });

  test(
    'nothing held is not shown while the server can still be asked',
    () async {
      // Shown, it would flash "No time was logged" until the fetch lands.
      source
        ..device = _entries(0)
        ..gate = Completer<void>();
      final vm = vmFor();
      unawaited(vm.open('task_item'));
      await settle();
      expect(vm.run.preview, isNull);
      source.gate!.complete();
      await settle();
      expect(vm.run.preview!.rows, hasLength(2));
    },
  );

  test(
    'offline, the device rows are the report — and the refresh is owed',
    () async {
      final online = StreamController<bool>.broadcast();
      addTearDown(online.close);
      final vm = vmFor(online: online.stream);
      online.add(false);
      await settle();
      await vm.open('task_item');
      await settle();
      expect(vm.run.preview!.rows, hasLength(1));
      expect(vm.resultFromDevice, isTrue);
      expect(source.refreshes, isEmpty);
      online.add(true);
      await settle();
      expect(source.refreshes, hasLength(1));
      expect(vm.resultFromDevice, isFalse);
    },
  );

  test('behind the plan gate it reads nothing, device included', () async {
    final vm = vmFor(canRun: () => false);
    await vm.open('task_item');
    await settle();
    expect(source.deviceReads, isEmpty);
    expect(source.refreshes, isEmpty);
    expect(vm.run.preview, isNull);
  });

  test(
    'a report with no source wired fails, rather than ask the server',
    () async {
      final vm = vmFor(wired: false);
      await vm.open('task_item');
      await settle();
      expect(vm.run.error, isNotNull);
      expect(repo.asked, isEmpty);
    },
  );

  test(
    'the range is resolved from the request, and the filters carried',
    () async {
      final vm = vmFor();
      await vm.open('task_item');
      await settle();
      vm.setPayload(
        vm.payload.copyWith(
          datePreset: ReportDatePreset.last7,
          clientId: () => 'c1,c2',
          projects: () => 'p1',
          tags: () => 't1',
          status: () => 'uninvoiced',
        ),
      );
      await settle();
      final q = source.refreshes.last;
      expect(q.start, Date(2026, 10, 9));
      expect(q.end, Date(2026, 10, 15));
      expect(q.clientIds, {'c1', 'c2'});
      expect(q.projectIds, {'p1'});
      expect(q.tagIds, {'t1'});
      expect(q.status, 'uninvoiced');
      expect(q.now, now);
    },
  );

  test('the comparison asks the source for the period before', () async {
    final vm = vmFor();
    await vm.open('task_item');
    await settle();
    vm.setCompare(true);
    await settle();
    final earlier = source.refreshes.last;
    // This month to the 15th, against last month to the 15th.
    expect(earlier.start, Date(2026, 9, 1));
    expect(earlier.end, Date(2026, 9, 15));
    expect(repo.asked, isEmpty);
  });

  test('its entries are not merged, though they share a task', () async {
    source.fetched = _entries(3);
    final vm = vmFor();
    await vm.open('task_item');
    await settle();
    expect(vm.run.preview!.rows, hasLength(3));
  });

  test('Reset view goes back to the opening range, not to All time', () async {
    final vm = vmFor();
    await vm.open('task_item');
    await settle();
    vm.setPayload(vm.payload.copyWith(datePreset: ReportDatePreset.lastYear));
    vm.resetEverything();
    expect(vm.payload.datePreset, ReportDatePreset.thisMonth);
  });

  test('coming back reads the device again, with no request', () async {
    final vm = vmFor();
    await vm.open('task_item');
    await settle();
    source.device = _entries(5);
    await vm.rereadFromDevice();
    expect(vm.run.preview!.rows, hasLength(5));
    expect(source.refreshes, hasLength(1));
    // Still the refreshed result, as far as its freshness goes.
    expect(vm.resultFromDevice, isFalse);
    expect(vm.resultFetchedAt, now);
  });

  group('from the Tasks report', () {
    test('Show task items lands on the same range and filters', () async {
      final vm = vmFor(report: 'task');
      // Task Items remembers a project filter of its own…
      await vm.open('task_item');
      await settle();
      vm.setPayload(vm.payload.copyWith(projects: () => 'p9'));
      await settle();
      await vm.open('task');
      await settle();
      vm.setPayload(
        vm.payload.copyWith(
          datePreset: ReportDatePreset.custom,
          startDate: () => Date(2026, 10, 5),
          endDate: () => Date(2026, 10, 11),
          clientId: () => 'c1',
          includeDeleted: true,
        ),
      );
      await settle();
      vm.seedNextOpen('task_item', vm.payload);
      await vm.open('task_item');
      await settle();
      expect(vm.payload.datePreset, ReportDatePreset.custom);
      expect(vm.payload.startDate, Date(2026, 10, 5));
      expect(vm.payload.clientId, 'c1');
      expect(vm.payload.includeDeleted, isTrue);
      // …which "the same range and filters" does not include.
      expect(vm.payload.projects, isNull);
      final q = source.refreshes.last;
      expect(q.start, Date(2026, 10, 5));
      expect(q.end, Date(2026, 10, 11));
      expect(q.projectIds, isEmpty);
    });

    test('the hint shows only when a task crosses the range', () async {
      var crosses = true;
      final vm = vmFor(report: 'task', tasksCrossRange: (q) async => crosses);
      void landed() {
        // Each answer is for a result on screen, not for one still coming.
        expect(vm.run.status, ReportRunStatus.ready);
        expect(vm.isParamDirty, isFalse);
      }

      await vm.open('task');
      await settle();
      landed();
      expect(vm.showsTaskItemsHint, isTrue);

      crosses = false;
      vm.setPayload(vm.payload.copyWith(datePreset: ReportDatePreset.lastYear));
      await settle();
      landed();
      expect(vm.showsTaskItemsHint, isFalse);

      // All time has no outside.
      crosses = true;
      vm.setPayload(vm.payload.copyWith(datePreset: ReportDatePreset.allTime));
      await settle();
      landed();
      expect(vm.showsTaskItemsHint, isFalse);
    });

    test('a task is one row, with its duration counted once', () async {
      // `TaskExport` writes a row per time entry, each with the task's whole
      // duration; the headline summed it once per entry.
      repo.answer = ReportPreview(
        columns: const [
          ReportColumn(
            identifier: 'task.number',
            displayLabel: 'Number',
            type: ReportColumnType.string,
          ),
          _duration,
          ReportColumn(
            identifier: 'task.time_log',
            displayLabel: 'Log',
            type: ReportColumnType.string,
          ),
        ],
        rows: [
          for (final log in ['1200', '2400', '3600'])
            ReportRow(
              cells: [
                const ReportStringCell(value: '0001', displayValue: '0001'),
                const ReportDurationCell(seconds: 7200, displayValue: '7200'),
                ReportStringCell(value: log, displayValue: log),
              ],
            ),
        ],
      );
      final vm = vmFor(report: 'task');
      await vm.open('task');
      await settle();
      final preview = vm.run.preview!;
      expect(preview.rows, hasLength(1));
      expect(
        vm.buildView().grandTotalsByCurrency['task.duration']?.values.single,
        Decimal.fromInt(7200),
      );
      // And the per-entry column is gone from the report.
      expect(preview.columns.map((c) => c.identifier), [
        'task.number',
        'task.duration',
      ]);
    });

    test('it still asks for the per-entry columns it hides', () async {
      // Without `task.time_log` a 5.13.44+ server merges the task itself and
      // leaves its start and end times blank.
      repo.answer = ReportPreview(
        columns: const [
          ReportColumn(
            identifier: 'task.number',
            displayLabel: 'Number',
            type: ReportColumnType.string,
          ),
          ReportColumn(
            identifier: 'task.time_log',
            displayLabel: 'Log',
            type: ReportColumnType.string,
          ),
          ReportColumn(
            identifier: 'task.id',
            displayLabel: 'Id',
            type: ReportColumnType.string,
          ),
        ],
        rows: const [
          ReportRow(
            cells: [
              ReportStringCell(value: '0001', displayValue: '0001'),
              ReportStringCell(value: '60', displayValue: '60'),
              ReportStringCell(value: 't1', displayValue: 't1'),
            ],
          ),
        ],
      );
      final vm = vmFor(report: 'task', fetchRowIds: true);
      await vm.open('task');
      await settle();
      // The plain run, then the row ids — which name the columns.
      expect(repo.keys, hasLength(2));
      expect(repo.keys.last, containsAll(<String>['task.time_log', 'task.id']));
      // And still nothing of it on screen.
      expect(
        vm.run.preview!.columns.map((c) => c.identifier),
        isNot(contains('task.time_log')),
      );
      expect(vm.serverReportKeys(), isNot(contains('task.time_log')));
    });

    test(
      'a date in the company format is read through the view model',
      () async {
        repo.answer = const ReportPreview(
          columns: [
            ReportColumn(
              identifier: 'task.start_date',
              displayLabel: 'Start Date',
              type: ReportColumnType.date,
            ),
          ],
          rows: [
            ReportRow(cells: [ReportDateCell(displayValue: '18-10-2026')]),
          ],
        );
        final vm = vmFor(
          report: 'task',
          companyFormat: () async =>
              (datePattern: 'dd-MM-yyyy', firstMonthOfYear: 1),
        );
        await vm.open('task');
        await settle();
        final cell = vm.run.preview!.rows.single.cells.single as ReportDateCell;
        expect(cell.value, Date(2026, 10, 18));
      },
    );
  });

  test('a filter, a further sort or a chart on a column that is gone goes '
      'too', () async {
    ReportColumn col(String id) => ReportColumn(
      identifier: id,
      displayLabel: id,
      type: inferColumnType(id),
    );
    ReportPreview preview(List<String> ids) => ReportPreview(
      columns: [for (final id in ids) col(id)],
      rows: [
        ReportRow(
          cells: [for (final _ in ids) const ReportStringCell(value: 'x')],
        ),
      ],
    );
    repo.answer = preview(['invoice.number', 'invoice.po_number']);
    final vm = vmFor(report: 'invoice');
    await vm.open('invoice');
    await settle();
    vm.setGroup(null);
    vm.setColumnFilter('invoice.po_number', 'PO');
    vm.toggleSort('invoice.number');
    vm.toggleSort('invoice.po_number', additive: true);
    vm.setChartColumn('invoice.po_number');
    expect(vm.thenBy, isNotEmpty);

    repo.answer = preview(['invoice.number']);
    await vm.runReport();
    expect(vm.columnFilters, isEmpty);
    expect(vm.thenBy, isEmpty);
    expect(vm.chartColumn, isNull);
    expect(vm.sortField, 'invoice.number');
  });
}
