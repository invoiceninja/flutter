import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/mobile_app_promo_controller.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/mobile_app_promo.dart';
import 'package:admin/ui/core/widgets/qr_code_image.dart';
import 'package:admin/ui/features/mobile_promo/mobile_app_promo_dialog.dart';

import '../../../_localization_helper.dart';

const _ios = [MobilePromoTarget.ios];
const _both = [MobilePromoTarget.ios, MobilePromoTarget.android];

const _selfHosted = MobilePromoAccount(
  email: 'me@example.com',
  serverUrl: 'http://192.168.1.20',
  privateNetwork: true,
  providerGaps: {MobilePromoTarget.android: 'apple'},
);

/// Opens the dialog the way the app does — through `showDialog` — so the
/// result each button pops with is observable.
class _Harness {
  Future<MobilePromoResult?>? result;
  late MobileAppPromoController controller;

  Future<void> open(
    WidgetTester tester, {
    List<MobilePromoTarget> targets = _ios,
    MobilePromoPresentation presentation = MobilePromoPresentation.qr,
    MobilePromoAccount account = const MobilePromoAccount(email: 'me@x.com'),
    bool isManual = false,
    MobileAppPromoState state = const MobileAppPromoState(),
    Size size = const Size(1280, 900),
    double textScale = 1,
    bool arm = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = DevicePrefsStore(null);
    controller = MobileAppPromoController(prefs: prefs);
    addTearDown(controller.dispose);
    // Seed the schedule (e.g. two closes already) without a public setter.
    for (var i = 0; i < state.closes; i++) {
      await controller.snooze(DateTime.utc(2026, 10, 14, 12));
    }
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => result = showDialog<MobilePromoResult>(
                  context: context,
                  // As `showMobileAppPromoDialog` opens it — which is what
                  // switches off the route's own Esc.
                  barrierDismissible: false,
                  builder: (_) => MobileAppPromoDialog(
                    targets: targets,
                    presentation: presentation,
                    account: account,
                    controller: controller,
                    isManual: isManual,
                    onSetPassword: () {},
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    if (arm) await tester.pump(const Duration(milliseconds: 300));
  }
}

String _qrData(WidgetTester tester) =>
    tester.widget<QrCodeImage>(find.byType(QrCodeImage)).data;

/// Every string the dialog shows or speaks: text, tooltips and semantics.
List<String> _everything(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    t.data ?? t.textSpan?.toPlainText() ?? '',
  for (final t in tester.widgetList<RichText>(find.byType(RichText)))
    t.text.toPlainText(),
  for (final t in tester.widgetList<Tooltip>(find.byType(Tooltip)))
    t.message ?? '',
  for (final s in tester.widgetList<Semantics>(find.byType(Semantics)))
    s.properties.label ?? '',
  for (final q in tester.widgetList<QrCodeImage>(find.byType(QrCodeImage)))
    q.semanticsLabel ?? '',
];

void main() {
  group('native macOS (App Review 2.3.10)', () {
    testWidgets('names no other platform anywhere — text, tooltip, semantics, '
        'QR code or copied link', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final h = _Harness();
      await h.open(tester, account: _selfHosted);

      expect(find.byType(SegmentedButton<MobilePromoTarget>), findsNothing);
      expect(_qrData(tester), kMobileAppIosUrl);
      expect(find.text('Scan with your iPhone or iPad camera'), findsOneWidget);

      void expectNoOtherPlatform(String step) {
        final shown = _everything(tester);
        expect(shown, isNotEmpty);
        for (final s in shown) {
          expect(s, isNot(contains('Android')), reason: '$step: $s');
          expect(s, isNot(contains('Google Play')), reason: '$step: $s');
          expect(s, isNot(contains(kMobileAppAndroidUrl)), reason: step);
        }
      }

      // The QR step: captions, the TestFlight line, the QR code's label.
      expect(find.textContaining('TestFlight'), findsOneWidget);
      expectNoOtherPlatform('QR step');
      expect(
        find.text('BETA'),
        findsNothing,
        reason: 'the Mac app must not read as calling itself a beta (2.2)',
      );

      await tester.tap(find.text('Copy Link'));
      await tester.pump();
      expect(copied, [kMobileAppIosUrl]);
      expect(h.controller.state.engaged, isTrue);

      // The sign-in step: the Apple gap is Android-only, so it is silent.
      await tester.tap(find.text("I've installed it"));
      await tester.pump();
      expectNoOtherPlatform('sign-in step');
    });
  });

  group('desktop with both phones', () {
    testWidgets('the toggle swaps the QR code and its captions', (
      tester,
    ) async {
      await _Harness().open(tester, targets: _both);
      expect(find.text('BETA'), findsOneWidget);
      expect(_qrData(tester), kMobileAppIosUrl);
      expect(find.text('Scan with your iPhone camera'), findsOneWidget);
      expect(find.textContaining('TestFlight'), findsOneWidget);

      await tester.tap(find.text('Android app'));
      await tester.pump();
      expect(_qrData(tester), kMobileAppAndroidUrl);
      expect(
        find.text("Scan with your Android phone's camera"),
        findsOneWidget,
      );
      expect(find.textContaining('Become a tester'), findsOneWidget);
    });

    testWidgets('the phone picture shows only when there is height to '
        'spare, so the QR code never drops below the fold', (tester) async {
      await _Harness().open(tester, targets: _both);
      expect(find.byType(Image), findsOneWidget);

      await _Harness().open(
        tester,
        targets: _both,
        size: const Size(1280, 700),
      );
      expect(find.byType(Image), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });

  testWidgets('a phone browser gets a store button and no QR code', (
    tester,
  ) async {
    await _Harness().open(
      tester,
      presentation: MobilePromoPresentation.storeButton,
      size: const Size(400, 800),
    );
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Download the iPhone app'), findsOneWidget);
  });

  testWidgets('"I\'ve installed it" says how to sign in, and Done ends the '
      'promo', (tester) async {
    final h = _Harness();
    await h.open(tester, targets: _both, account: _selfHosted);
    await tester.tap(find.text('Android app'));
    await tester.pump();
    await tester.tap(find.text("I've installed it"));
    await tester.pump();

    expect(h.controller.state.engaged, isTrue);
    expect(find.text('Sign in on your phone'), findsOneWidget);
    expect(find.text('me@example.com'), findsOneWidget);
    expect(find.text('http://192.168.1.20'), findsOneWidget);
    expect(find.textContaining('same network'), findsOneWidget);
    expect(find.textContaining('You sign in here with Apple'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(await h.result, MobilePromoResult.done);
    expect(h.controller.state.done, isTrue);
  });

  group('footer', () {
    testWidgets('an early automatic open offers a reminder and a way out', (
      tester,
    ) async {
      final h = _Harness();
      await h.open(tester);
      expect(find.text("Don't show again"), findsOneWidget);
      await tester.tap(find.text('Remind me later'));
      await tester.pumpAndSettle();
      expect(await h.result, MobilePromoResult.snoozed);
    });

    testWidgets("don't show again ends it for good", (tester) async {
      final h = _Harness();
      await h.open(tester);
      await tester.tap(find.text("Don't show again"));
      await tester.pumpAndSettle();
      expect(await h.result, MobilePromoResult.dismissed);
      expect(h.controller.state.done, isTrue);
    });

    testWidgets('the last reminder is just Close — no second button for the '
        'same answer', (tester) async {
      await _Harness().open(
        tester,
        state: const MobileAppPromoState(closes: 2),
      );
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Remind me later'), findsNothing);
      expect(find.text("Don't show again"), findsNothing);
    });

    testWidgets('a manual open never snoozes, but can still retire the '
        'sidebar card', (tester) async {
      await _Harness().open(tester, isManual: true);
      expect(find.text('Close'), findsOneWidget);
      expect(find.text('Remind me later'), findsNothing);
      expect(find.text("Don't show again"), findsOneWidget);
    });

    testWidgets('the ✕ is a full touch target', (tester) async {
      await _Harness().open(tester);
      final close = find.byTooltip('Close');
      expect(tester.getSize(close).height, greaterThanOrEqualTo(44));
    });
  });

  testWidgets('after "I\'ve installed it", Enter is Done', (tester) async {
    final h = _Harness();
    await h.open(tester);
    await tester.tap(find.text("I've installed it"));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(await h.result, MobilePromoResult.done);
  });

  group('Esc', () {
    testWidgets('closes it, as a snooze — although the barrier is not '
        'dismissible', (tester) async {
      final h = _Harness();
      await h.open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Invoice Ninja on your phone'), findsNothing);
      expect(await h.result, MobilePromoResult.snoozed);
    });

    testWidgets('after taking the app, closes it as engaged', (tester) async {
      final h = _Harness();
      await h.open(tester);
      await tester.tap(find.text("I've installed it"));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(await h.result, MobilePromoResult.engaged);
    });

    testWidgets('is ignored in the first half-second', (tester) async {
      final h = _Harness();
      await h.open(tester, arm: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Invoice Ninja on your phone'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(await h.result, MobilePromoResult.snoozed);
    });
  });

  testWidgets('a window just under the two-column width takes the single '
      'column, without overflow', (tester) async {
    // 720 of columns plus 40-px insets either side need 800.
    await _Harness().open(tester, targets: _both, size: const Size(780, 900));
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing, reason: 'single column');
  });

  testWidgets('a click or key press in the first half-second is ignored', (
    tester,
  ) async {
    final h = _Harness();
    await h.open(tester, arm: false);
    await tester.tap(find.text('Remind me later'));
    await tester.pump();
    expect(find.text('Remind me later'), findsOneWidget, reason: 'still open');

    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Remind me later'));
    await tester.pumpAndSettle();
    expect(await h.result, MobilePromoResult.snoozed);
  });

  testWidgets('large text on a narrow window lays out without overflow', (
    tester,
  ) async {
    await _Harness().open(
      tester,
      targets: _both,
      account: _selfHosted,
      size: const Size(390, 760),
      textScale: 1.4,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text("I've installed it"));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
