import 'dart:math' as math;

import 'package:admin/data/models/api/design_api_model.dart';
import 'package:admin/data/models/domain/design.dart';

/// The visual designer's layout model: **rows**.
///
/// The server prints a block design as a stack of rows — blocks sharing one
/// integer `gridPosition.y` sit side by side, each `w/12` of the row wide, and
/// every row is as tall as its content (`docs/invoice-designer.md`). `h` is
/// never read and `x` only orders a row. So the editor does not edit a free
/// grid: it edits rows, through the pure functions here, and writes
/// `gridPosition` back in a shape the server groups the same way.
///
/// Lives in the data layer because `DesignTemplate.toApi()` needs
/// [annotateBlocksAsApi] and `lib/data/**` must not import `lib/ui/**`.

const int kDesignerGridCols = 12;

/// `.flex-row { gap: 10px }` — between the blocks of one row.
const double kDesignerColumnGapPx = 10;

/// `.json-block { margin-bottom: 12px }` — between rows.
const double kDesignerRowGapPx = 12;

/// The blocks of one printed row, left to right.
typedef DesignRow = List<DesignBlock>;

/// The narrowest a block may be made, in columns.
typedef MinWidthOf = int Function(DesignBlock block);

/// Makes the id of a new block of [type].
typedef BlockIdFactory = String Function(String type);

// ── Save-time annotation ────────────────────────────────────────────────

/// Save-time projection of blocks to the API shape. `rowAlign` is what the
/// server's flex row places a block by (auto margins); `rowWidth`, `colStart`
/// and `colSpan` ride along for the other client and are read by nothing.
/// Never stored on the in-memory [DesignBlock] — always derived, so a
/// drag-then-save produces a fresh value.
List<DesignBlockApi> annotateBlocksAsApi(List<DesignBlock> blocks) {
  if (blocks.isEmpty) return const <DesignBlockApi>[];
  return blocks
      .map((b) {
        final p = b.gridPosition;
        return b.toApi().copyWith(
          rowAlign: rowAlignOf(b),
          rowWidth: _widthForCols(p.w),
          colStart: p.x + 1,
          colSpan: p.w,
        );
      })
      .toList(growable: false);
}

/// `left` / `right` / `center`, from where the block sits on the 12 columns:
/// flush left, flush right, or neither.
String rowAlignOf(DesignBlock block) {
  final p = block.gridPosition;
  if (p.w >= kDesignerGridCols) return 'left';
  if (p.x == 0) return 'left';
  if (p.x + p.w == kDesignerGridCols) return 'right';
  return 'center';
}

String _widthForCols(int w) {
  // "33.333333%" style — matches what the React annotator emits.
  final pct = (w / kDesignerGridCols) * 100;
  return '${pct.toStringAsFixed(6)}%';
}

// ── Rows ────────────────────────────────────────────────────────────────

/// Whether [blocks] were arranged on the old free grid in a way that grid
/// drew differently from how they print: two blocks at different heights
/// (`y`) whose spans overlap, side by side. The grid showed those next to
/// each other; the server — and the row canvas — puts each `y` on a row of
/// its own, one above the other.
///
/// A design this builder saved never has it: [blocksFromRows] gives every
/// row its own band.
bool hasFreeGridOverlap(List<DesignBlock> blocks) {
  for (var i = 0; i < blocks.length; i++) {
    final a = blocks[i].gridPosition;
    for (var j = i + 1; j < blocks.length; j++) {
      final b = blocks[j].gridPosition;
      if (a.y == b.y) continue;
      final overlapsInY = a.y < b.y + b.h && b.y < a.y + a.h;
      final apartInX = a.x + a.w <= b.x || b.x + b.w <= a.x;
      if (overlapsInY && apartInX) return true;
    }
  }
  return false;
}

