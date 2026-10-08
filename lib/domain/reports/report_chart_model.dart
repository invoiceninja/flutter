import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_measures.dart';

/// How many groups a ranked list shows before the rest fold into "Other".
const int kReportRankedLimit = 10;

/// How many groups a chart of groups-over-time draws as their own series
/// before the rest fold into "Other". Five, because a sixth colour is one
/// more than a reader holds apart at a glance, and every one of them also
/// has to be told from its neighbours by someone who cannot see red.
const int kReportSeriesLimit = 5;

/// What a report's summary draws for the current grouping and measure.
///
/// The form follows the data's job, not a preference:
/// * a date grouping is a trend → [ReportTimeSeriesChart];
/// * any other grouping is a comparison of magnitudes → [ReportRankedChart];
/// * a grouping split by period is both → [ReportPivotChart];
/// * no grouping still has a shape worth showing — the largest rows —
///   which is a [ReportRankedChart] too ([ReportRankedChart.fromRows]).
///
/// Pure data: keys are the engine's own bucket keys (identity — what a
/// drill-down matches on), and labels are the UI's business.
sealed class ReportChartModel {
  const ReportChartModel({required this.measureId, required this.currencyId});

  /// The measure plotted — a column identifier or [kReportCountSeriesId].
  final String measureId;

  /// The currency the figures are in; `''` for a report without one.
  final String currencyId;

  bool get isEmpty;
}

/// One period of a [ReportTimeSeriesChart].
class ReportChartPoint {
  const ReportChartPoint({
    required this.key,
    required this.value,
    required this.hasRows,
  });

  /// The bucket key — an ISO bucket start.
  final String key;
  final Decimal value;

  /// False for a period the gap fill supplied: nothing happened in it, so
  /// there is nothing to drill into.
  final bool hasRows;
}

/// A measure over time, oldest first, with empty periods filled in.
class ReportTimeSeriesChart extends ReportChartModel {
  const ReportTimeSeriesChart({
    required super.measureId,
    required super.currencyId,
    required this.points,
    required this.cumulative,
    this.previous = const [],
  });

  final List<ReportChartPoint> points;

  /// The same measure over the period before, one value per point and in
  /// step with it — the first month of this year beside the first month of
  /// last — or empty when nothing is being compared. Null where the earlier
  /// period has no such point (it was shorter, or is not over yet).
  final List<Decimal?> previous;

  bool get hasPrevious => previous.any((v) => v != null);

  /// Whether each point is the running total up to its period.
  final bool cumulative;

  @override
  bool get isEmpty => !points.any((p) => p.value != Decimal.zero);

  /// Index of the highest point, or -1 when nothing is above zero. Not
  /// offered for a running total, whose peak is always its last point.
  int get peakIndex {
    if (cumulative) return -1;
    var best = -1;
    var bestValue = Decimal.zero;
    for (var i = 0; i < points.length; i++) {
      if (points[i].value > bestValue) {
        bestValue = points[i].value;
        best = i;
      }
    }
    return best;
  }

  /// Index of the last period that has rows, or -1.
  int get latestIndex {
    for (var i = points.length - 1; i >= 0; i--) {
      if (points[i].hasRows) return i;
    }
    return -1;
  }
}

/// One line of a [ReportRankedChart].
class ReportRankedItem {
  const ReportRankedItem({
    required this.key,
    required this.value,
    required this.count,
    required this.share,
    this.isOther = false,
    this.row,
    this.previous,
  });

  /// What the same group came to in the period before, when a comparison is
  /// on and the group existed then. Null says "nothing to compare with",
  /// which is not zero.
  final Decimal? previous;

  /// The group's bucket key; for a list built from rows, the row's position
  /// as text. Meaningless for the "Other" line.
  final String key;
  final Decimal value;

  /// How many rows the line stands for — and, on the "Other" line, how many
  /// groups were folded into it.
  final int count;

