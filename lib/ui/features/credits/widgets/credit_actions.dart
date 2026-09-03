import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/credit.dart';
import 'package:admin/data/models/domain/credit_status.dart';
import 'package:admin/data/models/domain/payment.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/billing_cross_clone.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';
import 'package:admin/ui/features/payments/view_models/payment_edit_view_model.dart';

/// Credit action set. Mirrors `QuoteAction` but drops the conversion
/// actions (`approve` / `convertToInvoice` / `convertToProject`) — credits
/// have no convert lifecycle — and trims `cloneToRecurring` since recurring
/// credits don't exist.
enum CreditAction {
  edit,
  pdfGroup,
  viewPdf,
  downloadPdf,
  printPdf,
  sendEmail,
  scheduleEmail,
  markSent,
  markPaid,
  applyToInvoice,
  cloneGroup,
  clone,
  cloneToInvoice,
  cloneToQuote,
  cloneToPurchaseOrder,
  runTemplate,
  addComment,
  logCall,
  copyLink,
  archive,
  restore,
  delete,
}

class CreditActions {
  CreditActions._();

  /// SAVE-PARAM classifier (edit-screen action bar). Non-null => the
  /// action is performed *by* the create/update request via these query
  /// params (server creates/updates and acts atomically — no temp-id
  /// gap). Keys are credit-specific (verified against admin-portal
  /// `credit_repository.saveData`: `mark_paid` / `mark_sent`). `markPaid`
  /// only surfaces for negative credits (see [itemsFor]). `sendEmail` is
  /// intentionally **not** here — it is an after-save separate request.
  static Map<String, String>? saveParamFor(CreditAction action) {
    switch (action) {
      case CreditAction.markSent:
        return const {'mark_sent': 'true'};
      case CreditAction.markPaid:
        return const {'mark_paid': 'true'};
      default:
        return null;
    }
  }

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// archive / restore / delete (the clone group collapses as a whole).
  static bool isLifecycle(CreditAction action) {
    switch (action) {
      case CreditAction.cloneGroup:
      case CreditAction.clone:
      case CreditAction.cloneToInvoice:
      case CreditAction.cloneToQuote:
      case CreditAction.cloneToPurchaseOrder:
      case CreditAction.archive:
      case CreditAction.restore:
      case CreditAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// After-save actions whose [dispatch] navigates unconditionally; the
  /// create-mode edit scaffold uses this to keep that navigation instead of
  /// redirecting to the detail screen. See `InvoiceActions.navigatesOnCreate`.
  static bool navigatesOnCreate(CreditAction action) {
    switch (action) {
      case CreditAction.sendEmail:
      case CreditAction.scheduleEmail:
      case CreditAction.viewPdf:
      case CreditAction.applyToInvoice:
        return true;
      default:
        return false;
    }
  }

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(Credit credit) =>
      credit.number.isEmpty ? '' : '#${credit.number}';

  static List<EntityActionItem<CreditAction>> itemsFor(
    BuildContext context,
    Credit credit,
    void Function(CreditAction) onTap,
  ) {
    final canArchive = credit.archivedAt == null && !credit.isDeleted;
    final canRestore = credit.archivedAt != null || credit.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final canEdit = me?.can('edit_credit') ?? false;
    final canCreate = me?.can('create_credit') ?? false;
    final canDelete = me?.can('edit_credit') ?? false;
    final canMarkSent = canEdit && credit.isDraft;
    // Mark paid only for negative credits (which behave like a receivable),
    // and only while still open — mirrors React's `amount < 0` + status gate.
    final canMarkPaid =
        canEdit &&
        credit.amount < Decimal.zero &&
        (credit.isDraft || credit.isSent || credit.isPartial);

    return [
      if (canEdit)
        editActionItem(
          context: context,
          kind: CreditAction.edit,
          onTap: () => onTap(CreditAction.edit),
        ),
      pdfGroupActionItem(
        context: context,
        kind: CreditAction.pdfGroup,
        children: [
          EntityActionItem(
            kind: CreditAction.viewPdf,
            icon: Icons.picture_as_pdf_outlined,
            label: context.tr('view_pdf'),
            enabled: true,
            onTap: () => onTap(CreditAction.viewPdf),
          ),
          EntityActionItem(
            kind: CreditAction.downloadPdf,
            icon: Icons.download_outlined,
            label: context.tr('download_pdf'),
            enabled: true,
            onTap: () => onTap(CreditAction.downloadPdf),
          ),
          EntityActionItem(
            kind: CreditAction.printPdf,
            icon: Icons.print_outlined,
            label: context.tr('print_pdf'),
            enabled: true,
            onTap: () => onTap(CreditAction.printPdf),
          ),
        ],
      ),
      EntityActionItem(
        kind: CreditAction.sendEmail,
        icon: Icons.mail_outline,
        label: context.tr('send_email'),
        enabled: canEdit,
        onTap: () => onTap(CreditAction.sendEmail),
      ),
      EntityActionItem(
        kind: CreditAction.markSent,
        confirm: true,
        confirmSubject: _confirmSubject(credit),
        icon: Icons.send_outlined,
        label: context.tr('mark_sent'),
        enabled: canMarkSent,
        onTap: () => onTap(CreditAction.markSent),
      ),
      if (canMarkPaid)
        EntityActionItem(
          kind: CreditAction.markPaid,
          confirm: true,
          confirmSubject: _confirmSubject(credit),
          icon: Icons.payments_outlined,
          label: context.tr('mark_paid'),
          enabled: true,
          onTap: () => onTap(CreditAction.markPaid),
        ),
      if (me?.moduleEnabled(EntityType.invoice) ?? false)
        EntityActionItem(
          kind: CreditAction.applyToInvoice,
          icon: Icons.price_check_outlined,
          label: context.tr('apply_credit'),
          enabled: credit.balance > Decimal.zero && !credit.isDeleted,
          onTap: () => onTap(CreditAction.applyToInvoice),
        ),
      if (canCreate)
        cloneGroupActionItem(
          context: context,
          kind: CreditAction.cloneGroup,
          children: [
            EntityActionItem(
              kind: CreditAction.clone,
              icon: Icons.copy_outlined,
              label: context.tr('clone_credit'),
              enabled: true,
              onTap: () => onTap(CreditAction.clone),
            ),
            if (me?.moduleEnabled(EntityType.invoice) ?? false)
              EntityActionItem(
                kind: CreditAction.cloneToInvoice,
                icon: Icons.receipt_long_outlined,
                label: context.tr('clone_to_invoice'),
                enabled: true,
                onTap: () => onTap(CreditAction.cloneToInvoice),
              ),
            if (me?.moduleEnabled(EntityType.quote) ?? false)
              EntityActionItem(
                kind: CreditAction.cloneToQuote,
                icon: Icons.request_quote_outlined,
                label: context.tr('clone_to_quote'),
                enabled: true,
                onTap: () => onTap(CreditAction.cloneToQuote),
              ),
            if (me?.moduleEnabled(EntityType.purchaseOrder) ?? false)
              EntityActionItem(
                kind: CreditAction.cloneToPurchaseOrder,
                icon: Icons.shopping_bag_outlined,
                label: context.tr('clone_to_purchase_order'),
                enabled: true,
                onTap: () => onTap(CreditAction.cloneToPurchaseOrder),
              ),
          ],
        ),
      if (canEdit) ...[
        EntityActionItem(
          kind: CreditAction.runTemplate,
          icon: Icons.auto_awesome_outlined,
          label: context.tr('run_template'),
          enabled: true,
          onTap: () => onTap(CreditAction.runTemplate),
        ),
        EntityActionItem(
          kind: CreditAction.addComment,
          icon: Icons.chat_bubble_outline,
          label: context.tr('add_comment'),
          enabled: true,
          onTap: () => onTap(CreditAction.addComment),
        ),
        EntityActionItem(
          kind: CreditAction.logCall,
          icon: Icons.phone_in_talk_outlined,
          label: context.tr('log_call'),
          enabled: true,
          onTap: () => onTap(CreditAction.logCall),
        ),
      ],
      ?copyLinkActionItem(
        context: context,
        kind: CreditAction.copyLink,
        entityId: credit.id,
        onTap: () => onTap(CreditAction.copyLink),
      ),
      if (canEdit)
        ?archiveActionItem(
          context: context,
          subject: _confirmSubject(credit),
          kind: CreditAction.archive,
          canArchive: canArchive,
          onTap: () => onTap(CreditAction.archive),
        ),
      if (canEdit)
        ?restoreActionItem(
          context: context,
          kind: CreditAction.restore,
          canRestore: canRestore,
          onTap: () => onTap(CreditAction.restore),
        ),
      if (canDelete)
        ?deleteActionItem(
          context: context,
          subject: _confirmSubject(credit),
          kind: CreditAction.delete,
          canDelete: !credit.isDeleted,
          onTap: () => onTap(CreditAction.delete),
        ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    Credit credit,
    CreditAction action,
  ) async {
    bool tmpGate() => !requireSynced(context, credit.id);

    switch (action) {
      case CreditAction.edit:
        goEntityEdit(context, '/credits', credit.id);

      case CreditAction.pdfGroup:
        break; // Submenu parent — never dispatched; children carry the action.

      case CreditAction.viewPdf:
        if (tmpGate()) return;
        // `go` (not `push`): see client_actions.dart#viewStatement.
        context.go('/credits/${credit.id}/pdf');

      case CreditAction.downloadPdf:
      case CreditAction.printPdf:
        if (tmpGate()) return;
        try {
          final bytes = await services.credits.api.downloadPdf(
            entityJson: credit.toApiJson(),
            designId: credit.designId.isEmpty ? null : credit.designId,
          );
          if (!context.mounted) return;
          if (action == CreditAction.downloadPdf) {
            final fileName =
                'credit_${credit.number.isEmpty ? credit.id : credit.number}.pdf';
            await Printing.sharePdf(bytes: bytes, filename: fileName);
          } else {
            await Printing.layoutPdf(onLayout: (_) async => bytes);
          }
        } catch (e) {
          if (!context.mounted) return;
          Notify.error(context, context.tr('error'), error: e);
        }

      case CreditAction.sendEmail:
      case CreditAction.scheduleEmail:
        if (tmpGate()) return;
        // Full-screen Send Email surface; bulk multi-select still uses the
        // showBillingDocEmailSheet bottom sheet.
        context.go('/credits/${credit.id}/email?view=full');

      case CreditAction.markSent:
        if (tmpGate()) return;
        await services.credits.markSent(companyId: companyId, id: credit.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('marked_credit_as_sent'));

      case CreditAction.markPaid:
        if (tmpGate()) return;
        await services.credits.markPaid(companyId: companyId, id: credit.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('marked_credit_as_paid'));

      case CreditAction.applyToInvoice:
        if (tmpGate()) return;
        // Open the payment editor prefilled with this credit as a credit
        // allocation. The user adds the target invoice allocation there;
        // the payment then draws the credit balance down against it
        // (mirrors v1's "Apply Credit" → payment-with-credits flow).
        // `/payments/new` defaults to the slide-over sidebar (see
        // `_kEditDefaultsToSlide`); do not force `?view=full` here.
        services.stageCreateDraft(
          '/payments',
          emptyPayment().copyWith(
            clientId: credit.clientId,
            paymentables: [
              Paymentable(
                creditId: credit.id,
                amount: credit.balance,
                refunded: Decimal.zero,
              ),
            ],
          ),
        );
        context.go('/payments/new');

      case CreditAction.cloneGroup:
        break; // Submenu parent — never dispatched; children carry the action.
      case CreditAction.clone:
        // Reset everything that must not carry over to a fresh draft (mirrors
        // the invoice clone). Critically `statusId` + `paidToDate`: a clone of
        // an Applied credit must open as an unapplied Draft, not inherit
        // "applied" with a stale paid-to-date. Also drop dates (→ today /
        // unset), partial deposit, exchange rate, party links, and the
        // e-invoice block. Credits have no `subscriptionId` field.
        final draft = credit.copyWith(
          id: '',
          number: '',
          statusId: CreditStatus.draft,
          date: Date.today(),
          dueDate: null,
          partialDueDate: null,
          paidToDate: Decimal.zero,
          partial: Decimal.zero,
          taxAmount: Decimal.zero,
          balance: credit.amount,
          exchangeRate: Decimal.one,
          projectId: '',
          vendorId: '',
          eInvoice: null,
          // Drop the source's per-send lifecycle state — see
          // `InvitationClone.freshClone`. Without this the fresh draft shows
          // the original's sent/viewed timestamps and bounce error, and its
          // contact link opens the ORIGINAL document's portal page.
          invitations: credit.invitations.map((i) => i.freshClone()).toList(),
          // Sanitise the rows: drop the links back to the source task /
          // expense (else re-pointing the clone at another client dead-ends in
          // a `line_items` error with no field to fix) and drop any
          // server-generated unpaid-fee row (else the clone re-bills it).
          lineItems: clonedLineItems(credit.lineItems),
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        goEntityCreateFullWidth(context, '/credits', extra: draft);

      // Cross-type clone is client-side (the server's bulk performAction only
      // clones credit→credit): invoice/quote/PO are built here and opened in
      // the target's create form. Navigation IS the feedback — no toast, and no
      // tmp_ gate since it never hits the server. Same-type "clone" above does
      // the equivalent for credits.
      case CreditAction.cloneToInvoice:
        goEntityCreateFullWidth(
          context,
          '/invoices',
          extra: cloneToInvoice(billingCloneFromCredit(credit)),
        );

      case CreditAction.cloneToQuote:
        goEntityCreateFullWidth(
          context,
          '/quotes',
          extra: cloneToQuote(billingCloneFromCredit(credit)),
        );

      case CreditAction.cloneToPurchaseOrder:
        goEntityCreateFullWidth(
          context,
          '/purchase_orders',
          extra: cloneToPurchaseOrder(billingCloneFromCredit(credit)),
        );

      case CreditAction.logCall:
        await promptLogCallFor(
          context,
          companyId: companyId,
          entityId: credit.id,
          subject: _confirmSubject(credit),
          submit: (text) => services.credits.addComment(
            companyId: companyId,
            creditId: credit.id,
            text: text,
          ),
        );
      case CreditAction.addComment:
        await promptAddCommentFor(
          context,
          entityId: credit.id,
          submit: (text) => services.credits.addComment(
            companyId: companyId,
            creditId: credit.id,
            text: text,
          ),
        );
      case CreditAction.copyLink:
        await copyEntityLink(context, EntityType.credit, credit.id);
      case CreditAction.archive:
        if (tmpGate()) return;
        await StandardEntityActions.archive(
          context: context,
          wireName: 'credit',
          op: () =>
              services.credits.archive(companyId: companyId, id: credit.id),
          undoOp: () =>
              services.credits.restore(companyId: companyId, id: credit.id),
        );

      case CreditAction.restore:
        if (tmpGate()) return;
        await StandardEntityActions.restore(
          context: context,
          wireName: 'credit',
          op: () =>
              services.credits.restore(companyId: companyId, id: credit.id),
        );

      case CreditAction.delete:
        if (tmpGate()) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'credit',
          op: () =>
              services.credits.delete(companyId: companyId, id: credit.id),
          undoOp: () =>
              services.credits.restore(companyId: companyId, id: credit.id),
        );

      case CreditAction.runTemplate:
        if (tmpGate()) return;
        final templateId = await showRunTemplateDialog(context);
        if (templateId == null || !context.mounted) return;
        await services.credits.runTemplate(
          companyId: companyId,
          id: credit.id,
          templateId: templateId,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('template_queued'));
    }
  }
}
