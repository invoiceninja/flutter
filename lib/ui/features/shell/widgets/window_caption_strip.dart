import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/native_window.dart';
import 'package:admin/app/screenshot_window_controller.dart';

/// Gap between the traffic lights' trailing edge and any hosted content. Not an
/// [InSpacing] token — it separates app chrome from an OS control.
const double _kButtonsClearance = 8.0;

/// Trailing inset for hosted caption content. Matches `SidebarHeader`'s own
/// right inset (`in_sidebar.dart`, `fromLTRB(14, 8, 14, 8)`) so the forward
/// arrow's edge lines up with the Sync button directly below it.
const double _kCaptionTrailingInset = 14.0;

/// Window-caption region at the top of the sidebar: it reserves space for any
/// window controls that live there, provides a drag handle now that the native
/// title bar is hidden, and can host app chrome of its own beside them.
///
/// - **macOS**: a 28-px draggable strip; the real traffic-light buttons float
///   over it (top-left, native — so this strip only catches drags in the empty
///   space around them, and the buttons keep their own clicks + inactive-graying).
///   [trailingBuilder] fills the dead space to their right — the sidebar's
///   back/forward arrows, which would otherwise cost a whole row of their own
///   below. Every measurement comes from [NativeWindow.chrome]; nothing about
///   the titlebar is assumed here (macOS 26 changed all of it).
///   When there are no real buttons floating here — the Debug Panel hid them
///   for a clean screenshot ([ScreenshotWindowController.windowButtonsHidden]),
///   or macOS moved them into the fullscreen auto-hiding menu bar
///   ([NativeWindow.isFullscreen]) — the 28-px reservation and the drag handle
///   both drop: with nothing to host the strip collapses to zero height and the
///   sidebar / content rises to meet the window's top edge, and with [trailing]
///   the row simply shrinks to its content.
/// - **Windows/Linux**: their controls are *drawn* top-right (a future
///   `WindowControls` widget over the content top — see
///   `docs/desktop-window-state.md` § Desktop hidden title bar), so the sidebar
///   stays flush and this renders nothing for now. Once those frameless runners
///   are added it becomes the window drag handle on the left.
/// - **web / mobile**: nothing.
class WindowCaptionStrip extends StatelessWidget {
  const WindowCaptionStrip({
    super.key,
    required this.controller,
    this.trailingBuilder,
  });

  /// Screenshot/window controller, watched so the strip collapses the instant
  /// the Debug Panel hides the native window buttons.
  final ScreenshotWindowController controller;

  /// Builds app chrome rendered *inside* the caption row, aligned to its
  /// trailing edge — the nav history arrows from `InSidebar`'s persistent rail.
  ///
  /// A builder, not a widget, because the height it is handed is the height it
  /// must be: only this widget knows the measured band, and a caller sizing
  /// itself independently is precisely the split brain that misaligned the
  /// arrows in the first place.
  ///
  /// Only ever non-null where a caption row exists: gate the call site on
  /// [hostsCaptionRow], which is the one predicate that answers it.
  final Widget Function(double height)? trailingBuilder;

  /// Whether this platform has a caption row at all — i.e. whether it hides its
  /// title bar and floats the window controls over the app's own chrome. Only
  /// macOS does today, so only macOS can host [trailing].
  static bool hostsCaptionRow() =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    // Only macOS hides its title bar today (fullSizeContentView). Windows/Linux
    // keep their normal title bar until their runners + frameless mode land, at
    // which point a branch is added here.
    if (!hostsCaptionRow()) {
      // Content handed to a platform with no caption row would silently vanish.
      assert(
        trailingBuilder == null,
        'WindowCaptionStrip.trailingBuilder has no host here — gate the call '
        'site on WindowCaptionStrip.hostsCaptionRow().',
      );
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: Listenable.merge([controller, NativeWindow.instance.chrome]),
      builder: (context, _) {
        final chrome = NativeWindow.instance.chrome.value;
        // True while real traffic lights are floating over this row — i.e.
        // while there is something to reserve space for and a title bar to drag.
        // Fullscreen moves them into the auto-hiding menu bar; the Debug Panel
        // hides them outright for a clean screenshot.
        final reserve =
            chrome.hasWindowButtons && !controller.windowButtonsHidden;
        // Nothing to reserve, nothing to host: collapse entirely.
        if (trailingBuilder == null && !reserve) return const SizedBox.shrink();
        // Fit the content to the buttons and centre it ON them, rather than
        // centring it in the band and trusting the two to agree. AppKit does
        // centre them on every macOS to date — but assuming that is exactly the
        // bug this measurement exists to prevent, so state the requirement.
        final contentHeight = reserve
            ? math.min(chrome.captionHeight, 2 * chrome.buttonsCenterY)
            : kFallbackCaptionHeight;
        final topPad = reserve
            ? chrome.buttonsCenterY - contentHeight / 2
            : 0.0;
        final row = SizedBox(
          // The host `Column` sets no `crossAxisAlignment`, so it hands children
          // *loose* width — without this the row would shrink-wrap and trailing
          // alignment would collapse onto the content.
          width: double.infinity,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: reserve ? chrome.captionHeight : 0,
            ),
            // Defined background so the strip never reveals a gap in the narrow
            // layout (where it sits above the per-screen Scaffold). In the
            // sidebar it matches the surrounding surface-colored rail.
            child: ColoredBox(
              color: context.inTheme.surface,
              child: trailingBuilder == null
                  ? null
                  : Padding(
                      padding: EdgeInsetsDirectional.only(
                        start: reserve
                            ? chrome.buttonsTrailingX + _kButtonsClearance
                            : 0,
                        top: topPad,
                        end: _kCaptionTrailingInset,
                      ),
                      // A `Row`, not an `Align`: a non-flex child of a Row gets
                      // an *unbounded* main axis and so shrink-wraps, which is
                      // what lets `end` actually move it. Under an Align the
                      // width is bounded, and content that is itself a Row with
                      // the default `MainAxisSize.max` — `NavHistoryButtons` is
                      // exactly that — silently expands to fill and left-aligns
                      // its own children instead.
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [trailingBuilder!(contentHeight)],
                      ),
                    ),
            ),
          ),
        );
        // No window to drag in fullscreen, and screenshot mode deliberately has
        // no drag handle. Hosted content stays hit-testable either way — it's a
        // child, so its taps win the arena, while a pan that starts on it
        // correctly becomes a window drag.
        if (!reserve) return row;
        return GestureDetector(
          // Opaque so the otherwise-empty strip is hit-testable for the pan.
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => NativeWindow.instance.startDrag(),
          onDoubleTap: () => NativeWindow.instance.handleDoubleClick(),
          child: row,
        );
      },
    );
  }
}
