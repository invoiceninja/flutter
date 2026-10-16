import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/date_column_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/number_filter_key.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';

// `IsFilterKey` is re-exported so vendor screens can register it without
// reaching across to the clients filter-keys file. Same pattern as
// `client_filter_keys.dart`.
export 'package:admin/ui/core/list/search/filter_keys_common.dart'
    show IsFilterKey;

/// Build the filter keys exposed in the vendors list's search field.
///
/// Number is `VendorFilters::number` (exact — confirmed on the demo server);
/// Created / Updated are the base `created_at` / `updated_at` comparisons
/// and `created_between` / `updated_between` windows. Country and currency
/// have no server param for vendors, and assigned user has no local column
/// yet, so none of those is offered.
///
/// [company] is the current workspace's company snapshot. Used to resolve
/// configured custom-field labels when CustomFieldFilterKey gets wired.
/// [statics] feeds suggestion lists for membership keys (country, currency).
List<FilterKey> buildVendorFilterKeys({
  required Company? company,
  required StaticsRepository statics,
  required TagRepository tags,
  required String companyId,
}) {
  return <FilterKey>[
    const IsFilterKey(),
    const NumberFilterKey(hintKey: 'vendor_number_filter_hint'),
    const DateColumnFilterKey(
      id: 'created',
      serverKey: 'created_at',
      labelKey: 'created',
      hintKey: 'date_filter_hint',
      hasTime: true,
    ),
    const DateColumnFilterKey(
      id: 'updated',
      serverKey: 'updated_at',
      labelKey: 'updated',
      hintKey: 'date_filter_hint',
      hasTime: true,
    ),
    TagFilterKey(tags: tags, companyId: companyId, entityType: 'vendor'),
    for (var i = 1; i <= 4; i++)
      CustomFieldFilterKey(
        columnIndex: i,
        configuredLabel: company?.customFieldLabel('vendor$i') ?? '',
      ),
  ];
}