  /// [value] as a fraction of the total, or null when the total is not a
  /// sum of like-signed parts (a list holding both charges and credits has
  /// no meaningful "share").
  final double? share;
  final bool isOther;

  /// The row itself, when the list ranks rows rather than groups.
  final ReportRow? row;
}

/// Groups — or rows — compared by one measure, largest first.
class ReportRankedChart extends ReportChartModel {
  const ReportRankedChart({
    required super.measureId,
    required super.currencyId,
    required this.items,
    required this.total,
    required this.fromRows,
    required this.labelCellIndex,
    this.detailCellIndex = -1,
  });

  final List<ReportRankedItem> items;

  /// Everything, shown and folded.
  final Decimal total;

  /// Whether the lines are the report's own rows (an ungrouped report) —
  /// then [labelCellIndex] is the cell that names each one.
  final bool fromRows;
  final int labelCellIndex;

  /// A second cell that tells two rows with the same name apart — the
  /// record's own number beside its client — or -1 when the result shows
  /// none. Ten invoices of one client were otherwise ten identical lines.
  final int detailCellIndex;

  @override
  bool get isEmpty => items.isEmpty;

  /// The largest value on the list, for scaling the bars. Zero when empty.
  Decimal get maxValue {
    var best = Decimal.zero;
    for (final item in items) {
      final v = item.value.abs();
      if (v > best) best = v;
    }
    return best;
  }
}

/// One series of a [ReportPivotChart].
class ReportPivotSeries {
  const ReportPivotSeries({
    required this.key,
    required this.slot,
    required this.values,
    required this.total,
    required this.count,
    this.isOther = false,
  });

  /// The group part of the composite keys; meaningless for "Other".
  final String key;

  /// Which categorical colour the series wears, 0-based — assigned once per
  /// group and then kept, see [ReportChartModels.build]. -1 for "Other",
  /// which is neutral.
  final int slot;

  /// One value per [ReportPivotChart.periods], zero where there is none.
  final List<Decimal> values;
  final Decimal total;
  final int count;
  final bool isOther;
}

/// Groups compared over time: the largest few as series, the rest as one.
class ReportPivotChart extends ReportChartModel {
  const ReportPivotChart({
    required super.measureId,
    required super.currencyId,
    required this.periods,
    required this.series,
    required this.total,
  });

  /// Period keys, oldest first, gaps filled; a trailing `''` is the bucket
  /// of rows that had no date.
  final List<String> periods;

  /// Largest first, "Other" last.
  final List<ReportPivotSeries> series;
  final Decimal total;

  @override
  bool get isEmpty => series.isEmpty || periods.isEmpty;
}

/// Builds a [ReportChartModel] from an engine view.
abstract final class ReportChartModels {
  /// The chart for [view], or null when there is nothing it could draw (no
  /// measure, or an ungrouped report with no column to name its rows by).
  ///
  /// [groupColumn] is the column the view is grouped by, null when it is not
  /// grouped; [splitByPeriod] is whether its keys are composite. [fillSpan]
  /// supplies the contiguous period keys between two bucket starts (the
  /// engine's `dateBucketSpan` at the active granularity) and may answer
  /// empty to decline.
  ///
  /// [slots] is the caller's memory of which colour each group wears. It is
  /// read and **written**: a group keeps the slot it was first given for as
  /// long as the caller keeps the map, so narrowing a filter does not
  /// repaint the series that survive it. Colour follows the entity, never
  /// its rank.
  static ReportChartModel? build({
    required ReportView view,
    required String measureId,
    required String currencyId,
    required ReportColumn? groupColumn,
    required bool splitByPeriod,
    List<String> Function(String first, String last)? fillSpan,
    bool cumulative = false,
    int rankedLimit = kReportRankedLimit,
    int seriesLimit = kReportSeriesLimit,
    Map<String, int>? slots,
    ReportView? previous,
    String? Function(String periodKey)? previousPeriodOf,
  }) {
    if (groupColumn == null || view.groups.isEmpty) {
      return _fromRows(view, measureId, currencyId, rankedLimit);
    }
    if (splitByPeriod) {
      return _pivot(
        view,
        measureId,
        currencyId,
        fillSpan,
        seriesLimit,
        slots ?? <String, int>{},
      );
    }
    if (isReportDateType(groupColumn.type)) {
      return _timeSeries(
        view,
        measureId,
        currencyId,
        fillSpan,
        cumulative,
        previous: previous,
        previousPeriodOf: previousPeriodOf,
      );
    }
    return _ranked(
      view,
      measureId,
      currencyId,
      rankedLimit,
      previous: previous,
    );
  }

