import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/vendors/widgets/vendor_filter_keys.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the vendors list.
class VendorTokenSearchField extends StatelessWidget {
  const VendorTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final VendorListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    hintKey: 'search_vendors_or_filter_hint',
    customFieldPrefix: 'vendor',
    keysBuilder: (services, companyId, company, names) => buildVendorFilterKeys(
      company: company,
      statics: services.statics,
      tags: services.tags,
      companyId: companyId,
    ),
  );
}
