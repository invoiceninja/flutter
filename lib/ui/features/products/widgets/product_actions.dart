import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/quick_create.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/billing_shared/seed_billing_create_defaults.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_edit_view_model.dart';
import 'package:admin/ui/features/products/widgets/tax_category_dialog.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_edit_view_model.dart';
import 'package:admin/ui/features/quotes/view_models/quote_edit_view_model.dart';

/// Action set surfaced for a product. Mirrors `ClientAction`. The
/// new-document branches seed a draft with this product as a line item;
/// `setTaxCategory` opens a fixed-catalog picker and saves via the normal
/// update outbox. Consumed by both the detail-screen header and the
/// list-row popup.
enum ProductAction {
  edit,
  newGroup,
  newInvoice,
  newQuote,
  newPurchaseOrder,
  setTaxCategory,
  clone,
  copyLink,
  archive,
  restore,
  delete,
}

/// Single source of truth for what product actions exist and what they
/// do. List-row popup and detail header both consume this — mirrors
/// admin-portal's `entity.getActions(...)` pattern.
class ProductActions {
  ProductActions._();

  /// Actions the old admin-portal hid on a brand-new (unsaved) record.
  /// Fed to `filterForEditScreen` so the create screen drops clone /
  /// archive / restore / delete.
  static bool isLifecycle(ProductAction action) {
    switch (action) {
      case ProductAction.clone:
      case ProductAction.archive:
      case ProductAction.restore:
      case ProductAction.delete:
        return true;
      default:
        return false;
    }
  }

  /// After-save actions whose [dispatch] navigates unconditionally; the
  /// create-mode edit scaffold uses this to keep that navigation instead of
  /// redirecting to the detail screen. See `InvoiceActions.navigatesOnCreate`.
  /// All three need the resolved (real) product id for their `?product=` query.
  static bool navigatesOnCreate(ProductAction action) {
    switch (action) {
      case ProductAction.newInvoice:
      case ProductAction.newQuote:
      case ProductAction.newPurchaseOrder:
        return true;
      default:
        return false;
    }
  }

  /// Build the create-form draft for a clone. Strips identity + lifecycle
  /// fields so the create scaffold calls `repo.create(...)` (empty id), and
  /// clears `documents`: those references belong to the source entity (their
  /// ids are its real document ids), so carrying them over would show the
  /// source's attachments on the clone pre-sync and let an offline delete
  /// from the clone hit the original's file. Mirrors legacy's `clone` getter.
  static Product cloneDraftFor(Product product) => product.copyWith(
    id: '',
    archivedAt: null,
    isDeleted: false,
    isDirty: false,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    documents: const [],
  );

  /// Display label for the "Are you sure?" prompt, so a confirm fired
  /// from a long list says which record it's about. Blank is fine — the
  /// dialog just omits the line.
  static String _confirmSubject(Product product) => product.productKey;

