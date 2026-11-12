// The Contact Us screen capture waits for what the caller closed, never for
// "no animations", and never hangs or throws (docs/feedback-screenshots.md).

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/feedback/screen_capture.dart';

void main() {
  final key = GlobalKey();

  /// The boundary with a spinner inside — an animation that never ends, the
  /// way a running task timer's pulse never does.
  Future<void> pumpBoundary(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: const ColoredBox(
          color: Colors.white,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    ),
  );

  testWidgets('no boundary: null at once', (tester) async {
    final image = await captureAppScreen(
      boundaryKey: GlobalKey(),
      devicePixelRatio: 2,
    );
    expect(image, isNull);
  });

  testWidgets('waits for the closing route, then captures — a spinner '
      'running does not hold it up', (tester) async {
    await pumpBoundary(tester);
    final closing = Completer<void>();
    var finished = false;
    final capture = captureAppScreen(
      boundaryKey: key,
      devicePixelRatio: 1,
      afterClosing: closing.future,
    );
    unawaited(capture.then((_) => finished = true));

    await tester.pump(const Duration(milliseconds: 100));
    expect(finished, isFalse, reason: 'the route has not finished closing');

    closing.complete();
    await tester.pump();
    await tester.pump();
    final image = await tester.runAsync<ui.Image?>(() => capture);
    expect(image, isNotNull);
    expect(image!.width, 800);
    image.dispose();
  });

  testWidgets('a closing route that never completes gives up — no capture, '
      'no hang', (tester) async {
    await pumpBoundary(tester);
    ui.Image? image;
    var finished = false;
    unawaited(
      captureAppScreen(
        boundaryKey: key,
        devicePixelRatio: 1,
        afterClosing: Completer<void>().future,
      ).then((i) {
        image = i;
        finished = true;
      }),
    );
    await tester.pump(kCaptureTimeout + const Duration(milliseconds: 50));
    expect(finished, isTrue);
    expect(image, isNull);
  });
}
