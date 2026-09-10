import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/task.dart';

/// Client-side Project / Client / Assignee filtering shared by every task
/// view (kanban, calendar, daily, weekly). Empty string = "no filter".
///
/// Mixed onto a [ChangeNotifier]; the setters notify so a bound
/// `TaskFilterBar` and the view rebuild together. Extracted verbatim from the
/// original inline `KanbanViewModel` filter block so behavior is preserved.
mixin TaskFiltersMixin on ChangeNotifier {
  String _projectId = '';
  String _clientId = '';
  String _assignedUserId = '';

  String get projectId => _projectId;
  String get clientId => _clientId;
  String get assignedUserId => _assignedUserId;

  bool get filtersActive =>
      _projectId.isNotEmpty ||
      _clientId.isNotEmpty ||
      _assignedUserId.isNotEmpty;

  /// How many of the three dimensions are narrowing the view. Drives
  /// `FilterIconButton`'s dot and its state-bearing tooltip; nothing renders
  /// the number itself.
  int get activeFilterCount =>
      (_projectId.isEmpty ? 0 : 1) +
      (_clientId.isEmpty ? 0 : 1) +
      (_assignedUserId.isEmpty ? 0 : 1);

  void setProjectFilter(String id) {
    if (_projectId == id) return;
    _projectId = id;
    _notifyFilters();
  }

  void setClientFilter(String id) {
    if (_clientId == id) return;
    _clientId = id;
    _notifyFilters();
  }

  void setAssigneeFilter(String id) {
    if (_assignedUserId == id) return;
    _assignedUserId = id;
    _notifyFilters();
  }

  void clearFilters() {
    if (!filtersActive) return;
    _projectId = '';
    _clientId = '';
    _assignedUserId = '';
    _notifyFilters();
  }

  /// True when [t] passes all currently-active filters (AND across the trio).
  bool matchesFilters(Task t) =>
      (_projectId.isEmpty || t.projectId == _projectId) &&
      (_clientId.isEmpty || t.clientId == _clientId) &&
      (_assignedUserId.isEmpty || t.assignedUserId == _assignedUserId);

  bool _filtersDisposed = false;

  @override
  void dispose() {
    _filtersDisposed = true;
    super.dispose();
  }

  /// The same `if (!_disposed)` guard all four host view models already apply
  /// to their own async notifies (`KanbanViewModel`, `TaskDailyViewModel`, …);
  /// these setters were the one unguarded path into [notifyListeners].
  ///
  /// It is reachable, not defensive. `openTaskFilters` pushes a bottom sheet on
  /// the shell **branch** navigator and its dialog on the **root** one (the two
  /// `show*` defaults differ), so either can outlive the screen underneath it —
  /// and `RunningTimerPill` paints *above* the navigation shell (see
  /// `scaffold_with_nav.dart`, pinned 112 px up), over that surface, with a tap
  /// that navigates to a task's edit route. That sets `hasPane`, which locks
  /// `TaskListScreen` to the plain list, which unmounts the four custom views
  /// and disposes their view models — leaving an open filter surface bound to
  /// this notifier. Without the guard the next pick asserts in debug and
  /// silently no-ops in release.
  ///
  /// What the guard buys is a *safe* failure, not a good one: the surface stays
  /// up and goes inert, because the setters still write to a view model nothing
  /// will read again and the `ListenableBuilder` never rebuilds. Dismissing it
  /// instead would mean the host popping the route it did not open, or hoisting
  /// this state out of the per-view model — a decided non-goal for #136. Rare
  /// by construction (it needs an open sheet, a running timer, and a tap on the
  /// pill behind it), and one back gesture away from correct.
  void _notifyFilters() {
    if (!_filtersDisposed) notifyListeners();
  }
}
