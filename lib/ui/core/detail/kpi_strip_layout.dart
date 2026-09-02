import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// Width at which a detail KPI strip switches from the two-per-row grid to the
/// single divided row. Every strip has always used 1100; it lives here now so
/// they cannot drift apart.
const double kKpiStripWideBreakpoint = 1100;

/// Responsive layout for a detail-screen KPI strip's cells.
///
/// Wide (≥ [kKpiStripWideBreakpoint]): one row of equal-width cells separated
/// by hairline dividers. Narrow: two cells per row, over however many cells the
/// caller supplies.
///
/// **Layout only.** Each strip keeps its own cell widget — they genuinely
/// differ (some take a pre-built `Widget` value, Client takes a `Decimal` +
/// `Formatter`, Projects takes a `String` with a `'—'` sentinel), and folding
/// those together would mean four shapes behind one constructor.
///
/// This exists because the same two layout classes had been hand-copied into
/// **eight** files, five of which still indexed `cells[0..3]` directly — a
/// `RangeError` waiting for the first conditional cell. Product hit it
/// (invoiceninja/flutter#91), then Payment hit it again (#113) and copied the
/// fix rather than sharing it. The count-agnostic loop below is that fix, once:
/// a strip may now drop a cell without touching its layout.
///
/// Two things to know before changing this:
///
/// * The odd trailing cell keeps an empty [Expanded] beside it, so it stays at
///   **half width** instead of stretching across and knocking the column
///   alignment out. That is the whole reason the grid isn't a `Wrap`.
/// * [InSpacing.md] / [InSpacing.lg] read `MediaQuery.sizeOf(context).width` —
///   the *window*, not the local constraints — so the gaps here key off the
///   screen while the branch above keys off the box. That split is deliberate
///   and predates this widget; don't "fix" one to match the other.
///
/// Deliberately **not** merged with `BillingDocKpiStrip`, which looks similar
/// but branches on per-cell width (`maxWidth / cells.length >= 130`), falls
/// back to a `Wrap`, and uses a 32 px divider — merging would silently move
/// Invoice / Quote / Credit detail.
class KpiStripLayout extends StatelessWidget {
  const KpiStripLayout({super.key, required this.cells});

  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kKpiStripWideBreakpoint) {
          return _HorizontalStrip(cells: cells, tokens: tokens);
        }
        return _CellGrid(cells: cells);
      },
    );
  }
}

class _HorizontalStrip extends StatelessWidget {
  const _HorizontalStrip({required this.cells, required this.tokens});
  final List<Widget> cells;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) {
        children.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: InSpacing.lg(context)),
            child: SizedBox(
              width: 1,
              height: 36,
              child: ColoredBox(color: tokens.border),
            ),
          ),
        );
      }
      children.add(Expanded(child: cells[i]));
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: children,
    );
  }
}

class _CellGrid extends StatelessWidget {
  const _CellGrid({required this.cells});
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      if (rows.isNotEmpty) rows.add(SizedBox(height: InSpacing.md(context)));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cells[i]),
            SizedBox(width: InSpacing.md(context)),
            // Keeps the last cell of an odd row at half width rather than
            // letting it stretch across and break the column alignment.
            Expanded(
              child: i + 1 < cells.length
                  ? cells[i + 1]
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}
