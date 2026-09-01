import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';

/// Invoice-detail tab: the client's payments that still have **unapplied
/// funds**, with a one-tap "Apply" that allocates min(unapplied, balance) to
/// *this* invoice. Pure view + reuse of the existing `payments.apply`
/// pipeline — no new endpoint. Tapping a row opens the payment record.
class InvoiceUnappliedPaymentsSection extends StatelessWidget {
  const InvoiceUnappliedPaymentsSection({
    required this.invoice,
    required this.services,
    required this.companyId,
    super.key,
  });

  final Invoice invoice;
  final Services services;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    return WatchBuilder<List<Payment>>(
      cacheKey: (companyId, invoice.clientId),
      create: () => services.payments.watchForClient(
        companyId: companyId,
        clientId: invoice.clientId,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final payments = snapshot.data!
            .where((p) => p.hasUnappliedFunds && !p.isDeleted)
            .toList();
        if (payments.isEmpty) {
          return EmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: context.tr('no_unapplied_payments'),
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < payments.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _UnappliedPaymentRow(
                payment: payments[i],
                invoice: invoice,
                services: services,
                companyId: companyId,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _UnappliedPaymentRow extends StatelessWidget {
  const _UnappliedPaymentRow({
    required this.payment,
    required this.invoice,
    required this.services,
    required this.companyId,
  });

  final Payment payment;
  final Invoice invoice;
  final Services services;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final f = services.formatterIfReady(companyId);
    final unapplied = f == null ? '—' : f.money(payment.unapplied);
    final canApply =
        invoice.balance > Decimal.zero &&
        !invoice.isPaid &&
        !invoice.isCancelled;
    return ListTile(
      leading: Icon(Icons.account_balance_wallet_outlined, color: tokens.ink2),
      title: Text('#${payment.number}'),
      subtitle: Text(
        '${context.tr('unapplied')}: $unapplied',
        style: TextStyle(color: tokens.ink3),
      ),
      trailing: canApply
          ? FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => _apply(context),
              child: Text(context.tr('apply_payment')),
            )
          : null,
      onTap: () => goEntityRecord(context, EntityType.payment, payment.id),
    );
  }

  Future<void> _apply(BuildContext context) async {
    final toasts = Notify.capture(context);
    final tr = context.tr;
    final amount = payment.unapplied < invoice.balance
        ? payment.unapplied
        : invoice.balance;
    try {
      await services.payments.apply(
        companyId: companyId,
        paymentId: payment.id,
        allocations: [
          // `_id` is a client-row identifier the server ignores (React sends a
          // fresh uuid here); `invoice_id` + `amount` are the fields it reads.
          <String, dynamic>{
            '_id': const Uuid().v4(),
            'invoice_id': invoice.id,
            'amount': amount.toString(),
          },
        ],
      );
      toasts?.success(tr('applied_payment'));
    } catch (_) {
      if (context.mounted) {
        Notify.error(context, tr('an_error_occurred'));
      }
    }
  }
}
