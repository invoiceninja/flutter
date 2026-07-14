import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/router.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/dao/task_dao.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/value/date.dart';
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

/// Which body the tasks screen renders. Read from `?view=` on the URL so
/// deep links and back/forward navigation surface in the right view from
/// the first frame. List + Kanban use `EntityListScreenScaffold` / the kanban
/// board; daily / weekly / calendar are time-oriented views over the same
/// task set (see their respective screens).
enum TasksViewMode { list, daily, weekly, calendar, kanban }

/// Tasks list screen. When `view == TasksViewMode.kanban` the body
/// delegates to [KanbanScreen]; otherwise it's the standard
/// `EntityListScreenScaffold`. Both share the same AppBar toggle so the
/// user always sees how to switch back.
class TaskListScreen extends StatelessWidget {
  const TaskListScreen({
    super.key,
    this.view = TasksViewMode.list,
    this.focusDate,
    this.clientId,
    this.projectId,
    this.embedded = false,
  });

  final TasksViewMode view;

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

  @override
  Widget build(BuildContext context) {
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
      bulkActions: const [
        EntityListBulkAction(
          actionId: 'start',
          icon: Icons.play_arrow_outlined,
          tooltipKey: 'start',
          singleSuccessKey: 'started_task',
          pluralSuccessKey: 'started_tasks',
          nothingKey: 'nothing_to_start',
        ),
        EntityListBulkAction(
          actionId: 'stop',
          icon: Icons.stop_circle_outlined,
          tooltipKey: 'stop',
          singleSuccessKey: 'stopped_task',
          pluralSuccessKey: 'stopped_tasks',
          nothingKey: 'nothing_to_stop',
        ),
        EntityListBulkAction(
          actionId: 'archive',
          icon: Icons.archive_outlined,
          tooltipKey: 'archive',
          singleSuccessKey: 'archived_task',
          pluralSuccessKey: 'archived_tasks',
          nothingKey: 'nothing_to_archive',
        ),
        EntityListBulkAction(
          actionId: 'restore',
          icon: Icons.unarchive_outlined,
          tooltipKey: 'restore',
          singleSuccessKey: 'restored_task',
          pluralSuccessKey: 'restored_tasks',
          nothingKey: 'nothing_to_restore',
        ),
        EntityListBulkAction(
          actionId: 'delete',
          icon: Icons.delete_outline,
          tooltipKey: 'delete',
          singleSuccessKey: 'deleted_task',
          pluralSuccessKey: 'deleted_tasks',
          nothingKey: 'nothing_to_delete',
        ),
      ],
    );
  }
}
