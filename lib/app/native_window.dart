import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/env.dart';

/// Drives native desktop window actions that no longer have a title bar to back
/// them once it's hidden: moving the window, the double-click title-bar action,
/// and (on platforms where the app draws its own window buttons) minimize /
/// maximize / close. Also backs the Debug Panel's screenshot tools:
/// programmatic content resizing and hiding the native window buttons.
/// Triggered from the window-caption chrome at the top of the
/// shell (`WindowCaptionStrip`, plus the drawn controls on Windows/Linux).
///
/// Traffic flows both ways: [listenForNativeEvents] subscribes to the pushes a
/// runner makes back, which today carry the measured [WindowChrome].
///
/// Mirrors the `NativeWindowTheme` bridge shape. Desktop-only — every method is
/// a no-op on web and mobile. Each desktop runner answers the shared
/// `invoice_ninja/native_window` channel; see `docs/desktop-window-state.md`
/// § Desktop hidden title bar for which methods each platform implements (macOS
/// is wired today; Windows/Linux when those runners are added).
/// Caption-band height to assume when the platform reports nothing: the macOS
/// titlebar height from 10.15 through macOS 15. Correct on those releases and
/// harmless elsewhere, since only macOS renders a caption row at all.
const double kFallbackCaptionHeight = 28.0;

/// Trailing edge of the traffic lights to assume when the platform reports
/// nothing: 12-pt buttons centred at x = 20 / 40 / 60, plus clearance.
const double kFallbackButtonsTrailingX = 70.0;

/// The native window chrome Flutter has to lay itself out around, in logical
/// points measured from the window's **top-left** corner.
///
/// Measured by the runner, never assumed: macOS 26 enlarged the traffic lights
/// and grew the titlebar to ~31 pt, where 10.15 through macOS 15 used 28 — and
/// the app ships to all of them, so there is no constant that works everywhere.
/// A hardcoded 28 is what put the sidebar's nav arrows 2 pt above the buttons.
///
/// The defaults reproduce the pre-measurement behaviour exactly, so any platform
/// that never reports (everything but macOS) and any failed read behave as
/// before.
@immutable
class WindowChrome {
  const WindowChrome({
    this.fullscreen = false,
    this.captionHeight = kFallbackCaptionHeight,
    this.buttonsCenterY = kFallbackCaptionHeight / 2,
    this.buttonsTrailingX = kFallbackButtonsTrailingX,
  });

  /// Parses the runner's payload, falling back per-field. A non-fullscreen
  /// `captionHeight` of zero means "asked too early, before AppKit laid the
  /// window out" — keep the fallback rather than collapse the band to nothing.
  factory WindowChrome.fromMap(Map<Object?, Object?> map) {
    double? positive(String key) {
      final v = (map[key] as num?)?.toDouble();
      return (v == null || v <= 0) ? null : v;
    }

    final fullscreen = map['fullscreen'] == true;
    final height = positive('captionHeight') ?? kFallbackCaptionHeight;
    return WindowChrome(
      fullscreen: fullscreen,
      captionHeight: height,
      buttonsCenterY: positive('buttonsCenterY') ?? height / 2,
      // Zero is meaningful here — no buttons are floating over the content —
      // so it is preserved rather than defaulted.
      buttonsTrailingX:
          (map['buttonsTrailingX'] as num?)?.toDouble() ??
          kFallbackButtonsTrailingX,
    );
  }

  /// True in fullscreen, where macOS moves the buttons into the auto-hiding
  /// menu bar.
  final bool fullscreen;

  /// Height of the titlebar band the window controls float over.
  final double captionHeight;

  /// Vertical centre line of the traffic lights — what caption-row content
  /// aligns to. Deliberately separate from [captionHeight] / 2: AppKit centres
  /// them today on every macOS, but assuming that is the bug this type exists
  /// to prevent, so the alignment target is carried explicitly.
  final double buttonsCenterY;

  /// Trailing edge of the traffic lights — the leading region to keep clear.
  final double buttonsTrailingX;

  /// Whether real window buttons are floating over the caption row right now.
  bool get hasWindowButtons => !fullscreen && buttonsTrailingX > 0;

  @override
  bool operator ==(Object other) =>
      other is WindowChrome &&
      other.fullscreen == fullscreen &&
      other.captionHeight == captionHeight &&
      other.buttonsCenterY == buttonsCenterY &&
      other.buttonsTrailingX == buttonsTrailingX;

  @override
  int get hashCode =>
      Object.hash(fullscreen, captionHeight, buttonsCenterY, buttonsTrailingX);

  @override
  String toString() =>
      'WindowChrome(fullscreen: $fullscreen, captionHeight: $captionHeight, '
      'buttonsCenterY: $buttonsCenterY, buttonsTrailingX: $buttonsTrailingX)';
}

