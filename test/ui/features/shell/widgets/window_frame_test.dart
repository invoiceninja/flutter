import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/nav_history_controller.dart';
import 'package:admin/app/native_window.dart';
import 'package:admin/app/screenshot_window_controller.dart';
import 'package:admin/app/shell_mounted_notifier.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/shell/widgets/in_sidebar.dart';
import 'package:admin/ui/features/shell/widgets/nav_history_buttons.dart';
import 'package:admin/ui/features/shell/widgets/window_controls.dart';
import 'package:admin/ui/features/shell/widgets/window_frame.dart';

/// The app-painted title bar for the frameless Windows / Linux runners.
///
/// Neither runner can be built on the dev machine, so everything about this
/// widget's geometry is pinned here. Two harness traps shape the file:
///
///  * `flutter test` forces `TargetPlatform.android`, so the bar is a
///    passthrough unless a case overrides the platform — reset in a `finally`,
///    never `addTearDown` (the framework asserts the foundation debug vars are
///    clear before tear-downs run).
///  * **`setSurfaceSize` does NOT move `MediaQuery.sizeOf`** — that reads
///    `view.physicalSize / devicePixelRatio`, left at the harness default. The
///    wide/narrow gate reads exactly that, so every width case here drives
///    `tester.view.physicalSize` instead. Using `setSurfaceSize` would leave
///    these passing at a width they never actually set.
class _FakeRouter extends ChangeNotifier {
  String path = '/';
  void go(String next) {
    path = next;
    notifyListeners();
  }
}

ThemeData _theme() => ThemeData.light().copyWith(
  extensions: <ThemeExtension<dynamic>>[InTheme.light],
);

const _kSegment = ValueKey('windowFrame.leadingSegment');

