import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/debug_capture_store.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/screenshot_window_controller.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/features/settings/views/advanced/debug_panel_section.dart';

import '../../../_localization_helper.dart';
import '../../../_responsive_helper.dart';

void main() {
  const channel = MethodChannel('invoice_ninja/native_window');
  late List<MethodCall> calls;

  final onMacOS = TargetPlatformVariant.only(TargetPlatform.macOS);
  final onAndroid = TargetPlatformVariant.only(TargetPlatform.android);

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'setContentSize') {
            final args = call.arguments as Map<Object?, Object?>;
            return {'width': args['width'], 'height': args['height']};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Widget buildPanel(ScreenshotWindowController controller) {
    // The panel's Column contains Expanded, so it needs the bounded height a
    // real band gives it; Align keeps the loose width of a Scaffold body.
    return Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        height: 480,
        child: DebugPanelSection(
          store: DebugCaptureStore(),
          windowController: controller,
          onHide: () {},
        ),
      ),
    );
  }

  List<MethodCall> sizeCalls() =>
      calls.where((c) => c.method == 'setContentSize').toList();

  testWidgets('no overflow across widths with desktop controls', (
    tester,
  ) async {
    final controller = ScreenshotWindowController();
    for (final width in [320.0, 360.0, 500.0, 800.0, 1200.0]) {
      await pumpAt(tester, width, buildPanel(controller), scroll: false);
      expectNoOverflow(tester);
    }
    expect(find.byIcon(Icons.aspect_ratio), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera), findsOneWidget);
  }, variant: onMacOS);

  testWidgets('no overflow across widths on mobile, controls hidden', (
    tester,
  ) async {
    final controller = ScreenshotWindowController();
    for (final width in [320.0, 360.0, 500.0, 800.0, 1200.0]) {
      await pumpAt(tester, width, buildPanel(controller), scroll: false);
      expectNoOverflow(tester);
    }
    expect(find.byIcon(Icons.aspect_ratio), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    // The capture button is all-platforms, unlike the desktop-only size tools.
    expect(find.byIcon(Icons.photo_camera), findsOneWidget);
  }, variant: onAndroid);

  testWidgets('renders without a Scaffold/Material ancestor (mobile shell)', (
    tester,
  ) async {
    // The narrow shell hosts the band in a bare Column with no Scaffold above
    // it, so the panel must supply its own Material. Regression for the
    // "No Material widget found" crash on phones — built directly here because
    // the shared `pumpAt` harness wraps everything in a Scaffold and so masks
    // the bug.
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Center(
          child: SizedBox(
            width: 390,
            height: 480,
            child: DebugPanelSection(
              store: DebugCaptureStore(),
              windowController: ScreenshotWindowController(),
              onHide: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Switch), findsOneWidget);
  }, variant: onAndroid);

  testWidgets('toolbar stacks into two rows when narrow', (tester) async {
    final controller = ScreenshotWindowController();

    await pumpAt(tester, 360, buildPanel(controller), scroll: false);
    final narrowClose = tester.getCenter(find.byIcon(Icons.close));
    final narrowCopy = tester.getCenter(find.byIcon(Icons.copy_outlined));
    expect(
      narrowClose.dy,
      lessThan(narrowCopy.dy),
      reason: 'close stays in the top row, actions drop to the second row',
    );

    await pumpAt(tester, 1200, buildPanel(controller), scroll: false);
    final wideClose = tester.getCenter(find.byIcon(Icons.close));
    final wideCopy = tester.getCenter(find.byIcon(Icons.copy_outlined));
    expect(wideClose.dy, wideCopy.dy, reason: 'single toolbar row when wide');
  }, variant: onMacOS);

  testWidgets('preset tap sends px ÷ devicePixelRatio to the channel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScreenshotWindowController();

    await pumpAt(tester, 900, buildPanel(controller), scroll: false);
    await tester.tap(find.byIcon(Icons.aspect_ratio));
    await tester.pumpAndSettle();

    expect(find.text('Mac App Store'), findsOneWidget);
    expect(find.text('Google Play'), findsOneWidget);
    expect(find.text('Custom size…'), findsOneWidget);
    // Re-keyed Android labels render (device + orientation + dimensions).
    expect(
      find.text('10" tablet portrait (compact) — 1080 × 1920'),
      findsOneWidget,
    );
    expect(find.text('7" tablet landscape — 2560 × 1440'), findsOneWidget);

    await tester.tap(find.text('1280 × 800'));
    await tester.pumpAndSettle();

    expect(sizeCalls(), hasLength(1));
    expect(sizeCalls().single.arguments, {'width': 640.0, 'height': 400.0});
    expect(controller.appliedSizePx, (width: 1280, height: 800));
  }, variant: onMacOS);

  testWidgets('window buttons toggle drives the controller', (tester) async {
    final controller = ScreenshotWindowController();
    await pumpAt(tester, 900, buildPanel(controller), scroll: false);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();
    expect(controller.windowButtonsHidden, isTrue);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(
      calls.where((c) => c.method == 'setWindowButtonsHidden').single.arguments,
      {'hidden': true},
    );
  }, variant: onMacOS);

  testWidgets('custom size dialog validates and applies through the channel', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = ScreenshotWindowController();

    await pumpAt(tester, 900, buildPanel(controller), scroll: false);
    await tester.tap(find.byIcon(Icons.aspect_ratio));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Custom size…'));
    await tester.pumpAndSettle();

    final widthField = find.widgetWithText(TextField, 'Width (px)');
    final heightField = find.widgetWithText(TextField, 'Height (px)');
    final applyButton = find.widgetWithText(FilledButton, 'Apply');
    expect(widthField, findsOneWidget);
    expect(heightField, findsOneWidget);

    // Out-of-range input disables Apply.
    await tester.enterText(widthField, '50');
    await tester.pump();
    expect(tester.widget<FilledButton>(applyButton).onPressed, isNull);

    // Digits-only: letters are filtered out, leaving the field empty.
    await tester.enterText(widthField, 'abc');
    await tester.pump();
    expect(tester.widget<TextField>(widthField).controller!.text, isEmpty);

    await tester.enterText(widthField, '2000');
    await tester.enterText(heightField, '1200');
    await tester.pump();
    expect(tester.widget<FilledButton>(applyButton).onPressed, isNotNull);

    // Enter in the height field submits via FormSaveScope.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(sizeCalls(), hasLength(1));
    expect(sizeCalls().single.arguments, {'width': 1000.0, 'height': 600.0});
    expect(controller.appliedSizePx, (width: 2000, height: 1200));
  }, variant: onMacOS);

  testWidgets('errors tab level filter stays usable at 320', (tester) async {
    final controller = ScreenshotWindowController();
    await pumpAt(tester, 320, buildPanel(controller), scroll: false);

    // The counted tab labels exceed 320 px — the TabBar must scroll (it is
    // isScrollable when narrow) to reach the second tab.
    await tester.drag(find.byType(TabBar), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Recent Errors'));
    await tester.pumpAndSettle();
    expectNoOverflow(tester);
    expect(find.text('Warning+'), findsOneWidget);
  }, variant: onAndroid);
}
