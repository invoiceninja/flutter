import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/wysiwyg_canvas.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/text_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

import '../../../../../_localization_helper.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The workspace's `Shortcuts` sit between the property panel's fields and
/// Flutter's own text-editing shortcuts. Unguarded, they won: an arrow key
/// typed in a field moved the selected block and left the caret where it was,
/// and ⌘Z undid a canvas change instead of the typing.
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

  Future<void> pumpWorkspace(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        home: Scaffold(body: DesignerWorkspace(vm: vm, isPro: true)),
      ),
    );
    await tester.pump();
  }

  Finder contentField() => find.descendant(
    of: find.byType(TextBlockProperties),
    matching: find.byType(TextField),
  );

  /// A logo above a text block, the text block selected.
  String twoBlocks() {
    vm.addBlock(blockSpecFor('logo')!);
    vm.addBlock(blockSpecFor('text')!);
    return vm.selectedBlockId!;
  }

  testWidgets('arrow keys in a property field move the caret, nothing else', (
    tester,
  ) async {
    final text = twoBlocks();
    await pumpWorkspace(tester);
    final before = vm.blocks;

    await tester.tap(contentField().first);
    await tester.pump();
    await tester.enterText(contentField().first, 'abc');
    final controller = tester
        .widget<TextField>(contentField().first)
        .controller!;
    expect(controller.selection.baseOffset, 3);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(controller.selection.baseOffset, 2, reason: 'the caret moved');

    // On the canvas ↑ would select the logo, and Backspace delete the block.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump(const Duration(milliseconds: 400));
    expect(vm.selectedBlockId, text, reason: 'the selection did not');
    expect(vm.blocks.map((b) => b.id), before.map((b) => b.id));
  });

  testWidgets('⌘Z in a property field does not undo a canvas change', (
    tester,
  ) async {
    twoBlocks();
    await pumpWorkspace(tester);
    await tester.tap(contentField().first);
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(vm.blocks, hasLength(2), reason: 'the add was not undone');
  });

  testWidgets('with the canvas pressed, the keys act on the page', (
    tester,
  ) async {
    final text = twoBlocks();
    await pumpWorkspace(tester);
    final logo = vm.blocks.first.id;
    // Type in the field first: focus is then in the panel.
    await tester.tap(contentField().first);
    await tester.pump();

    // A press on the canvas takes focus back for the workspace.
    await tester.tapAt(
      tester.getTopLeft(find.byType(WysiwygCanvas)) + const Offset(4, 4),
    );
    await tester.pump();
    vm.selectBlock(text);
    await tester.pump();

    // A bare arrow moves the selection, never the block.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(vm.selectedBlockId, logo);
    expect(vm.blocks.first.id, logo);

    // Alt + arrow moves the block.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(vm.blocks.first.id, text);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(vm.blocks.first.id, logo, reason: 'the move was undone');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(vm.selectedBlockId, isNull);
  });

  group('a key that belongs to another control', () {
    /// Whether keyboard focus is on (inside) a widget of [type].
    bool focusIsOn(Type type) {
      final context = FocusManager.instance.primaryFocus?.context;
      if (context == null) return false;
      var found = context.widget.runtimeType == type;
      context.visitAncestorElements((e) {
        if (e.widget.runtimeType == type) found = true;
        return !found;
      });
      return found;
    }

    /// Tab until focus reaches a widget of [type].
    Future<void> tabTo(WidgetTester tester, Type type) async {
      for (var i = 0; i < 120 && !focusIsOn(type); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(focusIsOn(type), isTrue, reason: 'Tab never reached a $type');
    }

    testWidgets('Backspace on a focused control deletes nothing', (
      tester,
    ) async {
      final text = twoBlocks();
      await pumpWorkspace(tester);
      await tabTo(tester, DropdownButton<String>);

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pump();
      expect(vm.blocks, hasLength(2), reason: 'it deleted the selected block');

      // …nor does Esc drop the selection.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(vm.selectedBlockId, text);
      await tester.pump(const Duration(seconds: 15));
    });

    testWidgets('Enter on a focused dropdown opens the dropdown', (
      tester,
    ) async {
      twoBlocks();
      await pumpWorkspace(tester);
      await tabTo(tester, DropdownButton<String>);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);

      // The workspace used to take Enter for "edit the content".
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(navigator.canPop(), isTrue, reason: 'its menu is a route');

      navigator.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    testWidgets('⌘Z still undoes from there', (tester) async {
      twoBlocks();
      await pumpWorkspace(tester);
      await tabTo(tester, DropdownButton<String>);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(vm.blocks, hasLength(1));
    });
  });

  testWidgets('Alt+←/→ is left for the app; Alt+Shift moves along the row', (
    tester,
  ) async {
    vm.addBlock(blockSpecFor('text')!);
    final first = vm.selectedBlockId!;
    vm.insertBeside(blockSpecFor('logo')!, first, before: false);
    vm.selectBlock(first);
    await pumpWorkspace(tester);
    await tester.tapAt(
      tester.getTopLeft(find.byType(WysiwygCanvas)) + const Offset(4, 4),
    );
    await tester.pump();
    vm.selectBlock(first);
    await tester.pump();
    List<String> order() => [for (final b in vm.blocks) b.type];
    expect(order(), ['text', 'logo']);

    // Back / Forward in the shell: not this map's to take.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    final taken = await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(order(), ['text', 'logo']);
    expect(taken, isFalse, reason: 'the workspace consumed Alt+→');

    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pump();
    expect(order(), ['logo', 'text']);
  });

  testWidgets('in Preview the page keys do nothing', (tester) async {
    twoBlocks();
    final chrome = DesignerChrome();
    addTearDown(chrome.dispose);
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: DesignerWorkspace(
            vm: vm,
            isPro: true,
            chrome: chrome,
            previewBuilder: (_) => const Center(child: Text('the preview')),
          ),
        ),
      ),
    );
    await tester.pump();
    chrome.preview = true;
    await tester.pump();
    expect(find.text('the preview'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(vm.blocks, hasLength(2), reason: 'a block nobody can see was cut');
    await tester.pump(const Duration(seconds: 15));
  });
}
