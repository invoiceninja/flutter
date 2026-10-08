import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/drop_resolver.dart';

DropCell _c(String id, double left, double right, {bool gap = false}) =>
    DropCell(id: id, left: left, right: right, isGap: gap);

/// Three rows across a 600-wide page:
///   0:  0–100   [logo 0–200][gap 200–300][details 300–600]
///   1: 112–212  [table 0–600]
///   2: 224–324  [a 0–300][b 300–600]
final _rows = [
  DropRow(
    top: 0,
    bottom: 100,
    cells: [
      _c('logo', 0, 200),
      _c('g', 200, 300, gap: true),
      _c('details', 300, 600),
    ],
  ),
  DropRow(top: 112, bottom: 212, cells: [_c('table', 0, 600)]),
  DropRow(top: 224, bottom: 324, cells: [_c('a', 0, 300), _c('b', 300, 600)]),
];

DropTarget _at(
  double x,
  double y, {
  bool Function(String)? canJoin,
  String? movingId,
  List<DropRow>? rows,
}) => resolveDrop(
  point: Offset(x, y),
  rows: rows ?? _rows,
  width: 600,
  canJoin: canJoin ?? (_) => true,
  movingId: movingId,
).target;

void main() {
  group('a row of its own', () {
    test('on an empty page', () {
      expect(_at(10, 10, rows: const []), const DropNewRow(0));
    });

    test('above the first row and below the last', () {
      expect(_at(300, -20), const DropNewRow(0));
      expect(_at(300, 400), const DropNewRow(3));
    });

    test('in the space between two rows', () {
      expect(_at(300, 106), const DropNewRow(1));
      expect(_at(300, 218), const DropNewRow(2));
    });

    test('in the top or bottom band of a row', () {
      expect(_at(300, 116), const DropNewRow(1)); // top of the table row
      expect(_at(300, 208), const DropNewRow(2)); // its bottom
    });

    test('the bar sits between the rows it would part', () {
      final drop = resolveDrop(
        point: const Offset(300, 106),
        rows: _rows,
        width: 600,
        canJoin: (_) => true,
      );
      expect(drop.indicator.center.dy, 106);
      expect(drop.indicator.width, 600);
    });
  });

  group('into a row', () {
    test('before or after the block under the pointer', () {
      expect(_at(40, 50), const DropBeside('logo', before: true));
      expect(_at(180, 50), const DropBeside('logo', before: false));
      expect(_at(580, 50), const DropBeside('details', before: false));
    });

    test('over empty space, beside the nearer block on the facing side', () {
      expect(_at(220, 50), const DropBeside('logo', before: false));
      expect(_at(290, 50), const DropBeside('details', before: true));
    });

    test('the bar runs down the edge it would land on', () {
      final drop = resolveDrop(
        point: const Offset(180, 50),
        rows: _rows,
        width: 600,
        canJoin: (_) => true,
      );
      expect(drop.indicator.center.dx, 200);
      expect(drop.indicator.top, 0);
      expect(drop.indicator.bottom, 100);
    });

    test('a row with no room becomes a new row on the nearer side', () {
      expect(_at(300, 150, canJoin: (_) => false), const DropNewRow(1));
      expect(_at(300, 180, canJoin: (_) => false), const DropNewRow(2));
    });

    test('a block is never dropped beside itself', () {
      // Dragging `a` over its own place: the anchor is its neighbour.
      expect(_at(100, 274, movingId: 'a'), const DropBeside('b', before: true));
      // The only block of its row has nobody to sit beside.
      expect(_at(300, 150, movingId: 'table'), isA<DropNewRow>());
    });
  });
}
