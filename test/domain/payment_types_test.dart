// Payment types under the company's own names, and the hidden list
// (invoiceninja/flutter#191, docs/payment-types.md).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/payment_types.dart';
import 'package:admin/l10n/localization.dart';

void main() {
  group('kPaymentTypeLabelKeys', () {
    test('every key is a string the app bundles', () {
      Map<String, dynamic> read(String path) =>
          jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      final en = read('assets/i18n/en.json');
      final pending = read('assets/i18n/_app_pending.json');
      final missing = [
        for (final key in kPaymentTypeLabelKeys.values)
          if ((en[key] ?? pending[key]) == null) key,
      ];
      expect(missing, isEmpty);
    });

    // The server names these by other keys in its documents (`fpx`,
    // `bank_transfer`), so no one key renames them consistently.
    test('leaves out FPX (46) and Stripe Bank Transfer (50)', () {
      expect(kPaymentTypeLabelKeys.containsKey('46'), isFalse);
      expect(kPaymentTypeLabelKeys.containsKey('50'), isFalse);
    });
  });

  group('paymentTypeLabel', () {
    final bundle = {'payment_type_Instant Bank Pay': 'Instant Bank Pay'};

    test('a company name replaces the server\'s', () {
      final l10n = Localization.forTesting(
        strings: bundle,
      ).withOverrides({'payment_type_Instant Bank Pay': 'Echtzeitüberweisung'});
      expect(
        paymentTypeLabel(l10n, '45', 'Instant Bank Pay'),
        'Echtzeitüberweisung',
      );
    });

    // The server's name is already in the user's language; the bundle may
    // not be, so it never replaces it.
    test('without one, the server\'s name stays', () {
      final l10n = Localization.forTesting(strings: bundle);
      expect(
        paymentTypeLabel(l10n, '45', 'Sofortüberweisung (Server)'),
        'Sofortüberweisung (Server)',
      );
    });

    test('an id with no key, or no Localization, keeps the server\'s', () {
      final l10n = Localization.forTesting(
        strings: bundle,
      ).withOverrides({'fpx': 'Renamed'});
      expect(paymentTypeLabel(l10n, '46', 'FPX'), 'FPX');
      expect(paymentTypeLabel(l10n, '999', 'Future Type'), 'Future Type');
      expect(
        paymentTypeLabel(null, '45', 'Instant Bank Pay'),
        'Instant Bank Pay',
      );
    });
  });

  group('hidden_payment_types', () {
    test('parses a comma list, dropping blanks', () {
      expect(parseHiddenPaymentTypes(null), isEmpty);
      expect(parseHiddenPaymentTypes(''), isEmpty);
      expect(parseHiddenPaymentTypes(' 3, ,12,'), {'3', '12'});
    });

    test('encodes in numeric order, and none as an empty string', () {
      expect(encodeHiddenPaymentTypes({'12', '3', '25'}), '3,12,25');
      expect(encodeHiddenPaymentTypes(const <String>{}), '');
    });
  });
}