/// [blocks] as the rows the server will print: sorted by `(y, x)` — ties keep
/// their order — with a new row wherever `y` changes.
///
/// Mirrors `JsonToSectionsAdapter::sortBlocksByPosition` +
/// `groupBlocksIntoRows`. It **never merges**: two blocks that looked side by
/// side on the old free grid but differ by one `y` are two rows, because that
/// is how they print.
List<DesignRow> rowsOf(List<DesignBlock> blocks) {
  if (blocks.isEmpty) return const <DesignRow>[];
  final indexed = List<MapEntry<int, DesignBlock>>.generate(
    blocks.length,
    (i) => MapEntry(i, blocks[i]),
  );
  indexed.sort((a, b) {
    final ap = a.value.gridPosition;
    final bp = b.value.gridPosition;
    if (ap.y != bp.y) return ap.y - bp.y;
    if (ap.x != bp.x) return ap.x - bp.x;
    return a.key - b.key;
  });
  final rows = <DesignRow>[];
  int? y;
  for (final entry in indexed) {
    final block = entry.value;
    if (y == null || block.gridPosition.y != y) {
      rows.add(<DesignBlock>[]);
      y = block.gridPosition.y;
    }
    rows.last.add(block);
  }
  return rows;
}

/// [rows] flattened back to blocks, row by row, with `gridPosition.y` and
/// `.h` rewritten: `y` is the running sum of the rows above, `h` the tallest
/// stored `h` in the row (at least 1). `x` and `w` are left as they are.
///
/// That keeps what the server reads — equal `y` within a row, a larger `y`
/// for each row below — and gives the other client's grid a layout with no
/// overlaps to resolve.
List<DesignBlock> blocksFromRows(List<DesignRow> rows) {
  final out = <DesignBlock>[];
  var y = 0;
  for (final row in rows) {
    if (row.isEmpty) continue;
    var span = 1;
    for (final b in row) {
      span = math.max(span, b.gridPosition.h);
    }
    for (final b in row) {
      final p = b.gridPosition;
      out.add(
        p.y == y && p.h == span
            ? b
            : b.copyWith(
                gridPosition: p.copyWith(y: y, h: span),
              ),
      );
    }
    y += span;
  }
  return out;
}

/// Where [id] is: its row and its place in it. Null when it is not on the
/// page.
({int row, int index})? locateBlock(List<DesignRow> rows, String id) {
  for (var r = 0; r < rows.length; r++) {
    for (var i = 0; i < rows[r].length; i++) {
      if (rows[r][i].id == id) return (row: r, index: i);
    }
  }
  return null;
}

// ── Gap cells ───────────────────────────────────────────────────────────

/// Whether [block] is a *gap cell*: empty space in a row, stored as a spacer
/// with no height.
///
/// A row the user has edited always totals twelve columns, with any empty
/// space held by one of these. Leftover space in a flex row is otherwise
/// shared between auto margins, which cannot express "both blocks on the
/// left" and ignores a lone block's width altogether; a row with no leftover
/// has neither problem and prints exactly as drawn.
bool isGapBlock(DesignBlock block) {
  if (block.type != 'spacer') return false;
  final height = block.properties['height'];
  if (height is num) return height == 0;
  if (height is! String) return false;
  final digits = height.trim().toLowerCase().replaceAll('px', '');
  return (double.tryParse(digits) ?? -1) == 0;
}

/// A gap cell [w] columns wide.
DesignBlock newGapBlock(int w, BlockIdFactory newId) => DesignBlock(
  id: newId('spacer'),
  type: 'spacer',
  gridPosition: GridPosition(x: 0, y: 0, w: w, h: 1),
  properties: const <String, dynamic>{'height': '0px'},
);

// ── How a row prints ────────────────────────────────────────────────────

/// One block's horizontal extent within its row, in the unit of the
/// `contentWidth` given to [layoutRow].
class RowSlot {
  const RowSlot({required this.block, required this.left, required this.width});

  final DesignBlock block;
  final double left;
  final double width;

  double get right => left + width;
}

