import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/ui/core/widgets/in_time_field.dart';
import 'package:admin/ui/features/settings/widgets/phone_actions_section.dart';

import '../../../../_responsive_helper.dart';
import '../../../../_support/phone_actions_test_services.dart';

void main() {
  late PhoneActionsTestServices services;

  Future<void> pump(
    WidgetTester tester, {
    double width = 500,
    double textScale = 1.0,
  }) async {
    await pumpAt(
      tester,
      width,
      Provider<Services>.value(
        value: services,
        child: const PhoneActionsSection(),
      ),
      textScale: textScale,
    );
  }

  setUp(() => services = PhoneActionsTestServices());

  testWidgets('the guards are inert until tap-to-call is on', (tester) async {
    await services.phoneActions.setTapToCall(false);
    await pump(tester);

    // Greyed rather than hidden: a row that vanishes reads as a bug, and the
    // guards' state is worth seeing before switching the master on.
    for (final label in const [
      'Confirm before calling',
      'Warn outside business hours',
    ]) {
      expect(
        tester
            .widget<SwitchListTile>(
              find.ancestor(
                of: find.text(label),
                matching: find.byType(SwitchListTile),
              ),
            )
            .onChanged,
        isNull,
        reason: '$label should be disabled',
      );
    }
    expect(find.byType(InTimeField), findsNothing);
  });

  testWidgets('the hours pair appears only while the warning is on', (
    tester,
  ) async {
    await services.phoneActions.setTapToCall(true);
    await services.phoneActions.setWarnOutsideBusinessHours(true);
    await pump(tester);
    expect(find.byType(InTimeField), findsNWidgets(2));
    expect(find.text('Business hours'), findsOneWidget);

    await services.phoneActions.setWarnOutsideBusinessHours(false);
    await tester.pump();
    // Unlike a switch, an inert time field says nothing useful about state.
    expect(find.byType(InTimeField), findsNothing);
  });

  testWidgets('the hours round-trip through the controller', (tester) async {
    await services.phoneActions.setTapToCall(true);
    await pump(tester);

    await tester.enterText(find.byType(InTimeField).first, '9:30');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(services.phoneActions.value.startMinutes, 9 * 60 + 30);
  });

  testWidgets('lays out on a narrow phone at the maximum text scale', (
    tester,
  ) async {
    // The From / To pair is the only Row here, and 1.4 is the largest scale
    // Device Settings offers (the OS scaler multiplies on top).
    await services.phoneActions.setTapToCall(true);
    await pump(tester, width: 320, textScale: kTextScaleMax);
    expectNoOverflow(tester);
  });
}
