import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/templates.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

import '../../../../../_localization_helper.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  late AppDatabase db;
  late WysiwygDesignViewModel vm;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vm = WysiwygDesignViewModel(
      repo: DesignRepository(db: db, api: _FakeDesignsApi()),
      companyId: 'co1',
    );
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  Future<void> pumpToolbar(
    WidgetTester tester, {
    double width = 1440,
    bool companyHasLogo = true,
    List<String>? usedFor,
    VoidCallback? onUseDesign,
  }) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              DesignerToolbar(
                vm: vm,
                chrome: DesignerChrome(),
                companyHasLogo: companyHasLogo,
                usedFor: usedFor,
                onUseDesign: onUseDesign,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  List<String> types() => [for (final b in vm.blocks) b.type];

  group('suggestions', () {
    testWidgets('a complete layout shows none', (tester) async {
      vm.replaceLayout(buildStarterTemplates().first.blocks);
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.lightbulb_outline), findsNothing);
    });

    testWidgets('an empty page shows none either', (tester) async {
      await pumpToolbar(tester);
      expect(find.byIcon(Icons.lightbulb_outline), findsNothing);
    });

    testWidgets('a count that opens the list; "Add it" adds the block', (
      tester,
    ) async {
      vm.addBlock(blockSpecFor('text')!);
      await pumpToolbar(tester);
      expect(
        find.widgetWithText(TextButton, '2'),
        findsOneWidget,
        reason: 'no line items, no totals',
      );

      await tester.tap(find.byIcon(Icons.lightbulb_outline));
      await tester.pumpAndSettle();
      expect(find.textContaining('No line-items table'), findsOneWidget);
      await tester.tap(find.textContaining('No totals block'));
      await tester.pumpAndSettle();

      expect(types(), contains('total'));
      expect(find.widgetWithText(TextButton, '1'), findsOneWidget);
      // One step back takes the block away again.
      vm.undo();
      expect(types(), isNot(contains('total')));
    });

    testWidgets('a logo block with no company logo is said, not "fixed"', (
      tester,
    ) async {
      vm.replaceLayout(buildStarterTemplates().first.blocks);
      final before = types();
      await pumpToolbar(tester, companyHasLogo: false);
      await tester.tap(find.byIcon(Icons.lightbulb_outline));
      await tester.pumpAndSettle();
      expect(find.textContaining('company has no logo'), findsOneWidget);
      expect(find.text('Add it'), findsNothing);
      await tester.tapAt(const Offset(5, 500));
      await tester.pumpAndSettle();
      expect(types(), before);
    });
  });

  group('where the design is used', () {
    testWidgets('an unsaved design says nothing — it cannot be used yet', (
      tester,
    ) async {
      await pumpToolbar(tester);
      expect(find.text('Not in use'), findsNothing);
      await tester.tap(find.byTooltip('More Actions'));
      await tester.pumpAndSettle();
      expect(find.text('Use this design'), findsNothing);
    });

    testWidgets('a saved design nothing uses says so, and leads on', (
      tester,
    ) async {
      var opened = 0;
      await pumpToolbar(tester, usedFor: const [], onUseDesign: () => opened++);
      await tester.tap(find.text('Not in use'));
      expect(opened, 1);
      // And from the menu, which is all a narrower window has.
      await tester.tap(find.byTooltip('More Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this design'));
      await tester.pumpAndSettle();
      expect(opened, 2);
    });

    testWidgets('a design in use names one type and counts the rest', (
      tester,
    ) async {
      await pumpToolbar(
        tester,
        usedFor: const ['invoice', 'quote', 'credit'],
        onUseDesign: () {},
      );
      expect(find.text('Used for Invoices +2'), findsOneWidget);
    });

    testWidgets('under 1180 wide it lives in the menu only', (tester) async {
      await pumpToolbar(
        tester,
        width: 1100,
        usedFor: const [],
        onUseDesign: () {},
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Not in use'), findsNothing);
      await tester.tap(find.byTooltip('More Actions'));
      await tester.pumpAndSettle();
      expect(find.text('Use this design'), findsOneWidget);
    });
  });

  group('replace layout', () {
    Future<void> pickFromGallery(WidgetTester tester, String name) async {
      await tester.tap(find.byTooltip('More Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace layout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    List<String> starter(String id) => [
      for (final b
          in buildStarterTemplates().firstWhere((s) => s.id == id).blocks)
        b.type,
    ];

    testWidgets('an empty page takes the layout with no questions', (
      tester,
    ) async {
      await pumpToolbar(tester);
      await pickFromGallery(tester, 'Minimal');
      expect(types(), starter('minimal'));
    });

    testWidgets('a page with blocks asks first, and one undo brings it back', (
      tester,
    ) async {
      vm.addBlock(blockSpecFor('text')!);
      vm.addBlock(blockSpecFor('divider')!);
      await pumpToolbar(tester);

      await pickFromGallery(tester, 'Minimal');
      expect(types(), ['text', 'divider'], reason: 'not yet — it asks');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(types(), ['text', 'divider']);

      await pickFromGallery(tester, 'Minimal');
      await tester.tap(find.widgetWithText(FilledButton, 'Replace'));
      await tester.pumpAndSettle();
      expect(types(), starter('minimal'));

      vm.undo();
      expect(types(), ['text', 'divider']);
    });

    testWidgets('the page settings and the name survive', (tester) async {
      vm.setName('Letterhead');
      vm.setDocumentSettings(vm.documentSettings.copyWith(pageSize: 'letter'));
      await pumpToolbar(tester);
      await pickFromGallery(tester, 'Bold');
      expect(vm.draft.name, 'Letterhead');
      expect(vm.documentSettings.pageSize, 'letter');
    });
  });
}
