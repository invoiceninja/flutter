import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/screenshot_window_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('invoice_ninja/native_window');
  late List<MethodCall> calls;

  /// Installs a channel mock; [contentSizeAnswer] overrides the echo default
  /// for `setContentSize` (return null to simulate a runner without a reply).
  void mockChannel({
    Object? Function(Map<Object?, Object?> args)? contentSizeAnswer,
  }) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'setContentSize') {
            final args = call.arguments as Map<Object?, Object?>;
            if (contentSizeAnswer != null) return contentSizeAnswer(args);
            return {'width': args['width'], 'height': args['height']};
          }
          return null;
        });
  }

  setUp(() {
    calls = [];
    // Env.isDesktop gates the channel; widget tests default to android.
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    mockChannel();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  List<MethodCall> sizeCalls() =>
      calls.where((c) => c.method == 'setContentSize').toList();

  test('divides physical px by devicePixelRatio for the native call', () async {
    final controller = ScreenshotWindowController();
    final result = await controller.applySizePx(
      widthPx: 2880,
      heightPx: 1800,
      devicePixelRatio: 2.0,
      currentLogicalSize: const Size(1200, 800),
    );

    expect(sizeCalls(), hasLength(1));
    expect(sizeCalls().single.arguments, {'width': 1440.0, 'height': 900.0});
    expect(result.achievedPx, (width: 2880, height: 1800));
    expect(result.matched, isTrue);
    expect(controller.appliedSizePx, (width: 2880, height: 1800));
    expect(controller.canRestoreOriginalSize, isTrue);
  });

  test('sends exact doubles when px are not divisible by the ratio', () async {
    final controller = ScreenshotWindowController();
    await controller.applySizePx(
      widthPx: 1085,
      heightPx: 763,
      devicePixelRatio: 2.0,
      currentLogicalSize: const Size(1200, 800),
    );

    expect(sizeCalls().single.arguments, {'width': 542.5, 'height': 381.5});
  });

  test('reports a mismatch when the native side clamps the frame', () async {
    mockChannel(contentSizeAnswer: (_) => {'width': 1000.0, 'height': 700.0});
    final controller = ScreenshotWindowController();
    final result = await controller.applySizePx(
      widthPx: 2880,
      heightPx: 1800,
      devicePixelRatio: 2.0,
      currentLogicalSize: const Size(1200, 800),
    );

    expect(result.achievedPx, (width: 2000, height: 1400));
    expect(result.matched, isFalse);
    // The selection still records what the user asked for.
    expect(controller.appliedSizePx, (width: 2880, height: 1800));
  });

  test('tolerates 1 device px of fractional-DPR rounding', () async {
    mockChannel(contentSizeAnswer: (_) => {'width': 639.5, 'height': 399.5});
    final controller = ScreenshotWindowController();
    final result = await controller.applySizePx(
      widthPx: 1280,
      heightPx: 800,
      devicePixelRatio: 2.0,
      currentLogicalSize: const Size(1200, 800),
    );

    expect(result.achievedPx, (width: 1279, height: 799));
    expect(result.matched, isTrue);
  });

  test(
    'captures the original size on the first apply only and restores it',
    () async {
      final controller = ScreenshotWindowController();
      await controller.applySizePx(
        widthPx: 1280,
        heightPx: 800,
        devicePixelRatio: 2.0,
        currentLogicalSize: const Size(1200, 750),
      );
      // Second apply passes the now-resized window size; it must not replace
      // the restore target.
      await controller.applySizePx(
        widthPx: 1080,
        heightPx: 1920,
        devicePixelRatio: 2.0,
        currentLogicalSize: const Size(640, 400),
      );

      await controller.restoreOriginalSize();

      expect(sizeCalls(), hasLength(3));
      expect(sizeCalls().last.arguments, {'width': 1200.0, 'height': 750.0});
      expect(controller.appliedSizePx, isNull);
      expect(controller.canRestoreOriginalSize, isFalse);

      // Apply → restore keeps working on later cycles.
      await controller.applySizePx(
        widthPx: 1440,
        heightPx: 900,
        devicePixelRatio: 2.0,
        currentLogicalSize: const Size(1200, 750),
      );
      await controller.restoreOriginalSize();
      expect(sizeCalls().last.arguments, {'width': 1200.0, 'height': 750.0});
    },
  );

  test('setWindowButtonsHidden sends the flag and notifies', () async {
    final controller = ScreenshotWindowController();
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setWindowButtonsHidden(true);
    expect(controller.windowButtonsHidden, isTrue);
    expect(notified, 1);
    expect(
      calls.where((c) => c.method == 'setWindowButtonsHidden').single.arguments,
      {'hidden': true},
    );

    // No-op when unchanged.
    await controller.setWindowButtonsHidden(true);
    expect(notified, 1);
    expect(
      calls.where((c) => c.method == 'setWindowButtonsHidden'),
      hasLength(1),
    );
  });

  test(
    'a channel error leaves state untouched and reports no achieved size',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            throw PlatformException(code: 'bad_args');
          });
      final controller = ScreenshotWindowController();
      final result = await controller.applySizePx(
        widthPx: 1280,
        heightPx: 800,
        devicePixelRatio: 2.0,
        currentLogicalSize: const Size(1200, 800),
      );

      expect(result.achievedPx, isNull);
      expect(result.matched, isFalse);
      expect(controller.appliedSizePx, isNull);
      expect(controller.canRestoreOriginalSize, isFalse);
    },
  );

  test('does not touch the channel off desktop', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final controller = ScreenshotWindowController();
    final result = await controller.applySizePx(
      widthPx: 1280,
      heightPx: 800,
      devicePixelRatio: 2.0,
      currentLogicalSize: const Size(1200, 800),
    );
    await controller.setWindowButtonsHidden(true);

    expect(result.achievedPx, isNull);
    expect(controller.appliedSizePx, isNull);
    expect(calls, isEmpty);
  });

  group('preset validity', () {
    final allPresets = kScreenshotPresetGroups
        .expand((g) => g.presets)
        .toList();

    bool isRatio(ScreenshotPreset p, double ratio) =>
        (p.widthPx / p.heightPx - ratio).abs() < 0.001;

    test('Mac App Store presets are the four 16:10 store sizes', () {
      final mac = kScreenshotPresetGroups
          .firstWhere((g) => g.labelKey == 'mac_app_store')
          .presets;
      expect(
        mac.map((p) => (p.widthPx, p.heightPx)),
        containsAll(<(int, int)>[
          (1280, 800),
          (1440, 900),
          (2560, 1600),
          (2880, 1800),
        ]),
      );
      for (final p in mac) {
        expect(
          isRatio(p, 16 / 10),
          isTrue,
          reason: '${p.dimensionLabel} is not 16:10',
        );
      }
    });

    test('every Google Play preset is 16:9 or 9:16 within its slot bounds', () {
      final play = kScreenshotPresetGroups
          .firstWhere((g) => g.labelKey == 'google_play')
          .presets;
      for (final p in play) {
        final landscape = isRatio(p, 16 / 9);
        final portrait = isRatio(p, 9 / 16);
        expect(
          landscape || portrait,
          isTrue,
          reason:
              '${p.descriptionKey} (${p.dimensionLabel}) '
              'is neither 16:9 nor 9:16',
        );

        // 10″ tablet: 1080–7680 px/side; phone + 7″: 320–3840 px/side.
        final is10Inch = p.descriptionKey!.startsWith('tablet_10_inch');
        final minSide = is10Inch ? 1080 : 320;
        final maxSide = is10Inch ? 7680 : 3840;
        for (final side in [p.widthPx, p.heightPx]) {
          expect(
            side,
            inInclusiveRange(minSide, maxSide),
            reason:
                '${p.descriptionKey} side $side outside '
                '[$minSide, $maxSide]',
          );
        }
      }
    });

    test('description keys are present and unique', () {
      final keys = kScreenshotPresetGroups
          .firstWhere((g) => g.labelKey == 'google_play')
          .presets
          .map((p) => p.descriptionKey)
          .toList();
      expect(keys, everyElement(isNotNull));
      expect(keys.toSet(), hasLength(keys.length));
    });

    test('no preset uses the rejected 5:8 ratio', () {
      for (final p in allPresets) {
        expect(
          isRatio(p, 5 / 8),
          isFalse,
          reason: '${p.dimensionLabel} is 5:8 — Play rejects it',
        );
      }
    });
  });

  group('visibleScreenshotPresetGroups', () {
    List<String> labels({
      required bool isWeb,
      required bool isRelease,
      required TargetPlatform platform,
    }) => [
      for (final g in visibleScreenshotPresetGroups(
        isWeb: isWeb,
        isRelease: isRelease,
        platform: platform,
      ))
        g.labelKey,
    ];

    test('a release Mac build never names Google Play (App Review 2.3.10)', () {
      expect(
        labels(isWeb: false, isRelease: true, platform: TargetPlatform.macOS),
        isNot(contains('google_play')),
      );
    });

    test('every other build keeps every group — a debug Mac run is where '
        'the store screenshots are captured', () {
      final all = [for (final g in kScreenshotPresetGroups) g.labelKey];
      for (final (isWeb, isRelease, platform) in [
        (false, false, TargetPlatform.macOS),
        (false, true, TargetPlatform.windows),
        (false, true, TargetPlatform.linux),
        (true, true, TargetPlatform.macOS),
      ]) {
        expect(
          labels(isWeb: isWeb, isRelease: isRelease, platform: platform),
          all,
          reason: '$platform web=$isWeb release=$isRelease',
        );
      }
    });
  });
}