/// Where each block of [row] lands across [contentWidth] — a port of the
/// server's flex row, so the canvas draws a row the user has not touched
/// exactly as it prints.
///
/// A lone block fills the row. Otherwise every block's basis is `w/12` of the
/// width with [columnGap] between neighbours; a row that overflows shrinks
/// each block in proportion (`flex-shrink: 1`), and leftover space is shared
/// equally between the auto margins [rowAlignOf] gives each block.
List<RowSlot> layoutRow(
  DesignRow row,
  double contentWidth, {
  double columnGap = kDesignerColumnGapPx,
}) {
  if (row.isEmpty) return const <RowSlot>[];
  if (row.length == 1) {
    return [RowSlot(block: row.single, left: 0, width: contentWidth)];
  }
  final gaps = columnGap * (row.length - 1);
  final bases = [
    for (final b in row) contentWidth * b.gridPosition.w / kDesignerGridCols,
  ];
  final basisSum = bases.fold<double>(0, (a, b) => a + b);
  final free = contentWidth - gaps - basisSum;

  final widths = List<double>.of(bases);
  var margin = 0.0;
  if (free < 0 && basisSum > 0) {
    for (var i = 0; i < widths.length; i++) {
      widths[i] = math.max(0, bases[i] + free * bases[i] / basisSum);
    }
  } else if (free > 0) {
    var autos = 0;
    for (final b in row) {
      autos += rowAlignOf(b) == 'center' ? 2 : 1;
    }
    margin = free / autos;
  }

  final slots = <RowSlot>[];
  var x = 0.0;
  for (var i = 0; i < row.length; i++) {
    final align = rowAlignOf(row[i]);
    if (align != 'left') x += margin;
    slots.add(RowSlot(block: row[i], left: x, width: widths[i]));
    x += widths[i];
    if (align != 'right') x += margin;
    x += columnGap;
  }
  return slots;
}

// ── Making a row editable ───────────────────────────────────────────────

/// [row] rewritten so it totals twelve columns with every bit of empty space
/// held by a gap cell, and `x` running left to right — the form every edit
/// works on. Returns an empty row when it held nothing but gaps.
///
/// A row that already has that form comes back unchanged. One that does not —
/// a starter layout, or a design from the old free grid — has its leftover
/// columns handed out the way the server's auto margins would, so making a
/// row editable does not move anything on the PDF.
DesignRow explicitRow(DesignRow row, BlockIdFactory newId) {
  final solid = [
    for (final b in row)
      if (!isGapBlock(b)) b,
  ];
  if (solid.isEmpty) return <DesignBlock>[];
  if (row.length == 1) return [_at(row.single, 0, kDesignerGridCols)];

  final total = row.fold<int>(0, (sum, b) => sum + b.gridPosition.w);
  if (total == kDesignerGridCols) return packRow(row);

  // Too wide: shrink in proportion, as the flex row would.
  var cells = List<DesignBlock>.of(row);
  if (total > kDesignerGridCols) {
    final widths = _scaleTo([
      for (final b in cells) b.gridPosition.w,
    ], kDesignerGridCols);
    cells = [
      for (var i = 0; i < cells.length; i++)
        _at(cells[i], cells[i].gridPosition.x, widths[i]),
    ];
    return packRow([
      for (final b in cells)
        if (b.gridPosition.w > 0) b,
    ]);
  }

  // Too narrow: the leftover goes to the auto margins, left to right.
  final leftover = kDesignerGridCols - total;
  final aligns = [for (final b in cells) rowAlignOf(b)];
  var autos = 0;
  for (final a in aligns) {
    autos += a == 'center' ? 2 : 1;
  }
  final base = leftover ~/ autos;
  var extra = leftover % autos;
  int take() {
    final n = base + (extra > 0 ? 1 : 0);
    if (extra > 0) extra--;
    return n;
  }

  final out = <DesignBlock>[];
  for (var i = 0; i < cells.length; i++) {
    if (aligns[i] != 'left') {
      final n = take();
      if (n > 0) out.add(newGapBlock(n, newId));
    }
    out.add(cells[i]);
    if (aligns[i] != 'right') {
      final n = take();
      if (n > 0) out.add(newGapBlock(n, newId));
    }
  }
  return packRow(out);
}

