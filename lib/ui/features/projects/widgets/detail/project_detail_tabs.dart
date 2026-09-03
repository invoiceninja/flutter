import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/expenses/views/expense_list_screen.dart';
import 'package:admin/ui/features/invoices/views/invoice_list_screen.dart';
import 'package:admin/ui/features/projects/widgets/detail/analytics/project_analytics_tab.dart';
import 'package:admin/ui/features/quotes/views/quote_list_screen.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart';
import 'package:admin/utils/formatting.dart';

/// Bottom of the project detail screen: a tab strip of project-scoped
/// related-entity tables (Tasks, Invoices, Quotes, Expenses) plus the
/// standard Documents tab and an Activity feed.
///
/// Each related-entity tab embeds the corresponding workspace list screen
/// in `embedded: true` mode scoped to this project via its `projectId`
/// constructor param. The embedded scaffold renders its own slim toolbar
/// (filter + project-prefilled "New") and grows with the detail page.
/// Mirrors `ClientDetailTabs`; tabs whose module is disabled are hidden.
class ProjectDetailTabs extends StatelessWidget {
  const ProjectDetailTabs({
    required this.project,
    required this.formatter,
    required this.activityVm,
    required this.selectTab,
    super.key,
  });

  final Project project;
  final Formatter? formatter;

  /// Owned by `ProjectDetailScreen` so the Comments card above this strip and
  /// the two feed tabs below it share one fetch.
  final EntityActivityViewModel activityVm;
  final TabSelectionController selectTab;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.currentCompanyId ?? '';
    final projectId = project.id;
    // Hide related-entity tabs whose module is disabled for this company.
    final me = services.auth.session.value?.currentCompany;
    // Built as a local so the Comments tab's index can be derived rather than
    // guessed: six of these entries are gated, and Comments sits second-to-last
    // (see the tab itself for why it isn't first).
    final tabs = <EntityDetailTab>[
      if (me?.moduleEnabled(EntityType.task) ?? false)
        EntityDetailTab(
          label: context.tr('tasks'),
          icon: Icons.check_circle_outline,
          bodyBuilder: (_) =>
              TaskListScreen(projectId: projectId, embedded: true),
        ),
      if (me?.moduleEnabled(EntityType.invoice) ?? false)
        EntityDetailTab(
          label: context.tr('invoices'),
          icon: Icons.receipt_long_outlined,
          bodyBuilder: (_) =>
              InvoiceListScreen(projectId: projectId, embedded: true),
        ),
      if (me?.moduleEnabled(EntityType.quote) ?? false)
        EntityDetailTab(
          label: context.tr('quotes'),
          icon: Icons.request_quote_outlined,
          bodyBuilder: (_) =>
              QuoteListScreen(projectId: projectId, embedded: true),
        ),
      if (me?.moduleEnabled(EntityType.expense) ?? false)
        EntityDetailTab(
          label: context.tr('expenses'),
          icon: Icons.account_balance_wallet_outlined,
          bodyBuilder: (_) =>
              ExpenseListScreen(projectId: projectId, embedded: true),
        ),
      buildStandardDocumentsTab(
        context: context,
        companyId: companyId,
        entityId: project.id,
        documents: project.documents,
        repo: services.projects,
        formatter: formatter,
      ),
      // Server-computed analytics + burn-up. Gated on `view_dashboard`
      // because that's what both chart endpoints authorize against
      // (`ShowProjectAnalyticsRequest::authorize`) — without the gate a
      // restricted user would get a tab that can only 403. Also hidden for
      // an unsynced project: the endpoints are keyed by the server id, and
      // a `tmp_` id can only 404.
      if ((me?.can('view_dashboard') ?? false) && !projectId.startsWith('tmp_'))
        EntityDetailTab(
          label: context.tr('analytics'),
          icon: Icons.insights_outlined,
          bodyBuilder: (_) =>
              ProjectAnalyticsTab(projectId: projectId, formatter: formatter),
        ),
      // Read-only: `ProjectRepository` has no `addComment`, so this tab sits
      // beside Activity rather than taking first place the way the writable
      // entities do.
      EntityDetailTab(
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
        label: context.tr('activity'),
        icon: Icons.history_outlined,
        bodyBuilder: (_) => EntityActivityTab(
          vm: activityVm,
          formatter: formatter,
          hostWireName: 'project',
        ),
      ),
    ];
    return EntityDetailTabs(tabs: tabs, selectTab: selectTab);
  }
}
