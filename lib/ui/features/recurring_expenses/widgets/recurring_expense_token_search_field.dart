import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/recurring_expenses/widgets/recurring_expense_filter_keys.dart';
import 'package:admin/ui/features/recurring_expenses/view_models/recurring_expense_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the recurring expenses list.
class RecurringExpenseTokenSearchField extends StatelessWidget {
  const RecurringExpenseTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final RecurringExpenseListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    hintKey: 'search_recurring_expenses_or_filter_hint',
    // Recurring expenses read the `expense1..4` slots.
    customFieldPrefix: 'expense',
    keysBuilder: (services, companyId, company, names) =>
        buildRecurringExpenseFilterKeys(
          tags: services.tags,
          companyId: companyId,
          company: company,
        ),
  );
}
