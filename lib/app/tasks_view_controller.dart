import 'package:flutter/foundation.dart';

import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/domain/tasks/tasks_view_mode.dart';

/// Owns the Tasks layout the user last picked from the AppBar toggle
/// (`DevicePrefKeys.tasksView`, device-local).
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
/// an unparsable stored value (written by a newer build, then downgraded) all
/// behave identically.
///
/// An account preference: a sign-out forgets it, so a second user signing in
/// without relaunching never opens Tasks on the first user's board. An
/// involuntary 401 or an idle re-lock keeps local data, and the board with it.
class TasksViewController extends ValueNotifier<TasksViewMode?> {
  TasksViewController({required DevicePrefsStore prefs})
    : _prefs = prefs,
      super(_read(prefs)) {
    prefs.addListener(_sync);
  }

  final DevicePrefsStore _prefs;

  static TasksViewMode? _read(DevicePrefsStore prefs) =>
      tasksViewModeFromQuery(prefs.read(DevicePrefKeys.tasksView));

  void _sync() => value = _read(_prefs);

  Future<void> set(TasksViewMode mode) async {
    if (value == mode) return;
    value = mode;
    await _prefs.write(DevicePrefKeys.tasksView, mode.name);
  }

  @override
  void dispose() {
    _prefs.removeListener(_sync);
    super.dispose();
  }
}
