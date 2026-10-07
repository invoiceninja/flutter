import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/widgets/detail_info_row.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';

import '../../../_responsive_helper.dart';

/// `DetailRowColumns` is a `DetailRowStack` that can run in two columns, for
/// a Details card that has a wide window's full width to itself.

List<Widget> _rows(int n) => [
  for (var i = 1; i <= n; i++)
    DetailInfoRow(label: 'Label $i', value: 'Value $i', copyable: false),
];

Offset _at(WidgetTester tester, int i) =>
    tester.getTopLeft(find.text('Label $i'));

void main() {
  testWidgets('one column is the plain stack', (tester) async {
    await pumpAt(tester, 1200, DetailRowColumns(children: _rows(5)));
    for (var i = 2; i <= 5; i++) {
      expect(_at(tester, i).dx, _at(tester, 1).dx, reason: 'row $i');
      expect(_at(tester, i).dy, greaterThan(_at(tester, i - 1).dy));
    }
  });

  testWidgets('two columns read down, then across', (tester) async {
    await pumpAt(
      tester,
      1200,
      DetailRowColumns(columns: 2, children: _rows(7)),
    );
    // Seven rows: four on the left, three on the right.
    for (var i = 2; i <= 4; i++) {
      expect(_at(tester, i).dx, _at(tester, 1).dx, reason: 'row $i is left');
    }
    for (var i = 5; i <= 7; i++) {
      expect(
        _at(tester, i).dx,
        greaterThan(_at(tester, 1).dx),
        reason: 'row $i is right',
      );
    }
    // The second column starts level with the first.
    expect(_at(tester, 5).dy, _at(tester, 1).dy);
    expectNoOverflow(tester);
  });

  testWidgets('too few rows to be worth splitting stay one column', (
    tester,
  ) async {
    await pumpAt(
      tester,
      1200,
      DetailRowColumns(columns: 2, children: _rows(3)),
    );
    for (var i = 2; i <= 3; i++) {
      expect(_at(tester, i).dx, _at(tester, 1).dx);
    }
  });

  testWidgets('null entries are dropped, as in the stack', (tester) async {
    await pumpAt(
      tester,
      1200,
      DetailRowColumns(columns: 2, children: [null, ..._rows(4), null]),
    );
    // Four real rows: two and two.
    expect(_at(tester, 2).dx, _at(tester, 1).dx);
    expect(_at(tester, 3).dx, greaterThan(_at(tester, 1).dx));
    expect(_at(tester, 3).dy, _at(tester, 1).dy);
  });

  testWidgets('it sits inside an IntrinsicHeight row', (tester) async {
    // The reason it takes `columns` from its host instead of measuring
    // itself: a `LayoutBuilder` here would throw the moment a card holding it
    // was levelled against its neighbour.
    await pumpAt(
      tester,
      1200,
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: DetailRowColumns(columns: 2, children: _rows(6))),
            const Expanded(child: SizedBox(height: 10)),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
