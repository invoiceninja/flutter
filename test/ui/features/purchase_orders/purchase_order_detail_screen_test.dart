// The purchase order record screen, assembled. What the five billing
// documents share is exercised in `invoices/invoice_detail_screen_test.dart`;
// this is what is a purchase order's own — above all, that its party is the
// vendor.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/purchase_order_api_model.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/party_contact_row.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_profile.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_record_header.dart';
import 'package:admin/ui/features/billing_shared/detail/billing_doc_standing.dart';
import 'package:admin/ui/features/purchase_orders/views/purchase_order_detail_screen.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_actions.dart';

import '../../../_support/record_screen_harness.dart';
import '../billing_shared/detail/_billing_doc_fixtures.dart';

Map<String, dynamic> _order({
  String status = '2',
  String balance = '3720.00',
  bool deleted = false,
}) => {
  ...docJson(
    number: 'PO-0011',
    status: status,
    balance: balance,
    deleted: deleted,
  ),
  'client_id': '',
  'vendor_id': 'v1',
  'invitations': [
    {
      'id': 'pinv1',
      'key': 'k',
      'link': 'https://portal.example.com/vendor/purchase_order/k',
      'vendor_contact_id': 'vk1',
      'sent_date': '2000-01-02 09:12:00',
    },
  ],
};

void _screenTest(
  String description,
  Map<String, dynamic> order,
  Future<void> Function(WidgetTester tester, RecordScreen screen) body,
) => recordScreenTest(
  description,
  seed: (services) async {
    await seedVendor(services);
    await services.purchaseOrders.applyUpdateResponse(
      companyId: 'co1',
      serverResponse: PurchaseOrderApi.fromJson(order),
    );
  },
  screen: () => PurchaseOrderDetailScreen(id: order['id'] as String),
  ready: () => find.byType(StandingCard),
  body: (tester, screen) async {
    await screen.untilFound(
      find.byType(BillingDocContactsCard),
      'the contacts',
    );
    await body(tester, screen);
  },
);

List<String> _tiles(WidgetTester tester) {
  final strip = find.byType(EntityQuickActions<PurchaseOrderAction>);
  if (strip.evaluate().isEmpty) return const [];
  final texts =
      find
          .descendant(of: strip, matching: find.byType(Text))
          .evaluate()
          .map((e) => e.widget as Text)
          .toList()
        ..sort(
          (a, b) => tester
              .getTopLeft(find.byWidget(a))
              .dx
              .compareTo(tester.getTopLeft(find.byWidget(b)).dx),
        );
  return [for (final t in texts) t.data ?? ''];
}

Finder _inStanding(String text) =>
    find.descendant(of: find.byType(StandingCard), matching: find.text(text));

void main() {
  _screenTest(
    'a sent order: it is the vendor\'s, in every place a party is named',
    _order(),
    (tester, screen) async {
      final header = find.byType(BillingDocRecordHeader);
      expect(
        find.descendant(of: header, matching: find.text('PURCHASE ORDER')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: header, matching: find.text('#PO-0011')),
        findsOneWidget,
      );
      // Whose it is: the vendor, as the link under the number…
      expect(
        find.descendant(of: header, matching: find.text('Northwind Paper Co.')),
        findsOneWidget,
      );
      // …and the vendor's contact, with the vendor portal's link.
      expect(find.byType(PartyContactRow), findsOneWidget);
      expect(find.text('Olga Nordin'), findsOneWidget);
      expect(find.byTooltip('Vendor Portal: Copy Link'), findsOneWidget);
      expect(find.byTooltip('Client Portal: Copy Link'), findsNothing);

      // One figure. Its balance is its amount until something is recorded
      // against it, and the same number twice would be noise.
      expect(_inStanding('AMOUNT'), findsOneWidget);
      expect(_inStanding(r'$3,720.00'), findsOneWidget);
      expect(_inStanding('Balance'), findsNothing);
      expect(find.byType(BillingDocDueLine), findsNothing);

      expect(_tiles(tester), ['Email', 'PDF', 'Download', '+ Expense']);

      // The Overview now shows what is being ordered.
      expect(find.text('Design'), findsOneWidget);
    },
  );

  _screenTest('an accepted order: receiving it leads', _order(status: '3'), (
    tester,
    screen,
  ) async {
    expect(_tiles(tester).first, 'Inventory');
  });

  _screenTest(
    'a balance that differs from the amount is shown',
    _order(balance: '1000.00'),
    (tester, screen) async {
      expect(_inStanding('Balance'), findsOneWidget);
      expect(_inStanding(r'$1,000.00'), findsOneWidget);
    },
  );

  _screenTest('a deleted order is read-only', _order(deleted: true), (
    tester,
    screen,
  ) async {
    expect(
      find.text('This record is deleted. Restore it to make changes.'),
      findsOneWidget,
    );
    expect(_tiles(tester), isEmpty);
  });
}
