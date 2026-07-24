import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_custom_fields.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:admin/ui/features/products/product_filter_keys.dart';
import 'package:admin/ui/features/products/view_models/product_list_view_model.dart';

/// Thin wrapper that wires [TokenSearchField] for the products list. Mirrors
/// `TaskTokenSearchField` — the layout in `EntityListNormalAppBar` stays
/// entity-agnostic and only the filter keys / hint key change.
///
/// Stateful so the filter keys (and the company watch stream) are built once
/// and reused: `TagFilterKey` opens a Drift watch subscription in its
/// constructor, and rebuilding the key list on every list rebuild would leak
/// one live stream query per rebuild.
class ProductTokenSearchField extends StatefulWidget {
  const ProductTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final ProductListViewModel vm;
  final bool wide;

  @override
  State<ProductTokenSearchField> createState() =>
      _ProductTokenSearchFieldState();
}

class _ProductTokenSearchFieldState extends State<ProductTokenSearchField> {
  Stream<Company?>? _companyStream;
  String? _streamCompanyId;

  List<FilterKey>? _keys;
  String? _keysCompanyId;
  String? _keysLabelSignature;

  /// Rebuild the keys only when a company input that shapes them changes:
  /// `track_inventory` (gates the stock filter) and the custom-field labels.
  static String _labelSignature(Company? c) => c == null
      ? ''
      : [
          c.trackInventory.toString(),
          for (var i = 1; i <= 4; i++) c.customFieldLabel('product$i'),
        ].join(' ');

  void _disposeKeys() {
    for (final k in _keys ?? const <FilterKey>[]) {
      k.dispose();
    }
    _keys = null;
  }

  List<FilterKey> _keysFor(Services services, Company? company) {
    final signature = _labelSignature(company);
    if (_keys != null &&
        _keysCompanyId == widget.vm.companyId &&
        _keysLabelSignature == signature) {
      return _keys!;
    }
    _disposeKeys();
    _keysCompanyId = widget.vm.companyId;
    _keysLabelSignature = signature;
    return _keys = buildProductFilterKeys(
      tags: services.tags,
      companyId: widget.vm.companyId,
      company: company,
    );
  }

  @override
  void dispose() {
    _disposeKeys();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    // Hoisted (not built inline in the StreamBuilder) so a parent rebuild
    // doesn't swap the subscription — the stable-stream rule.
    if (_companyStream == null || _streamCompanyId != widget.vm.companyId) {
      _streamCompanyId = widget.vm.companyId;
      _companyStream = services.company.watchCompany(widget.vm.companyId);
    }
    return StreamBuilder<Company?>(
      stream: _companyStream,
      builder: (context, companySnap) {
        return TokenSearchField(
          vm: widget.vm,
          filterKeys: _keysFor(services, companySnap.data),
          wide: widget.wide,
          hintKey: 'search_products_or_filter_hint',
        );
      },
    );
  }
}
