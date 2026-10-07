import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/quick_create.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/related_tab_counts.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/expenses/views/expense_list_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_list_screen.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/project_analytics_tab.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_quick_add_task.dart';
import 'package:admin/ui/features/quotes/views/quote_list_screen.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart';
import 'package:admin/utils/formatting.dart';

/// Bottom of the project record screen: the record's own history, then the
/// project-scoped related lists (Tasks, Invoices, Quotes, Expenses), the
/// standard Documents tab and the server-computed Analytics.
///
/// Each related-entity tab embeds the corresponding workspace list screen in
/// `embedded: true` mode scoped to this project via its `projectId`
/// constructor param. The embedded scaffold renders its own slim toolbar
/// (filter + project-prefilled "New") and grows with the page. Mirrors
/// `ClientDetailTabs`; tabs whose module is disabled are hidden.
class ProjectDetailTabs extends StatelessWidget {
  const ProjectDetailTabs({
    required this.project,
    required this.formatter,
    required this.activityVm,
    required this.selectTab,
    this.layoutBuilder,
    this.onReveal,
    this.readOnly = false,
    this.counts,
    super.key,
  });

  final Project project;
  final Formatter? formatter;

  /// Owned by `ProjectDetailScreen` so the Comments card above this strip and
  /// the two feed tabs below it share one fetch.
  final EntityActivityViewModel activityVm;
  final TabSelectionController selectTab;

  /// Passed straight to [EntityDetailTabs] — the record page uses these to pin
  /// the strip and to bring it into view. See there.
  final EntityDetailTabsLayoutBuilder? layoutBuilder;
  final VoidCallback? onReveal;

  /// The project is deleted. Documents lists what is there and offers nothing
  /// else, and there is no quick-add. (The related lists get the same news
  /// through `EmbeddedListParentScope`.)
  final bool readOnly;

  /// How many records each related tab holds, when the server has said. Null
  /// (a host that does not count) and "not known yet" both draw no badge.
  final TabCounts? counts;

  /// The related-record tabs this company's modules allow, by id.
  ///
  /// The one gate for both halves of the screen: [build] draws a tab only for
  /// an id in this set, the standing card links a figure only to one, and the
  /// screen asks the server to count only these.
  static Set<String> relatedTabIds(bool Function(EntityType) moduleEnabled) => {
    if (moduleEnabled(EntityType.task)) DetailTabIds.tasks,
    if (moduleEnabled(EntityType.invoice)) DetailTabIds.invoices,
    if (moduleEnabled(EntityType.quote)) DetailTabIds.quotes,
    if (moduleEnabled(EntityType.expense)) DetailTabIds.expenses,
  };

  /// The tabs the server can count for a project, and the list filter that
  /// scopes each to one — **the key that tab's own embedded list sends**, so
  /// the badge is the number of rows the tab will show.
  ///
  /// The server does not name a project the same way twice: it is
  /// `project_tasks` on tasks (`TaskFilters`), `project_id` on invoices
  /// (`InvoiceFilters`) and `project_ids` on expenses (`ExpenseFilters`).
  /// Quotes are not here because `QuoteFilters` has no project filter at all —
  /// that list is narrowed locally, and a count taken without the filter
  /// would be every quote the company has.
  static const Map<String, String> countFilterKeys = {
    DetailTabIds.tasks: 'project_tasks',
    DetailTabIds.invoices: 'project_id',
    DetailTabIds.expenses: 'project_ids',
  };

  @override
  Widget build(BuildContext context) {
    final counts = this.counts;
    if (counts == null) return _tabs(context);
    // A count lands after the strip is on screen; only the strip's own
    // subtree needs to hear about it.
    return ListenableBuilder(
      listenable: counts,
      builder: (context, _) => _tabs(context),
    );
  }

  /// Keys an embedded list on the project's id.
  ///
  /// A list builds its view model once, with the id it was first given. A
  /// project opened while still `tmp_…` and synced with the screen open comes
  /// back through here with its server id — and without a key the list would
  /// keep asking about, and watching for, an id that no longer exists.
  static Widget _scoped(String projectId, Widget list) =>
      KeyedSubtree(key: ValueKey<String>(projectId), child: list);

