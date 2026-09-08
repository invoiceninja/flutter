import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/invoices/view_models/invoice_list_view_model.dart';

class InvoiceListEmptyState extends StatelessWidget {
  const InvoiceListEmptyState({super.key, required this.vm});

  final InvoiceListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.receipt_long_outlined,
    emptyTitle: context.tr('no_invoices_yet'),
    emptySubtitle: context.tr('create_your_first_invoice_placeholder'),
    archivedTitle: context.tr('no_archived_invoices'),
    deletedTitle: context.tr('no_deleted_invoices'),
    noMatchTitle: context.tr('no_invoices_match_filters'),
  );
}
