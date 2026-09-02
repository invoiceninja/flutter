import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_address_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_cards_grid.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_contacts_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_details_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_notes_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_shipping_address_card.dart';

import '../../../_responsive_helper.dart';

/// `ClientDetailCardsGrid` keeps a wholly-empty Details card in the wide
/// 3-column grid (so the columns stay aligned — no gap) but drops it from the
/// stacked single-column layout (mobile / master-detail sidebar preview).

Client _client({
  String phone = '',
  String address1 = '',
  String shippingAddress1 = '',
  String privateNotes = '',
  List<ContactApi> contacts = const [],
}) => Client.fromApi(
  ClientApi(
    id: 'c1',
    name: 'Acme',
    phone: phone,
    address1: address1,
    shippingAddress1: shippingAddress1,
    privateNotes: privateNotes,
    contacts: contacts,
    updatedAt: 1,
  ),
);

/// The all-blank contact the API seeds on every client.
const _blankContact = ContactApi(id: 'blank', isPrimary: true);
const _realContact = ContactApi(
  id: 'ct1',
  firstName: 'Ada',
  lastName: 'Lovelace',
);

// `phoneActions: true` — the Details card's phone row is a tap-to-call link
// now, and `PhoneActionsScope` reads `Provider<Services>`.
Future<void> _pump(WidgetTester tester, Client client, double width) => pumpAt(
  tester,
  width,
  ClientDetailCardsGrid(client: client, formatter: null),
  phoneActions: true,
);

