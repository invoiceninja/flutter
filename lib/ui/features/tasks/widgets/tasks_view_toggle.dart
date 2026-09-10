import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/list/entity_list_constants.dart';
import 'package:admin/ui/core/widgets/filter_icon_button.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:admin/ui/features/tasks/view_models/task_filters_mixin.dart';
import 'package:admin/ui/features/tasks/views/task_list_screen.dart'
    show TasksViewMode;

/// Shared AppBar for the custom task views (kanban / calendar / daily /
/// weekly), which don't use `EntityListScreenScaffold`. Renders the `tasks`
/// title + the [TasksViewToggle] with [active] highlighted, plus the filter
/// action when the pickers are collapsed.
///
/// [wide] arrives from the host screen's `LayoutBuilder` — the **content
/// pane**, the same way `EntityListScreenScaffold` feeds
/// `EntityListAppBar(wide:)`. It used to be read here off `MediaQuery`, i.e.
/// the *window*, which differs by the 232 px rail: in a 600-832 px window the
/// Tasks **list** drew its compact bar while these four drew the 69 px
/// `InSizes.headerBand`, so flipping views moved the toggle — the exact thing
/// the old version of this comment claimed to prevent. One bool per screen now
/// answers the flavour, whether the pickers render inline, and therefore
/// whether this bar carries the filter action.
///
/// [leading] stays a **window** read (`isGlobalNavVisible`): a hamburger must
/// not duplicate a rail that is already on screen. Same split
/// `EntityListAppBar` makes.
///
/// Pass [filters] + [onEditFilters] exactly when the pickers are collapsed
/// (`filters: inline ? null : _vm`); both null means the body is showing them
/// inline and a second entry point would be redundant chrome.
PreferredSizeWidget buildTasksViewAppBar(
  BuildContext context,
  TasksViewMode active, {
  required bool wide,
  TaskFiltersMixin? filters,
  VoidCallback? onEditFilters,
}) {
  final filterAction = filters == null || onEditFilters == null
      ? null
      : _FilterAction(
          filters: filters,
          onPressed: onEditFilters,
          // Wide is the height-constrained branch — see [_FilterAction.dense].
          dense: wide,
        );
  if (wide) {
    return AppBar(
      // The shared band, like the list toolbar this mirrors — a second copy of
      // the number is how the two drift when one of them moves.
      toolbarHeight: InSizes.headerBand,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      // The filter action goes in this `Row`, never in `actions:`. `AppBar`
      // builds `Stack([flexibleSpace, Material(toolbar)])`, so the toolbar
      // paints *over* the flexible space and — hit-testing being reverse paint
      // order — an `actions:` entry here would sit on top of the toggle below
      // and swallow its taps. That is why this branch has no `title:` and no
      // `actions:` at all.
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
              if (filterAction != null) ...[
                filterAction,
                const SizedBox(width: InSpacing.sm),
              ],
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
    // (not the pane) because above `Breakpoints.wide` the persistent sidebar is
    // already on screen and a hamburger would open a duplicate of it.
    leading: Breakpoints.isGlobalNavVisible(context)
        ? null
        : const DrawerHamburger(),
    // Dead in both branches — an explicit `leading` wins when there is one, and
    // when there isn't, the Scaffold's drawer is null on the same condition and
    // a shell-branch root has nothing to pop. Stated rather than defaulted
    // because this branch is now reachable *with* the rail up (the flavour
    // follows the pane, the hamburger the window), which is exactly where an
    // implied leading would be wrong. Same shape as
    // `dashboard_mobile_app_bar.dart`.
    automaticallyImplyLeading: !Breakpoints.isGlobalNavVisible(context),
    // Material's default 16 dp either side of the title is 32 dp this bar can't
    // spare now that it carries two actions — `_ToolbarLayout` subtracts
    // `middleSpacing * 2.0` from the title's `maxWidth`, so zeroing it buys
    // both sides back: on a 320 dp phone the hamburger,
    // the filter icon and the view toggle leave the title 136 dp, and `tasks`
    // is "Zeiterfassung" in German (~130 dp at `titleLarge`), so it ellipsises
    // at a large text scale. Conditional for the reason
    // `dashboard_mobile_app_bar.dart` gives: `NavigationToolbar` starts the
    // title at `leadingWidth + middleSpacing`, so with no hamburger a zero
    // spacing renders it hard against the sidebar's right border.
    titleSpacing: Breakpoints.isGlobalNavVisible(context) ? null : 0,
    title: Text(context.tr('tasks')),
    actions: [
      if (filterAction != null) filterAction,
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: TasksViewToggle(active: active, wide: false),
      ),
    ],
  );
}

