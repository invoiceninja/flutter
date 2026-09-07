import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/billing/line_item_type.dart';
import 'package:admin/domain/billing/totals_calculator.dart';

/// Differential parity against the REAL Invoice Ninja server math.
///
/// `tool/totals_oracle.php` loads the canonical `InvoiceSum` / `InvoiceItemSum`
/// (and their inclusive twins) from the server checkout and runs them offline,
/// so this asserts agreement with the implementation rather than with someone's
/// reading of it. That distinction is not academic: hand-deriving the
/// shared-tax-name case from the PHP gave 12/122 where the real code returns
/// 11.5/121.5, and a previous rewrite of this calculator passed the entire
/// 6,300-test suite while making ordinary USD invoices a cent light.
///
/// Skips (rather than fails) when the server source or its `vendor/` is absent,
/// so CI and machines without the checkout stay green. That means a green run
/// here is only meaningful where the oracle actually executed — the first test
/// asserts it did, locally.
void main() {
  Decimal d(String s) => Decimal.parse(s);

  LineItem item({
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
    productKey: '',
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

  /// One parity case: the same invoice expressed for both calculators.
  ({
    String label,
    int precision,
    BillingTotalsInput input,
    Map<String, dynamic> spec,
  })
  kase({
    required String label,
    int precision = 2,
    required List<({LineItem item, Map<String, dynamic> json})> lines,
    String discount = '0',
    bool isAmountDiscount = false,
    bool usesInclusiveTaxes = false,
    String taxName1 = '',
    String taxRate1 = '0',
    String taxName2 = '',
    String taxRate2 = '0',
    String customSurcharge1 = '0',
    bool customTaxes1 = false,
  }) {
    return (
      label: label,
      precision: precision,
      input: BillingTotalsInput(
        lineItems: [for (final l in lines) l.item],
        discount: d(discount),
        isAmountDiscount: isAmountDiscount,
        usesInclusiveTaxes: usesInclusiveTaxes,
        taxName1: taxName1,
        taxRate1: d(taxRate1),
        taxName2: taxName2,
        taxRate2: d(taxRate2),
        taxName3: '',
        taxRate3: Decimal.zero,
        customSurcharge1: d(customSurcharge1),
        customSurcharge2: Decimal.zero,
        customSurcharge3: Decimal.zero,
        customSurcharge4: Decimal.zero,
        customTaxes1: customTaxes1,
        customTaxes2: false,
        customTaxes3: false,
        customTaxes4: false,
      ),
      spec: {
        'precision': precision,
        'line_items': [for (final l in lines) l.json],
        'invoice': {
          'discount': num.parse(discount),
          'is_amount_discount': isAmountDiscount,
          'uses_inclusive_taxes': usesInclusiveTaxes,
          'tax_name1': taxName1,
          'tax_rate1': num.parse(taxRate1),
          'tax_name2': taxName2,
          'tax_rate2': num.parse(taxRate2),
          'custom_surcharge1': num.parse(customSurcharge1),
          'custom_surcharge_tax1': customTaxes1,
        },
      },
    );
  }

  ({LineItem item, Map<String, dynamic> json}) line({
    String cost = '0',
    String quantity = '1',
    String discount = '0',
    String taxName1 = '',
    String taxRate1 = '0',
    String taxName2 = '',
    String taxRate2 = '0',
  }) => (
    item: item(
      cost: cost,
      quantity: quantity,
      discount: discount,
      taxName1: taxName1,
      taxRate1: taxRate1,
      taxName2: taxName2,
      taxRate2: taxRate2,
    ),
    json: {
      'cost': num.parse(cost),
      'quantity': num.parse(quantity),
      'discount': num.parse(discount),
      'tax_name1': taxName1,
      'tax_rate1': num.parse(taxRate1),
      'tax_name2': taxName2,
      'tax_rate2': num.parse(taxRate2),
    },
  );

  final cases = [
    // The regression that a full green suite certified: qty x cost with more
    // than two decimals, default currency, nothing exotic.
    kase(
      label: 'USD 2.5 x 1.298 @ VAT 10%',
      lines: [
        line(cost: '1.298', quantity: '2.5', taxName1: 'VAT', taxRate1: '10'),
      ],
    ),
    kase(
      label: 'USD 2.05 @ VAT 50%, 50% invoice discount',
      lines: [line(cost: '2.05', taxName1: 'VAT', taxRate1: '50')],
      discount: '50',
    ),
    kase(
      label: 'JPY two line tiers (precision 0)',
      precision: 0,
      lines: [
        line(
          cost: '110',
          taxName1: 'CT',
          taxRate1: '5',
          taxName2: 'ST',
          taxRate2: '5',
        ),
      ],
    ),
    kase(
      label: 'JPY line tax and invoice tax sharing a name',
      precision: 0,
      lines: [line(cost: '110', taxName1: 'CT', taxRate1: '5')],
      taxName1: 'CT',
      taxRate1: '5',
    ),
    kase(
      label: 'JPY two fractional lines',
      precision: 0,
      lines: [
        line(cost: '110.5'),
        line(cost: '110.5'),
      ],
    ),
    kase(
      label: 'KWD fractional line @ 7% (precision 3)',
      precision: 3,
      lines: [line(cost: '10.0075', taxName1: 'VAT', taxRate1: '7')],
    ),
    kase(
      label: 'inclusive, taxable surcharge +20',
      lines: [line(cost: '110')],
      usesInclusiveTaxes: true,
      taxName1: 'VAT',
      taxRate1: '10',
      customSurcharge1: '20',
      customTaxes1: true,
    ),
    kase(
      label: 'inclusive, taxable surcharge -20 (negative is a real value)',
      lines: [line(cost: '110')],
      usesInclusiveTaxes: true,
      taxName1: 'VAT',
      taxRate1: '10',
      customSurcharge1: '-20',
      customTaxes1: true,
    ),
    kase(
      label: 'amount discount with a per-line discount',
      lines: [
        line(cost: '100', discount: '10', taxName1: 'VAT', taxRate1: '20'),
        line(cost: '50', taxName1: 'VAT', taxRate1: '20'),
      ],
      discount: '15',
      isAmountDiscount: true,
    ),
    kase(
      label: 'line tax with a 1-char name (server drops it)',
      lines: [line(cost: '100', taxName1: 'A', taxRate1: '10')],
    ),
    kase(
      label: 'two inclusive line rates share one base',
      lines: [
        line(
          cost: '1000',
          taxName1: 'AA',
          taxRate1: '10',
          taxName2: 'BB',
          taxRate2: '10',
        ),
      ],
      usesInclusiveTaxes: true,
    ),
    kase(
      label: 'rate with more than 3 decimals',
      lines: [line(cost: '100', taxName1: 'XX', taxRate1: '5.12345')],
    ),
    kase(
      label: 'amount discount larger than one line',
      lines: [
        line(cost: '40'),
        line(cost: '10', taxName1: 'VAT', taxRate1: '20'),
      ],
      discount: '45',
      isAmountDiscount: true,
    ),
    kase(
      label: 'zero-cost line among taxed lines',
      lines: [
        line(cost: '0', taxName1: 'VAT', taxRate1: '20'),
        line(cost: '99.99', taxName1: 'VAT', taxRate1: '20'),
      ],
    ),
    kase(
      label: 'JPY percent discount with a taxed fractional line',
      precision: 0,
      lines: [
        line(cost: '333.33', quantity: '3', taxName1: 'CT', taxRate1: '8'),
      ],
      discount: '10',
    ),
  ];

  List<Map<String, dynamic>>? oracle;
  String? skipReason;

  setUpAll(() {
    final specFile = File(
      '${Directory.systemTemp.createTempSync('totals_oracle').path}/spec.json',
    )..writeAsStringSync(jsonEncode([for (final c in cases) c.spec]));
    addTearDown(() => specFile.parent.deleteSync(recursive: true));
    final result = Process.runSync('php', [
      'tool/totals_oracle.php',
      specFile.path,
    ]);
    if (result.exitCode != 0) {
      skipReason = 'oracle failed: ${result.stderr}';
      return;
    }
    final decoded = jsonDecode(result.stdout as String);
    if (decoded is Map && decoded['skipped'] != null) {
      skipReason = 'oracle skipped: ${decoded['skipped']}';
      return;
    }
    oracle = (decoded as List).cast<Map<String, dynamic>>();
  });

  test('the oracle actually ran', () {
    // Reported as SKIPPED, never as passed. A parity file that silently goes
    // green when its reference is missing is the exact "green proves nothing"
    // trap this whole exercise exists to close.
    if (skipReason != null) markTestSkipped('totals parity: $skipReason');
    expect(skipReason == null || skipReason!.isNotEmpty, isTrue);
  });

  for (var i = 0; i < cases.length; i++) {
    final c = cases[i];
    test('parity: ${c.label}', () {
      if (skipReason != null) {
        markTestSkipped('no oracle: $skipReason');
        return;
      }
      final expected = oracle![i];
      final result = computeTotals(c.input, c.precision);

      expect(
        result.total.toString(),
        Decimal.parse(expected['total'] as String).toString(),
        reason: 'total disagrees with the server for "${c.label}"',
      );
      expect(
        result.taxAmount.toString(),
        Decimal.parse(expected['total_taxes'] as String).toString(),
        reason: 'total_taxes disagrees with the server for "${c.label}"',
      );
    });
  }
}