void main() {
  group('ClientDetailCardsGrid', () {
    testWidgets('empty Details card is dropped in the stacked layout', (
      tester,
    ) async {
      await _pump(tester, _client(), 500);
      expect(find.byType(ClientDetailDetailsCard), findsNothing);
    });

    testWidgets('empty Details card is kept in the wide grid (no gap)', (
      tester,
    ) async {
      await _pump(tester, _client(), 1200);
      expect(find.byType(ClientDetailDetailsCard), findsOneWidget);
    });

    testWidgets('Details card with a value is shown in the stacked layout', (
      tester,
    ) async {
      await _pump(tester, _client(phone: '555-1234'), 500);
      expect(find.byType(ClientDetailDetailsCard), findsOneWidget);
    });

    testWidgets(
      'stacked layout omits blank standard rows (label hidden), keeps the '
      'populated one',
      (tester) async {
        await _pump(tester, _client(phone: '555-1234'), 500);
        expect(find.text('Phone'), findsOneWidget);
        expect(find.text('555-1234'), findsOneWidget);
        // Website / VAT Number / ID Number are blank → no label, no dash.
        expect(find.text('Website'), findsNothing);
        expect(find.text('VAT Number'), findsNothing);
        expect(find.text('ID Number'), findsNothing);
        expect(find.text('—'), findsNothing);
      },
    );

    testWidgets('wide grid also hides blank standard rows (no dash)', (
      tester,
    ) async {
      await _pump(tester, _client(phone: '555-1234'), 1200);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('555-1234'), findsOneWidget);
      // Website / VAT Number / ID Number are blank → no label, no dash, even in
      // the wide multi-column layout (previously a dimmed `—` filled each).
      expect(find.text('Website'), findsNothing);
      expect(find.text('VAT Number'), findsNothing);
      expect(find.text('ID Number'), findsNothing);
      expect(find.text('—'), findsNothing);
    });

    testWidgets(
      'two-column grid engages at 1050px (below the old 1100 breakpoint)',
      (tester) async {
        // Regression lock for Breakpoints.entityFormMultiColumn (1000): a
        // full-width pane on a ~1280px window (~1048px content) must render
        // the wide grid — keeping the empty Details card — not the stretched
        // single column. Under the old 1100 threshold this width stacked and
        // dropped the empty card.
        await _pump(tester, _client(), 1050);
        expect(find.byType(ClientDetailDetailsCard), findsOneWidget);
      },
    );

    // ─────────── invoiceninja/flutter#115 ───────────

    testWidgets('a blank-only contact drops the wide grid to two columns', (
      tester,
    ) async {
      await _pump(tester, _client(contacts: const [_blankContact]), 1200);

      expect(find.byType(ClientDetailContactsCard), findsNothing);
      // Two columns share the width instead of three, so the Details card
      // roughly doubles in width. Asserted as a band rather than an exact
      // figure so `InSpacing.md` can move without breaking this.
      expect(
        tester.getSize(find.byType(ClientDetailDetailsCard)).width,
        greaterThan(500),
      );
    });

    testWidgets('a real contact keeps the third column', (tester) async {
      // The converse of the test above, so neither can pass vacuously.
      await _pump(tester, _client(contacts: const [_realContact]), 1200);

      expect(find.byType(ClientDetailContactsCard), findsOneWidget);
      expect(
        tester.getSize(find.byType(ClientDetailDetailsCard)).width,
        lessThan(450),
      );
    });

    testWidgets('a card that hides itself does not leave a doubled gap', (
      tester,
    ) async {
      // The stacked layout pays `InSpacing.md` per *entry*, not per painted
      // card, so an entry whose `build` returns `SizedBox.shrink()` leaves
      // `md + 0 + md` between its neighbours. Every entry is gated on its
      // card's `hasContent` for exactly this reason — and a `findsNothing` on
      // the hidden card would not catch a regression here.
      await _pump(
        tester,
        _client(
          phone: '555-1234',
          address1: '1 Main St',
          privateNotes: 'note',
          contacts: const [_blankContact],
        ),
        500,
      );

      expect(find.byType(ClientDetailContactsCard), findsNothing);
      // Measure the gap the hidden Contacts entry sits in against one where
      // nothing is hidden, so the assertion calibrates itself: `InSpacing.md`
      // reads `MediaQuery.sizeOf(context).width`, which the harness leaves at
      // its 800 default however the surface is sized, so a literal here would
      // pin the wrong number.
      final control =
          tester.getTopLeft(find.byType(ClientDetailAddressCard)).dy -
          tester.getBottomLeft(find.byType(ClientDetailDetailsCard)).dy;
      final gap =
          tester.getTopLeft(find.byType(ClientDetailNotesCard)).dy -
          tester.getBottomLeft(find.byType(ClientDetailAddressCard)).dy;
      expect(gap, control, reason: 'one InSpacing.md, not two');
    });

    testWidgets('the wide middle column pays no gap for a hidden Address', (
      tester,
    ) async {
      // The middle column stacks Address above Shipping, so it pays the same
      // per-entry gap the stacked layout does. A client with a shipping address
      // but no billing one left the collapsed Address card's gap behind and
      // pushed Shipping ~12 px below the cards beside it. Measured against the
      // Details card in the neighbouring column, which is what it must line up
      // with.
      await _pump(tester, _client(shippingAddress1: '2 Depot Rd'), 1200);

      expect(find.byType(ClientDetailAddressCard), findsNothing);
      expect(
        tester.getTopLeft(find.byType(ClientDetailShippingAddressCard)).dy,
        tester.getTopLeft(find.byType(ClientDetailDetailsCard)).dy,
        reason: 'column tops align — no orphaned gap above Shipping',
      );
    });

    testWidgets('the wide middle column keeps the gap when both cards show', (
      tester,
    ) async {
      // Converse of the test above, so gating the gap can't silently glue the
      // two cards together when both are present.
      await _pump(
        tester,
        _client(address1: '1 Main St', shippingAddress1: '2 Depot Rd'),
        1200,
      );

      final gap =
          tester.getTopLeft(find.byType(ClientDetailShippingAddressCard)).dy -
          tester.getBottomLeft(find.byType(ClientDetailAddressCard)).dy;
      expect(gap, greaterThan(0));
    });
  });
}
