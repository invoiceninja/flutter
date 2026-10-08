import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/cell_typography_editor.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_panel.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/info_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/table_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/text_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/total_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_inputs.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

import '../../../../../../_localization_helper.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

BlockSpec _spec(String type) => kBlockLibrary.firstWhere((s) => s.type == type);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: kTestLocalizationsDelegates,
  supportedLocales: kTestSupportedLocales,
  locale: const Locale('en'),
  theme: buildInTheme(InTheme.light),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  late AppDatabase db;
  late DesignRepository repo;
  const companyId = 'co1';

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DesignRepository(db: db, api: _FakeDesignsApi());
  });

  tearDown(() async {
    await db.close();
  });

  group('TableBlockProperties', () {
    testWidgets('lists each column with delete + drag handle', (tester) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('table'));
      final block = vm.blocks.single;
      await tester.pumpWidget(
        _wrap(TableBlockProperties(vm: vm, block: block)),
      );
      await tester.pump();
      // Default products table ships 5 columns.
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(5));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(5));
    });

    testWidgets('delete removes the column from properties', (tester) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('table'));
      final initial = (vm.blocks.single.properties['columns'] as List).length;
      await tester.pumpWidget(
        _wrap(TableBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pump();
      final after = (vm.blocks.single.properties['columns'] as List).length;
      expect(after, initial - 1);
    });

    testWidgets('shows an Add column button', (tester) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('table'));
      await tester.pumpWidget(
        _wrap(TableBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      expect(find.text('Add Column'), findsOneWidget);
    });
  });

  group('TotalBlockProperties', () {
    testWidgets('lists each item with show toggle + drag handle', (
      tester,
    ) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('total'));
      await tester.pumpWidget(
        _wrap(TotalBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      // 6 default items.
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(6));
      // Switch widgets for show toggle (one per item).
      expect(find.byType(Switch), findsAtLeastNWidgets(6));
    });

    testWidgets('renders the Show labels toggle', (tester) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('total'));
      await tester.pumpWidget(
        _wrap(TotalBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      expect(find.text('Show labels'), findsOneWidget);
    });
  });

  group('InfoBlockProperties — Add field flow', () {
    testWidgets('lists each fieldConfig with hide + delete', (tester) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('client-info'));
      await tester.pumpWidget(
        _wrap(InfoBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      // Default client-info ships 5 fieldConfigs.
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(5));
      expect(find.byIcon(Icons.delete_outline), findsNWidgets(5));
    });

    testWidgets('renders the Add field button', (tester) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('client-info'));
      await tester.pumpWidget(
        _wrap(InfoBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      expect(find.text('Add Field'), findsOneWidget);
    });

    testWidgets('toggling hide-if-empty updates the field', (tester) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('client-info'));
      await tester.pumpWidget(
        _wrap(InfoBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      // Phase 7c moved the hide-if-empty toggle into the per-row
      // expansion: tap the chevron to expand the first row, then flip
      // the Switch.
      final firstExpand = find.byIcon(Icons.expand_more).first;
      await tester.tap(firstExpand);
      await tester.pump();
      final hideSwitch = find
          .ancestor(
            of: find.text('Hide if Empty'),
            matching: find.byType(PropertySwitch),
          )
          .first;
      await tester.tap(hideSwitch);
      await tester.pump();
      final fields = vm.blocks.single.properties['fieldConfigs'] as List;
      expect((fields.first as Map)['hideIfEmpty'], isFalse);
    });
  });

  group('Phase 8a — PxInput clamping (table border width)', () {
    testWidgets('PxInput maxPx clamps to the cap', (tester) async {
      String? captured;
      await tester.pumpWidget(
        _wrap(
          PxInput(
            labelKey: 'width',
            value: null,
            maxPx: 20,
            onChanged: (v) => captured = v,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '999');
      expect(captured, '20px');

      await tester.enterText(find.byType(TextField), '15');
      expect(captured, '15px');
    });

    testWidgets('PxInput minPx floors low values', (tester) async {
      String? captured;
      await tester.pumpWidget(
        _wrap(
          PxInput(
            labelKey: 'width',
            value: null,
            minPx: 0,
            maxPx: 20,
            onChanged: (v) => captured = v,
          ),
        ),
      );
      // Negative not parseable as int; '0' clamps in-bounds.
      await tester.enterText(find.byType(TextField), '0');
      expect(captured, '0px');
    });
  });

  group('Phase 8d — Total per-item CellTypographyEditor', () {
    testWidgets(
      'expansion renders a CellTypographyEditor sub-card with italic toggle',
      (tester) async {
        final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
        vm.addBlock(_spec('total'));
        await tester.pumpWidget(
          _wrap(TotalBlockProperties(vm: vm, block: vm.blocks.single)),
        );
        await tester.pump();
        // Expand the first item row.
        final firstExpand = find.byIcon(Icons.expand_more).first;
        await tester.tap(firstExpand);
        await tester.pumpAndSettle();
        // Sub-card lands.
        expect(find.byType(CellTypographyEditor), findsOneWidget);
        // Italic toggle inside the sub-card flips fontStyle.
        final italic = find.byTooltip('Italic').first;
        await tester.ensureVisible(italic);
        await tester.pump();
        await tester.tap(italic);
        await tester.pump();
        final items = vm.blocks.single.properties['items'] as List;
        expect((items.first as Map)['fontStyle'], 'italic');
      },
    );
  });

  group('Phase 8c — Text content 300 ms debounce', () {
    testWidgets('typing does not commit until the 300ms timer fires', (
      tester,
    ) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('text'));
      await tester.pumpWidget(
        _wrap(TextBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      // Find the multi-line content TextField (the only one with
      // OutlineInputBorder + no labelText is the content field).
      final contentField = find.byType(TextField).first;
      await tester.enterText(contentField, 'h');
      await tester.enterText(contentField, 'hi');
      await tester.pump(const Duration(milliseconds: 100));
      // Still within the debounce window — nothing committed yet.
      expect(vm.blocks.single.properties['content'], isNot('hi'));
      // Past the debounce — the latest value commits exactly once.
      await tester.pump(const Duration(milliseconds: 250));
      expect(vm.blocks.single.properties['content'], 'hi');
    });

    // M4: switching blocks (or leaving the screen) within the 300ms window
    // must NOT lose the trailing content edit. The editor is keyed on the
    // block id, so a switch disposes this State; dispose flushes the pending
    // write instead of cancelling it silently.
    testWidgets('block-switch within the debounce window flushes the edit', (
      tester,
    ) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('text'));
      final blockId = vm.blocks.single.id;
      await tester.pumpWidget(
        _wrap(TextBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'hi');
      await tester.pump(const Duration(milliseconds: 100)); // still debouncing
      expect(vm.blocks.single.properties['content'], isNot('hi'));

      // Tear down the editor (simulates selecting another block).
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump(); // drain the deferred flush microtask

      expect(
        vm.blocks.firstWhere((b) => b.id == blockId).properties['content'],
        'hi',
        reason: 'pending content flushed on teardown, not dropped',
      );
    });
  });

  group('Phase 8j — Total keepTogether switch', () {
    testWidgets('toggling the keep-together switch writes the boolean', (
      tester,
    ) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('total'));
      await tester.pumpWidget(
        _wrap(TotalBlockProperties(vm: vm, block: vm.blocks.single)),
      );
      await tester.pump();
      // It lives in the Advanced group, which starts closed (and remembers
      // being opened for the rest of the session).
      Finder pageBreak() => find.ancestor(
        of: find.text('Force page break before this block'),
        matching: find.byType(PropertySwitch),
      );
      if (pageBreak().evaluate().isEmpty) {
        final advanced = find.text('ADVANCED');
        await tester.ensureVisible(advanced);
        await tester.pump();
        await tester.tap(advanced);
        await tester.pump();
      }
      await tester.ensureVisible(pageBreak().first);
      await tester.pump();
      await tester.tap(pageBreak().first);
      await tester.pump();
      expect(vm.blocks.single.properties['keepTogether'], isTrue);
    });
  });

  group('Phase 9b — Total block-level fontSize', () {
    testWidgets('typing a size, stepping it and clearing it', (tester) async {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_spec('total'));
      await tester.pumpWidget(
        _wrap(
          ListenableBuilder(
            listenable: vm,
            builder: (_, _) =>
                TotalBlockProperties(vm: vm, block: vm.blocks.single),
          ),
        ),
      );
      await tester.pump();
      final row = find.widgetWithText(PropertyRow, 'Font Size').first;
      final field = find.descendant(of: row, matching: find.byType(TextField));
      await tester.ensureVisible(field);
      await tester.pump();
      await tester.enterText(field, '18');
      await tester.pump();
      expect(vm.blocks.single.properties['fontSize'], '18px');

      await tester.tap(
        find.descendant(of: row, matching: find.byIcon(Icons.add)),
      );
      await tester.pump();
      expect(vm.blocks.single.properties['fontSize'], '19px');

      // Empty is "the document's size": the key leaves the block.
      await tester.enterText(field, '');
      await tester.pump();
      expect(vm.blocks.single.properties.containsKey('fontSize'), isFalse);
    });
  });

  group('Phase 9c/9d — embedDocuments + hideEmptyColumns setting', () {
    // The PropertyPanel's document form has pre-existing layout density
    // (font dropdowns overflow when squeezed into the panel's 280 px
    // width during widget tests). The UI wiring is a trivial
    // `onChanged: (v) => vm.setDocumentSettings(ds.copyWith(...))` —
    // assert directly on the VM that both new fields round-trip
    // through `setDocumentSettings + copyWith`.
    test('setDocumentSettings round-trips embedDocuments', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      expect(vm.documentSettings.embedDocuments, isFalse);
      vm.setDocumentSettings(
        vm.documentSettings.copyWith(embedDocuments: true),
      );
      expect(vm.documentSettings.embedDocuments, isTrue);
    });

    test('setDocumentSettings round-trips hideEmptyColumns', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      expect(vm.documentSettings.hideEmptyColumns, isFalse);
      vm.setDocumentSettings(
        vm.documentSettings.copyWith(hideEmptyColumns: true),
      );
      expect(vm.documentSettings.hideEmptyColumns, isTrue);
    });

    test('toggling one flag leaves the other untouched', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.setDocumentSettings(
        vm.documentSettings.copyWith(embedDocuments: true),
      );
      expect(vm.documentSettings.embedDocuments, isTrue);
      expect(vm.documentSettings.hideEmptyColumns, isFalse);
      vm.setDocumentSettings(
        vm.documentSettings.copyWith(hideEmptyColumns: true),
      );
      expect(vm.documentSettings.embedDocuments, isTrue);
      expect(vm.documentSettings.hideEmptyColumns, isTrue);
    });
  });

  group('page margins — four numbers for four distances', () {
    // The design stores a margin and a padding per side and the server adds
    // them into one `@page` margin. The panel used to show all eight.
    Widget bareWrap(Widget child) => MaterialApp(
      localizationsDelegates: kTestLocalizationsDelegates,
      supportedLocales: kTestSupportedLocales,
      locale: const Locale('en'),
      theme: buildInTheme(InTheme.light),
      home: Scaffold(body: child),
    );

    testWidgets('each side appears once and edits the whole inset', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      await tester.pumpWidget(
        bareWrap(
          ListenableBuilder(
            listenable: vm,
            builder: (_, _) => PropertyPanel(vm: vm),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      for (final side in const ['Top', 'Right', 'Bottom', 'Left']) {
        expect(find.text(side), findsOneWidget, reason: side);
      }
      Finder fieldOf(String side) => find.descendant(
        of: find.widgetWithText(PropertyRow, side),
        matching: find.byType(TextField),
      );
      // Defaults: margin 0 + padding 30.
      expect(tester.widget<TextField>(fieldOf('Top')).controller!.text, '30');

      // Wider than the padding: the margin takes the difference.
      await tester.enterText(fieldOf('Top'), '50');
      await tester.pump();
      expect(vm.documentSettings.pagePaddingTop, 30);
      expect(vm.documentSettings.pageMarginTop, 20);

      // Narrower than the padding: the padding gives way.
      await tester.enterText(fieldOf('Left'), '10');
      await tester.pump();
      expect(vm.documentSettings.pagePaddingLeft, 10);
      expect(vm.documentSettings.pageMarginLeft, 0);

      // A preset sets all four.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Wide'));
      await tester.pump();
      final ds = vm.documentSettings;
      expect(
        [
          ds.pageMarginTop + ds.pagePaddingTop,
          ds.pageMarginRight + ds.pagePaddingRight,
          ds.pageMarginBottom + ds.pagePaddingBottom,
          ds.pageMarginLeft + ds.pagePaddingLeft,
        ],
        [60, 60, 60, 60],
      );
    });

    testWidgets('a stored value the lists do not hold is shown as stored', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.setDocumentSettings(
        vm.documentSettings.copyWith(pageSize: 'B5', primaryFont: 'Zilla_Slab'),
      );
      await tester.pumpWidget(bareWrap(PropertyPanel(vm: vm)));
      await tester.pump();
      // Not a silent "A4", and not "Roboto".
      expect(find.textContaining('B5'), findsOneWidget);
      expect(find.textContaining('prints as A4'), findsOneWidget);
      expect(find.text('Zilla Slab'), findsOneWidget);
    });

    testWidgets(
      'a size the server prints is not called A4, whatever its case',
      (tester) async {
        tester.view.physicalSize = const Size(420, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final (stored, shown) in [
          ('a4', 'A4'),
          ('letter', 'Letter'),
          ('A1', 'A1'),
        ]) {
          final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
          vm.setDocumentSettings(
            vm.documentSettings.copyWith(pageSize: stored),
          );
          await tester.pumpWidget(
            bareWrap(PropertyPanel(key: ValueKey(stored), vm: vm)),
          );
          await tester.pump();
          expect(
            find.textContaining('prints as A4'),
            findsNothing,
            reason: stored,
          );
          expect(find.text(shown), findsWidgets, reason: stored);
        }
      },
    );
  });

  group('AlignmentInput', () {
    testWidgets('three icon buttons with spoken names; a press reports it', (
      tester,
    ) async {
      String? picked;
      await tester.pumpWidget(
        _wrap(
          AlignmentInput(
            labelKey: 'alignment',
            value: 'left',
            onChanged: (v) => picked = v,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.format_align_left), findsOneWidget);
      expect(find.byIcon(Icons.format_align_center), findsOneWidget);
      expect(find.byIcon(Icons.format_align_right), findsOneWidget);
      // Icon-only, so each carries its name as a tooltip.
      for (final name in const ['Left', 'Center', 'Right']) {
        expect(find.byTooltip(name), findsOneWidget, reason: name);
      }
      await tester.tap(find.byTooltip('Right'));
      expect(picked, 'right');
    });
  });

  group('ColorInput', () {
    testWidgets('opens a picker; a swatch sets it and Default clears it', (
      tester,
    ) async {
      String? value = '#111111';
      await tester.pumpWidget(
        _wrap(
          StatefulBuilder(
            builder: (context, setState) => DesignerPaletteScope(
              inUse: const ['#AB12CD'],
              brand: const [],
              child: ColorInput(
                labelKey: 'color',
                value: value,
                defaultValue: '#000000',
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('#111111'), findsOneWidget);

      await tester.tap(find.text('#111111'));
      await tester.pumpAndSettle();
      // Colours the design already uses come first.
      expect(find.text('In this design'), findsOneWidget);
      await tester.tap(find.text('Default'));
      await tester.pumpAndSettle();
      expect(value, '');
      // Unset reads "Default", not a hex code nobody chose.
      expect(find.text('Default'), findsOneWidget);
    });

    test('collects the colours a design already uses, once each', () {
      expect(
        collectHexColors([
          {
            'color': '#ff0000',
            'headerBg': '#F3F4F6',
            'items': [
              {'color': '#FF0000'},
              {'color': 'not a colour'},
            ],
          },
        ]),
        ['#FF0000', '#F3F4F6'],
      );
    });
  });
}
