import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/ui/core/widgets/party_money_cell.dart';
import 'package:admin/utils/formatting.dart';

/// Where a client stands: what they owe and what they have paid, always; a
/// credit or an unapplied payment only when there is one.
///
/// Balance is drawn in plain ink. It used to turn red whenever it was above
/// zero, which made a client invoiced yesterday on thirty-day terms look
/// delinquent — and on the invoice screen that same red means *past due*. Red
/// here is reserved for [footnote], which says what is actually late.
///
/// Each figure opens the tab that lists what it adds up, but only when that
/// tab exists: [tabIds] is the same set `ClientDetailTabs` gates its strip on,
/// so a figure is never drawn as a link to a tab the company has switched off.
///
/// Amounts go through `PartyCurrencyBuilder`, i.e. the client → group →
/// company cascade. Passing the client's own `currencyId` alone formats a
/// group-inheriting client in the company currency.
class ClientDetailStanding extends StatelessWidget {
  const ClientDetailStanding({
    super.key,
    required this.client,
    required this.formatter,
    required this.tabIds,
    required this.onOpenTab,
    this.footnoteBuilder,
  });

  final Client client;

  /// Null while it loads — the figures are blank until it arrives.
  final Formatter? formatter;
  final Set<String> tabIds;
  final ValueChanged<String> onOpenTab;

  /// The line under the primary figures — the past-due summary. Handed the
  /// same money formatter the figures use, so it cannot print the client's
  /// balance in one currency and its late part in another. Null, or a builder
  /// that returns null, draws no line.
  final Widget? Function(BuildContext context, String Function(Decimal) money)?
  footnoteBuilder;

  @override
  Widget build(BuildContext context) {
    return PartyCurrencyBuilder(
      clientId: client.id,
      builder: (context, currencyId) {
        String money(Decimal amount) =>
            formatter?.money(
              amount,
              clientCurrencyId: currencyId ?? client.currencyId,
            ) ??
            '';
        StandingFigure figure(String labelKey, Decimal amount, String tabId) {
          final linked = tabIds.contains(tabId);
          return StandingFigure(
            label: context.tr(labelKey),
            value: money(amount),
            onTap: linked ? () => onOpenTab(tabId) : null,
            // The tab's own name: "Invoices", "Payments".
            semanticsHint: linked ? context.tr(tabId) : null,
          );
        }

        final paymentBalance = client.paymentBalance ?? Decimal.zero;
        return StandingCard(
          primary: [
            figure('balance', client.balance, DetailTabIds.invoices),
            figure('paid_to_date', client.paidToDate, DetailTabIds.payments),
          ],
          // `!=`, never `>`: a negative balance is unusual and exactly the
          // one a user needs to see.
          secondary: [
            if (client.creditBalance != Decimal.zero)
              figure(
                'credit_balance',
                client.creditBalance,
                DetailTabIds.credits,
              ),
            if (paymentBalance != Decimal.zero)
              figure('payment_balance', paymentBalance, DetailTabIds.payments),
          ],
          // Not while the formatter is loading: the figures above are blank
          // then, and a line reading "Past Due: " would not be.
          footnote: formatter == null
              ? null
              : footnoteBuilder?.call(context, money),
        );
      },
    );
  }
}
