import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';

/// Tabular row layout used by the dashboard list cards, matching the v2
/// `InvoiceTable` (`docs/design/v2/screens.jsx:357-390`):
///
/// ```
///   INVOICE    CLIENT             STATUS    DUE     AMOUNT   ⋮
///   INV-2041   Bauhaus Atelier   [Overdue]  May 30  $4,200   ⋮
/// ```
///
/// The widget is intentionally column-agnostic — each card supplies its own
/// header labels, column widths, and row cells. Compact mode (the default,
/// used inside dashboard cards) gives `10×16` cell padding; the full variant
/// uses `14×16`, matching the spec's `compact` flag.
class DashboardEntityTable extends StatelessWidget {
  const DashboardEntityTable({
    super.key,
    required this.headers,
    required this.columnWidths,
    required this.rows,
    this.compact = true,
    this.cellAlignments = const {},
    this.cellPadding,
  });

  /// One label per column; pass `''` for the trailing menu column. Length
  /// must equal the number of columns in [columnWidths] and in each row's
  /// `cells`.
  final List<String> headers;

  /// Per-column width specification, keyed by column index. Standard recipe
  /// for the invoice-style layout is `{0: IntrinsicColumnWidth(), 1:
  /// FlexColumnWidth(2), 2..4: IntrinsicColumnWidth(), 5: FixedColumnWidth(32)}`.
  final Map<int, TableColumnWidth> columnWidths;

  /// Per-column cell alignment override. Defaults to `Alignment.centerLeft`
  /// when not set. The amount column typically wants `Alignment.centerRight`.
  final Map<int, Alignment> cellAlignments;

  final List<DashboardEntityTableRow> rows;

  /// Compact rows (10×16 padding) for dashboard cards; non-compact (14×16)
  /// matches the full invoice-list page.
  final bool compact;

  /// Horizontal cell padding override, applied to the header row as well as the
  /// body — 16 px each side by default, i.e. **32 px per column** before a
  /// glyph is drawn. That is affordable at five columns and is not at six in a
  /// ~570 px dashboard card, where it spends a third of the width on gutters
  /// and squeezes the client name to a few characters.
  ///
  /// It must reach [_HeaderCell] too: under `IntrinsicColumnWidth` the table
  /// takes the max intrinsic across *all* rows, so a header still padded at 16
  /// keeps setting the floor and a body-only override saves almost nothing.
  final double? cellPadding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final h = cellPadding ?? 16;
    final rowPadding = compact
        ? EdgeInsets.symmetric(horizontal: h, vertical: 10)
        : EdgeInsets.symmetric(horizontal: h, vertical: 14);

    return Table(
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        _headerRow(tokens, h),
        for (var i = 0; i < rows.length; i++)
          _dataRow(
            context,
            tokens,
            rows[i],
            rowPadding,
            isLast: i == rows.length - 1,
          ),
      ],
    );
  }

  TableRow _headerRow(InTheme tokens, double h) {
    return TableRow(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      children: [
        for (var i = 0; i < headers.length; i++)
          _HeaderCell(
            label: headers[i],
            alignment: cellAlignments[i] ?? Alignment.centerLeft,
            tokens: tokens,
            horizontalPadding: h,
          ),
      ],
    );
  }

  TableRow _dataRow(
    BuildContext context,
    InTheme tokens,
    DashboardEntityTableRow row,
    EdgeInsets padding, {
    required bool isLast,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: tokens.border)),
      ),
      children: [
        for (var i = 0; i < row.cells.length; i++)
          _bodyCell(
            child: row.cells[i],
            padding: padding,
            alignment: cellAlignments[i] ?? Alignment.centerLeft,
            onTap: i < (row.cellTaps?.length ?? 0) ? row.cellTaps![i] : null,
            // The label rides cell 0 and the rest fall silent, so the row is a
            // single announced target rather than one per column.
            semanticsLabel: i == 0 ? row.semanticsLabel : null,
            muteSemantics: i > 0 && row.semanticsLabel != null,
          ),
      ],
    );
  }

  Widget _bodyCell({
    required Widget child,
    required EdgeInsets padding,
    required Alignment alignment,
    VoidCallback? onTap,
    String? semanticsLabel,
    bool muteSemantics = false,
  }) {
    Widget inner = Padding(
      padding: padding,
      child: Align(alignment: alignment, child: child),
    );
    // `ExcludeSemantics` drops the subtree's nodes but keeps the widgets, so
    // the cell still paints and still takes the tap — it just stops speaking.
    // Safe against `semantics_excludes_need_ontap_test`, which fires on an
    // exclude that swallows an interactive role's own tap: here the row's
    // single announced target is cell 0, which is not excluded.
    if (muteSemantics) inner = ExcludeSemantics(child: inner);
    if (onTap == null) {
      return TableCell(child: inner);
    }
    return TableCell(
      child: Builder(
        builder: (context) {
          final tokens = context.inTheme;
          return TableRowInkWell(
            onTap: onTap,
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.pressed)) {
                return tokens.border;
              }
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return tokens.surfaceAlt;
              }
              return null;
            }),
            child: semanticsLabel == null
                ? inner
                : Semantics(
                    button: true,
                    label: semanticsLabel,
                    // Re-declared, not inherited: the subtree's own nodes are
                    // excluded below, and the `TableRowInkWell` carrying the
                    // real gesture is this node's PARENT — so without it a
                    // screen reader announces a button it cannot activate.
                    onTap: onTap,
                    child: ExcludeSemantics(child: inner),
                  ),
          );
        },
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.label,
    required this.alignment,
    required this.tokens,
    required this.horizontalPadding,
  });

  final String label;
  final Alignment alignment;
  final InTheme tokens;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 10,
        ),
        child: Align(
          alignment: alignment,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: tokens.ink3,
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardEntityTableRow {
  const DashboardEntityTableRow({
    required this.cells,
    this.cellTaps,
    this.semanticsLabel,
  });

  /// One announcement for the whole row, replacing the per-cell nodes.
  ///
  /// Only for a row whose cells all share a single destination. A `Table` has
  /// no widget to wrap a `TableRow` in, so the cells are separately actionable
  /// by construction: six cells over five rows is thirty nodes, each speaking a
  /// fragment with no row identity. Given this, cell 0 carries the composed
  /// label and every other cell's own node is excluded — one target, one
  /// announcement. Leave it null where the cells route to different places
  /// (`DashboardInvoiceTable`'s client cell does), since there each node is a
  /// genuinely distinct destination.
  final String? semanticsLabel;

  /// One widget per column. Length must equal `headers.length` in the
  /// surrounding table.
  final List<Widget> cells;

  /// Per-cell tap targets, aligned 1:1 with [cells]. A `null` entry (or a
  /// short list) leaves that cell as a plain non-interactive `TableCell`.
  /// Cells with a non-null callback are wrapped in `TableRowInkWell`, which
  /// shows hover/press feedback scoped to just that cell — the cue that
  /// different columns route to different destinations (invoice number →
  /// invoice, client name → client, etc.).
  final List<VoidCallback?>? cellTaps;
}
