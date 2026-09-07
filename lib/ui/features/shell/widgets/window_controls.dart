import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/native_window.dart';
import 'package:admin/app/screenshot_window_controller.dart';
import 'package:admin/l10n/localization.dart';

/// Width of one drawn caption button. Windows' own metric (46x32 at 100%
/// scale); GNOME and KDE disagree with each other and with this, so one
/// treatment ships on both platforms — see the class doc.
const double kWindowControlWidth = 46.0;

/// Close-button hover fill: WinUI's `SystemFillColorCritical`.
///
/// A literal, deliberately **not** `InTheme.overdue`. The status tokens are
/// user-overridable per light/dark preset, so a themed "overdue" could hand
/// someone a green close button. This one is an OS convention: the same red in
/// both themes, always under a white glyph.
const Color kWindowCloseHoverColor = Color(0xFFC42B1C);
const Color kWindowClosePressedColor = Color(0xFFC84031);

/// The drawn minimize / maximize-restore / close cluster for the frameless
/// Windows and Linux runners, mounted at the trailing edge of `WindowFrame`'s
/// title bar. macOS never uses this — it keeps its real traffic lights.
///
/// **One treatment on both platforms.** There is no single Linux convention
/// (Adwaita draws circles, Breeze draws squares), `gtk-decoration-layout` is
/// not readable from Flutter without a runner-side push, and guessing wrong is
/// worse than being neutral — so this follows Windows' metrics, exactly as
/// every cross-platform app the audience already runs (VS Code, Slack,
/// Spotify) does on Linux.
///
/// Deliberately not an `InkWell`: a caption button has a flat full-height fill,
/// not a ripple. That also sidesteps the [Ink] ban entirely (`Ink` registers on
/// the nearest ancestor `Material`, which up here is the wrong one).
class WindowControls extends StatelessWidget {
  const WindowControls({
    super.key,
    required this.controller,
    required this.height,
  });

  /// Watched so the cluster vanishes the instant the Debug Panel asks for a
  /// clean screenshot.
  final ScreenshotWindowController controller;

