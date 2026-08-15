import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/project_dao.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/projects/view_models/project_edit_view_model.dart';
import 'package:admin/ui/features/projects/view_models/project_list_view_model.dart';
import 'package:admin/ui/features/projects/widgets/project_actions.dart';
import 'package:admin/ui/features/projects/widgets/project_list_empty_state.dart';
import 'package:admin/ui/features/projects/widgets/project_list_tile.dart';
import 'package:admin/ui/features/projects/widgets/project_token_search_field.dart';

/// Projects list screen — pure config + per-entity widgets. Mirrors
/// `ProductListScreen` / `TaskListScreen`; the screen-level chrome lives
/// in `EntityListScreenScaffold`.
class ProjectListScreen extends StatelessWidget {
  const ProjectListScreen({super.key, this.clientId, this.embedded = false});

  /// When set, the list is filtered to one client.
  final String? clientId;

  /// True when this list lives inside another screen's body.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final cid = clientId;
    return EntityListScreenScaffold<Project, ProjectListViewModel>(
      titleKey: 'projects',
      newRoute: '/projects/new',
      newLabelKey: 'new_project',
      // Project's createBuilder reads `?client=` (prefillClientId).
      embeddedNewOverride: cid == null
          ? null
          : (ctx) => goEntityCreateFullWidth(
              ctx,
              '/projects',
              extra: emptyProject().copyWith(clientId: cid),
            ),
      emptyIcon: Icons.work_outline,
      emptyTitleKey: 'no_projects_yet',
      wantsFormatter: true,
      embedded: embedded,
      buildVm: (services, companyId) => ProjectListViewModel(
        repo: services.projects,
        companyId: companyId,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
        clientId: clientId,
      ),
      sortOptions: (context) => [
        SortOption(id: ProjectFieldIds.name, label: context.tr('name')),
        SortOption(id: ProjectFieldIds.number, label: context.tr('number')),
        SortOption(id: ProjectFieldIds.clientId, label: context.tr('client')),
        SortOption(id: ProjectFieldIds.dueDate, label: context.tr('due_date')),
        SortOption(
          id: ProjectFieldIds.budgetedHours,
          label: context.tr('budgeted_hours'),
        ),
        SortOption(
          id: ProjectFieldIds.currentHours,
          label: context.tr('current_hours'),
        ),
        SortOption(
          id: ProjectFieldIds.taskRate,
          label: context.tr('task_rate'),
        ),
        SortOption(
          id: ProjectFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          ProjectTokenSearchField(vm: vm, wide: wide),
      emptyStateBuilder: (context, vm) => ProjectListEmptyState(vm: vm),
      tileBuilder: (context, vm, project, index, options) {
        final isUrlSelected = options.selectedId == project.id;
        return ProjectListTile(
          project: project,
          columns: options.wide ? vm.columns : const [],
          wide: options.wide,
          editable: options.editable,
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(project.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(project.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/projects',
                )
              : () => goEntityRecord(context, vm.entityType, project.id),
          onLongPress: () => vm.toggleSelected(project.id),
          onSelectTap: () => vm.toggleSelected(project.id),
          onAction: options.selecting
              ? null
              : (action) => ProjectActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  project,
                  action,
                ),
        );
      },
      bulkActions: [
        const EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_project',
          pluralSuccessKey: 'archived_projects',
          nothingKey: 'nothing_to_archive',
        ),
        const EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_project',
          pluralSuccessKey: 'restored_projects',
          nothingKey: 'nothing_to_restore',
        ),
        const EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_project',
          pluralSuccessKey: 'deleted_projects',
          nothingKey: 'nothing_to_delete',
        ),
        // Selection-level actions (handled by `onSelection`, not the per-id
        // loop). companyId comes from the session at call time.
        EntityListBulkAction(
          actionId: 'invoice_project',
          icon: Icons.outbox_outlined,
          tooltipKey: 'invoice_project',
          singleSuccessKey: 'invoice_project',
          pluralSuccessKey: 'invoice_project',
          nothingKey: 'nothing_to_invoice',
          onSelection: (ctx, sel) {
            final services = ctx.read<Services>();
            return ProjectActions.invoiceProjects(
              ctx,
              services,
              services.auth.session.value!.currentCompanyId,
              sel.cast<Project>(),
            );
          },
        ),
        EntityListBulkAction(
          actionId: 'add_to_invoice',
          icon: Icons.playlist_add,
          tooltipKey: 'add_to_invoice',
          // The bundle's string is "Add to invoice :invoice" and no invoice is
          // picked yet — blank the placeholder rather than show it.
          labelParams: const {'invoice': ''},
          // Unused: `onSelection` handlers do their own toasting.
          singleSuccessKey: 'add_to_invoice',
          pluralSuccessKey: 'add_to_invoice',
          nothingKey: 'nothing_to_invoice',
          onSelection: (ctx, sel) {
            final services = ctx.read<Services>();
            return ProjectActions.addProjectsToInvoice(
              ctx,
              services,
              services.auth.session.value!.currentCompanyId,
              sel.cast<Project>(),
            );
          },
        ),
        EntityListBulkAction(
          actionId: 'download_documents',
          icon: Icons.download_outlined,
          tooltipKey: 'download_documents',
          singleSuccessKey: 'documents',
          pluralSuccessKey: 'documents',
          nothingKey: 'no_documents_to_download',
          onSelection: (ctx, sel) => ProjectActions.downloadDocuments(
            ctx,
            ctx.read<Services>(),
            sel.cast<Project>(),
          ),
        ),
      ],
    );
  }
}
