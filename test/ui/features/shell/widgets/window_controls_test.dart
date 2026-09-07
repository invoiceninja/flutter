import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/native_window.dart';
import 'package:admin/app/screenshot_window_controller.dart';
import 'package:admin/ui/features/shell/widgets/window_controls.dart';

/// The drawn min/max/close cluster for the frameless Windows and Linux
/// runners. None of this is observable on this dev machine (neither runner can
/// be built here), so the geometry, the state-tracking and the channel wiring
/// are pinned here instead.
///
/// `context.tr` falls back to the raw key with no `Localization` ancestor, so
/// the semantics labels below are asserted as keys — which is also stabler than
/// asserting English copy.
ThemeData _theme() => ThemeData.light().copyWith(
  extensions: <ThemeExtension<dynamic>>[InTheme.light],
);

Widget _wrap(Widget child) => MaterialApp(
  theme: _theme(),
  home: Scaffold(body: child),
);

const _kMin = ValueKey('windowControls.minimize');
const _kMax = ValueKey('windowControls.maximize');
const _kRestore = ValueKey('windowControls.restore');
const _kClose = ValueKey('windowControls.close');

Color _fillOf(WidgetTester tester, Key key) => tester
    .widget<ColoredBox>(
      find.descendant(of: find.byKey(key), matching: find.byType(ColoredBox)),
    )
    .color;

void main() {
  const channel = MethodChannel('invoice_ninja/native_window');
  late List<String> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    NativeWindow.instance.chrome.value = const WindowChrome();
  });

  Widget controls(ScreenshotWindowController c) =>
      _wrap(WindowControls(controller: c, height: kAppTitleBarHeight));

  testWidgets('renders three buttons at the Windows caption metric', (
    tester,
  ) async {
    await tester.pumpWidget(controls(ScreenshotWindowController()));

    for (final key in [_kMin, _kMax, _kClose]) {
      expect(find.byKey(key), findsOneWidget, reason: '$key');
      expect(
        tester.getSize(find.byKey(key)),
        const Size(kWindowControlWidth, kAppTitleBarHeight),
        reason: '$key',
      );
    }
    // Physical order, left to right, and never reversed for RTL.
    final minX = tester.getTopLeft(find.byKey(_kMin)).dx;
    final maxX = tester.getTopLeft(find.byKey(_kMax)).dx;
    final closeX = tester.getTopLeft(find.byKey(_kClose)).dx;
    expect(minX, lessThan(maxX));
    expect(maxX, lessThan(closeX));
  });

  testWidgets('each button invokes its own native method', (tester) async {
    // The platform override is load-bearing, not decoration: every
    // `NativeWindow` method early-returns unless `Env.isDesktop`, and
    // `flutter test` forces `TargetPlatform.android`. Without this the taps
    // land, the widget looks fine, and not one call reaches the channel.
    // Reset in a `finally`, never `addTearDown` — the framework asserts the
    // foundation debug vars are clear before tear-downs run.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await tester.pumpWidget(controls(ScreenshotWindowController()));

      await tester.tap(find.byKey(_kMin));
      await tester.tap(find.byKey(_kMax));
      await tester.tap(find.byKey(_kClose));
      await tester.pump();

      expect(calls, ['minimize', 'toggleMaximize', 'close']);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('the middle glyph tracks the pushed maximized state', (
    tester,
  ) async {
    await tester.pumpWidget(controls(ScreenshotWindowController()));
    expect(find.byKey(_kMax), findsOneWidget);
    expect(find.byKey(_kRestore), findsNothing);

    // Pushed, never inferred: Aero Snap and Win+Up change this without any tap.
    NativeWindow.instance.chrome.value = const WindowChrome(maximized: true);
    await tester.pump();

    expect(find.byKey(_kMax), findsNothing);
    expect(find.byKey(_kRestore), findsOneWidget);
  });

  testWidgets('the cluster hides for a clean screenshot', (tester) async {
    final controller = ScreenshotWindowController();
    await tester.pumpWidget(controls(controller));
    expect(find.byKey(_kClose), findsOneWidget);

    await controller.setWindowButtonsHidden(true);
    await tester.pump();

    expect(find.byKey(_kClose), findsNothing);
    // The BAND is the frame's business, not this widget's — the cluster only
    // removes itself. (`WindowFrame` keeps the band, unlike the macOS strip.)
    expect(tester.getSize(find.byType(WindowControls)).height, 0);
  });

  testWidgets('close hovers red while its neighbour hovers neutral', (
    tester,
  ) async {
    await tester.pumpWidget(controls(ScreenshotWindowController()));
    expect(_fillOf(tester, _kClose), Colors.transparent);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    await mouse.moveTo(tester.getCenter(find.byKey(_kClose)));
    await tester.pump();
    expect(_fillOf(tester, _kClose), kWindowCloseHoverColor);

    await mouse.moveTo(tester.getCenter(find.byKey(_kMin)));
    await tester.pump();
    // Neutral, and derived from the ink token so it inverts in dark mode.
    expect(_fillOf(tester, _kClose), Colors.transparent);
    expect(_fillOf(tester, _kMin), isNot(kWindowCloseHoverColor));
    expect(_fillOf(tester, _kMin), isNot(Colors.transparent));
  });

  testWidgets('an inactive window dims its glyphs', (tester) async {
    await tester.pumpWidget(controls(ScreenshotWindowController()));
    final active = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byKey(_kClose),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter;

    NativeWindow.instance.chrome.value = const WindowChrome(active: false);
    await tester.pump();

    final inactive = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byKey(_kClose),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter;
    // `shouldRepaint` compares glyph and colour, and the glyph is unchanged —
    // so this is true iff the colour moved. (An `expect(inactive, isNot(active))`
    // beside it would be worse than nothing: the painter declares no
    // `operator ==`, so two instances are never equal and it could not fail.)
    expect(inactive!.shouldRepaint(active!), isTrue);
  });

  testWidgets('every button is an ACTIVATABLE labelled node', (tester) async {
    // Not just `find.bySemanticsLabel`, which proves a node carries the label
    // and nothing about whether it can be tapped. The custom frame has already
    // removed the system title bar's UIA / AT-SPI landmark, so these three are
    // the only accessible route left to minimise, maximise or close the window
    // — a labelled node with no tap action is a dead button. Same assertion,
    // for the same reason, as `party_call_button_test.dart`.
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(controls(ScreenshotWindowController()));

    // Keys, not English — see the file doc. These are the real l10n keys.
    for (final entry in {
      _kMin: 'minimize',
      _kMax: 'maximize',
      _kClose: 'close',
    }.entries) {
      final node = tester.getSemantics(find.byKey(entry.key));
      expect(node.label, contains(entry.value), reason: '${entry.key}');
      expect(
        node.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
        reason: '${entry.key}: a labelled node with no tap action is dead',
      );
    }
    handle.dispose();
  });
}
