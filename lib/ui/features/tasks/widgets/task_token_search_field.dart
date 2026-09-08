import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
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
    keysBuilder: (services, companyId, company, names) => buildTaskFilterKeys(
      clients: services.clients,
      projects: services.projects,
      statuses: services.taskStatuses,
      tags: services.tags,
      companyId: companyId,
      company: company,
      nameForClientId: (id) => names.lookup(0, id),
    ),
  );
}