  /// Handed down by the title bar rather than defaulted here. The band owns its
  /// own height, and a child sizing itself from its own copy of the constant is
  /// exactly the split brain that misaligned the macOS nav arrows once already
  /// (see `WindowCaptionStrip.trailingBuilder`).
  final double height;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, NativeWindow.instance.chrome]),
      builder: (context, _) {
        // Hide the buttons for a clean capture — but the BAND does not
        // collapse, unlike the macOS caption strip. There the band exists only
        // to reserve room for the OS buttons; here it is app layout that also
        // hosts the nav arrows, so collapsing it would drop the arrows entirely
        // (the sidebar has already abstained) and shift every pixel below.
        if (controller.windowButtonsHidden) return const SizedBox.shrink();

        final chrome = NativeWindow.instance.chrome.value;
        final maximized = chrome.maximized;
        // Keyboard users reach these through Alt+Space (Windows) or the window
        // manager's own bindings (Linux), so the cluster stays out of the app's
        // Tab order rather than sitting in front of the first real control.
        return ExcludeFocus(
          child: Row(
            // Physical order, like the shell's own rail: the window buttons do
            // not swap sides in Arabic or Hebrew.
            textDirection: TextDirection.ltr,
            mainAxisSize: MainAxisSize.min,
            children: [
              _CaptionButton(
                key: const ValueKey('windowControls.minimize'),
                glyph: _CaptionGlyph.minimize,
                label: context.tr('minimize'),
                height: height,
                active: chrome.active,
                onPressed: NativeWindow.instance.minimize,
              ),
              _CaptionButton(
                key: ValueKey(
                  maximized
                      ? 'windowControls.restore'
                      : 'windowControls.maximize',
                ),
                glyph: maximized
                    ? _CaptionGlyph.restore
                    : _CaptionGlyph.maximize,
                label: context.tr(maximized ? 'restore' : 'maximize'),
                height: height,
                active: chrome.active,
                onPressed: NativeWindow.instance.toggleMaximize,
              ),
              _CaptionButton(
                key: const ValueKey('windowControls.close'),
                glyph: _CaptionGlyph.close,
                label: context.tr('close'),
                height: height,
                active: chrome.active,
                isClose: true,
                onPressed: NativeWindow.instance.close,
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _CaptionGlyph { minimize, maximize, restore, close }

class _CaptionButton extends StatefulWidget {
  const _CaptionButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.height,
    required this.active,
    required this.onPressed,
    this.isClose = false,
  });

  final _CaptionGlyph glyph;
  final String label;
  final double height;
  final bool active;
  final bool isClose;
  final VoidCallback onPressed;

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;

    Color fill = Colors.transparent;
    if (widget.isClose && (_hovered || _pressed)) {
      fill = _pressed ? kWindowClosePressedColor : kWindowCloseHoverColor;
    } else if (_pressed) {
      fill = tokens.ink.withValues(alpha: 0.12);
    } else if (_hovered) {
      // Reading the ink token means the overlay inverts correctly in dark mode
      // for free, rather than needing a second hardcoded colour.
      fill = tokens.ink.withValues(alpha: 0.07);
    }

    // An inactive window dims its chrome on both host platforms; a cluster that
    // never changes is the main tell that a title bar is drawn rather than real.
    //
    // The dim step is `ink2` -> `ink3`, the app's own secondary-to-muted pair,
    // rather than an alpha on `ink3`. Measured across all six palettes that is
    // 9.1–9.7:1 down to 4.0–4.7:1 — unmistakably dimmer, still legible. The
    // previous `ink3` at 45% landed at 1.7–1.9:1, which on a 1-px stroke inside
    // a 10-px glyph is barely on the screen at all; "inactive" should read as
    // receded, not as broken.
    final Color glyphColor = widget.isClose && (_hovered || _pressed)
        ? const Color(0xFFFFFFFF)
        : widget.active
        ? tokens.ink2
        : tokens.ink3;

    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        // The standard arrow, not a click cursor — window chrome, not content.
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: () {
            setState(() => _pressed = false);
            widget.onPressed();
          },
          child: ColoredBox(
            color: fill,
            child: SizedBox(
              width: kWindowControlWidth,
              height: widget.height,
              child: Center(
                child: CustomPaint(
                  size: const Size(10, 10),
                  painter: _CaptionGlyphPainter(
                    glyph: widget.glyph,
                    color: glyphColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the four caption glyphs by hand.
///
/// Not Material icons: `Icons.filter_none` (the usual stand-in for "restore")
/// is a rounded 24-px design, and `Icons.remove` / `Icons.close` are visually
/// far heavier than either OS convention. Strokes land on `.5` offsets so a
/// 1-px line falls on a device pixel at 100% scale, the common Windows case.
class _CaptionGlyphPainter extends CustomPainter {
  const _CaptionGlyphPainter({required this.glyph, required this.color});

  final _CaptionGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final w = size.width;
    final h = size.height;

    switch (glyph) {
      case _CaptionGlyph.minimize:
        final y = (h / 2).floorToDouble() + 0.5;
        canvas.drawLine(Offset(0, y), Offset(w, y), paint);
      case _CaptionGlyph.maximize:
        canvas.drawRect(Rect.fromLTWH(0.5, 0.5, w - 1, h - 1), paint);
      case _CaptionGlyph.restore:
        // Front square, bottom-left.
        canvas.drawRect(Rect.fromLTWH(0.5, 2.5, w - 3, h - 3), paint);
        // Back square, top-right — only the part the front one doesn't cover.
        canvas.drawPath(
          Path()
            // Start level with the front square's top edge, so the back
            // square's short left stub above it is drawn.
            ..moveTo(2.5, 2.5)
            ..lineTo(2.5, 0.5)
            ..lineTo(w - 0.5, 0.5)
            ..lineTo(w - 0.5, h - 2.5)
            ..lineTo(w - 2.5, h - 2.5),
          paint,
        );
      case _CaptionGlyph.close:
        canvas.drawLine(
          const Offset(0.5, 0.5),
          Offset(w - 0.5, h - 0.5),
          paint,
        );
        canvas.drawLine(Offset(w - 0.5, 0.5), Offset(0.5, h - 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_CaptionGlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}
