import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/repositories/statics_repository.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';

// `IsFilterKey` is re-exported so vendor screens can register it without
// reaching across to the clients filter-keys file. Same pattern as
// `client_filter_keys.dart`.
export 'package:admin/ui/core/list/search/filter_keys_common.dart'
    show IsFilterKey;

/// Build the filter keys exposed in the vendors list's search field.
///
/// First pass mirrors `taskStatus` / `paymentTerm`'s minimal surface — only
/// `IsFilterKey` is wired today. Expand to NameFilterKey / BalanceFilterKey
/// / CountryFilterKey when those server params are confirmed against the
/// `/api/v1/vendors` endpoint via the demo-API probe recipe (see
/// `docs/probing-the-demo-api.md`).
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
    TagFilterKey(tags: tags, companyId: companyId, entityType: 'vendor'),
    for (var i = 1; i <= 4; i++)
      CustomFieldFilterKey(
        columnIndex: i,
        configuredLabel: company?.customFieldLabel('vendor$i') ?? '',
      ),
  ];
}
