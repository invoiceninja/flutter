import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/product_dao.dart';
import 'package:admin/data/models/domain/product.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_list_section_header.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/products/view_models/product_list_view_model.dart';
import 'package:admin/ui/features/products/widgets/inventory_scope.dart';
import 'package:admin/ui/features/products/widgets/product_actions.dart';
import 'package:admin/ui/features/products/widgets/product_group_by_button.dart';
import 'package:admin/ui/features/products/widgets/product_list_tile.dart';
import 'package:admin/ui/features/products/widgets/product_token_search_field.dart';

/// Products list screen — pure config + per-entity widgets. Mirrors
/// [ClientListScreen]; the screen-level chrome lives in
/// [EntityListScreenScaffold].
class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityListScreenScaffold<Product, ProductListViewModel>(
      titleKey: 'products',
      // Products carry money columns (price / cost), so resolve the active
      // company Formatter and expose it via FormatterScope — without this the
      // price/cost cells (and the narrow tile) fall back to symbol-less locale
      // numbers. Mirrors ClientListScreen.
      wantsFormatter: true,
      newRoute: '/products/new',
      newLabelKey: 'new_product',
      emptyIcon: Icons.inventory_2_outlined,
      emptyTitleKey: 'no_products',
      buildVm: (services, companyId) => ProductListViewModel(
        repo: services.products,
        companyId: companyId,
        // The VM watches the company for inventory settings (track-inventory +
        // threshold) so the low-stock filter/highlight stay live; a company
        // switch rebuilds the VM with the new company's stream.
        companyStream: services.company.watchCompany(companyId),
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
        // Names the tag groups. A factory, not a stream: the VM folds it into
        // its page stream and rebuilds that on every re-subscribe. Archived
        // included so a row carrying one still lands in a named group rather
        // than Uncategorized.
        tagStream: () => services.tags.watchAll(
          companyId: companyId,
          entityType: 'product',
          includeArchived: true,
        ),
      ),
      sortOptions: (context) => [
        SortOption(
          id: ProductFieldIds.productKey,
          label: context.tr('product_key'),
        ),
        SortOption(id: ProductFieldIds.price, label: context.tr('price')),
        SortOption(id: ProductFieldIds.cost, label: context.tr('cost')),
        SortOption(id: ProductFieldIds.quantity, label: context.tr('quantity')),
        SortOption(
          id: ProductFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
      ],
      // Phones pick the grouping inside the sort sheet (see
      // `EntitySortFilterSheet`); wide screens get the labelled button below.
      // Both read the same `vm.groupField`.
      groupOptions: (context, vm) => [
        for (final id in vm.availableGroupFieldIds)
          GroupOption(
            id: id,
            label: id == kProductGroupTags
                ? context.tr('tags')
                : vm.groupFieldLabel(id),
          ),
      ],
      // Wide only: narrow would be a third AppBar glyph on top of the sheet
      // entry that already offers the same choice.
      extraAppBarActions: (context, vm, wide) =>
          wide ? [ProductGroupByButton(vm: vm)] : const <Widget>[],
      sectionHeaderBuilder: (context, vm, index) {
        if (vm.effectiveGroupField == null || !vm.isGroupStart(index)) {
          return null;
        }
        final label = vm.groupLabelAt(index);
        return EntityListSectionHeader(
          // `''` is the stored "no value" key — localize only for display, so
          // a folded group survives a language change.
          label: label.isEmpty ? context.tr('uncategorized') : label,
          count: vm.groupCount(label),
          collapsed: vm.isGroupCollapsed(label),
          onToggle: () => vm.toggleGroupCollapsed(label),
          isFirst: index == 0,
        );
      },
      searchFieldBuilder: (context, vm, wide) =>
          ProductTokenSearchField(vm: vm, wide: wide),
      tileBuilder: (context, vm, product, index, options) {
        final isUrlSelected = options.selectedId == product.id;
        final tile = ProductListTile(
          product: product,
          columns: options.wide ? vm.columns : const [],
          wide: options.wide,
          editable: options.editable,
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(product.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(product.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/products',
                )
              : () => goEntityRecord(context, vm.entityType, product.id),
          onLongPress: () => vm.toggleSelected(product.id),
          onSelectTap: () => vm.toggleSelected(product.id),
          onAction: options.selecting
              ? null
              : (action) => ProductActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  product,
                  action,
                ),
        );
        // Expose the company's inventory settings to the row's cells (the
        // on-hand-stock column reads them to colour low/out) and the narrow
        // tile's stock badge.
        return InventoryScope(
          trackInventory: vm.trackInventory,
          threshold: vm.inventoryThreshold,
          child: tile,
        );
      },
      bulkActions: const [
        EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_product',
          pluralSuccessKey: 'archived_products',
          nothingKey: 'nothing_to_archive',
        ),
        EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_product',
          pluralSuccessKey: 'restored_products',
          nothingKey: 'nothing_to_restore',
        ),
        EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_product',
          pluralSuccessKey: 'deleted_products',
          nothingKey: 'nothing_to_delete',
        ),
      ],
    );
  }
}
