// What is drawn is what is sent: the export goes through the same painter as
// the editor, and a redact leaves nothing of what it covers
// (docs/feedback-screenshots.md).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/feedback/markup.dart';
import 'package:admin/ui/features/feedback/markup_painter.dart';

const _red = Color(0xFFE5241B);

/// A [width] x [height] image filled with white.
Future<ui.Image> _white(int width, int height) {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  return recorder.endRecording().toImage(width, height);
}

Future<Uint8List> _rgba(ui.Image image) async => (await image.toByteData(
  format: ui.ImageByteFormat.rawRgba,
))!.buffer.asUint8List();

/// The RGBA of pixel (x, y).
List<int> _pixel(Uint8List rgba, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return rgba.sublist(i, i + 4);
}

void main() {
  testWidgets('a redact is solid black in the flattened image', (tester) async {
    await tester.runAsync(() async {
      final src = await _white(40, 30);
      final flat = await flattenMarkedImage(src, [
        RedactMark(
          MarkRect.fromPoints(const MarkPoint(10, 5), const MarkPoint(30, 25)),
        ),
      ], color: _red);
      final rgba = await _rgba(flat);
      expect(flat.width, 40);
      expect(flat.height, 30);
      for (final (x, y) in [(10, 5), (20, 15), (29, 24)]) {
        expect(_pixel(rgba, 40, x, y), [0, 0, 0, 255], reason: '($x, $y)');
      }
      expect(_pixel(rgba, 40, 2, 2), [255, 255, 255, 255]);
      src.dispose();
      flat.dispose();
    });
  });

  testWidgets('a box is drawn in the mark colour, in image pixels at any '
      'export scale', (tester) async {
    await tester.runAsync(() async {
      final src = await _white(40, 40);
      final flat = await flattenMarkedImage(
        src,
        [
          BoxMark(
            MarkRect.fromPoints(const MarkPoint(8, 8), const MarkPoint(32, 32)),
            width: 4,
          ),
        ],
        color: _red,
        scale: 0.5,
      );
      final rgba = await _rgba(flat);
      expect(flat.width, 20);
      // The box's left edge sits at image x = 8, i.e. x = 4 at half size.
      final edge = _pixel(rgba, 20, 4, 10);
      expect(edge[0], greaterThan(200));
      expect(edge[1], lessThan(80));
      expect(_pixel(rgba, 20, 10, 10), [255, 255, 255, 255]);
      src.dispose();
      flat.dispose();
    });
  });

  testWidgets('encodeMarkedImage returns a PNG within the budget', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final src = await _white(64, 48);
      final png = await encodeMarkedImage(src, const [], color: _red);
      expect(png, isNotNull);
      expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      expect(png.length, lessThanOrEqualTo(kFeedbackMaxImageBytes));
      src.dispose();
    });
  });

  testWidgets('encodeMarkedImage refuses what no allowed size can fit', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final src = await _white(64, 48);
      expect(
        await encodeMarkedImage(src, const [], color: _red, maxBytes: 10),
        isNull,
      );
      src.dispose();
    });
  });

  test('fitImage centres a contained image', () {
    final fit = fitImage(const Size(200, 100), const Size(100, 100));
    expect(fit.scale, 0.5);
    expect(fit.origin, const Offset(0, 25));
  });
}
