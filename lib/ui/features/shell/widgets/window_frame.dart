import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/native_window.dart';
import 'package:admin/app/screenshot_window_controller.dart';
import 'package:admin/app/shell_mounted_notifier.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/shell/widgets/in_sidebar.dart';
import 'package:admin/ui/features/shell/widgets/nav_history_buttons.dart';
import 'package:admin/ui/features/shell/widgets/window_controls.dart';

/// Leading inset inside the title bar. The same 10 the sidebar uses for its own
/// arrow row (`in_sidebar.dart`, `fromLTRB(10, 4, ...)`), which is what lines
/// the mark up with the company avatar directly below it.
const double _kBarLeadingInset = 10.0;

/// Size of the app mark in the band. Matches the ~16-18 px a Windows caption
/// draws its icon at; larger reads as content rather than chrome.
const double _kBarIconSize = 18.0;

/// Gap between the mark and the wordmark.
const double _kBarIconGap = 8.0;

/// The app-painted window title bar for the frameless Windows and Linux
/// runners, wrapped around the whole routed app in `main.dart`.
///
/// Off those two platforms this is a pure passthrough — it returns [child]
/// itself, adding no render object and changing no layout.
///
/// **Why it mounts above the router.** Six routes live outside the
/// authenticated shell (`/login`, `/signup`, `/lock`, `/setup`, `/too-old`,
/// `/calendar_connection/complete`) and so does go_router's `errorBuilder`
/// screen — which the deep-link guard can land on. A frameless window whose
/// only chrome lived inside the shell would be unmovable and unclosable on all
/// seven. It also sits INSIDE the screenshot `RepaintBoundary` on purpose:
/// `ScreenshotWindowController` compares the achieved size against what it
/// asked for, so a bar outside the boundary would make every store capture
/// short by the band and fail that check on every preset.
///
/// macOS is untouched — it keeps its real traffic lights and the
/// `WindowCaptionStrip` inside the sidebar.
class WindowFrame extends StatelessWidget {
  const WindowFrame({
    super.key,
    required this.screenshotWindow,
    required this.railCollapsed,
    required this.shellMounted,
    required this.child,
  });

  /// Watched so the drawn buttons vanish for a clean screenshot.
  final ScreenshotWindowController screenshotWindow;

  /// `services.sidebar` — the rail's collapsed preference, which sets the
  /// width of the bar's leading segment.
  final ValueListenable<bool> railCollapsed;

  /// `services.shellMounted` — whether there is a sidebar rail below at all.
  /// This widget sits above the router and cannot see the shell itself.
  ///
  /// Typed as the concrete notifier, not `ValueListenable<bool>`, and that is
  /// load-bearing: the writer is a *descendant* (`ScaffoldWithNav.initState`)
  /// and this listener has already been built for that frame, so the write must
  /// be frame-deferred or it is "setState() called during build" every time.
  /// [ShellMountedNotifier] is what defers it, so accepting the interface here
  /// would let a plain `ValueNotifier` compile and crash on the first login.
  final ShellMountedNotifier shellMounted;

  final Widget child;

  /// Whether this platform is frameless and paints its own title bar.
  static bool paintsTitleBar() => paintsAppTitleBar();

