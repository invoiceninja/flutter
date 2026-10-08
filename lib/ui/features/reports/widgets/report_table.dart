import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/models/domain/report_preview.dart';
import 'package:admin/domain/reports/report_column_types.dart';
import 'package:admin/domain/reports/report_engine.dart';
import 'package:admin/domain/reports/report_group_label.dart';
import 'package:admin/domain/reports/report_measures.dart';
import 'package:admin/domain/reports/report_table_model.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';
import 'package:admin/ui/core/widgets/status_pill.dart';
import 'package:admin/ui/features/reports/view_models/reports_view_model.dart';
import 'package:admin/ui/features/reports/widgets/report_cell_text.dart';
import 'package:admin/ui/features/reports/widgets/report_status_tone.dart';
import 'package:admin/ui/features/reports/widgets/report_table_layout.dart';
import 'package:admin/utils/formatting.dart';

/// Height of one table line. Fixed, so a result of fifty thousand rows is
/// laid out by arithmetic rather than by measuring each one — and grown with
/// the reader's text size, so a larger font is not sliced by the row.
double reportTableRowHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
  return (Env.isTouchPrimary ? 48.0 : 40.0) * scale;
}

/// Height of the column-header line.
double reportTableHeaderHeight(BuildContext context) {
  final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
  return (Env.isTouchPrimary ? 44.0 : 36.0) * scale;
}

const double _kCellPadding = 12;
const double _kIndent = 18;

/// One line of the table's frame: the first cell where it is, the rest
/// behind a clip and shifted by the horizontal scroll.
///
/// Every line of the table — header, totals, groups, rows — is one of these,
/// which is the whole of how the columns stay aligned and the first one
/// stays put: they all read the same [ReportTableScrollScope].
class ReportTableLineFrame extends StatelessWidget {
  const ReportTableLineFrame({
    super.key,
    required this.leading,
    required this.cells,
    required this.height,
  });

  /// The first column's cell.
  final Widget leading;

