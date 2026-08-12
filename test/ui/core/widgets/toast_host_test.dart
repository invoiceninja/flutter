import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';
import 'package:admin/ui/core/widgets/toast_host.dart';

/// Theme carrying the `InTheme` extension the card reads, without
/// `buildInTheme` (which kicks off a GoogleFonts HttpClient + pending timer).
final _theme = ThemeData.light().copyWith(
  extensions: <ThemeExtension<dynamic>>[InTheme.light],
);

Future<void> _pumpHost(
  WidgetTester tester,
  ToastController c, {
  Size size = const Size(1200, 800),
  Widget? below,
}) async {
  // Mount via MaterialApp.builder — a Stack SIBLING of the app child, exactly
  // like main.dart. That places the host ABOVE the root Navigator's Overlay,
  // which is the production reality: anything in the card that needs an
  // Overlay ancestor (e.g. an IconButton `tooltip:`) breaks here but would
  // pass if mounted under `home:`.
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      builder: (context, child) => MediaQuery(
        data: MediaQueryData(size: size),
        child: Stack(
          children: [
            if (child != null) child,
            if (below != null) Positioned.fill(child: below),
            Positioned.fill(child: ToastHost(controller: c)),
          ],
        ),
      ),
      home: const SizedBox.shrink(),
    ),
  );
}

