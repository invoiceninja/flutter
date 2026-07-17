import 'package:admin/data/models/value/money.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Decimal d(String s) => Decimal.parse(s);

  group('parseFormattedMoney (report export locale formatting) — #0', () {
    test('plain machine numbers pass through', () {
      expect(parseFormattedMoney('1234.00'), d('1234.00'));
      expect(parseFormattedMoney('0.5'), d('0.5'));
      expect(parseFormattedMoney('-100'), d('-100'));
      expect(parseFormattedMoney(3238), d('3238'));
      expect(parseFormattedMoney(3238.5), d('3238.5'));
      expect(parseFormattedMoney(''), Decimal.zero);
      expect(parseFormattedMoney(null), Decimal.zero);
    });

    test('US format (comma thousands, dot decimal)', () {
      expect(parseFormattedMoney('3,238.00'), d('3238.00'));
      expect(parseFormattedMoney('238.00'), d('238.00'));
      expect(parseFormattedMoney('1,234,567.89'), d('1234567.89'));
      expect(parseFormattedMoney('-1,234.50'), d('-1234.50'));
    });

    test('EU/German format (dot thousands, comma decimal)', () {
      expect(parseFormattedMoney('3.238,00'), d('3238.00'));
      expect(parseFormattedMoney('3,50'), d('3.50'));
      expect(parseFormattedMoney('238,00'), d('238.00'));
      expect(parseFormattedMoney('1.234.567,89'), d('1234567.89'));
    });

    test('0-decimal currency (JPY): all separators are grouping', () {
      expect(parseFormattedMoney('3,238'), d('3238'));
      expect(parseFormattedMoney('1,234,567'), d('1234567'));
      expect(parseFormattedMoney('238'), d('238'));
    });

    test('the CRITICAL regression: a value >= 1000 no longer zeroes', () {
      // Before the fix parseMoney("3,238.00") == Decimal.zero, so a report
      // total of $3,238 + $238 rendered as $238.
      final total =
          parseFormattedMoney('3,238.00') + parseFormattedMoney('238.00');
      expect(total, d('3476.00'));
    });
  });
}
