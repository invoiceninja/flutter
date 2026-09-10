/// Which body the Tasks screen renders — and how that choice is resolved.
///
/// Deliberately a leaf (**imports nothing**) so `lib/app/tasks_view_controller
/// .dart` can persist the mode without importing a UI screen; `task_list_screen
/// .dart` re-exports [TasksViewMode] so existing `show TasksViewMode` imports
/// are unaffected. Same shape as `lib/domain/sidebar_menu.dart` — enum plus a
/// pure parser — and the same reason as `lib/domain/columns/ids/`.
library;

/// The five Tasks layouts. List + Kanban use `EntityListScreenScaffold` / the
/// kanban board; daily / weekly / calendar are time-oriented views over the
/// same task set (see their respective screens).
enum TasksViewMode { list, daily, weekly, calendar, kanban }

/// Parses the `?view=` query param into a layout mode, or **null** when the URL
/// expressed no opinion.
///
/// Null — not [TasksViewMode.list] — is the whole point: the caller then falls
/// back to the remembered preference (see [resolveTasksViewMode]), which is what
/// fixes invoiceninja/flutter#133.
///
/// `'full'` must land in the null arm, and that is not defensive coding: the
/// `view` key is **overloaded**. `MasterDetailLayout` writes `?view=full` for
/// its full-width pane flag (`_toggleFullScreenInUrl`, and the auto-promote
/// redirect that fires one frame after an editor opens), and the tasks list is
/// rebuilt from that same `GoRouterState` — so every open editor hands this
/// function `'full'`. Mapping it onto a layout would make the pane flag read as
/// a layout mode; mapping it onto `list` would say the URL had chosen the list.
TasksViewMode? tasksViewModeFromQuery(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final mode in TasksViewMode.values) {
    if (mode.name == raw) return mode;
  }
  return null;
}

/// The layout to render: the URL wins, then the remembered preference, then
/// [TasksViewMode.list].
///
/// [locked] means "this screen can only be the plain list", and ignores both
/// [urlView] and [remembered]. Three cases, each of which silently breaks
/// something otherwise:
///
///  * **A master-detail pane is open** (`/tasks/:id`, `/tasks/:id/edit`,
///    `/tasks/new`). Only `EntityListScreenScaffold` writes
///    `MasterDetailNavController.update`, and the pane reads it for J/K
///    row-stepping and for `EntityDetailScaffold`'s synchronous first-frame
///    seed — with the board as the list both go dead and the pane opens on a
///    spinner. `TaskCalendarScreen.initState` also does network I/O
///    (`loadStatus` + the events fetch), so a remembered calendar would fire a
///    calendar-connection request on every record opened. Locking here keeps
///    everything behind the pane identical to what shipped; the mode only has
///    to survive the trip *out*.
///  * **A `ListFilterIntent` was handed in** — a dashboard task card navigates
///    with one as route `extra`, and only `GenericListViewModel` consumes it,
///    so a board would swallow the drill-down.
///  * **Embedded, or scoped to a client / project** — the kanban and calendar
///    bodies take no such argument and would drop the filter.
TasksViewMode resolveTasksViewMode({
  TasksViewMode? urlView,
  TasksViewMode? remembered,
  required bool locked,
}) {
  if (locked) return TasksViewMode.list;
  return urlView ?? remembered ?? TasksViewMode.list;
}
