import 'dart:async';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';

class _Trigger {
  final Completer<void> _gate = Completer<void>();
  void release() {
    if (!_gate.isCompleted) _gate.complete();
  }

  Future<void> get future => _gate.future;
}

/// Repository fake — drives runReport's behavior step-by-step via Triggers
/// so the test can interleave concurrent calls deterministically.
class _FakeRepo implements ReportsRepository {
  final List<_Trigger> _gates = [];
  final List<Object> _outcomes = [];

  /// Queue a "this call waits on [gate] then returns [preview]".
  void queue(_Trigger gate, ReportPreview preview) {
    _gates.add(gate);
    _outcomes.add(preview);
  }

  /// Queue a "this call waits on [gate] then throws [error]".
  void queueError(_Trigger gate, Object error) {
    _gates.add(gate);
    _outcomes.add(error);
  }

  int callCount = 0;

  /// Records the `reportKeys` passed to each preview / export call so tests
  /// can assert preview never narrows columns while export honors the
  /// selection (F1).
  final List<List<String>> previewReportKeys = [];
  final List<List<String>> exportReportKeys = [];

  @override
  Future<ReportPreview> runPreview({
    required String reportIdentifier,
    required String endpoint,
    required ReportPayload payload,
    List<String> reportKeys = const [],
    int maxRetries = ReportsApi.defaultPreviewRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async {
    previewReportKeys.add(reportKeys);
    final i = callCount++;
    await _gates[i].future;
    if (isCancelled?.call() == true) {
      throw const ReportError(kind: ReportErrorKind.cancelled);
    }
    final out = _outcomes[i];
    if (out is ReportPreview) return out;
    throw out;
  }

  /// Preview returned by `keepWaiting`'s continuation, when a test sets one.
  ReportPreview? continuation;

  @override
  Future<ReportPreview> continuePreview({
    required String hash,
    int maxRetries = ReportsApi.defaultPreviewRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async {
    final p = continuation;
    if (p == null) throw UnimplementedError();
    return p;
  }

  /// Export hook: when [exportError] is set it's thrown; otherwise
  /// [exportResult] (or a default) is returned. [exportCalls] records each
  /// invocation's format for assertions.
  ReportExportResult? exportResult;
  Object? exportError;
  final List<ReportExportFormat> exportCalls = [];

  /// Email hook: throw [sendEmailError] if set; record call count.
  Object? sendEmailError;
  int sendEmailCalls = 0;

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
  }) async {
    exportCalls.add(format);
    exportReportKeys.add(reportKeys);
    if (isCancelled?.call() == true) {
      throw const ReportError(kind: ReportErrorKind.cancelled);
    }
    if (exportError != null) throw exportError!;
    return exportResult ??
        ReportExportResult(bytes: Uint8List.fromList([1, 2, 3]), hash: 'h');
  }

  @override
  Future<ReportExportResult> continueExport({
    required String hash,
    required ReportExportFormat format,
    int maxRetries = ReportsApi.defaultExportRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async {
    if (exportError != null) throw exportError!;
    return exportResult ??
        ReportExportResult(bytes: Uint8List.fromList([1]), hash: hash);
  }

  @override
  Future<void> sendEmail({
    required String reportIdentifier,
    required String endpoint,
    required ReportPayload payload,
    List<String> reportKeys = const [],
    String? groupBy,
  }) async {
    sendEmailCalls++;
    if (sendEmailError != null) throw sendEmailError!;
  }

  @override
  ReportsApi get api => throw UnsupportedError('not used by tests');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StaticsRepository statics;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    statics = StaticsRepository(db: db, service: _NullStaticsService());
  });

  tearDown(() async {
    await db.close();
  });

  ReportPreview previewOf(String marker) => ReportPreview(
    columns: const [],
    rows: [
      ReportRow(
        cells: [ReportStringCell(value: marker, displayValue: marker)],
      ),
    ],
  );

  // A product-shaped preview with numeric price + in_stock_quantity columns,
  // so the VM can compute the synthetic stock_value column.
  ReportPreview productPreview() => ReportPreview(
    columns: const [
      ReportColumn(
        identifier: 'product_key',
        displayLabel: 'Product',
        type: ReportColumnType.string,
      ),
      ReportColumn(
        identifier: 'price',
        displayLabel: 'Price',
        type: ReportColumnType.money,
      ),
      ReportColumn(
        identifier: 'in_stock_quantity',
        displayLabel: 'Stock',
        type: ReportColumnType.number,
      ),
    ],
    rows: [
      ReportRow(
        cells: [
          const ReportStringCell(value: 'A'),
          ReportNumberCell(
            value: Decimal.fromInt(10),
            isMoney: true,
            currencyId: '1',
          ),
          ReportNumberCell(value: Decimal.fromInt(3)),
        ],
      ),
      ReportRow(
        cells: [
          const ReportStringCell(value: 'B'),
          ReportNumberCell(
            value: Decimal.fromInt(5),
            isMoney: true,
            currencyId: '1',
          ),
          ReportNumberCell(value: Decimal.fromInt(4)),
        ],
      ),
    ],
  );

  group('product report stock_value injection', () {
    test(
      'appends a computed stock_value money column with per-row values',
      () async {
        final repo = _FakeRepo();
        repo.queue(_Trigger()..release(), productPreview());
        final vm = ReportsViewModel(
          repo: repo,
          statics: statics,
          initialReport: 'product',
        );
        await vm.runReport();

        final preview = vm.run.preview!;
        final col = preview.columns.last;
        expect(col.identifier, 'stock_value');
        expect(col.type, ReportColumnType.money);
        expect(col.displayLabel, 'Stock value');

        final r0 = preview.rows[0].cells.last as ReportNumberCell;
        final r1 = preview.rows[1].cells.last as ReportNumberCell;
        expect(r0.value, Decimal.fromInt(30)); // 10 × 3
        expect(r0.isMoney, isTrue);
        expect(r0.currencyId, '1'); // carries the price cell's currency
        expect(r1.value, Decimal.fromInt(20)); // 5 × 4
      },
    );

    test('does not inject for non-product reports', () async {
      final repo = _FakeRepo();
      repo.queue(_Trigger()..release(), productPreview());
      // Default report identifier (clients), not product.
      final vm = ReportsViewModel(repo: repo, statics: statics);
      await vm.runReport();
      expect(
        vm.run.preview!.columns.any((c) => c.identifier == 'stock_value'),
        isFalse,
      );
    });

    test('strips the synthetic stock_value key from export', () async {
      final repo = _FakeRepo();
      repo.queue(_Trigger()..release(), productPreview());
      final vm = ReportsViewModel(
        repo: repo,
        statics: statics,
        initialReport: 'product',
      );
      await vm.runReport();
      expect(vm.visibleColumnIds.contains('stock_value'), isTrue);

      await vm.runExport(ReportExportFormat.csv);
      expect(repo.exportReportKeys.single, isNot(contains('stock_value')));
      expect(repo.exportReportKeys.single, contains('price'));
    });

    test(
      'serverReportKeys strips the synthetic key (ordered + unordered)',
      () async {
        // Covers the schedule flow too — the Schedule button delegates to
        // vm.serverReportKeys(ordered: true).
        final repo = _FakeRepo();
        repo.queue(_Trigger()..release(), productPreview());
        final vm = ReportsViewModel(
          repo: repo,
          statics: statics,
          initialReport: 'product',
        );
        await vm.runReport();
        expect(vm.visibleColumnIds.contains('stock_value'), isTrue);
        expect(vm.serverReportKeys(), isNot(contains('stock_value')));
        expect(vm.serverReportKeys(), contains('price'));
        expect(
          vm.serverReportKeys(ordered: true),
          isNot(contains('stock_value')),
        );
        expect(vm.serverReportKeys(ordered: true), contains('price'));
      },
    );
  });

  test(
    'isParamDirty flips on payload change and clears after a successful run',
    () async {
      final repo = _FakeRepo();
      final firstGate = _Trigger()..release();
      repo.queue(firstGate, previewOf('a'));
      final vm = ReportsViewModel(repo: repo, statics: statics);

      // Edit the date preset → dirty without a run.
      vm.setPayload(
        vm.payload.copyWith(datePreset: ReportDatePreset.lastMonth),
      );
      expect(vm.isParamDirty, isTrue);

      await vm.runReport();
      expect(vm.run.status, ReportRunStatus.ready);
      expect(vm.isParamDirty, isFalse);

      vm.setPayload(vm.payload.copyWith(datePreset: ReportDatePreset.thisYear));
      expect(vm.isParamDirty, isTrue);
    },
  );

  test(
    'concurrent Runs: only the latest result lands; older futures no-op',
    () async {
      final repo = _FakeRepo();
      final g1 = _Trigger();
      final g2 = _Trigger();
      repo.queue(g1, previewOf('first'));
      repo.queue(g2, previewOf('second'));
      final vm = ReportsViewModel(repo: repo, statics: statics);

      final f1 = vm.runReport();
      final f2 = vm.runReport();
      // Release the *second* call first — that's the one whose epoch matches.
      g2.release();
      await f2;
      // Release the first call — its epoch is stale, must not overwrite.
      g1.release();
      await f1;
      expect(vm.run.status, ReportRunStatus.ready);
      expect(
        (vm.run.preview!.rows.first.cells.first as ReportStringCell).value,
        'second',
      );
    },
  );

  test('cancelRun bumps epoch and restores previous preview', () async {
    final repo = _FakeRepo();
    final firstGate = _Trigger()..release();
    repo.queue(firstGate, previewOf('a'));
    final secondGate = _Trigger();
    repo.queue(secondGate, previewOf('b'));
    final vm = ReportsViewModel(repo: repo, statics: statics);

    await vm.runReport();
    expect(vm.run.status, ReportRunStatus.ready);

    final pending = vm.runReport();
    expect(vm.run.isLoading, isTrue);
    vm.cancelRun();
    expect(vm.run.status, ReportRunStatus.ready);
    expect(
      (vm.run.preview!.rows.first.cells.first as ReportStringCell).value,
      'a',
    );
    secondGate.release();
    await pending;
    // The first preview is still what the user sees — the stranded second
    // run did not overwrite.
    expect(
      (vm.run.preview!.rows.first.cells.first as ReportStringCell).value,
      'a',
    );
  });

  group('chartColumn', () {
    test('setChartColumn updates the getter and notifies listeners', () async {
      final repo = _FakeRepo();
      final vm = ReportsViewModel(repo: repo, statics: statics);
      var notified = 0;
      vm.addListener(() => notified++);

      expect(vm.chartColumn, isNull);
      vm.setChartColumn('invoice.amount');
      expect(vm.chartColumn, 'invoice.amount');
      expect(notified, 1);

      // Same value is a no-op — no second notification.
      vm.setChartColumn('invoice.amount');
      expect(notified, 1);

      // Null clears.
      vm.setChartColumn(null);
      expect(vm.chartColumn, isNull);
      expect(notified, 2);
    });

    test(
      'setReport clears chartColumn (new report\'s columns are unrelated)',
      () async {
        final repo = _FakeRepo();
        final vm = ReportsViewModel(repo: repo, statics: statics);
        vm.setChartColumn('invoice.amount');
        expect(vm.chartColumn, 'invoice.amount');

        // Switch to any other registered report — the identifier just needs
        // to differ; we don't run it, only assert the reset behavior.
        final otherId = vm.reportIdentifier == 'invoice'
            ? 'payment'
            : 'invoice';
        vm.setReport(otherId);
        expect(vm.chartColumn, isNull);
      },
    );

    test('resetEverything clears chartColumn', () async {
      final repo = _FakeRepo();
      final vm = ReportsViewModel(repo: repo, statics: statics);
      vm.setChartColumn('invoice.amount');
      vm.resetEverything();
      expect(vm.chartColumn, isNull);
    });

    test(
      'numericChartColumns returns only money + number types from preview',
      () async {
        final repo = _FakeRepo();
        final firstGate = _Trigger()..release();
        repo.queue(
          firstGate,
          const ReportPreview(
            columns: [
              ReportColumn(
                identifier: 'invoice.client',
                displayLabel: 'Client',
                type: ReportColumnType.string,
              ),
              ReportColumn(
                identifier: 'invoice.amount',
                displayLabel: 'Amount',
                type: ReportColumnType.money,
              ),
              ReportColumn(
                identifier: 'invoice.count',
                displayLabel: 'Count',
                type: ReportColumnType.number,
              ),
              ReportColumn(
                identifier: 'invoice.created_at',
                displayLabel: 'Created',
                type: ReportColumnType.dateTime,
              ),
            ],
            rows: [],
          ),
        );
        final vm = ReportsViewModel(repo: repo, statics: statics);
        // Before a Run lands → no preview → empty list.
        expect(vm.numericChartColumns(), isEmpty);

        await vm.runReport();
        final ids = vm.numericChartColumns().map((c) => c.identifier).toList();
        expect(ids, ['invoice.amount', 'invoice.count']);
      },
    );
  });

  test('dispose strands in-flight futures cleanly', () async {
    final repo = _FakeRepo();
    final gate = _Trigger();
    repo.queue(gate, previewOf('a'));
    final vm = ReportsViewModel(repo: repo, statics: statics);

    final pending = vm.runReport();
    vm.dispose();
    gate.release();
    // Must complete without throwing or calling notifyListeners after
    // dispose — pending should resolve via the disposed check.
    await pending;
  });

  test(
    'runExport returns result, records format, toggles isExporting',
    () async {
      final repo = _FakeRepo()
        ..exportResult = ReportExportResult(
          bytes: Uint8List.fromList([7]),
          hash: 'h7',
        );
      final vm = ReportsViewModel(repo: repo, statics: statics);
      expect(vm.isExporting, isFalse);

      final res = await vm.runExport(ReportExportFormat.csv);

      expect(res, isNotNull);
      expect(res!.bytes, [7]);
      expect(repo.exportCalls, [ReportExportFormat.csv]);
      expect(vm.isExporting, isFalse);
      expect(vm.exportError, isNull);
    },
  );

  test('runExport surfaces error into exportError, returns null', () async {
    final repo = _FakeRepo()
      ..exportError = const ReportError(kind: ReportErrorKind.serverError);
    final vm = ReportsViewModel(repo: repo, statics: statics);

    final res = await vm.runExport(ReportExportFormat.pdf);

    expect(res, isNull);
    expect(vm.exportError?.kind, ReportErrorKind.serverError);
    expect(vm.isExporting, isFalse);
  });

  test('runExport guards against double-submit', () async {
    final repo = _FakeRepo()
      ..exportResult = ReportExportResult(
        bytes: Uint8List.fromList([1]),
        hash: 'h',
      );
    final vm = ReportsViewModel(repo: repo, statics: statics);

    final a = vm.runExport(ReportExportFormat.pdf);
    final b = vm.runExport(ReportExportFormat.pdf); // ignored while in-flight
    await a;
    final second = await b;

    expect(second, isNull);
    expect(repo.exportCalls.length, 1);
  });

  test('sendEmail toggles isEmailing and calls repo; error rethrows', () async {
    final repo = _FakeRepo();
    final vm = ReportsViewModel(repo: repo, statics: statics);

    await vm.sendEmail();
    expect(repo.sendEmailCalls, 1);
    expect(vm.isEmailing, isFalse);

    repo.sendEmailError = const ReportError(kind: ReportErrorKind.network);
    await expectLater(vm.sendEmail(), throwsA(isA<ReportError>()));
    expect(vm.isEmailing, isFalse);
  });

  test('panelCollapsed toggles and notifies', () {
    final vm = ReportsViewModel(repo: _FakeRepo(), statics: statics);
    var notified = 0;
    vm.addListener(() => notified++);
    expect(vm.panelCollapsed, isFalse);
    vm.setPanelCollapsed(true);
    expect(vm.panelCollapsed, isTrue);
    expect(notified, 1);
    vm.setPanelCollapsed(true); // no-op, no extra notify
    expect(notified, 1);
  });

  group('column selection (F1)', () {
    ReportPreview colsPreview(List<String> ids) => ReportPreview(
      columns: [
        for (final id in ids)
          ReportColumn(
            identifier: id,
            displayLabel: id,
            type: ReportColumnType.string,
          ),
      ],
      rows: const [],
    );

    test(
      'preview requests the full column set; export honors the selection',
      () async {
        final repo = _FakeRepo();
        final g1 = _Trigger()..release();
        repo.queue(g1, colsPreview(['a', 'b', 'c']));
        final vm = ReportsViewModel(repo: repo, statics: statics);

        // First run: no selection yet → preview sends empty report_keys, and
        // the returned columns become the visible set.
        await vm.runReport();
        expect(repo.previewReportKeys.single, isEmpty);
        expect(vm.visibleColumnIds, {'a', 'b', 'c'});

        // Hide a column locally, then export → export carries the subset.
        vm.setVisibleColumns({'a', 'c'});
        await vm.runExport(ReportExportFormat.csv);
        expect(repo.exportReportKeys.single, unorderedEquals(['a', 'c']));
      },
    );

    test(
      'a deselected column survives a re-run and stays re-addable',
      () async {
        final repo = _FakeRepo();
        final g1 = _Trigger()..release();
        final g2 = _Trigger()..release();
        // The server returns the full set on every preview (with the optional
        // date column off — the only thing that sends report_keys — the VM
        // sends none).
        repo.queue(g1, colsPreview(['a', 'b', 'c']));
        repo.queue(g2, colsPreview(['a', 'b', 'c']));
        final vm = ReportsViewModel(repo: repo, statics: statics);

        await vm.runReport();
        vm.setVisibleColumns({'a', 'c'}); // hide 'b'
        await vm.runReport();

        // 'b' stays hidden across the re-run...
        expect(vm.visibleColumnIds, {'a', 'c'});
        // ...but is still in the preview, so the column picker can re-add it.
        expect(
          vm.run.preview!.columns.map((c) => c.identifier),
          containsAll(['a', 'b', 'c']),
        );
        // Neither preview run narrowed the columns.
        expect(repo.previewReportKeys, [isEmpty, isEmpty]);
      },
    );
  });

  group('restore-on-restart persistence', () {
    test('round-trips report + payload + view state for the company', () async {
      final vm1 = ReportsViewModel(
        repo: _FakeRepo(),
        statics: statics,
        navStateDao: db.navStateDao,
        companyId: 'co1',
        persistDebounce: Duration.zero,
      );
      await vm1.hydration;
      vm1.setReport('invoice');
      vm1.setPayload(
        vm1.payload.copyWith(datePreset: ReportDatePreset.lastMonth),
      );
      vm1.setVisibleColumns({'a', 'b'});
      vm1.setColumnFilter('a', 'foo');
      vm1.setPanelCollapsed(true);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final vm2 = ReportsViewModel(
        repo: _FakeRepo(),
        statics: statics,
        navStateDao: db.navStateDao,
        companyId: 'co1',
      );
      await vm2.hydration;
      expect(vm2.reportIdentifier, 'invoice');
      expect(vm2.payload.datePreset, ReportDatePreset.lastMonth);
      expect(vm2.visibleColumnIds, {'a', 'b'});
      expect(vm2.columnFilters['a'], 'foo');
      expect(vm2.panelCollapsed, isTrue);
    });

    test('round-trips columnOrder across restart', () async {
      final vm1 = ReportsViewModel(
        repo: _FakeRepo(),
        statics: statics,
        navStateDao: db.navStateDao,
        companyId: 'co1',
        persistDebounce: Duration.zero,
      );
      await vm1.hydration;
      vm1.setReport('invoice');
      vm1.setVisibleColumns({'a', 'b', 'c'}, order: ['c', 'a', 'b']);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final vm2 = ReportsViewModel(
        repo: _FakeRepo(),
        statics: statics,
        navStateDao: db.navStateDao,
        companyId: 'co1',
      );
      await vm2.hydration;
      expect(vm2.columnOrder, ['c', 'a', 'b']);
    });

    test('does not cross-read another company\'s snapshot', () async {
      final a = ReportsViewModel(
        repo: _FakeRepo(),
        statics: statics,
        navStateDao: db.navStateDao,
        companyId: 'A',
        persistDebounce: Duration.zero,
      );
      await a.hydration;
      a.setReport('payment');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final b = ReportsViewModel(
        repo: _FakeRepo(),
        statics: statics,
        navStateDao: db.navStateDao,
        companyId: 'B',
      );
      await b.hydration;
      expect(b.reportIdentifier, isNot('payment'));
    });

    test(
      'reconciles stale persisted columns/group against live preview',
      () async {
        // Seed co1 with a snapshot referencing columns a stale report had.
        final seed = ReportsViewModel(
          repo: _FakeRepo(),
          statics: statics,
          navStateDao: db.navStateDao,
          companyId: 'co1',
          persistDebounce: Duration.zero,
        );
        await seed.hydration;
        seed.setVisibleColumns({'old1', 'old2'});
        seed.setGroup('old1');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final repo = _FakeRepo();
        final gate = _Trigger()..release();
        repo.queue(
          gate,
          const ReportPreview(
            columns: [
              ReportColumn(
                identifier: 'old1',
                type: ReportColumnType.string,
                displayLabel: 'Old1',
              ),
              ReportColumn(
                identifier: 'newcol',
                type: ReportColumnType.string,
                displayLabel: 'New',
              ),
            ],
            rows: [],
          ),
        );
        final vm = ReportsViewModel(
          repo: repo,
          statics: statics,
          navStateDao: db.navStateDao,
          companyId: 'co1',
        );
        await vm.hydration;
        expect(vm.visibleColumnIds, {'old1', 'old2'});
        await vm.runReport();
        // old2 dropped (no longer returned); newcol NOT auto-shown — preview
        // always requests the full set now, so auto-adding would re-show every
        // hidden column on each run. The picker still exposes newcol for manual
        // add. Group kept (old1 still exists).
        expect(vm.visibleColumnIds, {'old1'});
        expect(vm.group, 'old1');
      },
    );

    test(
      'a user action before hydration is not clobbered by restore',
      () async {
        // Seed co1 with 'payment' persisted.
        final seed = ReportsViewModel(
          repo: _FakeRepo(),
          statics: statics,
          navStateDao: db.navStateDao,
          companyId: 'co1',
          persistDebounce: Duration.zero,
        );
        await seed.hydration;
        seed.setReport('payment');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // New VM for co1: hydration kicks off but suspends on the Drift read.
        // Switch report synchronously, before hydration resolves.
        final vm = ReportsViewModel(
          repo: _FakeRepo(),
          statics: statics,
          navStateDao: db.navStateDao,
          companyId: 'co1',
        );
        vm.setReport(
          'invoice',
        ); // user acts before _hydrate applies the snapshot
        await vm.hydration;
        // The live action wins; the persisted 'payment' did not overwrite it.
        expect(vm.reportIdentifier, 'invoice');
      },
    );
  });

  // invoiceninja/flutter#138. The clients report's date range filters on
  // `clients.created_at`, but the server's default column set carries no
  // `created_at` — so there is nothing to group or chart by until the app
  // asks for that column by name. Everything here is about asking for it
  // without breaking the "preview never narrows the columns" invariant.
  group('optional date column', () {
    ReportPreview clientPreview(List<String> ids) => ReportPreview(
      columns: [
        for (final id in ids)
          ReportColumn(
            identifier: id,
            // What the server actually answers for a key it has no
            // report-key entry for: `ctrans('texts.')`.
            displayLabel: id == 'client.created_at' ? 'texts.' : id,
            type: inferColumnType(id),
          ),
      ],
      rows: const [],
    );

    test('off by default — preview sends no report_keys', () async {
      final repo = _FakeRepo();
      repo.queue(_Trigger()..release(), clientPreview(['client.name']));
      final vm = ReportsViewModel(repo: repo, statics: statics);
      await vm.runReport();
      expect(vm.includeDateColumn, isFalse);
      expect(repo.previewReportKeys.single, isEmpty);
    });

    test('on, preview asks for the known set plus the extra column', () async {
      final repo = _FakeRepo();
      repo.queue(
        _Trigger()..release(),
        clientPreview(['client.name', 'client.balance']),
      );
      repo.queue(
        _Trigger()..release(),
        clientPreview(['client.name', 'client.balance', 'client.created_at']),
      );
      final vm = ReportsViewModel(repo: repo, statics: statics);
      await vm.runReport();
      vm.setIncludeDateColumn(true);
      await vm.runReport();

      expect(repo.previewReportKeys[0], isEmpty);
      expect(repo.previewReportKeys[1], [
        'client.name',
        'client.balance',
        'client.created_at',
      ]);
    });

    // The bug this exists for: after the first augmented run the preview
    // *contains* the extra column, so a "skip if already present" guard
    // would send `[]` on the second run and the column would vanish again —
    // invisible unless you press Run twice.
    test('a second augmented run still carries it exactly once', () async {
      final repo = _FakeRepo();
      final augmented = clientPreview([
        'client.name',
        'client.balance',
        'client.created_at',
      ]);
      repo.queue(
        _Trigger()..release(),
        clientPreview(['client.name', 'client.balance']),
      );
      repo.queue(_Trigger()..release(), augmented);
      repo.queue(_Trigger()..release(), augmented);
      final vm = ReportsViewModel(repo: repo, statics: statics);
      await vm.runReport();
      vm.setIncludeDateColumn(true);
      await vm.runReport();
      await vm.runReport();

      expect(repo.previewReportKeys[2], [
        'client.name',
        'client.balance',
        'client.created_at',
      ]);
    });

    // `_reconcileWithColumns` deliberately never un-hides a column, so
    // without an explicit opt-in the column arrives fetched and invisible
    // and the switch appears to do nothing at all.
    test('the column becomes visible when it arrives', () async {
      final repo = _FakeRepo();
      repo.queue(_Trigger()..release(), clientPreview(['client.name']));
      repo.queue(
        _Trigger()..release(),
        clientPreview(['client.name', 'client.created_at']),
      );
      final vm = ReportsViewModel(repo: repo, statics: statics);
      await vm.runReport();
      expect(vm.visibleColumnIds, {'client.name'});
      vm.setIncludeDateColumn(true);
      await vm.runReport();
      expect(vm.visibleColumnIds, {'client.name', 'client.created_at'});
    });

    test('replaces the unresolved server header', () async {
      final repo = _FakeRepo();
      repo.queue(_Trigger()..release(), clientPreview(['client.name']));
      repo.queue(
        _Trigger()..release(),
        clientPreview(['client.name', 'client.created_at']),
      );
      final vm = ReportsViewModel(repo: repo, statics: statics)
        ..optionalDateColumnLabel = 'Date Created';
      await vm.runReport();
      vm.setIncludeDateColumn(true);
      await vm.runReport();

      final col = vm.run.preview!.columns.last;
      expect(col.identifier, 'client.created_at');
      expect(col.displayLabel, 'Date Created');
      // `*_at` infers to dateTime, so the column is groupable and chartable
      // rather than an inert string.
      expect(col.type, ReportColumnType.dateTime);
    });

    test('a resolved server header wins over ours', () async {
      final repo = _FakeRepo();
      repo.queue(_Trigger()..release(), clientPreview(['client.name']));
      repo.queue(
        _Trigger()..release(),
        const ReportPreview(
          columns: [
            ReportColumn(
              identifier: 'client.created_at',
              // What the server would send if it ever adopted the column —
              // in the company's locale, which beats our English default.
              displayLabel: 'Fecha de Creación',
              type: ReportColumnType.dateTime,
            ),
          ],
          rows: [],
        ),
      );
      final vm = ReportsViewModel(repo: repo, statics: statics)
        ..optionalDateColumnLabel = 'Date Created';
      await vm.runReport();
      vm.setIncludeDateColumn(true);
      await vm.runReport();
      expect(vm.run.preview!.columns.single.displayLabel, 'Fecha de Creación');
    });

    // Stripping the key from report_keys isn't enough on its own:
    // `GenericReportRequest::prepareForValidation` unshifts `group_by` back
    // into the list, so the server would re-add the column to the file.
    test('export and email strip the column AND the group_by', () async {
      final repo = _FakeRepo();
      repo.queue(
        _Trigger()..release(),
        clientPreview(['client.name', 'client.created_at']),
      );
      final vm = ReportsViewModel(repo: repo, statics: statics);
      vm.setIncludeDateColumn(true);
      await vm.runReport();
      vm.setGroup('client.created_at', subgroup: ReportSubgroup.month);

      expect(vm.serverReportKeys(), ['client.name']);
      expect(vm.serverGroupBy, isNull);

      // An ordinary grouping is untouched.
      vm.setGroup('client.name');
      expect(vm.serverGroupBy, 'client.name');
    });

    // The flag changes the fetch without touching the payload, so it has to
    // join the dirty check by hand or Run keeps reading "Run report".
    test('flipping the switch marks the params dirty', () async {
      final repo = _FakeRepo();
      repo.queue(_Trigger()..release(), clientPreview(['client.name']));
      final vm = ReportsViewModel(repo: repo, statics: statics);
      await vm.runReport();
      expect(vm.isParamDirty, isFalse);
      vm.setIncludeDateColumn(true);
      expect(vm.isParamDirty, isTrue);
    });

    // Otherwise the panel offers a grouping the next run will drop.
    test('turning it off clears a grouping that depends on it', () async {
      final repo = _FakeRepo();
      repo.queue(
        _Trigger()..release(),
        clientPreview(['client.name', 'client.created_at']),
      );
      final vm = ReportsViewModel(repo: repo, statics: statics);
      vm.setIncludeDateColumn(true);
      await vm.runReport();
      vm.setGroup('client.created_at', subgroup: ReportSubgroup.month);

      vm.setIncludeDateColumn(false);
      expect(vm.group, isNull);
      expect(vm.subgroup, isNull);
    });

    test('a grouping on another column survives turning it off', () async {
      final repo = _FakeRepo();
      repo.queue(
        _Trigger()..release(),
        clientPreview(['client.name', 'client.created_at']),
      );
      final vm = ReportsViewModel(repo: repo, statics: statics);
      vm.setIncludeDateColumn(true);
      await vm.runReport();
      vm.setGroup('client.name');

      vm.setIncludeDateColumn(false);
      expect(vm.group, 'client.name');
    });

    // `keepWaiting` used to hand the raw preview straight to `_run`, skipping
    // every post-run step: no relabel, no column-set record, no visible-set
    // opt-in, and `isParamDirty` left stuck true. All of it invisible at the
    // call site, and `keepWaiting` had no test at all.
    test(
      'a "Keep waiting" continuation runs the same pipeline as a run',
      () async {
        final repo = _FakeRepo();
        repo.queue(_Trigger()..release(), clientPreview(['client.name']));
        // The run that carries the column times out, then its continuation
        // delivers it.
        repo.queueError(
          _Trigger()..release(),
          const ReportError(kind: ReportErrorKind.timeout, pollingHash: 'h1'),
        );
        repo.continuation = clientPreview(['client.name', 'client.created_at']);

        final vm = ReportsViewModel(repo: repo, statics: statics)
          ..optionalDateColumnLabel = 'Date Created';
        await vm.runReport();
        vm.setIncludeDateColumn(true);
        await vm.runReport(); // times out
        expect(vm.run.status, ReportRunStatus.error);

        await vm.keepWaiting();

        final col = vm.run.preview!.columns.last;
        // Relabelled: the server sends the literal "texts." for this key.
        expect(col.displayLabel, 'Date Created');
        // Visible, so the switch doesn't appear to have done nothing.
        expect(vm.visibleColumnIds, contains('client.created_at'));
        // Recorded, so the next augmented run has a current column set.
        expect(vm.serverGroupBy, isNull);
        // Settled: Run must not keep reading "Run to refresh".
        expect(vm.isParamDirty, isFalse);
      },
    );

    // Once the preview carries the column it is an ordinary dropdown item, so
    // the ordinary branch has to keep the opt-in on — otherwise the next Run
    // sends no report_keys, the server omits the column, and the grouping is
    // dropped with no message one interaction later.
    test('re-grouping from the plain dropdown keeps the opt-in', () async {
      final repo = _FakeRepo();
      final withColumn = clientPreview(['client.name', 'client.created_at']);
      repo.queue(_Trigger()..release(), withColumn);
      repo.queue(_Trigger()..release(), withColumn);
      final vm = ReportsViewModel(repo: repo, statics: statics);
      vm.setIncludeDateColumn(true);
      await vm.runReport();

      // Switch off — which clears the dependent grouping…
      vm.setIncludeDateColumn(false);
      expect(vm.group, isNull);
      // …then re-pick the column, which is now an ordinary item. This is what
      // `_GroupByField`'s ordinary branch does.
      vm.setIncludeDateColumn(true);
      vm.setGroup('client.created_at', subgroup: ReportSubgroup.month);

      await vm.runReport();
      expect(repo.previewReportKeys[1], contains('client.created_at'));
      expect(vm.group, 'client.created_at');
    });

    // A drill is into a bucket at the old granularity, so it cannot survive
    // the change: `_groupKey` re-derives against the new one and matches
    // nothing, leaving "No results" under a breadcrumb that has re-formatted
    // the stale key and now names a period that does have rows.
    test('changing the subgroup clears the drill', () async {
      final repo = _FakeRepo();
      repo.queue(
        _Trigger()..release(),
        clientPreview(['client.name', 'client.created_at']),
      );
      final vm = ReportsViewModel(repo: repo, statics: statics);
      vm.setIncludeDateColumn(true);
      await vm.runReport();
      vm.setGroup('client.created_at', subgroup: ReportSubgroup.day);
      vm.setSelectedGroup('2026-04-15');
      expect(vm.selectedGroup, '2026-04-15');

      vm.setSubgroup(ReportSubgroup.month);
      expect(vm.selectedGroup, isNull);
    });

    test('switching reports resets the opt-in', () async {
      final repo = _FakeRepo();
      repo.queue(_Trigger()..release(), clientPreview(['client.name']));
      final vm = ReportsViewModel(repo: repo, statics: statics);
      await vm.runReport();
      vm.setIncludeDateColumn(true);
      vm.setReport('invoice');
      expect(vm.includeDateColumn, isFalse);
      // The invoice report's date column is already in the default set, so
      // it has nothing to offer and the flag can't produce a request there.
      expect(vm.definition.optionalDateColumnId, isNull);
    });

    // A cold start has no preview, so the augmented request has nothing to
    // build from unless the last known column set was persisted — and
    // without it `_reconcileWithColumns` drops the restored grouping on the
    // very first run.
    test('restores the opt-in, the column set and the chart series', () async {
      final restored = clientPreview(['client.name', 'client.created_at']);

      final repo1 = _FakeRepo();
      repo1.queue(_Trigger()..release(), restored);
      final vm1 = ReportsViewModel(
        repo: repo1,
        statics: statics,
        navStateDao: db.navStateDao,
        companyId: 'co1',
        persistDebounce: Duration.zero,
      );
      await vm1.hydration;
      vm1.setIncludeDateColumn(true);
      await vm1.runReport();
      vm1.setGroup('client.created_at', subgroup: ReportSubgroup.month);
      vm1.setChartColumn('group.count');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final repo2 = _FakeRepo();
      repo2.queue(_Trigger()..release(), restored);
      final vm2 = ReportsViewModel(
        repo: repo2,
        statics: statics,
        navStateDao: db.navStateDao,
        companyId: 'co1',
      );
      await vm2.hydration;
      expect(vm2.includeDateColumn, isTrue);
      expect(vm2.group, 'client.created_at');
      expect(vm2.subgroup, ReportSubgroup.month);
      // Without persisting this the chart re-auto-picks the first numeric
      // column, silently losing a deliberate Count selection on restart.
      expect(vm2.chartColumn, 'group.count');

      // The first run after restore is already augmented — a plain cold run
      // would return no `created_at` and the grouping would be dropped.
      await vm2.runReport();
      expect(repo2.previewReportKeys.single, [
        'client.name',
        'client.created_at',
      ]);
      expect(vm2.group, 'client.created_at');
    });
  });
}

class _NullStaticsService implements StaticsService {
  @override
  Future<Map<String, dynamic>> fetch({
    bool includeStatic = true,
    bool? includeData,
  }) async => const <String, dynamic>{};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