  static List<EntityActionItem<ProductAction>> itemsFor(
    BuildContext context,
    Product product,
    void Function(ProductAction) onTap,
  ) {
    final me = context.read<Services>().auth.session.value?.currentCompany;
    // Archive, restore, delete and Set Tax Category all need `edit_product`:
    // the server authorizes each through `EntityPolicy::edit` (there is no
    // `delete_*` permission). Ungated, a view-only user was offered Restore —
    // one tap from the record's state banner — for a mutation the server
    // refuses.
    // The server's rule, not just the permission: the record's creator or
    // assignee may change it too (`AuthSession.canEditRecord`).
    final canEdit =
        context.read<Services>().auth.session.value?.canEditRecord(
          'product',
          createdBy: product.userId,
          assignedTo: product.assignedUserId,
          recordId: product.id,
        ) ??
        false;
    final canArchive =
        canEdit && product.archivedAt == null && !product.isDeleted;
    final canRestore =
        canEdit && (product.archivedAt != null || product.isDeleted);
    final notTmp = !product.id.startsWith('tmp_');
    // A create action needs its module AND the `create_<entity>` permission.
    // The module alone used to decide, which offered New Invoice to a user
    // the server would then refuse — and edit rights never imply create. A
    // clone is a new product; its own module is on or this product would not
    // be on screen.
    bool canCreate(EntityType type) =>
        (me?.moduleEnabled(type) ?? false) &&
        (me?.can(createPermissionFor(type)) ?? false);
    final canClone = me?.can(createPermissionFor(EntityType.product)) ?? false;

    return [
      // Everything that changes the product, copies it or puts it on a
      // document. Hidden entirely on a soft-deleted one — only the link and
      // Restore remain, as on a deleted client: the server refuses an edit of
      // a deleted record, and the screen says it is read-only.
      if (!product.isDeleted) ...[
        editActionItem(
          context: context,
          kind: ProductAction.edit,
          onTap: () => onTap(ProductAction.edit),
        ),
        // The "New X" items collapse into one fly-out submenu (like Client)
        // so they stop burying the rest of the actions menu.
        if (canCreate(EntityType.invoice) ||
            canCreate(EntityType.quote) ||
            canCreate(EntityType.purchaseOrder))
          newGroupActionItem(
            context: context,
            kind: ProductAction.newGroup,
            children: [
              if (canCreate(EntityType.invoice))
                EntityActionItem(
                  kind: ProductAction.newInvoice,
                  icon: Icons.receipt_long_outlined,
                  label: context.tr('new_invoice'),
                  enabled: notTmp,
                  onTap: () => onTap(ProductAction.newInvoice),
                ),
              if (canCreate(EntityType.quote))
                EntityActionItem(
                  kind: ProductAction.newQuote,
                  icon: Icons.request_quote_outlined,
                  label: context.tr('new_quote'),
                  enabled: notTmp,
                  onTap: () => onTap(ProductAction.newQuote),
                ),
              if (canCreate(EntityType.purchaseOrder))
                EntityActionItem(
                  kind: ProductAction.newPurchaseOrder,
                  icon: Icons.shopping_cart_outlined,
                  label: context.tr('new_purchase_order'),
                  enabled: notTmp,
                  onTap: () => onTap(ProductAction.newPurchaseOrder),
                ),
            ],
          ),
        if (canEdit)
          EntityActionItem(
            kind: ProductAction.setTaxCategory,
            icon: Icons.percent,
            label: context.tr('set_tax_category'),
            enabled: notTmp,
            onTap: () => onTap(ProductAction.setTaxCategory),
          ),
        if (canClone)
          EntityActionItem(
            kind: ProductAction.clone,
            icon: Icons.copy_outlined,
            label: context.tr('clone_product'),
            enabled: true,
            onTap: () => onTap(ProductAction.clone),
          ),
      ],
      ?copyLinkActionItem(
        context: context,
        kind: ProductAction.copyLink,
        entityId: product.id,
        onTap: () => onTap(ProductAction.copyLink),
      ),
      ?archiveActionItem(
        context: context,
        subject: _confirmSubject(product),
        kind: ProductAction.archive,
        canArchive: canArchive,
        onTap: () => onTap(ProductAction.archive),
      ),
      ?restoreActionItem(
        context: context,
        kind: ProductAction.restore,
        canRestore: canRestore,
        onTap: () => onTap(ProductAction.restore),
      ),
      ?deleteActionItem(
        context: context,
        subject: _confirmSubject(product),
        kind: ProductAction.delete,
        canDelete: canEdit && !product.isDeleted,
        onTap: () => onTap(ProductAction.delete),
      ),
    ];
  }

  /// The product screen's quick-action strip, most-used first. The strip
  /// shows the first few that apply (`pickQuickActions`); the rest stay in the
  /// `⋮` menu, which still lists everything.
  ///
  /// Every tile is the *same item* [itemsFor] builds, looked up by kind — the
  /// three create tiles from inside the menu's Create New group — so its
  /// module and permission gates and its unsynced guard cannot drift from the
  /// menu's. What a product is *for* is being put on a document, so those
  /// lead; Clone and the tax category follow.
  static List<EntityQuickAction<ProductAction>> quickItemsFor(
    BuildContext context,
    Product product,
    void Function(ProductAction) onTap,
  ) {
    // A deleted product is read-only, and an unsynced one would answer every
    // create tile with "sync first" — the banner says that once instead.
    if (product.isDeleted || product.id.startsWith('tmp_')) return const [];
    final items = itemsFor(context, product, onTap);
    EntityQuickAction<ProductAction>? pick(
      ProductAction kind,
      String shortLabel,
    ) {
      final item = findActionItem<ProductAction>(items, kind);
      if (item == null) return null;
      return EntityQuickAction(item: item, shortLabel: shortLabel);
    }

    // "+ Invoice", not "New Invoice": the entity noun is one word in most
    // bundled locales, where the verb phrase is two and will not fit a tile.
    String create(String nounKey) => '+ ${context.tr(nounKey)}';

    return [
      ?pick(ProductAction.newInvoice, create('invoice')),
      ?pick(ProductAction.newQuote, create('quote')),
      // "+ Order", as on the vendor screen: "Purchase Order" is three words
      // in French and Spanish and scaled down beside its neighbours on a
      // phone. The tooltip and the screen reader get the full label.
      ?pick(ProductAction.newPurchaseOrder, create('order')),
      ?pick(ProductAction.clone, context.tr('clone')),
      ?pick(ProductAction.setTaxCategory, context.tr('tax_category')),
    ];
  }

