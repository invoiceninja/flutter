import 'package:flutter_test/flutter_test.dart';

import 'package:admin/utils/address_format.dart';

void main() {
  group('cityStateZip', () {
    test('non-swap country renders "City, State PostalCode"', () {
      expect(
        cityStateZip(
          city: 'San Francisco',
          state: 'CA',
          postalCode: '94105',
          swapPostalCode: false,
        ),
        'San Francisco, CA 94105',
      );
    });

    test('swap country renders "PostalCode City, State"', () {
      expect(
        cityStateZip(
          city: 'Berlin',
          state: '',
          postalCode: '10115',
          swapPostalCode: true,
        ),
        '10115 Berlin',
      );
    });

    test('swap with state keeps the state after the city', () {
      expect(
        cityStateZip(
          city: 'Paris',
          state: 'Île-de-France',
          postalCode: '75001',
          swapPostalCode: true,
        ),
        '75001 Paris, Île-de-France',
      );
    });

    test('empty postal code drops the trailing separator', () {
      expect(
        cityStateZip(
          city: 'London',
          state: '',
          postalCode: '',
          swapPostalCode: false,
        ),
        'London',
      );
    });

    test('postal-only returns the postal code alone', () {
      expect(
        cityStateZip(
          city: '',
          state: '',
          postalCode: '90210',
          swapPostalCode: true,
        ),
        '90210',
      );
    });

    test('all empty returns empty', () {
      expect(
        cityStateZip(city: '', state: '', postalCode: '', swapPostalCode: true),
        '',
      );
    });
  });

  group('formatAddressLines', () {
    test('orders lines and appends the country name', () {
      expect(
        formatAddressLines(
          address1: '10 Downing St',
          address2: '',
          city: 'London',
          state: '',
          postalCode: 'SW1A 2AA',
          swapPostalCode: false,
          countryName: 'United Kingdom',
        ),
        ['10 Downing St', 'London SW1A 2AA', 'United Kingdom'],
      );
    });

    test('drops empty lines and an empty country', () {
      expect(
        formatAddressLines(
          address1: '',
          address2: 'Suite 5',
          city: 'Berlin',
          state: '',
          postalCode: '10115',
          swapPostalCode: true,
          countryName: '',
        ),
        ['Suite 5', '10115 Berlin'],
      );
    });

    test('empty address is an empty list', () {
      expect(
        formatAddressLines(
          address1: '',
          address2: '',
          city: '',
          state: '',
          postalCode: '',
          swapPostalCode: false,
        ),
        <String>[],
      );
    });
  });
}
