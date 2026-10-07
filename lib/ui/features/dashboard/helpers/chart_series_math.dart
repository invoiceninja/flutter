import 'package:admin/data/models/domain/dashboard/dashboard_chart_series.dart';
import 'package:admin/data/models/value/date.dart';
import 'package:admin/ui/features/dashboard/view_models/dashboard_view_model.dart'
    show ChartSeriesId, ChartGrouping;
import 'package:admin/utils/date_ranges.dart';

/// Continuous, zero-filled time axis built from the *sparse* per-date points
/// `POST /api/v1/charts/chart_summary_v2` returns.
///
/// The server only emits buckets for dates that had activity, so plotting the
/// raw list by index collapses a sparse-but-equal series into a flat line and
/// loses the date scale. The reference React client
/// (`react/src/pages/dashboard/components/Chart.tsx`,
/// `hooks/useGenerateWeekDateRange.ts`, `helpers/helpers.ts`) generates the
/// bucket boundaries for the chosen Day/Week/Month grouping, zero-fills them,
/// then accumulates each sparse point into its bucket. This is a faithful Dart
/// port of that algorithm.
///
/// Week start follows the company `first_day_of_week` (0=Sun..6=Sat). With the
/// default 0 (Sunday) the boundary is the Saturday week-end — matching dayjs's
/// default `en` locale `endOf('week')`, which is what React uses.
class ChartAxis {
  const ChartAxis({
    required this.buckets,
    required this.values,
    this.grouping = ChartGrouping.month,
  });

  /// The grouping the buckets were actually built at — the one asked for, or a
  /// coarser / finer one when that could not draw a useful line (see
  /// [buildContinuousAxis]). The chart's Day / Week / Month control shows this,
  /// so it never claims a grouping the plot is not using.
  final ChartGrouping grouping;

  /// Ordered, contiguous bucket boundary dates spanning the period.
  final List<Date> buckets;

  /// One value per [buckets] index, per series. Missing buckets are `0.0`.
  final Map<ChartSeriesId, List<double>> values;

  bool get isEmpty => buckets.isEmpty;
}

/// Render-only ceiling. If the selected grouping would emit more boundaries
/// than this (e.g. "All time" at Day granularity), the *render* coarsens one
/// step (day→week→month) so fl_chart isn't handed tens of thousands of spots.
/// The user's selected grouping is unchanged.
const int _maxRenderBuckets = 750;

/// The fewest boundaries that still draw a shape. A single month grouped by
/// month is two — its first day and its last — which plots as one straight
/// line from nothing to the total: the default range under the default
/// grouping, and it said nothing a figure did not.
const int _minUsefulBuckets = 4;

/// Whether [grouping] can draw the window `[start, end]` as it stands: enough
/// boundaries to show a shape, few enough to render.
bool chartGroupingFits(
  Date start,
  Date end,
  ChartGrouping grouping, {
  int firstDayOfWeek = 0,
}) {
  if (start.compareTo(end) > 0) return false;
  final n = _buildBoundaries(start, end, grouping, firstDayOfWeek).length;
  return n >= _minUsefulBuckets && n <= _maxRenderBuckets;
}

/// Builds a [ChartAxis] from [pointsBySeries] at [grouping] granularity. Range
/// is `[startDate, endDate]` when both are present; otherwise it falls back to
/// the min/max of every non-null point date across all series. Returns an empty
/// axis when there is nothing datable to plot (caller shows the "no data"
/// overlay).
ChartAxis buildContinuousAxis({
  required Map<ChartSeriesId, List<DashboardChartPoint>> pointsBySeries,
  required Date? startDate,
  required Date? endDate,
  required ChartGrouping grouping,
  int firstDayOfWeek = 0,
  bool refineShortRanges = false,
}) {
  Date? start = startDate;
  Date? end = endDate;

  if (start == null || end == null) {
    Date? lo;
    Date? hi;
    for (final pts in pointsBySeries.values) {
      for (final p in pts) {
        final d = p.date;
        if (d == null) continue;
        if (lo == null || d.compareTo(lo) < 0) lo = d;
        if (hi == null || d.compareTo(hi) > 0) hi = d;
      }
    }
    start ??= lo;
    end ??= hi;
  }

  if (start == null || end == null || start.compareTo(end) > 0) {
    return const ChartAxis(buckets: [], values: {});
  }

  // Coarsen the *render* grouping until the boundary count is bounded.
  var effective = grouping;
  var buckets = _buildBoundaries(start, end, effective, firstDayOfWeek);
  while (buckets.length > _maxRenderBuckets &&
      effective != ChartGrouping.month) {
    effective = effective == ChartGrouping.day
        ? ChartGrouping.week
        : ChartGrouping.month;
    buckets = _buildBoundaries(start, end, effective, firstDayOfWeek);
  }
  // …and refine it while it is too coarse to show anything. Opt-in: the
  // boundary rules themselves are a port of the web client's and are tested
  // as such; this is the chart's own choice of which of them to draw.
  while (refineShortRanges &&
      buckets.length < _minUsefulBuckets &&
      effective != ChartGrouping.day) {
    final finer = effective == ChartGrouping.month
        ? ChartGrouping.week
        : ChartGrouping.day;
    final next = _buildBoundaries(start, end, finer, firstDayOfWeek);
    if (next.length > _maxRenderBuckets) break;
    effective = finer;
    buckets = next;
  }

  final values = <ChartSeriesId, List<double>>{
    for (final id in ChartSeriesId.values)
      id: List<double>.filled(buckets.length, 0),
  };

  pointsBySeries.forEach((id, pts) {
    final lane = values[id]!;
    for (final p in pts) {
      final d = p.date;
      if (d == null) continue;
      final idx = _bucketIndex(buckets, d, effective);
      if (idx < 0) continue;
      lane[idx] += p.total.toDouble();
    }
  });

  return ChartAxis(buckets: buckets, values: values, grouping: effective);
}