  @override
  Widget build(BuildContext context) {
    if (!paintsTitleBar()) return child;
    return Column(
      children: [
        _TitleBar(
          screenshotWindow: screenshotWindow,
          railCollapsed: railCollapsed,
          shellMounted: shellMounted,
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({
    required this.screenshotWindow,
    required this.railCollapsed,
    required this.shellMounted,
  });

  final ScreenshotWindowController screenshotWindow;
  final ValueListenable<bool> railCollapsed;
  final ShellMountedNotifier shellMounted;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([shellMounted, railCollapsed]),
      builder: (context, _) {
        final tokens = context.inTheme;
        // The same threshold the shell's own LayoutBuilder splits on, and
        // provably the same number: nothing between this widget and
        // `ScaffoldWithNav` constrains width, so the window width the frame
        // reads is the box width the shell is handed. (Only the HEIGHT differs,
        // by the band.)
        final wide = Breakpoints.isGlobalNavVisible(context);
        final leading = (shellMounted.value && wide)
            ? (railCollapsed.value ? kInSidebarCollapsedWidth : kInSidebarWidth)
            : 0.0;
        // Arrows only on the expanded rail. The collapsed 64-px rail keeps them
        // in its own row, where two 32-px buttons fill it exactly — the same
        // split the macOS caption strip makes.
        final arrows = leading == kInSidebarWidth;
        // The collapsed 64-px rail has room for the mark but not the words.
        final showWordmark = leading != kInSidebarCollapsedWidth;

        return SizedBox(
          // `Column` hands children LOOSE width (its default crossAxisAlignment
          // is `center`), so without this the all-positioned Stack below would
          // measure zero wide. `WindowCaptionStrip` documents the same trap.
          width: double.infinity,
          height: kAppTitleBarHeight,
          child: Stack(
            children: [
              // Drag layer FIRST, so it is hit-tested LAST: the arrows and the
              // window buttons above it get first refusal, and a press on them
              // never enters the pan arena at all.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => NativeWindow.instance.startDrag(),
                  onDoubleTap: () => NativeWindow.instance.handleDoubleClick(),
                  // Right-click opens the OS window menu, as a real title bar
                  // does. The band is client area now, so this never reaches
                  // the runner as a non-client message — it has to be routed.
                  // No coordinates: the runner anchors on the cursor, which
                  // sidesteps the logical-vs-physical / client-vs-screen
                  // mismatch entirely (see NativeWindow.showSystemMenu).
                  onSecondaryTap: NativeWindow.instance.showSystemMenu,
                  child: ColoredBox(color: tokens.bg),
                ),
              ),
              if (leading > 0)
                // Physical `left`, not `PositionedDirectional`: the shell pins
                // its rail with a physical `Positioned(left: 0)` and does not
                // flip in Arabic or Hebrew, so this must not either.
                Positioned(
                  key: const ValueKey('windowFrame.leadingSegment'),
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: leading,
                  // Purely decorative, and it MUST be pointer-transparent:
                  // RenderDecoratedBox.hitTestSelf returns
                  // `decoration.hitTest(...)`, which is true anywhere inside a
                  // plain rectangle. Without this the segment eats every press
                  // over the rail's width — 232 px of dead title bar that
                  // cannot drag the window, and that a drag test probing the
                  // middle of the band never notices.
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        // 1 px inside the box — exactly how `InSidebar` draws
                        // its own right edge, so the two line up to the pixel.
                        border: Border(right: BorderSide(color: tokens.border)),
                      ),
                    ),
                  ),
                ),
              // The app identity the OS caption used to carry. It sits ABOVE
              // the segment in paint order but absorbs no pointers (an Image
              // and a Text both decline the hit test), so the whole mark stays
              // draggable like any other empty stretch of a title bar.
              Positioned(
                left: _kBarLeadingInset,
                top: 0,
                bottom: 0,
                // Bounded so a very narrow window ellipsizes the wordmark
                // rather than sliding it under the window buttons.
                right: (kWindowControlWidth * 3) + InSpacing.sm,
                // IgnorePointer is load-bearing, not defensive: `Text` renders
                // as a RenderParagraph, whose `hitTestSelf` returns true so it
                // can dispatch TextSpan recognizers. A Stack stops at the first
                // child that hits, so without this the wordmark swallows the
                // press and the window cannot be dragged by its own title —
                // the one part of a title bar everyone grabs.
                child: IgnorePointer(
                  child: _TitleBarIdentity(showWordmark: showWordmark),
                ),
              ),
              if (arrows)
                // Past the segment's divider rather than inside it: the mark
                // has the segment now, and squeezing both into 232 px overflows
                // once the wordmark grows at a large text scale.
                Positioned(
                  left: leading + _kBarLeadingInset,
                  top: 0,
                  bottom: 0,
                  child: const Center(
                    child: NavHistoryButtons(
                      height: kAppTitleBarHeight,
                      // No `Overlay` above the router — a tooltip would assert
                      // in debug and throw on hover in release. Semantics
                      // carries the label.
                      tooltips: false,
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: WindowControls(
                  controller: screenshotWindow,
                  height: kAppTitleBarHeight,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The app mark and wordmark, restoring what the OS caption used to show once
/// the window went frameless.
///
/// Deliberately inert: no `GestureDetector`, no `Semantics` action. Its caller
/// wraps it in an `IgnorePointer` so a drag or double-click started on the mark
/// falls through to the drag layer beneath — which is what a title bar's own
/// name has to do. (`Text` would otherwise swallow it: `RenderParagraph`
/// hit-tests itself so it can dispatch `TextSpan` recognizers.)
class _TitleBarIdentity extends StatelessWidget {
  const _TitleBarIdentity({required this.showWordmark});

  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Row(
      // Physical order, like the rail below it — the mark does not swap sides
      // in Arabic or Hebrew, because the segment it sits on does not either.
      textDirection: TextDirection.ltr,
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/icon.png',
          width: _kBarIconSize,
          height: _kBarIconSize,
          // The source is far larger than 18 px, so let the engine do a proper
          // downsample rather than a nearest-neighbour one.
          filterQuality: FilterQuality.medium,
          // Assets can fail to resolve in a test harness or a stripped build;
          // the band must not become an error box over it.
          errorBuilder: (_, _, _) =>
              const SizedBox(width: _kBarIconSize, height: _kBarIconSize),
        ),
        if (showWordmark) ...[
          const SizedBox(width: _kBarIconGap),
          Flexible(
            child: Text(
              // i18n-exempt: a product name, not UI copy — the same literal
              // `about_dialog.dart` uses.
              'Invoice Ninja',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.ink,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
