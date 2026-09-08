import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/products/product_filter_keys.dart';
import 'package:admin/ui/features/products/view_models/product_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the products list.
class ProductTokenSearchField extends StatelessWidget {
  const ProductTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final ProductListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    hintKey: 'search_products_or_filter_hint',
    customFieldPrefix: 'product',
    // `track_inventory` gates the stock filter, so it shapes the keys too.
    extraSignature: (c) => c?.trackInventory.toString() ?? '',
    keysBuilder: (services, companyId, company, names) =>
        buildProductFilterKeys(
          tags: services.tags,
          companyId: companyId,
          company: company,
        ),
  );
}
