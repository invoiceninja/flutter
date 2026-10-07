import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/build_standard_documents_tab.dart';
import 'package:admin/ui/core/detail/detail_tab_indices.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/entity_detail_scaffold.dart';
import 'package:admin/ui/core/detail/entity_detail_tabs.dart';
import 'package:admin/ui/core/detail/entity_list_empty_action.dart';
import 'package:admin/ui/core/detail/entity_quick_actions.dart';
import 'package:admin/ui/core/detail/entity_record_column.dart';
import 'package:admin/ui/core/detail/entity_state_banner.dart';
import 'package:admin/ui/core/detail/record_screen_controller.dart';
import 'package:admin/ui/core/widgets/client_name_label.dart';
import 'package:admin/ui/core/widgets/formatter_host_mixin.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_tab.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_activity_view_model.dart';
import 'package:admin/ui/features/billing_shared/activity/entity_comments_card.dart';
import 'package:admin/ui/features/tasks/view_models/task_detail_view_model.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_header.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_profile.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_standing.dart';
import 'package:admin/ui/features/tasks/widgets/detail/task_detail_time_log.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';

/// The task record screen, on the record layout
/// (`docs/detail-screen-layout.md`): identity, quick actions, standing,
/// comments and the profile above a pinned tab strip.
class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({required this.id, super.key});
  final String id;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen>
    with FormatterHostMixin {
  late final TaskDetailViewModel _vm;
  late final EntityActivityViewModel _activityVm;
  late final RecordScreenController _record;
  late final Services _services;
  late final String _companyId;

  /// True while a Start / Stop / Resume this screen dispatched is in flight —
  /// from the tile or from the bar above it, which share [_dispatch]. The
  /// timer tile shows it rather than taking a second tap.
  final ValueNotifier<bool> _timerBusy = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _services = context.read<Services>();
    _companyId = _services.auth.session.value!.currentCompanyId;
    _vm = TaskDetailViewModel.bound(
      _services.tasks.watch(companyId: _companyId, id: widget.id),
    );
    // Owned here, not by the Activity tab, so the Comments card, the
    // Comments tab and the Activity tab share one fetch. Armed from
    // `bodyBuilder`.
    _activityVm = EntityActivityViewModel(
      api: _services.activities,
      outbox: _services.db.outboxDao,
      companyId: _companyId,
      entityWireName: 'task',
      entityId: widget.id,
    );
    // No related lists hang off a task, so there is nothing to count.
    _record = RecordScreenController(
      services: _services,
      companyId: _companyId,
      routeId: widget.id,
      entityWireName: 'task',
      refreshRecord: (id) =>
          _services.tasks.refreshByIds(companyId: _companyId, ids: [id]),
      hasRecord: () => _vm.item != null,
      refreshWith: [_activityVm.refresh],
    );
    loadFormatter(_services, _companyId);
  }

  @override
  void dispose() {
    _timerBusy.dispose();
    _record.dispose();
    _activityVm.dispose();
    _vm.dispose();
    super.dispose();
  }

  Future<void> _dispatch(Task t, TaskAction action) async {
    if (!TaskActions.isTimerAction(action)) {
      return TaskActions.dispatch(context, _services, _companyId, t, action);
    }
    // One timer write at a time. A second tap while the first is in flight
    // would be planned against a task that is about to change under it.
    if (_timerBusy.value) return;
    _timerBusy.value = true;
    try {
      await TaskActions.dispatch(context, _services, _companyId, t, action);
    } finally {
      if (mounted) _timerBusy.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return EntityDetailScaffold<Task>(
      id: widget.id,
      vm: _vm,
      hydrate: () =>
          _services.tasks.ensureLoaded(companyId: _companyId, id: widget.id),
      emptyAction: entityListEmptyAction(context, EntityType.task),
      emptyIcon: Icons.task_outlined,
      emptyTitle: context.tr('task_not_found'),
      // `t` is captured at item-tap time — a late-arriving stream update
      // can't change which task gets archived/restored mid-action.
      actionsForItem: (context, t) => EntityDetailActionsRow<TaskAction>(
        items: TaskActions.itemsFor(context, t, (a) => _dispatch(t, a)),
      ),
      compactTitleForItem: (context, t) => _CompactTitle(task: t),
      // A deleted task is read-only until restored.
      isReadOnly: (t) => t.isDeleted,
      onRefresh: _record.refresh,
      bannerForItem: (context, t) => recordStateBanner<TaskAction>(
        context,
        items: TaskActions.itemsFor(context, t, (a) => _dispatch(t, a)),
        restoreKind: TaskAction.restore,
        entityId: t.id,
        isDeleted: t.isDeleted,
        archivedAt: t.archivedAt,
        formatter: formatter,
      ),
      bodyBuilder: (context, t) => _body(context, t),
    );
  }

  Widget _body(BuildContext context, Task t) {
    _activityVm.kick();
    _record.attach(recordId: t.id, revision: t.updatedAt);
    // The tabs own the `TabController`, so they wrap the page and hand back
    // the strip and the body for it to place — which is what lets the strip
    // stay pinned while a long time log scrolls under it.
    return EntityDetailTabs(
      // 2: the Comments + Activity pair leads, so the landing tab is still
      // the task's own content — its time log.
      initialIndex: 2,
      selectTab: _record.selectTab,
      onReveal: _record.page.revealTabs,
      layoutBuilder: (context, strip, body) =>
          _record.buildPage(strip: strip, body: body, top: _top(context, t)),
      tabs: [
        // The record's own history leads the strip on every entity that has
        // one: Comments is a filtered view of Activity, and burying either
        // behind a horizontal scroll is what invoiceninja/flutter#122 was
        // about. Read-only here — `TaskRepository` has no `addComment` — but
        // Activity is read-only everywhere, so that is no reason to bury it.
        EntityDetailTab(
          id: DetailTabIds.comments,
          label: context.tr('comments'),
          icon: Icons.comment_outlined,
          bodyBuilder: (_) => EntityActivityTab(
            vm: _activityVm,
            formatter: formatter,
            commentsOnly: true,
            hostWireName: 'task',
          ),
        ),
        EntityDetailTab(
          id: DetailTabIds.activity,
          label: context.tr('activity'),
          icon: Icons.history_outlined,
          bodyBuilder: (_) => EntityActivityTab(
            vm: _activityVm,
            formatter: formatter,
            hostWireName: 'task',
          ),
        ),
        // What the Overview tab came down to once its figures moved to the
        // standing card and its cards to the profile: the entries themselves.
        EntityDetailTab(
          id: DetailTabIds.timeLog,
          // Exact: the log rides on the task's own payload.
          count: t.timeLog.length,
          label: context.tr('time_log'),
          icon: Icons.timer_outlined,
          bodyBuilder: (_) => TaskDetailTimeLog(task: t, formatter: formatter),
        ),
        buildStandardDocumentsTab(
          context: context,
          companyId: _companyId,
          entityId: t.id,
          documents: t.documents,
          repo: _services.tasks,
          formatter: formatter,
          // A deleted task lists what it has and takes nothing new.
          readOnly: t.isDeleted,
        ),
      ],
    );
  }

  /// Everything above the tabs.
  ///
  /// One company watch, hoisted here, feeds the profile: which Details rows
  /// exist depends on the labels the company has given its custom fields.
  Widget _top(BuildContext context, Task t) {
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
      builder: (context, company) => EntityRecordColumn(
        header: TaskDetailHeader(
          task: t,
          formatter: formatter,
          // The banner above the page already says Deleted / Archived.
          showStatePills: !t.isDeleted && t.archivedAt == null,
        ),
        quickActions: EntityQuickActions<TaskAction>(
          priority: TaskActions.quickItemsFor(
            context,
            t,
            (a) => _dispatch(t, a),
            timerBusy: _timerBusy,
          ),
        ),
        standing: TaskDetailStanding(
          task: t,
          companyId: _companyId,
          formatter: formatter,
          onOpenTab: _record.selectTab.selectId,
        ),
        // Read-only: a task takes no comments of its own, so the card shows
        // what there is and hides itself when there is nothing.
        comments: EntityCommentsCard(
          vm: _activityVm,
          formatter: formatter,
          hostWireName: 'task',
          onViewAll: () => _record.selectTab.select(kCommentsTabIndex),
          matchFormColumn: true,
        ),
        profile: TaskDetailProfile(
          task: t,
          company: company.data,
          formatter: formatter,
        ),
      ),
    );
  }
}

/// The task's name and its client, for the fixed bar once the header has
/// scrolled away — so a long time log still says whose it is.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // The header's cascade, to its end.
          TaskDetailHeader.displayNameOf(context, task),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: tokens.ink,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (task.clientId.isNotEmpty)
          // Plain text: the bar is a tap target of its own (scroll to top).
          ClientNameLabel(
            clientId: task.clientId,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink2),
          ),
      ],
    );
  }
}
