import 'package:flutter/material.dart';

import 'package:admin/ui/core/list/search/entity_token_search_field.dart';
import 'package:admin/ui/features/clients/client_filter_keys.dart';
import 'package:admin/ui/features/clients/view_models/client_list_view_model.dart';

/// Wires [EntityTokenSearchField] for the clients list: the company (for
/// custom-field labels) plus live group and user name maps, so the `group:`
/// and `assigned:` chips render names rather than raw ids.
class ClientTokenSearchField extends StatelessWidget {
  const ClientTokenSearchField({
    required this.vm,
    required this.wide,
    super.key,
  });

  final ClientListViewModel vm;
  final bool wide;

  @override
  Widget build(BuildContext context) => EntityTokenSearchField(
    vm: vm,
    wide: wide,
    hintKey: 'search_clients_or_filter_hint',
    customFieldPrefix: 'client',
    nameSources: [
      (services, companyId) => services.groupSettings
          .watchAll(companyId: companyId)
          .map(
            (rows) => {
              for (final g in rows)
                if (g.name.isNotEmpty) g.id: g.name,
            },
          ),
      (services, companyId) => services.user
          .watchAllForPicker(companyId: companyId)
          .map(
            (rows) => {
              for (final u in rows)
                if (u.displayName.isNotEmpty) u.id: u.displayName,
            },
          ),
    ],
    keysBuilder: (services, companyId, company, names) => buildClientFilterKeys(
      company: company,
      statics: services.statics,
      groups: services.groupSettings,
      users: services.user,
      tags: services.tags,
      companyId: companyId,
      nameForGroupId: (id) => names.lookup(0, id),
      nameForAssignedId: (id) => names.lookup(1, id),
    ),
  );
}
