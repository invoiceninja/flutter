import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/recurring_invoices/widgets/recurring_invoice_filter_keys.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the recurring invoices list.
class RecurringInvoiceTokenSearchField extends StatelessWidget {
  const RecurringInvoiceTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final RecurringInvoiceListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    hintKey: 'search_recurring_invoices_or_filter_hint',
    // Recurring invoices share Invoice Ninja's `invoice1..4` slots.
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
        buildRecurringInvoiceFilterKeys(
          clients: services.clients,
          tags: services.tags,
          companyId: companyId,
          company: company,
          nameForClientId: (id) => names.lookup(0, id),
        ),
  );
}
