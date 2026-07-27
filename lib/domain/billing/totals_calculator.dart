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
  final total = _calculateTotal(input, precision);
  final breakdown = computeTaxBreakdown(input, precision);
  final taxAmount = breakdown.values.fold<Decimal>(Decimal.zero, _add);
  return BillingTotalsResult(
    subtotal: subtotal,
    total: total,
    taxAmount: _round(taxAmount, precision),
    taxBreakdown: breakdown,
  );
}

/// Pre-discount, pre-tax sum of all line items (each item's own discount is
/// applied first). Mirrors `CalculateInvoiceTotal.calculateSubtotal`.
Decimal computeSubtotal(BillingTotalsInput input, int precision) {
  var total = Decimal.zero;
  for (final item in input.lineItems) {
    final qty = _round(item.quantity, 5);
    final cost = _round(item.cost, 5);
    final itemDiscount = _round(item.discount, 5);
    var lineTotal = qty * cost;
    if (itemDiscount != Decimal.zero) {
      if (input.isAmountDiscount) {
        lineTotal = lineTotal - itemDiscount;
      } else {
        lineTotal =
            lineTotal - _round(_mulRate(lineTotal, itemDiscount), precision);
      }
    }
    total = total + _round(lineTotal, precision);
  }
  return total;
}

/// Per-name tax breakdown — sums per-item tax amounts plus invoice-level
/// taxes against the post-discount/post-surcharge running total. Mirrors
/// `CalculateInvoiceTotal.calculateTaxes`.
Map<String, Decimal> computeTaxBreakdown(
  BillingTotalsInput input,
  int precision,
) {
  var total = computeSubtotal(input, precision);
  final map = <String, Decimal>{};

  for (final item in input.lineItems) {
    final rate1 = _round(item.taxRate1, 3);
    final rate2 = _round(item.taxRate2, 3);
    final rate3 = _round(item.taxRate3, 3);
    // Σr for this line: the item's own inclusive rates share one divisor
    // (issue #12072). Zero rates contribute nothing.
    final itemRateSum = rate1 + rate2 + rate3;
    final lineTotal = getItemTaxable(item, total, input, precision);
    if (rate1 != Decimal.zero) {
      final t = _taxAmount(
        lineTotal,
        rate1,
        input.usesInclusiveTaxes,
        precision,
        totalRate: itemRateSum,
      );
      map.update(item.taxName1, (v) => v + t, ifAbsent: () => t);
    }
    if (rate2 != Decimal.zero) {
      final t = _taxAmount(
        lineTotal,
        rate2,
        input.usesInclusiveTaxes,
        precision,
        totalRate: itemRateSum,
      );
      map.update(item.taxName2, (v) => v + t, ifAbsent: () => t);
    }
    if (rate3 != Decimal.zero) {
      final t = _taxAmount(
        lineTotal,
        rate3,
        input.usesInclusiveTaxes,
        precision,
        totalRate: itemRateSum,
      );
      map.update(item.taxName3, (v) => v + t, ifAbsent: () => t);
    }
  }

  // Apply invoice-level discount + the surcharges that ARE taxable, then
  // run the invoice-level tax rates against the resulting taxable amount.
  if (input.discount != Decimal.zero) {
    if (input.isAmountDiscount) {
      total = total - _round(input.discount, precision);
    } else {
      total = total - _round(_mulRate(total, input.discount), precision);
    }
  }
  // NOTE: taxable surcharges are deliberately NOT folded into the tax base.
  // The server keeps them out of `$this->total` (they live in
  // `total_custom_values`) and instead adds a SEPARATELY ROUNDED tax component
  // per taxable slot via `InvoiceSum::getSurchargeTaxTotalForKey`. Folding them
  // in rounded once over the combined base, which differs by a cent once two
  // taxable surcharges are present — and in INCLUSIVE mode it was plain wrong:
  // `InvoiceSumInclusive` has the surcharge-tax lines commented out, so a
  // taxable surcharge must not shrink/inflate the inclusive base at all.
  // Invoice-level tax tiers require a tax NAME of length >= 2, matching the
  // server (InvoiceSum: each tier applies only when strlen(tax_nameN) >= 2,
  // with no rate-only escape hatch). Without this the breakdown shows — and
  // stampTotalsForSave persists — a tax the server silently drops on sync, so
  // the local total reads too high until a refresh. Line-item tax is NOT
  // name-gated server-side (InvoiceItemSum), so the per-line rates above stay
  // rate-only. (L6)
  // Σr for invoice-level inclusive tax is built from ALL THREE rates and is
  // deliberately NOT name-gated: `InvoiceSumInclusive::calculateTaxes` passes
  // the raw `[tax_rate1, tax_rate2, tax_rate3]` straight into
  // `InclusiveTax::backout` and applies the name gate only afterwards, when
  // deciding which component to add to `total_taxes`. So a rate carrying a
  // blank / 1-char name still shrinks the shared base for the tiers that do
  // survive the gate. Mirroring that keeps the on-screen total equal to what
  // the server stores (reachable via API-created or imported invoices — the
  // tax picker always sets name + rate together). Zero rates contribute
  // nothing. (issue #12072)
  final invoiceRateSum = input.taxRate1 + input.taxRate2 + input.taxRate3;
  if (input.taxRate1 != Decimal.zero && input.taxName1.length >= 2) {
    final t =
        _taxAmount(
          total,
          input.taxRate1,
          input.usesInclusiveTaxes,
          precision,
          totalRate: invoiceRateSum,
        ) +
        _surchargeTax(input, input.taxRate1, precision);
    map.update(input.taxName1, (v) => v + t, ifAbsent: () => t);
  }
  if (input.taxRate2 != Decimal.zero && input.taxName2.length >= 2) {
    final t =
        _taxAmount(
          total,
          input.taxRate2,
          input.usesInclusiveTaxes,
          precision,
          totalRate: invoiceRateSum,
        ) +
        _surchargeTax(input, input.taxRate2, precision);
    map.update(input.taxName2, (v) => v + t, ifAbsent: () => t);
  }
  if (input.taxRate3 != Decimal.zero && input.taxName3.length >= 2) {
    final t =
        _taxAmount(
          total,
          input.taxRate3,
          input.usesInclusiveTaxes,
          precision,
          totalRate: invoiceRateSum,
        ) +
        _surchargeTax(input, input.taxRate3, precision);
    map.update(input.taxName3, (v) => v + t, ifAbsent: () => t);
  }

  return map;
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
  final qty = _round(item.quantity, 5);
  final cost = _round(item.cost, 5);
  final itemDiscount = _round(item.discount, 5);
  var lineTotal = qty * cost;

  if (input.isAmountDiscount) {
    // Item discount FIRST, then prorate the invoice amount-discount across the
    // post-item-discount line total over the post-item-discount subtotal
    // (`invoiceTotal` == computeSubtotal) — matching the server's setDiscount →
    // calcTaxesWithAmountDiscount order and _calculateTotal above. Prorating on
    // the pre-item-discount line total over-shrinks the tax base.
    if (itemDiscount != Decimal.zero) lineTotal = lineTotal - itemDiscount;
    if (input.discount != Decimal.zero && invoiceTotal != Decimal.zero) {
      // Wide working scale (10) for the ratio — passing the currency precision
      // (typically 2) would truncate `lineTotal / invoiceTotal` and skew the
      // per-item tax breakdown (admin-portal's `double` math has no such loss).
      lineTotal =
          lineTotal -
          _safeDiv(lineTotal, invoiceTotal, precision: 10) * input.discount;
    }
  } else {
    // Percent discounts commute — order is irrelevant.
    if (input.discount != Decimal.zero) {
      final factor = (Decimal.fromInt(100) - input.discount);
      lineTotal = _safeDiv(
        lineTotal * factor,
        Decimal.fromInt(100),
        precision: 10,
      );
    }
    if (itemDiscount != Decimal.zero) {
      lineTotal = lineTotal - _mulRate(lineTotal, itemDiscount);
    }
  }

  return _round(lineTotal, precision);
}

