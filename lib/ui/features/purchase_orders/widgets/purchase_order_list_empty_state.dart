import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_list_view_model.dart';

class PurchaseOrderListEmptyState extends StatelessWidget {
  const PurchaseOrderListEmptyState({super.key, required this.vm});

  final PurchaseOrderListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.shopping_bag_outlined,
    emptyTitle: context.tr('no_purchase_orders_yet'),
    emptySubtitle: context.tr('create_your_first_purchase_order_placeholder'),
    archivedTitle: context.tr('no_archived_purchase_orders'),
    deletedTitle: context.tr('no_deleted_purchase_orders'),
    noMatchTitle: context.tr('no_purchase_orders_match_filters'),
  );
}