  static Future<void> dispatch(
    BuildContext context,
    Services services,
    String companyId,
    Product product,
    ProductAction action,
  ) async {
    switch (action) {
      case ProductAction.newGroup:
        break; // Submenu parent — never dispatched; children carry the action.
      case ProductAction.edit:
        goEntityEdit(context, '/products', product.id);
      case ProductAction.copyLink:
        await copyEntityLink(context, EntityType.product, product.id);
      case ProductAction.archive:
        await StandardEntityActions.archive(
          context: context,
          wireName: 'product',
          op: () =>
              services.products.archive(companyId: companyId, id: product.id),
          undoOp: () =>
              services.products.restore(companyId: companyId, id: product.id),
        );
      case ProductAction.restore:
        await StandardEntityActions.restore(
          context: context,
          wireName: 'product',
          op: () =>
              services.products.restore(companyId: companyId, id: product.id),
        );
      case ProductAction.clone:
        goEntityCreateFullWidth(
          context,
          '/products',
          extra: cloneDraftFor(product),
        );
      case ProductAction.delete:
        if (!requireSynced(context, product.id)) return;
        await StandardEntityActions.delete(
          context: context,
          wireName: 'product',
          op: () =>
              services.products.delete(companyId: companyId, id: product.id),
          undoOp: () =>
              services.products.restore(companyId: companyId, id: product.id),
        );
      case ProductAction.newInvoice:
        if (!requireSynced(context, product.id)) return;
        // Stage a draft pre-seeded with a line item for this product. The
        // staged draft survives the cross-branch hop + create-screen reuse
        // (a route `extra:`/query seed does not). It carries the company's
        // inclusive-tax mode: the edit screen seeds that only on a document
        // with no priced line, and this one arrives with one.
        final inclusive = await resolveCreateInclusiveTaxes(
          services.settings,
          companyId: companyId,
        );
        if (!context.mounted) return;
        goEntityCreateFullWidth(
          context,
          '/invoices',
          extra: emptyInvoice().copyWith(
            usesInclusiveTaxes: inclusive,
            lineItems: [lineItemForProduct(product)],
          ),
        );
      case ProductAction.newQuote:
        if (!requireSynced(context, product.id)) return;
        final inclusive = await resolveCreateInclusiveTaxes(
          services.settings,
          companyId: companyId,
        );
        if (!context.mounted) return;
        goEntityCreateFullWidth(
          context,
          '/quotes',
          extra: emptyQuote().copyWith(
            usesInclusiveTaxes: inclusive,
            lineItems: [lineItemForProduct(product)],
          ),
        );
      case ProductAction.newPurchaseOrder:
        if (!requireSynced(context, product.id)) return;
        final inclusive = await resolveCreateInclusiveTaxes(
          services.settings,
          companyId: companyId,
        );
        if (!context.mounted) return;
        goEntityCreateFullWidth(
          context,
          '/purchase_orders',
          extra: emptyPurchaseOrder().copyWith(
            usesInclusiveTaxes: inclusive,
            lineItems: [lineItemForProduct(product)],
          ),
        );
      case ProductAction.setTaxCategory:
        if (!requireSynced(context, product.id)) return;
        final categoryId = await showTaxCategoryDialog(
          context,
          current: product.taxId,
        );
        if (categoryId == null || !context.mounted) return;
        if (categoryId == product.taxId) return;
        await services.products.save(
          companyId: companyId,
          product: product.copyWith(taxId: categoryId),
        );
        if (!context.mounted) return;
        Notify.success(context, context.tr('updated_product'));
    }
  }
}
