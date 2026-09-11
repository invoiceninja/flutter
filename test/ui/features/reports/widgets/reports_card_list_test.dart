import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/report_payload.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/reports_api.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/widgets/reports_body.dart';

import '../../../../_localization_helper.dart';

/// Returns a fixed preview from runPreview; everything else is unimplemented.
class _PreviewRepo implements ReportsRepository {
  _PreviewRepo(this.preview);
  final ReportPreview preview;

  @override
  Future<ReportPreview> runPreview({
    required String reportIdentifier,
    required String endpoint,
    required ReportPayload payload,
    List<String> reportKeys = const [],
    int maxRetries = ReportsApi.defaultPreviewRetries,
    Duration pollInterval = ReportsApi.defaultPollInterval,
    ReportPollingCancellation? isCancelled,
  }) async => preview;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'narrow card list pairs each visible column label with its OWN cell '
    '(regression: positional row.cells[k] desync on reorder)',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900); // < 600 → narrow tier
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final statics = StaticsRepository(db: db, service: _NullStaticsService());

      const colA = ReportColumn(
        identifier: 'r.a',
        displayLabel: 'A',
        type: ReportColumnType.string,
      );
      const colB = ReportColumn(
        identifier: 'r.b',
        displayLabel: 'B',
        type: ReportColumnType.string,
      );
      const colC = ReportColumn(
        identifier: 'r.c',
        displayLabel: 'C',
        type: ReportColumnType.string,
      );
      // Cells stay in server order [a, b, c]; values are distinct so a
      // mis-pairing is detectable. No entity wire → rows aren't drillable, so
      // the fake Services' registry is never touched.
      final preview = ReportPreview(
        columns: const [colA, colB, colC],
        rows: const [
          ReportRow(
            cells: [
              ReportStringCell(value: 'aaa', displayValue: 'aaa'),
              ReportStringCell(value: 'bbb', displayValue: 'bbb'),
              ReportStringCell(value: 'ccc', displayValue: 'ccc'),
            ],
          ),
        ],
      );

      final vm = ReportsViewModel(
        repo: _PreviewRepo(preview),
        statics: statics,
      );
      vm.setReport('contact'); // minimal filter fields, no entity streams
      await vm.runReport();
      // Reorder columns so C renders first while cells keep their server order.
      vm.setVisibleColumns({'r.a', 'r.b', 'r.c'}, order: ['r.c', 'r.a', 'r.b']);

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

      // Title is the first VISIBLE column (C → 'ccc'), not the first server
      // cell ('aaa').
      expect(find.text('ccc'), findsOneWidget);
      // Subtitle pairs each label with its own cell.
      expect(find.text('A: aaa'), findsOneWidget);
      expect(find.text('B: bbb'), findsOneWidget);
      // The old positional pairing would have produced these instead.
      expect(find.text('A: bbb'), findsNothing);
      expect(find.text('B: ccc'), findsNothing);
    },
  );

  // invoiceninja/flutter#138. Two things converge here, neither previously
  // covered anywhere: the grouped bucket label is resolved by the *parent*
  // and handed to each row (so a bug wiring every row to `groups.first` would
  // still look right in a single-group fixture), and the settings panel's two
  // conditional controls — the opt-in switch and the Subgroup picker — only
  // render for a report with an `optionalDateColumnId` *and* an active date
  // grouping, which nothing else sets up. The panel is in the blocking
  // `integration-web` job's graph, so a layout error here fails CI on
  // headless Chrome rather than locally.
  //
  // Heights are deliberate. The panel's `ListView` is lazy and, at the narrow
  // tier, capped at 55% of the viewport — below ~1200 px the Subgroup field
  // is simply never built, so a 900 px fixture would assert nothing. These
  // two sizes render the whole panel on both tiers.
  ReportPreview groupedPreview() {
    const nameCol = ReportColumn(
      identifier: 'client.name',
      displayLabel: 'Name',
      type: ReportColumnType.string,
    );
    // The shape the server actually returns for the opted-in column: an
    // unresolved `"texts."` header, which `_augmentPreview` relabels.
    const created = ReportColumn(
      identifier: 'client.created_at',
      displayLabel: 'texts.',
      type: ReportColumnType.dateTime,
    );
    ReportRow row(String who, DateTime when) => ReportRow(
      cells: [
        ReportStringCell(value: who, displayValue: who),
        ReportDateTimeCell(value: when),
      ],
    );
    return ReportPreview(
      columns: const [nameCol, created],
      rows: [
        // Local noon on the 15th, so the bucket is the same calendar month in
        // every timezone — the engine buckets on the *local* day.
        row('Acme', DateTime(2026, 1, 15, 12)),
        row('Borealis', DateTime(2026, 1, 15, 12)),
        row('Cygnus', DateTime(2026, 3, 15, 12)),
      ],
    );
  }

  Future<ReportsViewModel> pumpGrouped(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final statics = StaticsRepository(db: db, service: _NullStaticsService());

    final vm = ReportsViewModel(
      repo: _PreviewRepo(groupedPreview()),
      statics: statics,
    )..optionalDateColumnLabel = 'Date Created';
    vm.setIncludeDateColumn(true);
    await vm.runReport();
    vm.setGroup('client.created_at', subgroup: ReportSubgroup.month);

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

  testWidgets('wide grouped table labels each bucket for itself', (
    tester,
  ) async {
    await pumpGrouped(tester, size: const Size(1400, 1000));
    expect(tester.takeException(), isNull);

    // Both conditional panel controls built.
    expect(find.text('Subgroup'), findsOneWidget);
    expect(find.text('Date Created'), findsWidgets);

    // `_GroupRow` renders "<label> (<count>)", which the chart's x-axis does
    // not — so these two finders can only match the rows. A `label` wired to
    // `groups.first` would render January twice and never match March.
    expect(find.text('January 2026 (2)'), findsOneWidget);
    expect(find.text('March 2026 (1)'), findsOneWidget);
    // Formatted, never the raw ISO key that `selectedGroup` matches on.
    expect(find.textContaining('2026-01-01'), findsNothing);
  });

  testWidgets('narrow grouped card list labels each bucket for itself', (
    tester,
  ) async {
    await pumpGrouped(tester, size: const Size(420, 1400));
    expect(tester.takeException(), isNull);

    expect(find.text('Subgroup'), findsOneWidget);

    // Scoped to the tiles: the chart's x-axis renders the same month strings,
    // so an unscoped finder would pass even with every row mislabelled.
    Finder tileText(String s) =>
        find.descendant(of: find.byType(ListTile), matching: find.text(s));
    expect(tileText('January 2026'), findsOneWidget);
    expect(tileText('March 2026'), findsOneWidget);
    expect(find.textContaining('2026-01-01'), findsNothing);
  });
}