/// Invoice-level taxable, after item discounts + invoice discount +
/// taxable surcharges. Mirrors `CalculateInvoiceTotal.getTaxable`. Kept
/// public for callers that want the pre-tax base independent of the
/// per-line breakdown.
Decimal getTaxable(BillingTotalsInput input, int precision) {
  var total = Decimal.zero;
  for (final item in input.lineItems) {
    var lineTotal = item.quantity * item.cost;
    if (item.discount != Decimal.zero) {
      if (input.isAmountDiscount) {
        lineTotal = lineTotal - item.discount;
      } else {
        lineTotal =
            lineTotal - _round(_mulRate(lineTotal, item.discount), precision);
      }
    }
    total = total + lineTotal;
  }
  if (input.discount != Decimal.zero) {
    if (input.isAmountDiscount) {
      total = total - input.discount;
    } else {
      total = _round(
        _safeDiv(
          total * (Decimal.fromInt(100) - input.discount),
          Decimal.fromInt(100),
          precision: 10,
        ),
        precision,
      );
    }
  }
  if (input.customTaxes1) total = total + input.customSurcharge1;
  if (input.customTaxes2) total = total + input.customSurcharge2;
  if (input.customTaxes3) total = total + input.customSurcharge3;
  if (input.customTaxes4) total = total + input.customSurcharge4;
  return total;
}

// -------------------------------------------------------------------------

