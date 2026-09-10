import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/task_dao.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/tasks/tasks_view_mode.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/entity_list_screen_scaffold.dart';
import 'package:admin/ui/core/list/entity_sort_filter_sheet.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/features/tasks/view_models/task_edit_view_model.dart';
import 'package:admin/ui/features/tasks/view_models/task_list_view_model.dart';
import 'package:admin/ui/features/tasks/views/kanban_screen.dart';
import 'package:admin/ui/features/tasks/views/task_calendar_screen.dart';
import 'package:admin/ui/features/tasks/views/task_daily_screen.dart';
import 'package:admin/ui/features/tasks/views/task_weekly_screen.dart';
import 'package:admin/ui/features/tasks/widgets/task_actions.dart';
import 'package:admin/ui/features/tasks/widgets/task_list_tile.dart';
import 'package:admin/ui/features/tasks/widgets/task_token_search_field.dart';
import 'package:admin/ui/features/tasks/widgets/tasks_view_toggle.dart';

/// Re-exported so `show TasksViewMode` importers keep pointing here while the
/// enum itself lives in a leaf the `lib/app/` controller can import without
/// dragging in a UI screen. Same shape as
/// `lib/domain/columns/<entity>_columns.dart` and its `ids/` leaf.
export 'package:admin/domain/tasks/tasks_view_mode.dart' show TasksViewMode;

