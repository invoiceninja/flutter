import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/domain/tasks/task_schedule.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/tasks/task_day.dart';
import 'package:admin/utils/formatting.dart';

/// A pending edit to one weekly cell (one task × one day). A null field means
/// that aspect wasn't touched; [merge] overlays a newer edit's non-null fields
/// so several edits to the same cell within the debounce window collapse.
class CellEdit {
  CellEdit({this.duration, this.description, this.billable});

  /// Raw user-typed duration text. An empty string means "cleared" → delete.
  String? duration;
  String? description;
  bool? billable;

  void merge(CellEdit other) {
    if (other.duration != null) duration = other.duration;
    if (other.description != null) description = other.description;
    if (other.billable != null) billable = other.billable;
  }

  CellEdit copy() => CellEdit(
    duration: duration,
    description: description,
    billable: billable,
  );

  bool sameValueAs(CellEdit o) =>
      duration == o.duration &&
      description == o.description &&
      billable == o.billable;
}

/// Duration text → seconds, mirroring React's `parseDurationToSeconds`:
/// empty string → 0 (a cleared cell deletes the entry); otherwise reuse
/// [parseDurationInput] (bare number = hours, `1:30` = H:M, unit suffixes).
/// Returns null only for unparseable *non-empty* input.
int? durationStringToSeconds(String raw) {
  if (raw.trim().isEmpty) return 0;
  return parseDurationInput(raw)?.inSeconds;
}

/// Apply a weekly-cell [edit] (one task × one [day]) to [logs], leaving
/// entries on other days untouched. Returns the new log, or null if [edit]
/// carries an unparseable duration.
///
/// Two modes, by whether the duration was touched:
///
/// - **Duration edit** ([edit.duration] != null): the cell's total duration was
///   set, so every same-day entry is collapsed into a single entry of that
///   duration (intended — the cell is one editable duration; React parity).
/// - **Note / billable-only edit** ([edit.duration] == null): the cell shows the
///   FIRST same-day entry's note/billable (see
///   `TaskWeeklyViewModel.cellDescription`/`cellBillable`), so the change is
///   overlaid onto that entry ONLY and every other same-day entry is kept as-is.
///   Collapsing here (as a duration edit does) would silently delete the other
///   same-day entries' logged hours — billable-time data loss into invoicing.
///
/// Local↔UTC discipline (the load-bearing part): day membership and the
/// synthesized 09:00 start are computed in local wall-clock, then stored as
/// UTC — [TimeEntry.start] is UTC on the wire. An existing entry's start is
/// preserved verbatim so re-editing a cell never drifts its clock time.
/// Result of a cell edit: the new log, or the reason it was refused.
///
/// Two refusals, and they must not share a message — `null` used to mean both,
/// and the view model could only report "Please enter a valid duration" for a
/// duration that was perfectly valid.
typedef CellEditResult = ({List<TimeEntry>? logs, TimeLogProblem? problem});

CellEditResult applyCellEditToLogs(
  List<TimeEntry> logs,
  Date day,
  CellEdit edit,
  DateTime now, {
  Date? dueDate,
}) {
  // ── Note / billable-only edit: don't collapse; overlay onto the first
  // same-day entry and preserve every other entry (and its hours). ──────────
  if (edit.duration == null) {
    var applied = false;
    final result = <TimeEntry>[];
    for (final e in logs) {
      if (!applied && timeEntryLocalDate(e) == day) {
        applied = true;
        final description = edit.description ?? e.description;
        final billable = edit.billable ?? e.billable;
        // Clearing the note on a zero-duration entry deletes it (mirrors the
        // duration path's delete rule); a running/timed entry is preserved
        // verbatim (copyWith keeps start/stop, so a note edit never freezes a
        // running timer or alters logged time).
        if (e.durationUpTo(now).inSeconds <= 0 && description.isEmpty) {
          continue;
        }
        result.add(e.copyWith(description: description, billable: billable));
      } else {
        result.add(e);
      }
    }
    if (applied) return (logs: result, problem: null);
    // No existing entry on this day → create one (local 09:00, zero duration)
    // carrying the note, unless it would be empty (then it's a no-op).
    final description = edit.description ?? '';
    if (description.isEmpty) return (logs: logs, problem: null);
    final startUtc = DateTime(day.year, day.month, day.day, 9).toUtc();
    return (
      logs: [
        ...logs,
        TimeEntry(
          start: startUtc,
          stop: startUtc,
          description: description,
          billable: edit.billable ?? true,
        ),
      ],
      problem: null,
    );
  }

  // ── Duration edit: collapse every same-day entry into one. ────────────────
  TimeEntry? existing;
  final remaining = <TimeEntry>[];
  for (final e in logs) {
    // A booking is a plan, not logged time. Collapsing one into the cell's
    // total silently overwrites the slot the user reserved — and, because the
    // collapsed entry inherits the *first* same-day entry's start, it would
    // also re-label the reserved window as work. Typing `3` into the Thursday
    // cell of a task booked 14:00–16:00 Thursday used to do exactly that.
    // The SHARED predicate, anchored on the task's own `due_date` — not
    // `stop > now`, which also matches the block this grid synthesizes for
    // today (every cell starts at local 09:00, so "8" typed this morning is
    // 09:00–17:00). Treating that as a booking made the grid refuse every
    // further edit to today's cell until 17:00.
    if (!isTimeEntryBooking(e, now: now, dueDate: dueDate) &&
        timeEntryLocalDate(e) == day) {
      // First same-day entry seeds description/billable/start; any further
      // same-day entries are intentionally collapsed away.
      existing ??= e;
    } else {
      remaining.add(e);
    }
  }

  final parsed = durationStringToSeconds(edit.duration!);
  if (parsed == null) return (logs: null, problem: null);
  final seconds = parsed;

  final description = edit.description ?? existing?.description ?? '';
  final billable = edit.billable ?? existing?.billable ?? true;

  // Zero duration and no description → delete the entry.
  if (seconds <= 0 && description.isEmpty) {
    return (logs: remaining, problem: null);
  }

  final DateTime startUtc;
  if (existing?.start != null) {
    startUtc = existing!.start!;
  } else {
    // Local 09:00 on `day`, stored as UTC.
    startUtc = DateTime(day.year, day.month, day.day, 9).toUtc();
  }
  remaining.add(
    TimeEntry(
      start: startUtc,
      stop: startUtc.add(Duration(seconds: seconds)),
      description: description,
      billable: billable,
    ),
  );
  // Refuse an edit the server would reject rather than queueing a 422: the
  // synthesized block can still run into a preserved booking on the same day,
  // and `remaining.add` leaves a running entry on another day no longer last.
  // The caller discards just this cell and reverts it on the next emission.
  final problem = timeLogProblem(remaining);
  if (problem != null) return (logs: null, problem: problem);
  return (logs: remaining, problem: null);
}