class NativeWindow {
  NativeWindow._();

  static final NativeWindow instance = NativeWindow._();

  static const MethodChannel _channel = MethodChannel(
    'invoice_ninja/native_window',
  );

  /// The measured native window chrome, watched by `WindowCaptionStrip`.
  ///
  /// Holds [WindowChrome]'s defaults on every platform whose runner doesn't
  /// report — every platform but macOS today — which is byte-for-byte how the
  /// caption strip behaved before it was measured.
  final ValueNotifier<WindowChrome> chrome = ValueNotifier<WindowChrome>(
    const WindowChrome(),
  );

  /// Subscribe to the native -> Dart events on the shared channel. Call once at
  /// boot, before `runApp`.
  ///
  /// The handler is installed *before* the initial state is pulled, and both
  /// halves are needed. The macOS runner restores a fullscreen window from
  /// `awakeFromNib` on a later main-queue turn, which can fire its delegate
  /// (and so the push) before this handler exists; the pull closes that gap,
  /// and installing first means no push can land inside it.
  Future<void> listenForNativeEvents() async {
    if (!Env.isDesktop) return;
    _channel.setMethodCallHandler((call) async {
      // Anything this build doesn't know about is ignored rather than thrown
      // back across the channel — a newer runner must not break an older app.
      if (call.method == 'windowChromeChanged') {
        final args = call.arguments as Map<Object?, Object?>?;
        if (args != null) chrome.value = WindowChrome.fromMap(args);
      }
      return null;
    });
    try {
      final map = await _channel.invokeMapMethod<Object?, Object?>(
        'windowChrome',
      );
      if (map != null) chrome.value = WindowChrome.fromMap(map);
      // The one place the measured geometry is observable. Alignment bugs here
      // are invisible in tests (which force `TargetPlatform.android`) and cost
      // a screenshot to spot, so leave a debug-build breadcrumb.
      assert(() {
        debugPrint('NativeWindow chrome: ${chrome.value}');
        return true;
      }());
    } catch (e) {
      // Missing handler (Windows/Linux today, or older native code): the
      // fallback chrome stands.
      debugPrint('NativeWindow.windowChrome failed: $e');
    }
  }

  /// Begin a native window drag. Call from a pan start while the mouse is still
  /// down so the current event is a drag event (macOS `performDrag`; Win/Linux
  /// `WM_NCLBUTTONDOWN` / `gtk_window_begin_move_drag`).
  Future<void> startDrag() => _invoke('startDrag');

  /// Run the platform's title-bar double-click action (macOS honors System
  /// Settings; Win/Linux toggle maximize).
  Future<void> handleDoubleClick() => _invoke('doubleClick');

  /// Minimize the window. Used by the drawn window buttons on Windows/Linux;
  /// unused on macOS (its native traffic lights handle this).
  Future<void> minimize() => _invoke('minimize');

  /// Toggle maximize / restore. Drawn-button target on Windows/Linux.
  Future<void> toggleMaximize() => _invoke('toggleMaximize');

  /// Close the window. Drawn-button target on Windows/Linux.
  Future<void> close() => _invoke('close');

  /// Resize the window's content area to [width]×[height] logical points,
  /// preserving the visual top-left corner (macOS exits fullscreen first if
  /// needed). Returns the achieved content size in logical points so callers
  /// can detect clamping; null when not on desktop, on a channel error, or
  /// when this platform's runner lacks the handler.
  Future<Size?> setContentSize(double width, double height) async {
    if (!Env.isDesktop) return null;
    try {
      final res = await _channel.invokeMapMethod<String, Object?>(
        'setContentSize',
        {'width': width, 'height': height},
      );
      final w = (res?['width'] as num?)?.toDouble();
      final h = (res?['height'] as num?)?.toDouble();
      if (w == null || h == null) return null;
      return Size(w, h);
    } catch (e) {
      debugPrint('NativeWindow.setContentSize failed: $e');
      return null;
    }
  }

  /// Hide or show the native window buttons (macOS traffic lights) for clean
  /// window captures. Deliberately never persisted natively — the buttons are
  /// visible again on every launch.
  Future<void> setWindowButtonsHidden(bool hidden) =>
      _invoke('setWindowButtonsHidden', {'hidden': hidden});

  Future<void> _invoke(String method, [Object? arguments]) async {
    if (!Env.isDesktop) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e) {
      // Missing handler (a method this platform's runner doesn't implement, or
      // older native code) is non-fatal — that control just does nothing until
      // the native side catches up.
      debugPrint('NativeWindow.$method failed: $e');
    }
  }
}
