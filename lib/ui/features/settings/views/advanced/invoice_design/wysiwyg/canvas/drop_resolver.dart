import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// Where a dragged block would land.
sealed class DropTarget {
  const DropTarget();
}

/// A row of its own at [rowIndex] (0 = above everything).
class DropNewRow extends DropTarget {
  const DropNewRow(this.rowIndex);
  final int rowIndex;

  @override
  bool operator ==(Object other) =>
      other is DropNewRow && other.rowIndex == rowIndex;

  @override
  int get hashCode => rowIndex.hashCode;
}

/// Into an existing row, beside block [anchorId].
class DropBeside extends DropTarget {
  const DropBeside(this.anchorId, {required this.before});
  final String anchorId;
  final bool before;

  @override
  bool operator ==(Object other) =>
      other is DropBeside &&
      other.anchorId == anchorId &&
      other.before == before;

  @override
  int get hashCode => Object.hash(anchorId, before);
}

/// One cell of a row as drawn: a block, or empty space.
class DropCell {
  const DropCell({
    required this.id,
    required this.left,
    required this.right,
    required this.isGap,
  });

  final String id;
  final double left;
  final double right;
  final bool isGap;
}

/// One row as drawn, in the coordinate space of the point given to
/// [resolveDrop].
class DropRow {
  const DropRow({required this.top, required this.bottom, required this.cells});

  final double top;
  final double bottom;
  final List<DropCell> cells;
}

/// A resolved drop: the target, and the bar that shows it.
class ResolvedDrop {
  const ResolvedDrop(this.target, this.indicator);
  final DropTarget target;
  final Rect indicator;
}

/// Decide where a block dragged to [point] would land among [rows].
///
/// The top and bottom [edgeBand] of a row, and the space between rows, mean
/// "a new row here"; the middle of a row means "into this row", at the
/// nearest edge of the block under the pointer — or beside the block next to
/// an empty cell. [canJoin] answers whether a row has room; when it has not,
/// the drop becomes a new row on the nearer side instead of doing nothing.
///
/// [width] is the content width (for the new-row bar) and [thickness] the
/// bar's stroke, both in the same space as [point].
ResolvedDrop resolveDrop({
  required Offset point,
  required List<DropRow> rows,
  required double width,
  required bool Function(String anchorId) canJoin,
  double edgeBand = 14,
  double thickness = 3,
  String? movingId,
}) {
  Rect rowBar(double y) =>
      Rect.fromLTWH(0, y - thickness / 2, width, thickness);

  if (rows.isEmpty) return ResolvedDrop(const DropNewRow(0), rowBar(0));

  double between(int i) {
    // The line a new row at index i would open on.
    if (i <= 0) return rows.first.top - thickness;
    if (i >= rows.length) return rows.last.bottom + thickness;
    return (rows[i - 1].bottom + rows[i].top) / 2;
  }

  ResolvedDrop newRow(int i) => ResolvedDrop(DropNewRow(i), rowBar(between(i)));

  if (point.dy < rows.first.top) return newRow(0);
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    if (point.dy > row.bottom) continue;
    if (point.dy < row.top) return newRow(i); // in the gap above row i
    final band = math.min(edgeBand, (row.bottom - row.top) / 4);
    if (point.dy < row.top + band) return newRow(i);
    if (point.dy > row.bottom - band) return newRow(i + 1);

    final besides = _beside(point.dx, row, movingId);
    if (besides == null || !canJoin(besides.anchor.id)) {
      final mid = (row.top + row.bottom) / 2;
      return newRow(point.dy < mid ? i : i + 1);
    }
    final x = besides.before ? besides.anchor.left : besides.anchor.right;
    return ResolvedDrop(
      DropBeside(besides.anchor.id, before: besides.before),
      Rect.fromLTWH(
        x - thickness / 2,
        row.top,
        thickness,
        row.bottom - row.top,
      ),
    );
  }
  return newRow(rows.length);
}

({DropCell anchor, bool before})? _beside(
  double x,
  DropRow row,
  String? movingId,
) {
  final solid = [
    for (final c in row.cells)
      if (!c.isGap && c.id != movingId) c,
  ];
  if (solid.isEmpty) return null;

  // The cell under the pointer, else the nearest one.
  DropCell? under;
  for (final c in row.cells) {
    if (x >= c.left && x <= c.right) under = c;
  }
  if (under != null && !under.isGap && under.id != movingId) {
    final mid = (under.left + under.right) / 2;
    return (anchor: under, before: x < mid);
  }
  // Over empty space (or the block being moved): beside whichever block is
  // nearer, on the side that faces the pointer.
  DropCell nearest = solid.first;
  var best = double.infinity;
  for (final c in solid) {
    final d = x < c.left
        ? c.left - x
        : x > c.right
        ? x - c.right
        : 0.0;
    if (d < best) {
      best = d;
      nearest = c;
    }
  }
  return (anchor: nearest, before: x < nearest.left);
}
