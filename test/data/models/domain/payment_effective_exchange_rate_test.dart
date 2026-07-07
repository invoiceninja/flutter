import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/payment_api_model.dart';
import 'package:admin/data/models/domain/payment.dart';

/// Guards [Payment.effectiveExchangeRate] — the legacy `exchange_rate == 0`
/// "no conversion" sentinel must be treated as identity (1) for the converted-
/// amount preview, not zero (which would render a $0 converted amount for an
/// already-stored zero-rate payment). Mirrors Expense.effectiveExchangeRate.
void main() {
  Payment payment({String amount = '100', String exchangeRate = '1'}) =>
      Payment.fromApi(
        PaymentApi(
          id: 'p1',
          amount: amount,
          exchangeRate: exchangeRate,
          updatedAt: 1,
        ),
      );

  test('zero exchange rate is treated as identity (1)', () {
    final p = payment(amount: '100', exchangeRate: '0');
    expect(p.effectiveExchangeRate, Decimal.one);
    expect(p.amount * p.effectiveExchangeRate, Decimal.fromInt(100));
  });

  test('non-zero exchange rate passes through unchanged', () {
    final p = payment(amount: '100', exchangeRate: '1.5');
    expect(p.effectiveExchangeRate, Decimal.parse('1.5'));
    expect(p.amount * p.effectiveExchangeRate, Decimal.fromInt(150));
  });
}
