import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/payments/view_models/payment_list_view_model.dart';

class PaymentListEmptyState extends StatelessWidget {
  const PaymentListEmptyState({super.key, required this.vm});

  final PaymentListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.payments_outlined,
    emptyTitle: context.tr('no_payments_yet'),
    // No first-run subtitle: a payment is recorded against an invoice, so
    // there is no "create your first payment" path to point at.
    archivedTitle: context.tr('no_archived_payments'),
    deletedTitle: context.tr('no_deleted_payments'),
    noMatchTitle: context.tr('no_payments_match_filters'),
  );
}
