import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/quotes/widgets/quote_filter_keys.dart';
import 'package:admin/ui/features/quotes/view_models/quote_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the quotes list.
class QuoteTokenSearchField extends StatelessWidget {
  const QuoteTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final QuoteListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    hintKey: 'search_quotes_or_filter_hint',
    // Quotes share Invoice Ninja's `invoice1..4` custom-field slots.
    customFieldPrefix: 'invoice',
    nameSources: [
      (services, companyId) => services.clients
          .watchActiveNames(companyId: companyId)
          .map(
            (rows) => {
              for (final r in rows)
                if (r.name.isNotEmpty) r.id: r.name,
            },
          ),
    ],
    keysBuilder: (services, companyId, company, names) => buildQuoteFilterKeys(
      clients: services.clients,
      tags: services.tags,
      companyId: companyId,
      company: company,
      nameForClientId: (id) => names.lookup(0, id),
    ),
  );
}
