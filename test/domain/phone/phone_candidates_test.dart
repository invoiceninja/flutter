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
    String email = '',
    String phone = '',
    bool isPrimary = false,
    bool isDeleted = false,
  }) => ContactApi(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
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
  group('clientCallLogCandidates', () {
    // The log-call form's Contact field answers "who did you speak to", not
    // "which number do I dial" (invoiceninja/flutter#129), so this walk keeps
    // rows the dialer's deliberately drops. Same order, same deleted-contact
    // filter, same stored-string rule.

    test('keeps a named contact with no number, in its usual position', () {
      final result = clientCallLogCandidates(
        client(
          contacts: [
            contact(id: '1', firstName: 'Bob', phone: '+1 415 555 0001'),
            contact(id: '2', firstName: 'Jane', isPrimary: true),
            contact(id: '3', firstName: 'Zoe', phone: '+1 415 555 0003'),
          ],
        ),
      );

      // Interleaved, not appended: the primary contact is what seeds the
      // Contact field, and appending would push it below a stranger.
      expect(result.map((c) => c.label), ['Jane', 'Bob', 'Zoe']);
      expect(result.first.phone, isEmpty);
      expect(result.first.isPrimary, isTrue);
    });

    test('keeps every contact sharing one switchboard number', () {
      // Two colleagues on the office line are one entry in the dialer and two
      // different answers here. The dedupe silently kept only the first.
      final result = clientCallLogCandidates(
        client(
          contacts: [
            contact(id: '1', firstName: 'Jane', phone: '+1 415 555 0002'),
            contact(id: '2', firstName: 'Bob', phone: '+1 (415) 555-0002'),
            contact(id: '3', firstName: 'Zoe', phone: '+14155550002'),
          ],
        ),
      );

      expect(result.map((c) => c.label), ['Jane', 'Bob', 'Zoe']);
    });

    test("the party's own line still collapses into a contact's", () {
      // Only the own line is deduped, so the common "office number repeated on
      // the primary contact" case doesn't render the same number twice.
      final result = clientCallLogCandidates(
        client(
          contacts: [
            contact(id: '1', firstName: 'Jane', phone: '+1 (415) 555-0002'),
          ],
          phone: '+14155550002',
        ),
      );

      expect(result.map((c) => c.label), ['Jane']);
    });

    test('keeps three numberless contacts, not one', () {
      // The dedupe key is the normalised phone, so `seen.add('')` succeeds
      // exactly once — a numberless row registered in it would show one
      // arbitrary contact out of three and look entirely plausible.
      final result = clientCallLogCandidates(
        client(
          contacts: [
            contact(id: '1', firstName: 'Jane'),
            contact(id: '2', firstName: 'Bob'),
            contact(id: '3', firstName: 'Zoe'),
          ],
        ),
      );

      expect(result.map((c) => c.label), ['Jane', 'Bob', 'Zoe']);
    });

    test('drops the blank contact the server seeds for every client', () {
      expect(
        clientCallLogCandidates(client(contacts: [contact(id: '1')])),
        isEmpty,
      );
    });

    test('drops a nameless contact that has only an email', () {
      // Stricter than `Contact.isBlank`, which counts `email` — right for the
      // detail card, which renders the address, and wrong for a picker row that
      // would read `(no name)` with nothing under it.
      final result = clientCallLogCandidates(
        client(
          contacts: [contact(id: '1', email: 'someone@example.test')],
        ),
      );

      expect(result, isEmpty);
    });

    test('keeps a named contact whose number cannot be dialled', () {
      // `1-800-FLOWERS` is a true record of who was called even though
      // `cleanPhoneNumber` refuses it, and the note is permanent.
      final result = clientCallLogCandidates(
        client(
          contacts: [
            contact(id: '1', firstName: 'Prose', phone: '1-800-FLOWERS'),
            contact(id: '2', firstName: 'Reception', phone: 'dial 9 first'),
            contact(id: '3', phone: 'x4402'),
          ],
        ),
      );

      expect(result.map((c) => c.label), ['Prose', 'Reception']);
      expect(result.first.phone, '1-800-FLOWERS');
    });

    test("never invents a numberless row for the party's own line", () {
      final result = clientCallLogCandidates(
        client(
          contacts: [contact(id: '1', firstName: 'Jane')],
        ),
      );

      expect(result.map((c) => c.label), ['Jane']);
      expect(result.every((c) => !c.isPartyOwnLine), isTrue);
    });

    test('still drops deleted contacts', () {
      final result = clientCallLogCandidates(
        client(
          contacts: [
            contact(id: '1', firstName: 'Gone', isDeleted: true),
            contact(id: '2', firstName: 'Here'),
          ],
        ),
      );

      expect(result.map((c) => c.label), ['Here']);
    });

    test('matches the dialer exactly when every contact has a number', () {
      // The two builders share one ordering rule; only the keep/dedupe tests
      // differ. If this diverges, one of them has grown a second walk.
      final c = client(
        contacts: [
          contact(id: '1', firstName: 'Bob', phone: '+1 415 555 0001'),
          contact(
            id: '2',
            firstName: 'Jane',
            isPrimary: true,
            phone: '+1 415 555 0002',
          ),
        ],
        phone: '+1 800 555 0100',
      );

      expect(clientCallLogCandidates(c), clientPhoneCandidates(c));
    });
  });

  group('vendorCallLogCandidates', () {
    test('walks a vendor the same way', () {
      final result = vendorCallLogCandidates(
        Vendor.fromApi(
          const VendorApi(
            id: 'v1',
            name: 'Acme Supplies',
            contacts: [
              VendorContactApi(id: '1', firstName: 'Bob'),
              VendorContactApi(id: '2', firstName: 'Ada', isPrimary: true),
              VendorContactApi(id: '3'),
            ],
          ),
        ),
      );

      expect(result.map((c) => c.label), ['Ada', 'Bob']);
      expect(result.every((c) => c.phone.isEmpty), isTrue);
    });
  });
  group('clientCallLogCandidates — the dialable-name asymmetry', () {
    test('a nameless contact WITH a number is kept', () {
      // Deliberately not symmetric with `drops a nameless contact that has only
      // an email`: a number is something to show and something to act on, so
      // the row renders `(no name)` over it, exactly as the dialer's does. The
      // name test only decides the numberless case.
      final result = clientCallLogCandidates(
        client(
          contacts: [contact(id: '1', phone: '+1 415 555 0002')],
        ),
      );

      expect(result.single.label, isEmpty);
      expect(result.single.phone, '+1 415 555 0002');
    });
  });

  group('vendorCallLogCandidates — the same three rules', () {
    Vendor vendor({
      List<VendorContactApi> contacts = const [],
      String phone = '',
    }) => Vendor.fromApi(
      VendorApi(
        id: 'v1',
        name: 'Acme Supplies',
        phone: phone,
        contacts: contacts,
      ),
    );

    test('keeps every contact sharing one switchboard number', () {
      final result = vendorCallLogCandidates(
        vendor(
          contacts: const [
            VendorContactApi(id: '1', firstName: 'Ada', phone: '+1 415 555 02'),
            VendorContactApi(id: '2', firstName: 'Bob', phone: '+1 415 55502'),
          ],
        ),
      );

      expect(result.map((c) => c.label), ['Ada', 'Bob']);
    });

    test("the vendor's own line still collapses into a contact's", () {
      final result = vendorCallLogCandidates(
        vendor(
          contacts: const [
            VendorContactApi(
              id: '1',
              firstName: 'Ada',
              phone: '+1 (415) 555-0002',
            ),
          ],
          phone: '+14155550002',
        ),
      );

      expect(result.map((c) => c.label), ['Ada']);
    });

    test('keeps a named contact whose number cannot be dialled', () {
      final result = vendorCallLogCandidates(
        vendor(
          contacts: const [
            VendorContactApi(
              id: '1',
              firstName: 'Reception',
              phone: 'dial 9 first',
            ),
            VendorContactApi(id: '2', phone: 'x4402'),
          ],
        ),
      );

      expect(result.map((c) => c.label), ['Reception']);
      expect(result.single.phone, 'dial 9 first');
    });
  });
}
