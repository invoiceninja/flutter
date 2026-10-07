import 'package:admin/data/repositories/dashboard_repository.dart';

/// One row of the wide dashboard's panel grid: a pair of panels side by side,
/// one panel across the whole row, or — only when nothing else is possible —
/// one panel in half a row.
class PanelRow {
  const PanelRow.pair(this.first, String this.second) : spans = false;

  const PanelRow.span(this.first) : second = null, spans = true;

  const PanelRow.half(this.first) : second = null, spans = false;

  /// The row's first (or only) panel.
  final String first;

  /// The panel beside [first], or null when the row holds one panel.
  final String? second;

  /// Whether [first] takes the whole row. False for a pair, and for the lone
  /// half-width panel a [PanelRow.half] is.
  final bool spans;

  @override
  bool operator ==(Object other) =>
      other is PanelRow &&
      other.first == first &&
      other.second == second &&
      other.spans == spans;

  @override
  int get hashCode => Object.hash(first, second, spans);

  @override
  String toString() => second != null
      ? 'pair($first, $second)'
      : (spans ? 'span($first)' : 'half($first)');
}

/// Lays [kinds] — the panels to show, in the user's order — out as rows with
/// no empty half row.
///
/// The grid used to fill two columns in order, so an odd number of panels left
/// half a row blank, and which panel sat beside the gap changed every time one
/// emptied out and was hidden. The rules, in order:
///
///  * **Invoices & Quotes always takes a whole row.** Its tab strip and its
///    wider rows are the one thing here that gains from the width, and a fixed
///    width means it never flips between half and full as its neighbours come
///    and go.
///  * **Everything else pairs up in order**, within the run of panels between
///    two full-width rows.
///  * **A run with an odd count gives one table the whole row**, chosen so the
///    rest still pair in order: the last panel at an even position in the run
///    that is not the calendar.
///  * **The task calendar is never stretched** — its month grid is capped at
///    440 px, so across a whole row it is an island — and never left alone
///    beside a gap unless it is the only panel in its run.
///
/// With one column every panel is its own row.
List<PanelRow> layoutPanelRows(List<String> kinds, {required int columns}) {
  if (columns <= 1) {
    return [for (final k in kinds) PanelRow.span(k)];
  }
  final rows = <PanelRow>[];
  var run = <String>[];

  void flushRun() {
    if (run.isEmpty) return;
    rows.addAll(_layoutRun(run));
    run = <String>[];
  }

  for (final kind in kinds) {
    if (kind == DashboardKind.invoicesAndQuotes) {
      flushRun();
      rows.add(PanelRow.span(kind));
    } else {
      run.add(kind);
    }
  }
  flushRun();
  return rows;
}

List<PanelRow> _layoutRun(List<String> run) {
  // Which panel, if any, takes a whole row so that the others pair.
  var spanAt = -1;
  if (run.length.isOdd) {
    for (var i = run.length - 1; i >= 0; i -= 2) {
      if (run[i] != DashboardKind.taskCalendar) {
        spanAt = i;
        break;
      }
    }
  }
  final rows = <PanelRow>[];
  var i = 0;
  while (i < run.length) {
    if (i == spanAt) {
      rows.add(PanelRow.span(run[i]));
      i += 1;
    } else if (i + 1 < run.length) {
      rows.add(PanelRow.pair(run[i], run[i + 1]));
      i += 2;
    } else {
      // Only reachable for a run that is the calendar on its own.
      rows.add(PanelRow.half(run[i]));
      i += 1;
    }
  }
  return rows;
}
