import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Action set surfaced for a payment. Apply intentionally lives inline on the
/// detail screen (not the action menu) since it's a one-tap/two-tap flow.
/// Refund opens a dedicated sub-route at `/payments/:id/refund`.
enum PaymentAction {
  edit,
  refund,
  sendEmail,
  addComment,
  archive,
  restore,
  delete,
}

class PaymentActions {
  PaymentActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops archive /
  /// restore / delete.
  static bool isLifecycle(PaymentAction action) {
    switch (action) {
      case PaymentAction.archive:
      case PaymentAction.restore:
      case PaymentAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// After-save actions whose [dispatch] navigates unconditionally; the
  /// create-mode edit scaffold uses this to keep that navigation instead of
  /// redirecting to the detail screen. See `InvoiceActions.navigatesOnCreate`.
  static bool navigatesOnCreate(PaymentAction action) {
    switch (action) {
      case PaymentAction.refund:
        return true;
      default:
        return false;
    }
  }

  static List<EntityActionItem<PaymentAction>> itemsFor(
    BuildContext context,
    Payment payment,
    void Function(PaymentAction) onTap,
  ) {
    final canArchive = payment.archivedAt == null && !payment.isDeleted;
    final canRestore = payment.archivedAt != null || payment.isDeleted;

    return [
      editActionItem(
        context: context,
        kind: PaymentAction.edit,
        onTap: () => onTap(PaymentAction.edit),
      ),
      EntityActionItem(
        kind: PaymentAction.refund,
        icon: Icons.replay_outlined,
        label: context.tr('refund_payment'),
        // Only offer Refund when there's an invoice allocation to refund
        // against — the refund screen has no client-account-refund path
        // (matches React), so an unapplied payment would dead-end.
        enabled: payment.canRefund && payment.hasInvoiceAllocations,
        onTap: () => onTap(PaymentAction.refund),
      ),
      EntityActionItem(
        kind: PaymentAction.sendEmail,
        icon: Icons.mail_outline,
        label: context.tr('send_email'),
        enabled: !payment.isDeleted,
        onTap: () => onTap(PaymentAction.sendEmail),
      ),
      EntityActionItem(
        kind: PaymentAction.addComment,
        icon: Icons.chat_bubble_outline,
        label: context.tr('add_comment'),
        enabled: true,
        onTap: () => onTap(PaymentAction.addComment),
      ),
      ?archiveActionItem(
        context: context,
        kind: PaymentAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(PaymentAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: PaymentAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(PaymentAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        kind: PaymentAction.delete,
        canDelete: !payment.isDeleted,
        onTap: () => onTap(PaymentAction.delete),
      ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    Payment payment,
    PaymentAction action,
  ) async {
    switch (action) {
      case PaymentAction.edit:
        goEntityEdit(context, '/payments', payment.id);
      case PaymentAction.refund:
        if (!requireSynced(context, payment.id)) return;
        context.go('/payments/${payment.id}/refund');
      case PaymentAction.sendEmail:
        // Re-save with sendEmail=true so the server fires off a receipt. The
        // outbox handles the round-trip; no extra endpoint needed.
        await services.payments.save(
          companyId: companyId,
          payment: payment,
          sendEmail: true,
        );
        if (context.mounted) {
          Notify.success(context, context.tr('emailed_payment'));
        }
      case PaymentAction.addComment:
        await _promptAddComment(context, services, companyId, payment);
      case PaymentAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'payment',
          op: () =>
              services.payments.archive(companyId: companyId, id: payment.id),
          undoOp: () =>
              services.payments.restore(companyId: companyId, id: payment.id),
        );
      case PaymentAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'payment',
          op: () =>
              services.payments.restore(companyId: companyId, id: payment.id),
        );
      case PaymentAction.delete:
        if (!requireSynced(context, payment.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'payment',
          op: () =>
              services.payments.delete(companyId: companyId, id: payment.id),
          undoOp: () =>
              services.payments.restore(companyId: companyId, id: payment.id),
        );
    }
  }
}

Future<void> _promptAddComment(
  BuildContext context,
  Services services,
  String companyId,
  Payment payment,
) async {
  final controller = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(ctx.tr('add_comment')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: ctx.tr('notes')),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(ctx.tr('cancel')),
              ),
              const SizedBox(width: 8),
              PrimaryDialogAction(
                label: ctx.tr('save'),
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                autofocus: false,
                showEnterHint: false,
              ),
            ],
          ),
        ],
      );
    },
  );
  if (text == null || text.isEmpty) return;
  await services.payments.addComment(
    companyId: companyId,
    paymentId: payment.id,
    text: text,
  );
}
