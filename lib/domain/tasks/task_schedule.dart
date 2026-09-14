/// Booked time vs. worked time — the rules behind invoiceninja/flutter#149.
///
/// A task carries no stored start *time*: scheduling one means seeding a
/// future [TimeEntry] (`line_item_task_seed.dart`, `calendar_event_seed.dart`),
/// so a booking and a completed session are the same four wire slots. This
/// file is the only place that tells them apart, and it does so purely from a
/// caller-supplied `now` — the `task_day_load.dart` contract, and what keeps
/// every fixture here honest under `TZ=UTC` on CI.
///
/// ## The server contract this exists to satisfy
///
/// `Request::checkTimeLog` (`app/Http/Requests/Request.php`) sorts the log by
/// start and **422s the whole payload** when an entry is inverted, when a
/// zero-end (running) entry is followed by anything, or when one entry starts
/// before the previous one ends. Two ordinary gestures hit it:
///
///   * a booking `09:00–11:00` + Start at `09:30` → overlap;
///   * a booking `14:00–16:00` + Start at `09:00` → running-not-last.
///
/// So a running timer **cannot coexist with an unfinished booking on the same
/// task**, whichever order they are in. [planTaskStart] is the only legal way
/// to begin work on a booked task: it consumes the booking rather than adding
/// beside it. There is no fifth wire slot to mark an entry "planned" — both
/// task requests cap an entry at four elements.
///
/// ## The limitation to know before extending this
///
/// The discriminator is `stop > now` and nothing else, so the instant a
/// booking's window closes an unclaimed block becomes **byte-identical** to
/// two hours of work — in `loggedDuration`, in the dashboard day tint, and on
/// the invoice. [TaskScheduleState.late] recovers *some* of that by anchoring
/// on the task's own `due_date` (which the app writes whenever it books), but
/// a booking made anywhere else, or one whose due date was cleared, is gone.
/// Claiming is what stops the phantom hours accruing, and only the user can
/// trigger it.
library;

import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';

/// Where a task sits relative to its own bookings, at an instant.
///
/// Orthogonal to "is the timer running": a running task is always
/// [TaskScheduleState.none] here, because claiming has already happened.
enum TaskScheduleState {
  /// Nothing booked, or the booking can no longer be identified.
  none,

  /// A booked block starts later.
  upcoming,

  /// The clock is inside a booked block and nothing is running — the
  /// "should I be on site?" state.
  dueNow,

  /// The task's booked block has passed with no work logged against it.
  /// Deliberately narrow — see [taskScheduleState].
  late,
}

/// Why a `time_log` would be rejected. Mirrors the three rejection modes in
/// `Request::checkTimeLog`, in its order of evaluation.
enum TimeLogProblemKind {
  /// `end != 0 && start > end`.
  inverted,

  /// A running entry with another entry after it once sorted by start.
  runningNotLast,

  /// One entry begins before the previous one ends.
  overlap,
}

/// A rejection, carrying the window the server would name in its message
/// (`Overlap detected: <from> - <to>.`) so the app can say the same thing
/// without a round trip. [from] / [to] are null for [TimeLogProblemKind.inverted]
/// and [TimeLogProblemKind.runningNotLast], which name no window.
typedef TimeLogProblem = ({
  TimeLogProblemKind kind,
  DateTime? from,
  DateTime? to,
});

/// What starting the timer on this task would mean.
enum TaskStartOutcome {
  /// No booking in the way — append a running entry, exactly as before.
  append,

  /// One booking, live now or later today: it becomes the running entry.
  /// One tap; the caller offers Undo.
  claim,

  /// One booking on a different calendar day. Legal, but the user is not
  /// standing in front of it — the caller confirms first.
  claimOtherDay,

  /// The booked block has passed unworked. Claiming replaces it with time
  /// from now; the caller confirms, because [TaskScheduleState.late] is
  /// inferred and a false positive would discard real logged work.
  claimLate,

  /// Two or more unfinished bookings. No legal log exists in either
  /// direction — whichever is claimed, the running entry still precedes the
  /// others. The caller must send the user to the time log.
  blocked,
}

/// The outcome plus the log it implies. [entries] is left untouched for
/// [TaskStartOutcome.blocked]; [claimed] is the booking that would be
/// consumed, for the copy the caller shows.
typedef TaskStartPlan = ({
  TaskStartOutcome outcome,
  List<TimeEntry> entries,
  TimeEntry? claimed,
});

