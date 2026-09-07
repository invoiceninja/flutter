import 'package:collection/collection.dart';
import 'package:decimal/decimal.dart';
// `rational` is a transitive dependency of `decimal` — `Decimal / Decimal`
// returns `Rational`. Pulled in directly here for the `toDecimal(...)` call;
// the lint is harmless since the package is locked via decimal's pubspec.
// ignore: depend_on_referenced_packages
import 'package:rational/rational.dart';

import 'package:admin/data/models/domain/billing/line_item.dart';

/// Inputs to [computeTotals]. Captures everything a billing-doc total
/// depends on: line items, the invoice-level discount + 4 surcharges (with
/// their tax-applicability flags), the inclusive-vs-exclusive tax mode,
/// and the three invoice-level tax rates.
///
/// Carried as a plain value type rather than a method on `Invoice` so the
/// totals math stays unit-testable in isolation and Quote / Credit /
/// PurchaseOrder / RecurringInvoice can plug into it without inheritance.
class BillingTotalsInput {
  BillingTotalsInput({
    required this.lineItems,
    required this.discount,
    required this.isAmountDiscount,
    required this.usesInclusiveTaxes,
    this.taxName1 = '',
    Decimal? taxRate1,
    this.taxName2 = '',
    Decimal? taxRate2,
    this.taxName3 = '',
    Decimal? taxRate3,
    Decimal? customSurcharge1,
    Decimal? customSurcharge2,
    Decimal? customSurcharge3,
    Decimal? customSurcharge4,
    this.customTaxes1 = false,
    this.customTaxes2 = false,
    this.customTaxes3 = false,
    this.customTaxes4 = false,
  }) : taxRate1 = taxRate1 ?? Decimal.zero,
       taxRate2 = taxRate2 ?? Decimal.zero,
       taxRate3 = taxRate3 ?? Decimal.zero,
       customSurcharge1 = customSurcharge1 ?? Decimal.zero,
       customSurcharge2 = customSurcharge2 ?? Decimal.zero,
       customSurcharge3 = customSurcharge3 ?? Decimal.zero,
       customSurcharge4 = customSurcharge4 ?? Decimal.zero;

  final List<LineItem> lineItems;
  final Decimal discount;
  final bool isAmountDiscount;
  final bool usesInclusiveTaxes;
  final String taxName1;
  final Decimal taxRate1;
  final String taxName2;
  final Decimal taxRate2;
  final String taxName3;
  final Decimal taxRate3;
  final Decimal customSurcharge1;
  final Decimal customSurcharge2;
  final Decimal customSurcharge3;
  final Decimal customSurcharge4;
  final bool customTaxes1;
  final bool customTaxes2;
  final bool customTaxes3;
  final bool customTaxes4;

  /// Value equality so `computeTotals` can be memoized: an edit that
  /// doesn't touch a totals input (invoice number, notes, client, dates…)
  /// yields an equal input and the cached result is reused, instead of
  /// re-summing every line item's Decimal math on every keystroke.
  /// `lineItems` are freezed (value-equal), so `ListEquality` is exact.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BillingTotalsInput &&
        const ListEquality<LineItem>().equals(lineItems, other.lineItems) &&
        discount == other.discount &&
        isAmountDiscount == other.isAmountDiscount &&
        usesInclusiveTaxes == other.usesInclusiveTaxes &&
        taxName1 == other.taxName1 &&
        taxRate1 == other.taxRate1 &&
        taxName2 == other.taxName2 &&
        taxRate2 == other.taxRate2 &&
        taxName3 == other.taxName3 &&
        taxRate3 == other.taxRate3 &&
        customSurcharge1 == other.customSurcharge1 &&
        customSurcharge2 == other.customSurcharge2 &&
        customSurcharge3 == other.customSurcharge3 &&
        customSurcharge4 == other.customSurcharge4 &&
        customTaxes1 == other.customTaxes1 &&
        customTaxes2 == other.customTaxes2 &&
        customTaxes3 == other.customTaxes3 &&
        customTaxes4 == other.customTaxes4;
  }

  @override
  int get hashCode => Object.hash(
    const ListEquality<LineItem>().hash(lineItems),
    discount,
    isAmountDiscount,
    usesInclusiveTaxes,
    taxName1,
    taxRate1,
    taxName2,
    taxRate2,
    taxName3,
    taxRate3,
    customSurcharge1,
    customSurcharge2,
    customSurcharge3,
    customSurcharge4,
    Object.hash(customTaxes1, customTaxes2, customTaxes3, customTaxes4),
  );
}

