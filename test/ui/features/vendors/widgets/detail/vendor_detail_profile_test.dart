import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/ui/core/widgets/address_block.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_address_card.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_contacts_card.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_details_card.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_notes_card.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_profile.dart';
import 'package:admin/utils/formatting.dart';

import '../../../../../_responsive_helper.dart';
import '../../../../../_support/phone_actions_test_services.dart';

/// `VendorDetailProfile` is a vendor's reference fields: Contacts, Details,
/// Address and Notes — always shown. Every entry is gated on its card having
/// content, in both layouts, because the gap between cards is paid per entry.

Vendor _vendor({
  String phone = '',
  String vatNumber = '',
  String address1 = '',
  String city = '',
  String privateNotes = '',
  String publicNotes = '',
  String customValue1 = '',
  int lastLogin = 0,
  int createdAt = 0,
  int updatedAt = 0,
  List<VendorContactApi> contacts = const [],
}) => Vendor.fromApi(
  VendorApi(
    id: 'v1',
    name: 'Acme',
    phone: phone,
    vatNumber: vatNumber,
    address1: address1,
    city: city,
    privateNotes: privateNotes,
    publicNotes: publicNotes,
    customValue1: customValue1,
    lastLogin: lastLogin,
    createdAt: createdAt,
    updatedAt: updatedAt,
    contacts: contacts,
  ),
);

/// The all-blank contact the server keeps on every vendor.
const _blankContact = VendorContactApi(id: 'blank', isPrimary: true);
const _lead = VendorContactApi(
  id: 'ct1',
  firstName: 'Ada',
  lastName: 'Lovelace',
  isPrimary: true,
);
const _second = VendorContactApi(
  id: 'ct2',
  firstName: 'Grace',
  lastName: 'Hopper',
);
const _third = VendorContactApi(
  id: 'ct3',
  firstName: 'Mary',
  lastName: 'Shelley',
);

// `phoneActions: true` — the Details card's phone row is a tap-to-call link,
// and `PhoneActionsScope` reads `Provider<Services>`.
Future<void> _pump(
  WidgetTester tester,
  Vendor vendor,
  double width, {
  Formatter? formatter,
}) => pumpAt(
  tester,
  width,
  VendorDetailProfile(vendor: vendor, company: null, formatter: formatter),
  phoneActions: true,
);

