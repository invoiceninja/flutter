import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/design_block_layout.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/block_preview.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/wysiwyg_canvas.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/palette/component_palette.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/templates.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

import '../../../../../../_localization_helper.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Design _seed(List<DesignBlock> blocks) => Design(
  id: '',
  name: '',
  isCustom: true,
  isActive: true,
  isTemplate: false,
  isFree: false,
  entities: const [],
  template: DesignTemplate(blocks: blocks),
  updatedAt: DateTime.utc(2000),
  createdAt: DateTime.utc(2000),
  archivedAt: null,
  isDeleted: false,
);

List<String> _shape(WysiwygDesignViewModel vm) => [
  for (final row in vm.rows)
    [
      for (final b in row)
        '${isGapBlock(b) ? 'gap' : b.type}:${b.gridPosition.w}',
    ].join(' '),
];

void main() {
  late AppDatabase db;
  late DesignRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DesignRepository(db: db, api: _FakeDesignsApi());
  });

  tearDown(() async => db.close());

  WysiwygDesignViewModel vmWith(List<DesignBlock> blocks) =>
      WysiwygDesignViewModel(repo: repo, companyId: 'co1', seed: _seed(blocks));

  Future<void> pump(
    WidgetTester tester,
    WysiwygDesignViewModel vm, {
    Size size = const Size(1200, 700),
    bool palette = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: vm,
            builder: (_, _) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (palette) ComponentPalette(vm: vm),
                Expanded(child: WysiwygCanvas(vm: vm)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder cell(DesignBlock block) => find.byWidgetPredicate(
    (w) => w is BlockPreview && w.block.id == block.id,
  );

  testWidgets(
    'every block type draws at its own height in the scrolling page',
    (tester) async {
      // One of each, plus the unknown type another client might have saved.
      final vm = vmWith([
        for (final (i, spec) in kBlockLibrary.indexed)
          spec.newInstance(idPrefix: spec.type, x: 0, y: i),
        const DesignBlock(
          id: 'twig-1',
          type: 'twig',
          gridPosition: GridPosition(x: 0, y: 99, w: 12, h: 2),
        ),
      ]);
      await pump(tester, vm);
      expect(tester.takeException(), isNull);
      expect(
        find.byType(BlockPreview),
        findsNWidgets(kBlockLibrary.length + 1),
      );
      // The unknown block says what it is rather than vanishing.
      expect(find.textContaining('twig'), findsOneWidget);
    },
  );

  testWidgets('a block past the first screen can be reached and selected', (
    tester,
  ) async {
    // The page used to be a fixed A4 box with no scrolling: the standard
    // starter's totals, notes and footer were painted past its edge, where
    // nothing could be clicked.
    final starter = buildStarterTemplates().firstWhere(
      (s) => s.id == 'standard',
    );
    final vm = vmWith(starter.blocks);
    await pump(tester, vm, size: const Size(1200, 420));
    final footer = vm.blocks.firstWhere((b) => b.type == 'footer');

    final scrollable = find.descendant(
      of: find.byType(WysiwygCanvas),
      matching: find.byType(Scrollable),
    );
    final position = tester.state<ScrollableState>(scrollable.first).position;
    expect(
      position.maxScrollExtent,
      greaterThan(0),
      reason: 'the page scrolls',
    );

    await tester.ensureVisible(cell(footer));
    await tester.pump();
    await tester.tap(cell(footer));
    await tester.pump();
    expect(vm.selectedBlockId, footer.id);
  });

  testWidgets('a press on the page outside any block clears the selection', (
    tester,
  ) async {
    final vm = vmWith([
      blockSpecFor('text')!.newInstance(idPrefix: 't', x: 0, y: 0),
    ]);
    vm.selectBlock(vm.blocks.single.id);
    await pump(tester, vm);
    await tester.tapAt(
      tester.getTopLeft(find.byType(WysiwygCanvas)) + const Offset(4, 4),
    );
    await tester.pump();
    expect(vm.selectedBlockId, isNull);
  });

  testWidgets('selecting a block added off-screen scrolls it into view', (
    tester,
  ) async {
    final starter = buildStarterTemplates().firstWhere(
      (s) => s.id == 'standard',
    );
    final vm = vmWith(starter.blocks);
    await pump(tester, vm, size: const Size(1200, 420));
    final scrollable = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byType(WysiwygCanvas),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(scrollable.position.pixels, 0);

    vm.selectBlock(vm.blocks.last.id);
    await tester.pump(); // rebuild; the reveal is scheduled post-frame
    await tester.pump(); // the scroll animation's first tick
    await tester.pump(const Duration(milliseconds: 400));
    expect(scrollable.position.pixels, greaterThan(0));
  });

  group('dragging (desktop)', () {
    // flutter_test reports Android, where a drag needs a long press.
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    testWidgets('a palette block lands where the pointer is', (tester) async {
      // With the default drag anchor it landed left of the cursor by however
      // far along the tile it had been grabbed.
      final vm = vmWith([
        blockSpecFor('logo')!.newInstance(idPrefix: 'l', x: 0, y: 0),
        blockSpecFor('footer')!.newInstance(idPrefix: 'f', x: 0, y: 1),
      ]);
      await pump(tester, vm, palette: true);
      final logo = vm.blocks.first;
      final footer = vm.blocks.last;

      // Grab the tile by its far (right) end.
      final tile = find.widgetWithText(ListTile, 'Text');
      final grab = tester.getTopRight(tile) + const Offset(-10, 20);
      // Drop between the two rows.
      final between =
          (tester.getBottomLeft(cell(logo)) +
              tester.getTopRight(cell(footer))) /
          2;

      final gesture = await tester.startGesture(
        grab,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(between + const Offset(0, -20));
      await tester.pump();
      await gesture.moveTo(between);
      await tester.pump();
      await gesture.up();
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;

      expect(
        [for (final row in vm.rows) row.single.type],
        ['logo', 'text', 'footer'],
      );
      expect(vm.selectedBlock!.type, 'text');
    });

    testWidgets('a block dragged onto the side of another joins its row', (
      tester,
    ) async {
      final vm = vmWith([
        blockSpecFor('text')!
            .newInstance(idPrefix: 't', x: 0, y: 0)
            .copyWith(
              properties: const {
                'content': 'First\nblock\nwith\nseveral\nlines',
              },
            ),
        blockSpecFor('footer')!.newInstance(idPrefix: 'f', x: 0, y: 1),
      ]);
      await pump(tester, vm);
      final text = vm.blocks.first;
      final footer = vm.blocks.last;

      final target = tester.getRect(cell(text));
      final gesture = await tester.startGesture(
        tester.getCenter(cell(footer)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.moveTo(target.center + const Offset(40, 0));
      await tester.pump();
      // Right-hand half of the block, in its middle band: after it.
      await gesture.moveTo(Offset(target.right - 30, target.center.dy));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;

      expect(_shape(vm), ['text:6 footer:6']);
    });

    testWidgets('a width handle moves an edge by whole columns, as one undo', (
      tester,
    ) async {
      final vm = vmWith([
        blockSpecFor('text')!
            .newInstance(idPrefix: 'a', x: 0, y: 0)
            .copyWith(
              gridPosition: const GridPosition(x: 0, y: 0, w: 6, h: 2),
              properties: const {'content': 'Left'},
            ),
        blockSpecFor('text')!
            .newInstance(idPrefix: 'b', x: 6, y: 0)
            .copyWith(
              gridPosition: const GridPosition(x: 6, y: 0, w: 6, h: 2),
              properties: const {'content': 'Right'},
            ),
      ]);
      vm.selectBlock(vm.blocks.first.id);
      await pump(tester, vm);
      final left = vm.blocks.first;

      // The selected block's right edge.
      final rect = tester.getRect(cell(left));
      final column = rect.width / 6;
      final gesture = await tester.startGesture(
        Offset(rect.right, rect.center.dy),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      // In steps, as a real drag arrives: the gesture starts on the first.
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(Offset(column / 2, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;

      expect(_shape(vm), ['text:8 text:4']);
      vm.undo();
      expect(_shape(vm), ['text:6 text:6']);
      expect(vm.canUndo, isFalse);
    });
  });

  group('width handles', () {
    DesignBlock text(String id, int x, int w) => blockSpecFor('text')!
        .newInstance(idPrefix: id, x: x, y: 0)
        .copyWith(
          gridPosition: GridPosition(x: x, y: 0, w: w, h: 2),
          properties: {'content': 'Block $id'},
        );

    Finder grips() => find.byWidgetPredicate(
      (w) => w is MouseRegion && w.cursor == SystemMouseCursors.resizeColumn,
    );

    testWidgets('a block alone in its row can be narrowed by its grip', (
      tester,
    ) async {
      // Both its edges are the row's ends. The grip was drawn past the
      // content box there, where nothing is hit-tested.
      final vm = vmWith([text('a', 0, 12)]);
      vm.selectBlock(vm.blocks.single.id);
      await pump(tester, vm);
      expect(grips(), findsNWidgets(2));

      final rect = tester.getRect(cell(vm.blocks.single));
      final right = tester.getCenter(grips().last);
      // On the outline, just outside the block.
      expect(right.dx, greaterThanOrEqualTo(rect.right));
      final gesture = await tester.startGesture(
        right,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(Offset(-rect.width / 12 / 2, 0));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      expect(_shape(vm), ['text:9 gap:3']);
    });

    testWidgets('a press on a grip that is not a drag keeps the selection', (
      tester,
    ) async {
      final vm = vmWith([text('a', 0, 6), text('b', 6, 6)]);
      final id = vm.blocks.first.id;
      vm.selectBlock(id);
      await pump(tester, vm);
      await tester.tapAt(tester.getCenter(grips().last));
      await tester.pump();
      // It fell through to the page's background, which deselects.
      expect(vm.selectedBlockId, id);
    });

    testWidgets('the block beside its edge is still the block', (tester) async {
      // The handle is the size of its grip, not a strip the block's height.
      final vm = vmWith([text('a', 0, 6), text('b', 6, 6)]);
      vm.selectBlock(vm.blocks.first.id);
      await pump(tester, vm);
      final rect = tester.getRect(cell(vm.blocks.first));
      await tester.tapAt(Offset(rect.right - 4, rect.top + 3));
      await tester.pump();
      expect(vm.selectedBlockId, vm.blocks.first.id);
    });

    testWidgets('deselecting mid-drag ends the drag', (tester) async {
      final vm = vmWith([text('a', 0, 6), text('b', 6, 6)]);
      vm.selectBlock(vm.blocks.first.id);
      await pump(tester, vm);
      final gesture = await tester.startGesture(
        tester.getCenter(grips().last),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
      }
      vm.selectBlock(null); // Esc
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // What follows is recorded again: add, then undo just the add.
      vm.addBlock(blockSpecFor('divider')!);
      vm.undo();
      expect([for (final b in vm.blocks) b.type], ['text', 'text']);
    });
  });

  group('what stands in for a block that prints nothing', () {
    test('an empty text block, a spacer, a table with no columns', () {
      final data = DesignerSampleData.fallback;
      DesignBlock b(String type, Map<String, dynamic> p) => DesignBlock(
        id: type,
        type: type,
        gridPosition: const GridPosition(x: 0, y: 0, w: 12, h: 1),
        properties: p,
      );
      expect(
        blockRendersNothing(b('text', const {'content': ' '}), data),
        isTrue,
      );
      expect(
        blockRendersNothing(b('text', const {'content': 'x'}), data),
        isFalse,
      );
      expect(
        blockRendersNothing(b('spacer', const {'height': '40px'}), data),
        isTrue,
      );
      expect(
        blockRendersNothing(b('table', const {'columns': <Object>[]}), data),
        isTrue,
      );
      expect(
        blockRendersNothing(
          b('total', const {
            'items': [
              {'label': 'x', 'field': r'$total', 'show': false},
            ],
          }),
          data,
        ),
        isTrue,
      );
      // Public notes fall back to the document's own notes.
      expect(blockRendersNothing(b('public-notes', const {}), data), isFalse);
    });

    test('an info block whose every field is hidden when empty', () {
      final data = DesignerSampleData.fallback;
      DesignBlock info(
        List<Map<String, dynamic>> fields, {
        bool title = false,
      }) => DesignBlock(
        id: 'i',
        type: 'client-info',
        gridPosition: const GridPosition(x: 0, y: 0, w: 12, h: 1),
        properties: {
          'fieldConfigs': fields,
          'showTitle': title,
          'title': r'$bill_to_label',
        },
      );
      expect(blockRendersNothing(info(const []), data), isTrue);
      expect(blockRendersNothing(info(const [], title: true), data), isFalse);
      expect(
        blockRendersNothing(
          info(const [
            {'variable': r'$client.name', 'hideIfEmpty': true},
          ]),
          data,
        ),
        isFalse,
      );
    });
  });
}
