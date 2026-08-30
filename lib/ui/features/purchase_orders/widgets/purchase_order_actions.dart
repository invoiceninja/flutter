import 'dart:async';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/invitation.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/purchase_order.dart';
import 'package:admin/data/models/domain/purchase_order_status.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/actions/add_comment_prompt.dart';
import 'package:admin/ui/features/billing_shared/billing_cross_clone.dart';
import 'package:admin/ui/features/invoices/widgets/detail/run_template_dialog.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_portal.dart';

/// PurchaseOrder action set. Mirrors Quote/Credit actions plus the
/// PO-specific actions (`addToInventory`, `convertToExpense`/`viewExpense`,
/// `vendorPortal`); drops conversion actions and the cloneToRecurring target
/// (no recurring POs). There is intentionally **no admin `accept`** — a PO is
/// accepted by the vendor via the portal; the server has no admin accept
/// route (not in the `/bulk` allow-list, `?accept=true` is ignored).
enum PurchaseOrderAction {
  edit,
  pdfGroup,
  viewPdf,
  downloadPdf,
  printPdf,
  downloadEPurchaseOrder,
  sendEmail,
  scheduleEmail,
  markSent,
  cancel,
  addToInventory,
  convertToExpense,
  viewExpense,
  vendorPortal,
  cloneGroup,
  clone,
  cloneToInvoice,
  cloneToQuote,
  cloneToCredit,
  runTemplate,
  addComment,
  copyLink,
  archive,
  restore,
  delete,
}

class PurchaseOrderActions {
  PurchaseOrderActions._();

