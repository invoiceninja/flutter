// Layout contract for the unconfirmed-email notice (invoiceninja/flutter#48).
//
// The notice gained a Resend Email action, and on a phone the message already
// wraps to two lines — so the action has to move under it rather than squeeze
// it. These pin the switch, and that neither branch overflows or clips at the
// text scales the app itself offers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/features/settings/views/advanced/user_management/widgets/unconfirmed_email_banner.dart';

import '../../../../../../_responsive_helper.dart';

void main() {
  Widget banner({bool withAction = true}) =>
      UnconfirmedEmailBanner(onResend: withAction ? () async {} : null);

  Finder message() =>
      find.text('An email has been sent to confirm the email address');
  Finder action() => find.widgetWithText(TextButton, 'Resend Email');

  /// True when the action sits below the message rather than beside it.
  bool isStacked(WidgetTester tester) =>
      tester.getRect(action()).top >= tester.getRect(message()).bottom;

  testWidgets('the action sits beside the message on a wide card', (
    tester,
  ) async {
    await pumpAt(tester, 800, banner());

    expect(isStacked(tester), isFalse);
    expectNoOverflow(tester);
  });

  testWidgets('the action moves below the message on a phone', (tester) async {
    await pumpAt(tester, 360, banner());

    expect(isStacked(tester), isTrue);
    expectNoOverflow(tester);
  });

  testWidgets('a wide card still stacks once the text scaler is doubling', (
    tester,
  ) async {
    // In the beside branch the button is a non-flex `Row` child, so `Expanded`
    // on the message cannot save the row from a button that outgrows it — at
    // 2x the label alone is wider than the message. `composeTextScaler`
    // multiplies the in-app factor by the OS one, so users do reach here.
    await pumpAt(tester, 800, banner(), textScale: 2.0);

    expect(isStacked(tester), isTrue);
    expectNoOverflow(tester);
  });

  testWidgets('no overflow at any width up to the app maximum text scale', (
    tester,
  ) async {
    for (final width in kResponsiveWidths) {
      await pumpAt(tester, width, banner(), textScale: kTextScaleMax);
      expectNoOverflow(tester);
    }
  });

  testWidgets('the action clears the touch-target floor', (tester) async {
    // `flutter test` reports TargetPlatform.android, so `Env.isTouchPrimary`
    // is true here and the 44px floor is the one under test.
    await pumpAt(tester, 360, banner());

    expect(
      tester.getSize(action()).height,
      greaterThanOrEqualTo(InSizes.touchTarget),
    );
  });

  testWidgets('the action is not vertically crushed at large text scale', (
    tester,
  ) async {
    // The check a `SizedBox(height: 44)` regression would fail while
    // `expectNoOverflow` stayed green: a tight height clamps the line box and
    // slices Inter Tight's descenders instead of throwing.
    await pumpAt(tester, 360, banner(), textScale: kTextScaleMax);

    expectNotVerticallyCrushed(tester, action());
  });

  testWidgets('omitting onResend renders the notice alone', (tester) async {
    // The user edit screen's call site: a typed-but-unsaved email change would
    // otherwise mail the address the server still holds.
    await pumpAt(tester, 800, banner(withAction: false));

    expect(message(), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expectNoOverflow(tester);
  });
}
