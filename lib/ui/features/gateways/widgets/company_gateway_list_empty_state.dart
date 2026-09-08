import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/gateways/view_models/company_gateway_list_view_model.dart';

class CompanyGatewayListEmptyState extends StatelessWidget {
  const CompanyGatewayListEmptyState({super.key, required this.vm});

  final CompanyGatewayListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.account_balance_wallet_outlined,
    emptyTitle: context.tr('no_company_gateways_yet'),
    emptySubtitle: context.tr('create_your_first_company_gateway_placeholder'),
    // Gateways are created from Settings, not from a list "New" button, so
    // the first-run state carries its own way in.
    emptyAction: FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
      onPressed: () => context.go('/settings/company_gateways/new'),
      icon: const Icon(Icons.add),
      label: Text(context.tr('add_gateway')),
    ),
    archivedTitle: context.tr('no_archived_company_gateways'),
    deletedTitle: context.tr('no_deleted_company_gateways'),
    noMatchTitle: context.tr('no_company_gateways_match_filters'),
  );
}
