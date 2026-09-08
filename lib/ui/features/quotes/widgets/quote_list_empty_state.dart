import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/quotes/view_models/quote_list_view_model.dart';

class QuoteListEmptyState extends StatelessWidget {
  const QuoteListEmptyState({super.key, required this.vm});

  final QuoteListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.request_quote_outlined,
    emptyTitle: context.tr('no_quotes_yet'),
    emptySubtitle: context.tr('create_your_first_quote_placeholder'),
    archivedTitle: context.tr('no_archived_quotes'),
    deletedTitle: context.tr('no_deleted_quotes'),
    noMatchTitle: context.tr('no_quotes_match_filters'),
  );
}
