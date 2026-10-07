import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standing_card.dart';
import 'package:admin/utils/formatting.dart';

/// Where a payment stands: what came in and how much of it has been put
/// against something, always; what is still unapplied or has gone back, only
/// when there is some.
///
/// It replaces the KPI strip and the "Unapplied funds" band under it, which
/// between them printed the unapplied amount in a callout of its own and the
/// word "Refunded" over `0.00` on a payment recorded a minute ago — the label
/// was the alarm, read before the eye reached the value
/// (invoiceninja/flutter#113).
///
/// **Refunded is `!= zero`, never `> zero`** ([PaymentStatusExt.hasRefund]): a
/// negative figure is an anomaly, and exactly the one a user needs to see.
/// Refundable is gone — it is `amount - refunded`, two cells from both.
///
/// Applied opens the tab that lists what it adds up, when that tab is there.
class PaymentDetailStanding extends StatelessWidget {
  const PaymentDetailStanding({
    super.key,
    required this.payment,
    required this.formatter,
    this.onOpenApplied,
  });

  final Payment payment;

  /// Null while it loads — the figures are blank until it arrives.
  final Formatter? formatter;

  /// Opens the Invoices tab. Null draws Applied as a plain figure.
  final VoidCallback? onOpenApplied;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    String money(Decimal amount) =>
        formatter?.money(amount, clientCurrencyId: p.currencyId) ?? '';
    return StandingCard(
      primary: [
        StandingFigure(label: context.tr('amount'), value: money(p.amount)),
        StandingFigure(
          label: context.tr('applied'),
          value: money(p.applied),
          onTap: onOpenApplied,
          semanticsHint: onOpenApplied == null ? null : context.tr('invoices'),
        ),
      ],
      secondary: [
        if (p.unapplied != Decimal.zero)
          StandingFigure(
            label: context.tr('unapplied'),
            value: money(p.unapplied),
          ),
        if (p.hasRefund)
          // Plain ink: a refund is a fact about the payment, not an alarm.
          StandingFigure(
            label: context.tr('refunded'),
            value: money(p.refunded),
          ),
      ],
    );
  }
}
