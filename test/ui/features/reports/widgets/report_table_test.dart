import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/data/models/value/company_format_settings.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/repositories/reports_repository.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/services/statics_service.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_table_model.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/widgets/report_table.dart';
import 'package:admin/ui/features/reports/widgets/report_table_layout.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../_localization_helper.dart';

class _NullStaticsService implements StaticsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Repo implements ReportsRepository {
  _Repo(this.preview);
  final ReportPreview preview;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #runPreview) {
      return Future<ReportPreview>.value(preview);
    }
    return super.noSuchMethod(invocation);
  }
}

ReportColumn _col(String id, String label) => ReportColumn(
  identifier: id,
  displayLabel: label,
  type: inferColumnType(id),
);

final _columns = [
  _col('client.name', 'Client'),
  _col('invoice.number', 'Number'),
  _col('invoice.status', 'Status'),
  _col('invoice.amount', 'Amount'),
  _col('invoice.balance', 'Balance'),
  _col('invoice.po_number', 'PO'),
  _col('invoice.public_notes', 'Notes'),
  _col('invoice.private_notes', 'Private'),
];

ReportPreview _preview(int rows) => ReportPreview(
  columns: _columns,
  rows: [
    for (var i = 0; i < rows; i++)
      ReportRow(
        currencyId: '1',
        cells: [
          ReportStringCell(
            value: 'Client ${i % 7}',
            displayValue: 'Client ${i % 7}',
          ),
          ReportStringCell(value: 'INV-$i', displayValue: 'INV-$i'),
          ReportStringCell(
            value: i.isEven ? 'Paid' : 'Sent',
            displayValue: i.isEven ? 'Paid' : 'Sent',
          ),
          ReportNumberCell(value: Decimal.fromInt(100 + i), isMoney: true),
          ReportNumberCell(value: Decimal.fromInt(i % 3), isMoney: true),
          const ReportStringCell(value: 'po', displayValue: 'po'),
          const ReportStringCell(value: 'note', displayValue: 'note'),
          const ReportStringCell(value: 'private', displayValue: 'private'),
        ],
      ),
  ],
);

Formatter _formatter() => Formatter(
  settings: CompanyFormatSettings.fallback,
  currencies: {
    '1': Currency.fromMap(const {
      'id': '1',
      'name': 'USD',
      'code': 'USD',
      'symbol': r'$',
      'precision': 2,
      'thousand_separator': ',',
      'decimal_separator': '.',
      'swap_currency_symbol': false,
      'exchange_rate': 1,
    }),
  },
  countries: const {},
  dateFormats: const {},
);

const double _kSummaryHeight = 300;

