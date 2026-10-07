import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/bank_account.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/utils/formatting.dart';

/// The account's balance as the provider last reported it, in the account's
/// own currency.
///
/// A bank account carries a currency **code** ("EUR"), not one of the app's
/// currency ids, so it is matched against the statics by code. A code the
/// statics do not hold is printed as it came — "XYZ 120.50" — rather than
/// formatted as if it were the company's currency.
///
/// Empty while the formatter is still loading: the standing card draws that
/// as a blank line of the right height, never as a dash.
String bankAccountBalanceText(BankAccount account, Formatter? formatter) {
  if (formatter == null) return '';
  String? currencyId;
  if (account.currency.isNotEmpty) {
    final code = account.currency.toUpperCase();
    for (final entry in formatter.currencies.entries) {
      if (entry.value.code.toUpperCase() == code) {
        currencyId = entry.key;
        break;
      }
    }
    if (currencyId == null) return '${account.currency} ${account.balance}';
  }
  final formatted = formatter.money(account.balance, currencyId: currencyId);
  return formatted.isNotEmpty ? formatted : '${account.balance}';
}

/// Where a bank account stands: its balance. A real zero is printed — on this
/// card `$0.00` is the answer.
///
/// One figure, because the provider reports one: there is no "last synced"
/// on the wire to put beside it.
class BankAccountDetailStanding extends StatelessWidget {
  const BankAccountDetailStanding({
    super.key,
    required this.account,
    required this.formatter,
    this.onOpenTransactions,
  });

  final BankAccount account;

  /// Null while it loads — the figure is blank until it arrives.
  final Formatter? formatter;

  /// Opens the Transactions tab. Null draws a plain figure.
  final VoidCallback? onOpenTransactions;

  @override
  Widget build(BuildContext context) {
    return StandingCard(
      primary: [
        StandingFigure(
          label: context.tr('balance'),
          value: bankAccountBalanceText(account, formatter),
          onTap: onOpenTransactions,
          semanticsHint: onOpenTransactions == null
              ? null
              : context.tr('transactions'),
        ),
      ],
    );
  }
}