/// Tasks list screen. Dispatches to [KanbanScreen] / [TaskCalendarScreen] /
/// [TaskDailyScreen] / [TaskWeeklyScreen], or the standard
/// `EntityListScreenScaffold`. All five share the same AppBar toggle so the
/// user always sees how to switch back.
///
/// The layout is resolved here rather than taken as a given: `?view=` on the
/// URL is the override, and the device-local `Services.tasksView` preference is
/// the fallback for a bare `/tasks`. Before invoiceninja/flutter#133 the URL was
/// the only carrier, and since every structural "up" navigation drops the query
/// string, tapping "New task" from the kanban board and cancelling put the user
/// back on the plain list.
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({
    super.key,
    this.view,
    this.focusDate,
    this.clientId,
    this.projectId,
    this.embedded = false,
    this.hasPane = false,
    this.hasListIntent = false,
  });

  /// The layout `?view=` asked for, or **null** when the URL expressed no
  /// opinion — including `?view=full`, which is `MasterDetailLayout`'s pane
  /// flag sharing the key. Null falls back to the remembered preference.
  final TasksViewMode? view;

  /// Initial focused day/week/month for the time-oriented views, seeded from
  /// `?date=` on the URL (e.g. a calendar day-cell tap deep-links into daily).
  /// Null defaults each view to today. Ignored by list / kanban.
  final Date? focusDate;

  /// When set, the list is filtered to one client.
  final String? clientId;

  /// When set, the list is filtered to one project (embedded in the
  /// Project detail screen's Tasks tab).
  final String? projectId;

  /// True when this list lives inside another screen's body.
  final bool embedded;

  /// True when a master-detail pane is open over this list (`/tasks/:id`,
  /// `/tasks/:id/edit`, `/tasks/new`).
  final bool hasPane;

  /// True when a dashboard `ListFilterIntent` rode in on the route's `extra`.
  final bool hasListIntent;

  @override
  Widget build(BuildContext context) {
    // "Locked" = this screen can only be the plain list, so the remembered
    // preference must not apply. Each arm breaks something silently otherwise —
    // see `resolveTasksViewMode` for what and why.
    final locked =
        embedded ||
        hasPane ||
        hasListIntent ||
        clientId != null ||
        projectId != null;
    return _RememberedTasksView(
      urlView: view,
      locked: locked,
      builder: _bodyFor,
    );
  }

  Widget _bodyFor(BuildContext context, TasksViewMode view) {
    if (view == TasksViewMode.calendar) {
      return TaskCalendarScreen(focusDate: focusDate);
    }
    if (view == TasksViewMode.daily) {
      return TaskDailyScreen(focusDate: focusDate);
    }
    if (view == TasksViewMode.weekly) {
      return TaskWeeklyScreen(focusDate: focusDate);
    }
    if (view == TasksViewMode.kanban) {
      return const KanbanScreen();
    }
    final cid = clientId;
    final pid = projectId;
    return EntityListScreenScaffold<Task, TaskListViewModel>(
      titleKey: 'tasks',
      newRoute: '/tasks/new',
      newLabelKey: 'new_task',
      // Press S to start/stop the timer on the selected/highlighted task —
      // the "fewer clicks" power path. Guarded so S still types in search.
      selectionShortcuts: {
        const SingleActivator(LogicalKeyboardKey.keyS): (ctx, task) {
          if (task == null) return;
          final services = ctx.read<Services>();
          final companyId = services.auth.session.value?.currentCompanyId;
          if (companyId == null) return;
          TaskActions.toggleTimer(ctx, services, companyId, task);
        },
      },
      // Default "Last Updated" column renders via cellDate and the opt-in
      // "Rate" via cellMoney — both read FormatterScope, which the scaffold
      // only provides when this is set (else dates ignore date_format_id).
      wantsFormatter: true,
      embeddedNewOverride: pid != null
          ? ((ctx) => goEntityCreateFullWidth(
              ctx,
              '/tasks',
              extra: emptyTask().copyWith(projectId: pid),
            ))
          : cid == null
          ? null
          : (ctx) => goEntityCreateFullWidth(
              ctx,
              '/tasks',
              extra: emptyTask().copyWith(clientId: cid),
            ),
      emptyIcon: Icons.task_outlined,
      emptyTitleKey: 'no_tasks',
      embedded: embedded,
      buildVm: (services, companyId) => TaskListViewModel(
        repo: services.tasks,
        companyId: companyId,
        navStateDao: services.db.navStateDao,
        userSettings: services.userSettings,
        savedViews: services.savedViews,
        clientId: clientId,
        projectId: projectId,
      ),
      sortOptions: (context) => [
        SortOption(
          id: TaskFieldIds.updatedAt,
          label: context.tr('last_updated'),
        ),
        SortOption(id: TaskFieldIds.number, label: context.tr('number')),
        SortOption(
          id: TaskFieldIds.description,
          label: context.tr('description'),
        ),
        SortOption(id: TaskFieldIds.rate, label: context.tr('rate')),
      ],
      searchFieldBuilder: (context, vm, wide) =>
          TaskTokenSearchField(vm: vm, wide: wide),
      extraAppBarActions: (context, vm, wide) => [
        TasksViewToggle(active: view, wide: wide),
      ],
      tileBuilder: (context, vm, task, index, options) {
        final isUrlSelected = options.selectedId == task.id;
        return TaskListTile(
          task: task,
          companyId: vm.companyId,
          columns: options.wide ? vm.columns : const [],
          wide: options.wide,
          editable: options.editable,
          hideBottomDivider: options.bottomDividerHidden,
          selecting: options.selecting,
          selected: vm.isSelected(task.id) || isUrlSelected,
          urlSelected: isUrlSelected,
          onTap: options.selecting
              ? () => vm.toggleSelected(task.id)
              : isUrlSelected
              ? () => MasterDetailNavScope.requestClose(
                  context,
                  basePath: '/tasks',
                )
              : () => goEntityRecord(context, vm.entityType, task.id),
          onLongPress: () => vm.toggleSelected(task.id),
          onSelectTap: () => vm.toggleSelected(task.id),
          onAction: options.selecting
              ? null
              : (action) => TaskActions.dispatch(
                  context,
                  context.read<Services>(),
                  vm.companyId,
                  task,
                  action,
                ),
        );
      },
      bulkActions: [
        const EntityListBulkAction(
          actionId: 'start',
          icon: Icons.play_arrow_outlined,
          tooltipKey: 'start',
          singleSuccessKey: 'started_task',
          pluralSuccessKey: 'started_tasks',
          nothingKey: 'nothing_to_start',
        ),
        const EntityListBulkAction(
          actionId: 'stop',
          icon: Icons.stop_circle_outlined,
          tooltipKey: 'stop',
          singleSuccessKey: 'stopped_task',
          pluralSuccessKey: 'stopped_tasks',
          nothingKey: 'nothing_to_stop',
        ),
        const EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_task',
          pluralSuccessKey: 'archived_tasks',
          nothingKey: 'nothing_to_archive',
        ),
        const EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_task',
          pluralSuccessKey: 'restored_tasks',
          nothingKey: 'nothing_to_restore',
        ),
        const EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_task',
          pluralSuccessKey: 'deleted_tasks',
          nothingKey: 'nothing_to_delete',
        ),
        // Selection-level actions (handled by `onSelection`, not the per-id
        // loop): one invoice from the whole selection, which may span several
        // projects — each project's first line carries a header so the
        // customer can tell them apart. Forum #23511.
        EntityListBulkAction(
          actionId: 'invoice_task',
          icon: Icons.outbox_outlined,
          tooltipKey: 'invoice_task',
          // Unused: `onSelection` handlers do their own toasting.
          singleSuccessKey: 'invoice_task',
          pluralSuccessKey: 'invoice_task',
          nothingKey: 'nothing_to_invoice',
          onSelection: (ctx, sel) {
            final services = ctx.read<Services>();
            return TaskActions.invoiceTasks(
              ctx,
              services,
              services.auth.session.value!.currentCompanyId,
              sel.cast<Task>(),
            );
          },
        ),
        EntityListBulkAction(
          actionId: 'add_to_invoice',
          icon: Icons.playlist_add,
          // `action_add_to_invoice` throughout: `add_to_invoice` is
          // "Add to invoice :invoice" and the bulk bar fires before an
          // invoice is picked (invoiceninja/flutter#35). `actionId` stays —
          // it's the wire id matched against the VM's `BulkAction.id`.
          tooltipKey: 'action_add_to_invoice',
          // Unused: `onSelection` handlers do their own toasting.
          singleSuccessKey: 'action_add_to_invoice',
          pluralSuccessKey: 'action_add_to_invoice',
          nothingKey: 'nothing_to_invoice',
          onSelection: (ctx, sel) {
            final services = ctx.read<Services>();
            return TaskActions.addTasksToInvoice(
              ctx,
              services,
              services.auth.session.value!.currentCompanyId,
              sel.cast<Task>(),
            );
          },
        ),
      ],
    );
  }
}

