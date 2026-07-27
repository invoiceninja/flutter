import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/invoice.dart';
import 'package:admin/data/models/domain/invoice_status.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/billing/invoice_lock.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/actions/add_comment_prompt.dart';
import 'package:admin/ui/features/invoices/widgets/detail/mark_paid_confirm_dialog.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_locked_dialog.dart';
import 'package:admin/ui/features/billing_shared/billing_cross_clone.dart';
import 'package:admin/ui/features/invoices/widgets/rectify_invoice.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';

/// Action set surfaced for an invoice.
///
/// M1 wired edit / clone / archive / restore / delete.
/// M2 wires viewPdf / downloadPdf / printPdf / sendEmail / scheduleEmail /
/// markSent / markPaid / autoBill / cancel (all enqueue outbox rows).
/// M3 adds clone-to-quote/credit/recurring/po + runTemplate.

/// Whether the per-invoice e-invoice send / validate actions apply: the
/// company has an e-invoice channel configured (`eInvoiceType` non-empty —
/// PEPPOL or VERIFACTU) and the invoice is exactly **Sent** (not draft,
/// and not partial/paid which were already transmitted, nor cancelled /
/// reversed / deleted). Mirrors React gating + avoids re-transmitting an
/// already-billed invoice. Pure + unit-tested.
bool canSendEInvoice(Invoice invoice, String? eInvoiceType) =>
    (eInvoiceType ?? '').isNotEmpty &&
    invoice.statusId == InvoiceStatus.sent &&
    !invoice.isDeleted;

/// Whether the read-only **Validate** e-invoice pre-flight applies. Unlike
/// [canSendEInvoice] this is *not* Sent-only: validation is most useful on a
/// **draft** (check the document is compliant before sending) and is a safe
/// read-only call at any status. Only requires an e-invoice channel
/// configured and a non-deleted invoice. Pure + unit-tested.
bool canValidateEInvoice(Invoice invoice, String? eInvoiceType) =>
    (eInvoiceType ?? '').isNotEmpty && !invoice.isDeleted;

enum InvoiceAction {
  edit,
  pdfGroup,
  viewPdf,
  downloadPdf,
  printPdf,
  deliveryNote,
  sendEmail,
  scheduleEmail,
  markSent,
  markPaid,
  refund,
  autoBill,
  enterPayment,
  cloneGroup,
  clone,
  cloneToQuote,
  cloneToCredit,
  cloneToRecurring,
  cloneToPurchaseOrder,
  runTemplate,
  cancel,
  rectify,
  sendEInvoice,
  validateEInvoice,
  addComment,
  archive,
  restore,
  delete,
}

class InvoiceActions {
  InvoiceActions._();

