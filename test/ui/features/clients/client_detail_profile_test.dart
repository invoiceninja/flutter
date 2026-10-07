import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_address_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_contacts_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_details_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_notes_card.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_profile.dart';
import 'package:admin/ui/features/clients/widgets/detail/client_detail_shipping_address_card.dart';

import '../../../_responsive_helper.dart';

/// `ClientDetailProfile` is a client's reference fields: Contacts, Details,
/// Address, Payment Methods and Notes — always shown. Every entry is gated on
/// its card having content, in both layouts, because the gap between cards is
/// paid per entry.

Client _client({
  String phone = '',
  String address1 = '',
  String shippingAddress1 = '',
  String privateNotes = '',
  String customValue1 = '',
  String paymentTerms = '',
  bool hasValidVatNumber = false,
  List<ContactApi> contacts = const [],
}) => Client.fromApi(
  ClientApi(
    id: 'c1',
    name: 'Acme',
    phone: phone,
    address1: address1,
    shippingAddress1: shippingAddress1,
    privateNotes: privateNotes,
    customValue1: customValue1,
    paymentTerms: paymentTerms,
    hasValidVatNumber: hasValidVatNumber,
    contacts: contacts,
    updatedAt: 1,
  ),
);

/// The all-blank contact the API seeds on every client.
const _blankContact = ContactApi(id: 'blank', isPrimary: true);
const _lead = ContactApi(
  id: 'ct1',
  firstName: 'Ada',
  lastName: 'Lovelace',
  isPrimary: true,
);
const _second = ContactApi(id: 'ct2', firstName: 'Grace', lastName: 'Hopper');
const _third = ContactApi(id: 'ct3', firstName: 'Mary', lastName: 'Shelley');

// `phoneActions: true` — the Details card's phone row is a tap-to-call link,
// and `PhoneActionsScope` reads `Provider<Services>`.
Future<void> _pump(WidgetTester tester, Client client, double width) => pumpAt(
  tester,
  width,
  ClientDetailProfile(client: client, company: null),
  phoneActions: true,
);

