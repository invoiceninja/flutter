import 'package:decimal/decimal.dart';

import 'package:admin/utils/formatting.dart';

/// The string in the bottom-left of the Add-items picker footer
/// (`_Footer`, `line_item_picker_body.dart`).
///
/// Blank until something is picked. That slot is *unlabelled* and its
/// non-zero form is money (`3 · $45.00`), so a bare `0` sitting there reads as
/// an amount whose currency symbol went missing — invoiceninja/flutter#132.
/// Nothing at all is the house rule for an empty value in an unlabelled slot;
/// the caller keeps its `Text` mounted and feeds it `''` (blank, not absent).
///
/// The gate is [count], never [total]: a picked free product has a zero total
/// and still has something to say, so `1 · $0.00` renders.
///
/// [clientCurrencyId] + [groupCurrencyId] label the sum with the document's
/// currency — the picked rows have already been converted into it.
/// `Formatter._resolveCurrencyId` walks them client → group → company, which
/// is the same cascade `watchEffectiveClientCurrency`
/// (`client_settings_cascade.dart`) resolves for the totals strip the user
/// lands on next; resolving only the client's own override rendered a grouped
/// client's totals in the company currency, "with the wrong symbol AND
/// precision" (`billing_edit_totals.dart`). Both empty is what a purchase
/// order gets — no client, no group — so it falls through to the company.
String lineItemPickerFooterText({
  required int count,
  required Decimal total,
  Formatter? formatter,
  String? clientCurrencyId,
  String? groupCurrencyId,
}) {
  if (count == 0) return '';
  final money = formatter?.money(
    total,
    clientCurrencyId: clientCurrencyId,
    groupCurrencyId: groupCurrencyId,
  );
  // `money` is empty for more than a missing `Formatter`: `Formatter.money`
  // returns `''` outright when the resolved currency id isn't in its
  // `currencies` map (`formatting.dart`, the `memo == null` branch). The code
  // this replaced interpolated unconditionally, so that case rendered `2 · `
  // — a dangling separator with nothing after it. Don't fold this back into
  // the interpolation. The window is narrow (`Services._buildFormatter`
  // awaits `statics.ensureLoaded()`, so a non-null formatter carries the full
  // global currency map) but it widened here: the id being resolved is now
  // the client's, not the company's. Degrading to the bare count rather than
  // re-running with the company currency is the house answer — every other
  // `clientCurrencyId:` call site lets an unknown id yield `''` instead of
  // labelling the amount with a currency it isn't in.
  if (money == null || money.isEmpty) return '$count';
  return '$count · $money';
}