  /// SAVE-PARAM classifier (edit-screen action bar). Non-null => the
  /// action is performed *by* the create/update request via these query
  /// params (server creates/updates and acts atomically — no temp-id
  /// gap). Keys are invoice-specific (verified against admin-portal
  /// `invoice_repository.saveData`: `paid` / `mark_sent` / `cancel` /
  /// `auto_bill`). `sendEmail` is intentionally **not** here — it is an
  /// after-save separate request.
  static Map<String, String>? saveParamFor(InvoiceAction action) {
    switch (action) {
      case InvoiceAction.markPaid:
        return const {'paid': 'true'};
      case InvoiceAction.markSent:
        return const {'mark_sent': 'true'};
      case InvoiceAction.cancel:
        return const {'cancel': 'true'};
      case InvoiceAction.autoBill:
        return const {'auto_bill': 'true'};
      default:
        return null;
    }
  }

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// archive / restore / delete (the clone group collapses as a whole).
  static bool isLifecycle(InvoiceAction action) {
    switch (action) {
      case InvoiceAction.cloneGroup:
      case InvoiceAction.clone:
      case InvoiceAction.cloneToQuote:
      case InvoiceAction.cloneToCredit:
      case InvoiceAction.cloneToRecurring:
      case InvoiceAction.cloneToPurchaseOrder:
      case InvoiceAction.archive:
      case InvoiceAction.restore:
      case InvoiceAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// After-save actions whose [dispatch] navigates *unconditionally* (an
  /// immediate `context.go` after the tmp gate). The create-mode edit scaffold
  /// uses this to skip its default detail redirect so the action's navigation
  /// survives once the create has drained and the tmp id resolves. Only
  /// unconditional navigators belong here — actions that may not navigate (e.g.
  /// `refund`, which no-ops when there are no payments) would otherwise strand
  /// the user on the saved form.
  static bool navigatesOnCreate(InvoiceAction action) {
    switch (action) {
      case InvoiceAction.sendEmail:
      case InvoiceAction.scheduleEmail:
      case InvoiceAction.viewPdf:
      case InvoiceAction.deliveryNote:
      case InvoiceAction.enterPayment:
        return true;
      default:
        return false;
    }
  }

  static List<EntityActionItem<InvoiceAction>> itemsFor(
    BuildContext context,
    Invoice invoice,
    void Function(InvoiceAction) onTap, {
    bool rectifyEligible = false,
    String? eInvoiceType,
    bool sendEInvoicePending = false,
  }) {
    // Both require an e-invoice channel configured (PEPPOL or Verifactu).
    // Send is Sent-only (don't re-transmit an already-billed invoice);
    // Validate is a read-only compliance pre-flight available at any status
    // (most useful on a draft, before sending). React parity:
    // Verifactu.tsx surfaces send + validate.
    final canEInvoice = canSendEInvoice(invoice, eInvoiceType);
    final canValidate = canValidateEInvoice(invoice, eInvoiceType);
    // Suppress the Send action while a `sendEInvoice` row is already
    // queued/in-flight for this invoice — prevents double-enqueue →
    // duplicate compliance transmissions (React uses a send cooldown).
    final canSend = canEInvoice && !sendEInvoicePending;
    final canArchive = invoice.archivedAt == null && !invoice.isDeleted;
    final canRestore = invoice.archivedAt != null || invoice.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;
    // Permission gates. Admin / owner bypass `can(...)`; otherwise check
    // the comma-separated `permissions` string. Server enforces too — UI
    // gates just hide affordances the user can't action.
    final canEditInvoice = me?.can('edit_invoice') ?? false;
    final canCreateInvoice = me?.can('create_invoice') ?? false;
    // There is no `delete_*` permission in the product — the server authorizes
    // a destroy through `EntityPolicy::edit` (`DestroyInvoiceRequest` →
    // `can('edit', $invoice)`), and React gates delete on `edit_*` too. Asking
    // for a `delete_invoice` token could never be granted, so Delete was hidden
    // from every non-admin.
    final canDeleteInvoice = me?.can('edit_invoice') ?? false;
    // `isLocked` (Verifactu) prevents *edits* but not status transitions —
    // marking sent / auto-billing a locked invoice is allowed; only
    // `markPaid` is gated because the synthetic payment it records is
    // itself an edit. (R4 fix.)
    final isLocked = invoice.isLocked;
    // Send → only meaningful for non-cancelled/non-reversed invoices.
    final canEmail =
        canEditInvoice && !invoice.isCancelled && !invoice.isReversed;
    // Mark sent → only from Draft.
    final canMarkSent = canEditInvoice && invoice.isDraft;
    // Mark paid → only when there's still a balance.
    final canMarkPaid =
        canEditInvoice &&
        !invoice.isPaid &&
        !invoice.isCancelled &&
        !invoice.isReversed;
    // Auto-bill → invoice must be payable + not already paid.
    final canAutoBill = canMarkPaid && invoice.statusId != InvoiceStatus.draft;
    // Cancel → sent / partial only (NOT paid). `isSent` includes paid, so
    // exclude it explicitly; matches v1 (`isSent && !isPaid`) and React
    // (`Sent || Partial`). The server `cancel` path has no paid guard, so a
    // missing `!isPaid` here would let a paid invoice be cancelled.
    final canCancel =
        canEditInvoice &&
        invoice.isSent &&
        !invoice.isPaid &&
        !invoice.isCancelled &&
        !invoice.isReversed;
    // Enter Payment → record a (partial) payment against an unpaid, non-draft
    // invoice. Promoted to the primary action (demoting Edit to a visible
    // secondary) when the invoice still owes money — recording payment is the
    // likely intent on a sent / past-due invoice.
    final canEnterPayment =
        (me?.can('create_payment') ?? false) &&
        !invoice.isDraft &&
        !invoice.isPaid &&
        !invoice.isCancelled &&
        !invoice.isReversed;

    return [
      if (canEnterPayment)
        EntityActionItem(
          kind: InvoiceAction.enterPayment,
          icon: Icons.payments_outlined,
          label: context.tr('enter_payment'),
          enabled: true,
          isPrimary: true,
          onTap: () => onTap(InvoiceAction.enterPayment),
        ),
      if (canEditInvoice)
        editActionItem(
          context: context,
          kind: InvoiceAction.edit,
          onTap: () => onTap(InvoiceAction.edit),
          isPrimary: !canEnterPayment,
        ),
      pdfGroupActionItem(
        context: context,
        kind: InvoiceAction.pdfGroup,
        children: [
          EntityActionItem(
            kind: InvoiceAction.viewPdf,
            icon: Icons.picture_as_pdf_outlined,
            label: context.tr('view_pdf'),
            enabled: true,
            onTap: () => onTap(InvoiceAction.viewPdf),
          ),
          EntityActionItem(
            kind: InvoiceAction.downloadPdf,
            icon: Icons.download_outlined,
            label: context.tr('download_pdf'),
            enabled: true,
            onTap: () => onTap(InvoiceAction.downloadPdf),
          ),
          EntityActionItem(
            kind: InvoiceAction.printPdf,
            icon: Icons.print_outlined,
            label: context.tr('print_pdf'),
            enabled: true,
            onTap: () => onTap(InvoiceAction.printPdf),
          ),
          EntityActionItem(
            kind: InvoiceAction.deliveryNote,
            icon: Icons.local_shipping_outlined,
            label: context.tr('delivery_note'),
            enabled: true,
            onTap: () => onTap(InvoiceAction.deliveryNote),
          ),
        ],
      ),
      EntityActionItem(
        kind: InvoiceAction.sendEmail,
        icon: Icons.mail_outline,
        label: context.tr('send_email'),
        enabled: canEmail,
        onTap: () => onTap(InvoiceAction.sendEmail),
      ),
      EntityActionItem(
        kind: InvoiceAction.markSent,
        icon: Icons.send_outlined,
        label: context.tr('mark_sent'),
        enabled: canMarkSent,
        onTap: () => onTap(InvoiceAction.markSent),
      ),
      EntityActionItem(
        kind: InvoiceAction.markPaid,
        icon: Icons.payments_outlined,
        label: context.tr('mark_paid'),
        enabled: canMarkPaid && !isLocked,
        onTap: () => onTap(InvoiceAction.markPaid),
      ),
      EntityActionItem(
        kind: InvoiceAction.refund,
        icon: Icons.undo_outlined,
        label: context.tr('refund_payment'),
        // Refunds operate on this invoice's payment(s); only meaningful
        // once it's (partially) paid. Dispatch resolves the actual
        // refundable payment(s) and routes to the existing refund screen.
        enabled:
            canEditInvoice &&
            (invoice.isPaid || invoice.isPartial) &&
            !invoice.isReversed,
        onTap: () => onTap(InvoiceAction.refund),
      ),
      EntityActionItem(
        kind: InvoiceAction.autoBill,
        icon: Icons.credit_card_outlined,
        label: context.tr('auto_bill'),
        enabled: canAutoBill,
        onTap: () => onTap(InvoiceAction.autoBill),
      ),
      EntityActionItem(
        kind: InvoiceAction.cancel,
        icon: Icons.cancel_outlined,
        label: context.tr('cancel_invoice'),
        enabled: canCancel,
        onTap: () => onTap(InvoiceAction.cancel),
      ),
      // Verifactu rectify — hidden entirely unless every gate condition
      // holds (React parity: the action is conditionally rendered, not
      // merely disabled). The caller resolves client country + company
      // e_invoice_type and passes the composed `rectifyEligible`.
      if (rectifyEligible)
        EntityActionItem(
          kind: InvoiceAction.rectify,
          icon: Icons.swap_horiz,
          label: context.tr('rectify'),
          enabled: true,
          onTap: () => onTap(InvoiceAction.rectify),
        ),
      if (canSend)
        EntityActionItem(
          kind: InvoiceAction.sendEInvoice,
          icon: Icons.send_outlined,
          label: context.tr('send_einvoice'),
          enabled: true,
          onTap: () => onTap(InvoiceAction.sendEInvoice),
        ),
      if (canValidate)
        EntityActionItem(
          kind: InvoiceAction.validateEInvoice,
          icon: Icons.fact_check_outlined,
          label: context.tr('validate'),
          enabled: true,
          onTap: () => onTap(InvoiceAction.validateEInvoice),
        ),
      if (canCreateInvoice)
        cloneGroupActionItem(
          context: context,
          kind: InvoiceAction.cloneGroup,
          children: [
            EntityActionItem(
              kind: InvoiceAction.clone,
              icon: Icons.copy_outlined,
              label: context.tr('clone_invoice'),
              enabled: true,
              onTap: () => onTap(InvoiceAction.clone),
            ),
            if (me?.moduleEnabled(EntityType.quote) ?? false)
              EntityActionItem(
                kind: InvoiceAction.cloneToQuote,
                icon: Icons.request_quote_outlined,
                label: context.tr('clone_to_quote'),
                enabled: true,
                onTap: () => onTap(InvoiceAction.cloneToQuote),
              ),
            if (me?.moduleEnabled(EntityType.credit) ?? false)
              EntityActionItem(
                kind: InvoiceAction.cloneToCredit,
                icon: Icons.assignment_return_outlined,
                label: context.tr('clone_to_credit'),
                enabled: true,
                onTap: () => onTap(InvoiceAction.cloneToCredit),
              ),
            if (me?.moduleEnabled(EntityType.recurringInvoice) ?? false)
              EntityActionItem(
                kind: InvoiceAction.cloneToRecurring,
                icon: Icons.event_repeat_outlined,
                label: context.tr('clone_to_recurring'),
                enabled: true,
                onTap: () => onTap(InvoiceAction.cloneToRecurring),
              ),
            if (me?.moduleEnabled(EntityType.purchaseOrder) ?? false)
              EntityActionItem(
                kind: InvoiceAction.cloneToPurchaseOrder,
                icon: Icons.shopping_bag_outlined,
                label: context.tr('clone_to_purchase_order'),
                enabled: true,
                onTap: () => onTap(InvoiceAction.cloneToPurchaseOrder),
              ),
          ],
        ),
      if (canEditInvoice) ...[
        EntityActionItem(
          kind: InvoiceAction.runTemplate,
          icon: Icons.auto_awesome_outlined,
          label: context.tr('run_template'),
          enabled: true,
          onTap: () => onTap(InvoiceAction.runTemplate),
        ),
        EntityActionItem(
          kind: InvoiceAction.addComment,
          icon: Icons.chat_bubble_outline,
          label: context.tr('add_comment'),
          enabled: true,
          onTap: () => onTap(InvoiceAction.addComment),
        ),
      ],
      if (canEditInvoice)
        ?archiveActionItem(
          context: context,
          kind: InvoiceAction.archive,
          canArchive: canArchive,
          onTap: () => onTap(InvoiceAction.archive),
        ),
      if (canEditInvoice)
        ?restoreActionItem(
          context: context,
          kind: InvoiceAction.restore,
          canRestore: canRestore,
          onTap: () => onTap(InvoiceAction.restore),
        ),
      if (canDeleteInvoice)
        ?deleteActionItem(
          context: context,
          kind: InvoiceAction.delete,
          canDelete: !invoice.isDeleted,
          onTap: () => onTap(InvoiceAction.delete),
        ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    Invoice invoice,
    InvoiceAction action,
  ) async {
    // Most server-bound actions require a real id. tmp_ rows live only in
    // the outbox until the create round-trips.
    bool tmpGate() => !requireSynced(context, invoice.id);

    switch (action) {
      case InvoiceAction.edit:
        // Hard-block editing a locked invoice (admin-portal parity). tmp_
        // rows are offline-created drafts — never locked, and there's no
        // persisted cascade to resolve yet. Reason-specific dialog; the
        // editor never opens. Other actions stay usable.
        if (!invoice.id.startsWith('tmp_')) {
          final reason = await resolveInvoiceLockReason(
            settings: services.settings,
            companyId: companyId,
            invoice: invoice,
          );
          if (reason != InvoiceLockReason.none) {
            if (!context.mounted) return;
            await showInvoiceLockedDialog(context, reason);
            return;
          }
        }
        if (!context.mounted) return;
        goEntityEdit(context, '/invoices', invoice.id);

      case InvoiceAction.pdfGroup:
        break; // Submenu parent — never dispatched; children carry the action.

      case InvoiceAction.viewPdf:
        if (tmpGate()) return;
        // `go` (not `push`) so the inner Navigator resolves the full
        // `/invoices/:id` + `pdf` chain when the user invokes this from
        // the bare list — `push` drops the missing `:id` parent and the
        // pane never opens. See client_actions.dart#viewStatement.
        context.go('/invoices/${invoice.id}/pdf');

      case InvoiceAction.deliveryNote:
        if (tmpGate()) return;
        context.go('/invoices/${invoice.id}/pdf?delivery_note=true');

      case InvoiceAction.downloadPdf:
      case InvoiceAction.printPdf:
        if (tmpGate()) return;
        try {
          final bytes = await services.invoices.api.downloadPdf(
            entityJson: invoice.toApiJson(),
            designId: invoice.designId.isEmpty ? null : invoice.designId,
          );
          if (!context.mounted) return;
          if (action == InvoiceAction.downloadPdf) {
            final fileName =
                'invoice_${invoice.number.isEmpty ? invoice.id : invoice.number}.pdf';
            await Printing.sharePdf(bytes: bytes, filename: fileName);
          } else {
            await Printing.layoutPdf(onLayout: (_) async => bytes);
          }
        } catch (e) {
          if (!context.mounted) return;
          Notify.error(context, context.tr('error'), error: e);
        }

      case InvoiceAction.sendEmail:
      case InvoiceAction.scheduleEmail:
        if (tmpGate()) return;
        // Full-screen Send Email surface (form + live preview + PDF +
        // History). The screen owns both immediate-send and scheduled
        // dispatch; bulk multi-select still uses showBillingDocEmailSheet.
        context.go('/invoices/${invoice.id}/email?view=full');

      case InvoiceAction.markSent:
        if (tmpGate()) return;
        await services.invoices.markSent(companyId: companyId, id: invoice.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('marked_invoice_as_sent'));

      case InvoiceAction.markPaid:
        if (tmpGate()) return;
        final confirmed = await showMarkPaidConfirmDialog(context);
        if (!confirmed) return;
        await services.invoices.markPaid(companyId: companyId, id: invoice.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('marked_invoice_as_paid'));

      case InvoiceAction.refund:
        if (tmpGate()) return;
        // Refund operates on the invoice's payment(s) via the existing
        // refund screen. Resolve the refundable ones; route directly when
        // there's exactly one, otherwise let the user pick.
        final payments = await services.payments
            .watchForInvoice(companyId: companyId, invoiceId: invoice.id)
            .first;
        final refundable = payments.where((p) => p.canRefund).toList();
        if (!context.mounted) return;
        if (refundable.isEmpty) {
          Notify.info(context, context.tr('no_refundable_payment'));
        } else if (refundable.length == 1) {
          context.go('/payments/${refundable.first.id}/refund');
        } else {
          await showModalBottomSheet<void>(
            context: context,
            builder: (sheetContext) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.all(InSpacing.lg(sheetContext)),
                    child: Text(
                      sheetContext.tr('select_payment'),
                      style: Theme.of(sheetContext).textTheme.titleSmall,
                    ),
                  ),
                  for (final p in refundable)
                    ListTile(
                      leading: const Icon(Icons.undo_outlined),
                      title: Text('#${p.number}'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        context.go('/payments/${p.id}/refund');
                      },
                    ),
                ],
              ),
            ),
          );
        }

      case InvoiceAction.autoBill:
        if (tmpGate()) return;
        await services.invoices.autoBill(companyId: companyId, id: invoice.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('auto_bill_queued'));

      case InvoiceAction.cancel:
        if (tmpGate()) return;
        await services.invoices.cancel(companyId: companyId, id: invoice.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('cancelled_invoice'));

      case InvoiceAction.enterPayment:
        if (tmpGate()) return;
        // Open the payment editor prefilled with this client + an invoice
        // allocation seeded to the outstanding balance. The user can lower
        // the amount for a partial payment — the allocations section + VM
        // auto-sync `amount` from the paymentables.
        // `/payments/new` defaults to the slide-over sidebar (see
        // `_kEditDefaultsToSlide`); do not force `?view=full` here.
        services.stageCreateDraft(
          '/payments',
          emptyPayment().copyWith(
            clientId: invoice.clientId,
            paymentables: [
              Paymentable(
                invoiceId: invoice.id,
                amount: invoice.balance,
                refunded: Decimal.zero,
              ),
            ],
          ),
        );
        context.go('/payments/new');

      case InvoiceAction.cloneGroup:
        break; // Submenu parent — never dispatched; children carry the action.
      case InvoiceAction.clone:
        // Reset everything that must not carry over to a fresh draft (React
        // CloneOptionsModal parity). Critically `statusId` + `paidToDate`: a
        // clone of a Paid invoice must open as an unpaid Draft, not inherit
        // "paid" with a stale paid-to-date. Also drop dates (→ today / unset),
        // exchange rate, partial, party links, and the e-invoice / backup
        // blocks. (Documents aren't serialized on save, so they need no reset.)
        final draft = invoice.copyWith(
          id: '',
          number: '',
          statusId: InvoiceStatus.draft,
          date: Date.today(),
          dueDate: null,
          partialDueDate: null,
          partial: Decimal.zero,
          paidToDate: Decimal.zero,
          taxAmount: Decimal.zero,
          balance: invoice.amount,
          exchangeRate: Decimal.one,
          lastSentDate: null,
          projectId: '',
          vendorId: '',
          subscriptionId: '',
          eInvoice: null,
          backup: null,
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        goEntityCreateFullWidth(context, '/invoices', extra: draft);

      case InvoiceAction.rectify:
        if (tmpGate()) return;
        final reason = await showRectifyReasonDialog(context);
        if (reason == null || !context.mounted) return;
        goEntityCreateFullWidth(
          context,
          '/invoices',
          extra: rectifiedDraft(invoice, reason),
        );

      case InvoiceAction.sendEInvoice:
        if (tmpGate()) return;
        await services.invoices.sendEInvoice(
          companyId: companyId,
          id: invoice.id,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('sent_einvoice'));

      case InvoiceAction.validateEInvoice:
        if (tmpGate()) return;
        try {
          final result = await services.invoices.api.validateEInvoice(
            invoice.id,
          );
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            builder: (d) {
              final flat = result.messages.where((s) => s.isNotEmpty).toList();
              final ok = result.passes && flat.isEmpty;
              return AlertDialog(
                title: Text(d.tr('validate')),
                content: ok
                    ? Text(d.tr('validation_passed'))
                    : SizedBox(
                        width: 420,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (final m in flat)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Text('• $m'),
                                ),
                            ],
                          ),
                        ),
                      ),
                actions: [
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 44),
                    ),
                    onPressed: () => Navigator.of(d).pop(),
                    child: Text(d.tr('close')),
                  ),
                ],
              );
            },
          );
        } catch (e) {
          if (context.mounted) {
            Notify.error(context, context.tr('an_error_occurred'), error: e);
          }
        }

      case InvoiceAction.addComment:
        if (tmpGate()) return;
        final text = await showAddCommentPrompt(context);
        if (text == null || !context.mounted) return;
        await services.invoices.addComment(
          companyId: companyId,
          invoiceId: invoice.id,
          text: text,
        );

      case InvoiceAction.archive:
        if (tmpGate()) return;
        await StandardEntityActions.archive(
          context: context,
          wireName: 'invoice',
          op: () =>
              services.invoices.archive(companyId: companyId, id: invoice.id),
          undoOp: () =>
              services.invoices.restore(companyId: companyId, id: invoice.id),
        );

      case InvoiceAction.restore:
        if (tmpGate()) return;
        await StandardEntityActions.restore(
          context: context,
          wireName: 'invoice',
          op: () =>
              services.invoices.restore(companyId: companyId, id: invoice.id),
        );

      case InvoiceAction.delete:
        if (tmpGate()) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'invoice',
          op: () =>
              services.invoices.delete(companyId: companyId, id: invoice.id),
          undoOp: () =>
              services.invoices.restore(companyId: companyId, id: invoice.id),
        );

      // Cross-type clone is client-side: the local builder produces the same
      // draft, so the target is built here and opened in its create form
      // (navigation IS the feedback — no toast, and no tmp_ gate since it never
      // hits the server). invoice→quote joins this group because the server's
      // bulk clone_to_quote 500s (unsaved factory + a mutated transformer —
      // review #17 / BACKEND.md); the local path just works, exactly like
      // credit/recurring/PO. Same-type "clone" above does the equivalent for
      // invoices.
      case InvoiceAction.cloneToQuote:
        goEntityCreateFullWidth(
          context,
          '/quotes',
          extra: cloneToQuote(billingCloneFromInvoice(invoice)),
        );

      case InvoiceAction.cloneToCredit:
        goEntityCreateFullWidth(
          context,
          '/credits',
          extra: cloneToCredit(billingCloneFromInvoice(invoice)),
        );

      case InvoiceAction.cloneToRecurring:
        goEntityCreateFullWidth(
          context,
          '/recurring_invoices',
          extra: cloneToRecurringInvoice(billingCloneFromInvoice(invoice)),
        );

      case InvoiceAction.cloneToPurchaseOrder:
        goEntityCreateFullWidth(
          context,
          '/purchase_orders',
          extra: cloneToPurchaseOrder(billingCloneFromInvoice(invoice)),
        );

      case InvoiceAction.runTemplate:
        if (tmpGate()) return;
        final templateId = await showRunTemplateDialog(context);
        if (templateId == null || !context.mounted) return;
        await services.invoices.runTemplate(
          companyId: companyId,
          id: invoice.id,
          templateId: templateId,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('template_queued'));
    }
  }
}
