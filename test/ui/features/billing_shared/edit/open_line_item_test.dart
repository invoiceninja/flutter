import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/ui/features/billing_shared/edit/open_line_item_request.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_edit_view_model.dart';
import 'package:admin/ui/features/purchase_orders/widgets/edit/purchase_order_edit_layout.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';
import 'package:admin/ui/features/quotes/widgets/edit/quote_edit_layout.dart';

import '../../shell/_shell_test_helpers.dart';
import '_billing_edit_harness.dart';

/// A line tapped on the record screen opens the edit screen with that line's
/// editor already up — admin-portal's tap-a-line-to-edit, which the rebuild
/// had turned into Edit → Items → tap the line.
void main() {
  LineItem line(String key, {String notes = ''}) => emptyLineItem().copyWith(
    productKey: key,
    notes: notes,
    cost: Decimal.fromInt(10),
  );

  // A blank line sits between the two real ones: the request indexes the
  // document's `line_items` as stored, blank lines counted.
  final lines = [line('Widget'), emptyLineItem(), line('Gadget')];

  /// Settle, with one real-async turn in the middle: the layout reads the
  /// company once (`watchCompany(...).first`) before opening the dialog, and
  /// that one-shot Drift query never completes on the fake clock alone.
  Future<void> settleWithQuery(WidgetTester tester) async {
    await settle(tester);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await settle(tester);
  }

  Future<ShellFixture> fixtureFor(WidgetTester tester, double width) async {
    setWindow(tester, width);
    final fixture = await buildFixture(
      closeStreamsSynchronously: true,
      companies: const [FakeCompany(id: kHarnessCompanyId, name: 'Co')],
    );
    addTearDown(fixture.dispose);
    return fixture;
  }

  Future<({ShellFixture fixture, QuoteEditViewModel vm})> mountQuote(
    WidgetTester tester, {
    required double width,
    required OpenLineItemRequest? request,
    List<LineItem>? items,
  }) async {
    final fixture = await fixtureFor(tester, width);
    final vm = QuoteEditViewModel(
      repo: fixture.services.quotes,
      companyId: kHarnessCompanyId,
      clientRequiredMessage: '',
      crossClientLineItemsMessage: '',
      partialInvalidMessage: '',
      cloneFrom: emptyQuote().copyWith(lineItems: items ?? lines),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        QuoteEditLayout(
          vm: vm,
          showPdfTab: width >= 600,
          openLineItem: request,
        ),
      ),
    );
    await settleWithQuery(tester);
    return (fixture: fixture, vm: vm);
  }

  Finder dialogField() => find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );

  testWidgets('a phone opens on Items with the line\'s editor up', (
    tester,
  ) async {
    final (:fixture, :vm) = await mountQuote(
      tester,
      width: 390,
      request: const OpenLineItemRequest(2),
    );

    final strip = tester.widget<TabBar>(find.byType(TabBar).first);
    final labels = tabBarLabels(tester).first;
    expect(strip.controller!.index, labels.indexOf('Items'));

    expect(find.text('Line Item'), findsOneWidget);
    final product = tester.widget<TextField>(dialogField().first);
    expect(product.controller!.text, 'Gadget');

    // Save writes the edit back to that line, and only that line.
    await tester.enterText(dialogField().first, 'Gizmo');
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Save')),
    );
    await settle(tester);
    expect(find.byType(Dialog), findsNothing);
    expect(vm.draft.lineItems.map((li) => li.productKey), [
      'Widget',
      '',
      'Gizmo',
    ]);
    await unmount(tester, fixture);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a tapped hourly line opens its Items sub-tab, Tasks', (
    tester,
  ) async {
    final (:fixture, :vm) = await mountQuote(
      tester,
      width: 390,
      request: const OpenLineItemRequest(1),
      items: [
        line('Widget'),
        line('Design').copyWith(typeId: LineItemType.task),
      ],
    );
    // Left on Products, the line just edited would be out of sight once its
    // dialog closed.
    expect(vm.itemsTab, 'tasks');
    expect(find.text('Line Item'), findsOneWidget);
    await unmount(tester, fixture);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('the request is one-shot: a strip mounted later opens on '
      'Details', (tester) async {
    final (:fixture, vm: _) = await mountQuote(
      tester,
      width: 1440,
      request: const OpenLineItemRequest(0),
    );
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Cancel')),
    );
    await settle(tester);

    setWindow(tester, 390);
    await settle(tester);
    final strip = tester.widget<TabBar>(find.byType(TabBar).first);
    expect(strip.controller!.index, 0);
    await unmount(tester, fixture);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('without a request the strip opens on Details, no dialog', (
    tester,
  ) async {
    final (:fixture, vm: _) = await mountQuote(
      tester,
      width: 390,
      request: null,
    );
    final strip = tester.widget<TabBar>(find.byType(TabBar).first);
    expect(strip.controller!.index, 0);
    expect(find.byType(Dialog), findsNothing);
    await unmount(tester, fixture);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a text line opens the text editor', (tester) async {
    final (:fixture, vm: _) = await mountQuote(
      tester,
      width: 390,
      request: const OpenLineItemRequest(0),
      items: [textLineItem().copyWith(notes: 'Thank you')],
    );
    expect(find.text('Line Item'), findsNothing);
    final notes = tester.widget<TextField>(dialogField().first);
    expect(notes.controller!.text, 'Thank you');
    await unmount(tester, fixture);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('a request for a blank line opens nothing', (tester) async {
    final (:fixture, vm: _) = await mountQuote(
      tester,
      width: 390,
      request: const OpenLineItemRequest(1),
    );
    expect(find.byType(Dialog), findsNothing);
    await unmount(tester, fixture);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('the desktop layout opens the same dialog (purchase order)', (
    tester,
  ) async {
    final fixture = await fixtureFor(tester, 1440);
    final vm = PurchaseOrderEditViewModel(
      repo: fixture.services.purchaseOrders,
      companyId: kHarnessCompanyId,
      vendorRequiredMessage: '',
      cloneFrom: emptyPurchaseOrder().copyWith(lineItems: lines),
    );
    addTearDown(vm.dispose);
    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        PurchaseOrderEditLayout(
          vm: vm,
          openLineItem: const OpenLineItemRequest(0),
        ),
      ),
    );
    await settleWithQuery(tester);
    expect(find.text('Line Item'), findsOneWidget);
    final product = tester.widget<TextField>(dialogField().first);
    expect(product.controller!.text, 'Widget');
    await unmount(tester, fixture);
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('only a request is read off the route extra', () {
    expect(OpenLineItemRequest.of(const OpenLineItemRequest(3))?.index, 3);
    expect(OpenLineItemRequest.of(null), isNull);
    expect(OpenLineItemRequest.of(emptyQuote()), isNull);
  });
}
