import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/domain/billing/totals_calculator.dart';

/// Tests the totals math ported from admin-portal's `CalculateInvoiceTotal`
/// mixin. Each scenario exercises one knob of the math so regressions
/// surface cleanly:
///
///   * Subtotal (qty × cost − item discount), per-item rounded to precision
///   * Per-item taxes vs invoice-level taxes
///   * Inclusive vs exclusive tax modes (`uses_inclusive_taxes`)
///   * Invoice-level discount in two flavors: percent vs amount
///   * Custom surcharges 1..4 with the `customTaxesN` "taxable" flag
///   * Tax-name collision (two items with same `tax_name1` accumulate)
///   * Empty `taxName` with non-zero rate is omitted from the breakdown
///   * Tax rates round to 3 decimals before applying
///
/// All assertions use `Decimal` (never `double`) — the math is precision-
/// sensitive and a `.toDouble()` round-trip in the test would mask real
/// rounding bugs.
void main() {
  Decimal d(String s) => Decimal.parse(s);

  LineItem item({
    String productKey = '',
    String cost = '0',
    String quantity = '1',
    String discount = '0',
    String taxName1 = '',
    String taxRate1 = '0',
    String taxName2 = '',
    String taxRate2 = '0',
    String taxName3 = '',
    String taxRate3 = '0',
  }) => LineItem(
    productKey: productKey,
    notes: '',
    cost: d(cost),
    productCost: Decimal.zero,
    quantity: d(quantity),
    taxName1: taxName1,
    taxName2: taxName2,
    taxName3: taxName3,
    taxRate1: d(taxRate1),
    taxRate2: d(taxRate2),
    taxRate3: d(taxRate3),
    typeId: LineItemType.standard,
    customValue1: '',
    customValue2: '',
    customValue3: '',
    customValue4: '',
    discount: d(discount),
    taxCategoryId: '',
  );

  BillingTotalsInput input({
    required List<LineItem> lineItems,
    String discount = '0',
    bool isAmountDiscount = false,
    bool usesInclusiveTaxes = false,
    String taxName1 = '',
    String taxRate1 = '0',
    String taxName2 = '',
    String taxRate2 = '0',
    String taxName3 = '',
    String taxRate3 = '0',
    String customSurcharge1 = '0',
    String customSurcharge2 = '0',
    String customSurcharge3 = '0',
    String customSurcharge4 = '0',
    bool customTaxes1 = false,
    bool customTaxes2 = false,
    bool customTaxes3 = false,
    bool customTaxes4 = false,
  }) => BillingTotalsInput(
    lineItems: lineItems,
    discount: d(discount),
    isAmountDiscount: isAmountDiscount,
    usesInclusiveTaxes: usesInclusiveTaxes,
    taxName1: taxName1,
    taxRate1: d(taxRate1),
    taxName2: taxName2,
    taxRate2: d(taxRate2),
    taxName3: taxName3,
    taxRate3: d(taxRate3),
    customSurcharge1: d(customSurcharge1),
    customSurcharge2: d(customSurcharge2),
    customSurcharge3: d(customSurcharge3),
    customSurcharge4: d(customSurcharge4),
    customTaxes1: customTaxes1,
    customTaxes2: customTaxes2,
    customTaxes3: customTaxes3,
    customTaxes4: customTaxes4,
  );

  group('subtotal', () {
    test('empty line items → zero', () {
      final result = computeTotals(input(lineItems: const []), 2);
      expect(result.subtotal, Decimal.zero);
      expect(result.total, Decimal.zero);
      expect(result.taxAmount, Decimal.zero);
      expect(result.taxBreakdown, isEmpty);
    });

    test('single line: qty × cost, no taxes, no discount', () {
      final result = computeTotals(
        input(
          lineItems: [item(cost: '50', quantity: '3')],
        ),
        2,
      );
      expect(result.subtotal, d('150'));
      expect(result.total, d('150'));
      expect(result.taxAmount, Decimal.zero);
    });

    test('multi-line subtotal sums correctly', () {
      final result = computeTotals(
        input(
          lineItems: [
            item(cost: '10', quantity: '2'),
            item(cost: '5.50', quantity: '4'),
          ],
        ),
        2,
      );
      // 20.00 + 22.00 = 42.00
      expect(result.subtotal, d('42.00'));
    });

    test('item-level amount discount subtracts before subtotal', () {
      final result = computeTotals(
        input(
          lineItems: [item(cost: '100', quantity: '1', discount: '15')],
          isAmountDiscount: true,
        ),
        2,
      );
      // 100 − 15 = 85
      expect(result.subtotal, d('85'));
    });

    test('item-level percent discount subtracts before subtotal', () {
      final result = computeTotals(
        input(
          lineItems: [item(cost: '100', quantity: '1', discount: '10')],
        ),
        2,
      );
      // 100 − 10% = 90
      expect(result.subtotal, d('90.00'));
    });
  });

  group('invoice-level tax (exclusive)', () {
    test('5% on a 100 subtotal adds 5 in tax', () {
      final result = computeTotals(
        input(
          lineItems: [item(cost: '100')],
          taxName1: 'GST',
          taxRate1: '5',
        ),
        2,
      );
      expect(result.subtotal, d('100'));
      expect(result.taxAmount, d('5.00'));
      expect(result.total, d('105.00'));
      expect(result.taxBreakdown['GST'], d('5.00'));
    });

    test('two invoice-level taxes stack into breakdown', () {
      final result = computeTotals(
        input(
          lineItems: [item(cost: '100')],
          taxName1: 'GST',
          taxRate1: '5',
          taxName2: 'PST',
          taxRate2: '7',
        ),
        2,
      );
      expect(result.taxBreakdown['GST'], d('5.00'));
      expect(result.taxBreakdown['PST'], d('7.00'));
      expect(result.total, d('112.00'));
    });

    test('empty taxName with non-zero rate is omitted from breakdown and '
        'total (server requires tax_name length >= 2)', () {
      final result = computeTotals(
        input(
          lineItems: [item(cost: '100')],
          // taxName1 left empty
          taxRate1: '10',
        ),
        2,
      );
      // The server (InvoiceSum) applies an invoice-level tier only when
      // strlen(tax_nameN) >= 2 — a blank/1-char name means no tax, with no
      // rate-only escape hatch. The local calc must match, or the displayed
      // and offline-stamped total reads too high (by the dropped tax) until a
      // refresh corrects it (L6). The legacy `double` mixin merged it under the
      // '' key; we no longer do.
      expect(result.taxBreakdown.containsKey(''), isFalse);
      expect(result.total, d('100.00'));
    });
  });

  group('invoice-level tax (inclusive)', () {
    test('inclusive 10% on 110 yields 10 tax + 100 net', () {
      final result = computeTotals(
        input(
          lineItems: [item(cost: '110')],
          taxName1: 'VAT',
          taxRate1: '10',
          usesInclusiveTaxes: true,
        ),
        2,
      );
      // amount − amount/(1+rate/100) = 110 − 110/1.1 = 110 − 100 = 10
      // total stays at subtotal (inclusive doesn't add to total).
      expect(result.taxBreakdown['VAT'], d('10.00'));
      expect(result.total, d('110.00'));
    });

    test('inclusive two invoice-level rates share the base → 83.33 each', () {
      // issue #12072: additive shared base 1000/(1+0.20) = 833.33, each tier
      // 83.33 — NOT independent extraction (90.91 each / 181.82). Names are
      // 2+ chars so they pass the invoice-level tax_name gate.
      final result = computeTotals(
        input(
          lineItems: [item(cost: '1000')],
          taxName1: 'VAT',
          taxRate1: '10',
          taxName2: 'GST',
          taxRate2: '10',
          usesInclusiveTaxes: true,
        ),
        2,
      );
      expect(result.taxBreakdown['VAT'], d('83.33'));
      expect(result.taxBreakdown['GST'], d('83.33'));
      expect(result.taxAmount, d('166.66'));
      expect(result.total, d('1000.00'));
    });
  });

  group('per-item taxes', () {
    test('two items with same tax name accumulate into one breakdown row', () {
      final result = computeTotals(
        input(
          lineItems: [
            item(cost: '100', taxName1: 'VAT', taxRate1: '10'),
            item(cost: '50', taxName1: 'VAT', taxRate1: '10'),
          ],
        ),
        2,
      );
      // 100 × 10% + 50 × 10% = 15
      expect(result.taxBreakdown['VAT'], d('15.00'));
    });

    test('different tax names produce separate breakdown rows', () {
      final result = computeTotals(
        input(
          lineItems: [
            item(cost: '100', taxName1: 'GST', taxRate1: '5'),
            item(cost: '50', taxName1: 'PST', taxRate1: '7'),
          ],
        ),
        2,
      );
      expect(result.taxBreakdown['GST'], d('5.00'));
      expect(result.taxBreakdown['PST'], d('3.50'));
    });

    test('three taxes per item all apply against the same lineTotal', () {
      final result = computeTotals(
        input(
          lineItems: [
            item(
              cost: '100',
              taxName1: 'A',
              taxRate1: '5',
              taxName2: 'B',
              taxRate2: '7',
              taxName3: 'C',
              taxRate3: '3',
            ),
          ],
        ),
        2,
      );
      expect(result.taxBreakdown['A'], d('5.00'));
      expect(result.taxBreakdown['B'], d('7.00'));
      expect(result.taxBreakdown['C'], d('3.00'));
    });

    test(
      'inclusive two item rates share the base → 83.33 each, total 1000',
      () {
        // issue #12072: line-item multi-rate inclusive is additive shared-base.
        final result = computeTotals(
          input(
            lineItems: [
              item(
                cost: '1000',
                taxName1: 'A',
                taxRate1: '10',
                taxName2: 'B',
                taxRate2: '10',
              ),
            ],
            usesInclusiveTaxes: true,
          ),
          2,
        );
        expect(result.taxBreakdown['A'], d('83.33'));
        expect(result.taxBreakdown['B'], d('83.33'));
        expect(result.taxAmount, d('166.66'));
        expect(result.total, d('1000.00'));
      },
    );
  });

  group('tax rate precision', () {
    test('rates round to 3 decimals before applying', () {
      // 100 × 5.12345% — legacy mixin rounds rate to 5.123 first.
      final result = computeTotals(
        input(
          lineItems: [item(cost: '100', taxName1: 'X', taxRate1: '5.12345')],
        ),
        2,
      );
      // 100 × 5.123 / 100 = 5.123, rounded to precision 2 = 5.12
      expect(result.taxBreakdown['X'], d('5.12'));
    });
  });

  group('invoice-level discount', () {
    test('amount discount subtracts from total', () {
      final result = computeTotals(
        input(
          lineItems: [item(cost: '100')],
          discount: '15',
          isAmountDiscount: true,
        ),
        2,
      );
      expect(result.subtotal, d('100'));
      expect(result.total, d('85.00'));
    });

    test('percent discount subtracts proportional amount', () {
      final result = computeTotals(
        input(
          lineItems: [item(cost: '100')],
          discount: '10',
        ),
        2,
      );
      expect(result.total, d('90.00'));
    });

    test('amount discount distributes across line items consistently in '
        'breakdown and total', () {
      // Two items totalling 100. Invoice-level $20 amount discount.
      //
      // The breakdown and the total now use the SAME per-line distribution
      // denominator — the subtotal (100), matching the server's
      // calcTaxesWithAmountDiscount (L7). Previously the breakdown used
      // subtotal + discount = 120 → GST 8.33, diverging from the total's
      // embedded 8.00 by a few cents (the rows didn't sum to the displayed
      // total). Now both are 8.00:
      //   - Item 1: 60 − 60/100 × 20 = 48 → tax 4.80
      //   - Item 2: 40 − 40/100 × 20 = 32 → tax 3.20
      //   - Breakdown GST = 8.00; embedded tax = 8.00; total = 100 − 20 + 8 = 88
      final result = computeTotals(
        input(
          lineItems: [
            item(cost: '60', taxName1: 'GST', taxRate1: '10'),
            item(cost: '40', taxName1: 'GST', taxRate1: '10'),
          ],
          discount: '20',
          isAmountDiscount: true,
        ),
        2,
      );
      expect(result.taxBreakdown['GST'], d('8.00'));
      expect(result.total, d('88.00'));
    });
  });

  group('custom surcharges', () {
    test('taxable surcharge adds to taxable base before invoice tax', () {
      // 100 subtotal + $20 surcharge (taxable=true) → taxable 120
      // 10% tax = 12. Total = 120 + 12 = 132.
      final result = computeTotals(
        input(
          lineItems: [item(cost: '100')],
          customSurcharge1: '20',
          customTaxes1: true,
          taxName1: 'GST',
          taxRate1: '10',
        ),
        2,
      );
      expect(result.taxBreakdown['GST'], d('12.00'));
      expect(result.total, d('132.00'));
    });

    test('non-taxable surcharge added AFTER tax, not part of tax base', () {
      // 100 subtotal, $20 surcharge (taxable=false), 10% tax.
      // Tax base = 100 × 10% = 10. Total = 100 + 10 + 20 = 130.
      final result = computeTotals(
        input(
          lineItems: [item(cost: '100')],
          customSurcharge1: '20',
          customTaxes1: false,
          taxName1: 'GST',
          taxRate1: '10',
        ),
        2,
      );
      expect(result.taxBreakdown['GST'], d('10.00'));
      expect(result.total, d('130.00'));
    });

    test('all four surcharges sum independently', () {
      final result = computeTotals(
        input(
          lineItems: [item(cost: '100')],
          customSurcharge1: '10',
          customSurcharge2: '20',
          customSurcharge3: '30',
          customSurcharge4: '40',
          // all non-taxable
        ),
        2,
      );
      // 100 + 10 + 20 + 30 + 40 = 200
      expect(result.total, d('200.00'));
    });
  });
}