void main() {
  group('which cards', () {
    testWidgets('a vendor with only a name builds no card at any width', (
      tester,
    ) async {
      for (final width in [500.0, 1200.0]) {
        await _pump(tester, _vendor(), width);
        expect(find.byType(VendorDetailDetailsCard), findsNothing);
        expect(find.byType(VendorDetailAddressCard), findsNothing);
        expect(find.byType(VendorDetailContactsCard), findsNothing);
        expect(find.byType(VendorDetailNotesCard), findsNothing);
      }
    });

    testWidgets('only populated rows render — no label, no dash', (
      tester,
    ) async {
      for (final width in [500.0, 1200.0]) {
        await _pump(tester, _vendor(phone: '555-1234'), width);
        expect(find.text('Phone'), findsOneWidget);
        expect(find.text('555-1234'), findsOneWidget);
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
      // it. The emptiness check this replaced counted the value regardless,
      // which opened a titled "Details" card with nothing in it.
      await _pump(tester, _vendor(customValue1: 'orphan'), 500);
      expect(find.byType(VendorDetailDetailsCard), findsNothing);
    });

    testWidgets('notes alone open the Notes card and nothing else', (
      tester,
    ) async {
      await _pump(tester, _vendor(privateNotes: 'Net 30.'), 500);
      expect(find.byType(VendorDetailNotesCard), findsOneWidget);
      expect(find.text('Net 30.'), findsOneWidget);
      expect(find.byType(VendorDetailDetailsCard), findsNothing);
    });

    testWidgets('notes that are only markup are not content', (tester) async {
      // Both fields are HTML on the wire.
      await _pump(
        tester,
        _vendor(privateNotes: '<p></p>', publicNotes: '<p><br></p>'),
        500,
      );
      expect(find.byType(VendorDetailNotesCard), findsNothing);
    });

    testWidgets('every contact is in the card, and the blank one the server '
        'seeds is not', (tester) async {
      await _pump(
        tester,
        _vendor(contacts: const [_blankContact, _second, _third]),
        500,
      );
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Mary Shelley'), findsOneWidget);
      expect(find.textContaining('no name'), findsNothing);
    });

    testWidgets('a vendor whose only contact is blank has no Contacts card', (
      tester,
    ) async {
      await _pump(
        tester,
        _vendor(phone: '555-1234', contacts: const [_blankContact]),
        1200,
      );
      expect(find.byType(VendorDetailContactsCard), findsNothing);
    });
  });

  group('details', () {
    testWidgets('the dates sit at the foot once there is a formatter', (
      tester,
    ) async {
      // Created / updated moved here from under the vendor's name. Far from
      // midnight UTC, so the local calendar day is the same everywhere.
      await _pump(
        tester,
        _vendor(
          vatNumber: 'DE1',
          createdAt: 1700049600, // 2023-11-15 12:00 UTC
          updatedAt: 1710504000, // 2024-03-15 12:00 UTC
        ),
        500,
        formatter: testFormatter,
      );
      expect(find.text('Date Created'), findsOneWidget);
      expect(find.text('15/Nov/2023'), findsOneWidget);
      expect(find.text('Updated'), findsOneWidget);
      expect(find.text('15/Mar/2024'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Date Created')).dy,
        greaterThan(tester.getTopLeft(find.text('VAT Number')).dy),
      );
    });

    testWidgets('the last portal login is a local calendar day', (
      tester,
    ) async {
      await _pump(
        tester,
        _vendor(lastLogin: 1710504000), // 2024-03-15 12:00 UTC
        500,
        formatter: testFormatter,
      );
      expect(find.text('Last Login'), findsOneWidget);
      expect(find.text('15/Mar/2024'), findsOneWidget);
    });

    test('hasContent is the rows the card draws', () {
      // Checked through the widget tests above for the cases that need a
      // context; this pins the address half, which needs none.
      expect(VendorDetailAddressCard.hasContent(_vendor()), isFalse);
      expect(
        VendorDetailAddressCard.hasContent(_vendor(address1: '1 Main St')),
        isTrue,
      );
      expect(
        VendorDetailAddressCard.hasContent(_vendor(city: 'Springfield')),
        isTrue,
      );
    });
  });

  group('address', () {
    testWidgets('one copyable block with a map link', (tester) async {
      await _pump(
        tester,
        _vendor(address1: '1 Main St', city: 'Springfield'),
        500,
      );
      expect(find.byType(AddressBlock), findsOneWidget);
      // One block, not a row per field: the old card put the city under a
      // label of its own.
      expect(find.text('1 Main St\nSpringfield'), findsOneWidget);
      expect(find.text('City'), findsNothing);
      expect(find.text('View Map'), findsOneWidget);
    });

    test('a country alone is not an address', () {
      // The server gives every vendor a country — the company's own when none
      // was sent — so counting it opened an Address card holding one word and
      // a map link on every vendor ever created.
      final vendor = Vendor.fromApi(
        const VendorApi(id: 'v1', name: 'Acme', countryId: '840'),
      );
      expect(VendorDetailAddressCard.hasContent(vendor), isFalse);
    });
  });

  group('layout', () {
    testWidgets('wide: the lead sections share one row, as equal cards', (
      tester,
    ) async {
      await _pump(
        tester,
        _vendor(
          phone: '555-1234',
          address1: '1 Main St',
          contacts: const [_lead, _second],
        ),
        1200,
      );
      final top = tester.getTopLeft(find.byType(VendorDetailContactsCard)).dy;
      expect(tester.getTopLeft(find.byType(VendorDetailDetailsCard)).dy, top);
      expect(tester.getTopLeft(find.byType(VendorDetailAddressCard)).dy, top);
      final widths = [
        tester.getSize(find.byType(VendorDetailContactsCard)).width,
        tester.getSize(find.byType(VendorDetailDetailsCard)).width,
        tester.getSize(find.byType(VendorDetailAddressCard)).width,
      ];
      expect(widths[1], moreOrLessEquals(widths[0], epsilon: 0.5));
      expect(widths[2], moreOrLessEquals(widths[0], epsilon: 0.5));
      expect(widths[0], lessThan(450), reason: 'a third of the row');
      // Contacts leads: who to talk to comes before the reference fields.
      expect(
        tester.getTopLeft(find.byType(VendorDetailContactsCard)).dx,
        lessThan(tester.getTopLeft(find.byType(VendorDetailDetailsCard)).dx),
      );
    });

    testWidgets('wide: the three cards end on one line', (tester) async {
      // Three contacts make that card the tall one; the other two have to be
      // stretched to it, not stop where their own text does.
      await _pump(
        tester,
        _vendor(
          phone: '555-1234',
          address1: '1 Main St',
          contacts: const [_lead, _second, _third],
        ),
        1200,
      );
      final contacts = tester.getRect(find.byType(VendorDetailContactsCard));
      final details = tester.getRect(find.byType(VendorDetailDetailsCard));
      final address = tester.getRect(find.byType(VendorDetailAddressCard));
      expect(details.bottom, contacts.bottom);
      expect(address.bottom, contacts.bottom);
      expect(address.height, greaterThan(140), reason: 'taller than its text');
    });

    testWidgets('wide: the tallest card can be any of the three', (
      tester,
    ) async {
      // Details is the long one here.
      await _pump(
        tester,
        _vendor(
          phone: '555-1234',
          vatNumber: 'DE1',
          address1: '1 Main St',
          createdAt: 1700049600,
          updatedAt: 1710504000,
          lastLogin: 1710504000,
          contacts: const [_lead],
        ),
        1200,
        formatter: testFormatter,
      );
      final contacts = tester.getRect(find.byType(VendorDetailContactsCard));
      final details = tester.getRect(find.byType(VendorDetailDetailsCard));
      final address = tester.getRect(find.byType(VendorDetailAddressCard));
      expect(contacts.bottom, details.bottom);
      expect(address.bottom, details.bottom);
    });

    testWidgets('wide: notes run full width beneath the row', (tester) async {
      await _pump(
        tester,
        _vendor(
          phone: '555-1234',
          address1: '1 Main St',
          privateNotes: 'Net 30.',
        ),
        1200,
      );
      final notes = tester.getRect(find.byType(VendorDetailNotesCard));
      final details = tester.getRect(find.byType(VendorDetailDetailsCard));
      expect(notes.top, greaterThan(details.bottom));
      expect(notes.width, greaterThan(1100));
    });

    testWidgets('wide: a missing section gives its width to the others', (
      tester,
    ) async {
      // No contact at all, so two columns share the width instead of three.
      await _pump(tester, _vendor(phone: '555-1234', address1: '1 Main'), 1200);
      expect(find.byType(VendorDetailContactsCard), findsNothing);
      expect(
        tester.getSize(find.byType(VendorDetailDetailsCard)).width,
        greaterThan(500),
      );
    });

    testWidgets('wide: a single section spans the profile', (tester) async {
      await _pump(tester, _vendor(phone: '555-1234'), 1200);
      expect(
        tester.getSize(find.byType(VendorDetailDetailsCard)).width,
        greaterThan(1100),
      );
    });

    testWidgets('narrow: sections stack, each only as tall as its content', (
      tester,
    ) async {
      await _pump(
        tester,
        _vendor(phone: '555-1234', address1: '1 Main', contacts: const [_lead]),
        500,
      );
      expect(tester.takeException(), isNull);
      final contacts = tester.getRect(find.byType(VendorDetailContactsCard));
      final details = tester.getRect(find.byType(VendorDetailDetailsCard));
      final address = tester.getRect(find.byType(VendorDetailAddressCard));
      expect(details.top, greaterThan(contacts.bottom));
      expect(address.top, greaterThan(details.bottom));
      expect(address.height, lessThan(160));
    });

    testWidgets('a section with no content does not leave a doubled gap', (
      tester,
    ) async {
      // The gap is paid per *entry*, so an entry whose card built nothing
      // would leave `md + 0 + md` between its neighbours — and a `findsNothing`
      // on the hidden card would not catch that. Measured against a gap where
      // nothing is hidden, so the assertion calibrates itself.
      await _pump(
        tester,
        _vendor(
          phone: '555-1234',
          address1: '1 Main St',
          privateNotes: 'note',
          contacts: const [_blankContact],
        ),
        500,
      );
      expect(find.byType(VendorDetailContactsCard), findsNothing);
      final control =
          tester.getTopLeft(find.byType(VendorDetailAddressCard)).dy -
          tester.getBottomLeft(find.byType(VendorDetailDetailsCard)).dy;
      final gap =
          tester.getTopLeft(find.byType(VendorDetailNotesCard)).dy -
          tester.getBottomLeft(find.byType(VendorDetailAddressCard)).dy;
      expect(gap, control, reason: 'one InSpacing.md, not two');
      // …and the first card sits at the very top, with no gap above it for
      // the Contacts card that is not there.
      expect(tester.getTopLeft(find.byType(VendorDetailDetailsCard)).dy, 0);
    });

    testWidgets('nothing overflows at any width', (tester) async {
      final vendor = _vendor(
        phone: '+49 30 5550 1212',
        vatNumber: 'DE811907980',
        address1: 'Friedrichstraße 112',
        city: 'Berlin',
        privateNotes: 'Net 30.',
        contacts: const [
          VendorContactApi(
            id: 'k1',
            firstName: 'Katrin',
            lastName: 'Vogel',
            email: 'katrin.vogel@brandenburg-office-supply.example.com',
            phone: '+49 30 5550 1213',
            isPrimary: true,
            link: 'https://portal.example.com/vendor/key_login/abc',
          ),
        ],
      );
      for (final width in [320.0, ...kResponsiveWidths, 1560.0]) {
        await _pump(tester, vendor, width);
        expectNoOverflow(tester);
      }
      // …nor at the largest text the app's own setting allows.
      for (final width in [320.0, 500.0, 1200.0]) {
        await pumpAt(
          tester,
          width,
          VendorDetailProfile(vendor: vendor, company: null),
          phoneActions: true,
          textScale: kTextScaleMax,
        );
        expectNoOverflow(tester);
      }
    });
  });
}