Future<void> _loadFonts() async {
  for (final (family, file) in [
    (kSansFontFamily, 'assets/fonts/InterTight.ttf'),
    (kMonoFontFamily, 'assets/fonts/JetBrainsMono.ttf'),
  ]) {
    final loader = FontLoader(family)
      ..addFont(Future.value(File(file).readAsBytesSync().buffer.asByteData()));
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<ReportsViewModel> vmWith(
    WidgetTester tester,
    ReportPreview preview,
  ) async {
    final vm = ReportsViewModel(
      repo: _Repo(preview),
      statics: StaticsRepository(db: db, service: _NullStaticsService()),
      initialReport: 'document',
    );
    await tester.runAsync(vm.runReport);
    addTearDown(vm.dispose);
    return vm;
  }

  Future<void> pump(
    WidgetTester tester,
    ReportsViewModel vm, {
    double width = 700,
    double height = 600,
    TextDirection direction = TextDirection.ltr,
    ReportTableSummary? summary,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Directionality(
          textDirection: direction,
          child: Scaffold(
            body: ListenableBuilder(
              listenable: vm,
              builder: (context, _) {
                const gutter = 16.0;
                final view = vm.buildView();
                final layout = ReportTableLayout.of(
                  columns: view.visibleColumns,
                  width: width - gutter * 2 - 2,
                  userWidths: vm.columnWidths,
                );
                final lines = buildReportTableLines(
                  view,
                  expanded: vm.expandedGroups,
                  splitByPeriod: vm.isSplitByPeriod,
                );
                return ReportTableHorizontalScroll(
                  layout: layout,
                  child: CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(
                        child: SizedBox(
                          key: Key('summary'),
                          height: _kSummaryHeight,
                        ),
                      ),
                      ...buildReportTableSlivers(
                        context,
                        vm: vm,
                        view: view,
                        lines: lines,
                        formatter: _formatter(),
                        currencyId: '1',
                        currencyLabel: null,
                        onFilter: (_) {},
                        gutter: gutter,
                        summary: summary,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder vertical() => find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  Finder horizontal() => find.byWidgetPredicate(
    (w) =>
        w is Scrollable &&
        (w.axisDirection == AxisDirection.right ||
            w.axisDirection == AxisDirection.left),
  );

  testWidgets('only the rows on screen are built', (tester) async {
    final vm = await vmWith(tester, _preview(50000));
    await pump(tester, vm);
    // 600 px of viewport under a 300 px summary: a handful of 48 px rows
    // (plus the cache extent), not fifty thousand.
    expect(find.textContaining('INV-').evaluate().length, lessThan(40));
    expect(find.text('INV-0'), findsOneWidget);
    expect(find.text('INV-49999'), findsNothing);
  });

  testWidgets('the header and totals pin; the summary scrolls away', (
    tester,
  ) async {
    final vm = await vmWith(tester, _preview(200));
    await pump(tester, vm);
    final headerTop = tester.getTopLeft(find.text('CLIENT')).dy;
    expect(headerTop, greaterThan(_kSummaryHeight - 1));

    await tester.drag(vertical(), const Offset(0, -900));
    await tester.pump();

    // The summary is gone, the header sits at the top of the viewport…
    expect(tester.getTopLeft(find.text('CLIENT')).dy, lessThan(40));
    // …with the totals still directly beneath it,
    expect(find.text('Total'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Total')).dy,
      greaterThan(tester.getTopLeft(find.text('CLIENT')).dy),
    );
    // …and the rows have moved on underneath.
    expect(find.text('INV-0'), findsNothing);
  });

  testWidgets('the totals are of the whole result, in the row currency', (
    tester,
  ) async {
    final vm = await vmWith(tester, _preview(3));
    await pump(tester, vm, width: 1400);
    // 100 + 101 + 102
    expect(find.text(r'$303.00'), findsOneWidget);
  });

  testWidgets('scrolling sideways moves the columns, not the first one', (
    tester,
  ) async {
    final vm = await vmWith(tester, _preview(20));
    await pump(tester, vm, width: 700);

    final clientBefore = tester.getTopLeft(find.text('Client 0').first).dx;
    final numberBefore = tester.getTopLeft(find.text('INV-0')).dx;
    final headerBefore = tester.getTopLeft(find.text('NUMBER')).dx;

    await tester.drag(horizontal(), const Offset(-150, 0));
    await tester.pump();

    expect(tester.getTopLeft(find.text('Client 0').first).dx, clientBefore);
    // (Less than the full 150: the gesture spends its first few pixels
    // deciding it is a drag.)
    final moved = numberBefore - tester.getTopLeft(find.text('INV-0')).dx;
    expect(moved, greaterThan(100));
    // The header moves with its column, by exactly as much.
    expect(headerBefore - tester.getTopLeft(find.text('NUMBER')).dx, moved);
  });

  testWidgets('it cannot scroll past the last column', (tester) async {
    final vm = await vmWith(tester, _preview(5));
    await pump(tester, vm, width: 700);
    await tester.drag(horizontal(), const Offset(-5000, 0));
    await tester.pump();
    // The last header ends inside the table, not somewhere off to the left.
    final right = tester.getTopRight(find.text('PRIVATE')).dx;
    expect(right, lessThanOrEqualTo(700 - 16));
    // …and it starts inside its own column, which now ends at that edge.
    final widest = defaultReportColumnWidth(_columns.last, leading: false);
    expect(right, greaterThan(700 - 16 - widest));
  });

  testWidgets('when every column fits, the table fills its width', (
    tester,
  ) async {
    final vm = await vmWith(tester, _preview(5));
    vm.setVisibleColumns({'client.name', 'invoice.number', 'invoice.amount'});
    await pump(tester, vm, width: 1200);

    // Nothing to scroll: a sideways drag moves nothing.
    final before = tester.getTopLeft(find.text('INV-0')).dx;
    await tester.drag(find.text('INV-1'), const Offset(-200, 0));
    await tester.pump();
    expect(tester.getTopLeft(find.text('INV-0')).dx, before);

    // And the amount is right-aligned against the table's far edge rather
    // than stranded in a 132 px column at the left.
    final amountRight = tester.getTopRight(find.text(r'$100.00')).dx;
    expect(amountRight, greaterThan(1100));
  });

  testWidgets('figures are right-aligned; text is not', (tester) async {
    final vm = await vmWith(tester, _preview(12));
    await pump(tester, vm, width: 1600);
    // Every amount ends on the same x, under the end of its header…
    final a = tester.getTopRight(find.text(r'$100.00')).dx;
    final b = tester.getTopRight(find.text(r'$103.00')).dx;
    expect(a, b);
    // …and text starts where its header starts.
    expect(
      tester.getTopLeft(find.text('INV-0')).dx,
      tester.getTopLeft(find.text('NUMBER')).dx,
    );
    expect(
      tester.getTopLeft(find.text('INV-0')).dx,
      tester.getTopLeft(find.text('INV-3')).dx,
    );
  });

  testWidgets('a group opens in place and closes again', (tester) async {
    final vm = await vmWith(tester, _preview(14));
    vm.setGroup('client.name');
    // By name, so the first group is a known one (a category grouping
    // opens ranked by its figure).
    vm.setSort('client.name');
    await pump(tester, vm, width: 1400);

    expect(find.text('INV-0'), findsNothing);
    expect(find.text('Client 0'), findsOneWidget);

    await tester.tap(find.text('Client 0'));
    await tester.pump();
    expect(find.text('INV-0'), findsOneWidget);
    expect(find.text('INV-7'), findsOneWidget);
    expect(find.text('INV-1'), findsNothing);

    await tester.tap(find.text('Client 0').first);
    await tester.pump();
    expect(find.text('INV-0'), findsNothing);
  });

  testWidgets(
    'a header click sorts; a shift-click adds a second key',
    (tester) async {
      final vm = await vmWith(tester, _preview(6));
      await pump(tester, vm, width: 1600);

      await tester.tap(find.text('STATUS'));
      await tester.pump();
      expect(vm.sortField, 'invoice.status');
      expect(vm.sortAscending, isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('AMOUNT'));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(vm.sortField, 'invoice.status');
      expect(vm.thenBy.single.columnId, 'invoice.amount');
      // With a pointer: `flutter test` runs as Android, where a header is one
      // target and opens the menu instead (the next test).
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'under a finger the whole header opens the column menu',
    (tester) async {
      final vm = await vmWith(tester, _preview(6));
      await pump(tester, vm, width: 1600);

      await tester.tap(find.text('STATUS'));
      await tester.pumpAndSettle();
      // Not a sort: one target per column on touch, and it is the menu, which
      // leads with both sorts.
      expect(vm.sortField, isNull);
      expect(find.text('Sort: Descending'), findsOneWidget);

      await tester.tap(find.text('Sort: Descending'));
      await tester.pumpAndSettle();
      expect(vm.sortField, 'invoice.status');
      expect(vm.sortAscending, isFalse);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('a narrow grouped table leads each group with one figure', (
    tester,
  ) async {
    final vm = await vmWith(tester, _preview(14));
    vm.setGroup('client.name');
    vm.setSort('client.name');
    await pump(
      tester,
      vm,
      width: 380,
      summary: ReportTableSummary(
        measureId: 'invoice.amount',
        column: _columns[3],
      ),
    );
    expect(tester.takeException(), isNull);
    // Client 0 holds INV-0 and INV-7: 100 + 107. Its total is on the line
    // itself, inside the pane — not in a column three swipes to the right.
    final figure = find.text(r'$207.00');
    expect(figure, findsOneWidget);
    expect(tester.getTopRight(figure).dx, lessThanOrEqualTo(380 - 16));
    expect(
      tester.getCenter(figure).dy,
      closeTo(tester.getCenter(find.text('Client 0')).dy, 2),
    );
    // And the totals line reads the same way.
    final total = find.text(r'$1,491.00');
    expect(total, findsOneWidget);
    expect(tester.getTopRight(total).dx, lessThanOrEqualTo(380 - 16));
  });

  testWidgets('a status is a pill, an amount is not', (tester) async {
    final vm = await vmWith(tester, _preview(2));
    await pump(tester, vm, width: 1600);
    expect(
      find.ancestor(of: find.text('Paid'), matching: find.byType(DecoratedBox)),
      findsWidgets,
    );
  });

  testWidgets('right to left, the held column is on the right', (tester) async {
    final vm = await vmWith(tester, _preview(5));
    await pump(tester, vm, width: 700, direction: TextDirection.rtl);
    final client = tester.getTopRight(find.text('Client 0').first).dx;
    final number = tester.getTopRight(find.text('INV-0')).dx;
    expect(client, greaterThan(number));
    expect(tester.takeException(), isNull);
  });

  testWidgets('no overflow at a phone width or at large text', (tester) async {
    final vm = await vmWith(tester, _preview(30));
    vm.setGroup('client.name');
    await pump(tester, vm, width: 390, height: 800);
    expect(tester.takeException(), isNull);
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(tester, vm, width: 390, height: 800);
    expect(tester.takeException(), isNull);
  });
}
