import 'dart:math' as math;

/// Marks a user draws on an image attached to a Contact Us message, and the
/// size rules those images are sent under (docs/feedback-screenshots.md).
///
/// Pure Dart — no `dart:ui` — so the history and the budgets are unit-tested
/// without a canvas. Every coordinate is in **image pixels**, not screen
/// points: the editor shows the image scaled to fit, the thumbnail smaller
/// still, and the export at full size, and only image space means the same
/// thing in all three.

/// A point in image pixels.
class MarkPoint {
  const MarkPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is MarkPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// An axis-aligned rectangle in image pixels, normalized so left <= right
/// and top <= bottom whichever way it was dragged.
class MarkRect {
  factory MarkRect.fromPoints(MarkPoint a, MarkPoint b) => MarkRect._(
    math.min(a.x, b.x),
    math.min(a.y, b.y),
    math.max(a.x, b.x),
    math.max(a.y, b.y),
  );

  const MarkRect._(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  @override
  bool operator ==(Object other) =>
      other is MarkRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

/// The editor's tools. Box is the default: "this, here" is the commonest
/// thing a support screenshot needs to say.
enum MarkupTool { pen, box, redact }

/// One mark. Drawn in order, so a later mark covers an earlier one — and a
/// redact covers everything under it, in the editor and in the export alike.
sealed class MarkupMark {
  const MarkupMark();
}

/// A freehand line. [width] is in image pixels.
class PenStroke extends MarkupMark {
  const PenStroke(this.points, {required this.width});

  final List<MarkPoint> points;
  final double width;
}

/// A rectangle outline. [width] is the stroke, in image pixels.
class BoxMark extends MarkupMark {
  const BoxMark(this.rect, {required this.width});

  final MarkRect rect;
  final double width;
}

/// A solid black rectangle. Opaque on purpose, never a blur or a tint: what
/// is under it must not survive into the image that is sent.
class RedactMark extends MarkupMark {
  const RedactMark(this.rect);

  final MarkRect rect;
}

/// The marks on one image, with undo. Clear is one undoable step, so it needs
/// no "are you sure".
class MarkupHistory {
  MarkupHistory([List<MarkupMark> initial = const []])
    : _states = [List.unmodifiable(initial)];

  final List<List<MarkupMark>> _states;

  List<MarkupMark> get marks => _states.last;
  bool get canUndo => _states.length > 1;

  void add(MarkupMark mark) => _states.add(List.unmodifiable([...marks, mark]));

  /// Removes every mark — as one step [undo] brings back. A no-op when there
  /// is nothing to clear, so Undo doesn't then "undo" nothing.
  void clear() {
    if (marks.isEmpty) return;
    _states.add(const []);
  }

  void undo() {
    if (canUndo) _states.removeLast();
  }
}

/// A drag shorter than this (in screen points) on the box or redact tool is a
/// stray tap, not a mark.
const double kMinMarkDragPoints = 6;

/// The pen and box stroke widths, in screen points at the editor's fit scale
/// (converted to image pixels when the mark is made, so a mark looks the
/// same on a phone shot and a 5K one).
const double kPenWidthPoints = 4;
const double kBoxWidthPoints = 3;

// ── Size rules ────────────────────────────────────────────────────────────

/// Images per message: the screen capture counts as one while it is there.
const int kFeedbackMaxImages = 3;

/// The most one image may weigh when sent. Under PHP's default
/// `upload_max_filesize` of 2 MB, which a bare-metal self-hosted install
/// still has — the server's own rule is only 10 MB in total.
const int kFeedbackMaxImageBytes = 1900 * 1024;

/// A picked file larger than this is refused before it is decoded at all.
const int kFeedbackMaxSourceBytes = 30 * 1024 * 1024;

/// A picked image with more pixels than this (read from its header) is
/// refused before decoding: on web the browser decodes it at full size first.
const int kFeedbackMaxSourcePixels = 40 * 1000 * 1000;

/// The longest edge a screen capture is taken at.
const double kFeedbackCaptureMaxEdge = 2560;

/// The smallest longest edge an image is shrunk to while fitting
/// [kFeedbackMaxImageBytes]; below it the image is refused, since the text in
/// a screenshot stops being readable.
const double kFeedbackMinEdge = 1280;

/// The pixel ratio to capture a [logicalWidth] x [logicalHeight] window at:
/// the device's own ratio, unless that would make the longest edge more than
/// [kFeedbackCaptureMaxEdge]. Capturing straight at that size re-renders the
/// layers (text stays crisp) instead of capturing at 5K and resizing.
double feedbackCaptureRatio({
  required double devicePixelRatio,
  required double logicalWidth,
  required double logicalHeight,
}) {
  final longest = math.max(logicalWidth, logicalHeight);
  if (longest <= 0) return devicePixelRatio;
  return math.min(devicePixelRatio, kFeedbackCaptureMaxEdge / longest);
}

/// The scales to try, largest first, when an image of [longestEdge] pixels
/// must be re-rendered to fit [kFeedbackMaxImageBytes]: full size, then
/// three steps of 0.75, never below [kFeedbackMinEdge] (an image already
/// smaller than that is tried at full size only).
List<double> feedbackRenderScales(double longestEdge) {
  final scales = <double>[1];
  var s = 1.0;
  for (var i = 0; i < 3; i++) {
    s *= 0.75;
    if (longestEdge * s < kFeedbackMinEdge) break;
    scales.add(s);
  }
  return scales;
}