/// Entries with a start, ascending — the order `TaskRepository::save` imposes
/// server-side (`array_multisort` on column 0) and the order every `.last`
/// read in this app assumes.
///
/// **Entries with no start are dropped**, mirroring `TimeEntry.encodeLog`,
/// which refuses to serialise them. In practice that is a wire `0` start —
/// `TimeEntry.fromWire` maps it to null — rather than the half-typed draft the
/// nullable field was added for, which no path in `lib/` actually produces.
///
/// The consequence is deliberate: [timeLogProblem] therefore judges the log
/// **as it will be sent**, not as it is held, so its verdict and the server's
/// are about the same bytes. Sorting a null start as epoch 0 instead would
/// float it to the front and read as a second running entry, putting a
/// permanent error on a form the server would happily accept.
List<TimeEntry> sortTimeLog(List<TimeEntry> entries) {
  // Decorated with the original index, because `List.sort` is documented as
  // unstable (and switches to quicksort past 32 elements) while the server's
  // `usort` is stable: with two entries sharing a start, an unstable order can
  // make this and `checkTimeLog` reach opposite verdicts on identical bytes.
  // A `Map` keyed by the entry cannot do it — `TimeEntry` has value equality,
  // so two equal entries collide on one key, which is precisely the case the
  // tie-break exists for.
  final decorated = <({int index, TimeEntry entry})>[];
  for (final e in entries) {
    if (e.start != null) {
      decorated.add((index: decorated.length, entry: e));
    }
  }
  decorated.sort((a, b) {
    final c = a.entry.start!.compareTo(b.entry.start!);
    return c != 0 ? c : a.index.compareTo(b.index);
  });
  return [for (final d in decorated) d.entry];
}

/// The first reason the server would reject [entries], or null when it would
/// accept them. A faithful port of `Request::checkTimeLog`.
///
/// Entries with no start are skipped rather than failed — the draft holds one
/// between "+ Add time" and the first keystroke, and `encodeLog` drops it
/// before it ever reaches the wire. Flagging it would put a permanent error
/// banner on the edit form the moment a row is added.
TimeLogProblem? timeLogProblem(List<TimeEntry> entries) {
  final log = sortTimeLog(entries);
  for (var i = 0; i < log.length; i++) {
    final entry = log[i];
    final start = entry.start!;
    final stop = entry.stop;

    if (stop != null && start.isAfter(stop)) {
      return (kind: TimeLogProblemKind.inverted, from: null, to: null);
    }
    if (i == log.length - 1) continue;

    // Running, with something after it. The server tests `end === 0` here and
    // bails before it can compare windows.
    if (stop == null) {
      return (kind: TimeLogProblemKind.runningNotLast, from: null, to: null);
    }

    final next = log[i + 1];
    if (next.start!.isBefore(stop)) {
      final nextStop = next.stop;
      return (
        kind: TimeLogProblemKind.overlap,
        from: start.isAfter(next.start!) ? start : next.start!,
        to: nextStop == null || stop.isBefore(nextStop) ? stop : nextStop,
      );
    }
  }
  return null;
}

/// Whether [e] is a **booking** — time the user set aside, not time worked.
///
/// Two shapes, and the second is the one that took a bug to get right:
///
///  * `start > now` — unambiguous. Nobody works in the future, so a stopped
///    entry that hasn't begun can only be a plan, whoever created it.
///  * `start <= now < stop` — the clock is inside the block, which is what a
///    live booking looks like **and what an ordinary forward-looking timesheet
///    entry looks like**. The weekly grid synthesizes every cell at local 09:00
///    (`weekly_merge.dart`), so "8" typed into today's column is `09:00–17:00`
///    and looks identical to a booking until 17:00; `TaskRepository::roundTimeLog`
///    reaches the same state server-side by rounding an entry's end *up* when
///    `task_round_to_nearest > 1`, so stopping a timer at 09:07 can store
///    `09:00–10:00`. Treated as bookings, both billed **zero**, showed up under
///    Upcoming, and — worst — were *claimed* by [planTaskStart], which rewrites
///    the block's start to now and destroys the logged work.
///
/// So the straddling case requires the same **`due_date` anchor** [late] uses:
/// the app writes `due_date` whenever it books (both scheduling sheets do), and
/// nothing else does. A hand-logged block on a task with no matching due date is
/// therefore never a booking, never claimable, and bills in full.
///
/// Residual, accepted and narrow: a straddling block on a task whose due date
/// *is* that day stays claimable.
bool isTimeEntryBooking(TimeEntry e, {required DateTime now, Date? dueDate}) =>
    _isBooking(e, now, dueDate);

bool _isBooking(TimeEntry e, DateTime now, Date? dueDate) {
  if (e.isRunning) return false;
  final start = e.start;
  final stop = e.stop;
  if (start == null || stop == null) return false;
  if (start.isAfter(now)) return true;
  if (!stop.isAfter(now)) return false;
  return dueDate != null && _dayOf(start) == dueDate;
}

