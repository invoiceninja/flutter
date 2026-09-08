import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/transactions/widgets/transaction_filter_keys.dart';
import 'package:admin/ui/features/transactions/view_models/transaction_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the bank transactions list.
class TransactionTokenSearchField extends StatelessWidget {
  const TransactionTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final TransactionListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    // Its keys ignore the company, so don't open a watch for it.
    watchesCompany: false,
    hintKey: 'search_transactions_or_filter_hint',
    keysBuilder: (services, companyId, company, names) =>
        buildTransactionFilterKeys(tags: services.tags, companyId: companyId),
  );
}
