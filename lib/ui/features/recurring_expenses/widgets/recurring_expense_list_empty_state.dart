import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_list_view_model.dart';

class RecurringExpenseListEmptyState extends StatelessWidget {
  const RecurringExpenseListEmptyState({super.key, required this.vm});

  final RecurringExpenseListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.event_repeat_outlined,
    emptyTitle: context.tr('no_recurring_expenses_yet'),
    emptySubtitle: context.tr(
      'create_your_first_recurring_expense_placeholder',
    ),
    archivedTitle: context.tr('no_archived_recurring_expenses'),
    deletedTitle: context.tr('no_deleted_recurring_expenses'),
    noMatchTitle: context.tr('no_recurring_expenses_match_filters'),
  );
}
