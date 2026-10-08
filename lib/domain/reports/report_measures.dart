import 'package:decimal/decimal.dart';

import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';

/// Identifier of the synthetic "how many rows" measure.
///
/// Not a preview column — [GroupTotals.count] already holds the number.
/// Named for the server's own key for the same figure (`groupedReturnJson`
/// appends a `group.count` column), which a preview can never carry: the app
/// does its grouping locally and never sends `group_by` on preview.
const String kReportCountSeriesId = 'group.count';

/// The columns of [preview] that are figures — the ones a report can
/// headline, chart and total. A column that is not totalled (a rate, a unit
/// price) is not one: there is no "tax rate by month".
///
/// Read from the preview, not from the visible set, so hiding a column from
/// the table does not blank the chart that plots it.
List<ReportColumn> reportMeasureColumns(ReportPreview? preview) {
  if (preview == null) return const [];
  return [
    for (final column in preview.columns)
      if (column.effectiveAggregation != ReportAggregation.none) column,
  ];
}

/// The currencies the rows of [view] are in, most rows first. Empty for a
/// report that names no currency at all.
List<String> reportCurrencies(ReportView view) {
  final entries =
      [
        for (final e in view.rowCountByCurrency.entries)
          if (e.key.isNotEmpty) e,
      ]..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
  return [for (final e in entries) e.key];
}

/// The currency [view]'s figures are read in — [resolveViewCurrency] over
/// its rows. Equal to [ReportView.currencyId] when [chosen] and
/// [companyCurrencyId] are the ones the view was computed with; kept for a
/// caller holding a view it did not compute.
String resolveReportCurrency(
  ReportView view, {
  String? chosen,
  String? companyCurrencyId,
}) => resolveViewCurrency(
  view.rowCountByCurrency,
  chosen: chosen,
  companyCurrencyId: companyCurrencyId,
);

/// One figure out of a `{columnId: {currencyId: total}}` map: [measureId] in
/// [currencyId]. Null when there is none — which is not zero.
Decimal? reportTotal(
  Map<String, Map<String, Decimal>> totals,
  String measureId,
  String currencyId,
) => totals[measureId]?[currencyId];

/// A group's figure for [measureId]: its row count for the count measure,
/// otherwise its total of that column in [currencyId].
///
/// **The count is of every row, whatever its currency.** A count is not an
/// amount: nothing about "214 invoices" is added across currencies that
/// should not be, and scoping it left the figure above the table (174) at
/// odds with the table's own row count (214) on any result that held two.
Decimal? reportGroupValue(
  GroupTotals group,
  String measureId,
  String currencyId,
) {
  if (measureId == kReportCountSeriesId) return Decimal.fromInt(group.count);
  return group.numericTotals[measureId]?[currencyId];
}

/// A row's own value for [measureId] — its cell in that column — or null
/// when the cell holds no quantity.
Decimal? reportRowValue(ReportRow row, int cellIndex) {
  if (cellIndex < 0 || cellIndex >= row.cells.length) return null;
  final cell = row.cells[cellIndex];
  if (cell is ReportNumberCell) return cell.value;
  if (cell is ReportDurationCell) {
    final seconds = cell.seconds;
    return seconds == null ? null : Decimal.fromInt(seconds);
  }
  return null;
}
