import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/domain/tasks/task_day.dart';
import 'package:admin/ui/features/tasks/view_models/task_filters_mixin.dart';
import 'package:admin/ui/features/tasks/widgets/weekly/weekly_merge.dart';
import 'package:admin/utils/date_ranges.dart';

/// Drives the weekly timesheet. Cell edits are buffered per task and flushed on
/// a debounce into a SINGLE `repo.save` (one outbox row), collapsing rapid
/// typing. The focused week is internal state, so scrubbing keeps this VM —
/// and its in-flight debounce — alive.
///
/// `_optimisticLog` holds the just-merged log for a task between the local save
/// and the Drift re-emission so the grid doesn't flicker; it's dropped once the
/// task is idle again (no pending edit, no in-flight flush) and Drift is truth.
class TaskWeeklyViewModel extends ChangeNotifier with TaskFiltersMixin {
  TaskWeeklyViewModel({
    required this.repo,
    required this.companyId,
    int firstDayOfWeek = 0,
    Date? focus,
    DateTime Function() now = DateTime.now,
    Duration flushDelay = const Duration(milliseconds: 1800),
  }) : _firstDayOfWeek = firstDayOfWeek,
       _now = now,
       _flushDelay = flushDelay,
       _focus = focus ?? Date.today() {
    _sub = repo.watchAllActive(companyId: companyId).listen(_onTasks);
  }

  final TaskRepository repo;
  final String companyId;
  final DateTime Function() _now;

  /// Debounce window before a task's buffered cell edits flush to one
  /// `repo.save`. Injectable so tests can drive it without real time.
  final Duration _flushDelay;

  int _firstDayOfWeek;
  Date _focus;
  StreamSubscription<List<Task>>? _sub;

  // Stable per-task state (never rebuilt in build()).
  final Map<String, Timer> _flushTimers = {};
  final Set<String> _flushing = {};
  final Map<String, Map<String, CellEdit>> _pending = {};
  final Map<String, List<TimeEntry>> _optimisticLog = {};

  Map<String, Task> _tasksById = const {};
  bool _disposed = false;

  String? _lastError;
  int _errorNonce = 0;
  String? get lastError => _lastError;

  /// Bumped on each error so the screen's listener fires the SnackBar once.
  int get errorNonce => _errorNonce;

  // ─── week geometry ───
  Date get weekStart => startOfWeek(_focus, _firstDayOfWeek);
  Date get weekEnd => weekStart.addDays(6);
  List<Date> get weekDays => [for (var i = 0; i < 7; i++) weekStart.addDays(i)];

  /// Current start-of-week, so the host can skip a redundant (and notifying)
  /// [setFirstDayOfWeek] — mirrors `TaskCalendarViewModel`.
  int get firstDayOfWeek => _firstDayOfWeek;

  void setFirstDayOfWeek(int value) {
    if (_firstDayOfWeek == value) return;
    _firstDayOfWeek = value;
    if (!_disposed) notifyListeners();
  }

  void prevWeek() => _setFocus(_focus.addDays(-7));
  void nextWeek() => _setFocus(_focus.addDays(7));
  void goToToday() => _setFocus(Date.today());

  void _setFocus(Date next) {
    if (next == _focus) return;
    _focus = next;
    if (!_disposed) notifyListeners();
  }

  // ─── reads ───
  List<TimeEntry> _logsFor(String taskId) =>
      _optimisticLog[taskId] ?? _tasksById[taskId]?.timeLog ?? const [];

  Iterable<Task> get _filtered => filtersActive
      ? _tasksById.values.where(matchesFilters)
      : _tasksById.values;

  /// Logged seconds for a cell (task × day). A pending duration edit wins;
  /// otherwise sum entries whose start's local date is [day] (running to now).
  int secondsFor(String taskId, Date day) {
    final pending = _pending[taskId]?[day.toIso()]?.duration;
    if (pending != null) {
      final s = durationStringToSeconds(pending);
      if (s != null) return s;
      // Unparseable mid-keystroke: keep showing the persisted value (the flush
      // will reject the input) rather than flashing 0.
    }
    final n = _now();
    var total = 0;
    for (final e in _logsFor(taskId)) {
      if (timeEntryLocalDate(e) == day) {
        total += e.durationUpTo(n).inSeconds;
      }
    }
    return total;
  }

  /// Tasks with real or pending activity in the visible week, ordered by
  /// earliest start then id (stable as the user types).
  List<Task> get rows {
    final keys = {for (final d in weekDays) d.toIso()};
    final list = <Task>[];
    for (final t in _filtered) {
      final hasReal = _logsFor(t.id).any((e) {
        final d = timeEntryLocalDate(e);
        return d != null && keys.contains(d.toIso());
      });
      final hasPending = (_pending[t.id] ?? const {}).keys.any(keys.contains);
      if (hasReal || hasPending) list.add(t);
    }
    list.sort((a, b) {
      final sa = a.earliestStart;
      final sb = b.earliestStart;
      if (sa != null && sb != null) {
        final c = sa.compareTo(sb);
        if (c != 0) return c;
      } else if (sa == null && sb != null) {
        return 1;
      } else if (sa != null && sb == null) {
        return -1;
      }
      return a.id.compareTo(b.id);
    });
    return list;
  }

  int weekTotalFor(String taskId) =>
      weekDays.fold(0, (sum, d) => sum + secondsFor(taskId, d));

  bool isReadOnly(String taskId) {
    final t = _tasksById[taskId];
    return t == null || t.isRunning || t.isInvoiced;
  }

  bool hasPending(String taskId, Date day) =>
      _pending[taskId]?[day.toIso()] != null;