/// Result of [computeTotals]. `taxBreakdown` keys by tax name (collapses
/// shared names across line items, matching the legacy behavior).
class BillingTotalsResult {
  const BillingTotalsResult({
    required this.subtotal,
    required this.total,
    required this.taxAmount,
    required this.taxBreakdown,
  });

  final Decimal subtotal;
  final Decimal total;
  final Decimal taxAmount;
  final Map<String, Decimal> taxBreakdown;
}

/// Compute totals for a billing doc. Ported faithfully from admin-portal's
/// `CalculateInvoiceTotal` mixin (`lib/data/models/mixins/invoice_mixin.dart`).
///
/// Precision comes from the client/company currency (typically 2). Tax
/// rates round to 3 decimals before applying. Quantity / cost / item
/// discount round to 5.
BillingTotalsResult computeTotals(BillingTotalsInput input, int precision) {
  final subtotal = computeSubtotal(input, precision);
  // ONE tax computation feeds both the card's rows and the total. Deriving
  // them from separate walks is how `taxAmount` and `total` came to contradict
  // each other on any currency whose precision isn't 2.
  final taxes = _computeTaxes(input, precision);

  var total = subtotal;
  if (input.discount != Decimal.zero) {
    // `Discounter::discount` returns an amount discount RAW and rounds a
    // percent one at 2.
    total = input.isAmountDiscount
        ? total - input.discount
        : total - _round2(_mulRate(total, input.discount));
  }
  // Inclusive tax already sits inside the gross line totals, so only exclusive
  // tax is added on top.
  if (!input.usesInclusiveTaxes) total = total + taxes.total;
  // Surcharges are summed RAW (`CustomValuer::valuer` returns them unchanged)
  // and land after tax, whatever the per-slot taxable flag.
  total =
      total +
      input.customSurcharge1 +
      input.customSurcharge2 +
      input.customSurcharge3 +
      input.customSurcharge4;

  return BillingTotalsResult(
    subtotal: subtotal,
    // NOT rounded at `precision`: the server's `calculateTotals` only adds tax,
    // and `getTotal()` returns that. The currency round happens later, when the
    // amount is persisted. Rounding here turned 121.5 into 122.
    total: total,
    taxAmount: taxes.total,
    taxBreakdown: taxes.breakdown,
  );
}

/// Pre-discount, pre-tax sum of all line items (each item's own discount is
/// applied first). Mirrors `CalculateInvoiceTotal.calculateSubtotal`.
Decimal computeSubtotal(BillingTotalsInput input, int precision) {
  var total = Decimal.zero;
  for (final item in input.lineItems) {
    // `push()` accumulates `round(line_total, currency->precision)` — the
    // SUBTOTAL rounds at the currency precision even though the line total
    // itself (and therefore the tax base) is a round-at-2 value.
    total = total + _round(_serverLineTotal(item, input, precision), precision);
  }
  return total;
}

/// Per-name tax breakdown — sums per-item tax amounts plus invoice-level
/// taxes against the post-discount/post-surcharge running total. Mirrors
/// `CalculateInvoiceTotal.calculateTaxes`.
Map<String, Decimal> computeTaxBreakdown(
  BillingTotalsInput input,
  int precision,
) => _computeTaxes(input, precision).breakdown;