  /// SAVE-PARAM classifier (edit-screen action bar). Non-null => the
  /// action is performed *by* the create/update request via these query
  /// params (server creates/updates and acts atomically — no temp-id
  /// gap). Only `mark_sent` qualifies for POs — the server's
  /// `TriggeredActions` honors `mark_sent` / `send_email` but **not**
  /// `accept`. `sendEmail` is intentionally **not** here — it is an
  /// after-save separate request.
  static Map<String, String>? saveParamFor(PurchaseOrderAction action) {
    switch (action) {
      case PurchaseOrderAction.markSent:
        return const {'mark_sent': 'true'};
      default:
        return null;
    }
  }

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// archive / restore / delete (the clone group collapses as a whole).
  static bool isLifecycle(PurchaseOrderAction action) {
    switch (action) {
      case PurchaseOrderAction.cloneGroup:
      case PurchaseOrderAction.clone:
      case PurchaseOrderAction.cloneToInvoice:
      case PurchaseOrderAction.cloneToQuote:
      case PurchaseOrderAction.cloneToCredit:
      case PurchaseOrderAction.archive:
      case PurchaseOrderAction.restore:
      case PurchaseOrderAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// After-save actions whose [dispatch] navigates unconditionally; the
  /// create-mode edit scaffold uses this to keep that navigation instead of
  /// redirecting to the detail screen. See `InvoiceActions.navigatesOnCreate`.
  static bool navigatesOnCreate(PurchaseOrderAction action) {
    switch (action) {
      case PurchaseOrderAction.sendEmail:
      case PurchaseOrderAction.scheduleEmail:
      case PurchaseOrderAction.viewPdf:
        return true;
      default:
        return false;
    }
  }

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(PurchaseOrder po) =>
      po.number.isEmpty ? '' : '#${po.number}';

  static List<EntityActionItem<PurchaseOrderAction>> itemsFor(
    BuildContext context,
    PurchaseOrder po,
    void Function(PurchaseOrderAction) onTap, {
    String? eInvoiceType,
  }) {
    final canArchive = po.archivedAt == null && !po.isDeleted;
    final canRestore = po.archivedAt != null || po.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final canEdit = me?.can('edit_purchase_order') ?? false;
    final canCreate = me?.can('create_purchase_order') ?? false;
    final canDelete = me?.can('edit_purchase_order') ?? false;
    final canMarkSent = canEdit && po.isDraft;
    // Server cancels a PO while `status_id <= SENT` (Draft or Sent) and
    // silently no-ops for Accepted/Received (`PurchaseOrderController` cancel
    // guard). Match that — a Draft can be cancelled as well as deleted.
    final canCancel = canEdit && (po.isDraft || po.isSent);
    // `add_to_inventory` moves an Accepted PO → Received (server guards on
    // `status_id < RECEIVED`). Matches React/legacy (Accepted-only).
    final canAddToInventory = canEdit && po.isAccepted;
    final expenseModuleEnabled = me?.moduleEnabled(EntityType.expense) ?? false;
    // Convert is offered while no expense exists yet (any status — the server
    // has no status guard, only a duplicate guard). Once expensed, we show
    // "View expense" instead.
    final hasExpense = po.expenseId.isNotEmpty;
    final portalLink = _firstPortalLink(po);
    final invitationKey = _firstInvitationKey(po);
    // e-PO download needs an e-invoice channel configured on the company plus
    // a vendor-portal invitation to key the authenticated download route.
    // Hidden (not disabled) otherwise — mirrors the invoice e-invoice gates.
    final canDownloadEInvoice =
        (eInvoiceType ?? '').isNotEmpty &&
        invitationKey.isNotEmpty &&
        !po.isDeleted;

    return [
      if (canEdit)
        editActionItem(
          context: context,
          kind: PurchaseOrderAction.edit,
          onTap: () => onTap(PurchaseOrderAction.edit),
        ),
      pdfGroupActionItem(
        context: context,
        kind: PurchaseOrderAction.pdfGroup,
        children: [
          EntityActionItem(
            kind: PurchaseOrderAction.viewPdf,
            icon: Icons.picture_as_pdf_outlined,
            label: context.tr('view_pdf'),
            enabled: true,
            onTap: () => onTap(PurchaseOrderAction.viewPdf),
          ),
          EntityActionItem(
            kind: PurchaseOrderAction.downloadPdf,
            icon: Icons.download_outlined,
            label: context.tr('download_pdf'),
            enabled: true,
            onTap: () => onTap(PurchaseOrderAction.downloadPdf),
          ),
          EntityActionItem(
            kind: PurchaseOrderAction.printPdf,
            icon: Icons.print_outlined,
            label: context.tr('print_pdf'),
            enabled: true,
            onTap: () => onTap(PurchaseOrderAction.printPdf),
          ),
        ],
      ),
      if (canDownloadEInvoice)
        EntityActionItem(
          kind: PurchaseOrderAction.downloadEPurchaseOrder,
          icon: Icons.code_outlined,
          label: context.tr('download_e_purchase_order'),
          enabled: true,
          onTap: () => onTap(PurchaseOrderAction.downloadEPurchaseOrder),
        ),
      EntityActionItem(
        kind: PurchaseOrderAction.sendEmail,
        icon: Icons.mail_outline,
        label: context.tr('send_email'),
        enabled: canEdit,
        onTap: () => onTap(PurchaseOrderAction.sendEmail),
      ),
      EntityActionItem(
        kind: PurchaseOrderAction.markSent,
        confirm: true,
        confirmSubject: _confirmSubject(po),
        icon: Icons.send_outlined,
        label: context.tr('mark_sent'),
        enabled: canMarkSent,
        onTap: () => onTap(PurchaseOrderAction.markSent),
      ),
      EntityActionItem(
        kind: PurchaseOrderAction.addToInventory,
        confirm: true,
        confirmSubject: _confirmSubject(po),
        icon: Icons.inventory_2_outlined,
        label: context.tr('add_to_inventory'),
        enabled: canAddToInventory,
        onTap: () => onTap(PurchaseOrderAction.addToInventory),
      ),
      if (expenseModuleEnabled && !hasExpense)
        EntityActionItem(
          kind: PurchaseOrderAction.convertToExpense,
          confirm: true,
          confirmSubject: _confirmSubject(po),
          icon: Icons.receipt_outlined,
          label: context.tr('convert_to_expense'),
          enabled: canEdit,
          onTap: () => onTap(PurchaseOrderAction.convertToExpense),
        ),
      if (expenseModuleEnabled && hasExpense)
        EntityActionItem(
          kind: PurchaseOrderAction.viewExpense,
          icon: Icons.receipt_long_outlined,
          // `view_expense_label`, not `view_expense` — the Transifex string is
          // "View expense # :expense" and this menu names no expense number.
          label: context.tr('view_expense_label'),
          enabled: true,
          onTap: () => onTap(PurchaseOrderAction.viewExpense),
        ),
      EntityActionItem(
        kind: PurchaseOrderAction.cancel,
        confirm: true,
        confirmSubject: _confirmSubject(po),
        icon: Icons.cancel_outlined,
        label: context.tr('cancel_purchase_order'),
        enabled: canCancel,
        onTap: () => onTap(PurchaseOrderAction.cancel),
      ),
      if (portalLink.isNotEmpty)
        EntityActionItem(
          kind: PurchaseOrderAction.vendorPortal,
          icon: Icons.open_in_new_outlined,
          label: context.tr('vendor_portal'),
          enabled: true,
          onTap: () => onTap(PurchaseOrderAction.vendorPortal),
        ),
      if (canCreate)
        cloneGroupActionItem(
          context: context,
          kind: PurchaseOrderAction.cloneGroup,
          children: [
            EntityActionItem(
              kind: PurchaseOrderAction.clone,
              icon: Icons.copy_outlined,
              label: context.tr('clone_purchase_order'),
              enabled: true,
              onTap: () => onTap(PurchaseOrderAction.clone),
            ),
            if (me?.moduleEnabled(EntityType.invoice) ?? false)
              EntityActionItem(
                kind: PurchaseOrderAction.cloneToInvoice,
                icon: Icons.receipt_long_outlined,
                label: context.tr('clone_to_invoice'),
                enabled: true,
                onTap: () => onTap(PurchaseOrderAction.cloneToInvoice),
              ),
            if (me?.moduleEnabled(EntityType.quote) ?? false)
              EntityActionItem(
                kind: PurchaseOrderAction.cloneToQuote,
                icon: Icons.request_quote_outlined,
                label: context.tr('clone_to_quote'),
                enabled: true,
                onTap: () => onTap(PurchaseOrderAction.cloneToQuote),
              ),
            if (me?.moduleEnabled(EntityType.credit) ?? false)
              EntityActionItem(
                kind: PurchaseOrderAction.cloneToCredit,
                icon: Icons.assignment_return_outlined,
                label: context.tr('clone_to_credit'),
                enabled: true,
                onTap: () => onTap(PurchaseOrderAction.cloneToCredit),
              ),
          ],
        ),
      if (canEdit) ...[
        EntityActionItem(
          kind: PurchaseOrderAction.runTemplate,
          icon: Icons.auto_awesome_outlined,
          label: context.tr('run_template'),
          enabled: true,
          onTap: () => onTap(PurchaseOrderAction.runTemplate),
        ),
        EntityActionItem(
          kind: PurchaseOrderAction.addComment,
          icon: Icons.chat_bubble_outline,
          label: context.tr('add_comment'),
          enabled: true,
          onTap: () => onTap(PurchaseOrderAction.addComment),
        ),
      ],
      ?copyLinkActionItem(
        context: context,
        kind: PurchaseOrderAction.copyLink,
        entityId: po.id,
        onTap: () => onTap(PurchaseOrderAction.copyLink),
      ),
      if (canEdit)
        ?archiveActionItem(
          context: context,
          subject: _confirmSubject(po),
          kind: PurchaseOrderAction.archive,
          canArchive: canArchive,
          onTap: () => onTap(PurchaseOrderAction.archive),
        ),
      if (canEdit)
        ?restoreActionItem(
          context: context,
          kind: PurchaseOrderAction.restore,
          canRestore: canRestore,
          onTap: () => onTap(PurchaseOrderAction.restore),
        ),
      if (canDelete)
        ?deleteActionItem(
          context: context,
          subject: _confirmSubject(po),
          kind: PurchaseOrderAction.delete,
          canDelete: !po.isDeleted,
          onTap: () => onTap(PurchaseOrderAction.delete),
        ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    PurchaseOrder po,
    PurchaseOrderAction action,
  ) async {
    bool tmpGate() => !requireSynced(context, po.id);

    switch (action) {
      case PurchaseOrderAction.edit:
        goEntityEdit(context, '/purchase_orders', po.id);

      case PurchaseOrderAction.pdfGroup:
        break; // Submenu parent — never dispatched; children carry the action.

      case PurchaseOrderAction.viewPdf:
        if (tmpGate()) return;
        // `go` (not `push`): see client_actions.dart#viewStatement.
        context.go('/purchase_orders/${po.id}/pdf');

      case PurchaseOrderAction.downloadPdf:
      case PurchaseOrderAction.printPdf:
        if (tmpGate()) return;
        try {
          final bytes = await services.purchaseOrders.api.downloadPdf(
            entityJson: po.toApiJson(),
            designId: po.designId.isEmpty ? null : po.designId,
          );
          if (!context.mounted) return;
          if (action == PurchaseOrderAction.downloadPdf) {
            final fileName =
                'purchase_order_${po.number.isEmpty ? po.id : po.number}.pdf';
            await Printing.sharePdf(bytes: bytes, filename: fileName);
          } else {
            await Printing.layoutPdf(onLayout: (_) async => bytes);
          }
        } catch (e) {
          if (!context.mounted) return;
          Notify.error(context, context.tr('error'), error: e);
        }

      case PurchaseOrderAction.downloadEPurchaseOrder:
        if (tmpGate()) return;
        final invitationKey = _firstInvitationKey(po);
        if (invitationKey.isEmpty) return;
        try {
          final bytes = await services.purchaseOrders.api
              .downloadEPurchaseOrder(invitationKey: invitationKey);
          final fileName =
              'purchase_order_${po.number.isEmpty ? po.id : po.number}.xml';
          // Save arbitrary (non-PDF) bytes via the same FilePicker path the
          // CSV / JSON exports use — `Printing.sharePdf` is PDF-typed. Web:
          // the shim downloads via a Blob; native: write defensively.
          final path = await FilePicker.saveFile(
            fileName: fileName,
            bytes: bytes,
          );
          if (path == null) return;
          if (!kIsWeb) {
            final file = File(path);
            if (!await file.exists() || await file.length() == 0) {
              await file.writeAsBytes(bytes);
            }
          }
          if (!context.mounted) return;
          Notify.success(context, context.tr('exported'));
        } catch (e) {
          if (!context.mounted) return;
          Notify.error(context, context.tr('error'), error: e);
        }

      case PurchaseOrderAction.sendEmail:
      case PurchaseOrderAction.scheduleEmail:
        if (tmpGate()) return;
        // Full-screen Send Email surface; bulk multi-select still uses the
        // showBillingDocEmailSheet bottom sheet.
        context.go('/purchase_orders/${po.id}/email?view=full');

      case PurchaseOrderAction.markSent:
        if (tmpGate()) return;
        await services.purchaseOrders.markSent(companyId: companyId, id: po.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('marked_purchase_order_as_sent'));

      case PurchaseOrderAction.addToInventory:
        if (tmpGate()) return;
        await services.purchaseOrders.addToInventory(
          companyId: companyId,
          id: po.id,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('added_to_inventory'));

      case PurchaseOrderAction.cancel:
        if (tmpGate()) return;
        await services.purchaseOrders.cancel(companyId: companyId, id: po.id);
        if (!context.mounted) return;
        Notify.success(context, context.tr('cancelled_purchase_order'));

      case PurchaseOrderAction.convertToExpense:
        if (tmpGate()) return;
        await services.purchaseOrders.convertToExpense(
          companyId: companyId,
          id: po.id,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('converted_to_expense'));

      case PurchaseOrderAction.viewExpense:
        if (po.expenseId.isEmpty) return;
        // `go` (not `push`): consistent with viewPdf above.
        context.go('/expenses/${po.expenseId}');

      case PurchaseOrderAction.vendorPortal:
        final link = _firstPortalLink(po);
        if (link.isEmpty) return;
        await launchVendorPortal(context, vendorPortalUrl(contactLink: link));

      case PurchaseOrderAction.cloneGroup:
        break; // Submenu parent — never dispatched; children carry the action.
      case PurchaseOrderAction.clone:
        // Reset everything that must not carry over to a fresh draft (mirrors
        // the invoice clone). Critically `statusId`: a clone of a Sent/Accepted
        // PO must open as a Draft, not inherit "sent/accepted". Also drop dates
        // (→ today / unset), exchange rate, project link, the downstream
        // `expenseId` conversion link, and the e-invoice block. POs are
        // vendor-centric — the `vendorId` is the core party, so it is kept.
        // POs have no `partial` / `partialDueDate` / `paidToDate` /
        // `subscriptionId` fields. Invitations keep their vendor contacts but
        // drop the source's sent/viewed/bounced state (`freshClone`) so the
        // clone doesn't show a stale bounce badge / old-PO portal link.
        final draft = po.copyWith(
          id: '',
          number: '',
          statusId: PurchaseOrderStatus.draft,
          date: Date.today(),
          dueDate: null,
          taxAmount: Decimal.zero,
          balance: po.amount,
          exchangeRate: Decimal.one,
          projectId: '',
          expenseId: '',
          invitations: po.invitations.map((i) => i.freshClone()).toList(),
          eInvoice: null,
          // Sanitise the rows: drop the links back to the source task /
          // expense (else re-pointing the clone at another client dead-ends in
          // a `line_items` error with no field to fix) and drop any
          // server-generated unpaid-fee row (else the clone re-bills it).
          lineItems: clonedLineItems(po.lineItems),
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        goEntityCreateFullWidth(context, '/purchase_orders', extra: draft);

      // Cross-type clone is client-side (the server's bulk performAction has no
      // PO clone targets): invoice/quote/credit are built here and opened in
      // the target's create form. The PO is vendor-billed, so the converter
      // drops the client + vendor invitations — the user picks the client on
      // the create screen. Navigation IS the feedback — no toast, no tmp_ gate.
      case PurchaseOrderAction.cloneToInvoice:
        goEntityCreateFullWidth(
          context,
          '/invoices',
          extra: cloneToInvoice(billingCloneFromPurchaseOrder(po)),
        );

      case PurchaseOrderAction.cloneToQuote:
        goEntityCreateFullWidth(
          context,
          '/quotes',
          extra: cloneToQuote(billingCloneFromPurchaseOrder(po)),
        );

      case PurchaseOrderAction.cloneToCredit:
        goEntityCreateFullWidth(
          context,
          '/credits',
          extra: cloneToCredit(billingCloneFromPurchaseOrder(po)),
        );

      case PurchaseOrderAction.addComment:
        if (tmpGate()) return;
        final text = await showAddCommentPrompt(context);
        if (text == null || !context.mounted) return;
        await services.purchaseOrders.addComment(
          companyId: companyId,
          purchaseOrderId: po.id,
          text: text,
        );

      case PurchaseOrderAction.copyLink:
        await copyEntityLink(context, EntityType.purchaseOrder, po.id);
      case PurchaseOrderAction.archive:
        if (tmpGate()) return;
        await StandardEntityActions.archive(
          context: context,
          wireName: 'purchase_order',
          op: () =>
              services.purchaseOrders.archive(companyId: companyId, id: po.id),
          undoOp: () =>
              services.purchaseOrders.restore(companyId: companyId, id: po.id),
        );

      case PurchaseOrderAction.restore:
        if (tmpGate()) return;
        await StandardEntityActions.restore(
          context: context,
          wireName: 'purchase_order',
          op: () =>
              services.purchaseOrders.restore(companyId: companyId, id: po.id),
        );

      case PurchaseOrderAction.delete:
        if (tmpGate()) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'purchase_order',
          op: () =>
              services.purchaseOrders.delete(companyId: companyId, id: po.id),
          undoOp: () =>
              services.purchaseOrders.restore(companyId: companyId, id: po.id),
        );

      case PurchaseOrderAction.runTemplate:
        if (tmpGate()) return;
        final templateId = await showRunTemplateDialog(context);
        if (templateId == null || !context.mounted) return;
        await services.purchaseOrders.runTemplate(
          companyId: companyId,
          id: po.id,
          templateId: templateId,
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('template_queued'));
    }
  }

  /// The first vendor-invitation portal link on the PO, or `''` if none.
  /// Gates + dispatches the Vendor Portal action (empty on an unsaved/unsent
  /// draft, so the action stays hidden there).
  static String _firstPortalLink(PurchaseOrder po) {
    for (final inv in po.invitations) {
      if (inv.link.isNotEmpty) return inv.link;
    }
    return '';
  }

  /// The first invitation `key` on the PO — keys the authenticated
  /// `download_e_purchase_order` route. `''` when the PO has no invitation
  /// (unsynced / unsent), which hides the e-PO download action.
  static String _firstInvitationKey(PurchaseOrder po) {
    for (final inv in po.invitations) {
      if (inv.key.isNotEmpty) return inv.key;
    }
    return '';
  }
}
