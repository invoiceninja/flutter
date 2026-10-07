import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/record_profile_layout.dart';
import 'package:admin/ui/core/widgets/detail_row_columns.dart';

import '../../../_responsive_helper.dart';

/// `RecordProfileLayout` places a record's profile cards: stacked below the
/// two-column breakpoint, level rows of equal cards at and above it, the tail
/// full width either way.

/// A card that is [height] tall on its own, and can be made taller.
Widget _card(String label, {double height = 80}) => Container(
  key: ValueKey(label),
  constraints: BoxConstraints(minHeight: height),
  color: const Color(0xFFEEEEEE),
  child: Text(label),
);

Rect _rect(WidgetTester tester, String label) =>
    tester.getRect(find.byKey(ValueKey(label)));

void main() {
  testWidgets('narrow: one stack, lead then tail, in the order given', (
    tester,
  ) async {
    await pumpAt(
      tester,
      500,
      RecordProfileLayout(
        lead: [_card('a'), _card('b'), _card('c')],
        tail: [_card('notes')],
      ),
    );
    final order = ['a', 'b', 'c', 'notes'];
    for (var i = 1; i < order.length; i++) {
      expect(
        _rect(tester, order[i]).top,
        greaterThan(_rect(tester, order[i - 1]).bottom),
        reason: '${order[i]} is below ${order[i - 1]}',
      );
      expect(_rect(tester, order[i]).left, _rect(tester, order[0]).left);
    }
    expectNoOverflow(tester);
  });

  testWidgets('wide: the lead cards share a row as equal cards that end on '
      'one line, whichever is taller', (tester) async {
    await pumpAt(
      tester,
      1200,
      RecordProfileLayout(
        lead: [_card('a', height: 60), _card('b', height: 220), _card('c')],
        tail: [_card('notes')],
      ),
    );
    final a = _rect(tester, 'a');
    final b = _rect(tester, 'b');
    final c = _rect(tester, 'c');
    expect(a.top, b.top);
    expect(c.top, b.top);
    expect(a.bottom, b.bottom);
    expect(c.bottom, b.bottom);
    expect(a.width, moreOrLessEquals(b.width, epsilon: 0.5));
    expect(b.width, moreOrLessEquals(c.width, epsilon: 0.5));
    expect(b.left, greaterThan(a.right));

    // The tail is beneath, across the whole width.
    final notes = _rect(tester, 'notes');
    expect(notes.top, greaterThan(b.bottom));
    expect(notes.left, a.left);
    expect(notes.right, c.right);
    expectNoOverflow(tester);
  });

  testWidgets('wide: four cards are two rows of two, not three and a stray', (
    tester,
  ) async {
    await pumpAt(
      tester,
      1200,
      RecordProfileLayout(
        lead: [_card('a'), _card('b'), _card('c'), _card('d')],
      ),
    );
    final a = _rect(tester, 'a');
    final b = _rect(tester, 'b');
    final c = _rect(tester, 'c');
    final d = _rect(tester, 'd');
    expect(b.top, a.top);
    expect(c.top, greaterThan(a.bottom));
    expect(d.top, c.top);
    expect(c.left, a.left);
    expect(d.left, b.left);
    expect(d.width, moreOrLessEquals(a.width, epsilon: 0.5));
  });

  testWidgets('wide: five cards are three and two', (tester) async {
    await pumpAt(
      tester,
      1200,
      RecordProfileLayout(lead: [for (final l in 'abcde'.split('')) _card(l)]),
    );
    expect(_rect(tester, 'c').top, _rect(tester, 'a').top);
    expect(_rect(tester, 'd').top, greaterThan(_rect(tester, 'a').bottom));
    expect(_rect(tester, 'e').top, _rect(tester, 'd').top);
  });

  testWidgets('wide: a lone card takes the row, and is told it may run its '
      'rows in two columns', (tester) async {
    // It used to be held to the header's column with the rest of the row
    // blank — one of three treatments the same case had on different
    // screens. It has the width; what it must not be is one column of rows
    // against a window of blank card, which is what the scope is for.
    int? columns;
    await pumpAt(
      tester,
      1200,
      RecordProfileLayout(
        lead: [
          Builder(
            builder: (context) {
              columns = DetailRowColumnsScope.of(context);
              return _card('a');
            },
          ),
        ],
        tail: [_card('notes')],
      ),
    );
    final a = _rect(tester, 'a');
    final notes = _rect(tester, 'notes');
    expect(a.left, notes.left);
    expect(a.width, notes.width);
    expect(columns, 2);
  });

  testWidgets('wide: cards that share a row are not told to split', (
    tester,
  ) async {
    final seen = <int>[];
    Widget probe(String label) => Builder(
      builder: (context) {
        seen.add(DetailRowColumnsScope.of(context));
        return _card(label);
      },
    );
    await pumpAt(
      tester,
      1200,
      RecordProfileLayout(lead: [probe('a'), probe('b')]),
    );
    expect(seen, everyElement(1));
  });

  testWidgets('narrow: a lone card is one column of rows', (tester) async {
    int? columns;
    await pumpAt(
      tester,
      500,
      RecordProfileLayout(
        lead: [
          Builder(
            builder: (context) {
              columns = DetailRowColumnsScope.of(context);
              return _card('a');
            },
          ),
        ],
      ),
    );
    expect(columns, 1);
  });

  testWidgets('nothing to show builds nothing', (tester) async {
    await pumpAt(tester, 1200, const RecordProfileLayout(lead: []));
    expect(tester.getSize(find.byType(RecordProfileLayout)).height, 0);
  });

  testWidgets('a card that grows after the first frame keeps its row level', (
    tester,
  ) async {
    // A linked record's name, or a custom-field label, lands a frame after
    // the card is first laid out and adds a row to it.
    final extra = ValueNotifier<double>(0);
    addTearDown(extra.dispose);
    await pumpAt(
      tester,
      1200,
      RecordProfileLayout(
        lead: [
          _card('a'),
          Container(
            key: const ValueKey('b'),
            color: const Color(0xFFEEEEEE),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 40, child: Text('b')),
                ValueListenableBuilder<double>(
                  valueListenable: extra,
                  builder: (_, height, _) => SizedBox(height: height),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    expect(_rect(tester, 'b').bottom, _rect(tester, 'a').bottom);

    extra.value = 300;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(_rect(tester, 'a').bottom, _rect(tester, 'b').bottom);
    expect(_rect(tester, 'a').height, greaterThan(300));
  });
}