  /// Effective description for a cell (pending wins, else first same-day
  /// entry).
  String cellDescription(String taskId, Date day) {
    final p = _pending[taskId]?[day.toIso()]?.description;
    if (p != null) return p;
    return _firstEntryOnDay(taskId, day)?.description ?? '';
  }

  /// Effective billable flag for a cell (pending wins, else first same-day
  /// entry, defaulting true).
  bool cellBillable(String taskId, Date day) {
    final p = _pending[taskId]?[day.toIso()]?.billable;
    if (p != null) return p;
    return _firstEntryOnDay(taskId, day)?.billable ?? true;
  }

  TimeEntry? _firstEntryOnDay(String taskId, Date day) {
    for (final e in _logsFor(taskId)) {
      if (timeEntryLocalDate(e) == day) return e;
    }
    return null;
  }

  // ─── editing (debounced, batched per task) ───
  void editCell(
    String taskId,
    Date day, {
    String? duration,
    String? description,
    bool? billable,
  }) {
    if (isReadOnly(taskId)) return;
    final forTask = _pending.putIfAbsent(taskId, () => {});
    final cell = forTask.putIfAbsent(day.toIso(), CellEdit.new);
    cell.merge(
      CellEdit(
        duration: duration,
        description: description,
        billable: billable,
      ),
    );
    _scheduleFlush(taskId);
    if (!_disposed) notifyListeners();
  }

  void _scheduleFlush(String taskId) {
    if (_disposed) return; // never arm a timer on a torn-down VM
    _flushTimers[taskId]?.cancel();
    _flushTimers[taskId] = Timer(_flushDelay, () => _flushTask(taskId));
  }

  Future<void> _flushTask(String taskId) async {
    // Already saving this task — re-arm and let the in-flight save finish so
    // we never issue two overlapping writes for one task.
    if (_flushing.contains(taskId)) {
      _scheduleFlush(taskId);
      return;
    }
    final pendingForTask = _pending[taskId];
    if (pendingForTask == null || pendingForTask.isEmpty) return;
    final task = _tasksById[taskId];
    if (task == null) return;
    if (task.isRunning || task.isInvoiced) {
      _emitError('stop_task_to_add_task_entry');
      _pending.remove(taskId);
      if (!_disposed) notifyListeners();
      return;
    }

    final snapshot = {
      for (final e in pendingForTask.entries) e.key: e.value.copy(),
    };

    var logs = _logsFor(taskId);
    var anyApplied = false;
    var anyFailed = false;
    for (final entry in snapshot.entries) {
      final day = Date.tryParse(entry.key);
      if (day == null) continue;
      final next = applyCellEditToLogs(logs, day, entry.value, _now());
      if (next == null) {
        // One cell's duration is invalid — discard just that cell so it can't
        // take valid sibling edits (other days) down with it.
        anyFailed = true;
        continue;
      }
      logs = next;
      anyApplied = true;
    }
    if (anyFailed) _emitError('please_enter_a_valid_duration');
    // Drop the whole snapshot: applied cells are now in `logs`, and the failed
    // cell reverts to its last-good value on the next emission (no re-arm loop).
    _dropSnapshot(taskId, snapshot);
    if (!anyApplied) {
      if (!_disposed) notifyListeners();
      return;
    }

    _optimisticLog[taskId] = logs;
    _flushing.add(taskId);
    if (!_disposed) notifyListeners();

    try {
      await repo.save(
        companyId: companyId,
        task: task.copyWith(timeLog: logs),
      );
    } catch (_) {
      _optimisticLog.remove(taskId);
      _emitError('an_error_occurred');
    } finally {
      _flushing.remove(taskId);
      if (!_disposed) {
        if ((_pending[taskId] ?? const {}).isNotEmpty) _scheduleFlush(taskId);
        notifyListeners();
      }
    }
  }

  /// Drop only the cells we snapshotted *if unchanged since* — keystrokes that
  /// arrived during the flush survive and re-arm.
  void _dropSnapshot(String taskId, Map<String, CellEdit> snap) {
    final forTask = _pending[taskId];
    if (forTask == null) return;
    for (final entry in snap.entries) {
      final cur = forTask[entry.key];
      if (cur != null && cur.sameValueAs(entry.value)) {
        forTask.remove(entry.key);
      }
    }
    if (forTask.isEmpty) _pending.remove(taskId);
  }

  void _emitError(String key) {
    _lastError = key;
    _errorNonce++;
  }

  void _onTasks(List<Task> tasks) {
    _tasksById = {for (final t in tasks) t.id: t};
    // Once a task is idle (no pending edit, no in-flight flush) Drift is the
    // truth — drop its optimistic override. After our own save the re-emission
    // carries the same log, so there's no flicker; a concurrent remote edit
    // (differs, no pending) correctly wins.
    for (final id in _optimisticLog.keys.toList()) {
      if (_flushing.contains(id)) continue;
      if ((_pending[id] ?? const {}).isNotEmpty) continue;
      _optimisticLog.remove(id);
    }
    _pending.removeWhere((id, _) => !_tasksById.containsKey(id));
    _optimisticLog.removeWhere((id, _) => !_tasksById.containsKey(id));
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _flushTimers.values) {
      timer.cancel();
    }
    _flushTimers.clear();
    // Best-effort durable flush of any pending edits before teardown — the
    // save only enqueues to Drift + the outbox (no network), so it's safe and
    // never silently drops user data. Not awaited (dispose is sync); the
    // `_disposed` guards skip post-teardown notifies.
    for (final id in _pending.keys.toList()) {
      if (!_flushing.contains(id)) unawaited(_flushTask(id));
    }
    _sub?.cancel();
    super.dispose();
  }
}
