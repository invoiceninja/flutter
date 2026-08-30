import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/payment_link.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';

/// Action set surfaced for a Payment Link. The standard minimum surface —
/// edit / archive / restore / delete — plus `clone`, which duplicates a
/// link into a fresh create form (invoiceninja/flutter#62: setting up
/// per-duration tiers of the same product otherwise means rebuilding all
/// four tabs by hand).
enum PaymentLinkAction { edit, clone, copyLink, archive, restore, delete }

/// Single source of truth for what PaymentLink actions exist and what
/// they do. Consumed by the list-row popup, detail header, and edit
/// screen's overflow menu.
class PaymentLinkActions {
  PaymentLinkActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// archive / restore / delete.
  static bool isLifecycle(PaymentLinkAction action) {
    switch (action) {
      case PaymentLinkAction.clone:
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

  /// Build the create-form draft for a clone. Strips identity + lifecycle
  /// fields so the create scaffold calls `repo.create(...)` (empty id), and
  /// clears the server-owned `purchasePage` / `planMap`: `purchasePage` is
  /// built from the *source's* hashed id and
  /// `PaymentLinkRepository._domainToCompanion` persists it into the local
  /// row, so carrying it over would show — and let the user copy — the
  /// source link's public purchase URL on the clone's own detail screen
  /// until the create drains.
  ///
  /// The name gets a `(copy)` suffix because the server requires `name` to
  /// be present *and* unique per company (`StoreSubscriptionRequest`, whose
  /// uniqueness check doesn't exclude soft-deleted rows) — a verbatim copy
  /// would 422 on every clone. Same convention as the gateway clone in
  /// [CompanyGatewayActions]. A residual collision (cloning the same link
  /// twice without renaming) surfaces inline on the Name field via
  /// `vm.fieldErrorFor('name')`.
  ///
  /// Everything else carries over deliberately: the four `*productIds`
  /// fields are shared product *references*, not owned children, and
  /// `webhookConfiguration` is a value object with no ids. `userId` /
  /// `companyId` are left alone (as in every other `cloneDraftFor`) — they
  /// are never sent on create and `applyCreateResponse` overwrites them.
  static PaymentLink cloneDraftFor(PaymentLink paymentLink) =>
      paymentLink.copyWith(
        id: '',
        name: paymentLink.name.isEmpty ? '' : '${paymentLink.name} (copy)',
        purchasePage: '',
        planMap: '',
        archivedAt: null,
        isDeleted: false,
        isDirty: false,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );

  static List<EntityActionItem<PaymentLinkAction>> itemsFor(
    BuildContext context,
    PaymentLink paymentLink,
    void Function(PaymentLinkAction) onTap,
  ) {
    final canArchive = paymentLink.archivedAt == null && !paymentLink.isDeleted;
    final canRestore = paymentLink.archivedAt != null || paymentLink.isDeleted;
    // Same gate as the list's New button (`canCreate: hasAccess`) — Clone is
    // a create affordance and `payment_links` is Pro-gated
    // (`kProGatedSettings`). Without it, Clone would be a create path that
    // reopens the hole the New-button gate closes, since the `/new` route
    // itself is ungated. Self-hosted always qualifies (`isProPlan` short-
    // circuits on `isSelfHosted`).
    final hasProAccess =
        context.read<Services>().auth.session.value?.hasProAccess ?? false;

    return [
      editActionItem(
        context: context,
        kind: PaymentLinkAction.edit,
        onTap: () => onTap(PaymentLinkAction.edit),
      ),
      EntityActionItem(
        kind: PaymentLinkAction.clone,
        icon: Icons.copy_outlined,
        label: context.tr('clone'),
        enabled: hasProAccess,
        onTap: () => onTap(PaymentLinkAction.clone),
      ),
      ?copyLinkActionItem(
        context: context,
        kind: PaymentLinkAction.copyLink,
        entityId: paymentLink.id,
        onTap: () => onTap(PaymentLinkAction.copyLink),
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
      case PaymentLinkAction.clone:
        // Client-side clone: seed the create form, no server round-trip (the
        // subscriptions route is a plain `Route::resource` — there is no
        // clone endpoint). Both `/settings/payment_links/new` registrations
        // already read the seed off `state.extra`.
        goEntityCreateFullWidth(
          context,
          '/settings/payment_links',
          extra: cloneDraftFor(paymentLink),
        );
      case PaymentLinkAction.copyLink:
        await copyEntityLink(context, EntityType.paymentLink, paymentLink.id);
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
