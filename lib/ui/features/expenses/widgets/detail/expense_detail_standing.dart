import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/expense.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/expenses/widgets/expense_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// Where an expense stands: what it cost, and where it is on the way from
/// logged to invoiced or paid.
///
/// It replaces a four-cell strip — Amount, Gross Amount, Date, Status — whose
/// second cell was a dash on every expense without tax, and whose third said
/// again what the header says.
///
/// * **Amount** is the amount as entered, the figure every list and the edit
///   form call by that name. It always prints, zero included.
/// * **The figure beside it exists only when there is tax**, and is whichever
///   one the amount is not: the gross when tax is added on top, the net when
///   the amount already includes it.
/// * **The status sits under the figures as the pill** the list shows beside
///   the amount — one word, in the colour the user already knows it by.
/// * **Tax and the converted amount** are drawn only when there is one
///   (`!= zero`, so a negative one shows too): on most expenses both are
///   nothing, and a labelled nothing is noise.
///
/// Amounts are in the expense's own currency; the converted amount is in the
/// currency it will be invoiced in.
class ExpenseDetailStanding extends StatelessWidget {
  const ExpenseDetailStanding({
    super.key,
    required this.expense,
    required this.formatter,
  });

  final Expense expense;

  /// Null while it loads — the figures are blank until it arrives.
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final e = expense;
    String money(Decimal amount, {String? currencyId}) =>
        formatter?.money(
          amount,
          clientCurrencyId: currencyId ?? e.currencyId,
        ) ??
        '';
    final tax = e.taxAmountSum;
    final hasTax = tax != Decimal.zero;
    // Only meaningful when an invoice currency is set and the rate is not a
    // no-op.
    final hasConversion =
        e.invoiceCurrencyId.isNotEmpty &&
        e.effectiveExchangeRate != Decimal.one;
    return StandingCard(
      primary: [
        StandingFigure(label: context.tr('amount'), value: money(e.amount)),
        if (hasTax)
          e.usesInclusiveTaxes
              ? StandingFigure(
                  label: context.tr('net_amount'),
                  value: money(e.netAmount),
                )
              : StandingFigure(
                  label: context.tr('gross_amount'),
                  value: money(e.grossAmount),
                ),
      ],
      secondary: [
        if (hasTax) StandingFigure(label: context.tr('tax'), value: money(tax)),
        if (hasConversion)
          StandingFigure(
            label: context.tr('converted_amount'),
            value: money(e.convertedAmount, currencyId: e.invoiceCurrencyId),
          ),
      ],
      footnote: Padding(
        padding: const EdgeInsets.only(top: kStandingFootnoteGap),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: ExpenseStatusPill(statusId: e.calculatedStatusId),
        ),
      ),
    );
  }
}
