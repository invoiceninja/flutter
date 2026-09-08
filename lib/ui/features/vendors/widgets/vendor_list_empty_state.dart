import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/vendors/view_models/vendor_list_view_model.dart';

class VendorListEmptyState extends StatelessWidget {
  const VendorListEmptyState({super.key, required this.vm});

  final VendorListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.store_outlined,
    emptyTitle: context.tr('no_vendors'),
    emptySubtitle: context.tr('create_your_first_vendor_placeholder'),
    archivedTitle: context.tr('no_archived_vendors'),
    deletedTitle: context.tr('no_deleted_vendors'),
    noMatchTitle: context.tr('no_vendors_match_filters'),
  );
}
