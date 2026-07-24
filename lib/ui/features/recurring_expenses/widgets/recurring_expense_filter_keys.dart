import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';

/// Build the filter keys exposed in the Recurring Expenses list's search
/// field. The status chip strip above the list owns the 5-status filter
/// dimension; plus tags and the shared custom-field filters (recurring
/// expenses share Invoice Ninja's `expense1..4` labels).
List<FilterKey> buildRecurringExpenseFilterKeys({
  required TagRepository tags,
  required String companyId,
  Company? company,
}) => <FilterKey>[
  const IsFilterKey(),
  TagFilterKey(
    tags: tags,
    companyId: companyId,
    entityType: 'recurring_expense',
  ),
  for (var i = 1; i <= 4; i++)
    CustomFieldFilterKey(
      columnIndex: i,
      configuredLabel: company?.customFieldLabel('expense$i') ?? '',
    ),
];
