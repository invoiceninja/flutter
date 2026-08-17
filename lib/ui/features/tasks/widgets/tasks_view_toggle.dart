import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart'
    show TasksViewMode;

/// Shared AppBar for the custom task views (kanban / calendar / daily /
/// weekly), which don't use `EntityListScreenScaffold`. Renders the `tasks`
/// title + the [TasksViewToggle] with [active] highlighted. Wide mirrors the
/// list view's chrome (64 px toolbar, 24 px gutter) so the toggle's pixel
/// position is stable as the user flips views; narrow drops to a compact row.
PreferredSizeWidget buildTasksViewAppBar(
  BuildContext context,
  TasksViewMode active,
) {
  final wide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
  if (wide) {
    return AppBar(
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      flexibleSpace: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          child: Row(
            children: [
              Text(
                context.tr('tasks'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              TasksViewToggle(active: active, wide: true),
            ],
          ),
        ),
      ),
    );
  }
  return AppBar(
    // Without this the four custom task views are a navigation dead end on a
    // phone. They build bare `Scaffold`s rather than going through
    // `EntityListScreenScaffold` (which attaches the drawer itself), the
    // routes are shell branches so there is nothing to pop, and
    // `automaticallyImplyLeading` therefore renders no leading at all — so
    // switching Tasks to Kanban/Calendar/Daily/Weekly removed every route to
    // the rest of the app except toggling back to List. Gated on window width
    // (not local constraints) exactly as the list scaffold is: above
    // `Breakpoints.wide` the persistent sidebar is already on screen and a
    // hamburger would open a duplicate of it.
    leading: Breakpoints.isGlobalNavVisible(context)
        ? null
        : const DrawerHamburger(),
    title: Text(context.tr('tasks')),
    actions: [
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: TasksViewToggle(active: active, wide: false),
      ),
    ],
  );
}

/// AppBar trailing widget that switches between the five task views — list,
/// daily, weekly, calendar (monthly), kanban. On wide screens renders an
/// icon-only `SegmentedButton` (five text labels won't fit) with tooltips; on
/// narrow falls back to a `PopupMenuButton` so the AppBar stays compact.
///
/// Driven entirely via URL: tapping navigates to `/tasks?view=<mode>` (list →
/// bare `/tasks`). Each screen reads the query param and rebuilds — no shared
/// local state to keep in sync. Switching views drops any `?date=` focus; each
/// time-oriented view re-defaults to today (a calendar day-cell tap deep-links
/// into daily with an explicit `?date=`).
class TasksViewToggle extends StatelessWidget {
  const TasksViewToggle({super.key, required this.active, required this.wide});

  final TasksViewMode active;
  final bool wide;

  static IconData _icon(TasksViewMode m) => switch (m) {
    TasksViewMode.list => Icons.view_list_outlined,
    TasksViewMode.daily => Icons.view_day_outlined,
    TasksViewMode.weekly => Icons.view_week_outlined,
    TasksViewMode.calendar => Icons.calendar_month_outlined,
    TasksViewMode.kanban => Icons.view_kanban_outlined,
  };

  static String _labelKey(TasksViewMode m) => switch (m) {
    TasksViewMode.list => 'list',
    TasksViewMode.daily => 'freq_daily',
    TasksViewMode.weekly => 'freq_weekly',
    TasksViewMode.calendar => 'freq_monthly',
    TasksViewMode.kanban => 'kanban',
  };

  void _go(BuildContext context, TasksViewMode next) {
    if (next == active) return;
    context.go(
      next == TasksViewMode.list ? '/tasks' : '/tasks?view=${next.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return SegmentedButton<TasksViewMode>(
        segments: [
          for (final m in TasksViewMode.values)
            ButtonSegment(
              value: m,
              icon: Icon(_icon(m), size: 16),
              tooltip: context.tr(_labelKey(m)),
            ),
        ],
        selected: {active},
        showSelectedIcon: false,
        onSelectionChanged: (next) => _go(context, next.first),
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 10),
          ),
        ),
      );
    }
    return PopupMenuButton<TasksViewMode>(
      tooltip: context.tr('view'),
      icon: Icon(_icon(active)),
      initialValue: active,
      onSelected: (m) => _go(context, m),
      itemBuilder: (context) => [
        for (final m in TasksViewMode.values)
          PopupMenuItem<TasksViewMode>(
            value: m,
            child: Row(
              children: [
                Icon(_icon(m), size: 18),
                const SizedBox(width: 12),
                Text(context.tr(_labelKey(m))),
              ],
            ),
          ),
      ],
    );
  }
}