/// The AppBar's filter affordance: the shared [FilterIconButton], rebuilt on
/// every filter change so its dot and count stay live.
class _FilterAction extends StatelessWidget {
  const _FilterAction({
    required this.filters,
    required this.onPressed,
    required this.dense,
  });

  final TaskFiltersMixin filters;
  final VoidCallback onPressed;

  /// True inside the wide `flexibleSpace` `Row`, which gets
  /// `InSizes.headerBand` (69) minus 24 px of padding = **45 px** for its
  /// children — hence the ~40 px `SegmentedButton` beside it. A default 48 px
  /// `IconButton` there neither fits nor throws: the constraints clamp it and it
  /// renders short. That branch is reachable with the pickers collapsed on a
  /// **landscape phone** (658 px pane, so `wide` is true while `inline` is not),
  /// so it is not a corner case.
  final bool dense;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: filters,
    builder: (context, _) => FilterIconButton(
      activeCount: filters.activeFilterCount,
      size: dense ? actionButtonSize() : null,
      onPressed: onPressed,
    ),
  );
}

/// AppBar trailing widget that switches between the five task views — list,
/// daily, weekly, calendar (monthly), kanban. On wide screens renders an
/// icon-only `SegmentedButton` (five text labels won't fit) with tooltips; on
/// narrow falls back to a `PopupMenuButton` so the AppBar stays compact.
///
/// **The layout is a preference, not a place.** Tapping writes
/// `Services.tasksView` and navigates to a bare `/tasks`; `TaskListScreen`
/// resolves the body from that preference, so closing a task pane, re-tapping
/// the sidebar row, switching company and relaunching all come back on the same
/// view instead of the plain list (invoiceninja/flutter#133). Switching views
/// drops any `?date=` focus; each time-oriented view re-defaults to today (a
/// calendar day-cell tap deep-links into daily with an explicit
/// `?view=daily&date=…`, which `TaskListScreen` mirrors back into the
/// preference).
///
/// It deliberately emits **no** `?view=`, so a switch is not a history step:
/// `isUpNavigation` compares paths only, so `/tasks` and `/tasks?view=kanban`
/// would be separate entries, and pressing Android back onto the bare one would
/// re-render the board from the preference and look like nothing happened.
/// Every other list-view control in the app — filters, sort, status tabs —
/// already lives in `nav_state` and creates no history entry; this now matches.
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

  /// Writes the preference, then navigates to the bare list URL. When the URL
  /// is already `/tasks` that `go` is a no-op — `GoRouterDelegate
  /// .setNewRoutePath` returns early on an unchanged `RouteMatchList` — so the
  /// repaint comes from `TaskListScreen`'s `ValueListenableBuilder` on this same
  /// controller. That is deliberate; don't "fix" it by re-adding a `?view=`.
  ///
  /// The early return needs **both** halves. `active` is what the screen is
  /// rendering, and while a master-detail pane is open the screen is locked to
  /// the list — so it reads List even for a user whose preference is Kanban, and
  /// tapping List there must still be able to set it. Comparing the preference
  /// as well also keeps a re-tap of the current view from navigating away from a
  /// `?date=` focus it is already showing.
  void _go(BuildContext context, TasksViewMode next) {
    final tasksView = context.read<Services>().tasksView;
    if (next == active && tasksView.value == next) return;
    tasksView.set(next);
    context.go('/tasks');
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
