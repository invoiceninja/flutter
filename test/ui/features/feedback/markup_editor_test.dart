// The markup editor: a drag makes a mark, Done hands back marks (never a
// flattened image), ⌘Z undoes, and leaving with new marks asks first
// (docs/feedback-screenshots.md).

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/domain/feedback/markup.dart';
import 'package:admin/ui/features/feedback/markup_editor.dart';
import 'package:admin/ui/features/feedback/markup_painter.dart';

import '../../../_localization_helper.dart';

void main() {
  late ui.Image image;
  List<MarkupMark>? result;
  var closed = false;

  Future<void> open(
    WidgetTester tester, {
    List<MarkupMark> marks = const [],
    Size surface = const Size(1280, 900),
  }) async {
    image = (await tester.runAsync(
      () => createTestImage(width: 400, height: 300),
    ))!;
    result = null;
    closed = false;
    await tester.binding.setSurfaceSize(surface);
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showMarkupEditor(
                context,
                image: image,
                marks: marks,
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder canvas() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is MarkedImagePainter,
  );

  Future<void> drag(WidgetTester tester, Offset by) async {
    final start = tester.getCenter(canvas()) - by / 2;
    final g = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    await g.moveTo(start + by / 2);
    await g.moveTo(start + by);
    await g.up();
    await tester.pump();
  }

  testWidgets('a drag makes a box; Done returns it', (tester) async {
    await open(tester);
    await drag(tester, const Offset(120, 80));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    final mark = result!.single as BoxMark;
    // In image pixels, inside the 400 x 300 image whatever the zoom.
    expect(mark.rect.left, greaterThanOrEqualTo(0));
    expect(mark.rect.right, lessThanOrEqualTo(400));
    expect(mark.rect.width, greaterThan(0));
  });

  testWidgets('a stray click makes no mark', (tester) async {
    await open(tester);
    await drag(tester, const Offset(2, 1));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, isEmpty);
  });

  testWidgets('the Redact tool makes a redact mark', (tester) async {
    await open(tester);
    await tester.tap(find.text('Redact'));
    await tester.pump();
    await drag(tester, const Offset(100, 60));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result!.single, isA<RedactMark>());
  });

  testWidgets('⌘Z undoes the last mark', (tester) async {
    await open(tester);
    await drag(tester, const Offset(120, 80));
    await drag(tester, const Offset(60, 90));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, hasLength(1));
  });

  testWidgets('Cancel with new marks asks before discarding them', (
    tester,
  ) async {
    await open(tester);
    await drag(tester, const Offset(120, 80));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.text('Discard'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('Cancel with nothing new just closes', (tester) async {
    final seeded = BoxMark(
      MarkRect.fromPoints(const MarkPoint(1, 1), const MarkPoint(9, 9)),
      width: 2,
    );
    await open(tester, marks: [seeded]);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });

  testWidgets('reopened, the earlier marks are kept and can be cleared', (
    tester,
  ) async {
    final seeded = BoxMark(
      MarkRect.fromPoints(const MarkPoint(1, 1), const MarkPoint(9, 9)),
      width: 2,
    );
    await open(tester, marks: [seeded]);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, isEmpty);
  });

  // A phone gets the full-screen editor: Close and Done in the app bar, the
  // tools at the bottom (the test platform is Android, so touch-primary).
  testWidgets('a phone gets the full-screen editor, and it lays out', (
    tester,
  ) async {
    await open(tester, surface: const Size(390, 844));
    expect(tester.takeException(), isNull);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.byTooltip('Cancel'), findsOneWidget);
    await drag(tester, const Offset(120, 80));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(result, hasLength(1));
  });
}
