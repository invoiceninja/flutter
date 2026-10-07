import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/project.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/detail/related_rows_proof.dart';
import 'package:admin/ui/core/list/embedded_list_parent_scope.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/features/projects/view_models/project_detail_view_model.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_detail_header.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_detail_profile.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_detail_standing.dart';
import 'package:admin/ui/features/projects/widgets/detail/project_detail_tabs.dart';
import 'package:admin/ui/features/projects/widgets/project_actions.dart';

/// The project record screen, on the record layout
/// (`docs/detail-screen-layout.md`): identity, quick actions, standing,
/// comments and the profile above a pinned tab strip.
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with FormatterHostMixin {
  late final ProjectDetailViewModel _vm;
  late final EntityActivityViewModel _activityVm;
  late final RecordScreenController _record;

  /// The project's tasks, handed over only when they are all of them — what
  /// the standing card adds up and the chart plots. See [RelatedRowsProof].
  late final RelatedRowsProof<Task> _tasks;
  late final Services _services;
  late final String _companyId;

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = ProjectDetailViewModel.bound(
      _services.projects.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from
    // `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'project',
      entityId: widget.id,
    );
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'project',
      refreshRecord: (id) =>
          _services.projects.refreshByIds(companyId: _companyId, ids: [id]),
      hasRecord: () => _vm.item != null,
      countFilterKey: 'project_id',
      // The server names a project differently on each list — see there.
      countFilterKeys: ProjectDetailTabs.countFilterKeys,
      // One small request per related tab, for the number beside its label.
      countFetchers: {
        DetailTabIds.tasks: _services.tasks.api.count,
        DetailTabIds.invoices: _services.invoices.api.count,
        DetailTabIds.expenses: _services.expenses.api.count,
      },
      // All three lists send this unless they are scoped to a client (their
      // repositories pass `excludeDeletedClients`), and the server then
      // leaves out rows whose client is archived or deleted. Counted without
      // it, a badge is not the rows its tab fetches — and the Tasks count is
      // also what `_tasks` measures the device's rows against.
      countExtras: const {
        DetailTabIds.tasks: {'without_deleted_clients': 'true'},
        DetailTabIds.invoices: {'without_deleted_clients': 'true'},
        DetailTabIds.expenses: {'without_deleted_clients': 'true'},
      },
      refreshWith: [_activityVm.refresh],
      refreshAfter: [() => _tasks.refresh()],
      onBackOnline: () => _tasks.retryIfUnanswered(),
    );
    _tasks = RelatedRowsProof<Task>(
      // The same rows the count is of and the fetch below brings: not those
      // of an archived or deleted client.
      watch: (projectId) => _services.tasks.watchForProject(
        companyId: _companyId,
        projectId: projectId,
        activeClientsOnly: true,
      ),
      // The Tasks tab's own request, a page at a time: `project_tasks` with
      // the list's default `status=active` — the rows the watch above holds
      // and the rows the tab's count is of. Scoped, so it neither reads nor
      // moves the task sync cursor.
      fetchPage: (projectId, page) => _services.tasks.ensurePageLoaded(
        companyId: _companyId,
        page: page,
        extraFilters: {
          ProjectDetailTabs.countFilterKeys[DetailTabIds.tasks]!: {projectId},
        },
      ),
      idOf: (t) => t.id,
      pageSize: _services.tasks.pageSize,
      // The count the Tasks tab's badge already asks for.
      counts: _record,
      countTabId: DetailTabIds.tasks,
      isCurrent: () =>
          _services.auth.session.value?.currentCompanyId == _companyId,
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    // Before the controller it listens to.
    _tasks.dispose();
    _record.dispose();
    _activityVm.dispose();
    _vm.dispose();
    super.dispose();
  }

  void _dispatch(Project p, ProjectAction action) =>
      ProjectActions.dispatch(context, _services, _companyId, p, action);

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Project>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.projects.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.project),
      emptyIcon: Icons.work_outline,
      emptyTitle: context.tr('project_not_found'),
      // `p` is captured at item-tap time — a late-arriving stream update
      // can't change which project gets archived/restored mid-action.
      actionsForItem: (context, p) => EntityDetailActionsRow<ProjectAction>(
        items: ProjectActions.itemsFor(context, p, (a) => _dispatch(p, a)),
      ),
      compactTitleForItem: (context, p) => _CompactTitle(project: p),
      // A deleted project is read-only until restored.
      isReadOnly: (p) => p.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, p) => recordStateBanner<ProjectAction>(
        context,
        items: ProjectActions.itemsFor(context, p, (a) => _dispatch(p, a)),
        restoreKind: ProjectAction.restore,
        entityId: p.id,
        isDeleted: p.isDeleted,
        archivedAt: p.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, p) => _body(context, p),
    );
  }

  Widget _body(BuildContext context, Project p) {
    _activityVm.kick();
    final me = _services.auth.session.value?.currentCompany;
    final related = ProjectDetailTabs.relatedTabIds(
      (t) => me?.moduleEnabled(t) ?? false,
    );
    _record.attach(
      recordId: p.id,
      revision: p.updatedAt,
      // Only the tabs the server can count — Quotes is not one of them.
      tabIds: related.intersection(
        ProjectDetailTabs.countFilterKeys.keys.toSet(),
      ),
    );
    // The tabs own the `TabController`, so they wrap the page and hand back
    // the strip and the body for it to place — which is what lets the strip
    // stay pinned while a long list scrolls under it.
    //
    // The scope tells the lists embedded in those tabs what they cannot know
    // from a project id alone: that this project is deleted (no New), or not
    // yet synced (New goes through the sync guard).
    return EmbeddedListParentScope(
      parentId: p.id,
      readOnly: p.isDeleted,
      intents: _record.listIntents,
      child: ProjectDetailTabs(
        project: p,
        formatter: formatter,
        activityVm: _activityVm,
        selectTab: _record.selectTab,
        readOnly: p.isDeleted,
        counts: _record,
        onReveal: _record.page.revealTabs,
        layoutBuilder: (context, strip, body) => _record.buildPage(
          strip: strip,
          body: body,
          top: _top(context, p, related),
        ),
      ),
    );
  }

  /// Everything above the tabs.
  ///
  /// Two sources, hoisted here because more than one slot needs each answer.
  /// The company row names the custom fields the Details card may draw. The
  /// project's tasks ([_tasks]) are what the standing card adds up, what the
  /// chart plots, and what decides whether the Invoice tile is worth its slot
  /// — three widgets each watching them could disagree for a frame.
  Widget _top(BuildContext context, Project p, Set<String> related) {
    final me = _services.auth.session.value?.currentCompany;
    // Nothing here is derived from tasks for a user who may not view them:
    // the local table would hold none (or only their own), and a total added
    // up from that is a wrong number, not a small one.
    final mayViewTasks =
        (me?.moduleEnabled(EntityType.task) ?? false) &&
        (me?.can('view_task') ?? false);
    return WatchBuilder<Company?>(
      cacheKey: _companyId,
      // Seeded from what is already in memory, so the rows that depend on the
      // company (custom-field labels) are there in the first frame rather
      // than arriving a frame late and pushing the tabs down.
      initialData: _services.company.peek(
        companyId: _companyId,
        id: _companyId,
      ),
      create: () => _services.company.watchCompany(_companyId),
      builder: (context, company) => ListenableBuilder(
        listenable: _tasks,
        builder: (context, _) {
          // From the record, never the route: a project opened while still
          // `tmp_…` keeps that route after it syncs.
          if (mayViewTasks) _tasks.attach(p.id);
          // Added up only when they are all of them. A project with more
          // tasks than this device has fetched would otherwise show the hours
          // and the uninvoiced amount of the first fifty as if they were the
          // project's — so until the rest are in, the card falls back to the
          // server's own running total and prints no money figure.
          final tasks = mayViewTasks ? _tasks.rows : null;
          // Whatever is held, complete or not: "is there anything to
          // invoice" may be answered from part of the list.
          final held = mayViewTasks ? _tasks.held : null;
          return EntityRecordColumn(
            header: ProjectDetailHeader(
              project: p,
              formatter: formatter,
              // The banner above the page already says Deleted / Archived.
              showStatePills: !p.isDeleted && p.archivedAt == null,
            ),
            quickActions: EntityQuickActions<ProjectAction>(
              priority: ProjectActions.quickItemsFor(
                context,
                p,
                (a) => _dispatch(p, a),
                hasBillableWork:
                    held != null && ProjectActions.hasBillableTasks(held),
              ),
            ),
            standing: ProjectDetailStanding(
              project: p,
              tasks: tasks,
              companyId: _companyId,
              formatter: formatter,
              tabIds: related,
              onOpenTab: _record.selectTab.selectId,
              showUninvoiced: me?.moduleEnabled(EntityType.invoice) ?? false,
              // May view them, and they are simply not all here yet.
              tasksPending: mayViewTasks && tasks == null,
            ),
            // Read-only: a project takes no comments of its own, so the card
            // shows the ones its tasks and invoices carry and hides itself
            // when there are none.
            comments: EntityCommentsCard(
              vm: _activityVm,
              formatter: formatter,
              hostWireName: 'project',
              onViewAll: () => _record.selectTab.select(kCommentsTabIndex),
              matchFormColumn: true,
            ),
            profile: ProjectDetailProfile(
              project: p,
              company: company.data,
              tasks: tasks,
              formatter: formatter,
            ),
          );
        },
      ),
    );
  }
}

/// The project's name and its client, for the fixed bar once the header has
/// scrolled away — so a long task list still says whose it is.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // The header's cascade, to its end: a project with no name is
          // "(no name)" there, and must not be a blank line here.
          project.name.isNotEmpty
              ? project.name
              : context.tr('no_name_fallback'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (project.clientId.isNotEmpty)
          // Plain text: the bar is a tap target of its own (scroll to top).
          ClientNameLabel(
            clientId: project.clientId,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink2),
          ),
      ],
    );
  }
}