/// The server keeps line taxes and invoice-level taxes in two separate maps and
/// rounds them at different scales: `setTaxMap` groups the LINE taxes by name
/// and rounds each group at the currency precision (`InvoiceSum:409`), while
/// each invoice-level tier goes straight into `total_taxes` from `Taxer::taxer`
/// at 2 dp and into its own `total_tax_map`.
///
/// Folding both into one name-keyed map and rounding the sum was wrong whenever
/// a line tax and an invoice-level tax share a name — "VAT" on both is the
/// normal case.
///
/// Returns the display breakdown (the two merged, for the totals card) and the
/// tax total. Both `taxAmount` and `total` are derived from THIS, so they
/// cannot contradict each other.
({Map<String, Decimal> breakdown, Decimal total}) _computeTaxes(
  BillingTotalsInput input,
  int precision,
) {
  final subtotal = computeSubtotal(input, precision);

  // --- line taxes: grouped by name, each group rounded at `precision` ---
  final lineGroups = <String, Decimal>{};
  for (final item in input.lineItems) {
    final rate1 = _round(item.taxRate1, 3);
    final rate2 = _round(item.taxRate2, 3);
    final rate3 = _round(item.taxRate3, 3);
    final itemRateSum = rate1 + rate2 + rate3;
    final base = getItemTaxable(item, subtotal, input, precision);
    // Exclusive per-line tax rounds at 2 (`calcAmountLineTax`); the inclusive
    // back-out uses the currency precision (`InvoiceItemSumInclusive:262`).
    final scale = input.usesInclusiveTaxes ? precision : 2;

    // The server gates each line tier on `strlen(tax_name) > 1`
    // (`InvoiceItemSum:326/334/342`) and drops it from `total_taxes` entirely
    // otherwise — `getTotalTaxes()` on the item sum is never read. For an
    // AMOUNT discount `setTaxMap` re-runs `calcTaxesWithAmountDiscount`, which
    // resets the groups first and uses the looser `strlen > 1 || total != 0`.
    bool applies(String name) => input.isAmountDiscount || name.length >= 2;

    void addTier(String name, Decimal rate) {
      if (rate == Decimal.zero || !applies(name)) return;
      final t = _taxAmount(
        base,
        rate,
        input.usesInclusiveTaxes,
        scale,
        totalRate: itemRateSum,
      );
      lineGroups.update(name, (v) => v + t, ifAbsent: () => t);
    }

    addTier(item.taxName1, rate1);
    addTier(item.taxName2, rate2);
    addTier(item.taxName3, rate3);
  }
  final rounded = {
    for (final e in lineGroups.entries) e.key: _round(e.value, precision),
  };

  // --- invoice-level tiers: against the post-discount total, rounded at 2 ---
  var taxable = subtotal;
  if (input.discount != Decimal.zero) {
    taxable = input.isAmountDiscount
        ? taxable - input.discount
        : taxable - _round2(_mulRate(taxable, input.discount));
  }
  if (input.usesInclusiveTaxes) {
    // `InvoiceSumInclusive::calculateInvoiceTaxes` folds each TAXABLE surcharge
    // into the inclusive base — guarded on `> 0`, so a negative surcharge is
    // excluded (they are first-class here: the field takes a signed keyboard).
    // Exclusive mode keeps them out of the base and adds a separately-rounded
    // component per slot instead (see [_surchargeTax]).
    if (input.customTaxes1 && input.customSurcharge1 > Decimal.zero) {
      taxable = taxable + input.customSurcharge1;
    }
    if (input.customTaxes2 && input.customSurcharge2 > Decimal.zero) {
      taxable = taxable + input.customSurcharge2;
    }
    if (input.customTaxes3 && input.customSurcharge3 > Decimal.zero) {
      taxable = taxable + input.customSurcharge3;
    }
    if (input.customTaxes4 && input.customSurcharge4 > Decimal.zero) {
      taxable = taxable + input.customSurcharge4;
    }
  }

  // Sigma-r is built from all three rates BEFORE the name gate — the server
  // passes the raw rates into `InclusiveTax::backout` and applies the gate only
  // when deciding which component reaches `total_taxes` (issue #12072).
  final invoiceRateSum = input.taxRate1 + input.taxRate2 + input.taxRate3;
  final invoiceTiers = <String, Decimal>{};
  void addInvoiceTier(String name, Decimal rate) {
    if (rate == Decimal.zero || name.length < 2) return;
    final t =
        _taxAmount(
          taxable,
          rate,
          input.usesInclusiveTaxes,
          2,
          totalRate: invoiceRateSum,
        ) +
        _surchargeTax(input, rate);
    invoiceTiers.update(name, (v) => v + t, ifAbsent: () => t);
  }

  addInvoiceTier(input.taxName1, input.taxRate1);
  addInvoiceTier(input.taxName2, input.taxRate2);
  addInvoiceTier(input.taxName3, input.taxRate3);

  final total =
      rounded.values.fold<Decimal>(Decimal.zero, _add) +
      invoiceTiers.values.fold<Decimal>(Decimal.zero, _add);

  // Display only: merge the two tiers by name for the totals card.
  final breakdown = <String, Decimal>{...rounded};
  for (final e in invoiceTiers.entries) {
    breakdown.update(e.key, (v) => v + e.value, ifAbsent: () => e.value);
  }
  return (breakdown: breakdown, total: total);
}

