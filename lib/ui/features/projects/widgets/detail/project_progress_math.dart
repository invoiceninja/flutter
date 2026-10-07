import 'package:admin/data/models/domain/task.dart';
import 'package:admin/data/models/domain/time_entry.dart';
import 'package:admin/data/models/value/date.dart';

/// The arithmetic behind a project's progress — logged hours, the pace they
/// imply, and what that says against the budget. Pure, so the standing card
/// above the tabs and the chart in the Progress tab cannot disagree: both read
/// these.

enum ProgressStatus { onTrack, offPace, overBudget, unknown }

/// Flatten every billable time entry across [tasks] into a day-bucketed
/// cumulative-hours series sorted ascending in time. Each emitted record is
/// `(day, cumulativeHours)` where `day` is the local-time midnight of the
/// bucket. For long projects (>60 days of activity) buckets widen to weekly
/// so the chart stays readable.
///
/// Running entries contribute `(start..now)` to the bucket of `now`. Closed
/// entries contribute `(start..stop)` to the bucket of `stop`.
List<({DateTime t, double hours})> buildCumulativeSeries(
  List<Task> tasks,
  DateTime now,
) {
  final byDay = <DateTime, double>{};
  for (final task in tasks) {
    for (final entry in task.timeLog) {
      if (!entry.billable || entry.start == null) continue;
      // A booking is a plan, not logged hours — a stopped entry ending in the
      // future contributes nothing, matching `Task.billableDuration`. Without
      // this a project reads "over budget" from work nobody has started
      // (invoiceninja/flutter#149).
      final stop = entry.stop;
      if (stop != null && stop.isAfter(now)) continue;
      final duration = entry.durationUpTo(now);
      if (duration <= Duration.zero) continue;
      // `TimeEntry.start/stop` come from `epochSecondsToUtc` so they're UTC.
      // Bucket by the user's local calendar day to match every other time
      // call site in the app (e.g. `_TaskRow`, `time_entry_row.dart`).
      final end = (entry.stop ?? now).toLocal();
      final day = DateTime(end.year, end.month, end.day);
      byDay[day] = (byDay[day] ?? 0) + duration.inSeconds / 3600.0;
    }
  }
  if (byDay.isEmpty) return const <({DateTime t, double hours})>[];

  final days = byDay.keys.toList()..sort();
  final useWeekly = days.length > 60;
  if (!useWeekly) {
    final out = <({DateTime t, double hours})>[];
    var cumulative = 0.0;
    for (final day in days) {
      cumulative += byDay[day]!;
      out.add((t: day, hours: cumulative));
    }
    return out;
  }

  // Weekly re-bucket anchored on the first observed day.
  final anchor = days.first;
  final byWeek = <DateTime, double>{};
  for (final day in days) {
    final daysSince = day.difference(anchor).inDays;
    final weekStart = anchor.add(Duration(days: (daysSince ~/ 7) * 7));
    byWeek[weekStart] = (byWeek[weekStart] ?? 0) + byDay[day]!;
  }
  final weeks = byWeek.keys.toList()..sort();
  final out = <({DateTime t, double hours})>[];
  var cumulative = 0.0;
  for (final w in weeks) {
    cumulative += byWeek[w]!;
    out.add((t: w, hours: cumulative));
  }
  return out;
}

/// Linearly extrapolate total hours at project finish, given current burn
/// rate. Returns null when there isn't enough signal to extrapolate (no due
/// date, no hours logged, or less than a day elapsed).
double? computeProjected(
  double logged,
  DateTime createdAt,
  Date? dueDate,
  DateTime now,
) {
  if (dueDate == null || logged <= 0) return null;
  final dueDt = dueDate.toDateTime().add(const Duration(days: 1));
  final totalDays = dueDt.difference(createdAt).inMinutes / (60.0 * 24.0);
  final elapsedDays = now.difference(createdAt).inMinutes / (60.0 * 24.0);
  if (elapsedDays < 1.0 || totalDays <= 0) return null;
  return logged * (totalDays / elapsedDays);
}

/// Three-state pace status from logged vs budgeted vs projected. Returns
/// `unknown` when there's no budget to compare against, or when there's no
/// due date to define "on schedule" against — the pill renders a contextual
/// fallback in either case.
ProgressStatus deriveStatus(
  double logged,
  double budgeted,
  double? projected, {
  required Date? dueDate,
}) {
  if (budgeted <= 0) return ProgressStatus.unknown;
  if (logged >= budgeted) return ProgressStatus.overBudget;
  if (dueDate == null) return ProgressStatus.unknown;
  if (projected != null && projected > budgeted) return ProgressStatus.offPace;
  return ProgressStatus.onTrack;
}

/// Compact hour formatter. Whole numbers render as ints, fractions trim to
/// one decimal.
String fmtHours(double h) {
  if (h.truncate().toDouble() == h) return h.toInt().toString();
  return h.toStringAsFixed(1);
}
