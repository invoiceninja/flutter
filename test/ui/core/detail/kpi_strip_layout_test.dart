import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/ui/core/detail/kpi_strip_layout.dart';

import '../../../_responsive_helper.dart';

/// The layout the eight detail KPI strips used to hand-copy. Five of those
/// copies indexed `cells[0..3]` directly and would have thrown `RangeError`
/// the first time a strip dropped a cell — which is exactly what Product
/// (invoiceninja/flutter#91) and then Payment (#113) needed to do. This is the
/// coverage those copies never had.
void main() {
  const narrow = 500.0;
  const wide = 1200.0;

  List<Widget> cells(int n) => [
    for (var i = 0; i < n; i++) SizedBox(key: ValueKey('cell$i'), height: 40),
  ];

  Finder cell(int i) => find.byKey(ValueKey('cell$i'));

  Future<void> pump(WidgetTester tester, double width, int count) =>
      pumpAt(tester, width, KpiStripLayout(cells: cells(count)));

  group('any cell count renders at any width', () {
    for (final width in const [narrow, wide]) {
      for (var count = 1; count <= 5; count++) {
        testWidgets('$count cell(s) at ${width.toInt()}px', (tester) async {
          await pump(tester, width, count);

          expectNoOverflow(tester);
          for (var i = 0; i < count; i++) {
            expect(cell(i), findsOneWidget, reason: 'cell $i went missing');
          }
        });
      }
    }
  });

  group('wide branch', () {
    testWidgets('separates cells with one divider less than the cell count', (
      tester,
    ) async {
      await pump(tester, wide, 4);

      // The hairline is the only 1px-wide ColoredBox in the tree.
      final dividers = tester.widgetList<SizedBox>(
        find.byWidgetPredicate(
          (w) => w is SizedBox && w.width == 1 && w.height == 36,
        ),
      );
      expect(dividers.length, 3);
    });

    testWidgets('a single cell gets no divider', (tester) async {
      await pump(tester, wide, 1);

      expect(
        find.byWidgetPredicate((w) => w is SizedBox && w.width == 1),
        findsNothing,
      );
    });

    testWidgets('cells share the width equally', (tester) async {
      await pump(tester, wide, 4);

      final widths = [
        for (var i = 0; i < 4; i++) tester.getSize(cell(i)).width,
      ];
      expect(widths.toSet().length, 1, reason: 'cells: $widths');
    });
  });

  group('narrow branch', () {
    testWidgets('lays out two per row', (tester) async {
      await pump(tester, narrow, 4);

      // Rows are distinguished by dy: 0 and 1 share one, 2 and 3 the next.
      expect(tester.getTopLeft(cell(0)).dy, tester.getTopLeft(cell(1)).dy);
      expect(tester.getTopLeft(cell(2)).dy, tester.getTopLeft(cell(3)).dy);
      expect(
        tester.getTopLeft(cell(2)).dy,
        greaterThan(tester.getTopLeft(cell(0)).dy),
      );
    });

    testWidgets('an odd trailing cell stays at half width', (tester) async {
      // The invariant the empty-Expanded filler exists for. Let it stretch and
      // the last row's cell no longer lines up with the column above it —
      // silent, and invisible to a "does it render" assertion.
      await pump(tester, narrow, 3);

      expect(tester.getSize(cell(2)).width, tester.getSize(cell(0)).width);
    });

    testWidgets('a lone cell also stays at half width', (tester) async {
      await pump(tester, narrow, 1);
      final loneWidth = tester.getSize(cell(0)).width;

      await pump(tester, narrow, 2);
      expect(tester.getSize(cell(0)).width, loneWidth);
    });
  });
}
