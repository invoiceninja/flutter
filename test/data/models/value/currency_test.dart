import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/value/currency.dart';

/// First coverage for `crossCurrencyRate` — money math with six call sites
/// (line-item editor, line-item picker, payment edit, and the expense /
/// recurring-expense currency-conversion sections) and no test until now.
///
/// The subtle part is the null guard: it fires when either currency is unknown
/// **or the *from* rate is zero**, but a zero *to* rate is not guarded and
/// yields `Decimal.zero`. Callers treat null as "leave the rate alone" and a
/// value as "overwrite it", so mixing the two up silently zeroes a converted
/// amount instead of leaving it untouched.
Currency _cur(String id, String rate) => Currency(
  id: id,
  name: 'C$id',
  code: 'C$id',
  symbol: r'$',
  precision: 2,
  thousandSeparator: ',',
  decimalSeparator: '.',
  swapCurrencySymbol: false,
  exchangeRate: Decimal.parse(rate),
);

void main() {
  final currencies = {
    '1': _cur('1', '1'), // USD base
    '2': _cur('2', '0.9'), // EUR
    '3': _cur('3', '3'),
    'zero': _cur('zero', '0'),
  };

  Decimal? rate({required String from, required String to}) =>
      crossCurrencyRate(
        currencies,
        fromExpenseCurrencyId: from,
        toInvoiceCurrencyId: to,
      );

  group('conversion', () {
    test('divides the target base rate by the source base rate', () {
      expect(rate(from: '1', to: '2'), Decimal.parse('0.9'));
    });

    test('inverts correctly in the other direction', () {
      // 1 / 0.9 needs more than 2 dp — scaleOnInfinitePrecision is 10.
      expect(rate(from: '2', to: '1'), Decimal.parse('1.1111111111'));
    });

    test('the same currency on both sides is an identity of 1', () {
      expect(rate(from: '2', to: '2'), Decimal.one);
    });

    test('a non-terminating quotient is capped at 10 decimal places', () {
      expect(rate(from: '3', to: '1'), Decimal.parse('0.3333333333'));
    });
  });

  group('null guards — caller reads null as "leave the rate alone"', () {
    test('an unknown source currency', () {
      expect(rate(from: 'nope', to: '1'), isNull);
    });

    test('an unknown target currency', () {
      expect(rate(from: '1', to: 'nope'), isNull);
    });

    test('a zero SOURCE rate (division by zero) returns null', () {
      expect(rate(from: 'zero', to: '1'), isNull);
    });

    test('a zero TARGET rate is NOT guarded — it returns zero, not null', () {
      // Deliberate asymmetry in the implementation. Pinned so a future
      // "symmetrise the guard" refactor is a conscious decision, not a
      // silent behaviour change for callers that distinguish the two.
      expect(rate(from: '1', to: 'zero'), Decimal.zero);
    });

    test('an empty currency map', () {
      expect(
        crossCurrencyRate(
          const {},
          fromExpenseCurrencyId: '1',
          toInvoiceCurrencyId: '2',
        ),
        isNull,
      );
    });
  });
}
