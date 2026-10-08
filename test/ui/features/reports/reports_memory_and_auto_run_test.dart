import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/money.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';

class _NullStaticsService implements StaticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReportColumn _col(String id) =>
    ReportColumn(identifier: id, displayLabel: id, type: inferColumnType(id));

ReportPreview _previewOf(List<String> columns, {String marker = 'x'}) =>
    ReportPreview(
      columns: [for (final c in columns) _col(c)],
      rows: [
        ReportRow(
          cells: [
            for (final _ in columns)
              ReportStringCell(value: marker, displayValue: marker),
          ],
        ),
      ],
    );

/// A repository that remembers what it returned, like the real one's cache.
class _Repo implements ReportsRepository {
  _Repo({this.columns = const ['client.name', 'invoice.number']});

  final List<String> columns;
  final List<(String, ReportPayload)> runs = [];
  final Map<String, ({ReportPreview preview, DateTime fetchedAt})> remembered =
      {};
  ReportError? error;
  Completer<void>? gate;
  DateTime Function() clock = DateTime.now;

  static String _key(String report, ReportPayload payload) =>
      '$report|${jsonEncode(payload.forPreview.toJson(reportIdentifier: report))}';

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
    runs.add((reportIdentifier, payload));
    await gate?.future;
    if (isCancelled?.call() == true) {
      throw const ReportError(kind: ReportErrorKind.cancelled);
    }
    final e = error;
    if (e != null) throw e;
    final preview = _previewOf(columns, marker: 'run${runs.length}');
    remembered[_key(reportIdentifier, payload)] = (
      preview: preview,
      fetchedAt: clock(),
    );
    return preview;
  }

  @override
  Future<({ReportPreview preview, DateTime fetchedAt})?> cachedPreview({
    required String companyId,
    required String reportIdentifier,
    required ReportPayload payload,
    FormattedNumberStyle? numberStyle,
  }) async => remembered[_key(reportIdentifier, payload)];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _marker(ReportsViewModel vm) =>
    (vm.run.preview!.rows.single.cells.first as ReportStringCell).value!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StaticsRepository statics;
  var now = DateTime(2026, 10, 8, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    statics = StaticsRepository(db: db, service: _NullStaticsService());
    now = DateTime(2026, 10, 8, 12);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> settle([int ms = 30]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  group('each report keeps its own state', () {
    ReportsViewModel vm0({String report = 'client'}) => ReportsViewModel(
      repo: _Repo(),
      statics: statics,
      initialReport: report,
    );

    test('a report opens on its own first view', () {
      final vm = vm0(report: 'invoice');
      // A year of invoices by month — not a decade of them in a flat list.
      expect(vm.payload.datePreset, ReportDatePreset.thisYear);
      expect(vm.group, 'invoice.date');
      expect(vm.subgroup, ReportSubgroup.month);
      vm.dispose();
    });

    test('a list-first report opens as a list, on everything', () {
      final vm = vm0();
      expect(vm.payload.datePreset, ReportDatePreset.allTime);
      expect(vm.group, isNull);
      vm.dispose();
    });

    test('switching away and back finds a report as it was left', () {
      final vm = vm0(report: 'invoice');
      vm.setPayload(
        vm.payload.copyWith(
          datePreset: ReportDatePreset.lastMonth,
          status: () => 'unpaid',
        ),
      );
      vm.setGroup('client.name');
      vm.setColumnFilter('invoice.balance', '500..');
      vm.setVisibleColumns({'client.name', 'invoice.balance'});
      vm.toggleSort('invoice.balance');
      vm.toggleSort('invoice.balance');

      vm.setReport('payment');
      // The other report is itself, not a copy of the one before it.
      expect(vm.payload.datePreset, ReportDatePreset.thisYear);
      expect(vm.payload.status, isNull);
      expect(vm.group, 'payment.date');
      expect(vm.columnFilters, isEmpty);
      expect(vm.visibleColumnIds, isEmpty);
      expect(vm.sortField, isNull);

      vm.setReport('invoice');
      expect(vm.payload.datePreset, ReportDatePreset.lastMonth);
      expect(vm.payload.status, 'unpaid');
      expect(vm.group, 'client.name');
      expect(vm.columnFilters, {'invoice.balance': '500..'});
      expect(vm.visibleColumnIds, {'client.name', 'invoice.balance'});
      expect(vm.sortField, 'invoice.balance');
      expect(vm.sortAscending, isFalse);
      vm.dispose();
    });

    test('a result does not follow the reader to another report', () async {
      final vm = vm0(report: 'invoice');
      await vm.runReport();
      expect(vm.run.preview, isNotNull);
      vm.setReport('payment');
      expect(vm.run.status, ReportRunStatus.idle);
      expect(vm.run.preview, isNull);
      vm.dispose();
    });

    test('the reports opened are listed most recent first', () {
      final vm = vm0();
      vm.setReport('invoice');
      vm.setReport('payment');
      vm.setReport('invoice');
      expect(vm.recentReports, ['invoice', 'payment']);
      vm.dispose();
    });

    test('survives a restart, for every report visited', () async {
      ReportsViewModel build() => ReportsViewModel(
        repo: _Repo(),
        statics: statics,
        navStateDao: db.navStateDao,
        companyId: 'co1',
        persistDebounce: Duration.zero,
      );
      final vm1 = build();
      await vm1.hydration;
      vm1.setReport('invoice');
      vm1.setGroup('client.name');
      vm1.setReport('payment');
      vm1.setPayload(
        vm1.payload.copyWith(datePreset: ReportDatePreset.lastQuarter),
      );
      vm1.setCurrency('3');
      vm1.setColumnWidth('payment.amount', 180);
      vm1.toggleSort('payment.date');
      vm1.toggleSort('payment.amount', additive: true);
      await settle();
      vm1.dispose();

      final vm2 = build();
      await vm2.hydration;
      expect(vm2.reportIdentifier, 'payment');
      expect(vm2.payload.datePreset, ReportDatePreset.lastQuarter);
      expect(vm2.currencyId, '3');
      expect(vm2.columnWidths, {'payment.amount': 180.0});
      expect(vm2.sortField, 'payment.date');
      expect(vm2.thenBy, [const ReportSort('payment.amount')]);
      expect(vm2.recentReports, ['payment', 'invoice']);
      vm2.setReport('invoice');
      expect(vm2.group, 'client.name');
      vm2.dispose();
    });

    test('a state written by an earlier build is read as it was', () async {
      // The one-report shape every build before this wrote.
      await db.navStateDao.saveFilters(
        filtersJson: jsonEncode({
          'co1': {
            'reports': {
              'report': 'expense',
              'payload': {
                'datePreset': 'lastYear',
                'status': 'paid',
                'documentEmailAttachment': true,
                'pdfEmailAttachment': true,
                'includeDeleted': true,
              },
              'visibleColumns': ['expense.amount'],
              'columnFilters': <String, String>{},
              'group': 'expense.category_id',
              'sortAscending': true,
              'panelCollapsed': true,
              'chartVisible': false,
            },
          },
        }),
        now: 1,
      );
      final vm = ReportsViewModel(
        repo: _Repo(),
        statics: statics,
        navStateDao: db.navStateDao,
        companyId: 'co1',
      );
      await vm.hydration;
      expect(vm.reportIdentifier, 'expense');
      expect(vm.payload.datePreset, ReportDatePreset.lastYear);
      expect(vm.payload.status, 'paid');
      expect(vm.payload.includeDeleted, isTrue);
      expect(vm.group, 'expense.category_id');
      expect(vm.visibleColumnIds, {'expense.amount'});
      expect(vm.chartVisible, isFalse);
      // A switch remembered from another month must not attach every PDF to
      // an email sent today.
      expect(vm.payload.documentEmailAttachment, isFalse);
      expect(vm.payload.pdfEmailAttachment, isFalse);
      vm.dispose();
    });

    test('what is written still reads as the old shape', () async {
      // A rolled-back build looks for the current report at the top level.
      final vm = ReportsViewModel(
        repo: _Repo(),
        statics: statics,
        navStateDao: db.navStateDao,
        companyId: 'co1',
        persistDebounce: Duration.zero,
      );
      await vm.hydration;
      vm.setReport('invoice');
      vm.setGroup('client.name');
      await settle();
      final row = await db.navStateDao.current();
      final snap =
          (jsonDecode(row!.filtersJson!) as Map)['co1']['reports'] as Map;
      expect(snap['report'], 'invoice');
      expect(snap['group'], 'client.name');
      expect((snap['payload'] as Map)['datePreset'], 'thisYear');
      vm.dispose();
    });

    test(
      'open() takes the report from the caller, not from the restore',
      () async {
        ReportsViewModel build() => ReportsViewModel(
          repo: _Repo(),
          statics: statics,
          navStateDao: db.navStateDao,
          companyId: 'co1',
          persistDebounce: Duration.zero,
        );
        final vm1 = build();
        await vm1.hydration;
        vm1.setReport('invoice');
        vm1.setGroup('invoice.status');
        await settle();
        vm1.dispose();

        // The route says "client" — the default — while disk says "invoice".
        final vm2 = build();
        await vm2.open('client');
        expect(vm2.reportIdentifier, 'client');
        // …and the report on disk kept what it remembered.
        await vm2.open('invoice');
        expect(vm2.group, 'invoice.status');
        vm2.dispose();
      },
    );
  });

  group('the first run shows a curated set of columns', () {
    test('the report\'s own, in its own order', () async {
      final repo = _Repo(
        columns: [
          'client.name',
          'client.vat_number',
          'invoice.amount',
          'invoice.number',
          'invoice.custom_value1',
          'invoice.date',
        ],
      );
      final vm = ReportsViewModel(
        repo: repo,
        statics: statics,
        initialReport: 'invoice',
      );
      await vm.runReport();
      expect(vm.visibleColumnIds, {
        'client.name',
        'invoice.number',
        'invoice.date',
        'invoice.amount',
      });
      final view = vm.buildView();
      // Grouped by date on opening, so the date leads; then the curated order.
      expect(view.visibleColumns.map((c) => c.identifier), [
        'invoice.date',
        'client.name',
        'invoice.number',
        'invoice.amount',
      ]);
      // Everything else is still there to be switched on.
      expect(vm.run.preview!.columns, hasLength(6));
      vm.dispose();
    });

    test('everything, when the server returns none of them', () async {
      final repo = _Repo(columns: ['a', 'b']);
      final vm = ReportsViewModel(
        repo: repo,
        statics: statics,
        initialReport: 'invoice',
      );
      await vm.runReport();
      expect(vm.visibleColumnIds, {'a', 'b'});
      vm.dispose();
    });

    test('a choice the reader made is not replaced', () async {
      final repo = _Repo(columns: ['client.name', 'invoice.amount', 'x']);
      final vm = ReportsViewModel(
        repo: repo,
        statics: statics,
        initialReport: 'invoice',
      );
      vm.setVisibleColumns({'x'});
      await vm.runReport();
      expect(vm.visibleColumnIds, {'x'});
      vm.dispose();
    });
  });

  group('sorting by more than one column', () {
    test('a shift-click adds a key; a plain click starts over', () {
      final vm = ReportsViewModel(repo: _Repo(), statics: statics);
      vm.toggleSort('a');
      vm.toggleSort('b', additive: true);
      vm.toggleSort('c', additive: true);
      expect(vm.sortField, 'a');
      expect(vm.thenBy, [const ReportSort('b'), const ReportSort('c')]);

      // Shift-clicking one already there flips it where it stands.
      vm.toggleSort('b', additive: true);
      expect(vm.thenBy, [
        const ReportSort('b', ascending: false),
        const ReportSort('c'),
      ]);

      vm.toggleSort('c');
      expect(vm.sortField, 'c');
      expect(vm.thenBy, isEmpty);
      vm.dispose();
    });

    test('a shift-click with no sort yet is just a sort', () {
      final vm = ReportsViewModel(repo: _Repo(), statics: statics);
      vm.toggleSort('a', additive: true);
      expect(vm.sortField, 'a');
      expect(vm.thenBy, isEmpty);
      vm.dispose();
    });
  });

  group('auto-run', () {
    late _Repo repo;
    var online = StreamController<bool>.broadcast();
    var allowed = true;

    setUp(() {
      repo = _Repo()..clock = () => now;
      online = StreamController<bool>.broadcast();
      allowed = true;
    });

    tearDown(() => online.close());

    ReportsViewModel build({String report = 'invoice'}) => ReportsViewModel(
      repo: repo,
      statics: statics,
      initialReport: report,
      companyId: 'co1',
      autoRun: true,
      canRun: () => allowed,
      online: online.stream,
      now: () => now,
      autoRunDebounce: const Duration(milliseconds: 10),
      freshFor: const Duration(minutes: 5),
    );

    test('opening a report runs it', () async {
      final vm = build();
      await vm.open('invoice');
      expect(repo.runs, hasLength(1));
      expect(vm.run.status, ReportRunStatus.ready);
      expect(vm.resultFetchedAt, now);
      vm.dispose();
    });

    test('a report with nothing to show on screen is not run', () async {
      final vm = build(report: 'profitloss');
      await vm.open('profitloss');
      expect(repo.runs, isEmpty);
      vm.dispose();
    });

    test(
      'a change that alters the rows re-runs, once it has settled',
      () async {
        final vm = build();
        await vm.open('invoice');
        vm.setPayload(vm.payload.copyWith(status: () => 'paid'));
        vm.setPayload(vm.payload.copyWith(status: () => 'paid,unpaid'));
        vm.setPayload(
          vm.payload.copyWith(datePreset: ReportDatePreset.lastMonth),
        );
        expect(repo.runs, hasLength(1), reason: 'not on every keystroke');
        await settle();
        expect(repo.runs, hasLength(2));
        expect(repo.runs.last.$2.status, 'paid,unpaid');
        expect(repo.runs.last.$2.datePreset, ReportDatePreset.lastMonth);
        vm.dispose();
      },
    );

    test('a change that cannot alter the rows does not run anything', () async {
      final vm = build();
      await vm.open('invoice');
      vm.setPayload(vm.payload.copyWith(templateId: () => 'tpl'));
      vm.setPayload(vm.payload.copyWith(pdfEmailAttachment: true));
      // Nor does anything local.
      vm.setGroup('client.name');
      vm.toggleSort('invoice.amount');
      vm.setSearch('acme');
      vm.setColumnFilter('invoice.status', 'Paid');
      await settle();
      expect(repo.runs, hasLength(1));
      expect(vm.isParamDirty, isFalse);
      vm.dispose();
    });

    test('a result still fresh is shown again, not fetched again', () async {
      final vm = build();
      await vm.open('invoice');
      vm.setReport('payment');
      await vm.open('payment');
      expect(repo.runs, hasLength(2));

      now = now.add(const Duration(minutes: 2));
      await vm.open('invoice');
      expect(repo.runs, hasLength(2), reason: 'two minutes old is current');
      expect(vm.run.status, ReportRunStatus.ready);
      expect(_marker(vm), 'run1');
      vm.dispose();
    });

    test('a stale result is shown at once and refreshed behind', () async {
      final vm = build();
      await vm.open('invoice');
      final first = vm.resultFetchedAt;
      vm.setReport('payment');

      now = now.add(const Duration(minutes: 30));
      repo.gate = Completer<void>();
      final opening = vm.open('invoice');
      await settle();
      // The old rows are on screen while the new ones are fetched.
      expect(vm.run.isLoading, isTrue);
      expect(_marker(vm), 'run1');
      expect(vm.resultFetchedAt, first);

      repo.gate!.complete();
      await opening;
      expect(vm.run.status, ReportRunStatus.ready);
      expect(_marker(vm), 'run2');
      expect(vm.resultFetchedAt, now);
      vm.dispose();
    });

    test('going back to a range already seen shows it straight away', () async {
      final vm = build();
      await vm.open('invoice');
      final thisYear = vm.payload;
      vm.setPayload(thisYear.copyWith(datePreset: ReportDatePreset.lastMonth));
      await settle();
      expect(repo.runs, hasLength(2));

      vm.setPayload(thisYear);
      await settle();
      expect(repo.runs, hasLength(2));
      expect(_marker(vm), 'run1');
      expect(vm.isParamDirty, isFalse);
      vm.dispose();
    });

    test(
      'offline: nothing is asked, and the run is made on reconnecting',
      () async {
        final vm = build();
        online.add(false);
        await settle(5);
        expect(vm.isOnline, isFalse);
        await vm.open('invoice');
        expect(repo.runs, isEmpty);

        online.add(true);
        await settle();
        expect(repo.runs, hasLength(1));
        expect(vm.run.status, ReportRunStatus.ready);
        vm.dispose();
      },
    );

    test('offline, a remembered result still opens', () async {
      final vm = build();
      await vm.open('invoice');
      vm.setReport('payment');
      online.add(false);
      await settle(5);
      now = now.add(const Duration(hours: 3));

      await vm.open('invoice');
      expect(repo.runs, hasLength(1));
      expect(vm.run.status, ReportRunStatus.ready);
      expect(_marker(vm), 'run1');
      vm.dispose();
    });

    test('behind the plan gate nothing runs until it lifts', () async {
      allowed = false;
      final vm = build();
      await vm.open('invoice');
      expect(repo.runs, isEmpty);

      allowed = true;
      vm.retryOwed();
      await settle();
      expect(repo.runs, hasLength(1));
      vm.dispose();
    });

    test('a rate limit is an error to show, not one to retry into', () async {
      repo.error = const ReportError(
        kind: ReportErrorKind.rateLimited,
        retryAfter: Duration(seconds: 30),
      );
      final vm = build();
      await vm.open('invoice');
      await settle(60);
      expect(repo.runs, hasLength(1));
      expect(vm.run.error?.kind, ReportErrorKind.rateLimited);
      vm.dispose();
    });

    test('switching report strands a run still pending', () async {
      final vm = build();
      await vm.open('invoice');
      vm.setPayload(vm.payload.copyWith(status: () => 'paid'));
      vm.setReport('client');
      await settle();
      expect(repo.runs.map((r) => r.$1), ['invoice']);
      vm.dispose();
    });

    test('off, nothing runs by itself', () async {
      final vm = ReportsViewModel(
        repo: repo,
        statics: statics,
        initialReport: 'invoice',
        autoRunDebounce: Duration.zero,
      );
      await vm.open('invoice');
      vm.setPayload(vm.payload.copyWith(status: () => 'paid'));
      await settle();
      expect(repo.runs, isEmpty);
      vm.dispose();
    });
  });
}
