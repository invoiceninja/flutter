import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/client_filter_key.dart';
import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/core/list/search/record_chip_names.dart';
import 'package:admin/ui/features/tasks/task_filter_keys.dart';
import 'package:admin/ui/features/tasks/view_models/task_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the tasks list.
class TaskTokenSearchField extends StatelessWidget {
  const TaskTokenSearchField({required this.vm, required this.wide, super.key});

  final TaskListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    hintKey: 'search_tasks_or_filter_hint',
    customFieldPrefix: 'task',
    nameSources: [ClientFilterKey.chipNames, projectChipNames],
    keysBuilder: (services, companyId, company, names) => buildTaskFilterKeys(
      clients: services.clients,
      projects: services.projects,
      statuses: services.taskStatuses,
      tags: services.tags,
      companyId: companyId,
      company: company,
      nameForClientId: (id) => names.lookup(0, id),
      nameForProjectId: (id) => names.lookup(1, id),
    ),
  );
}
