import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/billing_shared/line_item_picker/line_item_picker_body.dart';

import '../shell/_shell_test_helpers.dart';

/// "Create «filter»" in the Add-items picker (invoiceninja/ui#3384): the
/// typed text names no product, so the picker offers to make one — with a
/// price, not as a $0 catalog entry — and selects it.
void main() {
  Future<ShellFixture> pumpPicker(
    WidgetTester tester, {
    String permissions = '',
    bool isAdmin = true,
  }) async {
    final fixture = await buildFixture(
      companies: [
        FakeCompany(
          id: 'co1',
          name: 'Co',
          isAdmin: isAdmin,
          isOwner: isAdmin,
          permissions: permissions,
        ),
      ],
    );
    addTearDown(fixture.dispose);
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        const Scaffold(
          body: LineItemPickerBody(
            companyId: 'co1',
            clientId: '',
            showTasksAndExpenses: false,
            invoiceInclusive: false,
            excludedTaskIds: {},
            excludedExpenseIds: {},
            formatter: null,
          ),
        ),
      ),
    );
    await _settle(tester);
    return fixture;
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    // The product search is debounced.
    await tester.pump(const Duration(milliseconds: 500));
    await _settle(tester);
  }

  testWidgets('a name that matches no product offers to create it', (
    tester,
  ) async {
    await pumpPicker(tester);
    await search(tester, 'Widget');

    expect(find.text('Create "Widget"'), findsOneWidget);
    await _disposeTree(tester);
  });

  testWidgets('without create rights there is no create row', (tester) async {
    await pumpPicker(tester, isAdmin: false, permissions: 'view_product');
    await search(tester, 'Widget');

    expect(find.byKey(const Key('picker_create_product')), findsNothing);
    await _disposeTree(tester);
  });

  testWidgets('creating asks for a price and selects the new product', (
    tester,
  ) async {
    final fixture = await pumpPicker(tester);
    await search(tester, 'Widget');

    await tester.tap(find.text('Create "Widget"'));
    await _settle(tester);
    expect(find.text('New Product'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Price'), '12.50');
    await tester.tap(find.text('Save'));
    await _settle(tester);

    final products = await tester.runAsync(
      () => fixture.services.products.watchPage(companyId: 'co1').first,
    );
    final created = products!.singleWhere((p) => p.productKey == 'Widget');
    expect(created.price.toString(), '12.5');

    // Selected straight away, and the create row is gone — the name exists.
    final row = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Widget'),
    );
    expect(row.value, isTrue);
    expect(find.text('Create "Widget"'), findsNothing);
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
/// timers fire before the binding's end-of-test `!timersPending` check (see
/// `entity_list_pull_to_refresh_test.dart`).
Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
