import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/domain/tasks/task_day.dart';
import 'package:admin/ui/features/tasks/view_models/task_filters_mixin.dart';

/// Drives the daily timeline. Flattens every time entry whose start falls on
/// the focused day across all tasks, sorted by start. The focused day is
/// internal state (`prev/next/goToToday`). `watchAllActive` re-emits whenever a
/// timer starts/stops (the task row's `time_log` changes), so the Start/Stop
/// buttons stay current without a separate running subscription.
class TaskDailyViewModel extends ChangeNotifier with TaskFiltersMixin {
  TaskDailyViewModel({
    required this.repo,
    required this.companyId,
    Date? focusDay,
    DateTime Function() now = DateTime.now,
  }) : _day = focusDay ?? Date.today(),
       _now = now {
    _sub = repo.watchAllActive(companyId: companyId).listen(_onTasks);
  }

  final TaskRepository repo;
  final String companyId;
  final DateTime Function() _now;

  Date _day;
  StreamSubscription<List<Task>>? _sub;
  List<Task> _tasks = const [];
  bool _disposed = false;
  bool _isDuplicating = false;
  Date? _duplicatingDay;
  final Set<Date> _duplicatedDays = {};

  Date get day => _day;
  bool get isToday => _day == Date.today();

  /// Whether "duplicate yesterday" is allowed for the focused day: it's today,
  /// no duplicate run is in flight, and this day hasn't already been duplicated
  /// this session. Gates the header button so a double-tap (or a re-tap after
  /// the success toast) can't create a second full set of tasks (M2).
  bool get isDuplicating => _isDuplicating;
  bool get canDuplicateYesterday =>
      isToday && !_isDuplicating && !_duplicatedDays.contains(_day);

  /// Begin a duplicate-yesterday run; returns false (caller must abort) if one
  /// is already running or the focused day was already duplicated.
  bool beginDuplicate() {
    if (_isDuplicating || _duplicatedDays.contains(_day)) return false;
    _isDuplicating = true;
    _duplicatingDay = _day;
    if (!_disposed) notifyListeners();
    return true;
  }

  /// End a duplicate-yesterday run; records the day as duplicated when [created]
  /// so a later re-tap is a no-op even after the spinner/toast clears.
  void endDuplicate({required bool created}) {
    _isDuplicating = false;
    final day = _duplicatingDay;
    if (created && day != null) _duplicatedDays.add(day);
    _duplicatingDay = null;
    if (!_disposed) notifyListeners();
  }

  Iterable<Task> get _filtered =>
      filtersActive ? _tasks.where(matchesFilters) : _tasks;

  /// Time entries on the focused day, each paired with its task, sorted by
  /// start ascending.
  List<({Task task, TimeEntry entry})> get rows =>
      entriesOnDay(_filtered, _day);

  /// True when the day *does* hold entries and only an active filter is hiding
  /// them — the one case where offering "Clear filters" is honest.
  ///
  /// [filtersActive] alone is not that case: a day with nothing logged is
  /// equally empty with a filter applied, and that user is told to clear a
  /// filter that reveals nothing *and* loses the `Log time` action they
  /// actually want. The unfiltered pass runs only after [rows] has already come
  /// back empty, so the common path costs nothing.
  bool get hasFilteredOutRows =>
      filtersActive && rows.isEmpty && entriesOnDay(_tasks, _day).isNotEmpty;

  /// Total wall-clock time logged on the focused day (running entries counted
  /// up to now).
  Duration get total {
    final n = _now();
    var d = Duration.zero;
    for (final r in rows) {
      d += r.entry.durationUpTo(n);
    }
    return d;
  }

  /// Billable portion of [total].
  Duration get billable {
    final n = _now();
    var d = Duration.zero;
    for (final r in rows) {
      if (r.entry.billable) d += r.entry.durationUpTo(n);
    }
    return d;
  }

  /// All tasks whose day is [date] for the active filter set — backs
  /// "duplicate yesterday".
  List<Task> tasksOnDay(Date date) => [
    for (final t in _filtered)
      if (t.day == date) t,
  ];

  void prevDay() => _setDay(_day.addDays(-1));
  void nextDay() => _setDay(_day.addDays(1));
  void goToToday() => _setDay(Date.today());

  void _setDay(Date next) {
    if (next == _day) return;
    _day = next;
    if (!_disposed) notifyListeners();
  }

  void _onTasks(List<Task> tasks) {
    _tasks = tasks;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}
