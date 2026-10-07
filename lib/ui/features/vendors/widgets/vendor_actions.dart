import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/phone/phone_candidates.dart';
import 'package:admin/domain/quick_create.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/activity_note_actions.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/utils/mail_actions.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/party_call_button.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_edit_view_model.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_edit_view_model.dart';
import 'package:admin/ui/features/vendors/widgets/detail/merge_vendor_dialog.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_email_candidates.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_portal.dart';

/// Full action set surfaced for a vendor. Mirrors the actions exposed in
/// admin-portal's `vendor_model.dart#getActions`. Consumed by both the
/// detail-screen header and the list-row popup so the two surfaces stay
/// in sync — see [VendorActions.itemsFor].
enum VendorAction {
  edit,
  vendorPortal,
  addComment,
  logCall,

  /// Quick-action strip only — see [VendorActions.quickItemsFor]. Not in
  /// [VendorActions.itemsFor], so they reach neither the `⋮` menu, the list
  /// row's menu, nor the edit screen.
  call,
  email,
  clone,
  newGroup,
  newExpense,
  newPurchaseOrder,
  newRecurringExpense,
  merge,
  copyLink,
  archive,
  restore,
  delete,
}

/// Single source of truth for what vendor actions exist and what they do.
class VendorActions {
  VendorActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// archive / restore / delete.
  static bool isLifecycle(VendorAction action) {
    switch (action) {
      case VendorAction.clone:
      case VendorAction.archive:
      case VendorAction.restore:
      case VendorAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// Item list shown by both the detail header row and the list-row popup.
  /// [onTap] receives the action; the caller wires it to [dispatch] (or
  /// any other handler).
  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(Vendor vendor) => vendor.name;

  static List<EntityActionItem<VendorAction>> itemsFor(
    BuildContext context,
    Vendor vendor,
    void Function(VendorAction) onTap,
  ) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    // Archive, restore and delete all need `edit_vendor`: the server
    // authorizes each through `EntityPolicy::edit` (there is no `delete_*`
    // permission). Ungated, a view-only user was offered Restore — one tap
    // from the record's state banner — for a mutation the server refuses.
    // The server's rule, not just the permission: the record's creator or
    // assignee may change it too (`AuthSession.canEditRecord`).
    final canEditVendor =
        context.read<Services>().auth.session.value?.canEditRecord(
          'vendor',
          createdBy: vendor.userId,
          assignedTo: vendor.assignedUserId,
          recordId: vendor.id,
        ) ??
        false;
    final canArchive =
        canEditVendor && vendor.archivedAt == null && !vendor.isDeleted;
    final canRestore =
        canEditVendor && (vendor.archivedAt != null || vendor.isDeleted);
    final isAdminOrOwner = (me?.isAdmin ?? false) || (me?.isOwner ?? false);

    // The primary contact (falling back to the first) carries the portal
    // link. A `tmp_` vendor's contacts have no server link yet, so the action
    // disables itself rather than opening a dead URL.
    final portalContact = vendor.contacts.isEmpty
        ? null
        : vendor.contacts.firstWhere(
            (c) => c.isPrimary,
            orElse: () => vendor.contacts.first,
          );
    final hasPortalLink =
        (portalContact?.link.isNotEmpty ?? false) &&
        !vendor.id.startsWith('tmp_');

    // A create action needs its module AND the `create_<entity>` permission.
    // The module alone used to decide, which offered New Expense to a user the
    // server would then refuse — and edit rights never imply create.
    bool canCreate(EntityType type) =>
        (me?.moduleEnabled(type) ?? false) &&
        (me?.can(createPermissionFor(type)) ?? false);
    final createChildren = <EntityActionItem<VendorAction>>[
      if (canCreate(EntityType.expense))
        EntityActionItem(
          kind: VendorAction.newExpense,
          icon: Icons.attach_money,
          label: context.tr('new_expense'),
          enabled: true,
          onTap: () => onTap(VendorAction.newExpense),
        ),
      if (canCreate(EntityType.purchaseOrder))
        EntityActionItem(
          kind: VendorAction.newPurchaseOrder,
          icon: Icons.shopping_bag_outlined,
          label: context.tr('new_purchase_order'),
          enabled: true,
          onTap: () => onTap(VendorAction.newPurchaseOrder),
        ),
      if (canCreate(EntityType.recurringExpense))
        EntityActionItem(
          kind: VendorAction.newRecurringExpense,
          icon: Icons.event_repeat_outlined,
          label: context.tr('new_recurring_expense'),
          enabled: true,
          onTap: () => onTap(VendorAction.newRecurringExpense),
        ),
    ];

    return [
      // Single-record view / create / clone actions. Hidden entirely on a
      // soft-deleted vendor — only Copy Link and Restore remain: the server
      // refuses an edit of a deleted record, and a note or a new expense
      // against one is not something to offer beside "This record is deleted".
      if (!vendor.isDeleted) ...[
        editActionItem(
          context: context,
          kind: VendorAction.edit,
          onTap: () => onTap(VendorAction.edit),
        ),
        EntityActionItem(
          kind: VendorAction.vendorPortal,
          icon: Icons.cloud_outlined,
          label: context.tr('vendor_portal'),
          // Opens the primary contact's portal with silent auto-login.
          enabled: hasPortalLink,
          onTap: () => onTap(VendorAction.vendorPortal),
        ),
        EntityActionItem(
          kind: VendorAction.addComment,
          icon: Icons.add_comment_outlined,
          label: context.tr('add_comment'),
          enabled: true,
          startsGroup: true,
          onTap: () => onTap(VendorAction.addComment),
        ),
        EntityActionItem(
          kind: VendorAction.logCall,
          icon: Icons.phone_in_talk_outlined,
          label: context.tr('log_call'),
          enabled: true,
          onTap: () => onTap(VendorAction.logCall),
        ),
        if (createChildren.isNotEmpty)
          newGroupActionItem(
            context: context,
            kind: VendorAction.newGroup,
            children: createChildren,
            startsGroup: true,
          ),
        // The record-keeping tools, after everything a user does day to day.
        EntityActionItem(
          kind: VendorAction.clone,
          icon: Icons.copy_outlined,
          label: context.tr('clone'),
          enabled: true,
          startsGroup: true,
          onTap: () => onTap(VendorAction.clone),
        ),
      ],
      // Merge is admin/owner-only and never offered on a deleted vendor.
      if (isAdminOrOwner && !vendor.isDeleted)
        EntityActionItem(
          kind: VendorAction.merge,
          icon: Icons.merge_type,
          label: context.tr('merge'),
          // Destructive + server round-trip: only on a synced, active vendor.
          enabled: vendor.archivedAt == null && !vendor.id.startsWith('tmp_'),
          onTap: () => onTap(VendorAction.merge),
        ),
      ?copyLinkActionItem(
        context: context,
        kind: VendorAction.copyLink,
        entityId: vendor.id,
        onTap: () => onTap(VendorAction.copyLink),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(vendor),
        kind: VendorAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(VendorAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: VendorAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(VendorAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        subject: _confirmSubject(vendor),
        kind: VendorAction.delete,
        canDelete: canEditVendor && !vendor.isDeleted,
        onTap: () => onTap(VendorAction.delete),
      ),
    ];
  }

  /// The vendor screen's quick-action strip, most-used first. The strip shows
  /// the first few that apply (`pickQuickActions`); the rest stay one tap
  /// further away in the `⋮` menu, which still lists everything.
  ///
  /// Every tile but Email and Call is the *same item* [itemsFor] builds,
  /// looked up by kind, so its module and permission gates and its unsynced
  /// guard cannot drift from the menu's.
  ///
  /// The order is what a user does from a vendor, most often first: record
  /// what was spent, order from them, write, ring — then the two that are
  /// set up once (a recurring expense, the vendor's own portal).
  ///
  /// **Read under a `PhoneActionsScope`** — Call depends on the tap-to-call
  /// preference, and a detail screen stays mounted behind `/settings`.
  static List<EntityQuickAction<VendorAction>> quickItemsFor(
    BuildContext context,
    Vendor vendor,
    void Function(VendorAction) onTap,
  ) {
    // A deleted vendor is read-only, and an unsynced one would answer every
    // tile with "sync first" — the banner says that once instead.
    if (vendor.isDeleted || vendor.id.startsWith('tmp_')) return const [];
    final items = itemsFor(context, vendor, onTap);
    EntityQuickAction<VendorAction>? pick(
      VendorAction kind,
      String shortLabel,
    ) {
      final item = findActionItem<VendorAction>(items, kind);
      if (item == null) return null;
      return EntityQuickAction(item: item, shortLabel: shortLabel);
    }

    // "+ Expense", not "New Expense": the noun fits a tile in every bundled
    // locale, where the verb phrase does not. One word each — "Purchase
    // Order" is three in French and Spanish and scaled down to a visibly
    // smaller label than its neighbours on a phone, so that tile says
    // "+ Order" (beside a vendor's name there is only one kind), and
    // "Recurring Expense" says "+ Recurring" beside "+ Expense". The tooltip
    // and the screen reader get the full label either way.
    String create(String nounKey) => '+ ${context.tr(nounKey)}';

    final canCall =
        context.read<Services>().phoneActions.value.tapToCall &&
        vendorPhoneCandidates(vendor).isNotEmpty;
    return [
      ?pick(VendorAction.newExpense, create('expense')),
      ?pick(VendorAction.newPurchaseOrder, create('order')),
      EntityQuickAction(
        item: EntityActionItem(
          kind: VendorAction.email,
          icon: Icons.mail_outline,
          label: context.tr('email'),
          // No contact with a usable address: no tile, rather than one that
          // opens a blank message to nobody.
          enabled: vendorEmailCandidates(vendor).isNotEmpty,
          onTap: () => onTap(VendorAction.email),
        ),
        shortLabel: context.tr('email'),
      ),
      EntityQuickAction(
        item: EntityActionItem(
          kind: VendorAction.call,
          icon: Icons.call_outlined,
          label: context.tr('call'),
          enabled: canCall,
          onTap: () => onTap(VendorAction.call),
        ),
        shortLabel: context.tr('call'),
      ),
      ?pick(VendorAction.newRecurringExpense, create('recurring')),
      // Hidden when no contact has a portal link — the item is disabled then.
      ?pick(VendorAction.vendorPortal, context.tr('vendor_portal')),
    ];
  }

  /// Runs [action] for [vendor]. Single dispatch path for both the
  /// detail-screen header and the list-row popup. Mirrors
  /// `ClientActions.dispatch`.
  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    Vendor vendor,
    VendorAction action,
  ) async {
    switch (action) {
      case VendorAction.newGroup:
        break; // Submenu parent — never dispatched; children carry the action.
      case VendorAction.edit:
        goEntityEdit(context, '/vendors', vendor.id);
      case VendorAction.copyLink:
        await copyEntityLink(context, EntityType.vendor, vendor.id);
      case VendorAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'vendor',
          op: () =>
              services.vendors.archive(companyId: companyId, id: vendor.id),
          undoOp: () =>
              services.vendors.restore(companyId: companyId, id: vendor.id),
        );
      case VendorAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'vendor',
          op: () =>
              services.vendors.restore(companyId: companyId, id: vendor.id),
        );
      case VendorAction.logCall:
        await promptLogCallFor(
          context,
          companyId: companyId,
          entityId: vendor.id,
          subject: _confirmSubject(vendor),
          vendorId: vendor.id,
          submit: (text) => services.vendors.addComment(
            companyId: companyId,
            entityId: vendor.id,
            text: text,
          ),
        );
      case VendorAction.call:
        // No `onViewParty`: this is the party's own screen. No `clientId`
        // either — a vendor has no timezone of its own, so the out-of-hours
        // check uses the company's.
        await pickAndCallPhone(
          context,
          candidates: vendorPhoneCandidates(vendor),
          partyName: vendor.name,
          logTarget: (
            type: EntityType.vendor,
            id: vendor.id,
            subject: _confirmSubject(vendor),
          ),
        );
      case VendorAction.email:
        await pickAndComposeEmail(
          context,
          candidates: vendorEmailCandidates(vendor),
          partyName: vendor.name,
        );
      case VendorAction.addComment:
        await promptAddCommentFor(
          context,
          entityId: vendor.id,
          submit: (text) => services.vendors.addComment(
            companyId: companyId,
            entityId: vendor.id,
            text: text,
          ),
        );
      case VendorAction.clone:
        final draft = vendor.copyWith(
          id: '',
          number: '',
          archivedAt: null,
          isDeleted: false,
          isDirty: false,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          contacts: [
            for (final c in vendor.contacts)
              c.copyWith(
                id: '',
                updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
                isDeleted: false,
              ),
          ],
        );
        goEntityCreateFullWidth(context, '/vendors', extra: draft);
      case VendorAction.newExpense:
        if (!requireSynced(context, vendor.id)) return;
        goEntityCreateFullWidth(
          context,
          '/expenses',
          extra: emptyExpense().copyWith(vendorId: vendor.id),
        );
      case VendorAction.newPurchaseOrder:
        if (!requireSynced(context, vendor.id)) return;
        goEntityCreateFullWidth(
          context,
          '/purchase_orders',
          extra: emptyPurchaseOrder().copyWith(vendorId: vendor.id),
        );
      case VendorAction.newRecurringExpense:
        if (!requireSynced(context, vendor.id)) return;
        goEntityCreateFullWidth(
          context,
          '/recurring_expenses',
          extra: emptyRecurringExpense().copyWith(vendorId: vendor.id),
        );
      case VendorAction.vendorPortal:
        if (!requireSynced(context, vendor.id)) return;
        // Open the primary contact's portal (falling back to the first). The
        // item is disabled in itemsFor when no link exists, so the empty-url
        // guard here is just defensive.
        final portalContact = vendor.contacts.isEmpty
            ? null
            : vendor.contacts.firstWhere(
                (c) => c.isPrimary,
                orElse: () => vendor.contacts.first,
              );
        final portalUrl = portalContact == null
            ? ''
            : vendorPortalUrl(contactLink: portalContact.link);
        if (portalUrl.isEmpty) return;
        await launchVendorPortal(context, portalUrl);
      case VendorAction.merge:
        if (!requireSynced(context, vendor.id)) return;
        final survivor = await showMergeVendorDialog(
          context,
          services: services,
          companyId: companyId,
          source: vendor,
        );
        if (survivor == null || !context.mounted) return;
        try {
          // Password-gated server-side; the outbox 412 gate surfaces the
          // ConfirmPasswordSheet exactly as it does for delete/purge.
          await services.vendors.merge(
            companyId: companyId,
            mergeIntoId: survivor.id,
            mergeFromId: vendor.id,
          );
          if (!context.mounted) return;
          Notify.success(context, context.tr('merged_vendors'));
          // The absorbed vendor's detail route is now dead — leave it.
          context.go('/vendors');
        } catch (e) {
          if (context.mounted) {
            Notify.error(context, context.tr('could_not_save'), error: e);
          }
        }
      case VendorAction.delete:
        if (!requireSynced(context, vendor.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'vendor',
          op: () =>
              services.vendors.delete(companyId: companyId, id: vendor.id),
          undoOp: () =>
              services.vendors.restore(companyId: companyId, id: vendor.id),
        );
    }
  }
}