/// Taxable amount of a single line item against the invoice's running
/// total (used by the per-name breakdown calculator). Mirrors
/// `CalculateInvoiceTotal.getItemTaxable`.
Decimal getItemTaxable(
  LineItem item,
  Decimal invoiceTotal,
  BillingTotalsInput input,
  int precision,
) {
  // `InvoiceItemSum::calcTaxes` taxes
  // `line_total - line_total * (invoice.discount / 100)` — the line total is
  // already rounded (see [_serverLineTotal]) and the invoice-level deduction is
  // NOT rounded before `calcAmountLineTax` does its round-at-2. Rounding here
  // instead made this disagree with the total path by a cent.
  var lineTotal = _serverLineTotal(item, input, precision);

  if (input.discount == Decimal.zero) return lineTotal;

  if (input.isAmountDiscount) {
    // `calcTaxesWithAmountDiscount`: prorate the amount discount across the
    // post-item-discount line totals. Wide working scale for the ratio — the
    // currency precision would truncate it.
    if (invoiceTotal != Decimal.zero) {
      lineTotal =
          lineTotal -
          _safeDiv(lineTotal, invoiceTotal, precision: 10) * input.discount;
    }
    return lineTotal;
  }
  return lineTotal - _mulRate(lineTotal, input.discount);
}

/// Invoice-level taxable, after item discounts + invoice discount +
/// taxable surcharges. Mirrors `CalculateInvoiceTotal.getTaxable`. Kept
/// public for callers that want the pre-tax base independent of the
/// Invoice-level tax contributed by the taxable custom surcharges at [rate].
///
/// Mirrors `InvoiceSum::getSurchargeTaxTotalForKey`: each flagged slot's
/// component is rounded INDEPENDENTLY and summed, rather than taxing the
/// combined surcharge amount in one go. Inclusive mode contributes nothing —
/// `InvoiceSumInclusive` has these lines commented out.
Decimal _surchargeTax(BillingTotalsInput input, Decimal rate) {
  if (input.usesInclusiveTaxes || rate == Decimal.zero) return Decimal.zero;
  var out = Decimal.zero;
  if (input.customTaxes1) {
    out = out + _round2(_mulRate(input.customSurcharge1, rate));
  }
  if (input.customTaxes2) {
    out = out + _round2(_mulRate(input.customSurcharge2, rate));
  }
  if (input.customTaxes3) {
    out = out + _round2(_mulRate(input.customSurcharge3, rate));
  }
  if (input.customTaxes4) {
    out = out + _round2(_mulRate(input.customSurcharge4, rate));
  }
  return out;
}

