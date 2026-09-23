import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/widgets/reports_body.dart';

import '../../../../_localization_helper.dart';

class _FakeReportsRepo implements ReportsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
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

class _FakeAuth implements AuthRepository {
  final ValueNotifier<AuthSession?> _session = ValueNotifier(null);
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.auth);
  @override
  final AuthRepository auth;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Pumps the settings panel for [report] with [preview] already run, and
/// returns the VM so a test can drive it.
Future<ReportsViewModel> _panelVm(
  WidgetTester tester,
  String report, {
  ReportPreview preview = const ReportPreview(columns: [], rows: []),
}) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  final statics = StaticsRepository(db: db, service: _NullStaticsService());
  final vm = ReportsViewModel(repo: _SeededRepo(preview), statics: statics);
  vm.setReport(report);
  if (preview.columns.isNotEmpty) await vm.runReport();

  await tester.pumpWidget(
    MaterialApp(
      theme: buildInTheme(InTheme.light),
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      home: MultiProvider(
        providers: [
          Provider<Services>.value(value: _FakeServices(_FakeAuth())),
          ChangeNotifierProvider<ReportsViewModel>.value(value: vm),
        ],
        child: const Scaffold(body: ReportsBody(formatter: null)),
      ),
    ),
  );
  await tester.pump();
  return vm;
}

/// `reportKeys` of the most recent preview request.
List<String> _lastPreviewKeys = const [];