  static ReportTimeSeriesChart _timeSeries(
    ReportView view,
    String measureId,
    String currencyId,
    List<String> Function(String, String)? fillSpan,
    bool cumulative, {
    ReportView? previous,
    String? Function(String periodKey)? previousPeriodOf,
  }) {
    Map<String, Decimal> valuesOf(ReportView v) => {
      for (final g in v.groups)
        // A row with no date has no place on a time axis.
        if (g.key.isNotEmpty)
          g.key: reportGroupValue(g, measureId, currencyId) ?? Decimal.zero,
    };

    final byKey = valuesOf(view);
    final keys = _periodAxis(byKey.keys, fillSpan);
    // The period before, point for point. Matched by *position in the
    // period* — [previousPeriodOf] answers "which earlier bucket is this
    // one's counterpart" — never by index into two lists: this year's data
    // may start in March while last year's starts in January.
    final earlier = previous == null || previousPeriodOf == null
        ? null
        : valuesOf(previous);
    var running = Decimal.zero;
    var runningEarlier = Decimal.zero;
    final previousValues = <Decimal?>[];
    final points = <ReportChartPoint>[];
    for (final key in keys) {
      final value = byKey[key] ?? Decimal.zero;
      running += value;
      points.add(
        ReportChartPoint(
          key: key,
          value: cumulative ? running : value,
          hasRows: byKey.containsKey(key),
        ),
      );
      if (earlier != null) {
        final counterpart = previousPeriodOf!(key);
        if (counterpart == null) {
          previousValues.add(null);
        } else {
          // In the earlier window with no rows is a real zero.
          final v = earlier[counterpart] ?? Decimal.zero;
          runningEarlier += v;
          previousValues.add(cumulative ? runningEarlier : v);
        }
      }
    }
    return ReportTimeSeriesChart(
      measureId: measureId,
      currencyId: currencyId,
      cumulative: cumulative,
      points: points,
      previous: previousValues,
    );
  }

  static ReportRankedChart _ranked(
    ReportView view,
    String measureId,
    String currencyId,
    int limit, {
    ReportView? previous,
  }) {
    final lines = <(String, Decimal, int)>[];
    for (final g in view.groups) {
      final value = reportGroupValue(g, measureId, currencyId);
      if (value == null || value == Decimal.zero) continue;
      lines.add((g.key, value, _countIn(g.rows, currencyId)));
    }
    return _rankedOf(
      lines: lines,
      measureId: measureId,
      currencyId: currencyId,
      limit: limit,
      previous: previous == null
          ? null
          : {
              for (final g in previous.groups)
                if (reportGroupValue(g, measureId, currencyId) case final v?)
                  g.key: v,
            },
    );
  }

