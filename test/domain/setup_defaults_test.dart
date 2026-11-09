import 'dart:ui' show Locale;

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/value/currency.dart';
import 'package:admin/data/models/value/language.dart';
import 'package:admin/domain/setup_defaults.dart';

/// The setup wizard's starting currency and invoice language, from the
/// device locale (docs/first-run-welcome.md).
void main() {
  Currency currency(String id, String code) => Currency(
    id: id,
    name: code,
    code: code,
    symbol: '',
    precision: 2,
    thousandSeparator: ',',
    decimalSeparator: '.',
    swapCurrencySymbol: false,
    exchangeRate: Decimal.one,
  );
  final currencies = [
    currency('1', 'USD'),
    currency('2', 'GBP'),
    currency('3', 'EUR'),
    currency('9', 'CAD'),
  ];
  const languages = [
    Language(id: '1', name: 'English', locale: 'en'),
    Language(id: '7', name: 'French', locale: 'fr'),
    Language(id: '8', name: 'French (Canada)', locale: 'fr_CA'),
    Language(id: '4', name: 'German', locale: 'de'),
  ];

  test('the country picks the currency', () {
    expect(defaultCurrencyId(currencies, const Locale('en', 'GB')), '2');
    expect(defaultCurrencyId(currencies, const Locale('de', 'DE')), '3');
    expect(defaultCurrencyId(currencies, const Locale('fr', 'CA')), '9');
  });

  test('no country, or one not mapped, falls back to US Dollar', () {
    expect(defaultCurrencyId(currencies, const Locale('en')), '1');
    expect(defaultCurrencyId(currencies, const Locale('en', 'ZZ')), '1');
    expect(defaultCurrencyId(currencies, null), '1');
  });

  test('an exact language and country wins over the language alone', () {
    expect(defaultLanguageId(languages, const Locale('fr', 'CA')), '8');
    expect(defaultLanguageId(languages, const Locale('fr', 'FR')), '7');
    expect(defaultLanguageId(languages, const Locale('de', 'AT')), '4');
  });

  test('an unknown language falls back to English', () {
    expect(defaultLanguageId(languages, const Locale('xx')), '1');
    expect(defaultLanguageId(languages, null), '1');
  });
}