/// Tidy an edited row: adjacent gap cells become one, an empty cell is
/// dropped, a block left alone fills the row, and `x` is rewritten as the
/// running sum of the widths. A row with no block left in it comes back empty.
DesignRow packRow(DesignRow cells) {
  final merged = <DesignBlock>[];
  for (final cell in cells) {
    if (cell.gridPosition.w <= 0) continue;
    if (isGapBlock(cell) && merged.isNotEmpty && isGapBlock(merged.last)) {
      final last = merged.removeLast();
      merged.add(_at(last, 0, last.gridPosition.w + cell.gridPosition.w));
    } else {
      merged.add(cell);
    }
  }
  if (!merged.any((b) => !isGapBlock(b))) return <DesignBlock>[];
  if (merged.length == 1) return [_at(merged.single, 0, kDesignerGridCols)];
  final out = <DesignBlock>[];
  var x = 0;
  for (final cell in merged) {
    out.add(_at(cell, x, cell.gridPosition.w));
    x += cell.gridPosition.w;
  }
  return out;
}

DesignBlock _at(DesignBlock block, int x, int w) {
  final p = block.gridPosition;
  if (p.x == x && p.w == w) return block;
  return block.copyWith(
    gridPosition: p.copyWith(x: x, w: w),
  );
}

/// [widths] scaled to sum to [total], by largest remainder, each at least 1
/// while there is room for that.
List<int> _scaleTo(List<int> widths, int total) {
  final sum = widths.fold<int>(0, (a, b) => a + b);
  if (sum == 0 || widths.isEmpty) return widths;
  final exact = [for (final w in widths) w * total / sum];
  final out = [for (final e in exact) e.floor()];
  if (widths.length <= total) {
    for (var i = 0; i < out.length; i++) {
      if (out[i] < 1) out[i] = 1;
    }
  }
  var diff = total - out.fold<int>(0, (a, b) => a + b);
  final order = List<int>.generate(widths.length, (i) => i)
    ..sort((a, b) {
      final ra = exact[a] - exact[a].floor();
      final rb = exact[b] - exact[b].floor();
      return rb.compareTo(ra);
    });
  var i = 0;
  while (diff > 0) {
    out[order[i % order.length]]++;
    diff--;
    i++;
  }
  // Over by the min-1 bumps: take from the widest.
  while (diff < 0) {
    var widest = 0;
    for (var j = 1; j < out.length; j++) {
      if (out[j] > out[widest]) widest = j;
    }
    if (out[widest] <= 1) break;
    out[widest]--;
    diff++;
  }
  return out;
}

// ── Editing rows ────────────────────────────────────────────────────────

/// [rows] with [block] alone in a new row at [rowIndex] (0 = above
/// everything, `rows.length` = below).
List<DesignRow> withNewRow(
  List<DesignRow> rows,
  int rowIndex,
  DesignBlock block,
) {
  final out = List<DesignRow>.of(rows);
  out.insert(rowIndex.clamp(0, rows.length), [
    _at(block, 0, kDesignerGridCols),
  ]);
  return out;
}

/// [rows] with [block] placed into row [rowIndex] at [cellIndex] — an index
/// into that row *as [explicitRow] returns it*. The block asks for its own
/// `gridPosition.w`; the columns come first from gap cells, nearest first,
/// then from the widest blocks down to their minimums, and last from the
/// block's own request. Null when even its minimum will not fit.
List<DesignRow>? withBlockInRow(
  List<DesignRow> rows,
  int rowIndex,
  int cellIndex,
  DesignBlock block, {
  required MinWidthOf minWidthOf,
  required BlockIdFactory newId,
}) {
  if (rowIndex < 0 || rowIndex >= rows.length) return null;
  final cells = explicitRow(rows[rowIndex], newId);
  if (cells.isEmpty) return withNewRow(rows, rowIndex, block);
  final fitted = _fitInto(cells, cellIndex, block, minWidthOf);
  if (fitted == null) return null;
  final out = List<DesignRow>.of(rows);
  out[rowIndex] = fitted;
  return out;
}

/// Whether [block] could be placed beside the blocks of [row] at all.
bool canJoinRow(
  DesignRow row,
  DesignBlock block, {
  required MinWidthOf minWidthOf,
  required BlockIdFactory newId,
}) {
  final cells = explicitRow(row, newId);
  if (cells.isEmpty) return true;
  return _fitInto(cells, cells.length, block, minWidthOf) != null;
}

