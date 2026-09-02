import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/client.dart';
import 'package:admin/domain/columns/client_columns.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/clients/view_models/client_edit_view_model.dart';
import 'package:admin/ui/features/clients/view_models/client_list_view_model.dart';
import 'package:admin/ui/features/clients/widgets/client_actions.dart';
import 'package:admin/ui/features/clients/widgets/client_bulk_update_dialog.dart';
import 'package:admin/ui/features/clients/widgets/client_list_column_headers.dart';
import 'package:admin/ui/features/clients/widgets/client_list_empty_state.dart';
import 'package:admin/ui/features/clients/widgets/client_list_tile.dart';
import 'package:admin/ui/features/clients/widgets/client_token_search_field.dart';

/// Clients list screen — pure config + per-entity widgets. The screen-level
/// chrome (Scaffold / AppBar / FAB / drawer / body switching / bulk dispatch
/// / company-switch tracking / formatter wiring) lives in
/// [EntityListScreenScaffold]; this class just plugs Clients-specific bits
/// into it.
class ClientListScreen extends StatelessWidget {
  const ClientListScreen({
    super.key,
    this.groupSettingsId,
    this.embedded = false,
  });

  /// When set, the list is filtered to one group (the clients-in-group tab).
  final String? groupSettingsId;

  /// True when this list lives inside another screen's body.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final gid = groupSettingsId;
    return EntityListScreenScaffold<Client, ClientListViewModel>(
      titleKey: 'clients',
      newRoute: '/clients/new',
      newLabelKey: 'new_client',
      embedded: embedded,
      // Stage a draft pre-assigned to this group (route query is dropped on
      // the cross-branch jump; the create screen reads the staged draft).
      embeddedNewOverride: gid == null
          ? null
          : (ctx) => goEntityCreateFullWidth(
              ctx,
              '/clients',
              extra: emptyClient(groupSettingsId: gid),
            ),
      // Money columns — let the scaffold wire `FormatterHostMixin` so the
      // tile renders the per-client currency cascade.
      wantsFormatter: true,
      buildVm: (services, companyId) => ClientListViewModel(
        repo: services.clients,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
        companyId: companyId,
        groupSettingsId: groupSettingsId,
      ),
      sortOptions: (context) => [
        SortOption(id: ClientFieldIds.name, label: context.tr('name')),
        SortOption(id: ClientFieldIds.number, label: context.tr('number')),
        SortOption(id: ClientFieldIds.balance, label: context.tr('balance')),
        SortOption(
          id: ClientFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
        SortOption(id: ClientFieldIds.createdAt, label: context.tr('created')),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          ClientTokenSearchField(vm: vm, wide: wide),
      // Filter-aware empty copy ("no clients yet" vs "no clients match
      // these filters") — wrapper has the branch logic inside.
      emptyStateBuilder: (context, vm) => ClientListEmptyState(vm: vm),
      // Typedef wrapper; equivalent to `EntityListColumnHeaders<Client>`.
      wideColumnHeadersBuilder: (context, vm) =>
          ClientListColumnHeaders(vm: vm),
      tileBuilder: (context, vm, client, index, options) {
        final isUrlSelected = options.selectedId == client.id;
        return ClientListTile(
          client: client,
          formatter: options.formatter,
          wide: options.wide,
          editable: options.editable,
          columns: options.wide ? vm.columns : const <ClientColumn>[],
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(client.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(client.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/clients',
                )
              : () => goEntityRecord(context, vm.entityType, client.id),
          onLongPress: () => vm.toggleSelected(client.id),
          // Desktop entry point: hover reveals a checkbox in the leading
          // slot, click here enters multi-select. Same handler as
          // long-press (touch entry).
          onSelectTap: () => vm.toggleSelected(client.id),
          // Always *to* the record, unlike `onTap` above — this feeds the call
          // picker's "View client" footer, which exists for exactly the case
          // where none of the offered numbers is the one the user wanted.
          onViewRecord: () => goEntityRecord(context, vm.entityType, client.id),
          onAction: options.selecting
              ? null
              : (action) => ClientActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  client,
                  action,
                ),
        );
      },
      bulkActions: const [
        EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_client',
          pluralSuccessKey: 'archived_clients',
          nothingKey: 'nothing_to_archive',
        ),
        EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_client',
          pluralSuccessKey: 'restored_clients',
          nothingKey: 'nothing_to_restore',
        ),
        EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_client',
          pluralSuccessKey: 'deleted_clients',
          nothingKey: 'nothing_to_delete',
        ),
        EntityListBulkAction(
          actionId: 'bulk_update',
          icon: Icons.edit_outlined,
          tooltipKey: 'bulk_update',
          singleSuccessKey: 'updated_client',
          pluralSuccessKey: 'updated_clients',
          nothingKey: 'nothing_to_update',
          prepare: showClientBulkUpdateDialog,
        ),
      ],
    );
  }
}