  static ReportRankedChart? _fromRows(
    ReportView view,
    String measureId,
    String currencyId,
    int limit,
  ) {
    // The count of one row is one; a list of ones is not a ranking.
    if (measureId == kReportCountSeriesId) return null;
    final measureIndex = view.cellIndexByColumn[measureId];
    if (measureIndex == null) return null;
    final labelIndex = _labelCellIndex(view);
    if (labelIndex < 0) return null;
    final lines = <(String, Decimal, int)>[];
    final rows = <String, ReportRow>{};
    for (var i = 0; i < view.rows.length; i++) {
      final row = view.rows[i];
      if (currencyId.isNotEmpty && (row.currencyId ?? '') != currencyId) {
        continue;
      }
      final value = reportRowValue(row, measureIndex);
      if (value == null || value == Decimal.zero) continue;
      final key = '$i';
      lines.add((key, value, 1));
      rows[key] = row;
    }
    return _rankedOf(
      lines: lines,
      measureId: measureId,
      currencyId: currencyId,
      limit: limit,
      rows: rows,
      labelCellIndex: labelIndex,
      detailCellIndex: _detailCellIndex(view, labelIndex),
      // The rows beyond the first few are not a category worth a bar: "the
      // other 204 invoices" dwarfs every line it sits under.
      foldRest: false,
    );
  }

  /// The cell that names a row: the first visible text column.
  static int _labelCellIndex(ReportView view) {
    for (final column in view.visibleColumns) {
      if (column.type == ReportColumnType.string) {
        return view.cellIndexByColumn[column.identifier] ?? -1;
      }
    }
    return -1;
  }

  /// The cell that tells same-named rows apart: a visible `…number` column,
  /// else a visible `…name` column, other than the label itself.
  static int _detailCellIndex(ReportView view, int labelIndex) {
    for (final tail in const ['number', 'name']) {
      for (final column in view.visibleColumns) {
        if (column.type != ReportColumnType.string) continue;
        if (column.identifier.split('.').last != tail) continue;
        final index = view.cellIndexByColumn[column.identifier] ?? -1;
        if (index >= 0 && index != labelIndex) return index;
      }
    }
    return -1;
  }

  static ReportRankedChart _rankedOf({
    required List<(String, Decimal, int)> lines,
    required String measureId,
    required String currencyId,
    required int limit,
    Map<String, ReportRow>? rows,
    int labelCellIndex = -1,
    int detailCellIndex = -1,
    bool foldRest = true,
    Map<String, Decimal>? previous,
  }) {
    // Largest first; equal values keep the engine's order, so a list of ties
    // does not reshuffle between builds.
    final ranked = [for (var i = 0; i < lines.length; i++) (i, lines[i])]
      ..sort((a, b) {
        final byValue = b.$2.$2.compareTo(a.$2.$2);
        return byValue != 0 ? byValue : a.$1.compareTo(b.$1);
      });
    var total = Decimal.zero;
    var allPositive = true;
    for (final (_, line) in ranked) {
      total += line.$2;
      if (line.$2 < Decimal.zero) allPositive = false;
    }
    double? shareOf(Decimal value) {
      if (!allPositive || total <= Decimal.zero) return null;
      return (value / total).toDouble();
    }

    final shown = ranked.length > limit ? ranked.sublist(0, limit) : ranked;
    final rest = ranked.length > limit
        ? ranked.sublist(limit)
        : const <(int, (String, Decimal, int))>[];
    final items = [
      for (final (_, line) in shown)
        ReportRankedItem(
          key: line.$1,
          value: line.$2,
          count: line.$3,
          share: shareOf(line.$2),
          row: rows?[line.$1],
          previous: previous?[line.$1],
        ),
    ];
    if (rest.isNotEmpty && foldRest) {
      var other = Decimal.zero;
      for (final (_, line) in rest) {
        other += line.$2;
      }
      items.add(
        ReportRankedItem(
          key: '',
          value: other,
          count: rest.length,
          share: shareOf(other),
          isOther: true,
        ),
      );
    }
    return ReportRankedChart(
      measureId: measureId,
      currencyId: currencyId,
      items: items,
      total: total,
      fromRows: rows != null,
      labelCellIndex: labelCellIndex,
      detailCellIndex: detailCellIndex,
    );
  }

