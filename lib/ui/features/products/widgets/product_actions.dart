import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/billing/line_item.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/copy_entity_link.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/standard_entity_action_items.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/sync/require_synced.dart';
import 'package:admin/ui/core/widgets/notify.dart';
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
    final canArchive = product.archivedAt == null && !product.isDeleted;
    final canRestore = product.archivedAt != null || product.isDeleted;
    final me = context.read<Services>().auth.session.value?.currentCompany;
    final notTmp = !product.id.startsWith('tmp_');
    // Purge is admin/owner-only — mirrors the Client gate so the action
    // only renders when the user could plausibly run it.

    return [
      editActionItem(
        context: context,
        kind: ProductAction.edit,
        onTap: () => onTap(ProductAction.edit),
      ),
      // The "New X" items collapse into one fly-out submenu (like Client)
      // so they stop burying the rest of the actions menu.
      if ((me?.moduleEnabled(EntityType.invoice) ?? false) ||
          (me?.moduleEnabled(EntityType.quote) ?? false) ||
          (me?.moduleEnabled(EntityType.purchaseOrder) ?? false))
        newGroupActionItem(
          context: context,
          kind: ProductAction.newGroup,
          children: [
            if (me?.moduleEnabled(EntityType.invoice) ?? false)
              EntityActionItem(
                kind: ProductAction.newInvoice,
                icon: Icons.receipt_long_outlined,
                label: context.tr('new_invoice'),
                enabled: notTmp,
                onTap: () => onTap(ProductAction.newInvoice),
              ),
            if (me?.moduleEnabled(EntityType.quote) ?? false)
              EntityActionItem(
                kind: ProductAction.newQuote,
                icon: Icons.request_quote_outlined,
                label: context.tr('new_quote'),
                enabled: notTmp,
                onTap: () => onTap(ProductAction.newQuote),
              ),
            if (me?.moduleEnabled(EntityType.purchaseOrder) ?? false)
              EntityActionItem(
                kind: ProductAction.newPurchaseOrder,
                icon: Icons.shopping_cart_outlined,
                label: context.tr('new_purchase_order'),
                enabled: notTmp,
                onTap: () => onTap(ProductAction.newPurchaseOrder),
              ),
          ],
        ),
      EntityActionItem(
        kind: ProductAction.setTaxCategory,
        icon: Icons.percent,
        label: context.tr('set_tax_category'),
        enabled: notTmp,
        onTap: () => onTap(ProductAction.setTaxCategory),
      ),
      EntityActionItem(
        kind: ProductAction.clone,
        icon: Icons.copy_outlined,
        label: context.tr('clone_product'),
        enabled: true,
        onTap: () => onTap(ProductAction.clone),
      ),
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
        canDelete: !product.isDeleted,
        onTap: () => onTap(ProductAction.delete),
      ),
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
        // (a route `extra:`/query seed does not).
        goEntityCreateFullWidth(
          context,
          '/invoices',
          extra: emptyInvoice().copyWith(
            lineItems: [lineItemForProduct(product)],
          ),
        );
      case ProductAction.newQuote:
        if (!requireSynced(context, product.id)) return;
        goEntityCreateFullWidth(
          context,
          '/quotes',
          extra: emptyQuote().copyWith(
            lineItems: [lineItemForProduct(product)],
          ),
        );
      case ProductAction.newPurchaseOrder:
        if (!requireSynced(context, product.id)) return;
        goEntityCreateFullWidth(
          context,
          '/purchase_orders',
          extra: emptyPurchaseOrder().copyWith(
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
