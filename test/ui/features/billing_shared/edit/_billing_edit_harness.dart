// Mounts each of the five billing-document edit layouts over a real in-memory
// `Services` (the shell fixture) and reads back what they render, so the five
// copies can be pinned before they are consolidated into one. Nothing here
// knows about a particular field: it describes the tree, and the
// characterization test compares descriptions.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/services.dart';
import 'package:admin/ui/features/billing_shared/view_models/billing_doc_edit_view_model.dart';
import 'package:admin/ui/features/credits/view_models/credit_edit_view_model.dart';
import 'package:admin/ui/features/credits/widgets/edit/credit_edit_layout.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/invoices/widgets/edit/invoice_edit_layout.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_edit_view_model.dart';
import 'package:admin/ui/features/purchase_orders/widgets/edit/purchase_order_edit_layout.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';
import 'package:admin/ui/features/quotes/widgets/edit/quote_edit_layout.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_edit_view_model.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/edit/recurring_invoice_edit_layout.dart';

import '../../shell/_shell_test_helpers.dart';

const kHarnessCompanyId = 'co1';

enum BillingDoc { invoice, quote, credit, purchaseOrder, recurringInvoice }

/// A layout plus the view model behind it, which the caller must dispose.
typedef MountedLayout = ({
  Widget layout,
  GenericBillingDocEditViewModel<Object?> vm,
});

/// Build [doc]'s edit layout in create mode, exactly as its edit screen's
/// `bodyBuilder` does (`showPdfTab: !narrow`).
MountedLayout buildLayout(
  BillingDoc doc,
  Services services, {
  required bool showPdfTab,
}) {
  switch (doc) {
    case BillingDoc.invoice:
      final vm = InvoiceEditViewModel(
        repo: services.invoices,
        companyId: kHarnessCompanyId,
        clientRequiredMessage: '',
        crossClientLineItemsMessage: '',
        partialInvalidMessage: '',
      );
      return (
        layout: InvoiceEditLayout(vm: vm, showPdfTab: showPdfTab),
        vm: vm,
      );
    case BillingDoc.quote:
      final vm = QuoteEditViewModel(
        repo: services.quotes,
        companyId: kHarnessCompanyId,
        clientRequiredMessage: '',
        crossClientLineItemsMessage: '',
        partialInvalidMessage: '',
      );
      return (layout: QuoteEditLayout(vm: vm, showPdfTab: showPdfTab), vm: vm);
    case BillingDoc.credit:
      final vm = CreditEditViewModel(
        repo: services.credits,
        companyId: kHarnessCompanyId,
        clientRequiredMessage: '',
        crossClientLineItemsMessage: '',
        partialInvalidMessage: '',
      );
      return (layout: CreditEditLayout(vm: vm, showPdfTab: showPdfTab), vm: vm);
    case BillingDoc.purchaseOrder:
      final vm = PurchaseOrderEditViewModel(
        repo: services.purchaseOrders,
        companyId: kHarnessCompanyId,
        vendorRequiredMessage: '',
      );
      return (
        layout: PurchaseOrderEditLayout(vm: vm, showPdfTab: showPdfTab),
        vm: vm,
      );
    case BillingDoc.recurringInvoice:
      final vm = RecurringInvoiceEditViewModel(
        repo: services.recurringInvoices,
        companyId: kHarnessCompanyId,
        clientRequiredMessage: '',
        crossClientLineItemsMessage: '',
      );
      return (
        layout: RecurringInvoiceEditLayout(vm: vm, showPdfTab: showPdfTab),
        vm: vm,
      );
  }
}

/// Size the test window. `setSurfaceSize` leaves `MediaQuery` at 800×600, so
/// the view itself is resized (see the repo's widget-test notes).
void setWindow(WidgetTester tester, double width, {double height = 1000}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Let debounced work and stream first-events land without `pumpAndSettle`,
/// which never settles over a live Drift watch stream.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Unmount and flush what the torn-down tree scheduled on its way out —
/// Drift's zero-duration close timers, the debounces of editors that were
/// mid-edit. `pumpAndSettle` is safe here and only here: with the tree gone
/// there is no live watch stream left to keep it from settling, and without
/// it the fixture's `db.close()` in tear-down can wait forever on a timer the
/// fake clock never advances.
Future<void> unmount(WidgetTester tester, ShellFixture fixture) async {
  fixture.services.recentlyViewed.dispose();
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

/// Jump the top-level tab strip (the first [TabBar] on screen) to [index]
/// through its controller. Tapping is unreliable here: on a phone the strip
/// scrolls, so a later tab's label sits off-screen and the tap never lands.
Future<void> showTab(WidgetTester tester, int index) async {
  final bar = tester.widget<TabBar>(find.byType(TabBar).first);
  bar.controller!.index = index;
  // Even a controller jump animates the page (`TabBarView` warps with
  // `animateToPage`), and until it lands the previous page is still on
  // screen — so wait out the whole transition, not just a frame or two.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Tab labels of every [TabBar] currently on screen, in paint order.
List<List<String>> tabBarLabels(WidgetTester tester) => [
  for (final bar in tester.widgetList<TabBar>(find.byType(TabBar)))
    [
      for (final tab in bar.tabs)
        if (tab is Tab) tab.text ?? '?' else '?',
    ],
];

/// The label of every on-screen input decorator (text fields, pickers,
/// dropdowns), in paint order — the layout's field set, as the user reads it.
List<String> fieldLabels(WidgetTester tester, {Finder? within}) {
  final finder = within == null
      ? find.byType(InputDecorator)
      : find.descendant(of: within, matching: find.byType(InputDecorator));
  return [
    for (final d in tester.widgetList<InputDecorator>(finder))
      d.decoration.labelText ??
          switch (d.decoration.label) {
            final Text t => t.data ?? '',
            _ => d.decoration.hintText ?? '<unlabelled>',
          },
  ];
}
