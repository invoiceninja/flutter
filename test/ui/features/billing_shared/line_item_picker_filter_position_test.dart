import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/billing_shared/line_item_picker/line_item_picker_body.dart';

import '../shell/_shell_test_helpers.dart';

/// The phone sheet puts the Add-items filter above the footer, in thumb
/// reach and just above the keyboard; the wide dialog keeps it under the
/// header.
void main() {
  Future<void> pumpPicker(
    WidgetTester tester, {
    required bool filterAtBottom,
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(id: 'co1', name: 'Co', isAdmin: true, isOwner: true),
      ],
    );
    addTearDown(fixture.dispose);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        Scaffold(
          body: LineItemPickerBody(
            companyId: 'co1',
            clientId: '',
            showTasksAndExpenses: false,
            invoiceInclusive: false,
            excludedTaskIds: const {},
            excludedExpenseIds: const {},
            formatter: null,
            filterAtBottom: filterAtBottom,
          ),
        ),
      ),
    );
    await _settle(tester);
  }

  // The divider closing off the list, just above the footer.
  Rect listEnd(WidgetTester tester) => tester.getRect(
    find
        .descendant(
          of: find.byType(LineItemPickerBody),
          matching: find.byType(Divider),
        )
        .last,
  );

  Rect filter(WidgetTester tester) => tester.getRect(
    find.descendant(
      of: find.byType(LineItemPickerBody),
      matching: find.byType(TextField),
    ),
  );

  testWidgets('filterAtBottom puts the filter between the list and footer', (
    tester,
  ) async {
    await pumpPicker(tester, filterAtBottom: true);

    expect(filter(tester).top, greaterThanOrEqualTo(listEnd(tester).bottom));
    expect(
      filter(tester).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('Cancel')).top),
    );
    await _disposeTree(tester);
  });

  testWidgets('by default the filter sits above the list', (tester) async {
    await pumpPicker(tester, filterAtBottom: false);

    expect(filter(tester).bottom, lessThan(listEnd(tester).top));
    await _disposeTree(tester);
  });
}

/// `pumpAndSettle` never settles over a live Drift watch stream — step the
/// clock instead, letting the real async work run between frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Tear the subtree down inside the test body so the Drift watches' close
/// timers fire before the binding's end-of-test `!timersPending` check.
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
