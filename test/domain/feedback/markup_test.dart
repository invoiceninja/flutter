// The marks on a Contact Us image and the size rules images are sent under
// (docs/feedback-screenshots.md).

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/feedback/markup.dart';

void main() {
  const a = MarkPoint(10, 20);
  const b = MarkPoint(30, 5);
  final box = BoxMark(MarkRect.fromPoints(a, b), width: 3);
  final redact = RedactMark(MarkRect.fromPoints(a, b));

  group('MarkRect', () {
    test('is normalized whichever way it was dragged', () {
      final r = MarkRect.fromPoints(b, a);
      expect([r.left, r.top, r.right, r.bottom], [10, 5, 30, 20]);
      expect(r, MarkRect.fromPoints(a, b));
      expect(r.width, 20);
      expect(r.height, 15);
    });
  });

  group('MarkupHistory', () {
    test('undo takes back the last mark', () {
      final h = MarkupHistory()
        ..add(box)
        ..add(redact);
      expect(h.marks, [box, redact]);
      h.undo();
      expect(h.marks, [box]);
      h.undo();
      expect(h.marks, isEmpty);
      expect(h.canUndo, isFalse);
    });

    test('Clear is one step undo brings back', () {
      final h = MarkupHistory([box])..add(redact);
      h.clear();
      expect(h.marks, isEmpty);
      h.undo();
      expect(h.marks, [box, redact]);
    });

    test('Clear on nothing adds no step', () {
      final h = MarkupHistory()..clear();
      expect(h.canUndo, isFalse);
    });

    // Reopening the editor seeds the marks it returned last time; they are
    // the starting point, not a change that Undo removes one by one first.
    test('a seeded history has nothing to undo yet', () {
      final h = MarkupHistory([box, redact]);
      expect(h.marks, [box, redact]);
      expect(h.canUndo, isFalse);
    });
  });

  group('feedbackCaptureRatio', () {
    test('keeps the device ratio when the result fits 2560', () {
      expect(
        feedbackCaptureRatio(
          devicePixelRatio: 2,
          logicalWidth: 1280,
          logicalHeight: 800,
        ),
        2,
      );
    });

    // A 5K display: 2560 logical wide at 2x would be 5120 pixels.
    test('caps the longest edge at 2560', () {
      final r = feedbackCaptureRatio(
        devicePixelRatio: 2,
        logicalWidth: 2560,
        logicalHeight: 1440,
      );
      expect(r, 1);
      expect(2560 * r, kFeedbackCaptureMaxEdge);
    });
  });

  group('feedbackRenderScales', () {
    test('full size, then 0.75 steps, never below a 1280 px edge', () {
      expect(feedbackRenderScales(2560), [1, 0.75, 0.5625]);
      expect(feedbackRenderScales(4000), [1, 0.75, 0.5625, 0.421875]);
    });

    test('a small image is only tried at full size', () {
      expect(feedbackRenderScales(1000), [1]);
    });
  });
}
