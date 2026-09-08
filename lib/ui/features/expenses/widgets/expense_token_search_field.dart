import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/expenses/widgets/expense_filter_keys.dart';
import 'package:admin/ui/features/expenses/view_models/expense_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the expenses list.
class ExpenseTokenSearchField extends StatelessWidget {
  const ExpenseTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final ExpenseListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    // Its keys ignore the company, so don't open a watch for it.
    watchesCompany: false,
    hintKey: 'search_expenses_or_filter_hint',
    nameSources: [
      (services, companyId) => services.clients
          .watchActiveNames(companyId: companyId)
          .map(
            (rows) => {
              for (final r in rows)
                if (r.name.isNotEmpty) r.id: r.name,
            },
          ),
    ],
    keysBuilder: (services, companyId, company, names) =>
        buildExpenseFilterKeys(
          clients: services.clients,
          categories: services.expenseCategories,
          projects: services.projects,
          vendors: services.vendors,
          tags: services.tags,
          companyId: companyId,
          nameForClientId: (id) => names.lookup(0, id),
        ),
  );
}
