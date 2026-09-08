import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/credits/view_models/credit_list_view_model.dart';

class CreditListEmptyState extends StatelessWidget {
  const CreditListEmptyState({super.key, required this.vm});

  final CreditListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.assignment_return_outlined,
    emptyTitle: context.tr('no_credits_yet'),
    emptySubtitle: context.tr('create_your_first_credit_placeholder'),
    archivedTitle: context.tr('no_archived_credits'),
    deletedTitle: context.tr('no_deleted_credits'),
    noMatchTitle: context.tr('no_credits_match_filters'),
  );
}
