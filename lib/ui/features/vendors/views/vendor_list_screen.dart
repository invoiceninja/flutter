import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/vendor.dart';
import 'package:admin/domain/columns/vendor_columns.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_column_headers.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_list_view_model.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_actions.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_list_empty_state.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_list_tile.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_token_search_field.dart';

/// Vendors list screen — pure config + per-entity widgets. The screen-level
/// chrome lives in [EntityListScreenScaffold]; this class plugs Vendor-
/// specific bits into it. Mirror of `ClientListScreen`.
class VendorListScreen extends StatelessWidget {
  const VendorListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityListScreenScaffold<Vendor, VendorListViewModel>(
      titleKey: 'vendors',
      newRoute: '/vendors/new',
      newLabelKey: 'new_vendor',
      // Money columns — let the scaffold wire `FormatterHostMixin` so the
      // tile renders the per-vendor currency cascade.
      wantsFormatter: true,
      buildVm: (services, companyId) => VendorListViewModel(
        repo: services.vendors,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
        companyId: companyId,
      ),
      sortOptions: (context) => [
        SortOption(id: VendorFieldIds.name, label: context.tr('name')),
        SortOption(id: VendorFieldIds.number, label: context.tr('number')),
        SortOption(
          id: VendorFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
        SortOption(id: VendorFieldIds.createdAt, label: context.tr('created')),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          VendorTokenSearchField(vm: vm, wide: wide),
      emptyStateBuilder: (context, vm) => VendorListEmptyState(vm: vm),
      wideColumnHeadersBuilder: (context, vm) =>
          EntityListColumnHeaders<Vendor>(vm: vm),
      tileBuilder: (context, vm, vendor, index, options) {
        final isUrlSelected = options.selectedId == vendor.id;
        return VendorListTile(
          vendor: vendor,
          formatter: options.formatter,
          wide: options.wide,
          editable: options.editable,
          columns: options.wide ? vm.columns : const <VendorColumn>[],
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(vendor.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(vendor.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/vendors',
                )
              : () => goEntityRecord(context, vm.entityType, vendor.id),
          onLongPress: () => vm.toggleSelected(vendor.id),
          onSelectTap: () => vm.toggleSelected(vendor.id),
          // Always *to* the record, unlike `onTap` above — this feeds the call
          // picker's "View vendor" footer.
          onViewRecord: () => goEntityRecord(context, vm.entityType, vendor.id),
          onAction: options.selecting
              ? null
              : (action) => VendorActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  vendor,
                  action,
                ),
        );
      },
      bulkActions: const [
        EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_vendor',
          pluralSuccessKey: 'archived_vendors',
          nothingKey: 'nothing_to_archive',
        ),
        EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_vendor',
          pluralSuccessKey: 'restored_vendors',
          nothingKey: 'nothing_to_restore',
        ),
        EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_vendor',
          pluralSuccessKey: 'deleted_vendors',
          nothingKey: 'nothing_to_delete',
        ),
      ],
    );
  }
}
