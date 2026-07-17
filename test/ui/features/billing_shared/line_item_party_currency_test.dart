// Regression: billing-doc edit line-item money used to render in the *company
// default* currency because the editor never threaded the document's party
// currency into `Formatter.money`. A purchase order for a USD vendor with an
// attached EUR client therefore showed the euro sign on line items (the company
// default), not the vendor's USD. The fix threads the party currency (vendor for
// POs, client for client-docs) via `PartyCurrencyBuilder`.
//
// These tests seed a company whose default currency is USD ('1') and a party on
// EUR ('3'), then assert the line-item / totals money renders in the *party*
// currency (€), never the company default ($).

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/domain/billing/totals_calculator.dart';
import 'package:admin/ui/features/billing_shared/billing_edit_totals.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_editor.dart';
import 'package:admin/ui/features/billing_shared/line_item_editor/line_item_table_desktop.dart';

import '../shell/_shell_test_helpers.dart';

/// Seed the statics cache with USD ('1') and EUR ('3') so a warmed [Formatter]
/// can render their symbols. Mirrors the `/api/v1/statics` currency shape.
Future<void> _seedCurrencies(Services services) async {
  await services.statics.applyStatic(<String, dynamic>{
    'currencies': [
      {
        'id': '1',
        'name': 'US Dollar',
        'code': 'USD',
        'symbol': r'$',
        'precision': 2,
        'thousand_separator': ',',
        'decimal_separator': '.',
        'swap_currency_symbol': false,
        'exchange_rate': 1,
      },
      {
        'id': '3',
        'name': 'Euro',
        'code': 'EUR',
        'symbol': '€',
        'precision': 2,
        'thousand_separator': ',',
        'decimal_separator': '.',
        'swap_currency_symbol': false,
        'exchange_rate': 1,
      },
    ],
  });
}

LineItem _widgetLine() => emptyLineItem().copyWith(
  productKey: 'Widget',
  cost: Decimal.fromInt(10),
  quantity: Decimal.one,
);

void main() {
  // A billing row renders its identity + money in ~12 bounded frames — the
  // company + party watches emit asynchronously, so pump (not pumpAndSettle,
  // which hangs on the fixture's pending Services timers) until the euro symbol
  // resolves.
  Future<void> pumpUntilEuro(WidgetTester tester) async {
    for (
      var i = 0;
      i < 15 && find.textContaining('€').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> teardownSubtree(WidgetTester tester) async {
    // Drift schedules a zero-duration close timer on unsubscribe; unmount +
    // elapse the clock so it fires before the "Timer still pending" invariant.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('PO line-item money renders in the vendor currency, not the '
      'company default', (tester) async {
    tester.view.physicalSize = const Size(420, 900); // narrow → mobile cards
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await _seedCurrencies(fixture.services);
    await fixture.services.formatterFor('co1'); // warm formatterIfReady
    await fixture.services.vendors.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: const VendorApi(id: 'v1', name: 'V', currencyId: '3'),
    );

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        LineItemEditor(
          companyId: 'co1',
          vendorId: 'v1',
          items: [_widgetLine()],
          onChanged: (_) {},
          newItemFactory: emptyLineItem,
        ),
      ),
    );
    await pumpUntilEuro(tester);

    expect(find.textContaining('€'), findsWidgets); // vendor EUR
    expect(find.textContaining(r'$'), findsNothing); // never the company USD

    await teardownSubtree(tester);
  });

  testWidgets('invoice line-item money renders in the client currency '
      '(regression for client-billed docs)', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await _seedCurrencies(fixture.services);
    await fixture.services.formatterFor('co1');
    await fixture.services.clients.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: const ClientApi(id: 'c1', name: 'C', currencyId: '3'),
    );

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        LineItemEditor(
          companyId: 'co1',
          clientId: 'c1',
          items: [_widgetLine()],
          onChanged: (_) {},
          newItemFactory: emptyLineItem,
        ),
      ),
    );
    await pumpUntilEuro(tester);

    expect(find.textContaining('€'), findsWidgets); // client EUR
    expect(find.textContaining(r'$'), findsNothing);

    await teardownSubtree(tester);
  });

  testWidgets('edit-screen totals render a currency symbol without a '
      'FormatterScope (services fallback)', (tester) async {
    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await _seedCurrencies(fixture.services);
    await fixture.services.formatterFor('co1');
    await fixture.services.vendors.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: const VendorApi(id: 'v1', name: 'V', currencyId: '3'),
    );

    BillingTotalsResult totals(int precision) => BillingTotalsResult(
      subtotal: Decimal.fromInt(100),
      total: Decimal.fromInt(100),
      taxAmount: Decimal.zero,
      taxBreakdown: const {},
    );

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        BillingEditTotals(
          totalsAt: totals,
          vendorId: 'v1',
          discount: Decimal.zero,
          discountIsAmount: false,
        ),
      ),
    );
    await pumpUntilEuro(tester);

    // Before the fix this was symbol-less (no FormatterScope on edit screens).
    expect(find.textContaining('€'), findsWidgets);

    await teardownSubtree(tester);
  });

  testWidgets('PO desktop line-total column renders in the vendor currency '
      '(the reported edit-window surface)', (tester) async {
    tester.view.physicalSize = const Size(1400, 900); // wide → desktop table
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fixture = await buildFixture(
      companies: [const FakeCompany(id: 'co1', name: 'Co')],
    );
    addTearDown(fixture.dispose);
    await _seedCurrencies(fixture.services);
    await fixture.services.formatterFor('co1');
    await fixture.services.vendors.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: const VendorApi(id: 'v1', name: 'V', currencyId: '3'),
    );

    await tester.pumpWidget(
      wrapWithShell(
        fixture.services,
        LineItemEditor(
          companyId: 'co1',
          vendorId: 'v1',
          items: [_widgetLine()],
          onChanged: (_) {},
          newItemFactory: emptyLineItem,
        ),
      ),
    );
    await pumpUntilEuro(tester);

    expect(find.byType(LineItemTableDesktop), findsOneWidget); // desktop path
    expect(find.textContaining('€'), findsWidgets); // vendor EUR line-total
    expect(find.textContaining(r'$'), findsNothing); // never the company USD

    await teardownSubtree(tester);
  });
}
