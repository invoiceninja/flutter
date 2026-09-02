import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/ui/features/vendors/widgets/detail/vendor_detail_cards.dart';

/// `VendorDetailCardsGrid._stacked` pays `InSpacing.md` per *entry*, not per
/// painted card, so an entry whose `build` returns `SizedBox.shrink()` leaves a
/// doubled gap. Every entry is therefore gated on its card's `hasContent`, and
/// each must mirror the exact field set its `build` renders — the failure mode
/// is silent either way (a stray gap, or an empty bordered card).
///
/// The Details card additionally never self-hides at all: unlike its rows, it
/// always returns a `DashboardCardShell`, whose border, title and divider paint
/// regardless of an empty child.
Vendor _vendor(VendorApi Function(VendorApi) f) =>
    Vendor.fromApi(f(const VendorApi(id: 'v1', name: 'Acme', updatedAt: 1)));

void main() {
  group('VendorDetailDetailsCard.hasContent', () {
    test('a vendor with only a name has nothing to show', () {
      expect(VendorDetailDetailsCard.hasContent(_vendor((v) => v)), isFalse);
    });

    for (final entry in <String, VendorApi Function(VendorApi)>{
      'website': (v) => v.copyWith(website: 'acme.example.com'),
      'phone': (v) => v.copyWith(phone: '555-1234'),
      'vatNumber': (v) => v.copyWith(vatNumber: 'VAT1'),
      'idNumber': (v) => v.copyWith(idNumber: 'ID1'),
      'classification': (v) => v.copyWith(classification: 'company'),
      'routingId': (v) => v.copyWith(routingId: 'R1'),
      'isTaxExempt': (v) => v.copyWith(isTaxExempt: true),
      'currencyId': (v) => v.copyWith(currencyId: '1'),
      'languageId': (v) => v.copyWith(languageId: '1'),
      'lastLogin': (v) => v.copyWith(lastLogin: 1700000000),
      'customValue1': (v) => v.copyWith(customValue1: 'x'),
      'customValue4': (v) => v.copyWith(customValue4: 'x'),
    }.entries) {
      test('${entry.key} alone keeps the card', () {
        expect(
          VendorDetailDetailsCard.hasContent(_vendor(entry.value)),
          isTrue,
          reason: '${entry.key} renders a row, so it must gate the card',
        );
      });
    }

    test('a notes-only vendor does not keep it (Notes is its own card)', () {
      expect(
        VendorDetailDetailsCard.hasContent(
          _vendor((v) => v.copyWith(privateNotes: 'hi')),
        ),
        isFalse,
      );
    });
  });

  group('VendorDetailAddressCard.hasContent', () {
    test('no address at all', () {
      expect(VendorDetailAddressCard.hasContent(_vendor((v) => v)), isFalse);
    });

    for (final entry in <String, VendorApi Function(VendorApi)>{
      'address1': (v) => v.copyWith(address1: '1 Main St'),
      'address2': (v) => v.copyWith(address2: 'Apt 2'),
      'city': (v) => v.copyWith(city: 'Springfield'),
      'state': (v) => v.copyWith(state: 'IL'),
      'postalCode': (v) => v.copyWith(postalCode: '62704'),
      'countryId': (v) => v.copyWith(countryId: '840'),
    }.entries) {
      test('${entry.key} alone keeps the card', () {
        expect(
          VendorDetailAddressCard.hasContent(_vendor(entry.value)),
          isTrue,
        );
      });
    }
  });
}