DesignRow? _fitInto(
  DesignRow cells,
  int cellIndex,
  DesignBlock block,
  MinWidthOf minWidthOf,
) {
  final at = cellIndex.clamp(0, cells.length);
  final minIncoming = math.max(1, minWidthOf(block));
  var want = block.gridPosition.w.clamp(minIncoming, kDesignerGridCols);
  final widths = [for (final c in cells) c.gridPosition.w];
  // How far a cell is from the insertion point, in cells.
  int distance(int i) => i < at ? at - 1 - i : i - at;
  var need = want;

  // 1. Gap cells, nearest first, all the way to nothing.
  final gaps = [
    for (var i = 0; i < cells.length; i++)
      if (isGapBlock(cells[i])) i,
  ]..sort((a, b) => distance(a).compareTo(distance(b)));
  for (final i in gaps) {
    if (need == 0) break;
    final given = math.min(need, widths[i]);
    widths[i] -= given;
    need -= given;
  }

  // 2. Blocks, widest first, a column at a time, never below their minimum.
  while (need > 0) {
    var donor = -1;
    for (var i = 0; i < cells.length; i++) {
      if (isGapBlock(cells[i])) continue;
      if (widths[i] <= math.max(1, minWidthOf(cells[i]))) continue;
      if (donor == -1 ||
          widths[i] > widths[donor] ||
          (widths[i] == widths[donor] && distance(i) < distance(donor))) {
        donor = i;
      }
    }
    if (donor == -1) break;
    widths[donor]--;
    need--;
  }

  // 3. The incoming block settles for less.
  want -= need;
  if (want < minIncoming) return null;

  final out = <DesignBlock>[];
  for (var i = 0; i <= cells.length; i++) {
    if (i == at) out.add(_at(block, 0, want));
    if (i < cells.length) out.add(_at(cells[i], 0, widths[i]));
  }
  return packRow(out);
}

/// [rows] without block [id]. In a row it shared, a gap cell takes its place
/// so the others stay where they were; a row it had to itself goes with it.
List<DesignRow> withoutBlock(
  List<DesignRow> rows,
  String id, {
  required BlockIdFactory newId,
}) {
  final at = locateBlock(rows, id);
  if (at == null) return rows;
  final out = List<DesignRow>.of(rows);
  final cells = explicitRow(rows[at.row], newId);
  final packed = packRow([
    for (final c in cells)
      if (c.id == id) newGapBlock(c.gridPosition.w, newId) else c,
  ]);
  if (packed.isEmpty) {
    out.removeAt(at.row);
  } else {
    out[at.row] = packed;
  }
  return out;
}

/// [rows] with row [from] moved so it ends up at index [to] of the result.
List<DesignRow> withRowMoved(List<DesignRow> rows, int from, int to) {
  if (from < 0 || from >= rows.length) return rows;
  final out = List<DesignRow>.of(rows);
  final row = out.removeAt(from);
  out.insert(to.clamp(0, out.length), row);
  return out;
}

/// [rows] with one boundary of row [rowIndex] moved [deltaCols] columns to
/// the right (negative: left).
///
/// [boundary] counts the edges of the row *as [explicitRow] returns it*: `0`
/// is the row's left edge, `n` its right edge, and `i` the line between cells
/// `i - 1` and `i`. The cell the boundary moves into gives up the columns; a
/// block stops at its minimum, a gap cell at nothing. At an outer edge the
/// columns go to a new gap cell — that is how a block is made narrower than
/// its row.
List<DesignRow> withBoundaryMoved(
  List<DesignRow> rows,
  int rowIndex,
  int boundary,
  int deltaCols, {
  required MinWidthOf minWidthOf,
  required BlockIdFactory newId,
}) {
  if (rowIndex < 0 || rowIndex >= rows.length || deltaCols == 0) return rows;
  final cells = explicitRow(rows[rowIndex], newId);
  if (cells.isEmpty || boundary < 0 || boundary > cells.length) return rows;

  int floorOf(DesignBlock c) => isGapBlock(c) ? 0 : math.max(1, minWidthOf(c));
  final widths = [for (final c in cells) c.gridPosition.w];
  final left = boundary - 1; // grows when the boundary moves right
  final right = boundary; // grows when it moves left
  var leading = 0;
  var trailing = 0;

  if (deltaCols > 0) {
    if (right >= cells.length) return rows; // nothing to the right to take
    final give = math.min(deltaCols, widths[right] - floorOf(cells[right]));
    if (give <= 0) return rows;
    widths[right] -= give;
    if (left >= 0) {
      widths[left] += give;
    } else {
      leading = give;
    }
  } else {
    if (left < 0) return rows;
    final give = math.min(-deltaCols, widths[left] - floorOf(cells[left]));
    if (give <= 0) return rows;
    widths[left] -= give;
    if (right < cells.length) {
      widths[right] += give;
    } else {
      trailing = give;
    }
  }

  final next = packRow([
    if (leading > 0) newGapBlock(leading, newId),
    for (var i = 0; i < cells.length; i++) _at(cells[i], 0, widths[i]),
    if (trailing > 0) newGapBlock(trailing, newId),
  ]);
  final out = List<DesignRow>.of(rows);
  out[rowIndex] = next;
  return out;
}

