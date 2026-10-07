import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/core/detail/related_rows_proof.dart';

/// What a vendor's expenses come to.
@immutable
class VendorSpend {
  const VendorSpend({required this.total, required this.lastExpense});

  /// The sum of the expenses raised in the vendor's own currency.
  final Decimal total;

  /// The date of the most recent expense, in any currency. Null when the
  /// vendor has none.
  final Date? lastExpense;
}

/// Adds up [expenses] — a vendor's active expenses.
///
/// **Only [currencyId] is summed.** `Decimal` addition is currency-blind, so
/// an expense paid in another currency would be added as if it were in this
/// one. The date is currency-neutral and is taken from all of them.
VendorSpend vendorSpendOf(
  List<Expense> expenses, {
  required String currencyId,
}) {
  var total = Decimal.zero;
  Date? last;
  for (final e in expenses) {
    if (e.currencyId == currencyId) total += e.amount;
    final d = e.date;
    if (d != null && (last == null || d.compareTo(last) > 0)) last = d;
  }
  return VendorSpend(total: total, lastExpense: last);
}

/// Feeds the vendor screen's standing card: what the vendor's expenses add up
/// to, and when the last one was.
///
/// The server keeps no such figure for a vendor, so it is the sum of the
/// expenses **this device holds** — and expenses are paged in fifty at a time,
/// so the device may hold only some of them. [RelatedRowsProof] is what stands
/// between that and a confidently wrong total: the cached sum shows while
/// nothing says otherwise; once the Expenses tab's count says the device holds
/// fewer, the figure is withheld and the missing pages are fetched,
/// vendor-scoped; a vendor past [maxPages] pages stays withheld.
///
/// Owned by the screen, like the activity view model beside it.
class VendorSpendViewModel extends RelatedRowsProof<Expense> {
  VendorSpendViewModel({
    required super.watch,
    required super.fetchPage,
    required super.pageSize,
    required super.counts,
    required super.countTabId,
    required super.isCurrent,
    super.maxPages,
    super.debounce,
  }) : super(idOf: _idOf);

  static String _idOf(Expense e) => e.id;

  /// The vendor's spend in [currencyId], or null while it is not known: the
  /// local rows have not arrived, or the device is known to hold only some of
  /// them.
  VendorSpend? valueFor({required String currencyId}) {
    final rows = this.rows;
    return rows == null ? null : vendorSpendOf(rows, currencyId: currencyId);
  }
}
