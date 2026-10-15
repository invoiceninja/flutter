import 'package:decimal/decimal.dart';

/// One selected billing document, as the selection totals read it.
class SelectionTotalsRow {
  const SelectionTotalsRow({
    required this.clientId,
    required this.amount,
    required this.taxes,
    this.balance,
  });

  final String clientId;
  final Decimal amount;

  /// `total_taxes` — what separates the amount from the net amount.
  final Decimal taxes;

  /// Null where the list doesn't total a balance (quotes, recurring invoices).
  final Decimal? balance;
}

/// What a selection comes to in one currency.
class CurrencyTotals {
  const CurrencyTotals({
    required this.currencyId,
    required this.count,
    required this.amount,
    required this.net,
    this.balance,
  });

  final String currencyId;
  final int count;
  final Decimal amount;

  /// Amount less taxes — React's `calculateNetAmount`.
  final Decimal net;

  /// Null when no row carried one.
  final Decimal? balance;
}

/// The selected documents' Amount, Net Amount and Balance, **one set per
/// currency**, in the order each currency first appears. A total never adds
/// two currencies together: React's footer does, and prints the result
/// unformatted, which is a number with no meaning.
///
/// [currencyOf] resolves a row's client to its effective currency id. It may
/// return null for a client still resolving; the whole answer is then null,
/// since a total missing a row is a wrong total, not a partial one.
List<CurrencyTotals>? selectionTotals(
  Iterable<SelectionTotalsRow> rows,
  String? Function(String clientId) currencyOf,
) {
  final order = <String>[];
  final count = <String, int>{};
  final amount = <String, Decimal>{};
  final net = <String, Decimal>{};
  final balance = <String, Decimal>{};
  for (final row in rows) {
    final currency = currencyOf(row.clientId);
    if (currency == null) return null;
    if (!count.containsKey(currency)) {
      order.add(currency);
      count[currency] = 0;
      amount[currency] = Decimal.zero;
      net[currency] = Decimal.zero;
    }
    count[currency] = count[currency]! + 1;
    amount[currency] = amount[currency]! + row.amount;
    net[currency] = net[currency]! + row.amount - row.taxes;
    final b = row.balance;
    if (b != null) balance[currency] = (balance[currency] ?? Decimal.zero) + b;
  }
  return [
    for (final c in order)
      CurrencyTotals(
        currencyId: c,
        count: count[c]!,
        amount: amount[c]!,
        net: net[c]!,
        balance: balance[c],
      ),
  ];
}
