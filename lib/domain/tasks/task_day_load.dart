import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/domain/tasks/task_day.dart';

/// How much time is booked on each calendar day — the signal behind the
/// dashboard's task-calendar panel.
///
/// Sibling of `task_day.dart` rather than part of it: that file answers "which
/// day does this task belong to" and deliberately holds no policy, while this
/// one owns [kFullDayLoad], a product decision about what "a full day" means.
///
/// Four things are load-bearing.
///
/// **It buckets per TIME ENTRY, not per task.** [TaskDay.day] / `tasksByDay`
/// answer a different question — which day a task *starts* — and drop every
/// later day the task was worked on, so a task with entries on Monday and
/// Wednesday would colour only Monday. The per-entry rule here is the one
/// `TaskWeeklyViewModel.secondsFor` already applies, which is what keeps this
/// panel and the weekly timesheet from ever disagreeing about the same
/// Tuesday (`test/domain/tasks/task_day_load_test.dart` pins the parity).
///
/// **An entry is attributed entirely to its START day.** [timeEntryLocalDate]
/// keys on the start, so a 20:00 → 04:00 session puts all eight hours on the
/// first day, and a still-running entry begun yesterday lands wholly on
/// yesterday. That is imperfect for an availability read and it is still the
/// right call: the weekly timesheet does exactly this, and a panel that split
/// entries across midnight would contradict the screen the user taps through
/// to.
///
/// **[now] is a required parameter.** A running entry's elapsed time is
/// measured against it (`TimeEntryX.durationUpTo`, which already clamps a
/// negative to zero), so a hard-coded `DateTime.now()` in here would make
/// every test non-deterministic.
///
/// **The result is a snapshot at the caller's last rebuild, not a ticker.**
/// A running timer's cell therefore fills only when something else notifies.
/// That is deliberate — re-laying out 42 cells once a second to move a 3 px
/// bar is not worth the frames — so do not wrap a caller in a `Timer.periodic`
/// to "fix" it.
///
/// Inherited limitation: `task_day.dart`'s header records that bucketing uses
/// the DEVICE timezone while the server's `calculated_start_date` uses the
/// COMPANY timezone, so a near-midnight entry can land one cell off from the
/// React client. Unchanged here.

/// A fully-booked day. The server carries no capacity field, so this is a
/// named constant rather than a magic 8 at a call site — and every threshold
/// in [dayLoadBucket] is expressed against it, so moving it moves all three.
const Duration kFullDayLoad = Duration(hours: 8);

/// How booked a day is. [free] is the only level that renders nothing at all.
enum DayLoadBucket { free, light, limited, full }

/// Booked duration per LOCAL calendar day across [tasks].
///
/// Days with nothing logged are absent from the map rather than present at
/// zero — a caller reads `map[day] ?? Duration.zero`. A day whose entries all
/// have zero length *is* present, at zero, so a caller deciding whether
/// anything is booked must test the value, not the key.
///
/// [from] and [to] are inclusive bounds. Pass them whenever the caller only
/// renders a window: unbounded, this walks every entry of every task the
/// account has ever had and allocates a `Date` per entry, which on a surface
/// that rebuilds with the task stream is a lot of work to answer a question
/// about 42 days.
Map<Date, Duration> taskLoadByDay(
  Iterable<Task> tasks, {
  required DateTime now,
  Date? from,
  Date? to,
}) {
  final out = <Date, Duration>{};
  for (final task in tasks) {
    for (final entry in task.timeLog) {
      final day = timeEntryLocalDate(entry);
      if (day == null) continue;
      if (from != null && day.compareTo(from) < 0) continue;
      if (to != null && day.compareTo(to) > 0) continue;
      out[day] = (out[day] ?? Duration.zero) + entry.durationUpTo(now);
    }
  }
  return out;
}

/// Which bucket [booked] falls in.
///
/// Compared as whole [Duration]s, never as a `booked / kFullDayLoad` ratio:
/// a double puts the half-day and full-day boundaries on float edges, so
/// exactly 4h or exactly 8h could land either side depending on rounding.
DayLoadBucket dayLoadBucket(Duration booked) {
  if (booked <= Duration.zero) return DayLoadBucket.free;
  if (booked >= kFullDayLoad) return DayLoadBucket.full;
  if (booked < kFullDayLoad ~/ 2) return DayLoadBucket.light;
  return DayLoadBucket.limited;
}

/// [booked] as a fraction of a full day, clamped to `0..1` so an over-booked
/// day cannot overflow the bar it drives. The clamp is deliberate: two shades
/// of "over" are indistinguishable in a 36 px cell, and "full, no room" is the
/// actionable answer either way — the exact figure rides in the cell's
/// semantics label.
double dayLoadFraction(Duration booked) {
  if (booked <= Duration.zero) return 0;
  final f = booked.inSeconds / kFullDayLoad.inSeconds;
  return f > 1 ? 1 : f;
}
