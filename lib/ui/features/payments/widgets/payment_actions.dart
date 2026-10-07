import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/email/recipient_email_fix.dart';
import 'package:admin/ui/features/payments/widgets/payment_apply.dart';

/// Action set surfaced for a payment. Refund opens a dedicated sub-route at
/// `/payments/:id/refund`.
enum PaymentAction {
  edit,

  /// Quick-action strip only — see [PaymentActions.quickItemsFor]. Not in
  /// [PaymentActions.itemsFor], so it reaches neither the `⋮` menu, the list
  /// row's menu, nor the edit screen (where an action with no save param runs
  /// *after* a save the user did not ask for).
  apply,
  refund,
  sendEmail,
  addComment,
  logCall,
  viewClient,
  copyLink,
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

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(Payment payment) =>
      payment.number.isEmpty ? '' : '#${payment.number}';

  static List<EntityActionItem<PaymentAction>> itemsFor(
    BuildContext context,
    Payment payment,
    void Function(PaymentAction) onTap,
  ) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    // Permission gate, matching the linked name in the record's header.
    // Read lazily here (itemsFor runs per build) so it re-resolves on a
    // company switch.
    final canViewClient = me?.can('view_client') ?? false;
    // Archive, restore and delete all need `edit_payment`: the server
    // authorizes each through `EntityPolicy::edit` (there is no `delete_*`
    // permission). Ungated, a view-only user was offered Restore — one tap
    // from the record's state banner — for a mutation the server refuses.
    // The server's rule, not just the permission: the record's creator or
    // assignee may change it too (`AuthSession.canEditRecord`).
    final canEditPayment =
        context.read<Services>().auth.session.value?.canEditRecord(
          'payment',
          createdBy: payment.userId,
          assignedTo: payment.assignedUserId,
          recordId: payment.id,
        ) ??
        false;
    final canArchive =
        canEditPayment && payment.archivedAt == null && !payment.isDeleted;
    final canRestore =
        canEditPayment && (payment.archivedAt != null || payment.isDeleted);
    // `RefundPaymentRequest::authorize` is `isAdmin()` and nothing else, so
    // edit rights do not buy a refund.
    final isAdminOrOwner = (me?.isAdmin ?? false) || (me?.isOwner ?? false);

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
        enabled:
            isAdminOrOwner &&
            payment.canRefund &&
            payment.hasInvoiceAllocations,
        onTap: () => onTap(PaymentAction.refund),
      ),
      EntityActionItem(
        kind: PaymentAction.sendEmail,
        confirm: true,
        confirmSubject: _confirmSubject(payment),
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
      EntityActionItem(
        kind: PaymentAction.logCall,
        icon: Icons.phone_in_talk_outlined,
        label: context.tr('log_call'),
        enabled: true,
        onTap: () => onTap(PaymentAction.logCall),
      ),
      if (payment.clientId.isNotEmpty && canViewClient)
        EntityActionItem(
          kind: PaymentAction.viewClient,
          icon: Icons.person_outline,
          label: context.tr('view_client'),
          enabled: true,
          // Navigation only — must not reach the edit screen, where
          // `EntityEditScaffold._onAction` would save the dirty form (or
          // create the record) before dispatching it.
          isNavigationOnly: true,
          onTap: () => onTap(PaymentAction.viewClient),
        ),
      ?copyLinkActionItem(
        context: context,
        kind: PaymentAction.copyLink,
        entityId: payment.id,
        onTap: () => onTap(PaymentAction.copyLink),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(payment),
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
        subject: _confirmSubject(payment),
        kind: PaymentAction.delete,
        // The server refuses while a linked invoice is deleted
        // (`deleted_invoices_exist`) — a queued delete would only dead-letter.
        canDelete:
            canEditPayment && !payment.isDeleted && !payment.hasDeletedInvoice,
        onTap: () => onTap(PaymentAction.delete),
      ),
    ];
  }

  /// The record screen's quick-action tiles, most-used first: put the
  /// unapplied money somewhere, send the receipt, refund, open the client.
  ///
  /// Each tile is a second render of an action the record already has, so
  /// gating and the confirmation prompt stay on the item — except Apply, which
  /// exists only here (see [PaymentAction.apply]).
  static List<EntityQuickAction<PaymentAction>> quickItemsFor(
    BuildContext context,
    Payment payment,
    void Function(PaymentAction) onTap,
  ) {
    // A deleted payment is read-only, and an unsynced one would answer every
    // tile with "sync first" — the banner says that once instead.
    if (payment.isDeleted || payment.id.startsWith('tmp_')) return const [];
    final items = itemsFor(context, payment, onTap);
    EntityQuickAction<PaymentAction>? pick(
      PaymentAction kind,
      String shortLabel, {
      bool applies = true,
    }) {
      final item = findActionItem<PaymentAction>(items, kind);
      if (item == null) return null;
      return EntityQuickAction(
        item: item,
        shortLabel: shortLabel,
        applies: applies,
      );
    }

    return [
      EntityQuickAction(
        item: EntityActionItem(
          kind: PaymentAction.apply,
          icon: Icons.playlist_add_check_outlined,
          label: context.tr('apply_payment'),
          // An allocation is an edit of the payment (`UpdatePaymentRequest`),
          // which its creator or assignee may make too.
          enabled:
              context.read<Services>().auth.session.value?.canEditRecord(
                'payment',
                createdBy: payment.userId,
                assignedTo: payment.assignedUserId,
                recordId: payment.id,
              ) ??
              false,
          onTap: () => onTap(PaymentAction.apply),
        ),
        shortLabel: context.tr('apply'),
        // Only while there is money on it that pays for nothing yet.
        applies: payment.hasUnappliedFunds && payment.clientId.isNotEmpty,
      ),
      ?pick(PaymentAction.sendEmail, context.tr('email')),
      ?pick(PaymentAction.refund, context.tr('refund')),
      ?pick(PaymentAction.viewClient, context.tr('client')),
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
      case PaymentAction.apply:
        await applyPaymentToOldestInvoice(
          context,
          services,
          companyId,
          payment,
        );
      case PaymentAction.refund:
        if (!requireSynced(context, payment.id)) return;
        context.go('/payments/${payment.id}/refund');
      case PaymentAction.sendEmail:
        // The receipt goes to the client's primary contact (`EmailPayment`);
        // with no address there it goes nowhere (invoiceninja/ui#3400).
        if (!await ensureRecipientEmail(
          context,
          services,
          companyId: companyId,
          clientId: payment.clientId,
          invitations: null,
        )) {
          return;
        }
        if (!context.mounted) return;
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
      case PaymentAction.logCall:
        await promptLogCallFor(
          context,
          companyId: companyId,
          entityId: payment.id,
          subject: _confirmSubject(payment),
          clientId: payment.clientId,
          submit: (text) => services.payments.addComment(
            companyId: companyId,
            entityId: payment.id,
            text: text,
          ),
        );
      case PaymentAction.addComment:
        await promptAddCommentFor(
          context,
          entityId: payment.id,
          submit: (text) => services.payments.addComment(
            companyId: companyId,
            entityId: payment.id,
            text: text,
          ),
        );
      case PaymentAction.viewClient:
        if (payment.clientId.isEmpty) return;
        goEntityFullDetail(context, '/clients', payment.clientId);
      case PaymentAction.copyLink:
        await copyEntityLink(context, EntityType.payment, payment.id);
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
        // `hasDeletedInvoice` hides the action for most cases, but a cached
        // payment row predating the `is_deleted` read — or an invoice deleted
        // on this device since — only shows up in the local invoices table.
        if (await _linkedInvoiceDeleted(services, companyId, payment)) {
          if (context.mounted) {
            Notify.error(context, context.tr('deleted_invoices_exist'));
          }
          return;
        }
        if (!context.mounted) return;
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

  /// Whether any invoice [payment] is applied to is deleted — from the
  /// payment's own `invoices` include first, then the local invoices table.
  static Future<bool> _linkedInvoiceDeleted(
    Services services,
    String companyId,
    Payment payment,
  ) async {
    if (payment.hasDeletedInvoice) return true;
    final ids = {
      for (final i in payment.invoices) i.id,
      for (final pa in payment.paymentables) pa.invoiceId,
    }..remove('');
    for (final id in ids) {
      final invoice = await services.invoices
          .watchByRealId(companyId: companyId, id: id)
          .first;
      if (invoice?.isDeleted ?? false) return true;
    }
    return false;
  }
}
