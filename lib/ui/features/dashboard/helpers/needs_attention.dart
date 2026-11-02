// The band's buckets (what is past due, due soon, expiring) live in the
// domain so the home-screen widget snapshot can share them without importing
// `lib/ui`; only the band's column layout stays here.
export 'package:admin/domain/dashboard/needs_attention.dart';

/// The narrowest a column of the side-by-side band may be — the width at
/// which a stacked row still holds a number, a client and an amount on its
/// first line.
const double kAttentionMinColumnWidth = 300;

/// The most columns the band lays out, however wide it is. Three is the
/// number of lists; more would only stretch rows again.
const int kAttentionMaxColumns = 3;

/// How many equal columns a band [width] wide has room for.
int attentionMaxSlots(double width) {
  if (!width.isFinite || width <= 0) return 0;
  return (width / kAttentionMinColumnWidth).floor().clamp(
    0,
    kAttentionMaxColumns,
  );
}

/// How many of the band's columns each list takes, in list order — or empty
/// when the lists do not fit side by side and the band falls back to tabs.
///
/// [counts] is the number of rows each non-empty list has in hand.
///
/// **Columns stay narrow, and a list with more rows than fit takes more of
/// them.** Every list starts with one column; a spare column goes to whichever
/// list is tallest for the columns it has (the earliest on a tie), as long as
/// it has a row to put there. So one list of six runs three columns of two,
/// "4 past due + 6 quotes" is one column and two, and three lists take one
/// each. A column that no list can use is left empty rather than shared out:
/// widening the others is what put the Remind button 700 px from the name it
/// acted on.
///
/// Empty (tabs) when there are more lists than columns, or room for fewer
/// than two columns.
List<int> attentionSlots({required double width, required List<int> counts}) {
  final lists = counts.length;
  final max = attentionMaxSlots(width);
  if (lists == 0 || max < 2 || lists > max) return const [];
  final slots = List<int>.filled(lists, 1);
  for (var spare = max - lists; spare > 0; spare--) {
    var pick = -1;
    var tallest = 0.0;
    for (var i = 0; i < lists; i++) {
      // A list needs one more row than it has columns to use another.
      if (counts[i] <= slots[i]) continue;
      final height = counts[i] / slots[i];
      if (height > tallest) {
        tallest = height;
        pick = i;
      }
    }
    if (pick < 0) break;
    slots[pick]++;
  }
  return slots;
}

/// How [rows] rows of one list are laid out over [columns] columns: filled
/// column by column (the most urgent stay on the left) and balanced, so three
/// rows over two columns are two and one — not three beside an empty column.
List<int> attentionFlow(int rows, int columns) {
  if (rows <= 0 || columns <= 0) return const [];
  final used = rows < columns ? rows : columns;
  final base = rows ~/ used;
  final extra = rows % used;
  return [for (var i = 0; i < used; i++) base + (i < extra ? 1 : 0)];
}
