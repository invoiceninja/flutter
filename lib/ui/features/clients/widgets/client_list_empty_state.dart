import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/clients/view_models/client_list_view_model.dart';

class ClientListEmptyState extends StatelessWidget {
  const ClientListEmptyState({super.key, required this.vm});

  final ClientListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.people_outline,
    emptyTitle: context.tr('no_clients_yet'),
    emptySubtitle: context.tr('create_your_first_client_placeholder'),
    archivedTitle: context.tr('no_archived_clients'),
    deletedTitle: context.tr('no_deleted_clients'),
    noMatchTitle: context.tr('no_clients_match_filters'),
  );
}
