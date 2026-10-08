import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/invoice_api_model.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/wysiwyg_canvas.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/designer_pane.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/document_source.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/mobile/mobile_reorder_view.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/palette/component_palette.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_panel.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

import '../../../../../_localization_helper.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The app's sidebar, expanded.
const double _kSidebar = 232;

/// The designer is a route in the app shell, laid out **beside the sidebar**.
/// Every other designer test pumps it on its own, filling the window — which
/// is how a layout chosen from the window's width, and menus anchored in
/// window coordinates, both shipped looking right.
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

  /// The designer as the shell hosts it: a navigator of its own, starting
  /// [_kSidebar] in from the window's left edge.
  Future<void> pumpInShell(
    WidgetTester tester, {
    required double window,
    DesignerDocumentController? document,
  }) async {
    tester.view.physicalSize = Size(window, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final chrome = DesignerChrome();
    addTearDown(chrome.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        home: Row(
          children: [
            const SizedBox(width: _kSidebar),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => LayoutBuilder(
                    builder: (context, constraints) => DesignerPane(
                      width: constraints.maxWidth,
                      child: Scaffold(
                        appBar: AppBar(
                          automaticallyImplyLeading: false,
                          actions: [
                            Builder(
                              builder: (context) =>
                                  DesignerPane.tierOf(context) ==
                                      DesignerTier.outline
                                  ? const SizedBox.shrink()
                                  : DesignerToolbar(vm: vm, chrome: chrome),
                            ),
                          ],
                        ),
                        body: DesignerWorkspace(
                          vm: vm,
                          isPro: true,
                          chrome: chrome,
                          document: document,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
  }

  test('the tiers', () {
    expect(designerTierFor(1280), DesignerTier.full);
    expect(designerTierFor(1279), DesignerTier.docked);
    expect(designerTierFor(900), DesignerTier.docked);
    expect(designerTierFor(899), DesignerTier.canvas);
    expect(designerTierFor(560), DesignerTier.canvas);
    expect(designerTierFor(559), DesignerTier.outline);
  });

  group('the layout follows the pane, not the window', () {
    testWidgets('a 1280 window is a 1048 pane: no room for three columns', (
      tester,
    ) async {
      vm.addBlock(blockSpecFor('text')!);
      await pumpInShell(tester, window: 1280);
      expect(tester.takeException(), isNull);
      // The page keeps its width; the palette waits behind a button.
      expect(find.byType(ComponentPalette), findsNothing);
      expect(find.byType(PropertyPanel), findsOneWidget);
      expect(find.text('Add block'), findsOneWidget);
      // 1048 − the panel and its rule: well over the 486 three columns left.
      expect(
        tester.getSize(find.byType(WysiwygCanvas)).width,
        greaterThan(700),
      );
    });

    testWidgets('three columns once the pane itself is 1280', (tester) async {
      await pumpInShell(tester, window: 1280 + _kSidebar);
      expect(find.byType(ComponentPalette), findsOneWidget);
      expect(find.byType(PropertyPanel), findsOneWidget);
      expect(find.text('Add block'), findsNothing);
    });

    testWidgets('an iPad in portrait (820 → 588): the canvas, compact tools', (
      tester,
    ) async {
      await pumpInShell(tester, window: 820);
      expect(tester.takeException(), isNull, reason: 'the app bar fits');
      expect(find.byType(WysiwygCanvas), findsOneWidget);
      expect(find.byType(PropertyPanel), findsNothing);
      // No room for the Design | Preview pair: an icon instead.
      expect(find.text('Design'), findsNothing);
      expect(find.byTooltip('Preview'), findsOneWidget);
    });

    testWidgets('narrower than a page can be drawn: the outline', (
      tester,
    ) async {
      await pumpInShell(tester, window: 760);
      expect(tester.takeException(), isNull);
      expect(find.byType(MobileReorderView), findsOneWidget);
      expect(find.byType(WysiwygCanvas), findsNothing);
    });
  });

  group('menus open where they were asked for', () {
    testWidgets('the document picker, at its button', (tester) async {
      final document = DesignerDocumentController(
        loadRecent: () async => [
          Invoice.fromApi(
            InvoiceApi.fromJson({
              'id': 'inv1',
              'number': '0042',
              'amount': '10.00',
              'date': '2026-03-04',
              'updated_at': 1,
              'created_at': 1,
            }),
          ),
        ],
        loadClient: (_) async => null,
      );
      addTearDown(document.dispose);
      await document.load();
      await pumpInShell(tester, window: 1280 + _kSidebar, document: document);
      final button = tester.getTopLeft(find.text('Invoice 0042'));
      await tester.tap(find.text('Invoice 0042'));
      await tester.pumpAndSettle();
      final entry = tester.getTopLeft(find.text('Sample document'));
      // It used to open a sidebar's width to the right.
      expect((entry.dx - button.dx).abs(), lessThan(80));
    });

    testWidgets('a right-click menu, at the pointer — and its pick lands', (
      tester,
    ) async {
      vm.addBlock(blockSpecFor('text')!);
      vm.updateBlock(
        vm.blocks.single.copyWith(
          properties: {...vm.blocks.single.properties, 'content': 'Hello'},
        ),
      );
      vm.addBlock(blockSpecFor('divider')!);
      // The divider is selected; the text block is not.
      await pumpInShell(tester, window: 1280 + _kSidebar);
      final at = tester.getCenter(find.text('Hello'));
      final click = await tester.startGesture(
        at,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await click.up();
      await tester.pumpAndSettle();

      final entry = find.text('Duplicate');
      expect(entry, findsOneWidget);
      expect((tester.getTopLeft(entry).dx - at.dx).abs(), lessThan(80));

      // Opening the menu selected the block, which re-keys its cell: the
      // menu used to be waiting on that cell's context, and dropped the pick.
      await tester.tap(entry);
      await tester.pumpAndSettle();
      expect([for (final b in vm.blocks) b.type], ['text', 'text', 'divider']);
    });
  });

  group('the "Add block" button and what is under it', () {
    Future<DesignerDocumentController> oneInvoice() async {
      final document = DesignerDocumentController(
        loadRecent: () async => [
          Invoice.fromApi(
            InvoiceApi.fromJson({
              'id': 'inv1',
              'number': '0042',
              'amount': '10.00',
              'date': '2026-03-04',
              'updated_at': 1,
              'created_at': 1,
            }),
          ),
        ],
        loadClient: (_) async => null,
      );
      addTearDown(document.dispose);
      await document.load();
      return document;
    }

    testWidgets('it sits above the document bar, not on it', (tester) async {
      final document = await oneInvoice();
      await pumpInShell(tester, window: 820, document: document);
      final fab = tester.getRect(find.byType(FloatingActionButton));
      final bar = tester.getRect(find.byType(DesignerDocumentBar));
      expect(bar.height, greaterThan(0));
      expect(fab.bottom, lessThanOrEqualTo(bar.top));
    });

    testWidgets('the canvas leaves room to scroll its last row clear of it', (
      tester,
    ) async {
      await pumpInShell(tester, window: 820);
      expect(
        tester.widget<WysiwygCanvas>(find.byType(WysiwygCanvas)).bottomInset,
        greaterThanOrEqualTo(56),
      );
      // Where the palette is on screen there is no button, and no inset.
      await pumpInShell(tester, window: 1280 + _kSidebar);
      expect(
        tester.widget<WysiwygCanvas>(find.byType(WysiwygCanvas)).bottomInset,
        0,
      );
    });
  });

  group('the Page tab shows the page', () {
    testWidgets('in the drawer it used to close the drawer', (tester) async {
      vm.addBlock(blockSpecFor('divider')!);
      await pumpInShell(tester, window: 820);
      expect(find.byType(PropertyPanel), findsOneWidget, reason: 'selected');
      await tester.tap(find.text('Page'));
      await tester.pump();
      expect(vm.selectedBlockId, isNull);
      expect(find.byType(PropertyPanel), findsOneWidget);
      expect(find.text('Applies To'), findsOneWidget);
    });

    testWidgets('in the phone sheet it opens the page sheet, once', (
      tester,
    ) async {
      vm.addBlock(blockSpecFor('divider')!);
      vm.selectBlock(null);
      await pumpInShell(tester, window: 600);
      await tester.tap(find.text('Horizontal separator'));
      await tester.pumpAndSettle();
      expect(find.byType(PropertyPanel), findsOneWidget);

      await tester.tap(find.text('Page'));
      await tester.pumpAndSettle();
      expect(find.text('Applies To'), findsOneWidget);
      // The designer is still under it — nothing popped past the sheet.
      expect(find.byType(MobileReorderView), findsOneWidget);
    });

    testWidgets('deleting from the sheet closes the sheet and nothing else', (
      tester,
    ) async {
      vm.addBlock(blockSpecFor('divider')!);
      vm.selectBlock(null);
      await pumpInShell(tester, window: 600);
      await tester.tap(find.text('Horizontal separator'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete'));
      // Rebuild it a few more times while it leaves, as a closing keyboard
      // does — each used to pop one more route.
      for (var i = 0; i < 6; i++) {
        vm.setName('n$i');
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();
      expect(find.byType(PropertyPanel), findsNothing);
      expect(find.byType(MobileReorderView), findsOneWidget);
      expect(vm.blocks, isEmpty);
      await tester.pump(const Duration(seconds: 15)); // the Undo toast
    });
  });
}