/// Returns the supplied preview on Run; everything else is unreachable from
/// the settings panel.
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
  }) async {
    _lastPreviewKeys = reportKeys;
    return _preview;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Reports settings panel builds without crashing when a group is set '
    'but no preview has run (regression: GroupBy dropdown assertion)',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final statics = StaticsRepository(db: db, service: _NullStaticsService());

      // No navStateDao → no persistence Timer. setReport + setGroup put the
      // VM in the exact state hydration produces on a cold restart: a group
      // selected with `run.preview == null`. Before the fix this tripped
      // DropdownButtonFormField's "exactly one matching item" assertion
      // when the (now always-rendered, disabled) GroupBy field built with a
      // group id that isn't among its items (no preview → no columns).
      final vm = ReportsViewModel(repo: _FakeReportsRepo(), statics: statics);
      vm.setReport('contact'); // minimal filter fields, no entity streams
      vm.setGroup('contact.first_name');
      expect(vm.group, 'contact.first_name');
      expect(vm.run.preview, isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: MultiProvider(
            providers: [
              Provider<Services>.value(value: _FakeServices(_FakeAuth())),
              ChangeNotifierProvider<ReportsViewModel>.value(value: vm),
            ],
            child: const Scaffold(body: ReportsBody(formatter: null)),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      // GroupBy fell back to the "No grouping" item (disabled, no preview).
      expect(find.text('No grouping'), findsOneWidget);
    },
  );

  // invoiceninja/flutter#138's first ask turned out to already work: a date
  // range on the Clients report *is* "new clients in that period", because
  // `ClientExport::$date_key` is `created_at`. Nothing on screen said so.
  testWidgets('the date range names the column it filters on', (tester) async {
    await _panelVm(tester, 'client');
    // The hint frames the column ("Filtered by …") so it can't be misread as
    // a heading for the control below it; the opt-in switch further down the
    // panel carries the bare name. Both resolve from the same key, so they
    // cannot disagree about which column the range means.
    expect(find.text('Filtered by Date Created'), findsOneWidget);
    expect(find.text('Date Created'), findsOneWidget);
  });

  // `setSubgroup` shipped with the engine and had no caller anywhere in
  // lib/ or test/: date groupings were hardcoded to months.
  testWidgets('the subgroup picker appears only for a date grouping', (
    tester,
  ) async {
    final vm = await _panelVm(
      tester,
      'client',
      preview: const ReportPreview(
        columns: [
          ReportColumn(
            identifier: 'client.name',
            displayLabel: 'Name',
            type: ReportColumnType.string,
          ),
          ReportColumn(
            identifier: 'client.created_at',
            displayLabel: 'Date Created',
            type: ReportColumnType.dateTime,
          ),
        ],
        rows: [],
      ),
    );

    expect(find.byType(DropdownButtonFormField<ReportSubgroup>), findsNothing);

    vm.setGroup('client.name');
    await tester.pump();
    expect(find.byType(DropdownButtonFormField<ReportSubgroup>), findsNothing);

    vm.setGroup('client.created_at', subgroup: ReportSubgroup.month);
    await tester.pump();
    expect(
      find.byType(DropdownButtonFormField<ReportSubgroup>),
      findsOneWidget,
    );
  });

  // "Hours per user per month": a non-date grouping split by a date column.
  testWidgets('a non-date grouping offers a period split by date column', (
    tester,
  ) async {
    // Documents: simple filters, and `created_at` (the range's column) is
    // already in the default set, so nothing optional is offered.
    final vm = await _panelVm(
      tester,
      'document',
      preview: const ReportPreview(
        columns: [
          ReportColumn(
            identifier: 'document.name',
            displayLabel: 'Name',
            type: ReportColumnType.string,
          ),
          ReportColumn(
            identifier: 'document.updated_at',
            displayLabel: 'Updated At',
            type: ReportColumnType.dateTime,
          ),
          ReportColumn(
            identifier: 'document.created_at',
            displayLabel: 'Created At',
            type: ReportColumnType.dateTime,
          ),
        ],
        rows: [],
      ),
    );
    vm.setGroup('document.name');
    await tester.pump();

    expect(find.text('Subgroup'), findsOneWidget);
    // Resting on None, so no granularity yet.
    expect(find.text('None'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<ReportSubgroup>), findsNothing);

    // The column the date range filters on is offered first.
    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    final createdY = tester.getTopLeft(find.text('Created At').last).dy;
    final updatedY = tester.getTopLeft(find.text('Updated At').last).dy;
    expect(createdY, lessThan(updatedY));

    await tester.tap(find.text('Created At').last);
    await tester.pumpAndSettle();
    expect(vm.periodColumn, 'document.created_at');
    expect(vm.subgroup, ReportSubgroup.month);
    expect(
      find.byType(DropdownButtonFormField<ReportSubgroup>),
      findsOneWidget,
    );
  });

  testWidgets('no period split when there is no date column to split by', (
    tester,
  ) async {
    final vm = await _panelVm(
      tester,
      'document',
      preview: const ReportPreview(
        columns: [
          ReportColumn(
            identifier: 'document.name',
            displayLabel: 'Name',
            type: ReportColumnType.string,
          ),
        ],
        rows: [],
      ),
    );
    vm.setGroup('document.name');
    await tester.pump();
    expect(find.text('Subgroup'), findsNothing);
  });

  // Vendors have no date column by default, but can ask for created_at.
  testWidgets('the optional date column is offered as a period', (
    tester,
  ) async {
    final vm = await _panelVm(
      tester,
      'vendor',
      preview: const ReportPreview(
        columns: [
          ReportColumn(
            identifier: 'vendor.name',
            displayLabel: 'Vendor Name',
            type: ReportColumnType.string,
          ),
        ],
        rows: [],
      ),
    );
    vm.setGroup('vendor.name');
    await tester.pump();
    expect(find.text('Subgroup'), findsOneWidget);

    await tester.tap(find.text('None'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date Created').last);
    await tester.pumpAndSettle();
    // Picking it opts in and re-runs asking for the column. (This fake
    // answers every run with the same column-less preview, so the split
    // itself is then reconciled away — a real server returns the column.)
    expect(vm.includeDateColumn, isTrue);
    expect(_lastPreviewKeys, contains('vendor.created_at'));
  });
}