Decimal _taxAmount(
  Decimal amount,
  Decimal rate,
  bool inclusive,
  int precision, {
  Decimal? totalRate,
}) {
  if (inclusive) {
    // `totalRate` (Σr) is the sum of all inclusive rates sharing this base;
    // defaults to this tier's own rate for the single-rate case.
    final sumRate = totalRate ?? rate;
    // A combined inclusive rate ≤ 0 yields no tax — parity with the backend
    // `InclusiveTax::backout` `combined_rate <= 0` guard.
    if (sumRate <= Decimal.zero) return _round(Decimal.zero, precision);
    if (sumRate == rate) {
      // Single applicable rate: `amount - amount / (1 + rate/100)`.
      //
      // The net MUST be taken at working scale 10, not at `precision`.
      // `_div` goes through `Rational.toDecimal(scaleOnInfinitePrecision:)`,
      // which TRUNCATES (`decimal`'s default `toBigInt` is `Rational.truncate`),
      // so dividing at currency precision truncated the net and turned the tax
      // into a ceiling: 100.00 @ 10% gave 100 − 90.90 = 9.10 where the server's
      // `InclusiveTax::backout` (`round(amount × rate / (100 + Σr))`) gives
      // 9.09. Every non-divisible gross was a cent out, and it was persisted
      // via `stampTotalsForSave`. Scale 10 matches the multi-rate branch below
      // and `expense_tax_math.dart`, which had it right all along.
      final divisor = Decimal.one + _div(rate, Decimal.fromInt(100), 10);
      final taxAmount = amount - _safeDiv(amount, divisor, precision: 10);
      return _round(taxAmount, precision);
    }
    // Two or more inclusive rates (issue #12072): additive shared base — this
    // tier's share of the shared net `amount/(1 + Σr/100)`, kept at working
    // scale 10 so the net isn't pre-rounded before the per-rate split.
    final divisor = Decimal.one + _div(sumRate, Decimal.fromInt(100), 10);
    final net = _safeDiv(amount, divisor, precision: 10);
    return _round(_mulRate(net, rate), precision);
  }
  return _round(_mulRate(amount, rate), precision);
}

Decimal _mulRate(Decimal amount, Decimal rate) =>
    _div(amount * rate, Decimal.fromInt(100), 10);

Decimal _safeDiv(Decimal a, Decimal b, {int precision = 10}) {
  if (b == Decimal.zero) return Decimal.zero;
  return _div(a, b, precision);
}

Decimal _div(Decimal a, Decimal b, int scale) {
  final Rational r = (a / b);
  return r.toDecimal(scaleOnInfinitePrecision: scale);
}

Decimal _round(Decimal v, int precision) => v.round(scale: precision);

/// Round at a fixed 2 decimals, regardless of the currency's precision.
///
/// The server rounds most INTERMEDIATES at a hard 2 and reserves the currency
/// precision for the per-tax-name group total (`InvoiceSum:409`) and the final
/// amount. Threading `precision` through the intermediates instead is invisible
/// on a 2-decimal currency and wrong on every other one.
///
/// Verified scale map (`tool/totals_oracle.php` runs the real classes):
///
/// | site                                          | scale     |
/// |-----------------------------------------------|-----------|
/// | line total (`sumLineItem`/`setDiscount`)      | 2         |
/// | per-line tax, exclusive (`calcAmountLineTax`) | 2         |
/// | per-line tax, inclusive (`InvoiceItemSumInclusive:262`) | precision |
/// | invoice-level tax, either flavour             | 2         |
/// | invoice percent discount (`Discounter`)       | 2         |
/// | surcharge tax component                       | 2         |
/// | per-tax-name GROUP total (`InvoiceSum:409`)   | precision |
Decimal _round2(Decimal v) => v.round(scale: 2);

/// One line's `line_total` exactly as the server builds it: `sumLineItem`
/// rounds `qty x cost` at 2, then `setDiscount` formats the post-discount value
/// at the currency precision and `setLineTotal` rounds *that* at 2 again.
///
/// This is the value both the subtotal and the tax base start from. Deriving
/// them separately is how the totals card came to disagree with itself.
Decimal _serverLineTotal(
  LineItem item,
  BillingTotalsInput input,
  int precision,
) {
  final qty = _round(item.quantity, 5);
  final cost = _round(item.cost, 5);
  final itemDiscount = _round(item.discount, 5);
  var lineTotal = _round2(qty * cost);
  if (itemDiscount != Decimal.zero) {
    // `setDiscount`: an amount discount is formatted at the currency precision
    // and subtracted; a percent one is applied unrounded and the RESULT is
    // formatted. Both then pass through `setLineTotal`'s round-at-2.
    final reduced = input.isAmountDiscount
        ? lineTotal - _round(itemDiscount, precision)
        : lineTotal - _mulRate(lineTotal, itemDiscount);
    lineTotal = _round2(_round(reduced, precision));
  }
  return lineTotal;
}

Decimal _add(Decimal a, Decimal b) => a + b;