void main() {
  group('ToastHost — desktop (wide)', () {
    testWidgets('stacks multiple toasts with a close button', (tester) async {
      final c = ToastController();
      await _pumpHost(tester, c);

      c.show(variant: NotifyVariant.success, message: 'First');
      c.show(variant: NotifyVariant.info, message: 'Second');
      await tester.pumpAndSettle();

      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      // Each card carries a close affordance on desktop.
      expect(find.byIcon(Icons.close), findsNWidgets(2));

      c.clearAll();
      await tester.pumpAndSettle();
    });

    testWidgets('close button dismisses its toast', (tester) async {
      final c = ToastController();
      await _pumpHost(tester, c);

      c.show(variant: NotifyVariant.error, message: 'Boom');
      await tester.pumpAndSettle();
      expect(find.text('Boom'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('Boom'), findsNothing);
      expect(c.toasts, isEmpty);
    });

    testWidgets('close button survives mouse hover with no Overlay ancestor '
        '(regression: IconButton tooltip above the root Navigator)', (
      tester,
    ) async {
      final c = ToastController();
      await _pumpHost(tester, c);

      c.show(variant: NotifyVariant.success, message: 'Saved');
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.byIcon(Icons.close)));
      await tester.pumpAndSettle();

      // Pre-fix this threw "No Overlay widget found" from the close
      // button's Tooltip (debug: at card build; release: on hover).
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.close), findsOneWidget);

      c.clearAll();
      await tester.pumpAndSettle();
    });

    testWidgets('action button fires its callback and dismisses', (
      tester,
    ) async {
      var pressed = 0;
      final c = ToastController();
      await _pumpHost(tester, c);

      c.show(
        variant: NotifyVariant.error,
        message: 'Failed',
        action: NotifyAction('Retry', () => pressed++),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('RETRY'));
      await tester.pumpAndSettle();
      expect(pressed, 1);
      expect(find.text('Failed'), findsNothing);
    });

    testWidgets('hovering pauses the auto-dismiss timer', (tester) async {
      final c = ToastController();
      await _pumpHost(tester, c);

      c.show(variant: NotifyVariant.success, message: 'Saved'); // 3s
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await gesture.moveTo(tester.getCenter(find.text('Saved')));
      await tester.pump();

      // Past the 3s window, but the hover holds it open.
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('Saved'), findsOneWidget);

      // Move away → timer re-arms → it dismisses.
      await gesture.moveTo(const Offset(5, 5));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
    });
  });

  /// invoiceninja/flutter#30 — "floating status messages ... occasionally are
  /// empty but vertically long". The card gives the message 2 lines and the
  /// detail 3, and a blank line still occupies a full line box, so blank or
  /// newline-laden strings painted an empty card up to ~2.4× the normal height.
  group('ToastHost — blank content never paints a stretched card', () {
    // One `IntrinsicHeight` per card, and it wraps the whole card body.
    Size cardSize(WidgetTester tester) =>
        tester.getSize(find.byType(IntrinsicHeight).first);

    testWidgets('a toast with nothing to say paints no card', (tester) async {
      final c = ToastController();
      await _pumpHost(tester, c);

      c.show(variant: NotifyVariant.success, message: '');
      c.show(variant: NotifyVariant.error, message: '  \n\n ', detail: '\n');
      await tester.pumpAndSettle();

      expect(find.byType(IntrinsicHeight), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing, reason: 'no card chrome');
      c.clearAll();
      await tester.pumpAndSettle();
    });

    testWidgets('a blank detail leaves the card at its no-detail height', (
      tester,
    ) async {
      final c = ToastController();
      await _pumpHost(tester, c);

      c.show(
        variant: NotifyVariant.error,
        message: 'Could not save',
        detail: '\n\n\n\n',
      );
      await tester.pumpAndSettle();
      final blankDetail = cardSize(tester);

      c.clearAll();
      await tester.pumpAndSettle();
      c.show(variant: NotifyVariant.error, message: 'Could not save');
      await tester.pumpAndSettle();
      final noDetail = cardSize(tester);

      expect(blankDetail.height, noDetail.height);

      // Sanity-check the measurement: real detail lines *do* grow the card, so
      // the equality above is meaningful rather than measuring a fixed box.
      c.clearAll();
      await tester.pumpAndSettle();
      c.show(
        variant: NotifyVariant.error,
        message: 'Could not save',
        detail: 'one\ntwo\nthree',
      );
      await tester.pumpAndSettle();
      expect(cardSize(tester).height, greaterThan(noDetail.height));

      c.clearAll();
      await tester.pumpAndSettle();
    });
  });

  group('ToastHost — mobile (narrow)', () {
    testWidgets('shows a single toast with no close button', (tester) async {
      final c = ToastController();
      await _pumpHost(tester, c, size: const Size(400, 800));

      c.show(variant: NotifyVariant.info, message: 'Hello');
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.byType(Dismissible), findsOneWidget);

      c.clearAll();
      await tester.pumpAndSettle();
    });

    testWidgets('swipe dismisses the toast', (tester) async {
      final c = ToastController();
      await _pumpHost(tester, c, size: const Size(400, 800));

      c.show(variant: NotifyVariant.info, message: 'Swipe me');
      await tester.pumpAndSettle();

      await tester.fling(find.text('Swipe me'), const Offset(500, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Swipe me'), findsNothing);
      expect(c.toasts, isEmpty);
    });

    testWidgets('queued toasts that auto-dismiss unseen do not linger', (
      tester,
    ) async {
      // Regression: on mobile only the newest toast is painted; older queued
      // toasts must not leak in the host's `_rendered` (or resurface as a
      // zero-size ghost) when their timers fire while off-screen.
      final c = ToastController();
      await _pumpHost(tester, c, size: const Size(400, 800));

      c.show(variant: NotifyVariant.info, message: 'A');
      c.show(variant: NotifyVariant.info, message: 'B');
      c.show(variant: NotifyVariant.info, message: 'C');
      await tester.pumpAndSettle();
      expect(find.text('C'), findsOneWidget, reason: 'newest is shown');

      // Fire every toast's 3s auto-dismiss timer.
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(c.toasts, isEmpty);
      expect(find.byType(Dismissible), findsNothing, reason: 'no ghost entry');
      expect(find.text('A'), findsNothing);
      expect(find.text('B'), findsNothing);
      expect(find.text('C'), findsNothing);
    });
  });

  group('ToastHost — layering', () {
    testWidgets('renders above a full-screen barrier (hit-testable on top)', (
      tester,
    ) async {
      final c = ToastController();
      // `below` simulates a modal dialog's scrim painted under the toast host.
      await _pumpHost(
        tester,
        c,
        below: const ModalBarrier(dismissible: false, color: Colors.black54),
      );

      c.show(variant: NotifyVariant.error, message: 'On top');
      await tester.pumpAndSettle();
      expect(find.text('On top'), findsOneWidget);

      // If the barrier intercepted the tap, the close would never fire.
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.text('On top'), findsNothing);
    });
  });
}
