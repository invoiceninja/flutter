import 'package:admin/data/models/value/country.dart';
import 'package:admin/data/services/device_contacts_service.dart';
import 'package:admin/data/services/device_contacts_service_web.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final countries = [
    Country.fromMap({'id': '840', 'name': 'United States', 'iso_3166_2': 'US'}),
    Country.fromMap({
      'id': '826',
      'name': 'United Kingdom',
      'iso_3166_2': 'GB',
    }),
  ];

  group('resolveCountryId', () {
    test('matches the ISO alpha-2 code, case-insensitively', () {
      expect(resolveCountryId(countries, iso2: 'US', name: ''), '840');
      expect(resolveCountryId(countries, iso2: 'gb', name: ''), '826');
    });

    test('falls back to the country name when no ISO code is given', () {
      expect(
        resolveCountryId(countries, iso2: '', name: 'united states'),
        '840',
      );
      expect(
        resolveCountryId(countries, iso2: '', name: 'United Kingdom'),
        '826',
      );
    });

    test('prefers the ISO code over the name', () {
      // ISO says GB, name says US → ISO wins.
      expect(
        resolveCountryId(countries, iso2: 'GB', name: 'United States'),
        '826',
      );
    });

    test('returns empty string on no match or empty inputs', () {
      expect(resolveCountryId(countries, iso2: 'ZZ', name: 'Atlantis'), '');
      expect(resolveCountryId(countries, iso2: '', name: ''), '');
      expect(resolveCountryId(const [], iso2: 'US', name: 'United States'), '');
    });

    test(
      'displayLabel prefers the full name, then displayName, org, email',
      () {
        expect(
          const DeviceContactImport(
            firstName: 'Ada',
            lastName: 'Lovelace',
          ).displayLabel,
          'Ada Lovelace',
        );
        expect(
          const DeviceContactImport(displayName: 'Ada L.').displayLabel,
          'Ada L.',
        );
        expect(
          const DeviceContactImport(
            organization: 'Analytical Engines',
          ).displayLabel,
          'Analytical Engines',
        );
        expect(
          const DeviceContactImport(email: 'ada@x.test').displayLabel,
          'ada@x.test',
        );
      },
    );
  });

  group('UnsupportedDeviceContactsService (web / non-iOS stub)', () {
    test('reports unavailable and picks nothing', () async {
      const svc = UnsupportedDeviceContactsService();
      expect(svc.isAvailable, isFalse);
      expect(await svc.pickContact(), isNull);
    });
  });

  // Android merges a card into the user's own contact for the same person,
  // and flutter_contacts deletes and updates the whole merged contact. This
  // rule is all that keeps a delete from taking the user's copy with ours.
  group('ownsDeviceContact', () {
    test('only a contact that is exactly our one recorded entry is ours', () {
      expect(ownsDeviceContact(recorded: 'r1', entryIds: ['r1']), isTrue);
    });

    test('a contact merged with anyone else is never ours', () {
      expect(
        ownsDeviceContact(recorded: 'r1', entryIds: ['r1', 'user-9']),
        isFalse,
      );
    });

    test('a contact that no longer holds our entry is not ours — split apart, '
        'the id now belongs to the user\'s half', () {
      expect(ownsDeviceContact(recorded: 'r1', entryIds: ['user-9']), isFalse);
    });

    test('an unidentified entry is never ours, even on its own', () {
      expect(
        ownsDeviceContact(recorded: kUnidentifiedEntry, entryIds: ['x']),
        isFalse,
      );
    });

    test('an unreadable contact is never ours', () {
      expect(ownsDeviceContact(recorded: 'r1', entryIds: const []), isFalse);
      expect(ownsDeviceContact(recorded: null, entryIds: const []), isFalse);
    });

    test('a row from before the column is adopted on a single entry only', () {
      expect(ownsDeviceContact(recorded: null, entryIds: ['r1']), isTrue);
      expect(ownsDeviceContact(recorded: null, entryIds: ['a', 'b']), isFalse);
    });
  });

  group('entryIdToRecord', () {
    test('records the only entry, marks a merged contact unidentified, and '
        'leaves an unreadable one unchecked', () {
      expect(entryIdToRecord(['r1']), 'r1');
      expect(entryIdToRecord(['r1', 'user-9']), kUnidentifiedEntry);
      expect(entryIdToRecord(const []), isNull);
    });
  });
}
