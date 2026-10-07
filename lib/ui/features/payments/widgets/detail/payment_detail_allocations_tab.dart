import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/utils/formatting.dart';

/// One thing a payment was put against: an invoice it paid, or a credit that
/// was used alongside it.
@immutable
class PaymentAllocation {
  const PaymentAllocation({
    required this.type,
    required this.id,
    required this.number,
    required this.amount,
    required this.refunded,
  });

  /// [EntityType.invoice] or [EntityType.credit].
  final EntityType type;
  final String id;

  /// Empty when the payment's own payload does not name it.
  final String number;
  final Decimal amount;
  final Decimal refunded;
}

/// What [payment] was applied to, in the order the server lists it.
///
/// From the payment's own payload — `paymentables` for the amounts, the
/// `invoices` / `credits` includes for the numbers — so it needs no request
/// and the count on the tab is exact.
List<PaymentAllocation> paymentAllocationsOf(Payment payment) {
  final invoiceNumbers = {for (final i in payment.invoices) i.id: i.number};
  final creditNumbers = {for (final c in payment.credits) c.id: c.number};
  return [
    for (final pa in payment.paymentables)
      if (pa.invoiceId.isNotEmpty)
        PaymentAllocation(
          type: EntityType.invoice,
          id: pa.invoiceId,
          number: invoiceNumbers[pa.invoiceId] ?? '',
          amount: pa.amount,
          refunded: pa.refunded,
        )
      else if (pa.creditId.isNotEmpty)
        PaymentAllocation(
          type: EntityType.credit,
          id: pa.creditId,
          number: creditNumbers[pa.creditId] ?? '',
          amount: pa.amount,
          refunded: pa.refunded,
        ),
  ];
}

/// The Invoices tab on a payment: every invoice (and credit) it was applied
/// to, with how much.
///
/// The old screen showed "Applied $500.00" and no way to find out to what —
/// the allocations were only listed on the refund screen.
///
/// A row is the link to its record when the user may open it; the amount is
/// what this payment put against it, with whatever of that has since been
/// refunded on a second line.
class PaymentDetailAllocationsTab extends StatelessWidget {
  const PaymentDetailAllocationsTab({
    super.key,
    required this.payment,
    required this.formatter,
  });

  final Payment payment;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    final rows = paymentAllocationsOf(payment);
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: InSpacing.lg(context)),
        child: EmptyStateBody(
          icon: Icons.receipt_long_outlined,
          title: context.tr('no_invoices_found'),
        ),
      );
    }
    final tokens = context.inTheme;
    final me = context.read<Services>().auth.session.value?.currentCompany;
    bool canOpen(EntityType type) =>
        (me?.moduleEnabled(type) ?? false) &&
        (me?.can(type == EntityType.invoice ? 'view_invoice' : 'view_credit') ??
            false);
    String money(Decimal amount) =>
        formatter?.money(amount, clientCurrencyId: payment.currencyId) ?? '';
    return Padding(
      padding: EdgeInsets.only(top: InSpacing.md(context)),
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(InRadii.r3),
          border: Border.all(color: tokens.border),
          boxShadow: tokens.shadow1,
        ),
        clipBehavior: Clip.antiAlias,
        // The colour is painted by this `Material`, so the rows' ink shows.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: tokens.border),
                _AllocationRow(
                  allocation: rows[i],
                  amount: money(rows[i].amount),
                  refunded: rows[i].refunded == Decimal.zero
                      ? null
                      : money(rows[i].refunded),
                  onTap: canOpen(rows[i].type)
                      ? () => goEntityFullDetail(
                          context,
                          rows[i].type == EntityType.invoice
                              ? '/invoices'
                              : '/credits',
                          rows[i].id,
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AllocationRow extends StatelessWidget {
  const _AllocationRow({
    required this.allocation,
    required this.amount,
    required this.refunded,
    required this.onTap,
  });

  final PaymentAllocation allocation;
  final String amount;

  /// Null when nothing of this allocation has been refunded.
  final String? refunded;

  /// Null draws a plain row — the user may not open the record.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final isInvoice = allocation.type == EntityType.invoice;
    final kind = context.tr(isInvoice ? 'invoice' : 'credit');
    final title = allocation.number.isEmpty
        ? kind
        : '$kind #${allocation.number}';
    final row = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 40,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.lg(context),
          vertical: InSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(
              isInvoice
                  ? Icons.receipt_long_outlined
                  : Icons.credit_card_outlined,
              size: 18,
              color: tokens.ink2,
            ),
            const SizedBox(width: InSpacing.sm),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: onTap == null ? tokens.ink : tokens.accentInk,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: InSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  amount,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: tokens.ink, fontWeight: FontWeight.w600)
                      .merge(moneyTextStyle()),
                ),
                if (refunded != null)
                  Text(
                    '${context.tr('refunded')}: $refunded',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: tokens.ink2,
                    ),
                  ),
              ],
            ),
            if (onTap != null) ...[
              const SizedBox(width: InSpacing.xs),
              Icon(Icons.chevron_right, size: 18, color: tokens.ink3),
            ],
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$title $amount',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