/// The task's unfinished bookings, earliest first. [entries] must already be
/// sorted — every caller here holds a sorted list, and sorting again per row
/// per build is pure waste.
List<TimeEntry> _bookings(
  List<TimeEntry> sorted,
  DateTime now,
  Date? dueDate,
) => [
  for (final e in sorted)
    if (_isBooking(e, now, dueDate)) e,
];

/// Time already spent: every entry that isn't a booking, plus the running one
/// measured to [now].
///
/// A block is counted **in full**, not clamped at `now`. That matters for the
/// straddling case above: the user typed eight hours into today's timesheet and
/// meant eight hours, and paying them for the elapsed 1½ would be its own kind
/// of wrong. What must not be counted is a block identified as a *plan* — see
/// [_isBooking]. [scheduledDuration] is the exact complement.
Duration workedDuration(
  List<TimeEntry> entries, {
  required DateTime now,
  Date? dueDate,
}) {
  var total = Duration.zero;
  for (final e in entries) {
    final start = e.start;
    if (start == null) continue;
    if (_isBooking(e, now, dueDate)) continue;
    final stop = e.stop;
    final d = (stop ?? now).difference(start);
    if (!d.isNegative) total += d;
  }
  return total;
}

/// Time booked but not yet worked — the exact complement of [workedDuration].
Duration scheduledDuration(
  List<TimeEntry> entries, {
  required DateTime now,
  Date? dueDate,
}) {
  var total = Duration.zero;
  for (final e in _bookings(sortTimeLog(entries), now, dueDate)) {
    final d = e.stop!.difference(e.start!);
    if (!d.isNegative) total += d;
  }
  return total;
}

/// The local calendar date [t] falls on.
Date _dayOf(DateTime t) {
  final local = t.toLocal();
  return Date(local.year, local.month, local.day);
}

/// The local calendar date an entry's start falls on. Duplicated from
/// `task_day.dart`'s `timeEntryLocalDate` rather than imported so this file
/// stays a leaf over `time_entry.dart` + `date.dart`; both are three lines
/// over `.toLocal()` and `task_schedule_test.dart` pins that they agree.
Date? _localDate(TimeEntry e) {
  final s = e.start;
  return s == null ? null : _dayOf(s);
}

/// Where [entries] sits relative to its bookings at [now].
///
/// [dueDate] is the task's own `due_date`, and it is what makes
/// [TaskScheduleState.late] detectable at all: once a block's window closes,
/// nothing in the log distinguishes an unworked booking from a finished
/// session. The app writes `due_date` alongside every booking it creates, so
/// "the task's single entry sits on its due date and has passed" is a booking
/// that was never started. The test is deliberately narrow — one entry only,
/// dates equal — because the consequence of a false positive is an offer to
/// discard real logged work. A booking created anywhere else (the weekly
/// grid, another client) carries no due date and reports [TaskScheduleState.none]
/// once its window passes.
TaskScheduleState taskScheduleState(
  List<TimeEntry> entries, {
  required DateTime now,
  Date? dueDate,
  int estimatedSeconds = 0,
}) {
  final log = sortTimeLog(entries);
  // `any`, not `.last.isRunning` as `Task.isRunning` does: a draft can hold a
  // running entry that does not sort last (the state the server rejects), and
  // "there is a timer going" is the answer either way.
  if (log.any((e) => e.isRunning)) return TaskScheduleState.none;

  final booked = _bookings(log, now, dueDate);
  if (booked.isNotEmpty) {
    return booked.first.start!.isAfter(now)
        ? TaskScheduleState.upcoming
        : TaskScheduleState.dueNow;
  }

  if (_isUnworkedPastBooking(log, now, dueDate, estimatedSeconds)) {
    return TaskScheduleState.late;
  }
  return TaskScheduleState.none;
}

/// The narrow shape of "this was booked and nobody turned up".
///
/// Every clause is paying for something. **One entry** — prior work means the
/// block was worked. **On the due date** — the app writes `due_date` when it
/// books and nothing else does. **Matching [estimatedSeconds]** — both
/// scheduling sheets seed the estimate from the block's own length, so an
/// untouched booking still matches while a block someone worked and adjusted
/// does not; without this clause a task with a single real logged entry on its
/// due date reads *late*, and the claim offers to discard it.
///
/// Even so this is a heuristic over data the server cannot disambiguate, which
/// is why claiming it prompts and the prompt names the duration it will replace.
bool _isUnworkedPastBooking(
  List<TimeEntry> sorted,
  DateTime now,
  Date? dueDate,
  int estimatedSeconds,
) {
  if (dueDate == null || estimatedSeconds <= 0 || sorted.length != 1) {
    return false;
  }
  final only = sorted.first;
  final stop = only.stop;
  if (only.isRunning || stop == null || !stop.isBefore(now)) return false;
  if (_localDate(only) != dueDate) return false;
  return stop.difference(only.start!).inSeconds == estimatedSeconds;
}

