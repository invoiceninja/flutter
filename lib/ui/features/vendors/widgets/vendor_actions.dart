import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/notify_async.dart';
import 'package:admin/ui/features/clients/widgets/detail/add_comment_dialog.dart';
import 'package:admin/ui/features/expenses/view_models/expense_edit_view_model.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_edit_view_model.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_edit_view_model.dart';
import 'package:admin/ui/features/vendors/widgets/detail/merge_vendor_dialog.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_portal.dart';

/// Full action set surfaced for a vendor. Mirrors the actions exposed in
/// admin-portal's `vendor_model.dart#getActions`. Consumed by both the
/// detail-screen header and the list-row popup so the two surfaces stay
/// in sync — see [VendorActions.itemsFor].
enum VendorAction {
  edit,
  vendorPortal,
  addComment,
  clone,
  newExpense,
  newPurchaseOrder,
  newRecurringExpense,
  merge,
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
    final canArchive = vendor.archivedAt == null && !vendor.isDeleted;
    final canRestore = vendor.archivedAt != null || vendor.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;
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

    return [
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
        onTap: () => onTap(VendorAction.addComment),
      ),
      EntityActionItem(
        kind: VendorAction.clone,
        icon: Icons.copy_outlined,
        label: context.tr('clone'),
        enabled: true,
        onTap: () => onTap(VendorAction.clone),
      ),
      if (me?.moduleEnabled(EntityType.expense) ?? false)
        EntityActionItem(
          kind: VendorAction.newExpense,
          icon: Icons.attach_money,
          label: context.tr('new_expense'),
          enabled: true,
          onTap: () => onTap(VendorAction.newExpense),
        ),
      if (me?.moduleEnabled(EntityType.purchaseOrder) ?? false)
        EntityActionItem(
          kind: VendorAction.newPurchaseOrder,
          icon: Icons.shopping_bag_outlined,
          label: context.tr('new_purchase_order'),
          enabled: true,
          onTap: () => onTap(VendorAction.newPurchaseOrder),
        ),
      if (me?.moduleEnabled(EntityType.recurringExpense) ?? false)
        EntityActionItem(
          kind: VendorAction.newRecurringExpense,
          icon: Icons.event_repeat_outlined,
          label: context.tr('new_recurring_expense'),
          enabled: true,
          onTap: () => onTap(VendorAction.newRecurringExpense),
        ),
      if (isAdminOrOwner && !vendor.isDeleted)
        EntityActionItem(
          kind: VendorAction.merge,
          icon: Icons.merge_type,
          label: context.tr('merge'),
          // Destructive + server round-trip: only on a synced, active vendor.
          enabled: vendor.archivedAt == null && !vendor.id.startsWith('tmp_'),
          onTap: () => onTap(VendorAction.merge),
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
        canDelete: !vendor.isDeleted,
        onTap: () => onTap(VendorAction.delete),
      ),
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
      case VendorAction.edit:
        goEntityEdit(context, '/vendors', vendor.id);
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
      case VendorAction.addComment:
        // `tmp_` vendors only exist locally — the server has no row to
        // attach a comment to yet. Block instead of enqueuing a comment
        // that the dispatcher would 404 once the create round-trips.
        if (!requireSynced(context, vendor.id)) return;
        final text = await showAddCommentDialog(context);
        if (text == null || text.isEmpty || !context.mounted) return;
        await runMutationWithNotify(
          context,
          () => services.vendors.addComment(
            companyId: companyId,
            vendorId: vendor.id,
            text: text,
          ),
          successMsg: context.tr('added_comment'),
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