// ─── Boundary generation (ports of the React helpers) ───────────────────────

List<Date> _buildBoundaries(
  Date start,
  Date end,
  ChartGrouping grouping,
  int firstDayOfWeek,
) {
  switch (grouping) {
    case ChartGrouping.day:
      return _ensureUnique(_dailyBoundaries(start, end), end);
    case ChartGrouping.week:
      return _ensureUnique(_weeklyBoundaries(start, end, firstDayOfWeek), end);
    case ChartGrouping.month:
      return _ensureUnique(_monthlyBoundaries(start, end), end);
  }
}

List<Date> _dailyBoundaries(Date start, Date end) {
  // Date-space stepping (Date.addDays), not local-midnight + 24h: across a
  // DST transition the DateTime cursor drifted to 23:00/01:00, exited the
  // loop one day early, and silently dropped the range's final bucket (and
  // its revenue) from the chart.
  final out = <Date>[];
  var cursor = start;
  while (cursor.compareTo(end) <= 0) {
    out.add(cursor);
    cursor = cursor.addDays(1);
  }
  return out;
}

/// Port of `useGenerateWeekDateRange`: push `start` once, then each
/// `endOf('week')`, stepping a week at a time; clamp/append so the final
/// boundary lands on `end`. The week-end honors [firstDayOfWeek].
List<Date> _weeklyBoundaries(Date start, Date end, int firstDayOfWeek) {
  // Date-space stepping — see _dailyBoundaries.
  final out = <Date>[];
  var cursor = start;
  var first = true;
  while (cursor.compareTo(end) <= 0) {
    if (first) {
      out.add(start);
      first = false;
    }
    out.add(endOfWeek(cursor, firstDayOfWeek));
    cursor = cursor.addDays(7);
  }
  if (out.isEmpty) return out;
  if (out.last.compareTo(end) > 0) {
    out[out.length - 1] = end;
  } else if (out.last.compareTo(end) < 0) {
    out.add(end);
  }
  return out;
}

/// Port of `generateMonthDateRange`: partial-month-aware month-end boundaries.
List<Date> _monthlyBoundaries(Date start, Date end) {
  final out = <Date>[];
  final startFirst = _isFirstOfMonth(start);
  final startLast = _isLastOfMonth(start);
  if (!startFirst && !startLast) out.add(start);

  var year = start.year;
  var month = start.month;
  while (true) {
    final cursorFirst = Date(year, month, 1);
    if (cursorFirst == _firstOfMonth(start) && !startLast && startFirst) {
      out.add(start);
    }
    final eom = _monthEnd(Date(year, month, 1));
    if (eom.compareTo(end) <= 0) out.add(eom);

    if (year > end.year || (year == end.year && month >= end.month)) break;
    if (month == 12) {
      month = 1;
      year++;
    } else {
      month++;
    }
  }
  if (!_isLastOfMonth(end)) out.add(end);
  return out;
}

/// Port of `ensureUniqueDates`: clamp a trailing past-`end` boundary to `end`,
/// then dedupe by calendar day preserving first-seen order.
List<Date> _ensureUnique(List<Date> dates, Date end) {
  if (dates.isEmpty) return dates;
  if (dates.last.compareTo(end) > 0) dates[dates.length - 1] = end;
  final seen = <String>{};
  final out = <Date>[];
  for (final d in dates) {
    if (seen.add(d.toIso())) out.add(d);
  }
  return out;
}

// ─── Point → bucket assignment (port of `getRecordIndex`) ────────────────────

int _bucketIndex(List<Date> buckets, Date d, ChartGrouping grouping) {
  var idx = -1;
  var exact = false;
  for (var i = 0; i < buckets.length; i++) {
    if (i + 1 < buckets.length) {
      final lo = buckets[i];
      final hi = buckets[i + 1];
      final inRange = d.compareTo(lo) > 0 && d.compareTo(hi) < 0;
      final isExact = d == buckets[i];
      if (inRange || isExact) {
        idx = i;
        exact = isExact;
        break;
      }
    } else {
      if (d == buckets[i]) {
        idx = i;
        exact = true;
      }
      break;
    }
  }
  // Week/Month: a point landing strictly inside a period rolls into that
  // period's end bucket (the next boundary). Day never shifts.
  if (grouping != ChartGrouping.day && idx > -1 && !exact) {
    return idx + 1;
  }
  return idx;
}

// ─── Calendar helpers ───────────────────────────────────────────────────────

Date _firstOfMonth(Date d) => Date(d.year, d.month, 1);

Date _monthEnd(Date d) {
  // Day 0 of the next month == last day of this month.
  final dt = DateTime(d.year, d.month + 1, 0);
  return Date(dt.year, dt.month, dt.day);
}

bool _isFirstOfMonth(Date d) => d.day == 1;

bool _isLastOfMonth(Date d) => d.day == _monthEnd(d).day;
