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
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';

class _NullStaticsService implements StaticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ReportColumn _col(String id) =>
    ReportColumn(identifier: id, displayLabel: id, type: inferColumnType(id));

/// Answers like the server: the columns asked for, or its default two when
/// asked for none.
class _EchoRepo implements ReportsRepository {
  static const defaults = ['client.name', 'invoice.number'];

  final List<List<String>> requests = [];

  /// When set, a request carrying the id key throws this instead.
  ReportError? idRunError;

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
    requests.add(reportKeys);
    final error = idRunError;
    if (error != null && reportKeys.contains('invoice.id')) throw error;
    final keys = reportKeys.isEmpty ? defaults : reportKeys;
    return ReportPreview(
      columns: [for (final k in keys) _col(k)],
      rows: [
        ReportRow(
          cells: [
            for (final k in keys)
              ReportStringCell(
                value: k == 'invoice.id' ? 'VolejRejNm' : 'x',
                displayValue: k == 'invoice.id' ? 'VolejRejNm' : 'x',
              ),
          ],
        ),
      ],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late StaticsRepository statics;
  late _EchoRepo repo;
  var now = DateTime(2026, 10, 8, 12);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    statics = StaticsRepository(db: db, service: _NullStaticsService());
    repo = _EchoRepo();
    now = DateTime(2026, 10, 8, 12);
  });

  tearDown(() async {
    await db.close();
  });

  ReportsViewModel vmFor(String report, {bool fetchRowIds = true}) =>
      ReportsViewModel(
        repo: repo,
        statics: statics,
        initialReport: report,
        fetchRowIds: fetchRowIds,
        now: () => now,
      );

  /// Let the silent follow-up run finish.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('the first run is plain, and a second fetches the ids', () async {
    final vm = vmFor('invoice');
    await vm.runReport();
    await settle();

    // A non-empty `report_keys` pins the column set, so the id can only be
    // added to a set the server has already described.
    expect(repo.requests, [
      <String>[],
      ['client.name', 'invoice.number', 'invoice.id'],
    ]);
    final row = vm.run.preview!.rows.single;
    expect(row.recordId, 'VolejRejNm');
    expect(row.recordWire, 'invoice');
    vm.dispose();
  });

  test('the id never becomes a column', () async {
    final vm = vmFor('invoice');
    await vm.runReport();
    await settle();

    final ids = vm.run.preview!.columns.map((c) => c.identifier);
    expect(ids, ['client.name', 'invoice.number']);
    expect(vm.visibleColumnIds, {'client.name', 'invoice.number'});
    // …so it cannot reach an export, an email or a schedule either.
    expect(vm.serverReportKeys(), isNot(contains('invoice.id')));
    vm.dispose();
  });

  test('later runs carry the id in one request, exactly once', () async {
    final vm = vmFor('invoice');
    await vm.runReport();
    await settle();
    repo.requests.clear();

    await vm.runReport();
    await settle();
    await vm.runReport();
    await settle();

    // Strip-then-append: the stripped preview does not hold the id, but the
    // rule has to survive the day it does.
    expect(repo.requests, [
      ['client.name', 'invoice.number', 'invoice.id'],
      ['client.name', 'invoice.number', 'invoice.id'],
    ]);
    vm.dispose();
  });

  test('a stale column set is re-learned with a plain run', () async {
    final vm = vmFor('invoice');
    await vm.runReport();
    await settle();
    repo.requests.clear();

    // A pinned set never shows a column the server added since.
    now = now.add(const Duration(days: 8));
    await vm.runReport();
    await settle();

    expect(repo.requests.first, isEmpty);
    expect(repo.requests.last, contains('invoice.id'));
    vm.dispose();
  });

  test('a failed id fetch leaves the report as it was', () async {
    repo.idRunError = const ReportError(kind: ReportErrorKind.timeout);
    final vm = vmFor('invoice');
    await vm.runReport();
    await settle();

    expect(vm.run.status, ReportRunStatus.ready);
    expect(vm.run.error, isNull);
    expect(vm.run.preview!.rows.single.recordId, isNull);
    vm.dispose();
  });

  test('the id fetch does not dim the table', () async {
    final vm = vmFor('invoice');
    final statuses = <ReportRunStatus>[];
    vm.addListener(() => statuses.add(vm.run.status));
    await vm.runReport();
    await settle();

    // loading → ready, and then ready again when the ids land.
    expect(statuses.where((s) => s == ReportRunStatus.loading), hasLength(1));
    expect(statuses.last, ReportRunStatus.ready);
    vm.dispose();
  });

  test('a report with no id key runs once', () async {
    final vm = vmFor('document');
    await vm.runReport();
    await settle();
    expect(repo.requests, [<String>[]]);
    vm.dispose();
  });

  test('off, nothing extra is asked for', () async {
    final vm = vmFor('invoice', fetchRowIds: false);
    await vm.runReport();
    await settle();
    expect(repo.requests, [<String>[]]);
    expect(vm.run.preview!.rows.single.recordId, isNull);
    vm.dispose();
  });

  test('switching report strands an id fetch in flight', () async {
    final vm = vmFor('invoice');
    await vm.runReport();
    // The follow-up has been started but has not landed.
    vm.setReport('client');
    await settle();

    expect(vm.run.status, ReportRunStatus.idle);
    expect(vm.run.preview, isNull);
    vm.dispose();
  });
}
