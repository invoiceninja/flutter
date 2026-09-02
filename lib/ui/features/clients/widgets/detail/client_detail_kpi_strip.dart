import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/ui/core/detail/kpi_strip_layout.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/dashboard/widgets/card_shell.dart';
import 'package:admin/utils/formatting.dart';

/// Full-width KPI strip at the top of the client detail body — the page's
/// most important numbers (paid_to_date, balance, credit_balance, and the
/// placeholder payment_balance) pulled up to where the eye lands.
///
/// Layout switches at 1100 px:
/// - ≥1100 px: a single row of four cells separated by 1 px vertical dividers.
/// - <1100 px: a 2×2 grid (same pattern the old "Standing" card used).
///
/// Balance highlights `overdue` when positive — same affordance the old
/// Standing card had.
class ClientDetailKpiStrip extends StatelessWidget {
  const ClientDetailKpiStrip({
    super.key,
    required this.client,
    required this.formatter,
  });

  final Client client;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final cells = [
      _KpiCell(
        label: context.tr('paid_to_date'),
        amount: client.paidToDate,
        tokens: tokens,
        formatter: formatter,
        currencyId: client.currencyId,
      ),
      _KpiCell(
        label: context.tr('balance'),
        amount: client.balance,
        tokens: tokens,
        formatter: formatter,
        currencyId: client.currencyId,
        highlightWhenPositive: tokens.overdue,
      ),
      _KpiCell(
        label: context.tr('credit_balance'),
        amount: client.creditBalance,
        tokens: tokens,
        formatter: formatter,
        currencyId: client.currencyId,
      ),
      _KpiCell(
        label: context.tr('payment_balance'),
        amount: client.paymentBalance,
        tokens: tokens,
        formatter: formatter,
        currencyId: client.currencyId,
      ),
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
    required this.amount,
    required this.tokens,
    required this.formatter,
    required this.currencyId,
    this.highlightWhenPositive,
  });

  final String label;

  /// Null means "not yet wired" — rendered as `—`.
  final Decimal? amount;
  final InTheme tokens;
  final Formatter? formatter;
  final String currencyId;
  final Color? highlightWhenPositive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = this.amount;
    final isZero = amount == null || amount == Decimal.zero;
    final formatted = amount == null
        ? ''
        : (formatter?.money(amount, clientCurrencyId: currencyId) ?? '');
    final value = (isZero || formatted.isEmpty) ? '—' : formatted;
    final valueColor = isZero
        ? tokens.ink3
        : (highlightWhenPositive != null && amount > Decimal.zero
              ? highlightWhenPositive!
              : tokens.ink);
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
        Text(
          value,
          // Each cell is an Expanded slot (1 row wide / 2×2 grid narrow); a
          // long amount (big balance in a wide currency) must ellipsize, not
          // wrap to a second line and shove the strip taller on a phone.
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge
              ?.copyWith(color: valueColor, fontWeight: FontWeight.w600)
              .merge(moneyTextStyle()),
        ),
      ],
    );
  }
}
