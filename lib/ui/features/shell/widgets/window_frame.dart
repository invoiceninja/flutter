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

/// How far the arrow's visible glyph sits inside its own box.
///
/// `NavHistoryButtons` pins each arrow to `fixedSize: Size(32, ...)` around an
/// 18-px icon, so the glyph starts 7 px in. Aligning the *box* to the content
/// toolbar's inset would therefore leave the glyph 7 px right of the button it
/// is supposed to line up with — the box edge is invisible, the glyph is what
/// the eye measures against.
const double _kNavGlyphInset = (32.0 - 18.0) / 2;

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
    // The platform is only half the question — the runner also has to have
    // actually dropped its OS title bar. It can decline (the
    // IN_DISABLE_CUSTOM_FRAME kill switch, there so a broken frame can be
    // recovered from without a new build), and painting a band over a caption
    // that is still there gives two stacked title bars — which looks exactly
    // like the frame having failed, and is how the real bug hid for as long as
    // it did. Declining to draw turns that into a plain stock-caption window.
    //
    // `NativeWindow.customFrame`, not `chrome`: this wraps the whole routed
    // app, and `chrome` changes on every focus toggle. That notifier settles
    // once per process.
    return ValueListenableBuilder<bool>(
      valueListenable: NativeWindow.instance.customFrame,
      builder: (context, customFrame, _) {
        if (!customFrame) return child;
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
      },
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
          // The band mounts in `MaterialApp.builder`, ABOVE the Navigator — so
          // the only DefaultTextStyle in scope is MaterialApp's `_errorTextStyle`
          // fallback: 48-px monospace with a yellow double underline, whose own
          // debugLabel reads "consider putting your text in a Material". A local
          // `TextStyle` on the Text is not enough, because anything it does not
          // name (here `fontFamily` and `decoration`) still merges through from
          // that fallback. Setting it once for the whole band means text added
          // here later cannot walk into the same trap.
          child: DefaultTextStyle(
            style: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
            child: Stack(
              children: [
                // Drag layer FIRST, so it is hit-tested LAST: the arrows and the
                // window buttons above it get first refusal, and a press on them
                // never enters the pan arena at all.
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) => NativeWindow.instance.startDrag(),
                    onDoubleTap: () =>
                        NativeWindow.instance.handleDoubleClick(),
                    // Right-click opens the OS window menu, as a real title bar
                    // does. The band is client area now, so this never reaches
                    // the runner as a non-client message — it has to be routed.
                    // No coordinates: the runner anchors on the cursor, which
                    // sidesteps the logical-vs-physical / client-vs-screen
                    // mismatch entirely (see NativeWindow.showSystemMenu).
                    onSecondaryTap: NativeWindow.instance.showSystemMenu,
                    // ONE colour across the whole band, plus a hairline rule
                    // under it.
                    //
                    // It used to be two-tone — `surface` over the rail, `bg`
                    // over the content — which sounded like it continued the
                    // columns below. In practice the content pane's own header
                    // is `surface` too, so the band's right half landed as a
                    // strip of `bg` sandwiched between `surface` above-left and
                    // `surface` below: a colour step that reads as a thick,
                    // accidental border rather than as structure. A title bar
                    // is one strip, and the rule is what separates it from
                    // whatever header follows — in light and dark alike, since
                    // both tokens flip together.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.surface,
                        // `border`, like the app's other 55 dividers — this
                        // is not the place to be the 56th that is different.
                        //
                        // Drawn as ONE DEVICE PIXEL, not one logical pixel.
                        // `BorderSide`'s default 1.0 is logical, so at 150%
                        // scaling it covers 1.5 device rows and is antialiased
                        // across two — which reads both thicker and darker than
                        // a hairline, and is what made this line look heavy even
                        // after it was reverted from `borderStrong`. At 100% the
                        // two are identical. Deliberately finer than the app's
                        // other dividers: this is the outermost chrome edge, the
                        // only rule drawn against the window's own boundary.
                        //
                        // Recorded trade-off on the colour: `border` on
                        // `surface` measures 1.17-1.30:1 and is genuinely faint
                        // in the dark palettes (1.17 on Carbon). `borderStrong`
                        // was tried and reads visibly heavier than every line
                        // around it, including the content header's own rule
                        // directly below — which ships at that same contrast
                        // everywhere else and looks right.
                        border: Border(
                          // The window's own top edge, drawn HERE rather than
                          // by leaving the OS a pixel of non-client area to
                          // paint into. That pixel costs the entire caption:
                          // its height comes from the window style, not from
                          // how much room it is given, so one pixel of border
                          // brings back a ~31-px title bar. Inside the client
                          // area it cannot touch the frame.
                          //
                          // `borderStrong` to match the other three edges,
                          // which DWM paints from the same token via
                          // DWMWA_BORDER_COLOR — unlike the bottom rule below,
                          // which is an internal divider, not a window edge.
                          top: BorderSide(
                            color: tokens.borderStrong,
                            width: 1 / MediaQuery.devicePixelRatioOf(context),
                          ),
                          bottom: BorderSide(
                            color: tokens.border,
                            width: 1 / MediaQuery.devicePixelRatioOf(context),
                          ),
                        ),
                      ),
                    ),
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
                      // Carries only the divider now that the band is one
                      // colour — it continues the rail's own right edge up
                      // through the band, 1 px inside the box exactly as
                      // `InSidebar` draws it, so the two line up to the pixel.
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: tokens.border),
                          ),
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
                    // Backed off by the glyph inset so the ARROW lines up
                    // with the content toolbar's primary action ("New Client"),
                    // which sits `InSpacing.xl` past the rail
                    // (`entity_list_app_bar.dart`, the same 24 the table card
                    // below uses).
                    left: leading + InSpacing.xl - _kNavGlyphInset,
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
