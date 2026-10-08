import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/repositories/design_repository.dart';
import 'package:admin/data/services/designs_api.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_editors/text_block_properties.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_panel.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_screen.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

import '../../../../../../_localization_helper.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Undo covers property edits. The editors hold text of their own, seeded
/// when a block is selected — so after an undo they went on showing the
/// undone text, and the next keystroke wrote it back.
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

  Future<void> pumpPanel(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
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
            title: ListenableBuilder(
              listenable: vm,
              builder: (_, _) => DesignNameField(vm: vm),
            ),
          ),
          body: ListenableBuilder(
            listenable: vm,
            builder: (_, _) => PropertyPanel(vm: vm),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Finder contentField() => find.descendant(
    of: find.byType(TextBlockProperties),
    matching: find.byType(TextField),
  );

  String shown(WidgetTester tester) =>
      tester.widget<TextField>(contentField().first).controller!.text;

  String? stored() => vm.blocks.single.properties['content'] as String?;

  testWidgets('after an undo the Content field shows what was restored', (
    tester,
  ) async {
    vm.addBlock(blockSpecFor('text')!);
    await pumpPanel(tester);
    await tester.enterText(contentField().first, 'Hello');
    await tester.pump(const Duration(milliseconds: 400)); // the debounce
    expect(stored(), 'Hello');

    vm.undo();
    await tester.pump();
    expect(stored() ?? '', '');
    expect(shown(tester), '', reason: 'the field went on saying "Hello"');

    vm.redo();
    await tester.pump();
    expect(shown(tester), 'Hello');
  });

  testWidgets('an undo straight after typing undoes the typing', (
    tester,
  ) async {
    vm.addBlock(blockSpecFor('text')!);
    await pumpPanel(tester);
    await tester.enterText(contentField().first, 'Hi');
    await tester.pump(const Duration(milliseconds: 50)); // still debouncing
    expect(stored() ?? '', '');

    // The pending write is committed first, *then* undone — not left to land
    // on top of the restored state when the editor is rebuilt.
    vm.undo();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(stored() ?? '', '');
    expect(shown(tester), '');
    vm.redo();
    await tester.pump();
    expect(stored(), 'Hi');
  });

  testWidgets('what is typed is on the draft as soon as something asks', (
    tester,
  ) async {
    // ⌘S inside the debounce found nothing to save.
    vm.addBlock(blockSpecFor('text')!);
    await pumpPanel(tester);
    await tester.enterText(contentField().first, 'Now');
    await tester.pump(const Duration(milliseconds: 50));
    vm.flushPendingEdits();
    expect(stored(), 'Now');
  });

  testWidgets('the name field follows a name changed underneath it', (
    tester,
  ) async {
    vm.setName('First');
    await pumpPanel(tester);
    final field = find.descendant(
      of: find.byType(DesignNameField),
      matching: find.byType(TextField),
    );
    String name() => tester.widget<TextField>(field).controller!.text;
    expect(name(), 'First');

    // Typing is the field's own doing: the caret is left alone.
    await tester.enterText(field, 'Typed');
    await tester.pump();
    expect(vm.draft.name, 'Typed');

    // A Discard puts the draft back; the field used to keep "Typed" over a
    // Save disabled for want of a name.
    vm.resetToEmpty();
    await tester.pump();
    expect(name(), vm.draft.name);
  });
}
