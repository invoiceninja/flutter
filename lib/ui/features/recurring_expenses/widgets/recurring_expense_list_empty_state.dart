import 'package:flutter/material.dart';

import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_list_view_model.dart';

/// Empty-state picker for the Recurring Expenses list. Mirrors
/// `ExpenseListEmptyState`. A selected status tab lives in `extraFilters`
/// (`badge_mode`), so `hasActiveFilters` already accounts for it.
class RecurringExpenseListEmptyState extends StatelessWidget {
  const RecurringExpenseListEmptyState({super.key, required this.vm});

  final RecurringExpenseListViewModel vm;

  @override
  Widget build(BuildContext context) {
    if (!vm.hasActiveFilters) {
      return EmptyState(
        icon: Icons.event_repeat_outlined,
        title: context.tr('no_recurring_expenses_yet'),
        subtitle: context.tr('create_your_first_recurring_expense_placeholder'),
      );
    }
    final onlyArchived =
        vm.states.length == 1 &&
        vm.states.contains(EntityState.archived) &&
        vm.customFilters.isEmpty &&
        vm.extraFilters.isEmpty &&
        vm.search.isEmpty;
    final onlyDeleted =
        vm.states.length == 1 &&
        vm.states.contains(EntityState.deleted) &&
        vm.customFilters.isEmpty &&
        vm.extraFilters.isEmpty &&
        vm.search.isEmpty;
    if (onlyArchived) {
      return EmptyState(
        icon: Icons.archive_outlined,
        title: context.tr('no_archived_recurring_expenses'),
      );
    }
    if (onlyDeleted) {
      return EmptyState(
        icon: Icons.delete_outline,
        title: context.tr('no_deleted_recurring_expenses'),
      );
    }
    return EmptyState(
      icon: Icons.filter_alt_off_outlined,
      title: context.tr('no_recurring_expenses_match_filters'),
      action: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
        onPressed: vm.clearAllFilters,
        icon: const Icon(Icons.close),
        label: Text(context.tr('clear_filters')),
      ),
    );
  }
}
