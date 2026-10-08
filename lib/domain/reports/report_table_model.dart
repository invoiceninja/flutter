import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_engine.dart';

/// One line of the report table, below its header and totals.
sealed class ReportTableLine {
  const ReportTableLine({required this.depth});

  /// How far the line is indented: 0 at the top level, one more for each
  /// group it sits inside.
  final int depth;
}

/// A group, with what it adds up to.
class ReportTableGroupLine extends ReportTableLine {
  const ReportTableGroupLine({
    required this.id,
    required this.labelKey,
    required this.isPeriod,
    required this.drillKey,
    required this.count,
    required this.totals,
    required this.expanded,
    required super.depth,
  });

  /// Identity of the line among its siblings — what the expanded set holds.
  final String id;

  /// The key to label the line by. A whole engine key at the top level; on
  /// a period line beneath a group, the period's own bucket start (see
  /// [isPeriod]), so the line reads "March 2026" and does not repeat its
  /// parent's name.
  final String labelKey;

  /// Whether [labelKey] is a bare period — a date bucket under a group that
  /// is not itself a date.
  final bool isPeriod;

  /// The engine key of the bucket this line *is*, when it is one — what a
  /// drill-down selects. Null on the parent line of a grouping split by
  /// period, which spans several buckets and is none of them.
  final String? drillKey;

  final int count;

  /// `{columnId: {currencyId: total}}`, as on [GroupTotals].
  final Map<String, Map<String, Decimal>> totals;
  final bool expanded;
}

/// A row of the report.
class ReportTableRowLine extends ReportTableLine {
  const ReportTableRowLine({required this.row, required super.depth});

  final ReportRow row;
}

/// The id of the parent line that gathers a group's periods. Prefixed with
/// the ASCII record separator so it can never equal an engine key — a group
/// part followed by the unit separator and nothing *is* a real key, the
/// bucket of that group's undated rows.
String reportTableParentId(String groupPart) => '\u001E$groupPart';

/// The lines of the table for [view], with each group in [expanded] opened
/// in place.
///
/// * Not grouped: the rows.
/// * Grouped: a line per group, its rows beneath it when expanded.
/// * Grouped and split by period ([splitByPeriod]): a line per group
///   carrying the sum of its periods; expanded, a line per period; each of
///   those expanded, its rows.
///
/// The engine has already ordered everything — groups by the sort, a
/// group's periods chronologically and together, rows within a bucket by the
/// sort — so this only folds.
List<ReportTableLine> buildReportTableLines(
  ReportView view, {
  Set<String> expanded = const {},
  bool splitByPeriod = false,
}) {
  if (view.groups.isEmpty) {
    return [
      for (final row in view.rows) ReportTableRowLine(row: row, depth: 0),
    ];
  }
  final out = <ReportTableLine>[];
  if (!splitByPeriod) {
    for (final group in view.groups) {
      final open = expanded.contains(group.key);
      out.add(
        ReportTableGroupLine(
          id: group.key,
          labelKey: group.key,
          isPeriod: false,
          drillKey: group.key,
          count: group.count,
          totals: group.numericTotals,
          expanded: open,
          depth: 0,
        ),
      );
      if (open) {
        for (final row in group.rows) {
          out.add(ReportTableRowLine(row: row, depth: 1));
        }
      }
    }
    return out;
  }

  // Split by period: consecutive buckets share a group part.
  var i = 0;
  final groups = view.groups;
  while (i < groups.length) {
    final part = splitReportGroupKey(groups[i].key).$1;
    var j = i;
    while (j < groups.length && splitReportGroupKey(groups[j].key).$1 == part) {
      j++;
    }
    final periods = groups.sublist(i, j);
    final parentId = reportTableParentId(part);
    final parentOpen = expanded.contains(parentId);
    out.add(
      ReportTableGroupLine(
        id: parentId,
        labelKey: part,
        isPeriod: false,
        drillKey: null,
        count: periods.fold(0, (sum, g) => sum + g.count),
        totals: _mergeTotals(periods),
        expanded: parentOpen,
        depth: 0,
      ),
    );
    if (parentOpen) {
      for (final period in periods) {
        final open = expanded.contains(period.key);
        out.add(
          ReportTableGroupLine(
            id: period.key,
            labelKey: splitReportGroupKey(period.key).$2 ?? '',
            isPeriod: true,
            drillKey: period.key,
            count: period.count,
            totals: period.numericTotals,
            expanded: open,
            depth: 1,
          ),
        );
        if (open) {
          for (final row in period.rows) {
            out.add(ReportTableRowLine(row: row, depth: 2));
          }
        }
      }
    }
    i = j;
  }
  return out;
}

/// The per-currency totals of several buckets added together. Safe for a
/// column counted once per record too: a record's rows all share one date,
/// so it falls in exactly one of a group's periods.
Map<String, Map<String, Decimal>> _mergeTotals(List<GroupTotals> groups) {
  if (groups.length == 1) return groups.single.numericTotals;
  final out = <String, Map<String, Decimal>>{};
  for (final group in groups) {
    group.numericTotals.forEach((columnId, perCurrency) {
      final into = out[columnId] ??= {};
      perCurrency.forEach((currency, value) {
        into[currency] = (into[currency] ?? Decimal.zero) + value;
      });
    });
  }
  return out;
}
