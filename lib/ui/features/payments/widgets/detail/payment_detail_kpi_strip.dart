import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/ui/core/detail/kpi_strip_layout.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// Full-width KPI strip at the top of the payment Overview tab.
/// Cells: amount / applied, plus refunded / refundable once a refund exists.
/// "Unapplied" lives in a dedicated inline band below the strip (visible only
/// when there's a non-zero unapplied amount).
///
/// The refund pair is gated on [PaymentStatusExt.hasRefund] because a zero
/// there is the overwhelming default, and the *label* was the distraction —
/// people read the word "Refunded" on a payment they just recorded and
/// double-took before their eye reached the `0.00` (invoiceninja/flutter#113).
/// Refundable leaves with it: it is `amount - refunded`, so with no refund it
/// reprints Amount two cells away — on a payment the Refund action often won't
/// even offer, since that is gated on `canRefund` **and**
/// `hasInvoiceAllocations` (`payment_actions.dart`), not on `canRefund` alone.
class PaymentDetailKpiStrip extends StatelessWidget {
  const PaymentDetailKpiStrip({
    super.key,
    required this.payment,
    required this.formatter,
  });

  final Payment payment;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final p = payment;
    final f = formatter;

    String fmt(Decimal value) => f == null
        ? value.toString()
        : f.money(value, clientCurrencyId: p.currencyId);

    final cells = <Widget>[
      _KpiCell(
        label: context.tr('amount'),
        value: Text(
          fmt(p.amount),
          style: theme.textTheme.titleLarge
              ?.copyWith(color: tokens.ink, fontWeight: FontWeight.w600)
              .merge(moneyTextStyle()),
        ),
        tokens: tokens,
      ),
      _KpiCell(
        label: context.tr('applied'),
        value: Text(
          fmt(p.applied),
          style: theme.textTheme.titleLarge
              ?.copyWith(color: tokens.ink, fontWeight: FontWeight.w600)
              .merge(moneyTextStyle()),
        ),
        tokens: tokens,
      ),
      if (p.hasRefund) ...[
        _KpiCell(
          label: context.tr('refunded'),
          value: Text(
            fmt(p.refunded),
            style: theme.textTheme.titleLarge
                ?.copyWith(color: tokens.ink, fontWeight: FontWeight.w600)
                .merge(moneyTextStyle()),
          ),
          tokens: tokens,
        ),
        _KpiCell(
          label: context.tr('refundable'),
          value: Text(
            fmt(p.refundable),
            style: theme.textTheme.titleLarge
                ?.copyWith(color: tokens.ink, fontWeight: FontWeight.w600)
                .merge(moneyTextStyle()),
          ),
          tokens: tokens,
        ),
      ],
    ];

    return DashboardCardShell(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.lg(context),
      ),
      child: KpiStripLayout(cells: cells),
    );
  }
}

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.label,
    required this.value,
    required this.tokens,
  });

  final String label;
  final Widget value;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: tokens.ink3,
            fontWeight: FontWeight.w600,
            fontSize: 11,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        value,
      ],
    );
  }
}
