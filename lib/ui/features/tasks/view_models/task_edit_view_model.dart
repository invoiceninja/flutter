import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/project.dart';
import 'package:admin/utils/formatting.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/tasks/task_schedule.dart';
import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/repositories/_repository_helpers.dart';
import 'package:admin/data/repositories/task_repository.dart';
import 'package:admin/ui/core/edit/generic_edit_view_model.dart';

/// Drives the Task edit + create screen. Optimistic — `save()` lands the
/// draft in Drift via the repo, returns the saved entity, and the outbox
/// handles the server round-trip.
///
/// Task-specific surface area beyond the standard edit VM:
///   * Time-log mutations: [addEntry] / [removeEntry] / [updateEntry]
///     / [startTimer] / [stopTimer] / [resumeTimer]. Each mutates the
///     draft's `timeLog: List<TimeEntry>` and notifies; saving is still
///     done by the parent edit-scaffold's Save button.
///   * [hasRunningEntry] / [hasStoppedEntries] drive the Start/Stop/
///     Resume label swap in `TaskEditTimesSection`.
class TaskEditViewModel extends GenericEditViewModel<Task> {
  TaskEditViewModel({
    required this.repo,
    required this.companyId,
    required this.now,
    Task? existing,
    Task? cloneFrom,
    super.sync,
    super.connectivity,
    super.useCommaAsDecimalPlace,
  }) : super(
         initialDraft: cloneFrom ?? existing ?? emptyTask(),
         original: existing,
         companyId: companyId,
       );

  final TaskRepository repo;
  final String companyId;
  final DateTime Function() now;

  @override
  bool draftIsNonEmpty() {
    final d = draft;
    return d.description.isNotEmpty ||
        d.rate != Decimal.zero ||
        d.clientId.isNotEmpty ||
        d.timeLog.isNotEmpty;
  }

  @override
  Future<SaveResult<Task>> performSave() async {
    if (savesAsCreate) {
      final result = await repo.create(
        companyId: companyId,
        draft: draft,
        existingTempId: recoveryTempId,
      );
      rememberCreateTempId(result.entity.id);
      return result;
    }
    return repo.save(companyId: companyId, task: draft);
  }

  void resetToEmpty() => reset(emptyDraft: emptyTask());

  // ── Plain field setters ────────────────────────────────────────────

  void setDescription(String v) => updateDraft(draft.copyWith(description: v));
  void setNumber(String v) => updateDraft(draft.copyWith(number: v));
  void setRate(String input) => setDec((d, v) => d.copyWith(rate: v), input);
  void setClientId(String v) {
    // Changing the client invalidates a previously-selected project that
    // belonged to a different client — clear projectId so the form doesn't
    // serialize a mismatched pair. Caller (Project picker) will re-select.
    if (draft.projectId.isNotEmpty && v != draft.clientId) {
      updateDraft(draft.copyWith(clientId: v, projectId: ''));
    } else {
      updateDraft(draft.copyWith(clientId: v));
    }
  }

  void setProjectId(String v) => updateDraft(draft.copyWith(projectId: v));
  void setStatusId(String v) => updateDraft(draft.copyWith(statusId: v));
  void setAssignedUserId(String v) =>
      updateDraft(draft.copyWith(assignedUserId: v));
  void setTagIds(List<String> ids) => updateDraft(draft.copyWith(tagIds: ids));

  /// The day the work is promised for. Date-only server-side, so it cannot
  /// carry a booked *time* — that stays a future `time_log` block.
  void setDueDate(DateTime? v) => updateDraft(
    draft.copyWith(dueDate: v == null ? null : Date(v.year, v.month, v.day)),
  );

  /// Allocated time, from the form's duration shorthand (`1h 30m`, `2`, …).
  /// Unparseable input is ignored so a half-typed value can't destroy the
  /// committed one — the field reconciles itself on blur, the contract
  /// `InDateField` and the create-from-line-item sheet already implement.
  void setEstimatedDuration(String input) {
    final parsed = parseDurationInput(input);
    if (input.trim().isEmpty) {
      updateDraft(draft.copyWith(estimatedSeconds: 0));
      return;
    }
    if (parsed == null || parsed.isNegative) return;
    updateDraft(draft.copyWith(estimatedSeconds: parsed.inSeconds));
  }

