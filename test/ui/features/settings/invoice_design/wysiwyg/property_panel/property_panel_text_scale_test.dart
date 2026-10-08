import 'dart:io';

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
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_panel.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

import '../../../../../../_localization_helper.dart';

class _FakeDesignsApi implements DesignsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// The panel is 320 wide and every row in it is a name beside a control.
/// Under the test font nothing here means anything — its glyphs are square
/// — so this loads the app's own face and asks the question that matters:
/// does any row overflow when the user has made their text larger?
void main() {
  late AppDatabase db;
  late WysiwygDesignViewModel vm;

  setUpAll(() async {
    for (final (family, path) in [
      (kSansFontFamily, 'assets/fonts/InterTight.ttf'),
      (kMonoFontFamily, 'assets/fonts/JetBrainsMono.ttf'),
    ]) {
      final bytes = File(path).readAsBytesSync();
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    }
  });

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    vm = WysiwygDesignViewModel(
      repo: DesignRepository(db: db, api: _FakeDesignsApi()),
      companyId: 'co1',
      brandColors: const ['#2F7DC3'],
    );
  });

  tearDown(() async {
    vm.dispose();
    await db.close();
  });

  Future<void> pumpPanel(WidgetTester tester, double scale) async {
    tester.view.physicalSize = const Size(kDesignerPanelWidth, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: ListenableBuilder(
            listenable: vm,
            builder: (_, _) => PropertyPanel(vm: vm),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final scale in [1.0, 1.4]) {
    testWidgets('the page tab fits at ${scale}x', (tester) async {
      await pumpPanel(tester, scale);
      expect(tester.takeException(), isNull);
    });

    for (final spec in kBlockLibrary) {
      testWidgets('${spec.type} fits at ${scale}x', (tester) async {
        vm.addBlock(spec);
        await pumpPanel(tester, scale);
        expect(tester.takeException(), isNull, reason: spec.type);

        // And with every collapsed row and group open.
        for (final icon in [Icons.expand_more, Icons.chevron_right]) {
          for (var i = 0; i < 12; i++) {
            final closed = find.byIcon(icon);
            if (closed.evaluate().isEmpty) break;
            await tester.ensureVisible(closed.first);
            await tester.tap(closed.first, warnIfMissed: false);
            await tester.pump();
            expect(
              tester.takeException(),
              isNull,
              reason: '${spec.type}, a row opened',
            );
          }
        }
      });
    }
  }
}
