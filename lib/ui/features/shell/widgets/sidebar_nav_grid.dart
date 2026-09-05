import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// Gap between grid cells, both axes.
const double kSidebarMenuTileGap = InSpacing.sm;

/// Narrowest a menu tile may be at text scale 1.0, and the number that decides
/// the column count at every width the sidebar actually has.
///
/// There are only two of those — the 280-px mobile drawer and the 232-px rail,
/// each less the nav list's 12 + 12 padding — so this constant is not free to
/// pick. What it buys, per [sidebarMenuColumns]:
///
/// | content       | 1.0          | 1.2 (Large)  | 1.4 (Extra Large) |
/// |---------------|--------------|--------------|-------------------|
/// | drawer, 256   | 3 cols, 80px | 3 cols, 80px | 2 cols, 124px     |
/// | rail, 208     | 2 cols, 100  | 2 cols, 100  | 2 cols, 100       |
///
/// A larger value silently costs the whole feature. At **84** the *drawer*
/// renders two columns even at normal text scale, which is barely denser than
/// the list layout it replaces and is not the grid invoiceninja/flutter#125
/// asked for. At **76** it is three at normal scale but drops to two the moment
/// the user picks Large — the app offers four text sizes and the OS scaler
/// passes through unclamped, so that is an ordinary state, not an edge case.
/// **66** holds three columns through Large and yields at Extra Large, where 72
/// px of label at 14.7 px genuinely cannot carry "Recurring Invoices" over two
/// lines and legibility outranks density.
///
/// None of that is visible in review, so `sidebar_nav_grid_test.dart` asserts
/// the table cell for cell.
const double kSidebarMenuMinTileWidth = 66;

/// How many columns [SidebarNavGrid] renders in [width] logical pixels.
///
/// [textScale] is the user's text-size multiplier — pass
/// `scaler.scale(kSidebarMenuMinTileWidth) / kSidebarMenuMinTileWidth` rather
/// than assuming a linear scaler, since a platform one need not be.
///
/// Clamped to 2..4: below two the "grid" is just a list with a border, and
/// above four the labels are narrower than the icons they sit under.
int sidebarMenuColumns({required double width, required double textScale}) {
  final minTile = kSidebarMenuMinTileWidth * textScale;
  if (minTile <= 0 || width <= 0) return 2;
  final fits = (width + kSidebarMenuTileGap) ~/ (minTile + kSidebarMenuTileGap);
  return fits.clamp(2, 4);
}

/// The "pills" layout for the sidebar's nav block (invoiceninja/flutter#125):
/// [tiles] laid out in equal-width columns, icon-above-label cards rather than
/// full-width rows.
///
/// Lives in its own file, and takes plain widgets rather than reading
/// `Services`, because `InSidebar` itself cannot be widget-tested — pumping it
/// deadlocks on the saved-views Drift watch (see `sidebar_search_box_test.dart`
/// and `test/lint/sidebar_footer_wiring_test.dart`). Everything measurable
/// about the grid therefore has to be reachable from here.
///
/// Deliberately **not** a `Wrap`: `Wrap` gives a run the height of its tallest
/// child but does not stretch the others, so a one-line tile beside a two-line
/// one leaves a ragged bottom edge. `IntrinsicHeight` + a stretched `Row` is
/// what the dashboard's own quick-action row already uses.
///
/// Every tile handed in must render something. That is a real constraint, not a
/// nicety: a cell that collapsed to nothing would leave its column empty while
/// still consuming a slot. It holds by construction because the caller keeps
/// the one destination whose visibility resolves asynchronously (Outbox, which
/// hides itself at zero) out of the grid entirely.
class SidebarNavGrid extends StatelessWidget {
  const SidebarNavGrid({required this.tiles, super.key});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final scaler = MediaQuery.textScalerOf(context);
    final textScale =
        scaler.scale(kSidebarMenuMinTileWidth) / kSidebarMenuMinTileWidth;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = sidebarMenuColumns(
          width: constraints.maxWidth,
          textScale: textScale,
        );
        final runs = <Widget>[];
        for (var start = 0; start < tiles.length; start += columns) {
          final end = math.min(start + columns, tiles.length);
          final cells = <Widget>[];
          for (var i = start; i < end; i++) {
            if (i > start) {
              cells.add(const SizedBox(width: kSidebarMenuTileGap));
            }
            cells.add(Expanded(child: tiles[i]));
          }
          // Pad a short final run with empty columns so its tiles keep the
          // width of the run above instead of stretching out of alignment —
          // the rule `KpiStripLayout` documents for an odd trailing cell.
          for (var i = end - start; i < columns; i++) {
            cells.add(const SizedBox(width: kSidebarMenuTileGap));
            cells.add(const Expanded(child: SizedBox.shrink()));
          }
          if (runs.isNotEmpty) {
            runs.add(const SizedBox(height: kSidebarMenuTileGap));
          }
          runs.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: cells,
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: runs,
        );
      },
    );
  }
}
