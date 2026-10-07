import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:admin/ui/features/expense_categories/view_models/expense_category_list_view_model.dart';
import 'package:admin/ui/features/expense_categories/widgets/expense_category_filter_keys.dart';

/// Thin wrapper that wires [TokenSearchField] for the expense-categories
/// list. Mirrors `ProductTokenSearchField` so the layout / placement code in
/// `EntityListAppBar` stays entity-agnostic.
class ExpenseCategoryTokenSearchField extends StatelessWidget {
  const ExpenseCategoryTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final ExpenseCategoryListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return TokenSearchField(
      vm: vm,
      filterKeys: buildExpenseCategoryFilterKeys(),
      wide: wide,
      hintKey: 'search_expense_categories_or_filter_hint',
    );
  }
}
