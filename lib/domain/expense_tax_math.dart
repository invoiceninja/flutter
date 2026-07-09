import 'package:decimal/decimal.dart';

final Decimal _oneHundredth = Decimal.parse('0.01');

/// Tax amount for one expense tax tier, computed from its rate.
///
/// Mirrors admin-portal `expense_model.dart` `calculateTaxAmountN` and React
/// `useCalculateExpenseAmount`:
///   * exclusive: `amount * rate / 100`
///   * inclusive: extract the tier from a shared net base.
///
/// For inclusive tax the net base is `amount / (1 + Σr/100)` where `Σr`
/// ([totalRate]) is the sum of ALL inclusive rates on this same gross amount
/// (issue invoiceninja/invoiceninja#12072). Each tier's tax is then
/// `rate/100 × net`. With a single applicable rate `Σr == rate`, so this
/// reduces to the legacy `amount - amount/(1 + rate/100)` byte-for-byte — only
/// the two-or-more-inclusive-rates case changes (it used to extract each rate
/// independently from the full gross, which reconciled to no coherent model).
/// [totalRate] defaults to [rate] (the single-rate case) when omitted.
///
/// Rounded to 2 decimals — admin-portal's convention; the `Formatter` applies
/// the final per-currency precision on display. A zero rate yields zero.
///
/// In `calculate_tax_by_amount` mode the rate is not used at all — the stored
/// `tax_amount*` is the source of truth — so callers pass the stored amount
/// straight through rather than calling this.
Decimal expenseTierTaxAmount({
  required Decimal amount,
  required Decimal rate,
  required bool usesInclusiveTaxes,
  Decimal? totalRate,
}) {
  if (rate == Decimal.zero) return Decimal.zero;
  if (usesInclusiveTaxes) {
    // `Σr` — the sum of all inclusive rates sharing this gross. Defaults to
    // this tier's own rate (single-rate) when the caller doesn't pass it.
    final sumRate = totalRate ?? rate;
    // A combined inclusive rate ≤ 0 yields no tax — parity with the backend
    // `InclusiveTax::backout` `combined_rate <= 0` guard.
    if (sumRate <= Decimal.zero) return Decimal.zero;
    final divisor = Decimal.one + sumRate * _oneHundredth;
    if (divisor == Decimal.zero) return Decimal.zero;
    final net = (amount / divisor).toDecimal(scaleOnInfinitePrecision: 10);
    if (sumRate == rate) {
      // Single applicable rate: run the exact legacy expression so the common
      // case is byte-identical (see doc comment).
      return (amount - net).round(scale: 2);
    }
    // Two or more inclusive rates: additive shared-base — this tier's share of
    // the shared net (`rate/100 × net`), not an independent extraction.
    return (rate * _oneHundredth * net).round(scale: 2);
  }
  return (amount * rate * _oneHundredth).round(scale: 2);
}
