import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_nav_grid.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_nav_item.dart';

/// The two content widths the sidebar actually has: the 280-px mobile drawer
/// and the 232-px rail, each less the nav list's 12 + 12 horizontal padding.
const double _drawerContent = 256;
const double _railContent = 208;

ThemeData _theme() => ThemeData.light().copyWith(
  extensions: <ThemeExtension<dynamic>>[InTheme.light],
);

Widget _wrap(
  Widget child, {
  double width = _drawerContent,
  double scale = 1.0,
}) => MaterialApp(
  theme: _theme(),
  home: Scaffold(
    body: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    ),
  ),
);

Widget _tile(String label, {IconData icon = Icons.circle_outlined}) =>
    SidebarNavItem(
      label: label,
      icon: icon,
      active: false,
      tile: true,
      onTap: () {},
    );

void main() {
  group('sidebarMenuColumns', () {
    // This is the table `kSidebarMenuMinTileWidth`'s doc comment records, and
    // the reason it is a test: every wrong answer here still renders a
    // perfectly tidy grid, just a less dense one than invoiceninja/flutter#125
    // asked for. A reviewer cannot see the difference.
    test('the drawer keeps three columns through Large text', () {
      expect(sidebarMenuColumns(width: _drawerContent, textScale: 1.0), 3);
      expect(sidebarMenuColumns(width: _drawerContent, textScale: 1.2), 3);
    });

    test('the drawer yields to two columns at Extra Large', () {
      // 72 px of label at 14.7 px cannot carry "Recurring Invoices" over two
      // lines; legibility outranks density.
      expect(sidebarMenuColumns(width: _drawerContent, textScale: 1.4), 2);
    });

    test('the rail is two columns at every text size', () {
      for (final scale in [1.0, 1.2, 1.4]) {
        expect(
          sidebarMenuColumns(width: _railContent, textScale: scale),
          2,
          reason: 'rail at $scale',
        );
      }
    });

    test('clamps to 2..4 for absurd inputs', () {
      expect(sidebarMenuColumns(width: 40, textScale: 1.0), 2);
      expect(sidebarMenuColumns(width: 4000, textScale: 1.0), 4);
      expect(sidebarMenuColumns(width: 0, textScale: 1.0), 2);
      expect(sidebarMenuColumns(width: 256, textScale: 0), 2);
    });
  });

  group('SidebarNavGrid', () {
    testWidgets('renders nothing when there is nothing to render', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const SidebarNavGrid(tiles: [])));
      expect(find.byType(IntrinsicHeight), findsNothing);
    });

    testWidgets('lays the drawer out three across', (tester) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavGrid(
            tiles: [
              for (final label in ['A', 'B', 'C', 'D', 'E']) _tile(label),
            ],
          ),
        ),
      );
      // Two runs for five tiles at three columns.
      expect(find.byType(IntrinsicHeight), findsNWidgets(2));
      final a = tester.getTopLeft(find.text('A')).dy;
      expect(tester.getTopLeft(find.text('B')).dy, a);
      expect(tester.getTopLeft(find.text('C')).dy, a);
      expect(tester.getTopLeft(find.text('D')).dy, greaterThan(a));
    });

    testWidgets('a short final run keeps the column width of the run above', (
      tester,
    ) async {
      // Without the empty `Expanded` padding, the two survivors would stretch
      // to half the width each and fall out of line with the row above.
      await tester.pumpWidget(
        _wrap(
          SidebarNavGrid(
            tiles: [
              for (final label in ['A', 'B', 'C', 'D', 'E']) _tile(label),
            ],
          ),
        ),
      );
      Size cellOf(String label) => tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(SidebarNavItem),
        ),
      );
      expect(
        cellOf('D').width,
        moreOrLessEquals(cellOf('A').width, epsilon: 0.5),
      );
      expect(
        cellOf('E').width,
        moreOrLessEquals(cellOf('B').width, epsilon: 0.5),
      );
    });

    testWidgets('tiles in a run share a height when one label wraps', (
      tester,
    ) async {
      // The reason this is IntrinsicHeight + a stretched Row rather than a
      // Wrap: a Wrap gives the run the tallest child's height but leaves the
      // others short, which reads as a ragged bottom edge.
      await tester.pumpWidget(
        _wrap(
          SidebarNavGrid(
            tiles: [_tile('A'), _tile('Recurring Invoices'), _tile('C')],
          ),
        ),
      );
      Size cellOf(String label) => tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(SidebarNavItem),
        ),
      );
      final tall = cellOf('Recurring Invoices').height;
      expect(cellOf('A').height, tall);
      expect(cellOf('C').height, tall);
    });

    testWidgets('no overflow at Extra Large on the narrowest column', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SidebarNavGrid(
            tiles: [
              for (final label in [
                'Recurring Invoices',
                'Purchase Orders',
                'Transactions',
                'Dashboard',
              ])
                _tile(label),
            ],
          ),
          width: _railContent,
          scale: 1.4,
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
