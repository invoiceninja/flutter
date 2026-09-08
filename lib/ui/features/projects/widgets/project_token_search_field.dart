import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/projects/project_filter_keys.dart';
import 'package:admin/ui/features/projects/view_models/project_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the projects list.
class ProjectTokenSearchField extends StatelessWidget {
  const ProjectTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final ProjectListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    hintKey: 'search_projects_or_filter_hint',
    customFieldPrefix: 'project',
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
    keysBuilder: (services, companyId, company, names) =>
        buildProjectFilterKeys(
          clients: services.clients,
          tags: services.tags,
          companyId: companyId,
          company: company,
          nameForClientId: (id) => names.lookup(0, id),
        ),
  );
}
