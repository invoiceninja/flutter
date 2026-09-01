import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/utils/formatting.dart';

/// Read-only list of the payments applied to this invoice — each with the
/// amount it allocated (the matching `paymentables` entry) and its date.
/// Streams via `payments.watchForInvoice`, which filters on the `paymentables`
/// JSON in Drift. Renders nothing when no payment has been applied, so the
/// invoice Overview only shows the section when it has content. Tapping a row
/// opens the payment record.
class InvoiceAppliedPaymentsSection extends StatelessWidget {
  const InvoiceAppliedPaymentsSection({
    required this.invoice,
    required this.services,
    required this.companyId,
    this.formatter,
    this.currencyId,
    super.key,
  });

  final Invoice invoice;
  final Services services;
  final String companyId;
  final Formatter? formatter;
  final String? currencyId;

  @override
  Widget build(BuildContext context) {
    return WatchBuilder<List<Payment>>(
      cacheKey: (companyId, invoice.id),
      create: () => services.payments.watchForInvoice(
        companyId: companyId,
        invoiceId: invoice.id,
      ),
      builder: (context, snapshot) {
        final payments = (snapshot.data ?? const <Payment>[])
            .where((p) => !p.isDeleted)
            .toList(growable: false);
        if (payments.isEmpty) return const SizedBox.shrink();
        final tokens = context.inTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('payments'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tokens.ink3,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: tokens.border),
                borderRadius: BorderRadius.circular(InRadii.r3),
                color: tokens.surface,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < payments.length; i++)
                    _AppliedRow(
                      payment: payments[i],
                      invoiceId: invoice.id,
                      isLast: i == payments.length - 1,
                      formatter: formatter,
                      currencyId: currencyId,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AppliedRow extends StatelessWidget {
  const _AppliedRow({
    required this.payment,
    required this.invoiceId,
    required this.isLast,
    this.formatter,
    this.currencyId,
  });

  final Payment payment;
  final String invoiceId;
  final bool isLast;
  final Formatter? formatter;
  final String? currencyId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Net of refunds. A refund leaves `paymentable.amount` untouched and
    // accrues into `paymentable.refunded` (`RefundPayment::updatePaymentables`)
    // while decrementing the invoice's `paid_to_date`, so summing the gross
    // showed a figure that didn't reconcile with the Paid-to-date / Balance
    // card directly above it. The refund screen already nets the same way.
    final applied = payment.paymentables
        .where((p) => p.invoiceId == invoiceId)
        .fold<Decimal>(Decimal.zero, (sum, p) => sum + (p.amount - p.refunded));
    final appliedText =
        formatter?.money(applied, clientCurrencyId: currencyId) ??
        applied.toString();
    final dateText = payment.date != null
        ? (formatter?.date(payment.date!.toIso()) ?? payment.date!.toIso())
        : '';
    final number = payment.number.isEmpty
        ? context.tr('payment')
        : '#${payment.number}';
    return InkWell(
      onTap: () => goEntityRecord(context, EntityType.payment, payment.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: isLast
            ? null
            : BoxDecoration(
                border: Border(bottom: BorderSide(color: tokens.border)),
              ),
        child: Row(
          children: [
            Icon(Icons.payments_outlined, size: 16, color: tokens.ink2),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    number,
                    style: TextStyle(color: tokens.ink, fontSize: 13),
                  ),
                  if (dateText.isNotEmpty)
                    Text(
                      dateText,
                      style: TextStyle(color: tokens.ink3, fontSize: 11.5),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              appliedText,
              style: moneyTextStyle(
                color: tokens.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