/// How late the booked block is, or null when the task is not
/// [TaskScheduleState.late]. Measured from the booking's **start**, which is
/// the time the user promised to be there.
Duration? lateBy(
  List<TimeEntry> entries, {
  required DateTime now,
  Date? dueDate,
  int estimatedSeconds = 0,
}) {
  if (taskScheduleState(
        entries,
        now: now,
        dueDate: dueDate,
        estimatedSeconds: estimatedSeconds,
      ) !=
      TaskScheduleState.late) {
    return null;
  }
  final d = now.difference(sortTimeLog(entries).first.start!);
  return d.isNegative ? Duration.zero : d;
}

/// What "start the timer now" means for [entries] — the single decision every
/// start path in the app routes through.
///
/// The returned log is always one the server will accept (asserted in
/// `task_schedule_test.dart`), except for [TaskStartOutcome.blocked], where
/// none exists and [entries] comes back untouched.
TaskStartPlan planTaskStart(
  List<TimeEntry> entries, {
  required DateTime now,
  Date? dueDate,
  int estimatedSeconds = 0,
}) {
  final sorted = sortTimeLog(entries);

  // Close any running entry first. A running entry whose start is in the
  // FUTURE is foreign data (no path here writes one), and closing it at `now`
  // would invert it — so it is dropped rather than kept as a zero-length block
  // in the future, which `_isBooking` would then read as a plan and offer to
  // claim: "Start" on a task with a stuck timer would open a claim dialog
  // instead of starting. A just-closed entry is work either way, never a plan,
  // so it is also excluded from the booking set below.
  final log = <TimeEntry>[];
  final justClosed = <int>{};
  for (final e in sorted) {
    if (!e.isRunning) {
      log.add(e);
      continue;
    }
    if (e.start!.isAfter(now)) continue;
    justClosed.add(log.length);
    log.add(e.copyWith(stop: now));
  }

  final booked = <int>[
    for (var i = 0; i < log.length; i++)
      if (!justClosed.contains(i) && _isBooking(log[i], now, dueDate)) i,
  ];

  TaskStartPlan blocked() =>
      (outcome: TaskStartOutcome.blocked, entries: entries, claimed: null);

  /// Every plan is checked against the server's own rules before it is
  /// offered. Belt and braces for the cases reasoning misses — the first one
  /// it caught: a *worked* block that spans `now` (today's 09:00–17:00
  /// timesheet row) is deliberately not a booking, so the append path added a
  /// running entry inside it, which is an overlap. There is no legal log
  /// there, which is exactly what [TaskStartOutcome.blocked] means.
  TaskStartPlan legal(TaskStartPlan plan) =>
      timeLogProblem(plan.entries) == null ? plan : blocked();

  if (booked.length > 1) return blocked();

  if (booked.isEmpty) {
    if (_isUnworkedPastBooking(log, now, dueDate, estimatedSeconds)) {
      // Single entry by construction (see `_isUnworkedPastBooking`), but built
      // from `log` rather than returned as a bare `[claimed]` so loosening that
      // clause can never silently discard the rest of the time log.
      final claimed = log.first;
      return legal((
        outcome: TaskStartOutcome.claimLate,
        entries: sortTimeLog([
          for (final e in log)
            if (identical(e, claimed))
              e.copyWith(start: now, stop: null)
            else
              e,
        ]),
        claimed: claimed,
      ));
    }
    // Unchanged behaviour: carry the last entry's description onto the new
    // one, but never its `billable` flag — a Start must not silently inherit
    // a non-billable one (`TaskRepository.startTimer`'s long-standing rule).
    final last = log.isNotEmpty ? log.last : null;
    return legal((
      outcome: TaskStartOutcome.append,
      entries: sortTimeLog([
        ...log,
        TimeEntry(start: now, stop: null, description: last?.description ?? ''),
      ]),
      claimed: null,
    ));
  }

  // By index, not by value or identity: the log can legitimately hold two
  // equal entries, and claiming both would open two timers.
  final index = booked.single;
  final claimed = log[index];
  final next = [...log]..[index] = claimed.copyWith(start: now, stop: null);
  final sameDay = _localDate(claimed) == _dayOf(now);
  return legal((
    outcome: sameDay ? TaskStartOutcome.claim : TaskStartOutcome.claimOtherDay,
    entries: sortTimeLog(next),
    claimed: claimed,
  ));
}
