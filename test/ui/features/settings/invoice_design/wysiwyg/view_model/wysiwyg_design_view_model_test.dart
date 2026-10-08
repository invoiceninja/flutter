import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/api/company_settings_api_model.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/design_block_layout.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

BlockSpec _specByType(String type) =>
    kBlockLibrary.firstWhere((s) => s.type == type);

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

  List<String> shape(WysiwygDesignViewModel vm) => [
    for (final row in vm.rows)
      [
        for (final b in row)
          '${isGapBlock(b) ? 'gap' : b.type}:${b.gridPosition.w}',
      ].join(' '),
  ];

  group('selection / panel mode', () {
    test('starts unselected with Document Settings panel mode', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      expect(vm.selectedBlockId, isNull);
      expect(vm.panelMode, PropertyPanelMode.document);
    });

    test('addBlock selects the new block and switches to block mode', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      expect(vm.selectedBlockId, isNotNull);
      expect(vm.panelMode, PropertyPanelMode.block);
      expect(vm.selectedBlock?.type, 'logo');
    });

    test(
      'selectBlock(null) clears selection AND switches back to document mode',
      () {
        final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
        vm.addBlock(_specByType('text'));
        expect(vm.panelMode, PropertyPanelMode.block);
        vm.selectBlock(null);
        expect(vm.selectedBlockId, isNull);
        expect(vm.panelMode, PropertyPanelMode.document);
      },
    );

    test('deleting the selected block clears the selection', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      final id = vm.selectedBlockId!;
      vm.deleteBlock(id);
      expect(vm.selectedBlockId, isNull);
      expect(vm.blocks, isEmpty);
    });

    test('deleting a NON-selected block keeps the current selection', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      final logoId = vm.selectedBlockId!;
      vm.addBlock(_specByType('text'));
      final textId = vm.selectedBlockId!;
      // Delete the unselected logo block.
      vm.deleteBlock(logoId);
      expect(vm.selectedBlockId, textId);
      expect(vm.blocks, hasLength(1));
    });
  });

  group('rows — adding', () {
    test('a block from the palette is a row of its own, full width', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.addBlock(_specByType('total'));
      expect(shape(vm), ['logo:12', 'total:12']);
    });

    test('…added below the row of the selected block', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      final logo = vm.selectedBlockId;
      vm.addBlock(_specByType('footer'));
      vm.selectBlock(logo);
      vm.addBlock(_specByType('text'));
      expect(shape(vm), ['logo:12', 'text:12', 'footer:12']);
    });

    test('dropped beside a block, it shares that row', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      final logo = vm.selectedBlockId!;
      expect(
        vm.insertBeside(_specByType('invoice-details'), logo, before: false),
        isTrue,
      );
      // The details block asks for its default six columns; the logo, which
      // had the row to itself, gives them up.
      expect(shape(vm), ['logo:6 invoice-details:6']);
      expect(vm.selectedBlock!.type, 'invoice-details');
    });

    test('a row with no room refuses, and nothing changes', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('table')); // min 6
      final table = vm.selectedBlockId!;
      vm.insertBeside(_specByType('table'), table, before: false);
      expect(shape(vm), ['table:6 table:6']);
      expect(vm.canPlaceBeside(table, type: 'table'), isFalse);
      expect(
        vm.insertBeside(_specByType('table'), table, before: true),
        isFalse,
      );
      expect(shape(vm), ['table:6 table:6']);
    });

    test('what is saved groups into the same rows', () {
      // The server reads rows from `y` alone: equal within a row, larger
      // for each row below.
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.insertBeside(
        _specByType('invoice-details'),
        vm.selectedBlockId!,
        before: false,
      );
      vm.addBlock(_specByType('table'));
      final ys = [for (final b in vm.blocks) b.gridPosition.y];
      expect(ys[0], ys[1]);
      expect(ys[2], greaterThan(ys[1]));
    });
  });

  group('rows — moving', () {
    WysiwygDesignViewModel three() {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.addBlock(_specByType('text'));
      vm.addBlock(_specByType('footer'));
      return vm;
    }

    String idOf(WysiwygDesignViewModel vm, String type) =>
        vm.blocks.firstWhere((b) => b.type == type).id;

    test('to a row of its own between two others', () {
      final vm = three();
      vm.moveBlockToNewRow(idOf(vm, 'footer'), 1);
      expect(shape(vm), ['logo:12', 'footer:12', 'text:12']);
    });

    test('the index counts the rows as they were before the move', () {
      final vm = three();
      vm.moveBlockToNewRow(idOf(vm, 'logo'), 3); // below everything
      expect(shape(vm), ['text:12', 'footer:12', 'logo:12']);
    });

    test('onto the gap next to where it already is does nothing', () {
      final vm = three();
      vm.undo();
      vm.redo();
      final before = vm.blocks;
      vm.moveBlockToNewRow(idOf(vm, 'text'), 1);
      vm.moveBlockToNewRow(idOf(vm, 'text'), 2);
      expect(vm.blocks, before);
    });

    test('beside another block leaves no empty row behind', () {
      final vm = three();
      expect(
        vm.moveBlockBeside(idOf(vm, 'text'), idOf(vm, 'logo'), before: false),
        isTrue,
      );
      expect(shape(vm), ['logo:6 text:6', 'footer:12']);
    });

    test('out of a shared row leaves a gap where it was', () {
      final vm = three();
      vm.moveBlockBeside(idOf(vm, 'text'), idOf(vm, 'logo'), before: false);
      vm.moveBlockToNewRow(idOf(vm, 'text'), 2);
      expect(shape(vm), ['logo:6 gap:6', 'footer:12', 'text:12']);
    });

    test('up and down: a lone block trades rows, a shared one steps out', () {
      final vm = three();
      vm.moveBlockVertically(idOf(vm, 'footer'), -1);
      expect(shape(vm), ['logo:12', 'footer:12', 'text:12']);
      vm.moveBlockBeside(idOf(vm, 'text'), idOf(vm, 'footer'), before: false);
      expect(shape(vm), ['logo:12', 'footer:6 text:6']);
      vm.moveBlockVertically(idOf(vm, 'text'), -1);
      expect(shape(vm), ['logo:12', 'text:12', 'footer:6 gap:6']);
    });

    test('into the row above or below', () {
      final vm = three();
      expect(vm.joinNeighbourRow(idOf(vm, 'text'), -1), isTrue);
      expect(shape(vm), ['logo:6 text:6', 'footer:12']);
      expect(vm.joinNeighbourRow(idOf(vm, 'logo'), -1), isFalse);
    });

    test('within a row: trade places with the neighbour, or with a gap', () {
      final vm = three();
      vm.moveBlockBeside(idOf(vm, 'text'), idOf(vm, 'logo'), before: false);
      vm.moveBlockWithinRow(idOf(vm, 'text'), -1);
      expect(shape(vm).first, 'text:6 logo:6');
    });

    test('a whole row', () {
      final vm = three();
      vm.moveRow(2, 0);
      expect(shape(vm), ['footer:12', 'logo:12', 'text:12']);
    });
  });

  group('rows — widths', () {
    WysiwygDesignViewModel pair() {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.insertBeside(_specByType('text'), vm.selectedBlockId!, before: false);
      return vm; // logo:6 text:6
    }

    test('a drag replays from where it started, and is one undo step', () {
      final vm = pair();
      vm.beginGesture();
      vm.dragBoundary(0, 1, 1);
      vm.dragBoundary(0, 1, 2);
      vm.dragBoundary(0, 1, 3);
      vm.endGesture();
      expect(shape(vm), ['logo:9 text:3']);
      vm.undo();
      expect(shape(vm), ['logo:6 text:6']);
    });

    test('a drag back to the start leaves no undo step', () {
      final vm = pair();
      vm.undo();
      vm.redo();
      final before = vm.blocks;
      vm.beginGesture();
      vm.dragBoundary(0, 1, 2);
      vm.dragBoundary(0, 1, 0);
      vm.endGesture();
      expect(vm.blocks, before);
      vm.undo(); // the insert, not a ghost of the drag
      expect(shape(vm), ['logo:12']);
    });

    test('a block alone in its row can be made narrower', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('total'));
      vm.beginGesture();
      vm.dragBoundary(0, 0, 6); // its left edge, pushed in
      vm.endGesture();
      expect(shape(vm), ['gap:6 total:6']);
    });

    test('wider and narrower from the keyboard', () {
      final vm = pair();
      final text = vm.selectedBlockId!;
      vm.nudgeWidth(text, -1);
      expect(shape(vm), ['logo:6 text:5 gap:1']);
      vm.nudgeWidth(text, 1);
      expect(shape(vm), ['logo:6 text:6']);
      // Nothing left on its right: it grows leftwards instead.
      vm.nudgeWidth(text, 1);
      expect(shape(vm), ['logo:5 text:7']);
    });

    test('left, centre, right for a block with room to spare', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('total'));
      final total = vm.selectedBlockId!;
      vm.beginGesture();
      vm.dragBoundary(0, 1, -8);
      vm.endGesture();
      expect(shape(vm), ['total:4 gap:8']);
      vm.positionBlock(total, RowPosition.right);
      expect(shape(vm), ['gap:8 total:4']);
      vm.positionBlock(total, RowPosition.center);
      expect(shape(vm), ['gap:4 total:4 gap:4']);
    });

    test('removing the gaps hands the space to the blocks', () {
      final vm = pair();
      vm.nudgeWidth(vm.selectedBlockId!, -1);
      vm.nudgeWidth(vm.selectedBlockId!, -1);
      expect(shape(vm), ['logo:6 text:4 gap:2']);
      vm.removeGaps(0);
      expect(shape(vm), ['logo:7 text:5']);
    });
  });

  group('rows — deleting and copying', () {
    test('deleting from a shared row leaves a gap; the Undo puts it back', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.insertBeside(_specByType('text'), vm.selectedBlockId!, before: false);
      final text = vm.selectedBlockId!;
      final deleted = vm.deleteBlock(text)!;
      expect(shape(vm), ['logo:6 gap:6']);
      vm.restoreDeleted(deleted);
      expect(shape(vm), ['logo:6 text:6']);
      vm.restoreDeleted(deleted); // already back
      expect(vm.blocks.where((b) => b.id == text), hasLength(1));
    });

    test('…as a row of its own when something changed in between', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.addBlock(_specByType('text'));
      final deleted = vm.deleteBlock(vm.blocks.first.id)!;
      vm.addBlock(_specByType('divider'));
      vm.restoreDeleted(deleted);
      expect(shape(vm), ['logo:12', 'text:12', 'divider:12']);
    });

    test('deleting an unknown block is nothing', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      expect(vm.deleteBlock('nope'), isNull);
    });

    test('a copy lands directly below, in the same place across the row', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.insertBeside(_specByType('text'), vm.selectedBlockId!, before: false);
      final text = vm.selectedBlockId!;
      vm.addBlock(_specByType('footer'));
      vm.duplicateBlock(text);
      expect(shape(vm), ['logo:6 text:6', 'gap:6 text:6', 'footer:12']);
      expect(vm.selectedBlockId, isNot(text));
      expect(vm.selectedBlock!.type, 'text');
    });

    test('duplicateBlock of an id that is not on the page does nothing', () {
      // It is called with whatever is selected (⌘D, the menu, the panel);
      // a selection that has just gone must not be an exception.
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.duplicateBlock('nope');
      expect(vm.blocks, hasLength(1));
    });

    test('a whole row can be copied or removed', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.addBlock(_specByType('text'));
      vm.duplicateRow(0);
      expect(shape(vm), ['logo:12', 'logo:12', 'text:12']);
      expect({for (final b in vm.blocks) b.id}, hasLength(3));
      vm.deleteRow(1);
      expect(shape(vm), ['logo:12', 'text:12']);
    });
  });

  group('selection from the keyboard', () {
    test('steps along a row and to the nearest block above or below', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      final logo = vm.selectedBlockId!;
      vm.insertBeside(_specByType('text'), logo, before: false);
      final text = vm.selectedBlockId!;
      vm.addBlock(_specByType('footer'));
      final footer = vm.selectedBlockId!;

      vm.selectNeighbour(dy: -1);
      expect(vm.selectedBlockId, anyOf(logo, text));
      vm.selectBlock(logo);
      vm.selectNeighbour(dx: 1);
      expect(vm.selectedBlockId, text);
      vm.selectNeighbour(dx: 1); // nothing further right
      expect(vm.selectedBlockId, text);
      vm.selectNeighbour(dy: 1);
      expect(vm.selectedBlockId, footer);
    });

    test('with nothing selected, takes the first block', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      final logo = vm.selectedBlockId;
      vm.selectBlock(null);
      vm.selectNeighbour(dy: 1);
      expect(vm.selectedBlockId, logo);
    });
  });

  group('DocumentSettings seeding from company.settings', () {
    test('uses CompanySettings when seeding a brand-new design', () {
      const cs = CompanySettingsApi(
        pageLayout: 'landscape',
        pageSize: 'Letter',
        fontSize: 14,
        primaryFont: 'Open Sans',
        secondaryFont: 'Lato',
        showPaidStamp: true,
        showShippingAddress: true,
        embedDocuments: true,
        hideEmptyColumnsOnPdf: true,
        pageNumbering: true,
      );
      final vm = WysiwygDesignViewModel(
        repo: repo,
        companyId: companyId,
        companySettings: cs,
      );
      final ds = vm.documentSettings;
      expect(ds.pageLayout, 'landscape');
      expect(ds.pageSize, 'Letter');
      expect(ds.globalFontSize, 14);
      expect(ds.primaryFont, 'Open Sans');
      expect(ds.secondaryFont, 'Lato');
      expect(ds.showPaidStamp, isTrue);
      expect(ds.showShippingAddress, isTrue);
      expect(ds.embedDocuments, isTrue);
      expect(ds.hideEmptyColumns, isTrue);
      expect(ds.pageNumbering, isTrue);
    });

    test(
      'falls back to React-parity defaults when CompanySettings is null',
      () {
        final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
        final ds = vm.documentSettings;
        expect(ds.pageLayout, 'portrait');
        expect(ds.pageSize, 'A4');
        expect(ds.globalFontSize, 16);
        expect(ds.primaryFont, 'Roboto');
      },
    );

    test('handles partially-set CompanySettings (nulls fall through)', () {
      const cs = CompanySettingsApi(pageLayout: 'landscape');
      final vm = WysiwygDesignViewModel(
        repo: repo,
        companyId: companyId,
        companySettings: cs,
      );
      final ds = vm.documentSettings;
      expect(ds.pageLayout, 'landscape'); // from company
      expect(ds.pageSize, 'A4'); // default
      expect(ds.globalFontSize, 16); // default
    });
  });

  group('undo / redo', () {
    test('add → undo restores the prior empty blocks list', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      expect(vm.canUndo, isFalse);
      vm.addBlock(_specByType('logo'));
      expect(vm.blocks, hasLength(1));
      expect(vm.canUndo, isTrue);
      vm.undo();
      expect(vm.blocks, isEmpty);
      expect(vm.canRedo, isTrue);
    });

    test('add → add → undo → undo unwinds both mutations', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.addBlock(_specByType('text'));
      expect(vm.blocks, hasLength(2));
      vm.undo();
      expect(vm.blocks, hasLength(1));
      expect(vm.blocks.first.type, 'logo');
      vm.undo();
      expect(vm.blocks, isEmpty);
    });

    test('redo fast-forwards through an undone mutation', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.undo();
      expect(vm.blocks, isEmpty);
      vm.redo();
      expect(vm.blocks, hasLength(1));
      expect(vm.canRedo, isFalse);
    });

    test('new structural mutation after undo wipes the redo tail', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.undo();
      expect(vm.canRedo, isTrue);
      vm.addBlock(_specByType('text')); // branch — redo tail wiped
      expect(vm.canRedo, isFalse);
    });

    test('a property edit is its own undo step', () {
      // It used not to be recorded at all: ⌘Z after recolouring a block
      // removed the block instead.
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('text'));
      final current = vm.blocks.single;
      vm.updateBlock(
        current.copyWith(
          properties: {...current.properties, 'content': 'hello'},
        ),
      );
      vm.undo();
      expect(vm.blocks.single.properties['content'], '');
      vm.undo();
      expect(vm.blocks, isEmpty);
    });

    test('edits to one field fold into a single step', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('text'));
      for (final text in ['h', 'he', 'hel', 'hello']) {
        final b = vm.blocks.single;
        vm.updateBlock(
          b.copyWith(properties: {...b.properties, 'content': text}),
        );
      }
      vm.undo();
      expect(vm.blocks.single.properties['content'], '');
    });

    test('a different field starts a new step', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('text'));
      var b = vm.blocks.single;
      vm.updateBlock(b.copyWith(properties: {...b.properties, 'content': 'x'}));
      b = vm.blocks.single;
      vm.updateBlock(
        b.copyWith(properties: {...b.properties, 'align': 'right'}),
      );
      vm.undo();
      expect(vm.blocks.single.properties['align'], 'left');
      expect(vm.blocks.single.properties['content'], 'x');
    });

    test('coming back to a field after selecting elsewhere is a new step', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('text'));
      final id = vm.selectedBlockId;
      var b = vm.blocks.single;
      vm.updateBlock(b.copyWith(properties: {...b.properties, 'content': 'a'}));
      vm.selectBlock(null);
      vm.selectBlock(id);
      b = vm.blocks.single;
      vm.updateBlock(
        b.copyWith(properties: {...b.properties, 'content': 'ab'}),
      );
      vm.undo();
      expect(vm.blocks.single.properties['content'], 'a');
    });

    test('document settings are undoable', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.setDocumentSettings(
        vm.documentSettings.copyWith(pageLayout: 'landscape'),
      );
      expect(vm.canUndo, isTrue);
      vm.undo();
      expect(vm.documentSettings.pageLayout, 'portrait');
    });

    test('undo keeps the selection when its block is still there', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.addBlock(_specByType('text'));
      final id = vm.selectedBlockId!;
      vm.moveBlockVertically(id, -1);
      vm.undo();
      expect(vm.selectedBlockId, id);
      vm.undo(); // the add — the block is gone
      expect(vm.selectedBlockId, isNull);
    });

    test('every structural change is its own undo step', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.addBlock(_specByType('text'));
      final logoId = vm.blocks.first.id;
      final textId = vm.blocks.last.id;
      List<String> ids() => [for (final b in vm.blocks) b.id];
      final start = ids();

      vm.deleteBlock(textId);
      vm.undo();
      expect(ids(), start);

      vm.duplicateBlock(logoId);
      expect(vm.blocks, hasLength(3));
      vm.undo();
      expect(ids(), start);

      vm.moveBlockVertically(textId, -1);
      expect(ids(), [textId, logoId]);
      vm.undo();
      expect(ids(), start);

      vm.moveBlockBeside(textId, logoId, before: false);
      expect(vm.rows, hasLength(1));
      vm.undo();
      expect(vm.rows, hasLength(2));
    });

    test('resetToEmpty clears the history', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      vm.addBlock(_specByType('text'));
      expect(vm.canUndo, isTrue);
      vm.resetToEmpty();
      expect(vm.canUndo, isFalse);
      expect(vm.canRedo, isFalse);
    });
  });

  group('discard / reset', () {
    test('resetToEmpty clears blocks, selection, and re-seeds settings', () {
      const cs = CompanySettingsApi(pageSize: 'Letter');
      final vm = WysiwygDesignViewModel(
        repo: repo,
        companyId: companyId,
        companySettings: cs,
      );
      vm.addBlock(_specByType('logo'));
      vm.setName('Drafty');
      expect(vm.blocks, hasLength(1));
      expect(vm.isDirty, isTrue);
      vm.resetToEmpty(cs);
      expect(vm.blocks, isEmpty);
      expect(vm.selectedBlockId, isNull);
      expect(vm.draft.name, isEmpty);
      // Seed survived through the reset.
      expect(vm.documentSettings.pageSize, 'Letter');
    });
  });

  group('Phase 8k — importFromJson', () {
    test('round-trips a Design through export + import', () {
      // Build a non-trivial draft, export it, then import into a fresh
      // VM and assert the blocks + documentSettings come back intact.
      final source = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      source.addBlock(_specByType('logo'));
      source.addBlock(_specByType('total'));
      source.setDocumentSettings(
        source.documentSettings.copyWith(pageSize: 'Letter'),
      );
      final exported = source.draft.toApiJson(preserveTempId: false);
      final raw = const JsonEncoder().convert(exported);

      final target = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      final err = target.importFromJson(raw);
      expect(err, isNull);
      expect(target.blocks, hasLength(2));
      expect(target.blocks.map((b) => b.type).toList(), ['logo', 'total']);
      expect(target.documentSettings.pageSize, 'Letter');
    });

    test('returns "invalid_json" on malformed input', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      expect(vm.importFromJson('not json at all'), 'invalid_json');
      expect(vm.importFromJson('"just a string"'), 'invalid_json');
      expect(vm.importFromJson('[1, 2, 3]'), 'invalid_json');
    });

    test('an import clears the selection and is one undo step', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('logo'));
      expect(vm.selectedBlockId, isNotNull);
      expect(vm.canUndo, isTrue);
      // Fresh import from a different design.
      final other = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      other.addBlock(_specByType('text'));
      final raw = const JsonEncoder().convert(
        other.draft.toApiJson(preserveTempId: false),
      );
      final err = vm.importFromJson(raw);
      expect(err, isNull);
      expect(vm.selectedBlockId, isNull);
      expect(vm.blocks.single.type, 'text');
      // Replacing the whole layout is the change most worth undoing — it
      // used to wipe the history instead.
      vm.undo();
      expect(vm.blocks.single.type, 'logo');
    });
  });

  group('Phase 15d — performSave → repo round-trip', () {
    test(
      'create then watchById returns the same blocks + documentSettings',
      () async {
        final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
        // Build a non-trivial draft covering every important corner of the
        // schema: blocks list, GridPosition, properties (incl. Phase 8j
        // keepTogether), and DocumentSettings.
        vm.addBlock(_specByType('logo'));
        vm.addBlock(_specByType('total'));
        // Flip the keepTogether flag on the total block we just added.
        final totalBlock = vm.blocks.last;
        vm.updateBlock(
          totalBlock.copyWith(
            properties: {
              ...totalBlock.properties,
              'keepTogether': true,
              'align': 'right',
            },
          ),
        );
        vm.setDocumentSettings(
          vm.documentSettings.copyWith(
            pageSize: 'Letter',
            embedDocuments: true,
            hideEmptyColumns: true,
          ),
        );
        vm.setName('Round-trip test');

        // Save (create branch — vm.isCreate is true; this lands a `tmp_…`
        // row in Drift plus an outbox create row).
        final saved = await vm.performSave();
        expect(saved.entity.id, isNotEmpty);

        // Read back via the same repo. Use `watchAll` since the
        // create-path id is tmp_; we don't have a real server id yet.
        final all = await repo.watchAll(companyId: companyId).first;
        final fresh = all.firstWhere((d) => d.name == 'Round-trip test');

        // Blocks survived.
        expect(fresh.template.blocks, hasLength(2));
        expect(fresh.template.blocks.map((b) => b.type).toList(), [
          'logo',
          'total',
        ]);

        // The Phase 8j keepTogether boolean made it through the mapper
        // → Drift → row-rebuild cycle.
        final totalAfter = fresh.template.blocks.firstWhere(
          (b) => b.type == 'total',
        );
        expect(totalAfter.properties['keepTogether'], isTrue);
        expect(totalAfter.properties['align'], 'right');

        // GridPosition survived intact.
        expect(totalAfter.gridPosition.w, greaterThan(0));
        expect(totalAfter.gridPosition.h, greaterThan(0));

        // DocumentSettings round-tripped including the Phase 9c/9d flags.
        expect(fresh.template.documentSettings?.pageSize, 'Letter');
        expect(fresh.template.documentSettings?.embedDocuments, isTrue);
        expect(fresh.template.documentSettings?.hideEmptyColumns, isTrue);
      },
    );
  });

  group('a new design', () {
    Design starter() => Design(
      id: '',
      name: '',
      isCustom: true,
      isActive: true,
      isTemplate: false,
      isFree: false,
      entities: const [],
      template: DesignTemplate(
        blocks: [_specByType('logo').newInstance(idPrefix: 'logo', x: 0, y: 0)],
      ),
      updatedAt: DateTime.utc(2000),
      createdAt: DateTime.utc(2000),
      archivedAt: null,
      isDeleted: false,
    );

    test('a starter is the baseline, not an unsaved edit', () {
      final vm = WysiwygDesignViewModel(
        repo: repo,
        companyId: companyId,
        seed: starter(),
        defaultName: 'Visual design',
      );
      expect(vm.blocks, hasLength(1));
      expect(vm.draft.name, 'Visual design');
      expect(vm.isDirty, isFalse, reason: 'leaving must not ask to discard');
      expect(vm.hasUnsavedWork, isTrue, reason: 'but it is worth saving');
      expect(vm.canUndo, isFalse);
    });

    test('applies to every document type by default', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      expect(vm.draft.entities, [
        'invoice',
        'quote',
        'credit',
        'purchase_order',
      ]);
    });

    test('the last document type cannot be unticked', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      for (final e in ['quote', 'credit', 'purchase_order']) {
        vm.toggleEntity(e);
      }
      expect(vm.draft.entities, ['invoice']);
      vm.toggleEntity('invoice');
      expect(vm.draft.entities, ['invoice']);
      vm.toggleEntity('credit');
      expect(vm.draft.entities, ['invoice', 'credit']);
    });

    test(
      'a second save updates the design instead of creating it twice',
      () async {
        final vm = WysiwygDesignViewModel(
          repo: repo,
          companyId: companyId,
          seed: starter(),
          defaultName: 'Visual design',
        );
        final first = await vm.save();
        expect(first, isNotNull);
        expect(vm.hasUnsavedWork, isFalse);

        vm.setName('Renamed');
        expect(vm.hasUnsavedWork, isTrue);
        final second = await vm.save();
        expect(second!.id, first!.id);

        final rows = await db.select(db.designs).get();
        expect(rows, hasLength(1), reason: 'one record, not two');
        expect(rows.single.name, 'Renamed');
        final kinds = [
          for (final row in await db.select(db.outbox).get()) row.mutationKind,
        ];
        expect(kinds.where((k) => k == 'create'), hasLength(1));
      },
    );
  });

  group('undo keeps what was done apart', () {
    WysiwygDesignViewModel withTable() {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('table'));
      return vm;
    }

    List<Map<String, dynamic>> columns(WysiwygDesignViewModel vm) => [
      for (final c in vm.blocks.single.properties['columns'] as List)
        Map<String, dynamic>.from(c as Map),
    ];

    void setColumns(WysiwygDesignViewModel vm, List<Map<String, dynamic>> c) =>
        vm.updateBlock(
          vm.blocks.single.copyWith(
            properties: {...vm.blocks.single.properties, 'columns': c},
          ),
        );

    test('two headers, a width and a deleted column are four steps', () {
      // They are all "the columns property": keyed on that alone, one ⌘Z
      // after deleting the wrong column threw the renames away with it.
      final vm = withTable();
      final original = columns(vm);

      var c = columns(vm)..[0]['header'] = 'Code';
      setColumns(vm, c);
      c = columns(vm)..[1]['header'] = 'What';
      setColumns(vm, c);
      c = columns(vm)..[1]['width'] = '40%';
      setColumns(vm, c);
      c = columns(vm)..removeAt(2);
      setColumns(vm, c);
      expect(columns(vm), hasLength(original.length - 1));

      vm.undo(); // the delete, and only it
      expect(columns(vm), hasLength(original.length));
      expect(columns(vm)[0]['header'], 'Code');
      expect(columns(vm)[1]['header'], 'What');
      expect(columns(vm)[1]['width'], '40%');

      vm.undo(); // the width
      expect(columns(vm)[1]['width'], original[1]['width']);
      expect(columns(vm)[1]['header'], 'What');
      vm.undo();
      vm.undo();
      expect(columns(vm), original);
    });

    test('typing in one cell is still one step', () {
      final vm = withTable();
      final before = columns(vm)[0]['header'];
      for (final text in ['C', 'Co', 'Cod', 'Code']) {
        setColumns(vm, columns(vm)..[0]['header'] = text);
      }
      vm.undo();
      expect(columns(vm)[0]['header'], before);
    });
  });

  group('a drag that is never finished', () {
    WysiwygDesignViewModel twoHalves() {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('text'));
      final first = vm.selectedBlockId!;
      vm.insertBeside(_specByType('text'), first, before: false);
      return vm;
    }

    test('does not swallow the undo steps that follow it', () {
      final vm = twoHalves();
      vm.beginGesture();
      vm.dragBoundary(0, 1, 2);
      // The handle is unmounted (Esc deselects) and reports no end.
      vm.selectBlock(null);

      final depthBefore = vm.canUndo;
      vm.addBlock(_specByType('divider'));
      vm.undo();
      expect([for (final b in vm.blocks) b.type], ['text', 'text']);
      expect(depthBefore, isTrue);
    });

    test('is not what the next drag replays from', () {
      final vm = twoHalves();
      vm.beginGesture();
      vm.dragBoundary(0, 1, 2); // 8 | 4, and never ended
      vm.addBlock(_specByType('divider')); // work done since

      vm.beginGesture();
      vm.dragBoundary(0, 1, -1);
      vm.endGesture();
      // Replayed from the stale start, the divider was gone.
      expect([for (final b in vm.blocks) b.type], ['text', 'text', 'divider']);
      expect(shape(vm).first, 'text:7 text:5');
    });

    test('a press that moves nothing costs neither undo nor redo', () {
      final vm = twoHalves();
      vm.undo();
      expect(vm.canRedo, isTrue);
      final undoable = vm.canUndo;

      vm.beginGesture();
      vm.dragBoundary(0, 1, 0);
      vm.endGesture();
      expect(vm.canRedo, isTrue, reason: 'redo used to be wiped by the press');
      expect(vm.canUndo, undoable);
    });

    test('a no-op drag on blocks stored out of order changes nothing', () {
      // The server's own fixture is such a design. Committing the unchanged
      // rows re-sorted them: a do-nothing undo step, and a dirty design.
      final a = _specByType('text').newInstance(idPrefix: 'a', x: 0, y: 4);
      final b = _specByType('logo').newInstance(idPrefix: 'b', x: 0, y: 0);
      final vm = WysiwygDesignViewModel(
        repo: repo,
        companyId: companyId,
        seed: Design(
          id: '',
          name: 'x',
          isCustom: true,
          isActive: true,
          isTemplate: false,
          isFree: false,
          entities: const ['invoice'],
          template: DesignTemplate(blocks: [a, b]),
          updatedAt: DateTime.utc(2000),
          createdAt: DateTime.utc(2000),
          archivedAt: null,
          isDeleted: false,
        ),
      );
      final before = vm.draft.template;
      vm.beginGesture();
      vm.dragBoundary(0, 1, 3); // a full-width block has nothing to its right
      vm.endGesture();
      expect(vm.draft.template, before);
      expect(vm.canUndo, isFalse);
      expect(vm.isDirty, isFalse);
    });
  });

  group('what replaces the template tells the panel', () {
    test('undo, redo, an import and a new layout each bump the epoch', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('text'));
      var epoch = vm.templateEpoch;
      void bumped(String what) {
        expect(vm.templateEpoch, greaterThan(epoch), reason: what);
        epoch = vm.templateEpoch;
      }

      vm.undo();
      bumped('undo');
      vm.redo();
      bumped('redo');
      vm.replaceLayout(const []);
      bumped('replace layout');
      expect(vm.importFromJson('{"blocks": []}'), isNull);
      bumped('import');
      // An ordinary edit does not: the editor that made it is up to date.
      vm.addBlock(_specByType('text'));
      expect(vm.templateEpoch, epoch);
    });
  });

  group('import is of a design', () {
    test('an object that is not one is refused, and the page is kept', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      vm.addBlock(_specByType('text'));
      expect(
        vm.importFromJson('{"name": "x", "entities": "invoice"}'),
        'invalid_json',
      );
      expect(vm.blocks, hasLength(1));
      expect(vm.draft.template.extra, isEmpty);
    });

    test('blocks with no id, or a repeated one, are told apart', () {
      final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
      final err = vm.importFromJson(
        jsonEncode({
          'blocks': [
            {
              'type': 'text',
              'gridPosition': {'x': 0, 'y': 0, 'w': 12, 'h': 1},
            },
            {
              'type': 'text',
              'gridPosition': {'x': 0, 'y': 1, 'w': 12, 'h': 1},
            },
            {
              'id': 'd',
              'type': 'divider',
              'gridPosition': {'x': 0, 'y': 2, 'w': 12, 'h': 1},
            },
            {
              'id': 'd',
              'type': 'divider',
              'gridPosition': {'x': 0, 'y': 3, 'w': 12, 'h': 1},
            },
          ],
        }),
      );
      expect(err, isNull);
      final ids = {for (final b in vm.blocks) b.id};
      expect(ids, hasLength(4));
      expect(ids.contains(''), isFalse);
    });
  });

  test('ticking a type keeps one the control does not offer', () {
    final vm = WysiwygDesignViewModel(repo: repo, companyId: companyId);
    vm.setEntities(const ['invoice', 'statement']);
    vm.toggleEntity('quote');
    expect(vm.draft.entities, ['invoice', 'quote', 'statement']);
  });
}
