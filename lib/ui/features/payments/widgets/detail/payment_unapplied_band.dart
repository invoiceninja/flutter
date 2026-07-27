import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/utils/formatting.dart';

/// Inline callout shown on the payment detail screen when `amount > applied`.
/// Offers one action — Auto-apply oldest: one-tap allocation of the unapplied
/// amount against the client's oldest unpaid invoice (looks up via
/// [services.invoices]). An explicit "apply to a chosen invoice" picker is not
/// yet implemented; until then, allocating to a specific invoice happens on
/// the create form's allocations section.
class PaymentUnappliedBand extends StatelessWidget {
  const PaymentUnappliedBand({
    super.key,
    required this.payment,
    this.formatter,
  });

  final Payment payment;
  final Formatter? formatter;

  @override
  Widget build(BuildContext context) {
    if (!payment.hasUnappliedFunds) return const SizedBox.shrink();
    final tokens = context.inTheme;
    final f = formatter;
    final unappliedText = f == null
        ? payment.unapplied.toString()
        : f.money(payment.unapplied, clientCurrencyId: payment.currencyId);

    return Container(
      margin: EdgeInsets.only(top: InSpacing.md(context)),
      padding: EdgeInsets.all(InSpacing.lg(context)),
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        borderRadius: BorderRadius.circular(InRadii.r3),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_outlined, color: tokens.ink),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('unapplied_funds'),
                  style: TextStyle(
                    color: tokens.ink3,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unappliedText,
                  style: moneyTextStyle(
                    color: tokens.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: payment.id.startsWith('tmp_')
                ? null
                : () => _autoApplyOldest(context, payment),
            child: Text(context.tr('auto_apply_oldest')),
          ),
        ],
      ),
    );
  }
}

Future<void> _autoApplyOldest(BuildContext context, Payment payment) async {
  final services = context.read<Services>();
  final companyId = services.auth.session.value!.currentCompanyId;
  // Make sure the client's invoices are in Drift before we read the local
  // cache. Without this, a user landing on the payment detail screen
  // before ever opening the invoices list would see "no unpaid invoices"
  // even when the server has plenty.
  await services.invoices.ensurePageLoaded(
    companyId: companyId,
    page: 1,
    extraFilters: {
      'client_id': {payment.clientId},
    },
  );
  final invoices = await services.invoices
      .watchForClient(companyId: companyId, clientId: payment.clientId)
      .first;
  // Drafts and archived invoices are NOT auto-apply targets: the server's
  // `applyPayment` calls `markSent()` first, so auto-applying to a draft would
  // silently send AND pay it. Mirrors the manual picker's filter in
  // `payment_allocations_section.dart`.
  final candidates =
      invoices
          .where(
            (i) =>
                i.balance > Decimal.zero &&
                !i.isDeleted &&
                !i.isDraft &&
                i.archivedAt == null,
          )
          .toList()
        ..sort((a, b) {
          final ad = a.date?.toIso() ?? '';
          final bd = b.date?.toIso() ?? '';
          return ad.compareTo(bd);
        });
  if (candidates.isEmpty) {
    if (context.mounted) {
      Notify.error(context, context.tr('no_unpaid_invoices'));
    }
    return;
  }
  final target = candidates.first;
  final allocation = payment.unapplied < target.balance
      ? payment.unapplied
      : target.balance;
  await services.payments.apply(
    companyId: companyId,
    paymentId: payment.id,
    allocations: [
      // `_id` is a client-row identifier the server ignores (React sends a
      // fresh uuid here); `invoice_id` + `amount` are the fields it reads.
      <String, dynamic>{
        '_id': const Uuid().v4(),
        'invoice_id': target.id,
        'amount': allocation.toString(),
      },
    ],
  );
  if (context.mounted) {
    Notify.success(context, context.tr('applied_payment'));
  }
}
