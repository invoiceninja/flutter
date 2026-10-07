import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/bank_transaction.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/transaction_rule_matched_chip.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_status_pill.dart';
import 'package:admin/utils/formatting.dart';

/// The transaction's amount with its sign, formatted through the central
/// [Formatter] (symbol / code, separators, precision). Empty while the
/// formatter is still loading — the standing card draws that as a blank line
/// of the right height.
///
/// A currency the statics do not hold formats to nothing; then it is the raw
/// fixed-2 figure behind the bare currency id, so the amount is never blank
/// once the formatter is here.
String transactionAmountText(BankTransaction tx, Formatter? formatter) {
  if (formatter == null) return '';
  final sign = tx.isWithdrawal ? '-' : '+';
  final formatted = formatter.money(tx.amount, currencyId: tx.currencyId);
  final body = formatted.isNotEmpty
      ? formatted
      : '${tx.currencyId.isEmpty ? '' : '${tx.currencyId} '}'
            '${tx.amount.toStringAsFixed(2)}';
  return '$sign$body';
}

/// Where a transaction stands: how much moved and which way, and whether it
/// has been accounted for yet.
///
/// The caption is the direction ("Deposit" / "Withdrawal") rather than
/// "Amount", so the figure says both things at once. Money in is drawn in the
/// paid tone and money out in the overdue tone — the convention of a bank
/// statement, and the same pair the list row uses.
///
/// The status rides under the figure, with the rule that matched it when
/// there was one: "why was this categorized?" is a question about where the
/// transaction stands, not about what it is.
class TransactionDetailStanding extends StatelessWidget {
  const TransactionDetailStanding({
    super.key,
    required this.transaction,
    required this.formatter,
  });

  final BankTransaction transaction;

  /// Null while it loads — the figure is blank until it arrives.
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final tx = transaction;
    final byRule =
        tx.transactionRuleId.isNotEmpty && (tx.isMatched || tx.isConverted);
    return StandingCard(
      primary: [
        StandingFigure(
          label: context.tr(tx.isWithdrawal ? 'withdrawal' : 'deposit'),
          value: transactionAmountText(tx, formatter),
          valueColor: tx.isWithdrawal ? tokens.overdue : tokens.paid,
        ),
      ],
      // Owns its leading gap, as a footnote must.
      footnote: Padding(
        padding: const EdgeInsets.only(top: kStandingFootnoteGap),
        child: Wrap(
          spacing: InSpacing.sm,
          runSpacing: InSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TransactionStatusPill(statusId: tx.statusId),
            if (byRule)
              TransactionRuleMatchedChip(
                transactionRuleId: tx.transactionRuleId,
              ),
          ],
        ),
      ),
    );
  }
}
