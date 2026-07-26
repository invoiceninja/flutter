import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/ui/core/list/search/custom_field_filter_key.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/filter_keys_common.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';

List<FilterKey> buildPurchaseOrderFilterKeys({
  required TagRepository tags,
  required String companyId,
  Company? company,
}) => <FilterKey>[
  const IsFilterKey(),
  TagFilterKey(tags: tags, companyId: companyId, entityType: 'purchase_order'),
  // Purchase orders reuse the `invoice` custom-field config slots — there are
  // no `purchase_order1..4` keys server-side, and the PO detail/edit screens
  // already read `prefix: 'invoice'`. Reading the wrong slot yields an empty
  // label, which silently drops all four filters (`isAvailable` is false).
  for (var i = 1; i <= 4; i++)
    CustomFieldFilterKey(
      columnIndex: i,
      configuredLabel: company?.customFieldLabel('invoice$i') ?? '',
    ),
];
