import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/token_search_field.dart';
import 'package:admin/ui/features/transactions/view_models/transaction_list_view_model.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_filter_keys.dart';

/// Search field for the transactions list. Exposes free-text search + the
/// standard archive toggle (`is:archived`/`is:active`), plus transaction
/// dimensions: `tag:`, `status:unmatched|matched|converted`, and
/// `type:deposit|withdrawal`. Bank-account scoping rides the route query
/// string (`/transactions?bank_account_id=…`), not the token search.
///
/// Stateful + key-caching: `TagFilterKey` opens a Drift watch subscription in
/// its constructor, so the key list is built once per company and disposed on
/// unmount / company switch — never rebuilt on every parent rebuild.
class TransactionTokenSearchField extends StatefulWidget {
  const TransactionTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final TransactionListViewModel vm;
  final bool wide;

  @override
  State<TransactionTokenSearchField> createState() =>
      _TransactionTokenSearchFieldState();
}

class _TransactionTokenSearchFieldState
    extends State<TransactionTokenSearchField> {
  List<FilterKey>? _keys;
  String? _keysCompanyId;

  void _disposeKeys() {
    for (final k in _keys ?? const <FilterKey>[]) {
      k.dispose();
    }
    _keys = null;
  }

  List<FilterKey> _keysFor(Services services) {
    if (_keys != null && _keysCompanyId == widget.vm.companyId) return _keys!;
    _disposeKeys();
    _keysCompanyId = widget.vm.companyId;
    return _keys = buildTransactionFilterKeys(
      tags: services.tags,
      companyId: widget.vm.companyId,
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
    return TokenSearchField(
      vm: widget.vm,
      filterKeys: _keysFor(services),
      wide: widget.wide,
      hintKey: 'search_transactions_or_filter_hint',
    );
  }
}
