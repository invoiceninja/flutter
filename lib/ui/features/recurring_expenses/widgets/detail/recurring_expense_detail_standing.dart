import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// Where a recurring expense stands: what each run costs, when the next one
/// is, and whether it is running at all.
///
/// It replaces a four-cell strip — Amount, Next Send Date, Frequency, Status —
/// whose third cell is now part of the line under the number.
///
/// * **Amount** always prints, zero included.
/// * **Next Send Date** exists only when there is one. A draft that was never
///   scheduled and a schedule that has run its last cycle have no next date,
///   and a caption over a dash would read as one that failed to load.
/// * **The status sits under the figures as the pill** the list shows: the
///   same word and colour, saying whether the Start or the Stop tile beside
///   this card is the one on offer.
/// * **Tax and the cycles left** are drawn only when there is something to
///   say — an untaxed, endless schedule has neither. (When it last ran is a
///   Details row: a third line here made this card the tallest thing in the
///   band, and dropped the tiles beside it a long way from the header.)
class RecurringExpenseDetailStanding extends StatelessWidget {
  const RecurringExpenseDetailStanding({
    super.key,
    required this.recurringExpense,
    required this.formatter,
  });

  final RecurringExpense recurringExpense;

  /// Null while it loads — the figures are blank until it arrives.
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final e = recurringExpense;
    final f = formatter;
    String money(Decimal amount) =>
        f?.money(amount, clientCurrencyId: e.currencyId) ?? '';
    // Blank, never the raw ISO date, until the company's format is here.
    String date(String iso) => f?.date(iso) ?? '';
    final next = e.nextSendDate;
    final tax = e.taxAmountSum;
    return StandingCard(
      primary: [
        StandingFigure(label: context.tr('amount'), value: money(e.amount)),
        if (next != null)
          StandingFigure(
            label: context.tr('next_send_date'),
            value: date(next.toIso()),
          ),
      ],
      secondary: [
        if (tax != Decimal.zero)
          StandingFigure(label: context.tr('tax'), value: money(tax)),
        // -1 is "endless", the default; a finite count is the news. Zero is
        // one: the schedule has run out.
        if (e.remainingCycles != -1)
          StandingFigure(
            label: context.tr('remaining_cycles'),
            value: '${e.remainingCycles}',
          ),
      ],
      footnote: Padding(
        padding: const EdgeInsets.only(top: kStandingFootnoteGap),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: RecurringExpenseStatusPill(statusId: e.calculatedStatusId),
        ),
      ),
    );
  }
}