/// Where the one block of a row sits when the row has room to spare.
enum RowPosition { left, center, right }

/// [rows] with block [id] moved to the [position] of its row. Only for a
/// block that shares its row with nothing but gap cells; otherwise, and for a
/// block that fills its row, [rows] comes back unchanged.
List<DesignRow> withBlockPositioned(
  List<DesignRow> rows,
  String id,
  RowPosition position, {
  required BlockIdFactory newId,
}) {
  final at = locateBlock(rows, id);
  if (at == null) return rows;
  final cells = explicitRow(rows[at.row], newId);
  final solid = [
    for (final c in cells)
      if (!isGapBlock(c)) c,
  ];
  if (solid.length != 1) return rows;
  final block = solid.single;
  final spare = kDesignerGridCols - block.gridPosition.w;
  if (spare <= 0) return rows;
  final before = switch (position) {
    RowPosition.left => 0,
    RowPosition.center => spare ~/ 2,
    RowPosition.right => spare,
  };
  final after = spare - before;
  final out = List<DesignRow>.of(rows);
  out[at.row] = packRow([
    if (before > 0) newGapBlock(before, newId),
    block,
    if (after > 0) newGapBlock(after, newId),
  ]);
  return out;
}

/// Where a lone-with-gaps block currently sits, or null when [id] shares its
/// row with another block or fills it.
RowPosition? positionInRowOf(List<DesignRow> rows, String id) {
  final at = locateBlock(rows, id);
  if (at == null) return null;
  final row = rows[at.row];
  final solid = [
    for (final c in row)
      if (!isGapBlock(c)) c,
  ];
  if (solid.length != 1 || row.length == 1) return null;
  final total = row.fold<int>(0, (sum, b) => sum + b.gridPosition.w);
  if (total != kDesignerGridCols) return null;
  final index = row.indexWhere((c) => c.id == id);
  if (index == 0) return RowPosition.left;
  if (index == row.length - 1) return RowPosition.right;
  return RowPosition.center;
}

/// [rows] with the gap cells of row [rowIndex] removed and their columns
/// shared out between its blocks in proportion.
List<DesignRow> withoutGaps(
  List<DesignRow> rows,
  int rowIndex, {
  required BlockIdFactory newId,
}) {
  if (rowIndex < 0 || rowIndex >= rows.length) return rows;
  final cells = explicitRow(rows[rowIndex], newId);
  final solid = [
    for (final c in cells)
      if (!isGapBlock(c)) c,
  ];
  if (solid.isEmpty || solid.length == cells.length) return rows;
  final widths = _scaleTo([
    for (final b in solid) b.gridPosition.w,
  ], kDesignerGridCols);
  final out = List<DesignRow>.of(rows);
  out[rowIndex] = packRow([
    for (var i = 0; i < solid.length; i++) _at(solid[i], 0, widths[i]),
  ]);
  return out;
}

/// Whether row [row] has any gap cell — i.e. "Remove gaps" would do something.
bool rowHasGaps(DesignRow row) => row.length > 1 && row.any(isGapBlock);
