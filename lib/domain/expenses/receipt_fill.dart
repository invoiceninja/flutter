/// How a receipt read fills a New Expense — the rules, without the form
/// (`docs/receipt-ocr.md`). A leaf the view model calls, so every rule is
/// unit-testable.
///
/// The one principle: **a read only fills a field that is still blank and
/// untouched**. It never replaces a value the user typed, one a "New expense"
/// from a vendor or a clone brought, or one the company's defaults set — so
/// the worst a bad read can do is fill a blank wrongly, which the form marks
/// and Undo reverts.
library;

import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/currency.dart';
import 'package:admin/domain/expenses/receipt_parser.dart';
import 'package:admin/domain/expenses/receipt_scanner.dart';

/// A field a receipt read can fill — and the form can mark.
enum ReceiptFillField {
  amount,
  date,
  vendor,
  currency,
  tax1,
  tax2,
  tax3,
  notes,
}

/// What the company's settings say about where a read may go.
class ReceiptFillContext {
  const ReceiptFillContext({
    this.enabledTaxTiers = 0,
    this.taxRates = const [],
    this.currencies = const {},
    required this.receiptNote,
  });

  /// `enabled_expense_tax_rates`: 0 means the company turned expense tax off,
  /// and a read must not bring tax rows back.
  final int enabledTaxTiers;

  /// The company's configured tax rates, for keeping a read rate in By rate
  /// mode when it is one of them.
  final List<({String name, Decimal rate})> taxRates;

  /// The statics catalogue by id, for the receipt's currency code and the
  /// cross-currency rate.
  final Map<String, Currency> currencies;

  /// "Receipt #1001", localised — appended to the private notes.
  final String Function(String number) receiptNote;
}

class ReceiptFillResult {
  const ReceiptFillResult(this.draft, this.filled);

  /// The draft with the read applied (the input itself when nothing fit).
  final Expense draft;

  /// Which fields the read filled, and how sure it was of each.
  final Map<ReceiptFillField, ReceiptConfidence> filled;
}

/// [draft] with [read] applied to its blank, untouched fields.
///
/// [baseline] is the form's untouched state (`createBaseline`); [prefilled]
/// is a clone or a staged draft, whose date is not the "today" default.
/// [busy] lists fields the user is in the middle of editing — a half-typed
/// date isn't in the draft yet, and must not be overwritten under the caret.
/// [userChoseInclusive] is whether the user set the inclusive-taxes switch
/// themselves; a read then leaves it be.
ReceiptFillResult fillExpenseFromReceipt({
  required Expense draft,
  required Expense baseline,
  required bool prefilled,
  required ReceiptRead read,
  required ReceiptFillContext ctx,
  required bool paymentDateFollowsDate,
  bool userChoseInclusive = false,
  Set<ReceiptFillField> busy = const {},
}) {
  final scan = read.scan;
  final filled = <ReceiptFillField, ReceiptConfidence>{};
  var next = draft;

  final total = scan.total;
  if (total != null &&
      draft.amount == Decimal.zero &&
      !busy.contains(ReceiptFillField.amount)) {
    next = next.copyWith(amount: total.value);
    if (next.invoiceCurrencyId.isNotEmpty) {
      next = next.copyWith(foreignAmount: total.value * next.exchangeRate);
    }
    filled[ReceiptFillField.amount] = total.confidence;
  }

  final date = scan.date;
  if (date != null &&
      !prefilled &&
      draft.date == baseline.date &&
      !busy.contains(ReceiptFillField.date)) {
    next = next.copyWith(date: date.value);
    // A receipt back-dated to last week was paid last week: the Mark-paid
    // payment date follows, as it does when the user changes the date.
    if (paymentDateFollowsDate && next.paymentDate != null) {
      next = next.copyWith(paymentDate: date.value);
    }
    filled[ReceiptFillField.date] = date.confidence;
  }

  final vendorId = read.vendorId;
  final vendorFilled =
      vendorId != null &&
      draft.vendorId.isEmpty &&
      !busy.contains(ReceiptFillField.vendor);
  if (vendorFilled) {
    next = next.copyWith(vendorId: vendorId);
    filled[ReceiptFillField.vendor] = ReceiptConfidence.sure;
  }

  // The receipt's own currency first; else, as the vendor picker does, the
  // vendor's; never an ambiguous symbol (the parser drops those).
  if (draft.currencyId.isEmpty && !busy.contains(ReceiptFillField.currency)) {
    String? currencyId;
    final code = scan.currencyCode;
    if (code != null) {
      currencyId = ctx.currencies.values
          .where((c) => c.code.toUpperCase() == code)
          .firstOrNull
          ?.id;
    }
    if (currencyId == null && vendorFilled) {
      final v = read.vendorCurrencyId;
      if (v != null && v.isNotEmpty) currencyId = v;
    }
    if (currencyId != null) {
      next = next.copyWith(currencyId: currencyId);
      // An invoice currency already picked: the rate between the two moved.
      if (next.invoiceCurrencyId.isNotEmpty) {
        final rate = crossCurrencyRate(
          ctx.currencies,
          fromExpenseCurrencyId: currencyId,
          toInvoiceCurrencyId: next.invoiceCurrencyId,
        );
        if (rate != null) {
          next = next.copyWith(
            exchangeRate: rate,
            foreignAmount: next.amount * rate,
          );
        }
      }
      filled[ReceiptFillField.currency] = ReceiptConfidence.sure;
    }
  }

  final tiers = ctx.enabledTaxTiers.clamp(0, 3);
  if (tiers > 0 &&
      scan.taxes.isNotEmpty &&
      !_hasTax(draft) &&
      !busy.contains(ReceiptFillField.tax1)) {
    next = _fillTaxes(next, scan.taxes, tiers, ctx, filled, total?.value);
    // A receipt's total includes its tax — so inclusive, but only for an
    // amount the receipt gave: a net amount the user typed stays net.
    if (filled.containsKey(ReceiptFillField.tax1) &&
        !userChoseInclusive &&
        (filled.containsKey(ReceiptFillField.amount) ||
            draft.amount == Decimal.zero)) {
      next = next.copyWith(usesInclusiveTaxes: true);
    }
  }

  final number = scan.receiptNumber;
  if (number != null && !busy.contains(ReceiptFillField.notes)) {
    final note = ctx.receiptNote(number);
    if (!draft.privateNotes.contains(note)) {
      next = next.copyWith(
        privateNotes: draft.privateNotes.trim().isEmpty
            ? note
            : '${draft.privateNotes}\n$note',
      );
      filled[ReceiptFillField.notes] = ReceiptConfidence.sure;
    }
  }

  return ReceiptFillResult(next, filled);
}

