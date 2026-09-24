import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/native_splash.dart';

/// iOS-side counterpart to the macOS native splash. UIKit removes the
/// `LaunchScreen.storyboard` the instant the Flutter view appears, so we
/// paint an overlay at the same logo position/size to make the handoff
/// invisible, then animate it out when Flutter has finished its first paint.
///
/// On non-iOS platforms (macOS, Android, web), this is a transparent
/// passthrough — the macOS native splash lives in `MainFlutterWindow.swift`,
/// and other platforms don't have a custom splash to coordinate with.
///
/// Animation phases (iOS only), mirroring the macOS native implementation:
///   1. **idle / entry** — the wordmark zooms in (scale 0.90 → 1.0) while
///      fading in (α 0 → 1), 350 ms ease-out. Runs once on mount, in parallel
///      with the storyboard → Flutter handoff.
///   2. **dismissing** — the wordmark fades away (α 1 → 0) while it expands
///      from center (scale → 1.30), 0.35 s ease-out. Reduces to a 0.20 s
///      alpha-only fade under reduced motion (no zoom/expand in either phase).
///
/// Trigger: [NativeSplash.dismissed] flips to `true` from the post-frame
/// callback in `_InvoiceNinjaAppState.initState`; the listener defers the
/// state change with another post-frame callback to avoid `setState during
/// build` if the flag flips mid-build.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

enum _Phase { idle, dismissing, done }

class _SplashOverlayState extends State<SplashOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final AnimationController _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  _Phase _phase = _Phase.idle;

  /// Fixed for the State's life, so `dispose` undoes exactly what `initState`
  /// set up.
  late final bool _enabled =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    _exit.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _phase = _Phase.done);
      }
    });
    NativeSplash.dismissed.addListener(_onDismissedFlag);
    if (NativeSplash.dismissed.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _runExit());
    } else {
      // Zoom + fade the wordmark in once the first frame is up.
      // Reduced-motion users get a static logo (no zoom, no fade-in).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _phase != _Phase.idle) return;
        if (_reduceMotion()) return;
        _entry.forward();
      });
    }
  }

  bool _reduceMotion() {
    if (SemanticsBinding.instance.disableAnimations) return true;
    final mq = MediaQuery.maybeOf(context);
    return mq?.disableAnimations ?? false;
  }

  void _onDismissedFlag() {
    if (!NativeSplash.dismissed.value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _runExit());
  }

  void _runExit() {
    if (!mounted) return;
    if (_phase == _Phase.dismissing || _phase == _Phase.done) return;
    final reduce = _reduceMotion();
    _exit.duration = Duration(milliseconds: reduce ? 200 : 350);
    setState(() => _phase = _Phase.dismissing);
    _exit.forward(from: 0);
  }

  @override
  void dispose() {
    if (_enabled) {
      NativeSplash.dismissed.removeListener(_onDismissedFlag);
      _entry.dispose();
      _exit.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    // The same `Stack` for the whole life of the overlay, with the overlay
    // dropped from it once done. Returning [widget.child] in its place — the
    // app's own `Stack` — let Flutter match the two by type and remount every
    // unkeyed sibling inside the app's: the notice of a local-data reset told
    // the user a second time.
    if (_phase == _Phase.done) {
      return Stack(fit: StackFit.expand, children: [widget.child]);
    }

    final tokens = Theme.of(context).extension<InTheme>();
    final bg = tokens?.bg ?? const Color(0xFFF6F4EF);
    final isDark = tokens?.brightness == Brightness.dark;
    // Storyboard `LaunchImage` was generated from these source PNGs by
    // `flutter_native_splash` — render the same files at the same logical
    // size (109×25) so the storyboard → Flutter handoff is invisible.
    final logoAsset = isDark
        ? 'assets/images/logo_light.png'
        : 'assets/images/logo_dark.png';

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: Listenable.merge([_entry, _exit]),
            builder: (_, _) {
              final reduce = _reduceMotion();
              final entryT = Curves.easeOut.transform(_entry.value);
              final entryOpacity = reduce ? 1.0 : entryT; // 0 → 1
              final entryScale = reduce
                  ? 1.0
                  : 0.90 + entryT * 0.10; // 0.90 → 1.0
              final exitT = _exit.value;
              final opacity = (entryOpacity * (1.0 - exitT)).clamp(0.0, 1.0);
              // Bold expand-from-center on exit: 1.0 → 1.30 (Transform.scale
              // is center-anchored, so the logo blooms outward as it fades).
              final scale = reduce ? 1.0 : entryScale + exitT * 0.30;

              return Opacity(
                opacity: opacity,
                child: Container(
                  color: bg,
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: scale,
                    child: Image.asset(
                      logoAsset,
                      width: 109,
                      height: 25,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
