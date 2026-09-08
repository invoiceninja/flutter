import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/invoices/widgets/invoice_filter_keys.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the invoices list.
class InvoiceTokenSearchField extends StatelessWidget {
  const InvoiceTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final InvoiceListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    hintKey: 'search_invoices_or_filter_hint',
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
    keysBuilder: (services, companyId, company, names) =>
        buildInvoiceFilterKeys(
          clients: services.clients,
          tags: services.tags,
          companyId: companyId,
          company: company,
          nameForClientId: (id) => names.lookup(0, id),
        ),
  );
}
