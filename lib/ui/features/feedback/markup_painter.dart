import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:admin/domain/feedback/markup.dart';

/// Draws [marks] — given in image pixels — onto [canvas] at [scale] canvas
/// units per image pixel. The editor, the attachment thumbnails and the image
/// that is finally sent all go through this one function, so what the user
/// sees is what gets sent (docs/feedback-screenshots.md).
void paintMarks(
  Canvas canvas,
  List<MarkupMark> marks, {
  required double scale,
  required Color color,
}) {
  for (final mark in marks) {
    switch (mark) {
      case PenStroke(:final points, :final width):
        if (points.isEmpty) continue;
        final paint = Paint()
          ..color = color
          ..strokeWidth = width * scale
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke
          ..isAntiAlias = true;
        if (points.length == 1) {
          canvas.drawCircle(
            Offset(points.first.x * scale, points.first.y * scale),
            width * scale / 2,
            paint..style = PaintingStyle.fill,
          );
          continue;
        }
        final path = Path()
          ..moveTo(points.first.x * scale, points.first.y * scale);
        for (final p in points.skip(1)) {
          path.lineTo(p.x * scale, p.y * scale);
        }
        canvas.drawPath(path, paint);
      case BoxMark(:final rect, :final width):
        canvas.drawRect(
          _scaled(rect, scale),
          Paint()
            ..color = color
            ..strokeWidth = width * scale
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.miter,
        );
      case RedactMark(:final rect):
        // Opaque, never anti-aliased into what is under it.
        canvas.drawRect(
          _scaled(rect, scale),
          Paint()
            ..color = const Color(0xFF000000)
            ..isAntiAlias = false,
        );
    }
  }
}

Rect _scaled(MarkRect r, double scale) => Rect.fromLTRB(
  r.left * scale,
  r.top * scale,
  r.right * scale,
  r.bottom * scale,
);

/// The scale that fits an [imageSize] image inside [box], and where it sits.
({double scale, Offset origin}) fitImage(Size imageSize, Size box) {
  if (imageSize.isEmpty || box.isEmpty) {
    return (scale: 1, origin: Offset.zero);
  }
  final scale = math.min(
    box.width / imageSize.width,
    box.height / imageSize.height,
  );
  final drawn = imageSize * scale;
  return (
    scale: scale,
    origin: Offset(
      (box.width - drawn.width) / 2,
      (box.height - drawn.height) / 2,
    ),
  );
}

/// An image with its marks, fitted (contain) into the paint box. Used by the
/// editor canvas and the attachment thumbnails.
class MarkedImagePainter extends CustomPainter {
  MarkedImagePainter({
    required this.image,
    required this.marks,
    required this.color,
    this.inProgress,
  });

  final ui.Image image;
  final List<MarkupMark> marks;
  final Color color;

  /// The mark being drawn right now, painted on top of [marks].
  final MarkupMark? inProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final fit = fitImage(imageSize, size);
    canvas.save();
    canvas.translate(fit.origin.dx, fit.origin.dy);
    canvas.drawImageRect(
      image,
      Offset.zero & imageSize,
      Offset.zero & (imageSize * fit.scale),
      Paint()..filterQuality = FilterQuality.medium,
    );
    paintMarks(canvas, [...marks, ?inProgress], scale: fit.scale, color: color);
    canvas.restore();
  }

  @override
  bool shouldRepaint(MarkedImagePainter old) =>
      old.image != image ||
      old.marks != marks ||
      old.inProgress != inProgress ||
      old.color != color;
}

/// [image] with [marks] painted in, at [scale] times its size. The caller
/// disposes the result.
Future<ui.Image> flattenMarkedImage(
  ui.Image image,
  List<MarkupMark> marks, {
  required Color color,
  double scale = 1,
}) {
  final width = math.max(1, (image.width * scale).round());
  final height = math.max(1, (image.height * scale).round());
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    image,
    Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..filterQuality = FilterQuality.high,
  );
  paintMarks(canvas, marks, scale: width / image.width, color: color);
  final picture = recorder.endRecording();
  return picture.toImage(width, height).whenComplete(picture.dispose);
}

/// [image] with [marks] as PNG bytes no heavier than [maxBytes], or null when
/// even the smallest allowed size is too heavy.
///
/// PNG only, from the engine: `toByteData(format: png)` encodes off the UI
/// thread on native and through the browser's async encoder on the web. The
/// engine has no JPEG encoder, and `package:image`'s would run on the UI
/// thread on the web (`compute` is inline there) and freeze the dialog. So an
/// image over budget is re-rendered smaller instead ([feedbackRenderScales]).
Future<Uint8List?> encodeMarkedImage(
  ui.Image image,
  List<MarkupMark> marks, {
  required Color color,
  int maxBytes = kFeedbackMaxImageBytes,
}) async {
  final longest = math.max(image.width, image.height).toDouble();
  for (final scale in feedbackRenderScales(longest)) {
    final flat = await flattenMarkedImage(
      image,
      marks,
      color: color,
      scale: scale,
    );
    try {
      final data = await flat.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) continue;
      if (data.lengthInBytes <= maxBytes) return data.buffer.asUint8List();
    } finally {
      flat.dispose();
    }
  }
  return null;
}
