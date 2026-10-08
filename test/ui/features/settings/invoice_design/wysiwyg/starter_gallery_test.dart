import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/design_page_thumbnail.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/starter_gallery.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/templates.dart';

import '../../../../../_localization_helper.dart';

void main() {
  group('starterGalleryColumns', () {
    test('as many as fit, and never one card alone on the last line', () {
      // Five cards: all in a row when there is room…
      expect(starterGalleryColumns(888, 5), 5);
      // …and three then two where four would leave one behind.
      expect(starterGalleryColumns(708, 5), 3);
      expect(starterGalleryColumns(520, 5), 3);
      // A phone gets two across; an orphan there cannot be helped.
      expect(starterGalleryColumns(278, 5), 2);
      expect(starterGalleryColumns(100, 5), 2);
      // Never more columns than cards.
      expect(starterGalleryColumns(2000, 3), 3);
    });
  });

  Future<List<DesignBlock>? Function()> open(
    WidgetTester tester, {
    Size size = const Size(1200, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    List<DesignBlock>? result;
    var returned = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.light),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showStarterGallery(context, accent: '#2F7DC3');
                returned = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => returned ? result : throw StateError('still open');
  }

  testWidgets('Blank and every starter, each drawn as the page it makes', (
    tester,
  ) async {
    await open(tester);
    expect(tester.takeException(), isNull);
    final names = ['Blank', 'Standard', 'Bold', 'Minimal', 'Quote-friendly'];
    for (final name in names) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.byType(DesignPageThumbnail), findsNWidgets(names.length));
    // One row of five at this width, ending level.
    final tops = {
      for (final n in names) tester.getTopLeft(find.text(n)).dy.round(),
    };
    expect(tops, hasLength(1));
  });

  testWidgets('picking a starter returns its blocks', (tester) async {
    final result = await open(tester);
    await tester.tap(find.text('Bold'));
    await tester.pumpAndSettle();
    final blocks = result()!;
    expect(
      blocks.map((b) => b.type),
      buildStarterTemplates()
          .firstWhere((s) => s.id == 'bold')
          .blocks
          .map((b) => b.type),
    );
    // In the company's colour.
    expect(
      blocks.firstWhere((b) => b.type == 'table').properties['headerBg'],
      '#2F7DC3',
    );
  });

  testWidgets('Blank returns an empty page — which is not "dismissed"', (
    tester,
  ) async {
    final result = await open(tester);
    await tester.tap(find.text('Blank'));
    await tester.pumpAndSettle();
    expect(result(), isEmpty);
  });

  testWidgets('closing it returns nothing', (tester) async {
    final result = await open(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(result(), isNull);
  });

  testWidgets('fits a phone without overflowing', (tester) async {
    await open(tester, size: const Size(390, 844));
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Quote-friendly'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a thumbnail draws any layout, a row with a gap included', (
    tester,
  ) async {
    DesignBlock block(String type, int x, int y, int w) => DesignBlock(
      id: '$type-$x-$y',
      type: type,
      gridPosition: GridPosition(x: x, y: y, w: w, h: 2),
      properties: const {'content': 'Hello'},
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        locale: const Locale('en'),
        theme: buildInTheme(InTheme.dark),
        home: Scaffold(
          body: SizedBox(
            width: 160,
            child: DesignPageThumbnail(
              blocks: [
                block('text', 0, 0, 4),
                block('text', 8, 0, 4),
                block('mystery', 0, 2, 12),
              ],
              settings: const DocumentSettings(
                pageSize: 'letter',
                pageLayout: 'landscape',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    // The sheet's own proportions, whatever theme the app is in.
    final size = tester.getSize(find.byType(DesignPageThumbnail));
    expect(size.width, 160);
    expect(size.height, closeTo(160 * 816 / 1056, 0.5));
  });
}
