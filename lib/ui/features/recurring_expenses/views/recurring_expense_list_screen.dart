import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/recurring_expense_dao.dart';
import 'package:admin/data/models/domain/recurring_expense.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_edit_view_model.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_list_view_model.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_actions.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_list_empty_state.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_list_tile.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_token_search_field.dart';

/// Recurring expenses list screen. Mirrors `ExpenseListScreen`.
class RecurringExpenseListScreen extends StatelessWidget {
  const RecurringExpenseListScreen({
    super.key,
    this.vendorId,
    this.embedded = false,
  });

  /// When set, the list is filtered to one vendor.
  final String? vendorId;

  /// True when this list lives inside another screen's body.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final vid = vendorId;
    return EntityListScreenScaffold<
      RecurringExpense,
      RecurringExpenseListViewModel
    >(
      titleKey: 'recurring_expenses',
      newRoute: '/recurring_expenses/new',
      newLabelKey: 'new_recurring_expense',
      embeddedNewOverride: vid == null
          ? null
          : (ctx) => goEntityCreateFullWidth(
              ctx,
              '/recurring_expenses',
              extra: emptyRecurringExpense().copyWith(vendorId: vid),
            ),
      emptyIcon: Icons.event_repeat_outlined,
      emptyTitleKey: 'no_recurring_expenses_yet',
      wantsFormatter: true,
      embedded: embedded,
      buildVm: (services, companyId) => RecurringExpenseListViewModel(
        repo: services.recurringExpenses,
        companyId: companyId,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
        vendorId: vendorId,
      ),
      sortOptions: (context) => [
        SortOption(
          id: RecurringExpenseFieldIds.nextSendDate,
          label: context.tr('next_send_date'),
        ),
        SortOption(
          id: RecurringExpenseFieldIds.date,
          label: context.tr('date'),
        ),
        SortOption(
          id: RecurringExpenseFieldIds.number,
          label: context.tr('number'),
        ),
        SortOption(
          id: RecurringExpenseFieldIds.amount,
          label: context.tr('amount'),
        ),
        SortOption(
          id: RecurringExpenseFieldIds.vendorId,
          label: context.tr('vendor'),
        ),
        SortOption(
          id: RecurringExpenseFieldIds.clientId,
          label: context.tr('client'),
        ),
        SortOption(
          id: RecurringExpenseFieldIds.categoryId,
          label: context.tr('category'),
        ),
        SortOption(
          id: RecurringExpenseFieldIds.frequency,
          label: context.tr('frequency'),
        ),
        SortOption(
          id: RecurringExpenseFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          RecurringExpenseTokenSearchField(vm: vm, wide: wide),
      emptyStateBuilder: (context, vm) =>
          RecurringExpenseListEmptyState(vm: vm),
      tileBuilder: (context, vm, recurringExpense, index, options) {
        final isUrlSelected = options.selectedId == recurringExpense.id;
        return RecurringExpenseListTile(
          recurringExpense: recurringExpense,
          columns: options.wide ? vm.columns : const [],
          wide: options.wide,
          editable: options.editable,
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(recurringExpense.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(recurringExpense.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/recurring_expenses',
                )
              : () =>
                    goEntityRecord(context, vm.entityType, recurringExpense.id),
          onLongPress: () => vm.toggleSelected(recurringExpense.id),
          onSelectTap: () => vm.toggleSelected(recurringExpense.id),
          onAction: options.selecting
              ? null
              : (action) => RecurringExpenseActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  recurringExpense,
                  action,
                ),
        );
      },
      bulkActions: const [
        EntityListBulkAction(
          actionId: 'start',
          icon: Icons.play_arrow_outlined,
          tooltipKey: 'start',
          singleSuccessKey: 'started_recurring_expense',
          pluralSuccessKey: 'started_recurring_expenses',
          nothingKey: 'nothing_to_start',
        ),
        EntityListBulkAction(
          actionId: 'stop',
          icon: Icons.stop_outlined,
          tooltipKey: 'stop',
          singleSuccessKey: 'stopped_recurring_expense',
          pluralSuccessKey: 'stopped_recurring_expenses',
          nothingKey: 'nothing_to_stop',
        ),
        EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_recurring_expense',
          pluralSuccessKey: 'archived_recurring_expenses',
          nothingKey: 'nothing_to_archive',
        ),
        EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_recurring_expense',
          pluralSuccessKey: 'restored_recurring_expenses',
          nothingKey: 'nothing_to_restore',
        ),
        EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_recurring_expense',
          pluralSuccessKey: 'deleted_recurring_expenses',
          nothingKey: 'nothing_to_delete',
        ),
      ],
    );
  }
}
