import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/utils/formatting.dart';

/// What a payment link charges.
///
/// The price is not a field anyone types — the server derives it from the
/// link's products — which is exactly why it earns the card: it is the one
/// figure the edit screen cannot show. A real zero is printed (a free plan is
/// a price too).
class PaymentLinkDetailStanding extends StatelessWidget {
  const PaymentLinkDetailStanding({
    super.key,
    required this.paymentLink,
    required this.formatter,
  });

  final PaymentLink paymentLink;

  /// Null while it loads — the figure is blank until it arrives.
  final Formatter? formatter;

  /// The link's price in its own currency, or the company's when it names
  /// none. Empty until the formatter is here.
  static String priceText(PaymentLink link, Formatter? formatter) =>
      formatMoney(link.price, link, formatter);

  static String formatMoney(
    Decimal amount,
    PaymentLink link,
    Formatter? formatter,
  ) =>
      formatter?.money(
        amount,
        currencyId: link.currencyId.isEmpty ? null : link.currencyId,
      ) ??
      '';

  @override
  Widget build(BuildContext context) {
    return StandingCard(
      primary: [
        StandingFigure(
          label: context.tr('price'),
          value: priceText(paymentLink, formatter),
        ),
      ],
    );
  }
}
