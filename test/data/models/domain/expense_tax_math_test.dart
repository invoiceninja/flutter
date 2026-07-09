import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/expense_api_model.dart';
import 'package:admin/data/models/api/recurring_expense_api_model.dart';
import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/domain/expense_tax_math.dart';

Decimal _d(String s) => Decimal.parse(s);

Expense _expense({
  String amount = '0',
  String taxName1 = '',
  String taxRate1 = '0',
  String taxAmount1 = '0',
  String taxName2 = '',
  String taxRate2 = '0',
  String taxAmount2 = '0',
  String exchangeRate = '1',
  bool usesInclusiveTaxes = false,
  bool calculateTaxByAmount = false,
}) => Expense.fromApi(
  ExpenseApi(
    id: '1',
    amount: amount,
    taxName1: taxName1,
    taxRate1: taxRate1,
    taxAmount1: taxAmount1,
    taxName2: taxName2,
    taxRate2: taxRate2,
    taxAmount2: taxAmount2,
    exchangeRate: exchangeRate,
    usesInclusiveTaxes: usesInclusiveTaxes,
    calculateTaxByAmount: calculateTaxByAmount,
  ),
);

void main() {
  group('expenseTierTaxAmount', () {
    test('exclusive: amount * rate / 100', () {
      expect(
        expenseTierTaxAmount(
          amount: _d('100'),
          rate: _d('10'),
          usesInclusiveTaxes: false,
        ),
        _d('10'),
      );
    });

    test('exclusive: fractional rate rounds to 2', () {
      expect(
        expenseTierTaxAmount(
          amount: _d('100'),
          rate: _d('8.25'),
          usesInclusiveTaxes: false,
        ),
        _d('8.25'),
      );
    });

    test(
      'inclusive: amount - amount / (1 + rate/100) → 9.09 for 100 @ 10%',
      () {
        expect(
          expenseTierTaxAmount(
            amount: _d('100'),
            rate: _d('10'),
            usesInclusiveTaxes: true,
          ),
          _d('9.09'),
        );
      },
    );

    test('zero rate → zero', () {
      expect(
        expenseTierTaxAmount(
          amount: _d('100'),
          rate: Decimal.zero,
          usesInclusiveTaxes: false,
        ),
        Decimal.zero,
      );
    });

    test(
      'inclusive multi-rate: shares the divisor — 1000 @ 10% with Σr 20 → 83.33',
      () {
        expect(
          expenseTierTaxAmount(
            amount: _d('1000'),
            rate: _d('10'),
            totalRate: _d('20'),
            usesInclusiveTaxes: true,
          ),
          _d('83.33'),
        );
      },
    );

    test('inclusive single-rate guard: Σr == rate is byte-identical', () {
      // Passing totalRate == rate must take the legacy path (issue #12072).
      expect(
        expenseTierTaxAmount(
          amount: _d('100'),
          rate: _d('10'),
          totalRate: _d('10'),
          usesInclusiveTaxes: true,
        ),
        _d('9.09'),
      );
    });

    test('inclusive combined rate <= 0 → 0 (parity with backout guard)', () {
      // Backend InclusiveTax::backout returns 0 when combined_rate <= 0.
      expect(
        expenseTierTaxAmount(
          amount: _d('1000'),
          rate: _d('10'),
          totalRate: Decimal.zero,
          usesInclusiveTaxes: true,
        ),
        Decimal.zero,
      );
      expect(
        expenseTierTaxAmount(
          amount: _d('1000'),
          rate: _d('10'),
          totalRate: _d('-5'),
          usesInclusiveTaxes: true,
        ),
        Decimal.zero,
      );
    });
  });

  group('Expense tax getters (by rate)', () {
    test('exclusive single tier: gross = amount + tax', () {
      final e = _expense(amount: '100', taxName1: 'GST', taxRate1: '10');
      expect(e.taxAmount1Computed, _d('10'));
      expect(e.taxAmountSum, _d('10'));
      expect(e.netAmount, _d('100'));
      expect(e.grossAmount, _d('110'));
    });

    test('inclusive single tier: net = amount - tax, gross = amount', () {
      final e = _expense(
        amount: '100',
        taxName1: 'GST',
        taxRate1: '10',
        usesInclusiveTaxes: true,
      );
      expect(e.taxAmountSum, _d('9.09'));
      expect(e.netAmount, _d('90.91'));
      expect(e.grossAmount, _d('100'));
    });

    test('inclusive two tiers share the base → net 833.34, 83.33 each', () {
      // issue #12072: additive shared base, not independent extraction (818.18).
      // Net = gross − Σtax (matches backend InclusiveTax::backout): the net
      // absorbs the 1¢ residual so 833.34 + 166.66 = 1000.00 reconciles.
      final e = _expense(
        amount: '1000',
        taxName1: 'A',
        taxRate1: '10',
        taxName2: 'B',
        taxRate2: '10',
        usesInclusiveTaxes: true,
      );
      expect(e.taxAmount1Computed, _d('83.33'));
      expect(e.taxAmount2Computed, _d('83.33'));
      expect(e.taxAmountSum, _d('166.66'));
      expect(e.netAmount, _d('833.34'));
      expect(e.grossAmount, _d('1000'));
    });

    test('multi-tier exclusive sums each tier against the base amount', () {
      final e = _expense(
        amount: '100',
        taxName1: 'GST',
        taxRate1: '10',
        taxName2: 'PST',
        taxRate2: '5',
      );
      expect(e.taxAmountSum, _d('15'));
      expect(e.grossAmount, _d('115'));
    });

    test('convertedAmount = gross * exchange rate', () {
      final e = _expense(amount: '100', taxRate1: '10', exchangeRate: '2');
      expect(e.convertedAmount, _d('220'));
    });
  });

  group('Expense tax getters (by amount)', () {
    test('uses stored tax_amount, ignores the rate', () {
      final e = _expense(
        amount: '100',
        taxName1: 'GST',
        taxRate1: '0',
        taxAmount1: '7',
        calculateTaxByAmount: true,
      );
      expect(e.taxAmount1Computed, _d('7'));
      expect(e.taxAmountSum, _d('7'));
      expect(e.grossAmount, _d('107'));
    });

    test('inclusive multi-tier by-amount: stored amounts + gross-sum net', () {
      // By-amount mode has no rate to divide by, so the additive shared-base
      // fix must NOT touch it — stored amounts and `amount - sum` net stand.
      final e = _expense(
        amount: '1000',
        taxRate1: '0',
        taxAmount1: '90.91',
        taxRate2: '0',
        taxAmount2: '90.91',
        usesInclusiveTaxes: true,
        calculateTaxByAmount: true,
      );
      expect(e.taxAmountSum, _d('181.82'));
      expect(e.netAmount, _d('818.18'));
    });
  });

  group('RecurringExpense tax getters', () {
    test('exclusive single tier mirrors Expense', () {
      final r = RecurringExpense.fromApi(
        RecurringExpenseApi(
          id: '1',
          amount: '100',
          taxName1: 'GST',
          taxRate1: '10',
        ),
      );
      expect(r.taxAmount1Computed, _d('10'));
      expect(r.taxAmountSum, _d('10'));
      expect(r.grossAmount, _d('110'));
    });
  });
}