void main() {
  group('ClientDetailProfile', () {
    testWidgets('an empty client builds no card at any width', (tester) async {
      for (final width in [500.0, 1200.0]) {
        await _pump(tester, _client(), width);
        expect(find.byType(ClientDetailDetailsCard), findsNothing);
        expect(find.byType(ClientDetailAddressCard), findsNothing);
        expect(find.byType(ClientDetailContactsCard), findsNothing);
        expect(find.byType(ClientDetailNotesCard), findsNothing);
      }
    });

    testWidgets('only populated rows render — no label, no dash', (
      tester,
    ) async {
      for (final width in [500.0, 1200.0]) {
        await _pump(tester, _client(phone: '555-1234'), width);
        expect(find.text('Phone'), findsOneWidget);
        expect(find.text('555-1234'), findsOneWidget);
        // Website / VAT Number / ID Number are blank → no label, no dash.
        expect(find.text('Website'), findsNothing);
        expect(find.text('VAT Number'), findsNothing);
        expect(find.text('ID Number'), findsNothing);
        expect(find.text('—'), findsNothing);
      }
    });

    testWidgets('a custom value with no configured label is not content', (
      tester,
    ) async {
      // The card draws a custom field only when the company has a label for
      // it. The old emptiness check counted the value regardless, which opened
      // a titled "Details" card with nothing in it.
      final client = _client(customValue1: 'orphan');
      await _pump(tester, client, 500);
      expect(find.byType(ClientDetailDetailsCard), findsNothing);
    });

    // ─────────── which contacts ───────────

    testWidgets('every contact is in the card, the primary included', (
      tester,
    ) async {
      // There is no summary above this any more to carry the primary; a card
      // that still left it out would show a client with one contact as having
      // none.
      await _pump(tester, _client(contacts: const [_lead, _second]), 500);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Grace Hopper'), findsOneWidget);
    });

    testWidgets('a client with one contact has a Contacts card', (
      tester,
    ) async {
      await _pump(tester, _client(contacts: const [_lead]), 500);
      expect(find.byType(ClientDetailContactsCard), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('the blank contact the server seeds is not a row', (
      tester,
    ) async {
      final client = _client(contacts: const [_blankContact, _second, _third]);
      await _pump(tester, client, 500);
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Mary Shelley'), findsOneWidget);
      expect(find.textContaining('no name'), findsNothing);
    });

    // ─────────── layout ───────────

    testWidgets('wide: a contact\'s buttons sit close to its name', (
      tester,
    ) async {
      // As a strip across the whole window they were at its far edge — on a
      // 1780 px window, ~1,400 px from the name they act on. In a card that
      // is a third of the row they cannot be further than the card is wide.
      await _pump(
        tester,
        _client(
          phone: '555-1234',
          address1: '1 Main St',
          contacts: const [
            ContactApi(
              id: 'ct1',
              firstName: 'Ada',
              lastName: 'Lovelace',
              email: 'ada@example.com',
              isPrimary: true,
            ),
          ],
        ),
        1780,
      );
      final name = tester.getRect(find.text('Ada Lovelace'));
      final button = tester.getRect(find.byTooltip('Email'));
      expect(button.left - name.right, lessThan(520));
      expect(
        tester.getSize(find.byType(ClientDetailContactsCard)).width,
        lessThan(620),
      );
    });

    testWidgets('wide: the lead sections share one row', (tester) async {
      await _pump(
        tester,
        _client(
          phone: '555-1234',
          address1: '1 Main St',
          contacts: const [_lead, _second],
        ),
        1200,
      );
      final top = tester.getTopLeft(find.byType(ClientDetailContactsCard)).dy;
      expect(tester.getTopLeft(find.byType(ClientDetailDetailsCard)).dy, top);
      expect(tester.getTopLeft(find.byType(ClientDetailAddressCard)).dy, top);
      expect(
        tester.getSize(find.byType(ClientDetailDetailsCard)).width,
        lessThan(450),
        reason: 'a third of the row',
      );
    });

    testWidgets('wide: the three cards end on one line', (tester) async {
      // The Address column was stretched to the row's height but its card was
      // not, so it stopped short of the two beside it.
      await _pump(
        tester,
        _client(
          phone: '555-1234',
          address1: '1 Main St',
          contacts: const [_lead, _second, _third],
        ),
        1200,
      );
      final contacts = tester.getRect(find.byType(ClientDetailContactsCard));
      final details = tester.getRect(find.byType(ClientDetailDetailsCard));
      final address = tester.getRect(find.byType(ClientDetailAddressCard));
      expect(details.bottom, contacts.bottom);
      expect(address.bottom, contacts.bottom);
      expect(address.height, greaterThan(100), reason: 'taller than its text');
    });

    testWidgets('wide: with a separate shipping address, the pair still ends '
        'on that line', (tester) async {
      await _pump(
        tester,
        _client(
          phone: '555-1234',
          address1: '1 Main St',
          shippingAddress1: '2 Depot Rd',
          contacts: const [_lead, _second, _third],
        ),
        1200,
      );
      final contacts = tester.getRect(find.byType(ClientDetailContactsCard));
      final billing = tester.getRect(find.byType(ClientDetailAddressCard));
      final shipping = tester.getRect(
        find.byType(ClientDetailShippingAddressCard),
      );
      expect(billing.top, contacts.top);
      expect(shipping.top, greaterThan(billing.bottom));
      expect(shipping.bottom, contacts.bottom);
    });

    testWidgets('narrow: a stacked address card is only as tall as its text', (
      tester,
    ) async {
      // Nothing to fill in the stack — and an `Expanded` there would throw.
      await _pump(tester, _client(phone: '555-1234', address1: '1 Main'), 500);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(ClientDetailAddressCard)).height,
        lessThan(160),
      );
    });

    testWidgets('wide: a missing section gives its width to the others', (
      tester,
    ) async {
      // No contact at all, so two columns share the width instead of three.
      // Asserted as a band so `InSpacing.md` can move.
      await _pump(tester, _client(phone: '555-1234', address1: '1 Main'), 1200);
      expect(find.byType(ClientDetailContactsCard), findsNothing);
      expect(
        tester.getSize(find.byType(ClientDetailDetailsCard)).width,
        greaterThan(500),
      );
    });

    testWidgets('wide: a single section spans the profile', (tester) async {
      await _pump(tester, _client(phone: '555-1234'), 1200);
      expect(
        tester.getSize(find.byType(ClientDetailDetailsCard)).width,
        greaterThan(1100),
      );
    });

    testWidgets('narrow: sections stack', (tester) async {
      await _pump(tester, _client(phone: '555-1234', address1: '1 Main'), 500);
      expect(
        tester.getTopLeft(find.byType(ClientDetailAddressCard)).dy,
        greaterThan(
          tester.getBottomLeft(find.byType(ClientDetailDetailsCard)).dy,
        ),
      );
    });

    testWidgets('a section with no content does not leave a doubled gap', (
      tester,
    ) async {
      // The gap is paid per *entry*, so an entry whose card built nothing
      // would leave `md + 0 + md` between its neighbours — and a `findsNothing`
      // on the hidden card would not catch that. Measured against a gap where
      // nothing is hidden, so the assertion calibrates itself: `InSpacing.md`
      // reads `MediaQuery`, which the harness leaves at its default width.
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
      final control =
          tester.getTopLeft(find.byType(ClientDetailAddressCard)).dy -
          tester.getBottomLeft(find.byType(ClientDetailDetailsCard)).dy;
      final gap =
          tester.getTopLeft(find.byType(ClientDetailNotesCard)).dy -
          tester.getBottomLeft(find.byType(ClientDetailAddressCard)).dy;
      expect(gap, control, reason: 'one InSpacing.md, not two');
    });

    testWidgets('shipping without billing leaves no orphaned gap above it', (
      tester,
    ) async {
      // Billing stacks above Shipping and the pair pays the same per-entry
      // gap. With only a shipping address, Shipping must line up with the card
      // beside it rather than sit one gap low.
      await _pump(
        tester,
        _client(phone: '555-1234', shippingAddress1: '2 Depot Rd'),
        1200,
      );
      expect(find.byType(ClientDetailAddressCard), findsNothing);
      expect(
        tester.getTopLeft(find.byType(ClientDetailShippingAddressCard)).dy,
        tester.getTopLeft(find.byType(ClientDetailDetailsCard)).dy,
      );
    });

    testWidgets('billing and shipping keep a gap between them', (tester) async {
      // Converse of the test above, so gating the gap can't glue them together.
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

    // ─────────── addresses ───────────

    testWidgets('an address is one block, not a row per line', (tester) async {
      await _pump(tester, _client(address1: '1 Main St'), 500);
      expect(find.text('1 Main St'), findsOneWidget);
      expect(find.text('View Map'), findsOneWidget);
      // The old rows were labelled Address1 / City / Country.
      expect(find.text('Address1'), findsNothing);
      expect(find.text('City'), findsNothing);
      // On its own it is simply the address.
      expect(find.text('Address'), findsOneWidget);
    });

    testWidgets('a different shipping address gets its own block, and both '
        'are named', (tester) async {
      await _pump(
        tester,
        _client(address1: '1 Main St', shippingAddress1: '2 Depot Rd'),
        500,
      );
      expect(find.text('Billing Address'), findsOneWidget);
      expect(find.text('Shipping Address'), findsOneWidget);
      expect(find.text('View Map'), findsNWidgets(2));
    });

    testWidgets('a shipping address that is the billing address is shown once, '
        'and says so', (tester) async {
      // Dropping it silently would leave a user wondering whether this client
      // ships somewhere that was never entered.
      await _pump(
        tester,
        _client(address1: '1 Main St', shippingAddress1: '1 Main St'),
        500,
      );
      expect(find.byType(ClientDetailShippingAddressCard), findsNothing);
      expect(find.text('Billing Address · Shipping Address'), findsOneWidget);
      expect(find.text('1 Main St'), findsOneWidget);
    });

    // ─────────── details the edit screen sets ───────────

    testWidgets('fields set on the edit screen are shown here', (tester) async {
      await _pump(
        tester,
        _client(paymentTerms: '30', hasValidVatNumber: true),
        500,
      );
      expect(find.text('Payment Terms'), findsOneWidget);
      expect(find.text('30 Days'), findsOneWidget);
      expect(find.text('Valid VAT Number'), findsOneWidget);
    });
  });
}
