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
import 'package:admin/data/models/domain/quote.dart';
import 'package:admin/data/models/domain/quote_status.dart';
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

/// Quote action set. Mirrors `InvoiceAction` but drops `markPaid` /
/// `autoBill` (payment-side, invoice-only) and adds `approve` /
/// `convertToInvoice` / `convertToProject`.
enum QuoteAction {
  edit,
  pdfGroup,
  viewPdf,
  downloadPdf,
  printPdf,
  sendEmail,
  scheduleEmail,
  markSent,
  approve,
  convertToInvoice,
  convertToProject,
  cloneGroup,
  clone,
  cloneToInvoice,
  cloneToCredit,
  cloneToRecurring,
  cloneToPurchaseOrder,
  cancel,
  runTemplate,
  addComment,
  logCall,
  copyLink,
  archive,
  restore,
  delete,
}

class QuoteActions {
  QuoteActions._();

  /// SAVE-PARAM classifier (edit-screen action bar). Non-null => the
  /// action is performed *by* the create/update request via these query
  /// params (server creates/updates and acts atomically — no temp-id
  /// gap). Keys are quote-specific (verified against admin-portal
  /// `quote_repository.saveData`: `convert` / `mark_sent` / `approve`).
  /// `sendEmail` is intentionally **not** here — it is an after-save
  /// separate request.
  static Map<String, String>? saveParamFor(QuoteAction action) {
    switch (action) {
      case QuoteAction.convertToInvoice:
        return const {'convert': 'true'};
      case QuoteAction.markSent:
        return const {'mark_sent': 'true'};
      case QuoteAction.approve:
        return const {'approve': 'true'};
      default:
        return null;
    }
  }

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// archive / restore / delete (the clone group collapses as a whole).
  static bool isLifecycle(QuoteAction action) {
    switch (action) {
      case QuoteAction.cloneGroup:
      case QuoteAction.clone:
      case QuoteAction.cloneToInvoice:
      case QuoteAction.cloneToCredit:
      case QuoteAction.cloneToRecurring:
      case QuoteAction.cloneToPurchaseOrder:
      case QuoteAction.archive:
      case QuoteAction.restore:
      case QuoteAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// After-save actions whose [dispatch] navigates unconditionally; the
  /// create-mode edit scaffold uses this to keep that navigation instead of
  /// redirecting to the detail screen. See `InvoiceActions.navigatesOnCreate`.
  static bool navigatesOnCreate(QuoteAction action) {
    switch (action) {
      case QuoteAction.sendEmail:
      case QuoteAction.scheduleEmail:
      case QuoteAction.viewPdf:
        return true;
      default:
        return false;
    }
  }

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(Quote quote) =>
      quote.number.isEmpty ? '' : '#${quote.number}';

  static List<EntityActionItem<QuoteAction>> itemsFor(
    BuildContext context,
    Quote quote,
    void Function(QuoteAction) onTap,
  ) {
    final canArchive = quote.archivedAt == null && !quote.isDeleted;
    final canRestore = quote.archivedAt != null || quote.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final canEdit = me?.can('edit_quote') ?? false;
    final canCreate = me?.can('create_quote') ?? false;
    final canDelete = me?.can('edit_quote') ?? false;
    final canMarkSent = canEdit && quote.isDraft;
    // Approve any non-terminal quote (draft or sent) — matches React
    // (`Draft || Sent`) and admin-portal (`!isApproved`); excludes
    // approved / converted / rejected.
    final canApprove = canEdit && (quote.isDraft || quote.isSent);
    // Convert any not-yet-converted quote (incl. drafts) — admin-portal
    // gates only on `invoiceId.isEmpty`.
    final canConvert = canEdit && !quote.isConverted;
    // Cancel is server-allowed for Sent quotes (rarely used in practice
    // but available — mirrors the Invoice rule). Converted quotes can't
    // be cancelled since their downstream invoice has its own lifecycle.

    return [
      if (canEdit)
        editActionItem(
          context: context,
          kind: QuoteAction.edit,
          onTap: () => onTap(QuoteAction.edit),
        ),
      pdfGroupActionItem(
        context: context,
        kind: QuoteAction.pdfGroup,
        children: [
          EntityActionItem(
            kind: QuoteAction.viewPdf,
            icon: Icons.picture_as_pdf_outlined,
            label: context.tr('view_pdf'),
            enabled: true,
            onTap: () => onTap(QuoteAction.viewPdf),
          ),
          EntityActionItem(
            kind: QuoteAction.downloadPdf,
            icon: Icons.download_outlined,
            label: context.tr('download_pdf'),
            enabled: true,
            onTap: () => onTap(QuoteAction.downloadPdf),
          ),
          EntityActionItem(
            kind: QuoteAction.printPdf,
            icon: Icons.print_outlined,
            label: context.tr('print_pdf'),
            enabled: true,
            onTap: () => onTap(QuoteAction.printPdf),
          ),
        ],
      ),
      EntityActionItem(
        kind: QuoteAction.sendEmail,
        icon: Icons.mail_outline,
        label: context.tr('send_email'),
        enabled: canEdit,
        onTap: () => onTap(QuoteAction.sendEmail),
      ),
      EntityActionItem(
        kind: QuoteAction.markSent,
        confirm: true,
        confirmSubject: _confirmSubject(quote),
        icon: Icons.send_outlined,
        label: context.tr('mark_sent'),
        enabled: canMarkSent,
        onTap: () => onTap(QuoteAction.markSent),
      ),
      EntityActionItem(
        kind: QuoteAction.approve,
        confirm: true,
        confirmSubject: _confirmSubject(quote),
        icon: Icons.thumb_up_alt_outlined,
        label: context.tr('approve'),
        enabled: canApprove,
        onTap: () => onTap(QuoteAction.approve),
      ),
      if (me?.moduleEnabled(EntityType.invoice) ?? false)
        EntityActionItem(
          kind: QuoteAction.convertToInvoice,
          confirm: true,
          confirmSubject: _confirmSubject(quote),
          icon: Icons.receipt_long_outlined,
          label: context.tr('convert_to_invoice'),
          enabled: canConvert,
          onTap: () => onTap(QuoteAction.convertToInvoice),
        ),
      if (me?.moduleEnabled(EntityType.project) ?? false)
        EntityActionItem(
          kind: QuoteAction.convertToProject,
          confirm: true,
          confirmSubject: _confirmSubject(quote),
          icon: Icons.work_outline,
          label: context.tr('convert_to_project'),
          // Hidden once a project is linked — mirrors admin-portal's
          // `projectId.isEmpty` gate.
          enabled: canEdit && !quote.isConverted && quote.projectId.isEmpty,
          onTap: () => onTap(QuoteAction.convertToProject),
        ),
      // 'Cancel' is an invoice-only action — the server's quote bulk whitelist
      // has no 'cancel', so offering it here only produced a success toast then
      // a dead 422'd outbox row. Removed (the QuoteAction.cancel enum/handler
      // stay as unreachable no-ops).
      if (canCreate)
        cloneGroupActionItem(
          context: context,
          kind: QuoteAction.cloneGroup,
          children: [
            EntityActionItem(
              kind: QuoteAction.clone,
              icon: Icons.copy_outlined,
              label: context.tr('clone_quote'),
              enabled: true,
              onTap: () => onTap(QuoteAction.clone),
            ),
            if (me?.moduleEnabled(EntityType.invoice) ?? false)
              EntityActionItem(
                kind: QuoteAction.cloneToInvoice,
                icon: Icons.receipt_long_outlined,
                label: context.tr('clone_to_invoice'),
                enabled: true,
                onTap: () => onTap(QuoteAction.cloneToInvoice),
              ),
            if (me?.moduleEnabled(EntityType.credit) ?? false)
              EntityActionItem(
                kind: QuoteAction.cloneToCredit,
                icon: Icons.assignment_return_outlined,
                label: context.tr('clone_to_credit'),
                enabled: true,
                onTap: () => onTap(QuoteAction.cloneToCredit),
              ),
            if (me?.moduleEnabled(EntityType.recurringInvoice) ?? false)
              EntityActionItem(
                kind: QuoteAction.cloneToRecurring,
                icon: Icons.event_repeat_outlined,
                label: context.tr('clone_to_recurring'),
                enabled: true,
                onTap: () => onTap(QuoteAction.cloneToRecurring),
              ),
            if (me?.moduleEnabled(EntityType.purchaseOrder) ?? false)
              EntityActionItem(
                kind: QuoteAction.cloneToPurchaseOrder,
                icon: Icons.shopping_bag_outlined,
                label: context.tr('clone_to_purchase_order'),
                enabled: true,
                onTap: () => onTap(QuoteAction.cloneToPurchaseOrder),
              ),
          ],
        ),
      if (canEdit) ...[
        EntityActionItem(
          kind: QuoteAction.runTemplate,
          icon: Icons.auto_awesome_outlined,
          label: context.tr('run_template'),
          enabled: true,
          onTap: () => onTap(QuoteAction.runTemplate),
        ),
        EntityActionItem(
          kind: QuoteAction.addComment,
          icon: Icons.chat_bubble_outline,
          label: context.tr('add_comment'),
          enabled: true,
          onTap: () => onTap(QuoteAction.addComment),
        ),
        EntityActionItem(
          kind: QuoteAction.logCall,
          icon: Icons.phone_in_talk_outlined,
          label: context.tr('log_call'),
          enabled: true,
          onTap: () => onTap(QuoteAction.logCall),
        ),
      ],
      ?copyLinkActionItem(
        context: context,
        kind: QuoteAction.copyLink,
        entityId: quote.id,
        onTap: () => onTap(QuoteAction.copyLink),
      ),
      if (canEdit)
        ?archiveActionItem(
          context: context,
          subject: _confirmSubject(quote),
          kind: QuoteAction.archive,
          canArchive: canArchive,
          onTap: () => onTap(QuoteAction.archive),
        ),
      if (canEdit)
        ?restoreActionItem(
          context: context,
          kind: QuoteAction.restore,
          canRestore: canRestore,
          onTap: () => onTap(QuoteAction.restore),
        ),
      if (canDelete)
        ?deleteActionItem(
          context: context,
          subject: _confirmSubject(quote),
          kind: QuoteAction.delete,
          canDelete: !quote.isDeleted,
          onTap: () => onTap(QuoteAction.delete),
        ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    Quote quote,
    QuoteAction action,
  ) async {
    bool tmpGate() => !requireSynced(context, quote.id);

    switch (action) {
      case QuoteAction.edit:
        goEntityEdit(context, '/quotes', quote.id);

      case QuoteAction.pdfGroup:
        break; // Submenu parent — never dispatched; children carry the action.

      case QuoteAction.viewPdf:
        if (tmpGate()) return;
        // `go` (not `push`): see client_actions.dart#viewStatement.
        context.go('/quotes/${quote.id}/pdf');

      case QuoteAction.downloadPdf:
      case QuoteAction.printPdf:
        if (tmpGate()) return;
        try {
          final bytes = await services.quotes.api.downloadPdf(
            entityJson: quote.toApiJson(),
            designId: quote.designId.isEmpty ? null : quote.designId,
          );
          if (!context.mounted) return;
          if (action == QuoteAction.downloadPdf) {
            final fileName =
                'quote_${quote.number.isEmpty ? quote.id : quote.number}.pdf';
            await Printing.sharePdf(bytes: bytes, filename: fileName);
          } else {
            await Printing.layoutPdf(onLayout: (_) async => bytes);
          }
        } catch (e) {
          if (!context.mounted) return;
          Notify.error(context, context.tr('error'), error: e);
        }

      case QuoteAction.sendEmail:
      case QuoteAction.scheduleEmail:
        if (tmpGate()) return;
        // Full-screen Send Email surface; bulk multi-select still uses the
        // showBillingDocEmailSheet bottom sheet.
        context.go('/quotes/${quote.id}/email?view=full');

      case QuoteAction.markSent:
        if (tmpGate()) return;
        await services.quotes.markSent(companyId: companyId, id: quote.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('marked_quote_as_sent'));

      case QuoteAction.approve:
        if (tmpGate()) return;
        await services.quotes.approve(companyId: companyId, id: quote.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('approved_quote'));

      case QuoteAction.convertToInvoice:
        if (tmpGate()) return;
        await services.quotes.convertToInvoice(
          companyId: companyId,
          id: quote.id,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('converted_to_invoice'));

      case QuoteAction.convertToProject:
        if (tmpGate()) return;
        await services.quotes.convertToProject(
          companyId: companyId,
          id: quote.id,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('converted_to_project'));

      case QuoteAction.cancel:
        if (tmpGate()) return;
        await services.quotes.cancel(companyId: companyId, id: quote.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('cancelled_quote'));

      case QuoteAction.cloneGroup:
        break; // Submenu parent — never dispatched; children carry the action.
      case QuoteAction.clone:
        // Reset everything that must not carry over to a fresh draft (mirrors
        // the invoice clone). Critically `statusId`: a clone of a Sent/Approved
        // quote must open as a Draft, not inherit "sent/approved". Also drop
        // dates (→ today / unset), exchange rate, partial, party links, and the
        // e-invoice block. `balance: quote.amount` mirrors invoice.
        final draft = quote.copyWith(
          id: '',
          number: '',
          statusId: QuoteStatus.draft,
          date: Date.today(),
          dueDate: null,
          partialDueDate: null,
          // Server-computed send timestamps must not carry to a fresh draft.
          lastSentDate: null,
          nextSendDate: null,
          partial: Decimal.zero,
          taxAmount: Decimal.zero,
          balance: quote.amount,
          exchangeRate: Decimal.one,
          projectId: '',
          vendorId: '',
          subscriptionId: '',
          invoiceId: '',
          eInvoice: null,
          // Drop the source's per-send lifecycle state — see
          // `InvitationClone.freshClone`. Without this the fresh draft shows
          // the original's sent/viewed timestamps and bounce error, and its
          // contact link opens the ORIGINAL document's portal page.
          invitations: quote.invitations.map((i) => i.freshClone()).toList(),
          // Sanitise the rows: drop the links back to the source task /
          // expense (else re-pointing the clone at another client dead-ends in
          // a `line_items` error with no field to fix) and drop any
          // server-generated unpaid-fee row (else the clone re-bills it).
          lineItems: clonedLineItems(quote.lineItems),
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        goEntityCreateFullWidth(context, '/quotes', extra: draft);

      // Cross-type clone is client-side: the local builder produces the same
      // draft, so the target is built here and opened in its create form.
      // Navigation IS the feedback — no toast, and no tmp_ gate since it never
      // hits the server. quote→invoice joins this group because the server's
      // bulk clone_to_invoice 500s (unsaved factory + a mutated transformer —
      // review #17 / BACKEND.md); the local path just works, like credit/
      // recurring/PO.
      case QuoteAction.cloneToInvoice:
        goEntityCreateFullWidth(
          context,
          '/invoices',
          extra: cloneToInvoice(billingCloneFromQuote(quote)),
        );

      case QuoteAction.cloneToCredit:
        goEntityCreateFullWidth(
          context,
          '/credits',
          extra: cloneToCredit(billingCloneFromQuote(quote)),
        );

      case QuoteAction.cloneToRecurring:
        goEntityCreateFullWidth(
          context,
          '/recurring_invoices',
          extra: cloneToRecurringInvoice(billingCloneFromQuote(quote)),
        );

      case QuoteAction.cloneToPurchaseOrder:
        goEntityCreateFullWidth(
          context,
          '/purchase_orders',
          extra: cloneToPurchaseOrder(billingCloneFromQuote(quote)),
        );

      case QuoteAction.logCall:
        await promptLogCallFor(
          context,
          companyId: companyId,
          entityId: quote.id,
          subject: _confirmSubject(quote),
          submit: (text) => services.quotes.addComment(
            companyId: companyId,
            quoteId: quote.id,
            text: text,
          ),
        );
      case QuoteAction.addComment:
        await promptAddCommentFor(
          context,
          entityId: quote.id,
          submit: (text) => services.quotes.addComment(
            companyId: companyId,
            quoteId: quote.id,
            text: text,
          ),
        );
      case QuoteAction.copyLink:
        await copyEntityLink(context, EntityType.quote, quote.id);
      case QuoteAction.archive:
        if (tmpGate()) return;
        await StandardEntityActions.archive(
          context: context,
          wireName: 'quote',
          op: () => services.quotes.archive(companyId: companyId, id: quote.id),
          undoOp: () =>
              services.quotes.restore(companyId: companyId, id: quote.id),
        );

      case QuoteAction.restore:
        if (tmpGate()) return;
        await StandardEntityActions.restore(
          context: context,
          wireName: 'quote',
          op: () => services.quotes.restore(companyId: companyId, id: quote.id),
        );

      case QuoteAction.delete:
        if (tmpGate()) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'quote',
          op: () => services.quotes.delete(companyId: companyId, id: quote.id),
          undoOp: () =>
              services.quotes.restore(companyId: companyId, id: quote.id),
        );

      case QuoteAction.runTemplate:
        if (tmpGate()) return;
        final templateId = await showRunTemplateDialog(context);
        if (templateId == null || !context.mounted) return;
        await services.quotes.runTemplate(
          companyId: companyId,
          id: quote.id,
          templateId: templateId,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('template_queued'));
    }
  }
}
