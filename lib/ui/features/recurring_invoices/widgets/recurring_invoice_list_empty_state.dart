import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/recurring_invoices/view_models/recurring_invoice_list_view_model.dart';

class RecurringInvoiceListEmptyState extends StatelessWidget {
  const RecurringInvoiceListEmptyState({super.key, required this.vm});

  final RecurringInvoiceListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.event_repeat_outlined,
    emptyTitle: context.tr('no_recurring_invoices_yet'),
    emptySubtitle: context.tr(
      'create_your_first_recurring_invoice_placeholder',
    ),
    archivedTitle: context.tr('no_archived_recurring_invoices'),
    deletedTitle: context.tr('no_deleted_recurring_invoices'),
    noMatchTitle: context.tr('no_recurring_invoices_match_filters'),
  );
}
