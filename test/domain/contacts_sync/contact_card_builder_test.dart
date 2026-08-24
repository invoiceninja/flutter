import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/client.dart';
import 'package:admin/data/models/domain/contact.dart';
import 'package:admin/data/models/value/country.dart';
import 'package:admin/domain/contacts_sync/contact_card_builder.dart';

const _countries = <String, Country>{
  '840': Country(
    id: '840',
    name: 'United States',
    iso2: 'US',
    iso3: 'USA',
    swapCurrencySymbol: false,
    thousandSeparator: ',',
    decimalSeparator: '.',
    swapPostalCode: false,
  ),
};

Contact _contact(
  String id, {
  String firstName = 'Jane',
  String lastName = 'Smith',
  String email = '',
  String phone = '',
  bool isPrimary = false,
  bool isDeleted = false,
}) => Contact(
  id: id,
  firstName: firstName,
  lastName: lastName,
  email: email,
  phone: phone,
  isPrimary: isPrimary,
  sendEmail: true,
  isDeleted: isDeleted,
  updatedAt: DateTime.utc(2026),
);

Client _client({
  String id = 'c1',
  String name = 'Acme Corp',
  String displayName = 'Acme Corp',
  String phone = '',
  String website = '',
  String address1 = '',
  String city = '',
  String countryId = '',
  List<Contact> contacts = const [],
}) => Client(
  id: id,
  name: name,
  displayName: displayName,
  number: '',
  idNumber: '',
  vatNumber: '',
  website: website,
  phone: phone,
  address1: address1,
  address2: '',
  city: city,
  state: '',
  postalCode: '',
  countryId: countryId,
  balance: Decimal.zero,
  paidToDate: Decimal.zero,
  creditBalance: Decimal.zero,
  currencyId: '',
  languageId: '',
  paymentTerms: '',
  privateNotes: '',
  publicNotes: '',
  groupSettingsId: '',
  assignedUserId: '',
  updatedAt: DateTime.utc(2026),
  createdAt: DateTime.utc(2026),
  archivedAt: null,
  isDeleted: false,
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  contacts: contacts,
);

