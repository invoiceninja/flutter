import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/client_api_model.dart';
import 'package:admin/data/models/api/contact_api_model.dart';
import 'package:admin/data/models/api/vendor_api_model.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/phone/phone_candidates.dart';

/// The ordering + filtering rule behind the billing-doc header's call button
/// (invoiceninja/flutter#110). Pure — no Drift, no `Services`, no widget tree,
/// which is the reason it lives in `lib/domain/` rather than beside the widget.
void main() {
  ContactApi contact({
    required String id,
    String firstName = '',
    String lastName = '',
    String phone = '',
    bool isPrimary = false,
    bool isDeleted = false,
  }) => ContactApi(
    id: id,
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    isPrimary: isPrimary,
    isDeleted: isDeleted,
  );

  Client client({
    List<ContactApi> contacts = const [],
    String phone = '',
    String displayName = 'Acme Corporation',
  }) => Client.fromApi(
    ClientApi(
      id: 'c1',
      displayName: displayName,
      phone: phone,
      contacts: contacts,
    ),
  );

  group('clientPhoneCandidates', () {
    test('offers the primary contact first, then declaration order', () {
      final result = clientPhoneCandidates(
        client(
          contacts: [
            contact(id: '1', firstName: 'Bob', phone: '+1 415 555 0001'),
            contact(
              id: '2',
              firstName: 'Jane',
              isPrimary: true,
              phone: '+1 415 555 0002',
            ),
            contact(id: '3', firstName: 'Zoe', phone: '+1 415 555 0003'),
          ],
        ),
      );

      expect(result.map((c) => c.label), ['Jane', 'Bob', 'Zoe']);
      expect(result.first.isPrimary, isTrue);
      expect(result.every((c) => !c.isPartyOwnLine), isTrue);
    });

    test("appends the client's own line last, flagged", () {
      final result = clientPhoneCandidates(
        client(
          contacts: [
            contact(id: '1', firstName: 'Jane', phone: '+1 415 555 0002'),
          ],
          phone: '+1 800 555 0100',
        ),
      );

      expect(result.map((c) => c.phone), [
        '+1 415 555 0002',
        '+1 800 555 0100',
      ]);
      expect(result.last.isPartyOwnLine, isTrue);
      expect(result.last.label, 'Acme Corporation');
      expect(result.first.isPartyOwnLine, isFalse);
    });

    test('keeps the number as stored, not normalised', () {
      final result = clientPhoneCandidates(
        client(
          contacts: [contact(id: '1', phone: '(+1) 415-555-0002')],
        ),
      );

      // What the user typed is what the picker shows and the clipboard gets;
      // normalisation happens inside `telUri`.
      expect(result.single.phone, '(+1) 415-555-0002');
    });

    test('drops deleted contacts', () {
      final result = clientPhoneCandidates(
        client(
          contacts: [
            contact(
              id: '1',
              firstName: 'Gone',
              phone: '+1 415 555 0001',
              isDeleted: true,
            ),
            contact(id: '2', firstName: 'Here', phone: '+1 415 555 0002'),
          ],
        ),
      );

      expect(result.map((c) => c.label), ['Here']);
    });

    test('a deleted primary does not suppress a live contact', () {
      final result = clientPhoneCandidates(
        client(
          contacts: [
            contact(
              id: '1',
              firstName: 'Gone',
              isPrimary: true,
              phone: '+1 415 555 0001',
              isDeleted: true,
            ),
            contact(id: '2', firstName: 'Here', phone: '+1 415 555 0002'),
          ],
        ),
      );

      expect(result.map((c) => c.label), ['Here']);
    });

    test('drops anything cleanPhoneNumber refuses to dial', () {
      final result = clientPhoneCandidates(
        client(
          contacts: [
            contact(id: '1', firstName: 'Blank', phone: ''),
            contact(id: '2', firstName: 'Prose', phone: '1-800-FLOWERS'),
            contact(id: '3', firstName: 'Ext', phone: 'x4402'),
            contact(id: '4', firstName: 'Reception', phone: 'dial 9 first'),
            contact(id: '5', firstName: 'Real', phone: '+1 415 555 0002'),
          ],
        ),
      );

      expect(result.map((c) => c.label), ['Real']);
    });

    test('dedupes two spellings of the same number', () {
      // The client's office line repeated on its primary contact is the
      // common case, not an edge one.
      final result = clientPhoneCandidates(
        client(
          contacts: [
            contact(id: '1', firstName: 'Jane', phone: '+1 (415) 555-0002'),
          ],
          phone: '+14155550002',
        ),
      );

      expect(result.map((c) => c.label), ['Jane']);
    });

    test('is empty when nothing is dialable', () {
      expect(clientPhoneCandidates(client()), isEmpty);
      expect(
        clientPhoneCandidates(
          client(
            contacts: [contact(id: '1', phone: 'call the office')],
          ),
        ),
        isEmpty,
      );
    });

    test('leaves a nameless contact label empty for the UI to fill', () {
      // `lib/domain/` cannot call `context.tr`, so the widget substitutes
      // `no_name_fallback`.
      final result = clientPhoneCandidates(
        client(
          contacts: [contact(id: '1', phone: '+1 415 555 0002')],
        ),
      );

      expect(result.single.label, isEmpty);
    });
  });

  group('vendorPhoneCandidates', () {
    test('walks a vendor the same way', () {
      final result = vendorPhoneCandidates(
        Vendor.fromApi(
          const VendorApi(
            id: 'v1',
            name: 'Acme Supplies',
            phone: '+1 800 555 0200',
            contacts: [
              VendorContactApi(
                id: '1',
                firstName: 'Bob',
                phone: '+1 415 555 0001',
              ),
              VendorContactApi(
                id: '2',
                firstName: 'Ada',
                isPrimary: true,
                phone: '+1 415 555 0002',
              ),
              VendorContactApi(
                id: '3',
                firstName: 'Dead',
                isDeleted: true,
                phone: '+1 415 555 0003',
              ),
            ],
          ),
        ),
      );

      expect(result.map((c) => c.label), ['Ada', 'Bob', 'Acme Supplies']);
      expect(result.last.isPartyOwnLine, isTrue);
    });
  });
}
