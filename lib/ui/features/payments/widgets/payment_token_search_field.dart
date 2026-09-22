import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/payments/widgets/payment_filter_keys.dart';
import 'package:admin/ui/features/payments/view_models/payment_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the payments list.
class PaymentTokenSearchField extends StatelessWidget {
  const PaymentTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final PaymentListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    // Matches the other entity search fields. The Transifex `search_payments`
    // is a bare "Search Payments" label and never mentions the filter tokens
    // this field accepts.
    hintKey: 'search_payments_or_filter_hint',
    customFieldPrefix: 'payment',
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
    keysBuilder: (services, companyId, company, names) =>
        buildPaymentFilterKeys(
          clients: services.clients,
          tags: services.tags,
          companyId: companyId,
          company: company,
          nameForClientId: (id) => names.lookup(0, id),
        ),
  );
}