void main() {
  group('primaryContact', () {
    test('prefers the flagged primary over list order', () {
      final first = _contact('a');
      final flagged = _contact('b', isPrimary: true);
      expect(primaryContact([first, flagged])?.id, 'b');
    });

    test('falls back to the first when nothing is flagged', () {
      expect(primaryContact([_contact('a'), _contact('b')])?.id, 'a');
    });

    test('is null for an empty list', () {
      expect(primaryContact(const []), isNull);
    });
  });

  group('buildCards', () {
    test('emits one card per contact, with the client as the organization', () {
      final cards = buildCards(
        _client(
          contacts: [
            _contact('k1', firstName: 'Jane', phone: '555-0142'),
            _contact('k2', firstName: 'Bob', phone: '555-0143'),
          ],
        ),
        countries: _countries,
      );

      expect(cards.map((c) => c.sourceId), ['k1', 'k2']);
      expect(cards.every((c) => c.organization == 'Acme Corp'), isTrue);
      expect(cards.first.firstName, 'Jane');
    });

    test('the client phone rides along on the primary card only — otherwise a '
        'client with five contacts plants the same number five times', () {
      final cards = buildCards(
        _client(
          phone: '555-0100',
          contacts: [
            _contact('k1', phone: '555-0142', isPrimary: true),
            _contact('k2', phone: '555-0143'),
          ],
        ),
        countries: _countries,
      );

      final primary = cards.firstWhere((c) => c.sourceId == 'k1');
      final other = cards.firstWhere((c) => c.sourceId == 'k2');
      expect(primary.phones.map((p) => p.number), ['555-0142', '555-0100']);
      expect(primary.phones.last.isWork, isTrue);
      expect(other.phones.map((p) => p.number), ['555-0143']);
    });

    test('does not duplicate the client phone when it only differs in '
        'formatting from the contact phone', () {
      final cards = buildCards(
        _client(
          phone: '(555) 010-0000',
          contacts: [_contact('k1', phone: '5550100000', isPrimary: true)],
        ),
        countries: _countries,
      );
      expect(cards.single.phones, hasLength(1));
    });

    test('an unnamed contact borrows the client name so a call resolves to '
        'something better than a bare number', () {
      final cards = buildCards(
        _client(
          contacts: [
            _contact('k1', firstName: '', lastName: '', phone: '555-0142'),
          ],
        ),
        countries: _countries,
      );
      expect(cards.single.firstName, 'Acme Corp');
      expect(cards.single.lastName, '');
    });

    test('drops a contact carrying neither a phone nor an email', () {
      final cards = buildCards(
        _client(contacts: [_contact('k1')]),
        countries: _countries,
      );
      // Falls through to the client fallback, which is also useless here.
      expect(cards, isEmpty);
    });

    test('keeps an email-only contact — useful for "who emailed me"', () {
      final cards = buildCards(
        _client(contacts: [_contact('k1', email: 'jane@acme.com')]),
        countries: _countries,
      );
      expect(cards.single.sourceId, 'k1');
      expect(cards.single.phones, isEmpty);
    });

    test('skips deleted contacts', () {
      final cards = buildCards(
        _client(
          contacts: [
            _contact('k1', phone: '555-0142', isDeleted: true),
            _contact('k2', phone: '555-0143'),
          ],
        ),
        countries: _countries,
      );
      expect(cards.map((c) => c.sourceId), ['k2']);
    });

    test('skips a contact with no id — there would be no stable link key, so '
        'it would be re-created and duplicated on every run', () {
      final cards = buildCards(
        _client(
          contacts: [
            _contact('', phone: '555-0142'),
            _contact('k2', phone: '555-0143'),
          ],
        ),
        countries: _countries,
      );
      expect(cards.map((c) => c.sourceId), ['k2']);
    });

    test('a client with no contacts still yields one card from its own record '
        'so a company that never named a person is not invisible', () {
      final cards = buildCards(
        _client(phone: '555-0100', website: 'acme.com'),
        countries: _countries,
      );
      expect(cards.single.sourceId, 'client:c1');
      expect(cards.single.firstName, 'Acme Corp');
      expect(cards.single.phones.single.number, '555-0100');
      expect(cards.single.phones.single.isWork, isTrue);
      expect(cards.single.website, 'acme.com');
    });

    test(
      'a client with neither contacts nor a phone yields nothing at all',
      () {
        expect(buildCards(_client(), countries: _countries), isEmpty);
      },
    );

    test('the fallback is not emitted when any contact produced a card', () {
      final cards = buildCards(
        _client(
          phone: '555-0100',
          contacts: [_contact('k1', phone: '555-1')],
        ),
        countries: _countries,
      );
      expect(cards.map((c) => c.sourceId), ['k1']);
    });

    test('resolves the country name from the numeric country id', () {
      final cards = buildCards(
        _client(
          countryId: '840',
          address1: '12 Main St',
          city: 'Springfield',
          contacts: [_contact('k1', phone: '555-0142')],
        ),
        countries: _countries,
      );
      expect(cards.single.countryName, 'United States');
      expect(cards.single.address1, '12 Main St');
      expect(cards.single.city, 'Springfield');
    });

    test('an unknown country id leaves the name blank rather than leaking '
        'the raw id onto the contact card', () {
      final cards = buildCards(
        _client(
          countryId: '9999',
          contacts: [_contact('k1', phone: '555-1')],
        ),
        countries: _countries,
      );
      expect(cards.single.countryName, '');
    });

    test('falls back to name when displayName is blank', () {
      final cards = buildCards(
        _client(
          displayName: '',
          name: 'Acme Corp',
          contacts: [_contact('k1', phone: '555-1')],
        ),
        countries: _countries,
      );
      expect(cards.single.organization, 'Acme Corp');
    });
  });

  group('cardHash', () {
    Client clientWith({String phone = '555-0142', String first = 'Jane'}) =>
        _client(
          contacts: [_contact('k1', firstName: first, phone: phone)],
        );

    test('is stable for identical content', () {
      final a = buildCards(clientWith(), countries: _countries).single;
      final b = buildCards(clientWith(), countries: _countries).single;
      expect(cardHash(a), cardHash(b));
    });

    test('changes when a mapped field changes', () {
      final a = buildCards(clientWith(), countries: _countries).single;
      final b = buildCards(
        clientWith(first: 'Janet'),
        countries: _countries,
      ).single;
      expect(cardHash(a), isNot(cardHash(b)));
    });

    test('changes when a phone changes — the field the whole feature is '
        'about, and the one a stale hash would silently pin', () {
      final a = buildCards(clientWith(), countries: _countries).single;
      final b = buildCards(
        clientWith(phone: '555-9999'),
        countries: _countries,
      ).single;
      expect(cardHash(a), isNot(cardHash(b)));
    });

    test('does not collide across a field boundary — "Jane Smith"/"" and '
        '"Jane"/"Smith" are different cards', () {
      final joined = buildCards(
        _client(
          contacts: [
            _contact('k1', firstName: 'Jane Smith', lastName: '', phone: '1'),
          ],
        ),
        countries: _countries,
      ).single;
      final split = buildCards(
        _client(
          contacts: [
            _contact('k1', firstName: 'Jane', lastName: 'Smith', phone: '1'),
          ],
        ),
        countries: _countries,
      ).single;
      expect(cardHash(joined), isNot(cardHash(split)));
    });
  });
}