bool _hasTax(Expense d) =>
    [d.taxName1, d.taxName2, d.taxName3].any((n) => n.isNotEmpty) ||
    [
      d.taxRate1,
      d.taxRate2,
      d.taxRate3,
      d.taxAmount1,
      d.taxAmount2,
      d.taxAmount3,
    ].any((v) => v != Decimal.zero);

const _taxSlots = [
  ReceiptFillField.tax1,
  ReceiptFillField.tax2,
  ReceiptFillField.tax3,
];

Expense _fillTaxes(
  Expense d,
  List<ReceiptTax> taxes,
  int tiers,
  ReceiptFillContext ctx,
  Map<ReceiptFillField, ReceiptConfidence> filled,
  Decimal? total,
) {
  // One tax whose rate is exactly one of the company's, and whose printed
  // amount is what that rate on the total comes to: By rate, under the
  // company's own name for it. A receipt where the rate covers only some
  // lines (untaxed groceries: 8.625% printed, 0.56 tax on 14.23) would be
  // taxed whole by rate — so it goes By amount, as printed.
  String? companyName;
  if (taxes.length == 1 && taxes.single.rate != null) {
    final rate = taxes.single.rate!;
    final matches = ctx.taxRates.where((r) => r.rate == rate).toList();
    if (matches.length == 1) {
      companyName = matches.single.name;
      final amount = taxes.single.amount;
      if (amount == null || _rateAgrees(rate, amount, total)) {
        filled[ReceiptFillField.tax1] = ReceiptConfidence.sure;
        return d.copyWith(
          calculateTaxByAmount: false,
          taxName1: companyName,
          taxRate1: rate,
          taxAmount1: Decimal.zero,
        );
      }
    }
  }
  // Otherwise By amount — what a receipt states — one tier per printed tax,
  // the last tier carrying the sum of any that don't fit.
  final withAmount = [
    for (final t in taxes)
      if (t.amount != null && t.amount! > Decimal.zero) t,
  ];
  if (withAmount.isEmpty) return d;
  final names = <String>[];
  final amounts = <Decimal>[];
  for (var i = 0; i < withAmount.length; i++) {
    final t = withAmount[i];
    if (i < tiers - 1 || withAmount.length <= tiers) {
      names.add(i == 0 && companyName != null ? companyName : _taxLabel(t));
      amounts.add(t.amount!);
    } else {
      // Fold the rest into the last tier.
      final rest = withAmount.skip(i).toList();
      names.add(rest.map(_taxLabel).toSet().join(' + '));
      amounts.add(rest.fold(Decimal.zero, (sum, t) => sum + t.amount!));
      break;
    }
  }
  var next = d.copyWith(
    calculateTaxByAmount: true,
    taxRate1: Decimal.zero,
    taxRate2: Decimal.zero,
    taxRate3: Decimal.zero,
  );
  for (var i = 0; i < names.length; i++) {
    next = switch (i) {
      0 => next.copyWith(taxName1: names[i], taxAmount1: amounts[i]),
      1 => next.copyWith(taxName2: names[i], taxAmount2: amounts[i]),
      _ => next.copyWith(taxName3: names[i], taxAmount3: amounts[i]),
    };
    filled[_taxSlots[i]] = ReceiptConfidence.sure;
  }
  return next;
}

/// Whether [amount] is [rate] percent of the tax-inclusive [total], to the
/// cent. Without a total there is nothing to check against.
bool _rateAgrees(Decimal rate, Decimal amount, Decimal? total) {
  if (total == null) return true;
  final expected = (total * rate / (Decimal.fromInt(100) + rate)).toDecimal(
    scaleOnInfinitePrecision: 4,
  );
  return (expected - amount).abs() <= Decimal.parse('0.01');
}

String _taxLabel(ReceiptTax t) {
  final rate = t.rate;
  return rate == null ? t.name : '${t.name} ${rate.toString()}%';
}
