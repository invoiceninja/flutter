import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_empty_state.dart';
import 'package:admin/ui/features/projects/view_models/project_list_view_model.dart';

class ProjectListEmptyState extends StatelessWidget {
  const ProjectListEmptyState({super.key, required this.vm});

  final ProjectListViewModel vm;

  @override
  Widget build(BuildContext context) => EntityListEmptyState(
    vm: vm,
    icon: Icons.work_outline,
    emptyTitle: context.tr('no_projects_yet'),
    emptySubtitle: context.tr('create_your_first_project_placeholder'),
    archivedTitle: context.tr('no_archived_projects'),
    deletedTitle: context.tr('no_deleted_projects'),
    noMatchTitle: context.tr('no_projects_match_filters'),
  );
}
