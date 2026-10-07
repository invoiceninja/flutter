import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_spend_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// Where a vendor stands: what has been spent with them, and when last.
///
/// A vendor has no server-side balance, so both figures come from its
/// expenses on this device — see [VendorSpendViewModel] for when that is, and
/// is not, the whole story. The three renderings:
///
///  * **known** — the total, zero included (`$0.00` is the answer to "what
///    have we spent with them"), and the date of the last expense;
///  * **no expense yet** — the total is a real zero and the date is a muted
///    dash: the slot is labelled, and there is no date to put in it;
///  * **not known** — blank lines of the right height, never a dash and never
///    a partial sum. The formatter is still loading, or the device is known
///    to hold only some of the vendor's expenses.
///
/// Both figures open the Expenses tab, which lists what they summarize —
/// newest first, so the last expense is its first row.
class VendorDetailStanding extends StatelessWidget {
  const VendorDetailStanding({
    super.key,
    required this.vendor,
    required this.formatter,
    required this.spend,
    required this.onOpenExpenses,
  });

  final Vendor vendor;

  /// Null while it loads — the figures are blank until it arrives.
  final Formatter? formatter;
  final VendorSpendViewModel spend;
  final VoidCallback onOpenExpenses;

  /// The currency [vendor]'s expenses are summed and printed in. A vendor
  /// saved by the current server always has one; an older record without one
  /// is in the company's.
  static String currencyIdOf(Vendor vendor, Formatter formatter) =>
      vendor.currencyId.isNotEmpty
      ? vendor.currencyId
      : formatter.settings.currencyId;

  @override
  Widget build(BuildContext context) {
    // Its own listenable, inside the card: an expense arriving re-draws two
    // figures, not the page.
    return ListenableBuilder(
      listenable: spend,
      builder: (context, _) {
        final f = formatter;
        final value = f == null
            ? null
            : spend.valueFor(currencyId: currencyIdOf(vendor, f));
        final last = value?.lastExpense;
        final tabName = context.tr('expenses');
        return StandingCard(
          primary: [
            StandingFigure(
              label: context.tr('total_expenses'),
              value: value == null || f == null
                  ? ''
                  : f.money(
                      value.total,
                      clientCurrencyId: currencyIdOf(vendor, f),
                    ),
              onTap: onOpenExpenses,
              semanticsHint: tabName,
            ),
            StandingFigure(
              label: context.tr('last_expense_date'),
              value: value == null || f == null
                  ? ''
                  : (last == null ? '—' : f.date(last.toIso())),
              // A dash leads nowhere; a date leads to the expense it names.
              onTap: last == null ? null : onOpenExpenses,
              semanticsHint: last == null ? null : tabName,
              valueColor: value != null && last == null
                  ? context.inTheme.ink3
                  : null,
              // The dash is a placeholder, not a value to copy.
              copyable: last != null,
            ),
          ],
        );
      },
    );
  }
}
