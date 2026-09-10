import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/tasks/tasks_view_mode.dart';

final _log = Logger('TasksViewController');

/// Owns the Tasks layout the user last picked from the AppBar toggle and
/// persists it to `nav_state.tasks_view` — the same single-row, device-local
/// pattern as [StatusTabsController] / [SidebarMenuController].
///
/// The layout used to live **only** in the URL (`/tasks?view=kanban`), and every
/// structural "up" navigation drops the query string by construction — so
/// tapping "New task" from the kanban board and cancelling landed the user on
/// the plain list, along with closing a task's detail pane, re-tapping the
/// already-active Tasks sidebar row, and switching company from a task record
/// (invoiceninja/flutter#133). The URL is still the *override*; this is the
/// fallback a bare `/tasks` resolves through. The legacy admin-portal persists
/// the same choice (`prefState.showKanban`).
///
/// Null means **never chosen** rather than "list", so [resolveTasksViewMode]
/// owns that default in one place and a fresh install, a cleared preference and
/// an unparsable stored value all behave identically.
class TasksViewController extends ValueNotifier<TasksViewMode?> {
  TasksViewController({
    required AppDatabase db,
    DateTime Function()? now,
    TasksViewMode? initial,
  }) : _db = db,
       _now = now ?? DateTime.now,
       super(initial);

  final AppDatabase _db;
  final DateTime Function() _now;

  /// No stored row (fresh install) or an unrecognised name (written by a newer
  /// build, then downgraded) both leave the value null — never a throw, because
  /// this runs inside `main`'s boot `Future.wait`.
  Future<void> restore() async {
    final row = await _db.navStateDao.current();
    final stored = tasksViewModeFromQuery(row?.tasksView);
    if (stored == null) return;
    value = stored;
  }

  /// Drop the choice without touching the database — joins the
  /// `onBeforeLogout` fan-out beside [SidebarMenuController.resetInMemory], for
  /// the same reason. A deliberate sign-out wipes `nav_state`, but this
  /// controller is built once in `Services.build` and outlives the logout, and
  /// [restore] early-returns on a null stored value so it can never clear
  /// itself — so a second user signing in without relaunching would open Tasks
  /// on the first user's board, and the state would differ depending on whether
  /// the app had been restarted. An involuntary 401 preserves local data, so it
  /// keeps the preference.
  void resetInMemory() {
    if (value == null) return;
    value = null;
  }

  Future<void> set(TasksViewMode mode) async {
    if (value == mode) return;
    value = mode;
    try {
      await _db.navStateDao.saveTasksView(
        name: mode.name,
        now: _now().millisecondsSinceEpoch,
      );
    } catch (e, st) {
      // A failed write doesn't roll back the in-memory value — the user still
      // sees the view they picked until next launch.
      _log.warning('Failed to persist tasks view', e, st);
    }
  }
}
