import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:admin/domain/feedback/markup.dart';

/// How long to wait for whatever the caller just closed (a drawer, a dialog,
/// a sheet) to finish animating away, when the caller can't say exactly.
/// Covers the drawer's 246 ms close and a dialog's 150 ms exit.
const Duration kCaptureSettleWait = Duration(milliseconds: 300);

/// The most a capture may take before Contact Us opens without one — a
/// hidden or minimised window produces no frames, and must not hang it.
const Duration kCaptureTimeout = Duration(seconds: 1);

/// A picture of the app as it is now, for a Contact Us message
/// (docs/feedback-screenshots.md), or null — never an error.
///
/// [boundaryKey] is the root capture boundary (`ScreenshotWindowController`),
/// which holds the router, the root navigator and its overlay: an open dialog
/// is in the shot, toasts are not. So the shot waits for what the caller just
/// closed to be gone:
///
/// * [afterClosing] — that route's `TransitionRoute.completed`, which resolves
///   once its exit animation is over (the palette, About). Pass
///   `Future.value()` when nothing is closing.
/// * null — the caller doesn't know; wait [settleWait].
///
/// It deliberately does not wait for `transientCallbackCount` to reach zero:
/// a running task timer's pulse, any spinner and the iOS caret never let it.
///
/// The capture is taken at [feedbackCaptureRatio], re-rendering the layers at
/// that size rather than capturing a 5K window and resizing it. The caller
/// owns (and disposes) the image.
Future<ui.Image?> captureAppScreen({
  required GlobalKey boundaryKey,
  required double devicePixelRatio,
  Future<void>? afterClosing,
  Duration settleWait = kCaptureSettleWait,
  Duration timeout = kCaptureTimeout,
}) async {
  // No boundary (a test, a surface outside the app's builder): nothing to wait
  // for.
  if (boundaryKey.currentContext == null) return null;
  try {
    return await _capture(
      boundaryKey: boundaryKey,
      devicePixelRatio: devicePixelRatio,
      afterClosing: afterClosing,
      settleWait: settleWait,
    ).timeout(timeout, onTimeout: () => null);
  } catch (_) {
    return null;
  }
}

Future<ui.Image?> _capture({
  required GlobalKey boundaryKey,
  required double devicePixelRatio,
  required Future<void>? afterClosing,
  required Duration settleWait,
}) async {
  if (afterClosing != null) {
    // A route that never completes (an unusual pop) mustn't stall the shot.
    await afterClosing
        .timeout(kCaptureTimeout, onTimeout: () {})
        .catchError((Object _) {});
  } else {
    await Future<void>.delayed(settleWait);
  }

  // The overlay entry of a route that just finished goes away in the next
  // frame; and the boundary's layer is only current once a frame has painted.
  final binding = WidgetsBinding.instance;
  binding.scheduleFrame();
  await binding.endOfFrame;

  final render = boundaryKey.currentContext?.findRenderObject();
  if (render is! RenderRepaintBoundary || !render.attached) return null;
  if (!kReleaseMode && render.debugNeedsPaint) {
    binding.scheduleFrame();
    await binding.endOfFrame;
  }
  final size = render.size;
  return render.toImage(
    pixelRatio: feedbackCaptureRatio(
      devicePixelRatio: devicePixelRatio,
      logicalWidth: size.width,
      logicalHeight: size.height,
    ),
  );
}
