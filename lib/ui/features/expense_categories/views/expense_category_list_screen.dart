import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/expense_category_dao.dart';
import 'package:admin/data/models/domain/expense_category.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/expense_categories/view_models/expense_category_list_view_model.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_actions.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_list_tile.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_token_search_field.dart';

/// Labels surfaced on the list screen for the in-app settings search index.
const kExpenseCategoryListSearchKeys = <String>[
  'expense_categories',
  'name',
  'color',
  'last_updated',
  'new_expense_category',
];

/// `/settings/expense_categories` — list every expense category. Reached
/// only from the Settings sidebar (Settings → Advanced); not present in
/// the main workspace nav. The screen uses the canonical
/// [EntityListScreenScaffold] for chrome and renders its rows via the
/// generic list tile — the layout matches Products / Clients so the visual
/// vocabulary stays consistent across the app.
class ExpenseCategoryListScreen extends StatelessWidget {
  const ExpenseCategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EntityListScreenScaffold<
      ExpenseCategory,
      ExpenseCategoryListViewModel
    >(
      titleKey: 'expense_categories',
      newRoute: '/settings/expense_categories/new',
      newLabelKey: 'new_expense_category',
      // Opt-in "Last Updated" column renders via cellDate → FormatterScope.
      wantsFormatter: true,
      emptyIcon: Icons.category_outlined,
      emptyTitleKey: 'no_expense_categories',
      buildVm: (services, companyId) => ExpenseCategoryListViewModel(
        repo: services.expenseCategories,
        companyId: companyId,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
      ),
      sortOptions: (context) => [
        SortOption(id: ExpenseCategoryFieldIds.name, label: context.tr('name')),
        SortOption(
          id: ExpenseCategoryFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          ExpenseCategoryTokenSearchField(vm: vm, wide: wide),
      tileBuilder: (context, vm, category, index, options) {
        final isUrlSelected = options.selectedId == category.id;
        return ExpenseCategoryListTile(
          category: category,
          columns: options.wide ? vm.columns : const [],
          wide: options.wide,
          editable: options.editable,
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(category.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(category.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/settings/expense_categories',
                )
              : () => goEntityRecord(context, vm.entityType, category.id),
          onLongPress: () => vm.toggleSelected(category.id),
          onSelectTap: () => vm.toggleSelected(category.id),
          onAction: options.selecting
              ? null
              : (action) => ExpenseCategoryActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  category,
                  action,
                ),
        );
      },
      bulkActions: const [
        EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_expense_category',
          pluralSuccessKey: 'archived_expense_categories',
          nothingKey: 'nothing_to_archive',
        ),
        EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_expense_category',
          pluralSuccessKey: 'restored_expense_categories',
          nothingKey: 'nothing_to_restore',
        ),
      ],
    );
  }
}