Decimal _calculateTotal(BillingTotalsInput input, int precision) {
  var total = computeSubtotal(input, precision);
  var itemTax = Decimal.zero;

  for (final item in input.lineItems) {
    final qty = _round(item.quantity, 5);
    final cost = _round(item.cost, 5);
    final itemDiscount = _round(item.discount, 5);
    final rate1 = _round(item.taxRate1, 3);
    final rate2 = _round(item.taxRate2, 3);
    final rate3 = _round(item.taxRate3, 3);
    var lineTotal = qty * cost;

    if (input.isAmountDiscount) {
      // The server applies the ITEM discount first (setDiscount), THEN prorates
      // the invoice amount-discount across the ALREADY-reduced line totals
      // (calcTaxesWithAmountDiscount: amount = line_total − discount×line_total/
      // sub_total, where line_total and sub_total are both post-item-discount).
      // Applying the proration on the pre-item-discount line total over-shrinks
      // the tax base whenever a line also carries its own discount.
      if (itemDiscount != Decimal.zero) lineTotal = lineTotal - itemDiscount;
      if (input.discount != Decimal.zero && total != Decimal.zero) {
        // Wide working scale for the ratio — see getItemTaxable rationale.
        lineTotal =
            lineTotal -
            _round(
              _safeDiv(lineTotal, total, precision: 10) * input.discount,
              precision,
            );
      }
    } else {
      // Percent discounts commute, so order is irrelevant.
      if (input.discount != Decimal.zero) {
        lineTotal =
            lineTotal - _round(_mulRate(lineTotal, input.discount), precision);
      }
      if (itemDiscount != Decimal.zero) {
        lineTotal =
            lineTotal - _round(_mulRate(lineTotal, itemDiscount), precision);
      }
    }
    lineTotal = _round(lineTotal, precision);

    if (rate1 != Decimal.zero) {
      itemTax = itemTax + _round(_mulRate(lineTotal, rate1), precision);
    }
    if (rate2 != Decimal.zero) {
      itemTax = itemTax + _round(_mulRate(lineTotal, rate2), precision);
    }
    if (rate3 != Decimal.zero) {
      itemTax = itemTax + _round(_mulRate(lineTotal, rate3), precision);
    }
  }

  if (input.discount != Decimal.zero) {
    if (input.isAmountDiscount) {
      total = total - _round(input.discount, precision);
    } else {
      total = total - _round(_mulRate(total, input.discount), precision);
    }
  }
  if (!input.usesInclusiveTaxes) {
    // Invoice-level tiers require tax_name length >= 2 (server parity — see
    // computeTaxBreakdown); `itemTax` (per-line) is name-independent. (L6)
    // Each tier = round(base × rate) + a separately-rounded component per
    // taxable surcharge, matching `InvoiceSum::getSurchargeTaxTotalForKey`.
    // The surcharges themselves stay OUT of the base (server:
    // `total_custom_values`) and are added after tax, below.
    final t1 = input.taxName1.length >= 2
        ? _round(_mulRate(total, input.taxRate1), precision) +
              _surchargeTax(input, input.taxRate1, precision)
        : Decimal.zero;
    final t2 = input.taxName2.length >= 2
        ? _round(_mulRate(total, input.taxRate2), precision) +
              _surchargeTax(input, input.taxRate2, precision)
        : Decimal.zero;
    final t3 = input.taxName3.length >= 2
        ? _round(_mulRate(total, input.taxRate3), precision) +
              _surchargeTax(input, input.taxRate3, precision)
        : Decimal.zero;
    total = total + itemTax + t1 + t2 + t3;
  }
  // All four surcharges are added AFTER tax (server: `total_custom_values` is
  // summed into the total once, regardless of the per-slot tax flag).
  total = total + _round(input.customSurcharge1, precision);
  total = total + _round(input.customSurcharge2, precision);
  total = total + _round(input.customSurcharge3, precision);
  total = total + _round(input.customSurcharge4, precision);
  return _round(total, precision);
}

/// Invoice-level tax contributed by the taxable custom surcharges at [rate].
///
/// Mirrors `InvoiceSum::getSurchargeTaxTotalForKey`: each flagged slot's
/// component is rounded INDEPENDENTLY and summed, rather than taxing the
/// combined surcharge amount in one go. Inclusive mode contributes nothing —
/// `InvoiceSumInclusive` has these lines commented out.
Decimal _surchargeTax(BillingTotalsInput input, Decimal rate, int precision) {
  if (input.usesInclusiveTaxes || rate == Decimal.zero) return Decimal.zero;
  var out = Decimal.zero;
  if (input.customTaxes1) {
    out = out + _round(_mulRate(input.customSurcharge1, rate), precision);
  }
  if (input.customTaxes2) {
    out = out + _round(_mulRate(input.customSurcharge2, rate), precision);
  }
  if (input.customTaxes3) {
    out = out + _round(_mulRate(input.customSurcharge3, rate), precision);
  }
  if (input.customTaxes4) {
    out = out + _round(_mulRate(input.customSurcharge4, rate), precision);
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

Decimal _add(Decimal a, Decimal b) => a + b;
