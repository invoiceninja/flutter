import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/design_block_layout.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/mobile/mobile_reorder_view.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_panel.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/templates.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

import '../../../../../../_localization_helper.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

List<String> _shape(WysiwygDesignViewModel vm) => [
  for (final row in vm.rows)
    [
      for (final b in row)
        '${isGapBlock(b) ? 'gap' : b.type}:${b.gridPosition.w}',
    ].join(' '),
];

void main() {
  late AppDatabase db;
  late WysiwygDesignViewModel vm;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vm = WysiwygDesignViewModel(
      repo: DesignRepository(db: db, api: _FakeDesignsApi()),
      companyId: 'co1',
      seed: Design(
        id: '',
        name: '',
        isCustom: true,
        isActive: true,
        isTemplate: false,
        isFree: false,
        entities: const [],
        template: DesignTemplate(
          blocks: buildStarterTemplates()
              .firstWhere((s) => s.id == 'standard')
              .blocks,
        ),
        updatedAt: DateTime.utc(2000),
        createdAt: DateTime.utc(2000),
        archivedAt: null,
        isDeleted: false,
      ),
    );
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    // A real phone: `physicalSize`, not `setSurfaceSize`, so MediaQuery
    // reports it too.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: vm,
            builder: (_, _) => MobileReorderView(vm: vm),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('one card per row, in the order the page prints', (tester) async {
    await pump(tester);
    expect(tester.takeException(), isNull);
    // Six rows: logo + details, the two addresses, table, totals, notes,
    // footer — not eight blocks in the order they were added.
    expect(find.byIcon(Icons.drag_handle), findsNWidgets(6));
    final first = tester.getTopLeft(find.text('Company Logo'));
    final details = tester.getTopLeft(find.text('Invoice Details'));
    expect(details.dy, first.dy, reason: 'side by side in one card');
    expect(details.dx, greaterThan(first.dx));
  });

  testWidgets('moving a row leaves every block as wide as it was', (
    tester,
  ) async {
    // The old list's one gesture rewrote every block on the page to full
    // width.
    await pump(tester);
    final before = _shape(vm);
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView),
    );
    list.onReorderItem!(0, 2);
    await tester.pump();
    expect(_shape(vm), [before[1], before[2], before[0], ...before.skip(3)]);
    expect(_shape(vm)[2], contains('logo'));
    expect(_shape(vm)[2], contains('invoice-details'));
  });

  testWidgets('a block opens its properties; its menu has the moves', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();
    expect(find.byType(PropertyPanel), findsOneWidget);
    expect(vm.selectedBlock!.type, 'table');
    Navigator.of(tester.element(find.byType(PropertyPanel))).pop();
    await tester.pumpAndSettle();

    // A block alone in its row has a menu button of its own.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text('Move Up'), findsOneWidget);
    expect(find.text('Move into the row above'), findsOneWidget);
    expect(find.text('Duplicate'), findsOneWidget);
    await tester.tap(find.text('Move Up'));
    await tester.pumpAndSettle();
    expect(_shape(vm)[1], contains('table'));
  });

  testWidgets('an empty page offers to add a block', (tester) async {
    for (final block in List.of(vm.blocks)) {
      vm.deleteBlock(block.id);
    }
    await pump(tester);
    expect(find.text('Add block'), findsOneWidget);
    expect(find.byIcon(Icons.drag_handle), findsNothing);
  });
}