  static ReportPivotChart _pivot(
    ReportView view,
    String measureId,
    String currencyId,
    List<String> Function(String, String)? fillSpan,
    int seriesLimit,
    Map<String, int> slots,
  ) {
    // group part → period → value
    final values = <String, Map<String, Decimal>>{};
    final counts = <String, int>{};
    final periodKeys = <String>{};
    for (final g in view.groups) {
      final value = reportGroupValue(g, measureId, currencyId);
      if (value == null || value == Decimal.zero) continue;
      final (group, period) = splitReportGroupKey(g.key);
      final p = period ?? '';
      periodKeys.add(p);
      final into = values[group] ??= {};
      into[p] = (into[p] ?? Decimal.zero) + value;
      counts[group] = (counts[group] ?? 0) + _countIn(g.rows, currencyId);
    }
    final dated = _periodAxis(periodKeys.where((k) => k.isNotEmpty), fillSpan);
    final periods = [...dated, if (periodKeys.contains('')) ''];

    Decimal totalOf(Map<String, Decimal> perPeriod) {
      var sum = Decimal.zero;
      for (final v in perPeriod.values) {
        sum += v;
      }
      return sum;
    }

    final groups = values.keys.toList();
    final totals = {for (final g in groups) g: totalOf(values[g]!)};
    final order = [for (var i = 0; i < groups.length; i++) (i, groups[i])]
      ..sort((a, b) {
        final byTotal = totals[b.$2]!.compareTo(totals[a.$2]!);
        return byTotal != 0 ? byTotal : a.$1.compareTo(b.$1);
      });
    final leading = [for (final (_, g) in order.take(seriesLimit)) g];
    final rest = [for (final (_, g) in order.skip(seriesLimit)) g];

    // A group keeps the colour it already has; a newcomer takes the lowest
    // one nobody on screen is wearing.
    final taken = {
      for (final g in leading)
        if (slots[g] case final slot? when slot < seriesLimit) slot,
    };
    for (final g in leading) {
      final existing = slots[g];
      if (existing != null && existing < seriesLimit) continue;
      var slot = 0;
      while (taken.contains(slot)) {
        slot++;
      }
      taken.add(slot);
      slots[g] = slot;
    }

    var total = Decimal.zero;
    for (final t in totals.values) {
      total += t;
    }
    final series = [
      for (final g in leading)
        ReportPivotSeries(
          key: g,
          slot: slots[g]!,
          values: [for (final p in periods) values[g]![p] ?? Decimal.zero],
          total: totals[g]!,
          count: counts[g] ?? 0,
        ),
    ];
    if (rest.isNotEmpty) {
      var otherTotal = Decimal.zero;
      final otherValues = [
        for (final p in periods)
          () {
            var sum = Decimal.zero;
            for (final g in rest) {
              sum += values[g]![p] ?? Decimal.zero;
            }
            otherTotal += sum;
            return sum;
          }(),
      ];
      series.add(
        ReportPivotSeries(
          key: '',
          slot: -1,
          values: otherValues,
          total: otherTotal,
          count: rest.length,
          isOther: true,
        ),
      );
    }
    return ReportPivotChart(
      measureId: measureId,
      currencyId: currencyId,
      periods: periods,
      series: series,
      total: total,
    );
  }

  /// [keys] oldest first, with the periods between the first and the last
  /// filled in when [fillSpan] can supply them.
  static List<String> _periodAxis(
    Iterable<String> keys,
    List<String> Function(String, String)? fillSpan,
  ) {
    final sorted = keys.toList()..sort();
    if (sorted.length < 2 || fillSpan == null) return sorted;
    final span = fillSpan(sorted.first, sorted.last);
    // Declined (too long a span, an undeclared granularity) or nothing
    // missing: the buckets as they are.
    return span.length > sorted.length ? span : sorted;
  }

  static int _countIn(List<ReportRow> rows, String currencyId) {
    if (currencyId.isEmpty) return rows.length;
    var count = 0;
    for (final row in rows) {
      if (row.currencyId == currencyId) count++;
    }
    return count;
  }
}