  /// Pick a project (or clear with null). Mirrors React's `TaskDetails`
  /// bidirectional pick: setting a project also sets the clientId from the
  /// project and auto-fills `rate` from `project.taskRate` **only when**
  /// the current rate is zero (never overwrite a value the user typed).
  /// The auto-fill check is intentional — do not "fix" it to always copy.
  void selectProject(Project? project) {
    if (project == null) {
      updateDraft(draft.copyWith(projectId: ''));
      return;
    }
    final shouldFillRate = draft.rate == Decimal.zero;
    updateDraft(
      draft.copyWith(
        projectId: project.id,
        clientId: project.clientId,
        rate: shouldFillRate && project.taskRate != Decimal.zero
            ? project.taskRate
            : draft.rate,
      ),
    );
  }

  void setCustomValue1(String v) =>
      updateDraft(draft.copyWith(customValue1: v));
  void setCustomValue2(String v) =>
      updateDraft(draft.copyWith(customValue2: v));
  void setCustomValue3(String v) =>
      updateDraft(draft.copyWith(customValue3: v));
  void setCustomValue4(String v) =>
      updateDraft(draft.copyWith(customValue4: v));

  // ── time_log mutations ────────────────────────────────────────────

  /// Whether the draft has an entry that's currently running (no stop).
  bool get hasRunningEntry =>
      draft.timeLog.isNotEmpty && draft.timeLog.last.isRunning;

  /// Whether the draft has any non-running entries.
  bool get hasStoppedEntries =>
      draft.timeLog.any((e) => !e.isRunning && e.start != null);

  /// Add a new entry. Defaults to seeding 30 minutes before now → now,
  /// matching the "I worked on this for the last half hour" case.
  void addEntry({
    DateTime? start,
    DateTime? stop,
    String description = '',
    bool billable = true,
  }) {
    final n = now();
    final running = hasRunningEntry ? draft.timeLog.last : null;
    var defaultedStop = stop ?? n;
    var defaultedStart =
        start ?? defaultedStop.subtract(const Duration(minutes: 30));
    // A *defaulted* seed must not overlap the running entry — the server's
    // checkTimeLog rejects overlapping rows, wedging the save. Snap the
    // default block to end where the timer began ("I worked on this right
    // before starting the timer"). Explicit caller-supplied times are
    // respected as-is.
    final runningStart = running?.start;
    if (stop == null &&
        runningStart != null &&
        defaultedStop.isAfter(runningStart)) {
      defaultedStop = runningStart;
      if (start == null) {
        defaultedStart = defaultedStop.subtract(const Duration(minutes: 30));
      }
    }
    final entry = _clamp(
      TimeEntry(
        start: defaultedStart,
        stop: defaultedStop,
        description: description,
        billable: billable,
      ),
    );
    // Keep a running entry LAST: every running-state check in the stack is
    // `.last`-based (hasRunningEntry, stopTimer, Task.isRunning, the repo's
    // startTimer/stopRunningTimer, the global timer pill), and the server
    // keeps the log sorted by start. Appending a stopped manual entry after
    // the running one buried it — the Stop button vanished, the timer became
    // unstoppable from every surface, and its duration accrued unbounded.
    final entries = <TimeEntry>[...draft.timeLog];
    if (running != null) {
      entries.insert(entries.length - 1, entry);
    } else {
      entries.add(entry);
    }
    updateDraft(draft.copyWith(timeLog: entries));
  }

  /// Clamp an inverted entry (stop before start) to zero length — matches
  /// React's auto-correct and keeps the server from rejecting the time_log
  /// on save (a negative interval 422s).
  TimeEntry _clamp(TimeEntry e) {
    final s = e.start;
    final p = e.stop;
    if (s != null && p != null && p.isBefore(s)) return e.copyWith(stop: s);
    return e;
  }

