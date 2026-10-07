import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/features/dashboard/widgets/configured_cards_grid.dart';

/// How the user's metric cards are split into rows. The grid used to fill
/// rows in order, so five cards at four to a row were four and a stray one.
void main() {
  test('how many fit a row follows the width', () {
    expect(metricCardsPerRow(390), 2);
    expect(metricCardsPerRow(700), 3);
    expect(metricCardsPerRow(1100), 4);
  });

  test('rows are balanced — no stray tile', () {
    expect(metricCardRows(5, 1100), [3, 2]);
    expect(metricCardRows(6, 1100), [3, 3]);
    expect(metricCardRows(7, 1100), [4, 3]);
    expect(metricCardRows(9, 1100), [3, 3, 3]);
    expect(metricCardRows(4, 700), [2, 2]);
    expect(metricCardRows(3, 390), [2, 1]);
  });

  test('what fits one row stays one row', () {
    expect(metricCardRows(1, 1100), [1]);
    expect(metricCardRows(4, 1100), [4]);
    expect(metricCardRows(2, 390), [2]);
  });

  test('no cards, no rows', () {
    expect(metricCardRows(0, 1100), isEmpty);
  });

  test('every card is placed exactly once, and no row exceeds the limit', () {
    for (final width in const [390.0, 700.0, 1100.0]) {
      final perRow = metricCardsPerRow(width);
      for (var n = 1; n <= 24; n++) {
        final rows = metricCardRows(n, width);
        expect(rows.reduce((a, b) => a + b), n, reason: '$n @ $width');
        expect(rows.every((r) => r >= 1 && r <= perRow), isTrue);
        // Balanced: no row is more than one card shorter than another.
        final sorted = [...rows]..sort();
        expect(sorted.last - sorted.first, lessThanOrEqualTo(1));
      }
    }
  });
}