void main() {
  const channel = MethodChannel('invoice_ninja/native_window');
  late List<String> calls;
  late _FakeRouter router;
  late ValueNotifier<AuthSession?> session;
  late NavHistoryController history;
  late ValueNotifier<bool> railCollapsed;
  late ShellMountedNotifier shellMounted;
  late ScreenshotWindowController screenshot;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    router = _FakeRouter();
    session = ValueNotifier<AuthSession?>(
      AuthSession(
        baseUrl: 'https://example.com',
        isHosted: true,
        accountId: 'acc',
        companies: const [],
        currentCompanyId: 'co_1',
      ),
    );
    history = NavHistoryController(
      changes: router,
      currentPath: () => router.path,
      navigate: router.go,
      session: session,
    );
    railCollapsed = ValueNotifier<bool>(false);
    shellMounted = ShellMountedNotifier()..value = true;
    screenshot = ScreenshotWindowController();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    history.dispose();
    session.dispose();
    railCollapsed.dispose();
    shellMounted.dispose();
    NativeWindow.instance.chrome.value = const WindowChrome();
  });

  Widget frame({Widget? child}) =>
      ChangeNotifierProvider<NavHistoryController>.value(
        value: history,
        child: MaterialApp(
          theme: _theme(),
          home: WindowFrame(
            screenshotWindow: screenshot,
            railCollapsed: railCollapsed,
            shellMounted: shellMounted,
            child: child ?? const SizedBox.expand(key: ValueKey('body')),
          ),
        ),
      );

  /// Sets the *window* size the wide/narrow gate actually reads.
  void setWindow(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  Future<void> under(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  group('platform gate', () {
    for (final platform in [
      TargetPlatform.macOS,
      TargetPlatform.iOS,
      TargetPlatform.android,
    ]) {
      testWidgets('is a rect-identical passthrough on $platform', (
        tester,
      ) async {
        await under(platform, () async {
          setWindow(tester, const Size(1200, 800));
          await tester.pumpWidget(frame());

          // Not merely "no bar" — the child must occupy the frame's own box,
          // which is what makes this zero-cost rather than merely invisible.
          expect(
            tester.getRect(find.byKey(const ValueKey('body'))),
            tester.getRect(find.byType(WindowFrame)),
          );
          expect(find.byType(WindowControls), findsNothing);
        });
      });
    }

    for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
      testWidgets('paints a $platform band that pushes the child down', (
        tester,
      ) async {
        await under(platform, () async {
          setWindow(tester, const Size(1200, 800));
          await tester.pumpWidget(frame());

          expect(find.byType(WindowControls), findsOneWidget);
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
            kAppTitleBarHeight,
          );
        });
      });
    }
  });

  group('leading segment', () {
    testWidgets('matches the expanded rail width', (tester) async {
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        await tester.pumpWidget(frame());

        expect(tester.getSize(find.byKey(_kSegment)).width, kInSidebarWidth);
        expect(
          tester.getSize(find.byKey(_kSegment)).height,
          kAppTitleBarHeight,
        );
      });
    });

    testWidgets('follows the rail into its collapsed width', (tester) async {
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        await tester.pumpWidget(frame());
        railCollapsed.value = true;
        await tester.pump();

        expect(
          tester.getSize(find.byKey(_kSegment)).width,
          kInSidebarCollapsedWidth,
        );
      });
    });

    testWidgets('is absent with no shell — /login has no rail', (tester) async {
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        shellMounted.value = false;
        await tester.pumpWidget(frame());

        expect(find.byKey(_kSegment), findsNothing);
        // The band and the window buttons stay: those routes still need to be
        // movable and closable.
        expect(find.byType(WindowControls), findsOneWidget);
        expect(
          tester.getSize(find.byType(WindowFrame)).height,
          greaterThan(kAppTitleBarHeight),
        );
      });
    });

    testWidgets('splits on the same width the shell does', (tester) async {
      // The frame reads the window and the shell reads its own box; nothing
      // between them constrains width, so they must agree to the pixel. A
      // disagreement would paint a rail-coloured segment over a narrow layout
      // that has no rail.
      await under(TargetPlatform.windows, () async {
        setWindow(tester, Size(Breakpoints.wide, 800));
        await tester.pumpWidget(frame());
        expect(find.byKey(_kSegment), findsOneWidget);

        setWindow(tester, Size(Breakpoints.wide - 1, 800));
        await tester.pumpWidget(frame());
        expect(find.byKey(_kSegment), findsNothing);
      });
    });
  });

  group('nav arrows', () {
    testWidgets('sit just past the segment, clear of the app identity', (
      tester,
    ) async {
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        await tester.pumpWidget(frame());

        expect(find.byType(NavHistoryButtons), findsOneWidget);
        // Past the rail divider, at the same 10 inset the mark uses on the
        // other side of it. Inside the segment they would collide with the
        // wordmark once it grows at a large text scale.
        expect(
          tester.getTopLeft(find.byType(NavHistoryButtons)).dx,
          kInSidebarWidth + 10.0,
        );
        // Pinned to the band, not floored: a taller box would grow the bar.
        expect(
          tester.getSize(find.byType(NavHistoryButtons)).height,
          kAppTitleBarHeight,
        );
        // ...and they must not overlap the identity that now owns the segment.
        expect(
          tester.getTopLeft(find.byType(NavHistoryButtons)).dx,
          greaterThan(tester.getBottomRight(find.text('Invoice Ninja')).dx),
        );
      });
    });

    testWidgets('carry no tooltip — there is no Overlay above the router', (
      tester,
    ) async {
      // The bug this guards: `Tooltip` -> `RawTooltip` -> `OverlayPortal`
      // asserts in debug and throws on hover in release with no `Overlay`
      // ancestor, and `MaterialApp.builder` is above the root Navigator.
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        router.go('/clients');
        router.go('/clients/1');
        await tester.pumpWidget(frame());

        expect(history.canGoBack, isTrue, reason: 'need an enabled arrow');
        expect(
          find.descendant(
            of: find.byType(WindowFrame),
            matching: find.byType(Tooltip),
          ),
          findsNothing,
        );
        expect(find.bySemanticsLabel('go_back'), findsOneWidget);
      });
    });

    testWidgets('stay in the rail when it is collapsed or absent', (
      tester,
    ) async {
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        railCollapsed.value = true;
        await tester.pumpWidget(frame());
        expect(find.byType(NavHistoryButtons), findsNothing);

        railCollapsed.value = false;
        shellMounted.value = false;
        await tester.pump();
        expect(find.byType(NavHistoryButtons), findsNothing);
      });
    });
  });

  group('app identity', () {
    testWidgets('shows the mark and wordmark the OS caption used to', (
      tester,
    ) async {
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        await tester.pumpWidget(frame());

        expect(find.text('Invoice Ninja'), findsOneWidget);
        expect(find.byType(Image), findsOneWidget);
        // Leading edge, where a Windows caption puts it.
        expect(tester.getTopLeft(find.byType(Image)).dx, 10.0);
      });
    });

    testWidgets('drops the wordmark on the collapsed rail, keeps the mark', (
      tester,
    ) async {
      // 64 px has room for the icon and nothing else; ellipsizing the product
      // name to "In…" would be worse than omitting it.
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        railCollapsed.value = true;
        await tester.pumpWidget(frame());

        expect(find.byType(Image), findsOneWidget);
        expect(find.text('Invoice Ninja'), findsNothing);
      });
    });

    testWidgets('is present with no shell at all — /login has chrome too', (
      tester,
    ) async {
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        shellMounted.value = false;
        await tester.pumpWidget(frame());

        expect(find.text('Invoice Ninja'), findsOneWidget);
      });
    });

    testWidgets('absorbs no pointer — the mark is still a drag handle', (
      tester,
    ) async {
      // A title bar's own name has to drag the window. An Image and a Text
      // both decline the hit test, so the press falls through to the drag
      // layer beneath; anything tappable added here would break that.
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        await tester.pumpWidget(frame());

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Invoice Ninja')),
        );
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
        await gesture.up();
        await tester.pump(const Duration(seconds: 1));

        expect(calls, contains('startDrag'));
      });
    });
  });

  group('drag handle', () {
    testWidgets('a pan on the empty band drags the window', (tester) async {
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        await tester.pumpWidget(frame());

        // Middle of the band: past the rail segment, short of the buttons.
        // Targeted by coordinate rather than by widget — the frame's own centre
        // is in the body, well below the strip being tested.
        final gesture = await tester.startGesture(
          const Offset(600, kAppTitleBarHeight / 2),
        );
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
        await gesture.up();
        // The same GestureDetector carries onDoubleTap, whose recognizer arms a
        // timer on pointer-up; leave it pending and the harness fails the test
        // on a stray timer rather than on anything about the drag.
        await tester.pump(const Duration(seconds: 1));

        expect(calls, contains('startDrag'));
      });
    });

    testWidgets('a tap on an arrow navigates and does NOT drag', (
      tester,
    ) async {
      // The drag layer is first in the Stack so it hit-tests last; the arrows
      // above it must win outright rather than racing in the gesture arena.
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        router.go('/clients');
        router.go('/clients/1');
        await tester.pumpWidget(frame());

        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pump();

        expect(calls, isNot(contains('startDrag')));
        expect(router.path, '/clients');
      });
    });

    testWidgets('the rail-coloured segment drags too', (tester) async {
      // Regression: the segment is a DecoratedBox, and
      // RenderDecoratedBox.hitTestSelf returns `decoration.hitTest(...)` —
      // true anywhere inside a plain rectangle. It therefore swallowed every
      // press across the rail's 232 px, leaving that whole stretch of title
      // bar unable to drag the window. The other drag case probes the middle
      // of the band and cannot see it.
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        await tester.pumpWidget(frame());

        // Inside the segment, clear of both the wordmark and the arrows.
        final gesture = await tester.startGesture(
          const Offset(kInSidebarWidth - 8, kAppTitleBarHeight / 2),
        );
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump();
        await gesture.up();
        await tester.pump(const Duration(seconds: 1));

        expect(calls, contains('startDrag'));
      });
    });

    testWidgets('a right-click opens the OS window menu', (tester) async {
      // The band is client area once the frame is custom, so this never
      // reaches the runner as WM_NCRBUTTONUP — it has to be routed from Dart.
      // It is also the second recovery path if a drawn button ever fails.
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        await tester.pumpWidget(frame());

        final gesture = await tester.startGesture(
          const Offset(600, kAppTitleBarHeight / 2),
          buttons: kSecondaryButton,
        );
        await gesture.up();
        await tester.pump(const Duration(seconds: 1));

        expect(calls, contains('showSystemMenu'));
      });
    });

    testWidgets('a tap on a window button does NOT drag', (tester) async {
      await under(TargetPlatform.windows, () async {
        setWindow(tester, const Size(1200, 800));
        await tester.pumpWidget(frame());

        await tester.tap(find.byKey(const ValueKey('windowControls.close')));
        await tester.pump();

        expect(calls, contains('close'));
        expect(calls, isNot(contains('startDrag')));
      });
    });
  });

  testWidgets('the band is unchanged when maximized or fullscreen', (
    tester,
  ) async {
    // "Fullscreen" on Windows means maximized — there is no F11 mechanism (see
    // docs/desktop-window-state.md), and the runner always reports
    // fullscreen:false. A window manager CAN fullscreen the Linux window,
    // though, and the band deliberately stays: it is the only window chrome
    // left, so hiding it could strand someone who does not know their WM's
    // keybinding. Either way the layout must not shift.
    await under(TargetPlatform.windows, () async {
      setWindow(tester, const Size(1200, 800));
      await tester.pumpWidget(frame());
      final normalBodyTop = tester
          .getTopLeft(find.byKey(const ValueKey('body')))
          .dy;

      NativeWindow.instance.chrome.value = const WindowChrome(
        maximized: true,
        fullscreen: true,
      );
      await tester.pump();

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
        normalBodyTop,
      );
      expect(tester.getSize(find.byKey(_kSegment)).width, kInSidebarWidth);
      expect(find.text('Invoice Ninja'), findsOneWidget);
      expect(find.byType(NavHistoryButtons), findsOneWidget);
      // ...and the middle glyph offers "restore", not "maximize".
      expect(
        find.byKey(const ValueKey('windowControls.restore')),
        findsOneWidget,
      );
    });
  });

  testWidgets('a screenshot hides the buttons but KEEPS the band', (
    tester,
  ) async {
    // The macOS strip collapses here because it exists only to reserve room
    // for the OS buttons. This band is app layout that also hosts the arrows,
    // so collapsing it would drop them entirely and shift the page.
    await under(TargetPlatform.windows, () async {
      setWindow(tester, const Size(1200, 800));
      await tester.pumpWidget(frame());
      await screenshot.setWindowButtonsHidden(true);
      await tester.pump();

      expect(find.byKey(const ValueKey('windowControls.close')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
        kAppTitleBarHeight,
      );
      expect(find.byType(NavHistoryButtons), findsOneWidget);
    });
  });

  testWidgets('shellMounted may be flipped from inside a build', (
    tester,
  ) async {
    // The writer (`ScaffoldWithNav.initState`) is a DESCENDANT of this widget,
    // and the frame has already been built for the frame in which it runs — so
    // a synchronous notify here is "setState() called during build" every
    // time, not occasionally. A non-deferring notifier fails this test.
    await under(TargetPlatform.windows, () async {
      setWindow(tester, const Size(1200, 800));
      shellMounted.value = false;
      await tester.pumpWidget(
        frame(
          child: Builder(
            builder: (_) {
              shellMounted.value = true;
              return const SizedBox.expand(key: ValueKey('body'));
            },
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.pump();
      expect(find.byKey(_kSegment), findsOneWidget);
    });
  });

  testWidgets('the band holds its height at 1.4x text scale', (tester) async {
    await under(TargetPlatform.windows, () async {
      setWindow(tester, const Size(1200, 800));
      await tester.pumpWidget(
        ChangeNotifierProvider<NavHistoryController>.value(
          value: history,
          child: MaterialApp(
            theme: _theme(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: WindowFrame(
                screenshotWindow: screenshot,
                railCollapsed: railCollapsed,
                shellMounted: shellMounted,
                child: const SizedBox.expand(key: ValueKey('body')),
              ),
            ),
          ),
        ),
      );

      expect(
        tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
        kAppTitleBarHeight,
      );
    });
  });
}
