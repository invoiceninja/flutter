import 'package:admin/data/models/value/dashboard_filter.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/utils/date_ranges.dart';

/// What a dashboard figure's trend compares: the part of the selected window
/// that has happened, and the matching part of the period before it.
///
/// The trend used to compare the whole window with the same number of days
/// shifted back. For a window still in progress that is not a comparison at
/// all: on the 7th, "This Month" set seven days of income against a whole
/// month, so every figure showed a steep fall until the month was nearly over.
/// A window still in progress is now compared with the same elapsed span of
/// the period before — the 1st to the 7th against the 1st to the 7th.
class DashboardComparison {
  const DashboardComparison({
    required this.currentStart,
    required this.currentEnd,
    required this.previousStart,
    required this.previousEnd,
  });

  /// The selected window up to today. Equal to the whole window once it is
  /// over.
  final Date currentStart;
  final Date currentEnd;

  /// The window the trend is measured against.
  final Date previousStart;
  final Date previousEnd;

  @override
  bool operator ==(Object other) =>
      other is DashboardComparison &&
      other.currentStart == currentStart &&
      other.currentEnd == currentEnd &&
      other.previousStart == previousStart &&
      other.previousEnd == previousEnd;

  @override
  int get hashCode =>
      Object.hash(currentStart, currentEnd, previousStart, previousEnd);

  @override
  String toString() =>
      'DashboardComparison($currentStart..$currentEnd vs '
      '$previousStart..$previousEnd)';
}

extension DashboardFilterComparison on DashboardFilter {
  /// The comparison for this filter, or null when there is no period before
  /// it to compare with ("All time").
  ///
  /// [today] is passed in, as it is to `resolveDates`, so both resolve against
  /// one calendar day and a test can fix it.
  DashboardComparison? comparison({Date? today}) {
    final t = today ?? Date.today();
    final r = range;
    if (r is DashboardPresetRange && r.preset == DashboardDatePreset.allTime) {
      return null;
    }
    final (start, end) = resolveDates(today: t);
    final (prevStart, prevEnd) = _precedingPeriod(r, start, end);

    // In progress: it has started and its last day is still to come.
    final inProgress = start.compareTo(t) <= 0 && end.compareTo(t) > 0;
    if (!inProgress) {
      return DashboardComparison(
        currentStart: start,
        currentEnd: end,
        previousStart: prevStart,
        previousEnd: prevEnd,
      );
    }
    // The same number of days from the start of the period before, and never
    // past its end: 31 days into March is the whole of February, not a
    // window that runs into March itself.
    final elapsedDays = t.differenceInDays(start) + 1;
    final spanEnd = prevStart.addDays(elapsedDays - 1);
    return DashboardComparison(
      currentStart: start,
      currentEnd: t,
      previousStart: prevStart,
      previousEnd: spanEnd.compareTo(prevEnd) > 0 ? prevEnd : spanEnd,
    );
  }

  /// The whole period immediately before `[start, end]`.
  ///
  /// A calendar preset steps back one calendar unit — the month before, the
  /// quarter before, the fiscal year before — because "the same number of days
  /// earlier" is not that: 30 days before September starts on August 2nd. A
  /// rolling window or a custom range has no calendar unit, so it steps back
  /// by its own length.
  (Date, Date) _precedingPeriod(DashboardDateRange r, Date start, Date end) {
    final before = start.addDays(-1);
    if (r is DashboardPresetRange) {
      switch (r.preset) {
        case DashboardDatePreset.thisMonth:
        case DashboardDatePreset.lastMonth:
          return (Date(before.year, before.month, 1), before);
        case DashboardDatePreset.thisQuarter:
        case DashboardDatePreset.lastQuarter:
          // `before` is the last day of the preceding quarter, so its quarter
          // starts two months earlier. `DateTime` carries a month below 1
          // into the year before.
          final first = DateTime(before.year, before.month - 2, 1);
          return (Date(first.year, first.month, first.day), before);
        case DashboardDatePreset.thisYear:
        case DashboardDatePreset.lastYear:
          return (startOfFiscalYear(before, firstMonthOfYear), before);
        case DashboardDatePreset.last7:
        case DashboardDatePreset.last30:
        case DashboardDatePreset.last365:
        case DashboardDatePreset.allTime:
          break;
      }
    }
    final length = end.differenceInDays(start) + 1;
    return (start.addDays(-(length <= 0 ? 1 : length)), before);
  }
}