/// Resolves the layout for [TaskListScreen] and mirrors an explicit URL choice
/// back into the remembered preference. Stateful for the mirror alone.
///
/// **The mirror is one of two writers.** `TasksViewToggle._go` writes the user's
/// own choice (and navigates to a bare `/tasks`, so a switch is not a history
/// step); this mirror covers every URL-driven path instead — the calendar
/// day-cell's `?view=daily&date=…` deep link, the post-OAuth
/// `/tasks?view=calendar` landing, a restored `nav_state` route, back/forward —
/// so the preference can never drift from a URL that does name a layout. It
/// writes post-frame so `ValueNotifier.notifyListeners` can never fire inside
/// the parent's build phase.
class _RememberedTasksView extends StatefulWidget {
  const _RememberedTasksView({
    required this.urlView,
    required this.locked,
    required this.builder,
  });

  final TasksViewMode? urlView;
  final bool locked;
  final Widget Function(BuildContext context, TasksViewMode mode) builder;

  @override
  State<_RememberedTasksView> createState() => _RememberedTasksViewState();
}

class _RememberedTasksViewState extends State<_RememberedTasksView> {
  @override
  void initState() {
    super.initState();
    _mirror();
  }

  @override
  void didUpdateWidget(covariant _RememberedTasksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.urlView != oldWidget.urlView ||
        widget.locked != oldWidget.locked) {
      _mirror();
    }
  }

  void _mirror() {
    final mode = widget.urlView;
    if (widget.locked || mode == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<Services>().tasksView.set(mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Load-bearing, not decoration: the toggle sets the preference and then
    // navigates to a bare `/tasks`, which is the URL a preference-driven board
    // is *already* on — and `GoRouterDelegate.setNewRoutePath` short-circuits an
    // unchanged `RouteMatchList`, so nothing rebuilds from the router. This
    // subscription is the whole repaint path for a view switch.
    //
    // It is built UNCONDITIONALLY, including when `locked` — the stable element
    // position is the point, not the value. `locked` carries `hasPane`, which
    // flips on every pane open and close, so returning the child bare in that
    // branch alternates the widget at this slot between `ValueListenableBuilder`
    // and `EntityListScreenScaffold`; `Widget.canUpdate` fails on the
    // runtimeType change and the list is unmounted and re-inflated. On a wide
    // window that is a real regression, because `MasterDetailLayout` keeps the
    // list element alive there on purpose (`Positioned.fill(Offstage(…))` is
    // Stack child 0 in both pane states) — the list would reset its scroll,
    // rebuild its ViewModel back to page 1 and drop multi-select every time a
    // row is clicked, and the freshly-seeded `MasterDetailNavController` could
    // no longer resolve the row the pane just opened.
    //
    // Note `EntityListScreenScaffold._statusTabs` is NOT a precedent for
    // branching here: that guard wraps an optional *sibling* in a `Column`, so
    // its early return destabilises nothing below it.
    return ValueListenableBuilder<TasksViewMode?>(
      valueListenable: context.read<Services>().tasksView,
      builder: (context, remembered, _) => widget.builder(
        context,
        resolveTasksViewMode(
          urlView: widget.urlView,
          remembered: remembered,
          locked: widget.locked,
        ),
      ),
    );
  }
}
