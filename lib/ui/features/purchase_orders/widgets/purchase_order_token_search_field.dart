import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/purchase_orders/widgets/purchase_order_filter_keys.dart';
import 'package:admin/ui/features/purchase_orders/view_models/purchase_order_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the purchase orders list.
class PurchaseOrderTokenSearchField extends StatelessWidget {
  const PurchaseOrderTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final PurchaseOrderListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    hintKey: 'search_purchase_orders_or_filter_hint',
    // Purchase orders share Invoice Ninja's `invoice1..4` slots.
    customFieldPrefix: 'invoice',
    keysBuilder: (services, companyId, company, names) =>
        buildPurchaseOrderFilterKeys(
          tags: services.tags,
          companyId: companyId,
          company: company,
        ),
  );
}
