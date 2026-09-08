import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/expenses/view_models/expense_list_view_model.dart';

class ExpenseListEmptyState extends StatelessWidget {
  const ExpenseListEmptyState({super.key, required this.vm});

  final ExpenseListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.account_balance_wallet_outlined,
    emptyTitle: context.tr('no_expenses_yet'),
    emptySubtitle: context.tr('create_your_first_expense_placeholder'),
    archivedTitle: context.tr('no_archived_expenses'),
    deletedTitle: context.tr('no_deleted_expenses'),
    noMatchTitle: context.tr('no_expenses_match_filters'),
  );
}