  Widget _tabs(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.currentCompanyId ?? '';
    final projectId = project.id;
    // Hide related-entity tabs whose module is disabled for this company.
    final me = services.auth.session.value?.currentCompany;
    final related = relatedTabIds((t) => me?.moduleEnabled(t) ?? false);
    final quickAdd = ProjectQuickAddTask.appliesTo(
      project,
      canCreateTask: me?.can(createPermissionFor(EntityType.task)) ?? false,
    );
    return EntityDetailTabs(
      // 2: the pair leads, so the landing tab is still the first content tab.
      initialIndex: 2,
      selectTab: selectTab,
      layoutBuilder: layoutBuilder,
      onReveal: onReveal,
      tabs: [
        // The record's own history leads the strip on every entity that has
        // one: Comments is a filtered view of Activity, and on a project the
        // pair used to sit 7th and 8th of 8, i.e. behind a horizontal scroll
        // (invoiceninja/flutter#122). Read-only here — `ProjectRepository` has
        // no `addComment` — but Activity is read-only everywhere, so that is
        // no reason to bury it.
        EntityDetailTab(
          id: DetailTabIds.comments,
          label: context.tr('comments'),
          icon: Icons.comment_outlined,
          bodyBuilder: (_) => EntityActivityTab(
            vm: activityVm,
            formatter: formatter,
            commentsOnly: true,
            hostWireName: 'project',
          ),
        ),
        EntityDetailTab(
          id: DetailTabIds.activity,
          label: context.tr('activity'),
          icon: Icons.history_outlined,
          bodyBuilder: (_) => EntityActivityTab(
            vm: activityVm,
            formatter: formatter,
            hostWireName: 'project',
          ),
        ),
        if (related.contains(DetailTabIds.tasks))
          EntityDetailTab(
            id: DetailTabIds.tasks,
            count: counts?.countFor(DetailTabIds.tasks),
            label: context.tr('tasks'),
            icon: Icons.check_circle_outline,
            bodyBuilder: (context) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rapid entry heads the list it feeds: a task typed here
                // appears as the first row beneath it.
                if (quickAdd) ...[
                  SizedBox(height: InSpacing.md(context)),
                  ProjectQuickAddTask(project: project, companyId: companyId),
                ],
                _scoped(
                  projectId,
                  TaskListScreen(projectId: projectId, embedded: true),
                ),
              ],
            ),
          ),
        if (related.contains(DetailTabIds.invoices))
          EntityDetailTab(
            id: DetailTabIds.invoices,
            count: counts?.countFor(DetailTabIds.invoices),
            label: context.tr('invoices'),
            icon: Icons.receipt_long_outlined,
            bodyBuilder: (_) => _scoped(
              projectId,
              InvoiceListScreen(projectId: projectId, embedded: true),
            ),
          ),
        if (related.contains(DetailTabIds.quotes))
          EntityDetailTab(
            id: DetailTabIds.quotes,
            // No count: the server cannot scope quotes to a project — see
            // [countFilterKeys].
            label: context.tr('quotes'),
            icon: Icons.request_quote_outlined,
            bodyBuilder: (_) => _scoped(
              projectId,
              QuoteListScreen(projectId: projectId, embedded: true),
            ),
          ),
        if (related.contains(DetailTabIds.expenses))
          EntityDetailTab(
            id: DetailTabIds.expenses,
            count: counts?.countFor(DetailTabIds.expenses),
            label: context.tr('expenses'),
            icon: Icons.account_balance_wallet_outlined,
            bodyBuilder: (_) => _scoped(
              projectId,
              ExpenseListScreen(projectId: projectId, embedded: true),
            ),
          ),
        buildStandardDocumentsTab(
          context: context,
          companyId: companyId,
          entityId: project.id,
          documents: project.documents,
          repo: services.projects,
          formatter: formatter,
          readOnly: readOnly,
        ),
        // Server-computed analytics + burn-up. Gated on `view_dashboard`
        // because that's what both chart endpoints authorize against
        // (`ShowProjectAnalyticsRequest::authorize`) — without the gate a
        // restricted user would get a tab that can only 403. Also hidden for
        // an unsynced project: the endpoints are keyed by the server id, and
        // a `tmp_` id can only 404.
        if ((me?.can('view_dashboard') ?? false) &&
            !projectId.startsWith('tmp_'))
          EntityDetailTab(
            id: DetailTabIds.analytics,
            label: context.tr('analytics'),
            icon: Icons.insights_outlined,
            bodyBuilder: (_) => _scoped(
              projectId,
              ProjectAnalyticsTab(projectId: projectId, formatter: formatter),
            ),
          ),
      ],
    );
  }
}
