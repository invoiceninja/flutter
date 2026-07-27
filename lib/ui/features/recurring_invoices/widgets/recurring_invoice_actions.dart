import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/recurring_invoice.dart';
import 'package:admin/data/models/domain/recurring_invoice_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/actions/add_comment_prompt.dart';
import 'package:admin/ui/features/billing_shared/billing_cross_clone.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';

/// RecurringInvoice action set. Mirrors invoice actions but drops markPaid
/// / autoBill / cancel / convert (recurring doesn't have those), and adds
/// `start` / `stop` lifecycle actions.
enum RecurringInvoiceAction {
  edit,
  pdfGroup,
  viewPdf,
  downloadPdf,
  printPdf,
  sendEmail,
  sendNow,
  start,
  stop,
  cloneGroup,
  clone,
  cloneToInvoice,
  cloneToQuote,
  cloneToCredit,
  cloneToPurchaseOrder,
  runTemplate,
  addComment,
  archive,
  restore,
  delete,
}

class RecurringInvoiceActions {
  RecurringInvoiceActions._();

  /// SAVE-PARAM classifier (edit-screen action bar). Non-null => the
  /// action is performed *by* the create/update request via these query
  /// params (server creates/updates and acts atomically — no temp-id
  /// gap). Keys are recurring-invoice-specific (verified against
  /// admin-portal `recurring_invoice_repository.saveData`: `start` /
  /// `stop` / `send_now`). `sendEmail` is intentionally **not** here — it
  /// is an after-save separate request.
  static Map<String, String>? saveParamFor(RecurringInvoiceAction action) {
    switch (action) {
      case RecurringInvoiceAction.start:
        return const {'start': 'true'};
      case RecurringInvoiceAction.stop:
        return const {'stop': 'true'};
      case RecurringInvoiceAction.sendNow:
        return const {'send_now': 'true'};
      default:
        return null;
    }
  }

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// archive / restore / delete (the clone group collapses as a whole).
  static bool isLifecycle(RecurringInvoiceAction action) {
    switch (action) {
      case RecurringInvoiceAction.cloneGroup:
      case RecurringInvoiceAction.clone:
      case RecurringInvoiceAction.cloneToInvoice:
      case RecurringInvoiceAction.cloneToQuote:
      case RecurringInvoiceAction.cloneToCredit:
      case RecurringInvoiceAction.cloneToPurchaseOrder:
      case RecurringInvoiceAction.archive:
      case RecurringInvoiceAction.restore:
      case RecurringInvoiceAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// After-save actions whose [dispatch] navigates unconditionally; the
  /// create-mode edit scaffold uses this to keep that navigation instead of
  /// redirecting to the detail screen. See `InvoiceActions.navigatesOnCreate`.
  static bool navigatesOnCreate(RecurringInvoiceAction action) {
    switch (action) {
      case RecurringInvoiceAction.sendEmail:
      case RecurringInvoiceAction.viewPdf:
        return true;
      default:
        return false;
    }
  }

  static List<EntityActionItem<RecurringInvoiceAction>> itemsFor(
    BuildContext context,
    RecurringInvoice ri,
    void Function(RecurringInvoiceAction) onTap,
  ) {
    final canArchive = ri.archivedAt == null && !ri.isDeleted;
    final canRestore = ri.archivedAt != null || ri.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final canEdit = me?.can('edit_recurring_invoice') ?? false;
    final canCreate = me?.can('create_recurring_invoice') ?? false;
    final canDelete = me?.can('edit_recurring_invoice') ?? false;
    // React gates send_now on draft (it sends the first occurrence now); it is
    // performed as `?send_now=true` on a normal save, not a bulk action.
    final canSendNow = canEdit && ri.isDraft;
    final canStart = canEdit && (ri.isDraft || ri.isPaused);
    final canStop = canEdit && ri.isActive;

    return [
      if (canEdit)
        editActionItem(
          context: context,
          kind: RecurringInvoiceAction.edit,
          onTap: () => onTap(RecurringInvoiceAction.edit),
        ),
      pdfGroupActionItem(
        context: context,
        kind: RecurringInvoiceAction.pdfGroup,
        children: [
          EntityActionItem(
            kind: RecurringInvoiceAction.viewPdf,
            icon: Icons.picture_as_pdf_outlined,
            label: context.tr('view_pdf'),
            enabled: true,
            onTap: () => onTap(RecurringInvoiceAction.viewPdf),
          ),
          EntityActionItem(
            kind: RecurringInvoiceAction.downloadPdf,
            icon: Icons.download_outlined,
            label: context.tr('download_pdf'),
            enabled: true,
            onTap: () => onTap(RecurringInvoiceAction.downloadPdf),
          ),
          EntityActionItem(
            kind: RecurringInvoiceAction.printPdf,
            icon: Icons.print_outlined,
            label: context.tr('print_pdf'),
            enabled: true,
            onTap: () => onTap(RecurringInvoiceAction.printPdf),
          ),
        ],
      ),
      EntityActionItem(
        kind: RecurringInvoiceAction.sendEmail,
        icon: Icons.mail_outline,
        label: context.tr('send_email'),
        enabled: canEdit,
        onTap: () => onTap(RecurringInvoiceAction.sendEmail),
      ),
      EntityActionItem(
        kind: RecurringInvoiceAction.sendNow,
        icon: Icons.outgoing_mail,
        label: context.tr('send_now'),
        enabled: canSendNow,
        onTap: () => onTap(RecurringInvoiceAction.sendNow),
      ),
      EntityActionItem(
        kind: RecurringInvoiceAction.start,
        icon: Icons.play_arrow_outlined,
        label: context.tr('start'),
        enabled: canStart,
        onTap: () => onTap(RecurringInvoiceAction.start),
      ),
      EntityActionItem(
        kind: RecurringInvoiceAction.stop,
        icon: Icons.stop_outlined,
        label: context.tr('stop'),
        enabled: canStop,
        onTap: () => onTap(RecurringInvoiceAction.stop),
      ),
      if (canCreate)
        cloneGroupActionItem(
          context: context,
          kind: RecurringInvoiceAction.cloneGroup,
          children: [
            EntityActionItem(
              kind: RecurringInvoiceAction.clone,
              icon: Icons.copy_outlined,
              label: context.tr('clone_recurring_invoice'),
              enabled: true,
              onTap: () => onTap(RecurringInvoiceAction.clone),
            ),
            if (me?.moduleEnabled(EntityType.invoice) ?? false)
              EntityActionItem(
                kind: RecurringInvoiceAction.cloneToInvoice,
                icon: Icons.receipt_long_outlined,
                label: context.tr('clone_to_invoice'),
                enabled: true,
                onTap: () => onTap(RecurringInvoiceAction.cloneToInvoice),
              ),
            if (me?.moduleEnabled(EntityType.quote) ?? false)
              EntityActionItem(
                kind: RecurringInvoiceAction.cloneToQuote,
                icon: Icons.request_quote_outlined,
                label: context.tr('clone_to_quote'),
                enabled: true,
                onTap: () => onTap(RecurringInvoiceAction.cloneToQuote),
              ),
            if (me?.moduleEnabled(EntityType.credit) ?? false)
              EntityActionItem(
                kind: RecurringInvoiceAction.cloneToCredit,
                icon: Icons.assignment_return_outlined,
                label: context.tr('clone_to_credit'),
                enabled: true,
                onTap: () => onTap(RecurringInvoiceAction.cloneToCredit),
              ),
            if (me?.moduleEnabled(EntityType.purchaseOrder) ?? false)
              EntityActionItem(
                kind: RecurringInvoiceAction.cloneToPurchaseOrder,
                icon: Icons.shopping_bag_outlined,
                label: context.tr('clone_to_purchase_order'),
                enabled: true,
                onTap: () => onTap(RecurringInvoiceAction.cloneToPurchaseOrder),
              ),
          ],
        ),
      if (canEdit) ...[
        // 'Run template' removed: the recurring-invoice bulk endpoint's action
        // whitelist has no 'template' (BulkRecurringInvoiceRequest), so it only
        // toasted success then 422'd into a dead outbox row. See BACKEND.md.
        // (The RecurringInvoiceAction.runTemplate enum/handler stay as
        // unreachable no-ops.)
        EntityActionItem(
          kind: RecurringInvoiceAction.addComment,
          icon: Icons.chat_bubble_outline,
          label: context.tr('add_comment'),
          enabled: true,
          onTap: () => onTap(RecurringInvoiceAction.addComment),
        ),
      ],
      if (canEdit)
        ?archiveActionItem(
          context: context,
          kind: RecurringInvoiceAction.archive,
          canArchive: canArchive,
          onTap: () => onTap(RecurringInvoiceAction.archive),
        ),
      if (canEdit)
        ?restoreActionItem(
          context: context,
          kind: RecurringInvoiceAction.restore,
          canRestore: canRestore,
          onTap: () => onTap(RecurringInvoiceAction.restore),
        ),
      if (canDelete)
        ?deleteActionItem(
          context: context,
          kind: RecurringInvoiceAction.delete,
          canDelete: !ri.isDeleted,
          onTap: () => onTap(RecurringInvoiceAction.delete),
        ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    RecurringInvoice ri,
    RecurringInvoiceAction action,
  ) async {
    bool tmpGate() => !requireSynced(context, ri.id);

    switch (action) {
      case RecurringInvoiceAction.edit:
        goEntityEdit(context, '/recurring_invoices', ri.id);

      case RecurringInvoiceAction.pdfGroup:
        break; // Submenu parent — never dispatched; children carry the action.

      case RecurringInvoiceAction.viewPdf:
        if (tmpGate()) return;
        // `go` (not `push`): see client_actions.dart#viewStatement.
        context.go('/recurring_invoices/${ri.id}/pdf');

      case RecurringInvoiceAction.downloadPdf:
      case RecurringInvoiceAction.printPdf:
        if (tmpGate()) return;
        try {
          final bytes = await services.recurringInvoices.api.downloadPdf(
            entityJson: ri.toApiJson(),
            designId: ri.designId.isEmpty ? null : ri.designId,
          );
          if (!context.mounted) return;
          if (action == RecurringInvoiceAction.downloadPdf) {
            final fileName =
                'recurring_invoice_${ri.number.isEmpty ? ri.id : ri.number}.pdf';
            await Printing.sharePdf(bytes: bytes, filename: fileName);
          } else {
            await Printing.layoutPdf(onLayout: (_) async => bytes);
          }
        } catch (e) {
          if (!context.mounted) return;
          Notify.error(context, context.tr('error'), error: e);
        }

      case RecurringInvoiceAction.sendEmail:
        if (tmpGate()) return;
        // Full-screen Send Email surface; bulk multi-select still uses the
        // showBillingDocEmailSheet bottom sheet. (Recurring invoices have no
        // "schedule send" — the server's task_scheduler rejects them — so the
        // composer hides its Schedule action; see BillingDocType.supportsScheduledSend.)
        context.go('/recurring_invoices/${ri.id}/email?view=full');

      case RecurringInvoiceAction.sendNow:
        if (tmpGate()) return;
        await services.recurringInvoices.sendNow(
          companyId: companyId,
          id: ri.id,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('sent_recurring_invoice'));

      case RecurringInvoiceAction.start:
        if (tmpGate()) return;
        await services.recurringInvoices.start(companyId: companyId, id: ri.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('started_recurring_invoice'));

      case RecurringInvoiceAction.stop:
        if (tmpGate()) return;
        await services.recurringInvoices.stop(companyId: companyId, id: ri.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('stopped_recurring_invoice'));

      case RecurringInvoiceAction.cloneGroup:
        break; // Submenu parent — never dispatched; children carry the action.
      case RecurringInvoiceAction.clone:
        // Reset everything that must not carry over to a fresh draft (mirrors
        // the invoice clone). Critically `statusId`: a clone of an Active/Paused
        // recurring invoice must open as a Draft (un-started), not inherit
        // "active". Also drop dates (→ today / unset), the last-sent marker,
        // exchange rate, partial, party links, and the e-invoice block. The
        // recurring template config (`frequencyId`, `nextSendDate`,
        // `remainingCycles`) is intentionally kept. Recurring has no
        // `paidToDate` field.
        final draft = ri.copyWith(
          id: '',
          number: '',
          statusId: RecurringInvoiceStatus.draft,
          date: Date.today(),
          dueDate: null,
          partialDueDate: null,
          partial: Decimal.zero,
          taxAmount: Decimal.zero,
          balance: ri.amount,
          exchangeRate: Decimal.one,
          lastSentDate: null,
          projectId: '',
          vendorId: '',
          subscriptionId: '',
          eInvoice: null,
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        goEntityCreateFullWidth(context, '/recurring_invoices', extra: draft);

      // Cross-type clone is client-side (the server's bulk performAction has no
      // recurring-invoice clone targets): all targets are built here and opened
      // in the target's create form. Navigation IS the feedback — no toast, and
      // no tmp_ gate since it never hits the server. Same-type "clone" above
      // does the equivalent for recurring invoices.
      case RecurringInvoiceAction.cloneToInvoice:
        goEntityCreateFullWidth(
          context,
          '/invoices',
          extra: cloneToInvoice(billingCloneFromRecurringInvoice(ri)),
        );

      case RecurringInvoiceAction.cloneToQuote:
        goEntityCreateFullWidth(
          context,
          '/quotes',
          extra: cloneToQuote(billingCloneFromRecurringInvoice(ri)),
        );

      case RecurringInvoiceAction.cloneToCredit:
        goEntityCreateFullWidth(
          context,
          '/credits',
          extra: cloneToCredit(billingCloneFromRecurringInvoice(ri)),
        );

      case RecurringInvoiceAction.cloneToPurchaseOrder:
        goEntityCreateFullWidth(
          context,
          '/purchase_orders',
          extra: cloneToPurchaseOrder(billingCloneFromRecurringInvoice(ri)),
        );

      case RecurringInvoiceAction.addComment:
        if (tmpGate()) return;
        final text = await showAddCommentPrompt(context);
        if (text == null || !context.mounted) return;
        await services.recurringInvoices.addComment(
          companyId: companyId,
          recurringInvoiceId: ri.id,
          text: text,
        );

      case RecurringInvoiceAction.archive:
        if (tmpGate()) return;
        await StandardEntityActions.archive(
          context: context,
          wireName: 'recurring_invoice',
          op: () => services.recurringInvoices.archive(
            companyId: companyId,
            id: ri.id,
          ),
          undoOp: () => services.recurringInvoices.restore(
            companyId: companyId,
            id: ri.id,
          ),
        );

      case RecurringInvoiceAction.restore:
        if (tmpGate()) return;
        await StandardEntityActions.restore(
          context: context,
          wireName: 'recurring_invoice',
          op: () => services.recurringInvoices.restore(
            companyId: companyId,
            id: ri.id,
          ),
        );

      case RecurringInvoiceAction.delete:
        if (tmpGate()) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'recurring_invoice',
          op: () => services.recurringInvoices.delete(
            companyId: companyId,
            id: ri.id,
          ),
          undoOp: () => services.recurringInvoices.restore(
            companyId: companyId,
            id: ri.id,
          ),
        );

      case RecurringInvoiceAction.runTemplate:
        if (tmpGate()) return;
        final templateId = await showRunTemplateDialog(context);
        if (templateId == null || !context.mounted) return;
        await services.recurringInvoices.runTemplate(
          companyId: companyId,
          id: ri.id,
          templateId: templateId,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('template_queued'));
    }
  }
}