  void removeEntry(int index) {
    if (index < 0 || index >= draft.timeLog.length) return;
    final next = <TimeEntry>[...draft.timeLog]..removeAt(index);
    updateDraft(draft.copyWith(timeLog: next));
  }

  void updateEntry(int index, TimeEntry next) {
    if (index < 0 || index >= draft.timeLog.length) return;
    final entries = <TimeEntry>[...draft.timeLog]..[index] = _clamp(next);
    updateDraft(draft.copyWith(timeLog: entries));
  }

  /// Begin a fresh timer. Routed through [planTaskStart] like every other
  /// start path, so this form cannot build a log the server will reject —
  /// which matters more here than anywhere else, because the alternative is a
  /// draft the user can see, edit and then fail to save.
  ///
  /// Unlike the list and menu paths this one never prompts before claiming a
  /// booking: the whole time log is on screen, the claimed row visibly changes,
  /// and nothing is persisted until Save. [TaskStartOutcome.blocked] is a
  /// no-op — [timeLogProblem] is already reporting why.
  void startTimer({String description = '', bool billable = true}) {
    final plan = planTaskStart(
      draft.timeLog,
      now: now(),
      dueDate: draft.dueDate,
      estimatedSeconds: draft.estimatedSeconds,
    );
    if (plan.outcome == TaskStartOutcome.blocked) return;
    final entries = <TimeEntry>[...plan.entries];
    // The caller's seed wins over the plan's carried-over description; a claim
    // keeps the booking's own, which is the note the user wrote when booking.
    if (plan.claimed == null) {
      entries[entries.length - 1] = entries.last.copyWith(
        description: description,
        billable: billable,
      );
    }
    updateDraft(draft.copyWith(timeLog: entries));
  }

  /// Why the server would reject this draft's `time_log`, or null when it
  /// wouldn't. Surfaced on the form so an overlap is a visible, fixable field
  /// error rather than a 422 that dead-letters in the outbox after Save.
  ///
  /// Named for the draft rather than after the free function it calls, which
  /// a bare `timeLogProblem` getter would shadow inside this class.
  TimeLogProblem? get draftTimeLogProblem => timeLogProblem(draft.timeLog);

  /// Where the draft sits relative to its own bookings — what makes the times
  /// section offer Start rather than Resume on a task that has never been
  /// worked.
  TaskScheduleState get scheduleState => draft.scheduleStateAt(now());

  /// Stop the currently-running entry. No-op when nothing is running.
  void stopTimer() {
    if (draft.timeLog.isEmpty) return;
    final last = draft.timeLog.last;
    if (!last.isRunning) return;
    final n = now();
    final entries = <TimeEntry>[...draft.timeLog];
    entries[entries.length - 1] = last.copyWith(stop: n);
    updateDraft(draft.copyWith(timeLog: entries));
  }

  /// Resume tracking, seeded with the previous entry's description +
  /// billable so the user doesn't re-type context for an ongoing session.
  /// Falls through to [startTimer], which decides whether this is an append or
  /// a claim.
  void resumeTimer() {
    final entries = draft.timeLog;
    if (entries.isEmpty) {
      startTimer();
      return;
    }
    final last = entries.last;
    startTimer(description: last.description, billable: last.billable);
  }

  /// Seed a single running entry on a brand-new task when the company has
  /// `auto_start_tasks` enabled (admin-portal parity). No-op when the draft
  /// already has entries (e.g. a clone), so it's safe to call once after the
  /// company resolves.
  void applyAutoStartIfEmpty() {
    if (draft.timeLog.isNotEmpty) return;
    startTimer();
  }
}

Task emptyTask() => Task(
  id: '',
  number: '',
  description: '',
  rate: Decimal.zero,
  invoiceId: '',
  clientId: '',
  projectId: '',
  statusId: '',
  statusOrder: 0,
  assignedUserId: '',
  timeLog: const <TimeEntry>[],
  customValue1: '',
  customValue2: '',
  customValue3: '',
  customValue4: '',
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  archivedAt: null,
  isDeleted: false,
);
