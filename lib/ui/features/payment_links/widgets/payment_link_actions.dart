import 'package:flutter/material.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';

/// Action set surfaced for a Payment Link. Standard minimum surface —
/// edit / archive / restore / delete — mirroring
/// [ExpenseCategoryAction]. No clone today.
enum PaymentLinkAction { edit, archive, restore, delete }

/// Single source of truth for what PaymentLink actions exist and what
/// they do. Consumed by the list-row popup, detail header, and edit
/// screen's overflow menu.
class PaymentLinkActions {
  PaymentLinkActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops archive /
  /// restore / delete.
  static bool isLifecycle(PaymentLinkAction action) {
    switch (action) {
      case PaymentLinkAction.archive:
      case PaymentLinkAction.restore:
      case PaymentLinkAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(PaymentLink paymentLink) => paymentLink.name;

  static List<EntityActionItem<PaymentLinkAction>> itemsFor(
    BuildContext context,
    PaymentLink paymentLink,
    void Function(PaymentLinkAction) onTap,
  ) {
    final canArchive = paymentLink.archivedAt == null && !paymentLink.isDeleted;
    final canRestore = paymentLink.archivedAt != null || paymentLink.isDeleted;

    return [
      editActionItem(
        context: context,
        kind: PaymentLinkAction.edit,
        onTap: () => onTap(PaymentLinkAction.edit),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(paymentLink),
        kind: PaymentLinkAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(PaymentLinkAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: PaymentLinkAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(PaymentLinkAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        subject: _confirmSubject(paymentLink),
        kind: PaymentLinkAction.delete,
        canDelete: !paymentLink.isDeleted,
        onTap: () => onTap(PaymentLinkAction.delete),
      ),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    PaymentLink paymentLink,
    PaymentLinkAction action,
  ) async {
    switch (action) {
      case PaymentLinkAction.edit:
        goEntityEdit(context, '/settings/payment_links', paymentLink.id);
      case PaymentLinkAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'payment_link',
          op: () => services.paymentLinks.archive(
            companyId: companyId,
            id: paymentLink.id,
          ),
          undoOp: () => services.paymentLinks.restore(
            companyId: companyId,
            id: paymentLink.id,
          ),
        );
      case PaymentLinkAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'payment_link',
          op: () => services.paymentLinks.restore(
            companyId: companyId,
            id: paymentLink.id,
          ),
        );
      case PaymentLinkAction.delete:
        if (!requireSynced(context, paymentLink.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'payment_link',
          op: () => services.paymentLinks.delete(
            companyId: companyId,
            id: paymentLink.id,
          ),
          undoOp: () => services.paymentLinks.restore(
            companyId: companyId,
            id: paymentLink.id,
          ),
        );
    }
  }
}
