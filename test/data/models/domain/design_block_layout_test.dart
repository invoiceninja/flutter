import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/design_block_layout.dart';

DesignBlock _b(
  String id, {
  int x = 0,
  int y = 0,
  int w = 12,
  int h = 2,
  String type = 'text',
  Map<String, dynamic> properties = const {'content': 'x'},
}) => DesignBlock(
  id: id,
  type: type,
  gridPosition: GridPosition(x: x, y: y, w: w, h: h),
  properties: properties,
);

DesignBlock _gap(String id, {int x = 0, int y = 0, int w = 1}) => _b(
  id,
  x: x,
  y: y,
  w: w,
  h: 1,
  type: 'spacer',
  properties: const {'height': '0px'},
);

int _min(DesignBlock b) => b.type == 'table' ? 6 : 2;

/// `(id, x, w)` per cell, with gap cells shown as `gap`.
List<String> _shape(DesignRow row) => [
  for (final b in row)
    '${isGapBlock(b) ? 'gap' : b.id}@${b.gridPosition.x}+${b.gridPosition.w}',
];

void main() {
  var counter = 0;
  String newId(String type) => '$type-new${counter++}';
  setUp(() => counter = 0);

  group('rowsOf — the server\'s grouping', () {
    // JsonToSectionsAdapter: sort by (y, x), then a new row whenever y
    // changes. Fixtures are derived by hand from that code.
    test('same y is one row, ordered by x', () {
      final rows = rowsOf([
        _b('details', x: 6, y: 0, w: 6),
        _b('logo', x: 0, y: 0, w: 4),
        _b('table', y: 8),
      ]);
      expect(rows.map((r) => r.map((b) => b.id).toList()), [
        ['logo', 'details'],
        ['table'],
      ]);
    });

    test('blocks one y apart are two rows, however they looked', () {
      // Side by side on the old free grid; stacked on the PDF.
      final rows = rowsOf([
        _b('a', x: 0, y: 4, w: 6, h: 4),
        _b('b', x: 6, y: 5, w: 6, h: 4),
      ]);
      expect(rows, hasLength(2));
    });

    test('a tie on (y, x) keeps the list order', () {
      final rows = rowsOf([_b('first', y: 2), _b('second', y: 2)]);
      expect(rows.single.map((b) => b.id), ['first', 'second']);
    });

    test('no blocks, no rows', () => expect(rowsOf(const []), isEmpty));
  });

  group('blocksFromRows — what is written back', () {
    final rows = [
      [
        _b('logo', x: 0, y: 3, w: 4, h: 4),
        _b('details', x: 6, y: 3, w: 6, h: 5),
      ],
      [_b('table', y: 40, h: 8)],
      [_b('footer', y: 41, h: 0)],
    ];

    test('y is the running sum of the rows above; h is the row\'s tallest', () {
      final blocks = blocksFromRows(rows);
      expect(
        [
          for (final b in blocks)
            '${b.id}:${b.gridPosition.y}/${b.gridPosition.h}',
        ],
        ['logo:0/5', 'details:0/5', 'table:5/8', 'footer:13/1'],
      );
    });

    test('x and w are not touched', () {
      final blocks = blocksFromRows(rows);
      expect(blocks.first.gridPosition.x, 0);
      expect(blocks.first.gridPosition.w, 4);
      expect(blocks[1].gridPosition.x, 6);
    });

    test('round-trips through rowsOf, and is idempotent', () {
      final once = blocksFromRows(rows);
      final regrouped = rowsOf(once);
      expect(regrouped.map((r) => r.map((b) => b.id).toList()), [
        ['logo', 'details'],
        ['table'],
        ['footer'],
      ]);
      expect(blocksFromRows(regrouped), once);
    });

    test('the row alignment the server is sent is unchanged by it', () {
      final before = annotateBlocksAsApi([for (final r in rows) ...r]);
      final after = annotateBlocksAsApi(blocksFromRows(rows));
      expect(
        [for (final b in after) b.rowAlign],
        [for (final b in before) b.rowAlign],
      );
    });

    test('the other client\'s grid opens it without overlaps', () {
      // React hydrates a design with no `builderGridVersion` through its
      // legacy metrics: y' = round(76y/14), h' = ceil((76h - 12)/14).
      final blocks = blocksFromRows([
        for (var h = 1; h <= 9; h++) [_b('r$h', h: h)],
      ]);
      for (var i = 0; i + 1 < blocks.length; i++) {
        final p = blocks[i].gridPosition;
        final top = (76 * p.y / 14).round();
        final height = ((76 * p.h - 12) / 14).ceil();
        final nextTop = (76 * blocks[i + 1].gridPosition.y / 14).round();
        expect(top + height, lessThanOrEqualTo(nextTop), reason: 'row $i');
      }
    });
  });

  group('isGapBlock', () {
    test('a spacer with no height', () {
      expect(isGapBlock(_gap('g')), isTrue);
      expect(
        isGapBlock(_b('s', type: 'spacer', properties: const {'height': '0'})),
        isTrue,
      );
    });

    test('not a spacer that has one, nor any other block', () {
      expect(
        isGapBlock(
          _b('s', type: 'spacer', properties: const {'height': '40px'}),
        ),
        isFalse,
      );
      expect(
        isGapBlock(_b('s', type: 'spacer', properties: const {})),
        isFalse,
      );
      expect(isGapBlock(_b('t', properties: const {'height': '0px'})), isFalse);
    });
  });

  group('layoutRow — a port of the flex row', () {
    test('a block alone fills the row, whatever its w', () {
      final slot = layoutRow([_b('a', x: 6, w: 6)], 1000).single;
      expect(slot.left, 0);
      expect(slot.width, 1000);
    });

    test('a full row shrinks each block by its share of the gaps', () {
      // Probed: [spacer w6][text w6] printed as two 50% columns.
      final slots = layoutRow([_b('a', x: 0, w: 6), _b('b', x: 6, w: 6)], 1000);
      expect(slots[0].width, 495);
      expect(slots[1].left, 505);
      expect(slots[1].right, 1000);
    });

    test('leftover goes between a flush-left and a flush-right block', () {
      final slots = layoutRow([_b('a', x: 0, w: 4), _b('b', x: 6, w: 6)], 1000);
      expect(slots[0].left, 0);
      expect(slots[1].right, closeTo(1000, 0.001));
      expect(slots[1].left, closeTo(500, 0.001));
    });

    test('a block that touches neither edge is centred in its share', () {
      // left + center: three auto margins share (1000 - 10 - 500) = 490.
      final slots = layoutRow([_b('a', x: 0, w: 3), _b('b', x: 3, w: 3)], 1000);
      expect(slots[1].left, closeTo(250 + 490 / 3 + 10 + 490 / 3, 0.001));
    });
  });

  group('explicitRow — every bit of space accounted for', () {
    test('a lone block fills the row', () {
      expect(_shape(explicitRow([_b('a', x: 6, w: 6)], newId)), ['a@0+12']);
    });

    test('a row that already totals twelve only has its x rewritten', () {
      final row = explicitRow([
        _b('a', x: 0, w: 5),
        _b('b', x: 9, w: 7),
      ], newId);
      expect(_shape(row), ['a@0+5', 'b@5+7']);
    });

    test('leftover becomes the gap the auto margins would leave', () {
      final row = explicitRow([
        _b('logo', x: 0, w: 4),
        _b('d', x: 6, w: 6),
      ], newId);
      expect(_shape(row), ['logo@0+4', 'gap@4+2', 'd@6+6']);
    });

    test('…shared between three margins when a block is in the middle', () {
      final row = explicitRow([
        _b('a', x: 0, w: 3),
        _b('b', x: 3, w: 3),
      ], newId);
      expect(_shape(row), ['a@0+3', 'gap@3+4', 'b@7+3', 'gap@10+2']);
    });

    test('a row wider than twelve is scaled down', () {
      final row = explicitRow([
        _b('a', x: 0, w: 8),
        _b('b', x: 8, w: 8),
      ], newId);
      expect(_shape(row), ['a@0+6', 'b@6+6']);
    });

    test('a row of nothing but gaps is no row', () {
      expect(explicitRow([_gap('g', w: 12)], newId), isEmpty);
      expect(
        explicitRow([_gap('g', w: 6), _gap('h', x: 6, w: 6)], newId),
        isEmpty,
      );
    });
  });

  group('packRow', () {
    test('adjacent gaps merge and x runs left to right', () {
      final row = packRow([_gap('g1', w: 2), _gap('g2', w: 3), _b('a', w: 7)]);
      expect(_shape(row), ['gap@0+5', 'a@5+7']);
      expect(row.first.id, 'g1');
    });

    test('a block left alone fills the row', () {
      expect(_shape(packRow([_b('a', w: 5)])), ['a@0+12']);
    });
  });

  group('withBlockInRow', () {
    final rows = [
      [_b('a', x: 0, w: 4), _gap('g', x: 4, w: 4), _b('b', x: 8, w: 4)],
    ];

    test('takes its columns from a gap first', () {
      final out = withBlockInRow(
        rows,
        0,
        1,
        _b('new', w: 3),
        minWidthOf: _min,
        newId: newId,
      )!;
      expect(_shape(out.single), ['a@0+4', 'new@4+3', 'gap@7+1', 'b@8+4']);
    });

    test('then from the widest blocks, down to their minimum', () {
      final full = [
        [_b('a', x: 0, w: 8), _b('b', x: 8, w: 4)],
      ];
      final out = withBlockInRow(
        full,
        0,
        2,
        _b('new', w: 4),
        minWidthOf: _min,
        newId: newId,
      )!;
      // Always from whichever is widest at that moment: 8/4 ends even.
      expect(_shape(out.single), ['a@0+4', 'b@4+4', 'new@8+4']);
    });

    test('and settles for less than it asked when the row is tight', () {
      final tight = [
        [_b('t', x: 0, w: 8, type: 'table'), _b('b', x: 8, w: 4)],
      ];
      final out = withBlockInRow(
        tight,
        0,
        2,
        _b('new', w: 6),
        minWidthOf: _min,
        newId: newId,
      )!;
      // table min 6, b min 2: four columns can be found, not six.
      expect(_shape(out.single), ['t@0+6', 'b@6+2', 'new@8+4']);
    });

    test('null when even its minimum will not fit', () {
      final packed = [
        [for (var i = 0; i < 6; i++) _b('b$i', x: i * 2, w: 2)],
      ];
      expect(
        withBlockInRow(
          packed,
          0,
          0,
          _b('new', w: 4),
          minWidthOf: _min,
          newId: newId,
        ),
        isNull,
      );
      expect(
        canJoinRow(packed.single, _b('new'), minWidthOf: _min, newId: newId),
        isFalse,
      );
    });

    test('joining a lone block splits its row', () {
      final lone = [
        [_b('a', x: 3, w: 6)],
      ];
      final out = withBlockInRow(
        lone,
        0,
        1,
        _b('new', w: 4),
        minWidthOf: _min,
        newId: newId,
      )!;
      expect(_shape(out.single), ['a@0+8', 'new@8+4']);
    });
  });

  group('withoutBlock', () {
    test('a gap takes its place, so the others do not move', () {
      final out = withoutBlock(
        [
          [_b('a', x: 0, w: 4), _b('b', x: 4, w: 4), _b('c', x: 8, w: 4)],
        ],
        'b',
        newId: newId,
      );
      expect(_shape(out.single), ['a@0+4', 'gap@4+4', 'c@8+4']);
    });

    test('a row it had to itself goes with it', () {
      final out = withoutBlock(
        [
          [_b('a')],
          [_b('b', y: 2)],
        ],
        'a',
        newId: newId,
      );
      expect(out.single.single.id, 'b');
    });

    test('so does a row left holding only gaps', () {
      final out = withoutBlock(
        [
          [_gap('g', w: 6), _b('a', x: 6, w: 6)],
        ],
        'a',
        newId: newId,
      );
      expect(out, isEmpty);
    });
  });

  group('withBoundaryMoved', () {
    final row = [_b('a', x: 0, w: 6), _b('b', x: 6, w: 6)];

    DesignRow move(DesignRow row, int boundary, int delta) => withBoundaryMoved(
      [row],
      0,
      boundary,
      delta,
      minWidthOf: _min,
      newId: newId,
    ).single;

    test('an inner boundary trades columns between its neighbours', () {
      expect(_shape(move(row, 1, 2)), ['a@0+8', 'b@8+4']);
      expect(_shape(move(row, 1, -3)), ['a@0+3', 'b@3+9']);
    });

    test('a block stops at its minimum', () {
      expect(_shape(move(row, 1, 9)), ['a@0+10', 'b@10+2']);
    });

    test('the right edge pulled in leaves a gap behind it', () {
      expect(_shape(move(row, 2, -2)), ['a@0+6', 'b@6+4', 'gap@10+2']);
    });

    test('the left edge pushed in leaves one in front', () {
      expect(_shape(move(row, 0, 3)), ['gap@0+3', 'a@3+3', 'b@6+6']);
    });

    test('an outer edge cannot be pushed outwards', () {
      expect(_shape(move(row, 0, -2)), _shape(row));
      expect(_shape(move(row, 2, 2)), _shape(row));
    });

    test('a gap squeezed to nothing disappears', () {
      final gapped = [
        _b('a', x: 0, w: 6),
        _gap('g', x: 6, w: 2),
        _b('b', x: 8, w: 4),
      ];
      expect(_shape(move(gapped, 1, 2)), ['a@0+8', 'b@8+4']);
    });

    test('a lone block can be made narrower than its row', () {
      // The server ignores a lone block's width; with a gap beside it the
      // row has two cells and the width is real.
      expect(_shape(move([_b('a', x: 0, w: 12)], 1, -6)), ['a@0+6', 'gap@6+6']);
    });
  });

  group('withBlockPositioned', () {
    final rows = [
      [_b('a', x: 0, w: 4), _gap('g', x: 4, w: 8)],
    ];

    DesignRow at(RowPosition p) =>
        withBlockPositioned(rows, 'a', p, newId: newId).single;

    test('left, centre, right', () {
      expect(_shape(at(RowPosition.left)), ['a@0+4', 'gap@4+8']);
      expect(_shape(at(RowPosition.center)), ['gap@0+4', 'a@4+4', 'gap@8+4']);
      expect(_shape(at(RowPosition.right)), ['gap@0+8', 'a@8+4']);
    });

    test('and reads back', () {
      expect(positionInRowOf(rows, 'a'), RowPosition.left);
      expect(
        positionInRowOf([at(RowPosition.center)], 'a'),
        RowPosition.center,
      );
      expect(positionInRowOf([at(RowPosition.right)], 'a'), RowPosition.right);
    });

    test('not offered for a block that fills its row or shares it', () {
      expect(
        positionInRowOf([
          [_b('a')],
        ], 'a'),
        isNull,
      );
      final shared = [
        [_b('a', x: 0, w: 6), _b('b', x: 6, w: 6)],
      ];
      expect(positionInRowOf(shared, 'a'), isNull);
      expect(
        withBlockPositioned(shared, 'a', RowPosition.right, newId: newId),
        shared,
      );
    });
  });

  group('withoutGaps', () {
    test('the blocks share the freed columns in proportion', () {
      final rows = [
        [_b('a', x: 0, w: 2), _gap('g', x: 2, w: 6), _b('b', x: 8, w: 4)],
      ];
      expect(rowHasGaps(rows.single), isTrue);
      final out = withoutGaps(rows, 0, newId: newId);
      expect(_shape(out.single), ['a@0+4', 'b@4+8']);
      expect(rowHasGaps(out.single), isFalse);
    });
  });

  group('withNewRow / withRowMoved', () {
    final rows = [
      [_b('a')],
      [_b('b')],
      [_b('c')],
    ];
    List<String> ids(List<DesignRow> r) => [for (final row in r) row.first.id];

    test('a new row holds its block alone and full width', () {
      final out = withNewRow(rows, 1, _b('new', x: 4, w: 3));
      expect(ids(out), ['a', 'new', 'b', 'c']);
      expect(_shape(out[1]), ['new@0+12']);
    });

    test('a row moves to the index it should end up at', () {
      expect(ids(withRowMoved(rows, 0, 2)), ['b', 'c', 'a']);
      expect(ids(withRowMoved(rows, 2, 0)), ['c', 'a', 'b']);
    });
  });

  test('every edit leaves its row totalling twelve', () {
    var rows = <DesignRow>[
      [_b('logo', x: 0, w: 4), _b('details', x: 6, w: 6)],
      [_b('table', type: 'table')],
    ];
    rows = withBlockInRow(
      rows,
      0,
      1,
      _b('qr', w: 2),
      minWidthOf: _min,
      newId: newId,
    )!;
    rows = withBoundaryMoved(rows, 0, 1, -1, minWidthOf: _min, newId: newId);
    rows = withoutBlock(rows, 'details', newId: newId);
    rows = withBoundaryMoved(rows, 1, 1, -5, minWidthOf: _min, newId: newId);
    for (final row in rows) {
      expect(
        row.fold<int>(0, (sum, b) => sum + b.gridPosition.w),
        kDesignerGridCols,
        reason: _shape(row).join(' '),
      );
      var x = 0;
      for (final b in row) {
        expect(b.gridPosition.x, x);
        x += b.gridPosition.w;
      }
    }
  });

  group('annotateBlocksAsApi', () {
    test('single block at x=0 is left-aligned', () {
      final out = annotateBlocksAsApi([_b('a', x: 0, y: 0, w: 4, h: 2)]);
      expect(out[0].rowAlign, 'left');
      expect(out[0].colStart, 1);
      expect(out[0].colSpan, 4);
      expect(out[0].rowWidth, '33.333333%');
    });

    test('block touching right edge is right-aligned', () {
      final out = annotateBlocksAsApi([_b('a', x: 8, y: 0, w: 4, h: 2)]);
      expect(out[0].rowAlign, 'right');
      expect(out[0].colStart, 9);
    });

    test('mid-row block is center-aligned', () {
      final out = annotateBlocksAsApi([_b('a', x: 3, y: 0, w: 4, h: 2)]);
      expect(out[0].rowAlign, 'center');
    });

    test('full-width block is left-aligned', () {
      final out = annotateBlocksAsApi([_b('a', x: 0, y: 0, w: 12, h: 2)]);
      expect(out[0].rowAlign, 'left');
      expect(out[0].rowWidth, '100.000000%');
    });

    test('empty input returns empty output (legacy designs)', () {
      expect(annotateBlocksAsApi(const []), isEmpty);
    });

    test('annotated wire JSON carries the four save-time fields', () {
      // jsonEncode flattens nested typed freezed objects to maps, mirroring
      // what the network layer sends.
      final wire =
          jsonDecode(
                jsonEncode(
                  annotateBlocksAsApi([
                    _b(
                      'logo-1',
                      x: 0,
                      y: 0,
                      w: 4,
                      h: 4,
                      type: 't',
                      properties: const {},
                    ),
                  ]).map((b) => b.toJson()).toList(),
                ),
              )
              as List<dynamic>;
      final first = wire.first as Map<String, dynamic>;
      expect(first['id'], 'logo-1');
      expect(first['type'], 't');
      expect(first['gridPosition'], {'x': 0, 'y': 0, 'w': 4, 'h': 4});
      // Always present, even with nothing in it — the server reads it
      // unguarded.
      expect(first['properties'], isEmpty);
      expect(first['rowAlign'], 'left');
      expect(first['rowWidth'], '33.333333%');
      expect(first['colStart'], 1);
      expect(first['colSpan'], 4);
    });
  });

  group('hasFreeGridOverlap', () {
    DesignBlock at(int x, int y, int w, int h) => DesignBlock(
      id: 'b-$x-$y',
      type: 'text',
      gridPosition: GridPosition(x: x, y: y, w: w, h: h),
      properties: const {},
    );

    test(
      'side by side at different heights: the grid and the PDF disagreed',
      () {
        // The old grid drew these next to each other; they print stacked.
        expect(hasFreeGridOverlap([at(0, 0, 6, 4), at(6, 1, 6, 3)]), isTrue);
      },
    );

    test('a real row — the same y — is not it', () {
      expect(hasFreeGridOverlap([at(0, 0, 6, 4), at(6, 0, 6, 2)]), isFalse);
    });

    test('stacked blocks, touching or apart, are not it', () {
      expect(hasFreeGridOverlap([at(0, 0, 12, 4), at(0, 4, 12, 2)]), isFalse);
      expect(hasFreeGridOverlap([at(0, 0, 6, 4), at(6, 9, 6, 2)]), isFalse);
    });

    test('nothing this builder saves has it', () {
      final rows = [
        [at(0, 0, 4, 3), at(4, 0, 8, 5)],
        [at(0, 9, 12, 2)],
        [at(0, 2, 6, 6), at(6, 2, 6, 1)],
      ];
      expect(hasFreeGridOverlap(blocksFromRows(rows)), isFalse);
    });
  });
}
