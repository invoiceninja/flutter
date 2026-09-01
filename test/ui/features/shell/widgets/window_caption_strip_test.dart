import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/native_window.dart';
import 'package:admin/app/screenshot_window_controller.dart';
import 'package:admin/ui/features/shell/widgets/window_caption_strip.dart';

/// Theme that supplies the `InTheme` extension the strip reads via
/// `context.inTheme` on the platform where it actually renders.
ThemeData _theme() => ThemeData.light().copyWith(
  extensions: <ThemeExtension<dynamic>>[InTheme.light],
);

Widget _wrap(Widget child) => MaterialApp(
  theme: _theme(),
  home: Scaffold(body: Column(children: [child])),
);

void main() {
  // The strip's controller pings the native window channel when buttons are
  // hidden; swallow those calls so `setWindowButtonsHidden` doesn't throw
  // `MissingPluginException`.
  const channel = MethodChannel('invoice_ninja/native_window');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // The platform override must be reset inside the test body (a `finally`, not
  // `addTearDown`) — the test framework asserts all foundation debug vars are
  // unset before tear-downs run.

  // Guards the platform gate: window chrome must never leak onto platforms that
  // still show their native title bar (mobile today; web is `kIsWeb`-gated in
  // the widget). Only macOS hides its title bar, so only macOS renders the strip.
  testWidgets('renders nothing on a platform without a hidden title bar', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(
        _wrap(WindowCaptionStrip(controller: ScreenshotWindowController())),
      );

      expect(find.byType(WindowCaptionStrip), findsOneWidget);
      // The SizedBox.shrink path: no drag handle, zero height.
      expect(
        find.descendant(
          of: find.byType(WindowCaptionStrip),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      expect(tester.getSize(find.byType(WindowCaptionStrip)).height, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('renders a draggable caption strip on macOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        _wrap(WindowCaptionStrip(controller: ScreenshotWindowController())),
      );

      expect(
        find.descendant(
          of: find.byType(WindowCaptionStrip),
          matching: find.byType(GestureDetector),
        ),
        findsOneWidget,
      );
      expect(tester.getSize(find.byType(WindowCaptionStrip)).height, 28);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // Hiding the OS buttons from the Debug Panel collapses the strip so the
  // sidebar / content rises to the window's top edge.
  testWidgets('collapses to zero height when window buttons are hidden', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final controller = ScreenshotWindowController();
      await tester.pumpWidget(
        _wrap(WindowCaptionStrip(controller: controller)),
      );

      // Baseline: buttons visible → the 28-px draggable strip is reserved.
      expect(tester.getSize(find.byType(WindowCaptionStrip)).height, 28);

      await controller.setWindowButtonsHidden(true);
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(WindowCaptionStrip),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
      expect(tester.getSize(find.byType(WindowCaptionStrip)).height, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // ---------------------------------------------------------------------------
  // Hosted content: the sidebar's nav arrows ride in the caption row beside the
  // traffic lights instead of costing a row of their own below it.
  // ---------------------------------------------------------------------------

  // The one gate `InSidebar` reads before handing over the arrows. Getting it
  // wrong doesn't throw — the arrows would just silently vanish on a platform
  // whose strip renders nothing.
  testWidgets('hostsCaptionRow is true only where the title bar is hidden', (
    tester,
  ) async {
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      try {
        expect(
          WindowCaptionStrip.hostsCaptionRow(),
          platform == TargetPlatform.macOS,
          reason: '$platform',
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }
  });

  testWidgets('hosts trailing content on the traffic lights\' center line', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        _wrap(
          WindowCaptionStrip(
            controller: ScreenshotWindowController(),
            trailingBuilder: (_) =>
                const SizedBox(key: Key('arrows'), width: 48, height: 24),
          ),
        ),
      );

      final strip = tester.getRect(find.byType(WindowCaptionStrip));
      final arrows = tester.getRect(find.byKey(const Key('arrows')));
      // Still the reserved titlebar band, with shorter content centered in it —
      // which is exactly where AppKit centers the real traffic lights.
      expect(strip.height, 28);
      expect(arrows.center.dy, strip.center.dy);
      // Trailing-aligned, at the same inset as the Sync button a row below.
      expect(strip.right - arrows.right, 14);
      // And nowhere near the buttons themselves.
      expect(arrows.left, greaterThan(70));
      // The drag handle survives underneath the content.
      expect(
        find.descendant(
          of: find.byType(WindowCaptionStrip),
          matching: find.byType(GestureDetector),
        ),
        findsOneWidget,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // Regression: the trailing slot was an `Align` first, and `NavHistoryButtons`
  // is a `Row` with the default `MainAxisSize.max`. Bounded width made it fill
  // the slot and left-align its own children, so the arrows rendered hard
  // against the traffic lights while every size assertion still passed.
  testWidgets('trailing content that fills its width is still pushed to the '
      'trailing edge', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        _wrap(
          WindowCaptionStrip(
            controller: ScreenshotWindowController(),
            trailingBuilder: (_) => const Row(
              children: [SizedBox(key: Key('arrows'), width: 48, height: 24)],
            ),
          ),
        ),
      );

      final strip = tester.getRect(find.byType(WindowCaptionStrip));
      final arrows = tester.getRect(find.byKey(const Key('arrows')));
      expect(strip.right - arrows.right, 14);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // 28 is a floor, not a fixed height: `flutter test` forces
  // `TargetPlatform.android` and so `standard` visual density, where the real
  // arrows measure 32 rather than the 24 they take at desktop `compact`.
  testWidgets('taller trailing content grows the row instead of clipping', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        _wrap(
          WindowCaptionStrip(
            controller: ScreenshotWindowController(),
            trailingBuilder: (_) => const SizedBox(width: 64, height: 40),
          ),
        ),
      );

      expect(tester.getSize(find.byType(WindowCaptionStrip)).height, 40);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // Fullscreen moves the traffic lights into the auto-hiding menu bar, so there
  // is nothing left to reserve space for and no title bar to drag.
  testWidgets('fullscreen drops the reserved band and the drag handle', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        _wrap(
          WindowCaptionStrip(
            controller: ScreenshotWindowController(),
            trailingBuilder: (_) =>
                const SizedBox(key: Key('arrows'), width: 48, height: 24),
          ),
        ),
      );
      expect(tester.getSize(find.byType(WindowCaptionStrip)).height, 28);

      NativeWindow.instance.chrome.value = const WindowChrome(
        fullscreen: true,
        captionHeight: 0,
        buttonsCenterY: 0,
        buttonsTrailingX: 0,
      );
      await tester.pumpAndSettle();

      // The content stays put — it must not jump back down to a row of its own
      // just because the window went fullscreen.
      expect(find.byKey(const Key('arrows')), findsOneWidget);
      expect(tester.getSize(find.byType(WindowCaptionStrip)).height, 24);
      expect(
        find.descendant(
          of: find.byType(WindowCaptionStrip),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    } finally {
      NativeWindow.instance.chrome.value = const WindowChrome();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('fullscreen collapses a strip with nothing to host', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        _wrap(WindowCaptionStrip(controller: ScreenshotWindowController())),
      );
      expect(tester.getSize(find.byType(WindowCaptionStrip)).height, 28);

      NativeWindow.instance.chrome.value = const WindowChrome(
        fullscreen: true,
        captionHeight: 0,
        buttonsCenterY: 0,
        buttonsTrailingX: 0,
      );
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(WindowCaptionStrip)).height, 0);
    } finally {
      NativeWindow.instance.chrome.value = const WindowChrome();
      debugDefaultTargetPlatformOverride = null;
    }
  });
  // ---------------------------------------------------------------------------
  // Measured chrome. macOS 26 reports a 32-pt titlebar with the buttons centred
  // at 16; 10.15 through macOS 15 used 28 / 14. Centring hosted content in a
  // hardcoded 28-pt band is what left the arrows 2 pt above the buttons on 26,
  // so both shapes are pinned here.
  // ---------------------------------------------------------------------------
  for (final (name, chrome) in <(String, WindowChrome)>[
    // Exactly what AppKit reported on macOS 26.4.1.
    (
      'macOS 26',
      WindowChrome(captionHeight: 32, buttonsCenterY: 16, buttonsTrailingX: 69),
    ),
    // The pre-26 shape, which is also the fallback when nothing reports.
    (
      'macOS 15 and earlier',
      WindowChrome(
        captionHeight: kFallbackCaptionHeight,
        buttonsCenterY: kFallbackCaptionHeight / 2,
        buttonsTrailingX: kFallbackButtonsTrailingX,
      ),
    ),
  ]) {
    testWidgets('$name: the band and the hosted content follow the measured '
        'chrome', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      NativeWindow.instance.chrome.value = chrome;
      try {
        await tester.pumpWidget(
          _wrap(
            WindowCaptionStrip(
              controller: ScreenshotWindowController(),
              // Exactly what `InSidebar` does: the strip dictates the height.
              trailingBuilder: (height) =>
                  SizedBox(key: const Key('arrows'), width: 48, height: height),
            ),
          ),
        );

        final strip = tester.getRect(find.byType(WindowCaptionStrip));
        final arrows = tester.getRect(find.byKey(const Key('arrows')));
        // The band is the real titlebar, not a guess.
        expect(strip.height, chrome.captionHeight);
        // And the content sits on the buttons' own centre line. This is the
        // assertion the shipped bug would have failed.
        expect(arrows.center.dy - strip.top, chrome.buttonsCenterY);
        // Clear of the buttons, and inset from the trailing edge like the Sync
        // button a row below.
        expect(strip.right - arrows.right, 14);
        expect(arrows.left - strip.left, greaterThan(chrome.buttonsTrailingX));
      } finally {
        NativeWindow.instance.chrome.value = const WindowChrome();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }
}