  /// The other columns' cells, in column order.
  final List<Widget> cells;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scope = ReportTableScrollScope.of(context);
    final layout = scope.layout;
    final tokens = context.inTheme;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final rest = SizedBox(
      width: layout.scrollContent,
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            SizedBox(width: layout.widths[i + 1], child: cells[i]),
        ],
      ),
    );
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: layout.pinnedWidth, child: leading),
          Expanded(
            child: !layout.scrolls
                ? rest
                : ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        OverflowBox(
                          alignment: AlignmentDirectional.centerStart,
                          minWidth: layout.scrollContent,
                          maxWidth: layout.scrollContent,
                          child: AnimatedBuilder(
                            animation: scope.offset,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(
                                scope.offset.hasPixels
                                    ? (rtl ? 1 : -1) * scope.offset.pixels
                                    : 0,
                                0,
                              ),
                              child: child,
                            ),
                            child: rest,
                          ),
                        ),
                        // The seam of the held column: a hairline that only
                        // appears once something has scrolled under it.
                        PositionedDirectional(
                          start: 0,
                          top: 0,
                          bottom: 0,
                          child: AnimatedBuilder(
                            animation: scope.offset,
                            builder: (context, _) =>
                                scope.offset.hasPixels &&
                                    scope.offset.pixels > 0.5
                                ? SizedBox(
                                    width: 1,
                                    child: ColoredBox(
                                      color: tokens.borderStrong,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// The table's pinned top: the column headers, and under them the totals.
///
/// The totals sit at the top, directly beneath the headers they total,
/// rather than at the foot of a list that may be thousands of rows away —
/// and pinned, so they are on screen wherever the reader is in the rows.
class ReportTableHeader extends StatelessWidget {
  const ReportTableHeader({
    super.key,
    required this.vm,
    required this.view,
    required this.formatter,
    required this.currencyId,
    required this.currencyLabel,
    required this.onFilter,
    this.showTotals = true,
    this.summary,
  });

  final ReportsViewModel vm;
  final ReportView view;
  final Formatter? formatter;

  /// Set on a narrow pane showing groups: the totals line is then the label
  /// and this one figure, full width — see [ReportTableSummary].
  final ReportTableSummary? summary;

  /// The currency the totals are read in; `''` for a report without one.
  final String currencyId;

  /// Its code ("USD"), shown beside "Total" when the result holds more than
  /// one currency. Null says nothing — a single-currency total needs no
  /// qualifier.
  final String? currencyLabel;

  /// Open the filter editor for a column.
  final ValueChanged<ReportColumn> onFilter;
  final bool showTotals;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final layout = ReportTableScrollScope.of(context).layout;
    final columns = layout.columns;
    if (columns.isEmpty) return const SizedBox.shrink();
    final headerHeight = reportTableHeaderHeight(context);
    final radius = const Radius.circular(InRadii.r3);
    Widget header(int i) => _HeaderCell(
      vm: vm,
      column: columns[i],
      width: layout.widths[i],
      isGroupColumn: vm.group == columns[i].identifier,
      onFilter: () => onFilter(columns[i]),
    );

    final total = context.tr('total');
    return Material(
      color: tokens.surfaceAlt,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: BorderRadius.only(topLeft: radius, topRight: radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReportTableLineFrame(
            height: headerHeight,
            leading: header(0),
            cells: [for (var i = 1; i < columns.length; i++) header(i)],
          ),
          if (showTotals) ...[
            Divider(height: 1, thickness: 1, color: tokens.border),
            ColoredBox(
              color: tokens.surface,
              child: summary != null
                  ? _SummaryLine(
                      height: reportTableRowHeight(context),
                      label: Text(
                        currencyLabel == null
                            ? total
                            : '$total · $currencyLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _labelStyle(
                          context,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      figure: summary!.isCount
                          ? _Figure(
                              value: Decimal.fromInt(view.totalRowCount),
                              currencyId: currencyId,
                              foreign: false,
                            )
                          : _figureOf(
                              view.grandTotalsByCurrency[summary!.measureId],
                              currencyId,
                            ),
                      summary: summary!,
                      formatter: formatter,
                      strong: true,
                    )
                  : ReportTableLineFrame(
                      height: reportTableRowHeight(context),
                      leading: _CellBox(
                        child: Text(
                          currencyLabel == null
                              ? total
                              : '$total · $currencyLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _labelStyle(
                            context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      cells: [
                        for (var i = 1; i < columns.length; i++)
                          _TotalCell(
                            column: columns[i],
                            figure: _figureOf(
                              view.grandTotalsByCurrency[columns[i].identifier],
                              currencyId,
                              // The grand total is of one currency by
                              // definition; it never borrows another's.
                              ownOnly: true,
                            ),
                            formatter: formatter,
                            strong: true,
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// On a narrow pane a grouped table leads each line with **one** figure —
/// the measure the chart above is of — instead of a row of column totals
/// that are three sideways swipes away.
///
/// A phone shows the held column and about one more. A group line laid out
/// on the columns therefore showed a name and no numbers: the reader had to
/// scroll sideways to learn what "March" came to. Full width, name on one
/// side and its total on the other, the list answers the question it exists
/// for; the figure tabs above choose which total, and the rows inside a
/// group are still a table.
class ReportTableSummary {
  const ReportTableSummary({required this.measureId, this.column});

  /// The measure shown; [kReportCountSeriesId] for the row count.
  final String measureId;

  /// Its column; null for the count.
  final ReportColumn? column;

  bool get isCount => column == null;
}

/// One figure of a totals or group line, and the currency it is in.
class _Figure {
  const _Figure({
    required this.value,
    required this.currencyId,
    required this.foreign,
  });

  final Decimal value;
  final String currencyId;

  /// Not in the currency the table is being read in — see [_figureOf].
  final bool foreign;
}

/// A line's figure for one column out of its per-currency totals.
///
/// In [currencyId] when the line has rows in it. Otherwise — a client billed
/// only in euros, on a table being read in dollars — in **its own** currency
/// when it has exactly one: the amount carries its own symbol, so it cannot
/// be mistaken for dollars, and it is drawn quieter because it is no part of
/// the total above. A blank there said the client had no invoices. A line
/// in several other currencies stays blank: there is no one figure to show.
_Figure? _figureOf(
  Map<String, Decimal>? byCurrency,
  String currencyId, {
  bool ownOnly = false,
}) {
  if (byCurrency == null || byCurrency.isEmpty) return null;
  final own = byCurrency[currencyId];
  if (own != null) {
    return _Figure(value: own, currencyId: currencyId, foreign: false);
  }
  if (ownOnly || byCurrency.length != 1) return null;
  final only = byCurrency.entries.single;
  return _Figure(value: only.value, currencyId: only.key, foreign: true);
}

/// A full-width line: a label at the start, one figure at the end.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.height,
    required this.label,
    required this.figure,
    required this.summary,
    required this.formatter,
    this.indent = 0,
    this.strong = false,
  });

  final double height;
  final Widget label;
  final _Figure? figure;
  final ReportTableSummary summary;
  final Formatter? formatter;
  final double indent;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final figure = this.figure;
    final column = summary.column;
    final String? text;
    if (figure == null) {
      text = null;
    } else if (column == null) {
      final n = figure.value.toBigInt().toInt();
      text = formatter?.integer(n) ?? '$n';
    } else {
      text = reportValueText(
        figure.value,
        column: column,
        formatter: formatter,
        currencyId: figure.currencyId,
      );
    }
    final weight = strong ? FontWeight.w600 : FontWeight.w500;
    final color = figure?.foreign ?? false ? tokens.ink2 : tokens.ink;
    return SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          start: _kCellPadding + indent,
          end: _kCellPadding,
        ),
        child: Row(
          children: [
            Expanded(child: label),
            if (text != null) ...[
              const SizedBox(width: InSpacing.sm),
              Text(
                text,
                maxLines: 1,
                softWrap: false,
                style: column?.type == ReportColumnType.money
                    ? moneyTextStyle(
                        fontSize: 13,
                        fontWeight: weight,
                        color: color,
                      )
                    : _labelStyle(context).copyWith(
                        fontWeight: weight,
                        color: color,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

TextStyle _labelStyle(BuildContext context) =>
    TextStyle(fontSize: 13, height: 1.2, color: context.inTheme.ink);

/// A cell's box: the shared horizontal padding, content centred on the line.
class _CellBox extends StatelessWidget {
  const _CellBox({required this.child, this.alignEnd = false, this.indent = 0});

  final Widget child;
  final bool alignEnd;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: _kCellPadding + indent,
        end: _kCellPadding,
      ),
      child: Align(
        alignment: alignEnd
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: child,
      ),
    );
  }
}

/// A figure in a totals or group line; blank where the column has none.
class _TotalCell extends StatelessWidget {
  const _TotalCell({
    required this.column,
    required this.figure,
    required this.formatter,
    this.strong = false,
  });

  final ReportColumn column;
  final _Figure? figure;
  final Formatter? formatter;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final figure = this.figure;
    if (figure == null) return const SizedBox.shrink();
    final tokens = context.inTheme;
    final text = reportValueText(
      figure.value,
      column: column,
      formatter: formatter,
      currencyId: figure.currencyId,
    );
    final weight = strong ? FontWeight.w600 : FontWeight.w500;
    final color = figure.foreign ? tokens.ink2 : tokens.ink;
    return _CellBox(
      alignEnd: true,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: column.type == ReportColumnType.money
            ? moneyTextStyle(fontSize: 13, fontWeight: weight, color: color)
            : _labelStyle(context).copyWith(
                fontWeight: weight,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
      ),
    );
  }
}

/// A column's header: its name, how the table is sorted by it, a menu, and —
/// with a pointer — an edge to drag.
class _HeaderCell extends StatefulWidget {
  const _HeaderCell({
    required this.vm,
    required this.column,
    required this.width,
    required this.isGroupColumn,
    required this.onFilter,
  });

  final ReportsViewModel vm;
  final ReportColumn column;
  final double width;
  final bool isGroupColumn;
  final VoidCallback onFilter;

  @override
  State<_HeaderCell> createState() => _HeaderCellState();
}

class _HeaderCellState extends State<_HeaderCell> {
  /// The width while a drag is in progress — its own running total, so the
  /// drag does not lose the fraction a clamp or a rebuild rounded away.
  double? _dragWidth;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final vm = widget.vm;
    final column = widget.column;
    final id = column.identifier;
    final numeric = isReportColumnNumeric(column.type);
    final isPrimary = vm.sortField == id;
    final thenAt = vm.thenBy.indexWhere((s) => s.columnId == id);
    final sorted = isPrimary || thenAt >= 0;
    final ascending = isPrimary
        ? vm.sortAscending
        : (thenAt >= 0 && vm.thenBy[thenAt].ascending);
    final filtered = vm.columnFilters.containsKey(id);
    final tr = context.tr;

    final label = Text(
      column.displayLabel.toUpperCase(),
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: sorted ? tokens.ink2 : tokens.ink3,
      ),
    );
    final marks = [
      if (sorted)
        Icon(
          ascending ? Icons.arrow_upward : Icons.arrow_downward,
          size: 12,
          color: tokens.ink2,
        ),
      // Which key this is, once there is more than one to tell apart.
      if (sorted && vm.thenBy.isNotEmpty)
        Text(
          '${isPrimary ? 1 : thenAt + 2}',
          style: TextStyle(fontSize: 10, color: tokens.ink2),
        ),
      if (filtered) Icon(Icons.filter_alt, size: 12, color: tokens.accentInk),
    ];

    final sortState = !sorted
        ? ''
        : ', ${tr(ascending ? 'ascending' : 'descending')}';
    final touch = Env.isTouchPrimary;
    final content = Padding(
      padding: EdgeInsetsDirectional.only(
        start: _kCellPadding,
        end: touch ? _kCellPadding : 2,
      ),
      child: Row(
        mainAxisAlignment: numeric
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Flexible(child: label),
          for (final mark in marks) ...[const SizedBox(width: 3), mark],
        ],
      ),
    );

    if (touch) {
      // A finger gets one target per column, and it is the whole header: it
      // opens the menu, which leads with the two sorts. A header that
      // sorted on tap *and* carried a 44 px menu button beside its name
      // spent a third of a phone's table on buttons.
      return _ColumnMenu(
        vm: vm,
        column: column,
        isGroupColumn: widget.isGroupColumn,
        onFilter: widget.onFilter,
        builder: (context, controller) {
          void toggle() =>
              controller.isOpen ? controller.close() : controller.open();
          return Semantics(
            button: true,
            label: '${column.displayLabel}$sortState: ${tr('more_actions')}',
            onTap: toggle,
            child: ExcludeSemantics(
              child: InkWell(onTap: toggle, child: content),
            ),
          );
        },
      );
    }

    final body = Semantics(
      button: true,
      label: '${tr('sort')}: ${column.displayLabel}$sortState',
      onTap: () => vm.toggleSort(id),
      child: ExcludeSemantics(
        child: InkWell(
          onTap: () => vm.toggleSort(
            id,
            // A shift-click adds this column behind the current sort.
            additive: HardwareKeyboard.instance.isShiftPressed,
          ),
          child: content,
        ),
      ),
    );

    final extent = 24.0;
    final menu = _ColumnMenu(
      vm: vm,
      column: column,
      isGroupColumn: widget.isGroupColumn,
      onFilter: widget.onFilter,
      // The menu button appears on hover, and stays while a filter is on so
      // there is always a way back to it.
      builder: (context, controller) => Visibility(
        visible: _hovered || filtered || controller.isOpen,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        maintainSemantics: true,
        maintainInteractivity: true,
        child: IconButton(
          tooltip: '${column.displayLabel}: ${tr('more_actions')}',
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
          icon: Icon(Icons.more_vert, size: 16, color: tokens.ink3),
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            fixedSize: Size(extent, extent),
            minimumSize: Size.zero,
            maximumSize: Size.infinite,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: body),
              Center(child: menu),
              const SizedBox(width: 4),
            ],
          ),
          PositionedDirectional(
            end: 0,
            top: 0,
            bottom: 0,
            child: _ResizeHandle(
              active: _dragWidth != null,
              onStart: () => setState(() => _dragWidth = widget.width),
              onUpdate: (dx) {
                final next = ((_dragWidth ?? widget.width) + dx)
                    .clamp(kReportColumnMinWidth, kReportColumnMaxWidth)
                    .toDouble();
                setState(() => _dragWidth = next);
                // Applied as it moves, so the column follows the pointer.
                // It reaches disk once: the view model's write is
                // debounced, and a drag keeps pushing it back.
                vm.setColumnWidth(id, next);
              },
              onEnd: () => setState(() => _dragWidth = null),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({
    required this.active,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final bool active;
  final VoidCallback onStart;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Not a control a screen reader can use; widths are a pointer nicety.
        excludeFromSemantics: true,
        onHorizontalDragStart: (_) => onStart(),
        onHorizontalDragUpdate: (d) => onUpdate(rtl ? -d.delta.dx : d.delta.dx),
        onHorizontalDragEnd: (_) => onEnd(),
        onHorizontalDragCancel: onEnd,
        child: SizedBox(
          width: 7,
          child: Center(
            child: SizedBox(
              width: active ? 2 : 1,
              child: ColoredBox(
                color: active ? context.inTheme.accent : context.inTheme.border,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What can be done with a column: sort by it, filter it, group by it, hide
/// it.
class _ColumnMenu extends StatelessWidget {
  const _ColumnMenu({
    required this.vm,
    required this.column,
    required this.isGroupColumn,
    required this.onFilter,
    required this.builder,
  });

  final ReportsViewModel vm;
  final ReportColumn column;
  final bool isGroupColumn;
  final VoidCallback onFilter;

  /// What opens the menu: a button beside the header with a pointer, the
  /// header itself under a finger.
  final Widget Function(BuildContext context, MenuController controller)
  builder;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final id = column.identifier;
    final filtered = vm.columnFilters.containsKey(id);
    return BackDismissibleMenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.arrow_upward, size: 16),
          onPressed: () => vm.setSort(id),
          child: Text('${tr('sort')}: ${tr('ascending')}'),
        ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.arrow_downward, size: 16),
          onPressed: () => vm.setSort(id, ascending: false),
          child: Text('${tr('sort')}: ${tr('descending')}'),
        ),
        const Divider(height: 1),
        MenuItemButton(
          leadingIcon: const Icon(Icons.filter_alt_outlined, size: 16),
          onPressed: onFilter,
          child: Text(tr('filter')),
        ),
        if (filtered)
          MenuItemButton(
            leadingIcon: const Icon(Icons.filter_alt_off_outlined, size: 16),
            onPressed: () => vm.clearColumnFilter(id),
            child: Text(tr('clear')),
          ),
        if (!isGroupColumn)
          MenuItemButton(
            leadingIcon: const Icon(Icons.segment, size: 16),
            onPressed: () => vm.groupBy(id),
            child: Text(tr('group_by')),
          ),
        if (!isGroupColumn)
          MenuItemButton(
            leadingIcon: const Icon(Icons.visibility_off_outlined, size: 16),
            onPressed: () =>
                vm.setVisibleColumns({...vm.visibleColumnIds}..remove(id)),
            child: Text(tr('hide')),
          ),
      ],
      builder: (context, controller, _) => builder(context, controller),
    );
  }
}

/// The table's lines, as a sliver: built only where they are on screen.
class ReportTableRows extends StatelessWidget {
  const ReportTableRows({
    super.key,
    required this.vm,
    required this.view,
    required this.lines,
    required this.formatter,
    required this.currencyId,
    this.summary,
  });

  final ReportsViewModel vm;
  final ReportView view;
  final List<ReportTableLine> lines;
  final Formatter? formatter;
  final String currencyId;

  /// Non-null draws each group line full width with this one figure.
  final ReportTableSummary? summary;

  @override
  Widget build(BuildContext context) {
    final height = reportTableRowHeight(context);
    return SliverFixedExtentList(
      itemExtent: height,
      delegate: SliverChildBuilderDelegate(
        (context, i) {
          final line = lines[i];
          return switch (line) {
            ReportTableGroupLine() => _GroupRow(
              vm: vm,
              view: view,
              line: line,
              formatter: formatter,
              currencyId: currencyId,
              height: height,
              summary: summary,
            ),
            ReportTableRowLine() => _DataRow(
              view: view,
              line: line,
              formatter: formatter,
              height: height,
            ),
          };
        },
        childCount: lines.length,
        // Rows hold no state worth keeping alive off screen, and a repaint
        // boundary each would be thousands of layers for no saved paint.
        addAutomaticKeepAlives: false,
      ),
    );
  }
}

/// The surface every body line sits on: the card's sides and a hairline
/// beneath, with ink for the lines that go somewhere.
class _RowSurface extends StatelessWidget {
  const _RowSurface({required this.child, this.onTap, this.semanticsLabel});

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final hover = Theme.of(context).brightness == Brightness.light
        ? tokens.surfaceAlt
        : Color.alphaBlend(tokens.ink.withAlpha(0x14), tokens.surface);
    final surface = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: tokens.border),
          right: BorderSide(color: tokens.border),
          bottom: BorderSide(color: tokens.border),
        ),
      ),
      child: Material(
        color: tokens.surface,
        child: onTap == null
            ? child
            : InkWell(onTap: onTap, hoverColor: hover, child: child),
      ),
    );
    if (onTap == null || semanticsLabel == null) return surface;
    return Semantics(
      button: true,
      label: semanticsLabel,
      onTap: onTap,
      child: ExcludeSemantics(child: surface),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.vm,
    required this.view,
    required this.line,
    required this.formatter,
    required this.currencyId,
    required this.height,
    this.summary,
  });

  final ReportsViewModel vm;
  final ReportView view;
  final ReportTableGroupLine line;
  final Formatter? formatter;
  final String currencyId;
  final double height;
  final ReportTableSummary? summary;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final columns = ReportTableScrollScope.of(context).layout.columns;
    final label = _label(context);
    final count = context.tr(line.count == 1 ? 'row' : 'rows');
    final summary = this.summary;
    final indent = line.depth * _kIndent - 4;
    final name = Row(
      children: [
        Icon(
          line.expanded ? Icons.expand_more : Icons.chevron_right,
          size: 18,
          color: tokens.ink2,
        ),
        const SizedBox(width: 2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _labelStyle(context).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${line.count}',
          style: TextStyle(fontSize: 12, color: tokens.ink3),
        ),
      ],
    );
    return _RowSurface(
      onTap: () => vm.toggleGroupExpanded(line.id),
      semanticsLabel:
          '$label, ${line.count} $count, '
          '${context.tr(line.expanded ? 'collapse' : 'expand')}',
      child: summary != null
          ? _SummaryLine(
              height: height,
              indent: indent,
              label: name,
              // The count is already beside the name.
              figure: summary.isCount
                  ? null
                  : _figureOf(line.totals[summary.measureId], currencyId),
              summary: summary,
              formatter: formatter,
            )
          : ReportTableLineFrame(
              height: height,
              leading: _CellBox(indent: indent, child: name),
              cells: [
                for (var i = 1; i < columns.length; i++)
                  _TotalCell(
                    column: columns[i],
                    figure: _figureOf(
                      line.totals[columns[i].identifier],
                      currencyId,
                    ),
                    formatter: formatter,
                  ),
              ],
            ),
    );
  }

  String _label(BuildContext context) {
    if (line.isPeriod) {
      // A period under a group: labelled as the bare date bucket it is.
      final text = reportGroupDisplayLabel(
        key: line.labelKey,
        columnType: ReportColumnType.date,
        subgroup: vm.subgroup ?? ReportSubgroup.month,
        formatter: formatter,
      );
      return text.isEmpty ? '—' : text;
    }
    final text = reportGroupDisplayLabel(
      key: line.labelKey,
      columnType: vm.groupColumn?.type,
      subgroup: vm.subgroup,
      formatter: formatter,
    );
    return text.isEmpty ? '—' : text;
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({
    required this.view,
    required this.line,
    required this.formatter,
    required this.height,
  });

  final ReportView view;
  final ReportTableRowLine line;
  final Formatter? formatter;
  final double height;

  @override
  Widget build(BuildContext context) {
    final columns = ReportTableScrollScope.of(context).layout.columns;
    final row = line.row;
    final route = reportRowRoute(context, row);
    Widget cell(int i, {double indent = 0}) {
      final column = columns[i];
      final index = view.cellIndexByColumn[column.identifier];
      if (index == null || index >= row.cells.length) {
        return const SizedBox.shrink();
      }
      return _DataCell(
        cell: row.cells[index],
        column: column,
        formatter: formatter,
        rowCurrencyId: row.currencyId,
        indent: indent,
      );
    }

    return _RowSurface(
      onTap: route == null ? null : () => context.go(route),
      semanticsLabel: route == null ? null : context.tr('open'),
      child: ReportTableLineFrame(
        height: height,
        leading: cell(0, indent: line.depth * _kIndent),
        cells: [for (var i = 1; i < columns.length; i++) cell(i)],
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  const _DataCell({
    required this.cell,
    required this.column,
    required this.formatter,
    required this.rowCurrencyId,
    this.indent = 0,
  });

  final ReportCell cell;
  final ReportColumn column;
  final Formatter? formatter;
  final String? rowCurrencyId;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final text = reportCellText(
      context,
      cell,
      column,
      formatter,
      rowCurrencyId: rowCurrencyId,
    );
    if (text.isEmpty) return const SizedBox.shrink();
    final numeric = isReportColumnNumeric(column.type);
    if (isReportStatusColumn(column) && cell is ReportStringCell) {
      final tone = reportStatusTone(context, text);
      return _CellBox(
        indent: indent,
        child: StatusPill(label: text, fgColor: tone.fg, bgColor: tone.bg),
      );
    }
    final isZero =
        cell is ReportNumberCell &&
        (cell as ReportNumberCell).value == Decimal.zero;
    final TextStyle style;
    if (column.type == ReportColumnType.money) {
      style = moneyTextStyle(
        fontSize: 13,
        // A zero is the least interesting figure in a column of amounts.
        color: isZero ? tokens.ink3 : tokens.ink,
      );
    } else {
      style = _labelStyle(context).copyWith(
        color: isZero ? tokens.ink3 : tokens.ink,
        fontFeatures: numeric ? const [FontFeature.tabularFigures()] : null,
      );
    }
    return _CellBox(
      alignEnd: numeric,
      indent: indent,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

/// The foot of the table's card: its bottom edge and corners. A sliver of
/// its own because the rows above it are a lazily built list with no last
/// child to round.
class ReportTableFoot extends StatelessWidget {
  const ReportTableFoot({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    const radius = Radius.circular(InRadii.r3);
    return Container(
      height: InRadii.r3,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(
          left: BorderSide(color: tokens.border),
          right: BorderSide(color: tokens.border),
          bottom: BorderSide(color: tokens.border),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: radius,
          bottomRight: radius,
        ),
      ),
    );
  }
}

/// A horizontal scroll that moves the table's columns and nothing else.
///
/// It wraps the page's vertical scroll view, so a sideways drag, a trackpad
/// swipe or a shift-wheel anywhere over the table is this scrollable's — and
/// the framework gives it a scrollbar along the bottom of the page on
/// desktop for free. Nothing under it is actually moved by it: the table's
/// lines read [ReportTableScrollScope] and shift themselves.
class ReportTableHorizontalScroll extends StatelessWidget {
  const ReportTableHorizontalScroll({
    super.key,
    required this.layout,
    required this.child,
    this.controller,
  });

  final ReportTableLayout layout;
  final Widget child;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return Scrollable(
      axisDirection: Directionality.of(context) == TextDirection.rtl
          ? AxisDirection.left
          : AxisDirection.right,
      controller: controller,
      // Nothing to scroll: stay out of the gesture arena entirely, so a
      // sideways swipe is still the shell's (an edge-swipe back, a drawer).
      physics: layout.scrolls
          ? const ClampingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      viewportBuilder: (context, offset) => ReportTableScrollExtent(
        offset: offset,
        viewport: layout.scrollViewport,
        content: layout.scrollContent,
        child: ReportTableScrollScope(
          offset: offset,
          layout: layout,
          child: child,
        ),
      ),
    );
  }
}

/// The table as slivers of the page's own scroll view: its pinned top, its
/// lines, and its foot — each inset by [gutter] at the sides.
///
/// Slivers of the page, not a scroll view of its own, so the report has one
/// vertical scroll: the summary above scrolls away, the header and totals
/// pin when they reach the top, and the rows carry on beneath them. A table
/// with its own scroll inside a scrolling page is the arrangement where the
/// wheel stops working halfway down.
List<Widget> buildReportTableSlivers(
  BuildContext context, {
  required ReportsViewModel vm,
  required ReportView view,
  required List<ReportTableLine> lines,
  required Formatter? formatter,
  required String currencyId,
  required String? currencyLabel,
  required ValueChanged<ReportColumn> onFilter,
  required double gutter,
  ReportTableSummary? summary,
}) {
  final tokens = context.inTheme;
  // One figure per line only makes sense for lines that are groups.
  final lineSummary = view.groups.isEmpty ? null : summary;
  final inset = EdgeInsets.symmetric(horizontal: gutter);
  return [
    PinnedHeaderSliver(
      // Opaque in the page's colour: rows scroll *under* the pinned top, and
      // would otherwise show through its rounded corners and the gutters.
      child: ColoredBox(
        color: tokens.bg,
        child: Padding(
          padding: inset,
          child: ReportTableHeader(
            vm: vm,
            view: view,
            formatter: formatter,
            currencyId: currencyId,
            currencyLabel: currencyLabel,
            onFilter: onFilter,
            summary: lineSummary,
          ),
        ),
      ),
    ),
    SliverPadding(
      padding: inset,
      sliver: ReportTableRows(
        vm: vm,
        view: view,
        lines: lines,
        formatter: formatter,
        currencyId: currencyId,
        summary: lineSummary,
      ),
    ),
    SliverPadding(
      padding: inset,
      sliver: const SliverToBoxAdapter(child: ReportTableFoot()),
    ),
  ];
}
