import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/design_block_layout.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_menu.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_renderers/_shared.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/block_preview.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/drop_resolver.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/page_metrics.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/sample/sample_data.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';
import 'package:admin/utils/formatting.dart';

/// What is being dragged over the canvas.
sealed class CanvasDropPayload {
  const CanvasDropPayload();
}

/// A new block, from the palette.
class PalettePayload extends CanvasDropPayload {
  const PalettePayload(this.spec);
  final BlockSpec spec;
}

/// A block already on the page.
class BlockMovePayload extends CanvasDropPayload {
  const BlockMovePayload(this.blockId);
  final String blockId;
}

/// A whole row, by its grip.
class RowMovePayload extends CanvasDropPayload {
  const RowMovePayload(this.rowIndex);
  final int rowIndex;
}

/// Space between the page and the edge of its pane.
const double _kPanePadding = 24;

/// The designer's canvas: the page as it will print.
///
/// A sheet at its true size (`DesignerPageMetrics`), scaled down to fit the
/// pane and scrolling when the layout runs long. On it, the rows the server
/// will print (`rowsOf`), each as tall as its content — there is no grid and
/// nothing has a height to drag, because the PDF has neither
/// (`docs/invoice-designer.md`).
///
/// A block is dragged to the space between two rows (a row of its own) or to
/// the side of another block (into that row); a bar shows which. The selected
/// block has a handle on each side that moves that edge by whole columns.
/// Everything a drag can do is also in the block's menu.
class WysiwygCanvas extends StatefulWidget {
  const WysiwygCanvas({
    super.key,
    required this.vm,
    this.sample,
    this.formatter,
    this.bottomInset = 0,
  });

  final WysiwygDesignViewModel vm;

  /// Extra room under the page, for whatever floats over the pane's bottom
  /// edge (the "Add block" button) — so the last row can scroll clear of it.
  final double bottomInset;

  /// The document the blocks are filled from. Defaults to the fixture.
  final DesignerSampleData? sample;

  /// The company's formatter, for amounts and dates.
  final Formatter? formatter;

  @override
  State<WysiwygCanvas> createState() => _WysiwygCanvasState();
}

class _DisplayRow {
  const _DisplayRow(this.index, this.cells, this.slots);
  final int index;

  /// The row with its empty space spelled out as gap cells
  /// ([explicitRow]) — what the user would get by touching it.
  final DesignRow cells;
  final List<RowSlot> slots;
}

class _WysiwygCanvasState extends State<WysiwygCanvas> {
  static final ThemeData _paperTheme = buildInTheme(InTheme.light);

  final ScrollController _scroll = ScrollController();

  /// The block content's box: the coordinate space drops are resolved in.
  final GlobalKey _contentKey = GlobalKey(debugLabel: 'designer content');
  final GlobalKey _selectedCellKey = GlobalKey(debugLabel: 'selected block');
  final List<GlobalKey> _rowKeys = [];

  /// Anchors for the two bits of chrome that sit *outside* a block's own box
  /// — its chip and its row's grip. They are followers in a layer above the
  /// page rather than children of the block, because a child drawn outside
  /// its parent's bounds cannot be hit: that is what once made the selection
  /// toolbar of a block at the top of the page unclickable.
  final LayerLink _blockLink = LayerLink();
  final LayerLink _rowLink = LayerLink();

  final ValueNotifier<ResolvedDrop?> _drop = ValueNotifier<ResolvedDrop?>(null);
  final ValueNotifier<String?> _hovered = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _dragging = ValueNotifier<bool>(false);

  List<_DisplayRow> _display = const [];
  double _layoutWidth = 1;
  double _scale = 1;

  EdgeDraggingAutoScroller? _autoScroller;
  Offset? _lastPointer;
  CanvasDropPayload? _payload;

  // Width-handle gesture.
  double _resizeStartX = 0;
  int _resizeRow = 0;
  int _resizeBoundary = 0;
  int _resizeCols = 0;

  String? _revealedSelection;

  WysiwygDesignViewModel get vm => widget.vm;

  @override
  void dispose() {
    // A drag in progress will never report its end now.
    vm.endGesture();
    _autoScroller?.stopAutoScroll();
    _scroll.dispose();
    _drop.dispose();
    _hovered.dispose();
    _dragging.dispose();
    super.dispose();
  }

  // ── Drag and drop ─────────────────────────────────────────────────

  void _onDragMove(DragTargetDetails<CanvasDropPayload> details) {
    _payload = details.data;
    _lastPointer = details.offset;
    _dragging.value = true;
    _resolve();
    if (_scroll.hasClients) {
      final scroller = _autoScroller ??= EdgeDraggingAutoScroller(
        _scroll.position.context as ScrollableState,
        onScrollViewScrolled: _onAutoScrolled,
        velocityScalar: 20,
      );
      scroller.startAutoScrollIfNecessary(_scrollProbe(details.offset));
    }
  }

  /// A box around the pointer: once it pokes past the viewport's edge the
  /// page scrolls.
  Rect _scrollProbe(Offset pointer) =>
      Rect.fromCenter(center: pointer, width: 40, height: 96);

  /// The scroller moves the page one step and stops; asking again is what
  /// keeps it going under a pointer held still at the edge (`ReorderableList`
  /// does the same). Without this the page crept 48px and waited for the
  /// pointer to move.
  void _onAutoScrolled() {
    _resolve();
    final pointer = _lastPointer;
    if (pointer != null) {
      _autoScroller?.startAutoScrollIfNecessary(_scrollProbe(pointer));
    }
  }

  void _endDrag() {
    _autoScroller?.stopAutoScroll();
    _lastPointer = null;
    _payload = null;
    _drop.value = null;
    _dragging.value = false;
  }

  /// Work out where the dragged thing would land, in the content's own
  /// (unscaled) coordinates — `globalToLocal` undoes the page's scaling.
  void _resolve() {
    final pointer = _lastPointer;
    final payload = _payload;
    final content = _contentKey.currentContext?.findRenderObject();
    if (pointer == null || payload == null || content is! RenderBox) return;
    final local = content.globalToLocal(pointer);

    final rows = <DropRow>[];
    for (final row in _display) {
      final box = _rowKeys[row.index].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: content).dy;
      rows.add(
        DropRow(
          top: top,
          bottom: top + box.size.height,
          cells: [
            for (final slot in row.slots)
              DropCell(
                id: slot.block.id,
                left: slot.left,
                right: slot.right,
                isGap: isGapBlock(slot.block),
              ),
          ],
        ),
      );
    }

    final thickness = 3 / _scale;
    if (payload is RowMovePayload) {
      // A row only ever goes between rows.
      var index = 0;
      for (final row in rows) {
        if (local.dy > (row.top + row.bottom) / 2) index++;
      }
      final y = rows.isEmpty
          ? 0.0
          : index >= rows.length
          ? rows.last.bottom + kDesignerRowGapPx / 2
          : rows[index].top - kDesignerRowGapPx / 2;
      _drop.value = ResolvedDrop(
        DropNewRow(index),
        Rect.fromLTWH(0, y - thickness / 2, _layoutWidth, thickness),
      );
      return;
    }

    final movingId = payload is BlockMovePayload ? payload.blockId : null;
    _drop.value = resolveDrop(
      point: local,
      rows: rows,
      width: _layoutWidth,
      thickness: thickness,
      edgeBand: 14 / _scale,
      movingId: movingId,
      canJoin: (anchorId) => switch (payload) {
        PalettePayload(:final spec) => vm.canPlaceBeside(
          anchorId,
          type: spec.type,
        ),
        BlockMovePayload(:final blockId) => vm.canPlaceBeside(
          anchorId,
          movingId: blockId,
        ),
        RowMovePayload() => false,
      },
    );
  }

  void _onDrop(DragTargetDetails<CanvasDropPayload> details) {
    _payload = details.data;
    _lastPointer = details.offset;
    _resolve();
    final target = _drop.value?.target;
    final payload = details.data;
    _endDrag();
    if (target == null) {
      if (payload is PalettePayload) vm.addBlock(payload.spec);
      return;
    }
    switch ((payload, target)) {
      case (PalettePayload(:final spec), DropNewRow(:final rowIndex)):
        vm.insertRow(spec, rowIndex);
      case (
        PalettePayload(:final spec),
        DropBeside(:final anchorId, :final before),
      ):
        vm.insertBeside(spec, anchorId, before: before);
      case (BlockMovePayload(:final blockId), DropNewRow(:final rowIndex)):
        vm.moveBlockToNewRow(blockId, rowIndex);
      case (
        BlockMovePayload(:final blockId),
        DropBeside(:final anchorId, :final before),
      ):
        vm.moveBlockBeside(blockId, anchorId, before: before);
      case (RowMovePayload(:final rowIndex), DropNewRow(rowIndex: final to)):
        vm.moveRow(rowIndex, to > rowIndex ? to - 1 : to);
      case (RowMovePayload(), DropBeside()):
        break;
    }
  }

  // ── Width handles ─────────────────────────────────────────────────

  void _resizeStart(double globalX, int rowIndex, int boundary) {
    vm.beginGesture();
    _resizeStartX = globalX;
    _resizeRow = rowIndex;
    _resizeBoundary = boundary;
    _resizeCols = 0;
  }

  void _resizeUpdate(double globalX) {
    // One column on screen, gaps included — near enough for snapping.
    final column = _layoutWidth / kDesignerGridCols * _scale;
    final cols = ((globalX - _resizeStartX) / column).round();
    if (cols == _resizeCols) return;
    _resizeCols = cols;
    vm.dragBoundary(_resizeRow, _resizeBoundary, cols);
  }

  void _resizeEnd() => vm.endGesture();

  // ── Selection ─────────────────────────────────────────────────────

  void _select(String id) {
    if (vm.selectedBlockId == id) {
      // A second press on the selected block goes for its text.
      vm.requestContentFocus();
    } else {
      vm.selectBlock(id);
    }
  }

  /// Open a block's menu from the canvas's own context — not the cell's.
  /// The menu selects the block, and selecting re-keys the cell, so a menu
  /// opened on the cell's context lost it before an entry could be picked
  /// (right-click → Duplicate on an unselected block did nothing). The cell
  /// is also inside the page's light theme, which the menu must not inherit.
  void _openBlockMenu(String id, Offset globalPosition) =>
      showBlockMenu(context, vm, id, globalPosition: globalPosition);

  /// Scroll a newly selected block into view — one just added from the
  /// palette lands wherever its row is, which may be off-screen.
  void _revealSelection() {
    final id = vm.selectedBlockId;
    if (id == _revealedSelection) return;
    _revealedSelection = id;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final cell = _selectedCellKey.currentContext?.findRenderObject();
      final viewport = context.findRenderObject();
      if (cell is! RenderBox || viewport is! RenderBox || !cell.hasSize) return;
      final top = cell.localToGlobal(Offset.zero, ancestor: viewport).dy;
      final bottom = cell
          .localToGlobal(Offset(0, cell.size.height), ancestor: viewport)
          .dy;
      const margin = 40.0;
      double? delta;
      if (top < margin) {
        delta = top - margin;
      } else if (bottom > viewport.size.height - margin) {
        delta = math.min(bottom - viewport.size.height + margin, top - margin);
      }
      if (delta == null || delta.abs() < 1) return;
      final position = _scroll.position;
      _scroll.animateTo(
        (position.pixels + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final settings = vm.documentSettings;
    final metrics = DesignerPageMetrics.of(settings);
    final rows = vm.rows;
    while (_rowKeys.length < rows.length) {
      _rowKeys.add(GlobalKey(debugLabel: 'designer row ${_rowKeys.length}'));
    }
    final display = <_DisplayRow>[];
    for (var i = 0; i < rows.length; i++) {
      var n = 0;
      final cells = explicitRow(rows[i], (_) => 'display-gap-$i-${n++}');
      if (cells.isEmpty) continue;
      display.add(_DisplayRow(i, cells, layoutRow(cells, metrics.layoutWidth)));
    }
    _display = display;
    _layoutWidth = metrics.layoutWidth;
    _revealSelection();

    final selectedId = vm.selectedBlockId;
    final selectedAt = selectedId == null
        ? null
        : locateBlock(rows, selectedId);
    final sample = widget.sample ?? DesignerSampleData.fallback;

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - _kPanePadding * 2;
        final fit = (available / metrics.size.width).clamp(0.1, 1.0);
        final scale = fit * kDesignerBodyZoom;
        _scale = scale;

        final content = Stack(
          key: _contentKey,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (display.isEmpty) const _EmptyPage(),
                for (final row in display)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: row == display.last ? 0 : kDesignerRowGapPx,
                    ),
                    child: _linked(
                      _rowLink,
                      selectedAt?.row == row.index && row.cells.length > 1,
                      _RowView(
                        key: _rowKeys[row.index],
                        row: row,
                        vm: vm,
                        sample: sample,
                        scale: scale,
                        accent: tokens.accent,
                        selectedId: selectedId,
                        selectedCellKey: _selectedCellKey,
                        blockLink: _blockLink,
                        hovered: _hovered,
                        dragging: _dragging,
                        onSelect: _select,
                        onMenu: _openBlockMenu,
                      ),
                    ),
                  ),
              ],
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: ValueListenableBuilder<ResolvedDrop?>(
                  valueListenable: _drop,
                  builder: (_, drop, _) => drop == null
                      ? const SizedBox.shrink()
                      : CustomPaint(
                          painter: _DropPainter(drop.indicator, tokens.accent),
                        ),
                ),
              ),
            ),
          ],
        );

        final sheet = _Sheet(
          metrics: metrics,
          fontName: settings.primaryFont,
          fontSize: settings.globalFontSize.toDouble(),
          formatter: widget.formatter,
          theme: _paperTheme,
          child: content,
        );

        final selected = selectedAt == null
            ? null
            : rows[selectedAt.row][selectedAt.index];
        // Whether the selected block starts its row — it then has the
        // page's margin to its left.
        final atRowStart =
            selectedAt != null &&
            display.any(
              (d) =>
                  d.index == selectedAt.row && d.cells.first.id == selected?.id,
            );
        // The selected block's place among its row's cells *as drawn* —
        // gaps included — which is what the width handles count edges in.
        var selectedCell = -1;
        if (selectedAt != null) {
          for (final d in display) {
            if (d.index != selectedAt.row) continue;
            selectedCell = d.cells.indexWhere((c) => c.id == selected?.id);
          }
        }
        // A grip only where it adds something: a row with more than one
        // cell. A block alone in its row is moved by dragging the block.
        final showGrip =
            selectedAt != null &&
            display.any((d) => d.index == selectedAt.row && d.cells.length > 1);
        return DragTarget<CanvasDropPayload>(
          onWillAcceptWithDetails: (_) => true,
          onMove: _onDragMove,
          onLeave: (_) => _endDrag(),
          onAcceptWithDetails: _onDrop,
          builder: (context, _, _) => ColoredBox(
            color: tokens.bg,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => vm.selectBlock(null),
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Stack(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          _kPanePadding,
                          _kPanePadding,
                          _kPanePadding,
                          _kPanePadding + widget.bottomInset,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: metrics.size.width * fit,
                            child: FittedBox(
                              fit: BoxFit.fitWidth,
                              alignment: Alignment.topCenter,
                              child: sheet,
                            ),
                          ),
                        ),
                      ),
                      if (selected != null)
                        ..._selectionChrome(
                          selected: selected,
                          rowIndex: selectedAt!.row,
                          cellIndex: selectedCell,
                          atRowStart: atRowStart,
                          showGrip: showGrip,
                          // Room beside the page for the tab: the page's own
                          // margin plus the pane's padding.
                          gutter: metrics.insetLeft * fit + _kPanePadding,
                          scale: scale,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The selected block's tab and, for a row of several cells, the row's
  /// grip — followers in the layer above the page.
  ///
  /// The tab goes in the page's left margin, level with the block's top,
  /// whenever the block starts its row and the margin is wide enough: there
  /// it covers nothing. Otherwise it sits above the block's corner, over the
  /// end of the row above. The grip takes the margin beside the row's middle,
  /// or drops under the tab when both are there.
  List<Widget> _selectionChrome({
    required DesignBlock selected,
    required int rowIndex,
    required int cellIndex,
    required bool atRowStart,
    required bool showGrip,
    required double gutter,
    required double scale,
  }) {
    final tokens = context.inTheme;
    final tab = _BlockChip(vm: vm, block: selected);
    final grip = _RowGrip(vm: vm, rowIndex: rowIndex);
    Widget follower({
      required LayerLink link,
      required Alignment target,
      required Alignment anchor,
      required Offset offset,
      required Widget child,
    }) => Positioned(
      left: 0,
      top: 0,
      child: CompositedTransformFollower(
        link: link,
        showWhenUnlinked: false,
        targetAnchor: target,
        followerAnchor: anchor,
        offset: offset,
        // The follower inherits the page's scaling; undo it so the chrome
        // is a constant size on screen.
        child: Transform.scale(
          scale: 1 / scale,
          alignment: anchor,
          child: child,
        ),
      ),
    );

    // The two width handles, centred on the block's vertical edges. In the
    // layer above the page, like the tab: a handle drawn as a child of the
    // row reached past the content box at the row's ends, and nothing out
    // there is hit-tested — on a block alone in its row neither grip could
    // be pressed. Sized to the grip rather than to the block's height, so a
    // press on the block beside its edge still reaches the block.
    final handles = cellIndex < 0
        ? const <Widget>[]
        : [
            for (final (target, boundary, side) in [
              (Alignment.centerLeft, cellIndex, 'L'),
              (Alignment.centerRight, cellIndex + 1, 'R'),
            ])
              KeyedSubtree(
                // Stable through the drag, which rebuilds the row under it.
                key: ValueKey('handle-${selected.id}-$side'),
                child: follower(
                  link: _blockLink,
                  target: target,
                  anchor: Alignment.center,
                  // The grip sits on the selection outline, just outside
                  // the block, so it never covers the first or last letter.
                  offset: Offset((side == 'L' ? -3 : 3) / scale, 0),
                  child: _WidthHandle(
                    accent: tokens.accent,
                    onStart: (gx) => _resizeStart(gx, rowIndex, boundary),
                    onUpdate: _resizeUpdate,
                    onEnd: _resizeEnd,
                  ),
                ),
              ),
          ];

    if (atRowStart && gutter >= 48) {
      return [
        ...handles,
        follower(
          link: _blockLink,
          target: Alignment.topLeft,
          anchor: Alignment.topRight,
          offset: Offset(-9 / scale, -3 / scale),
          child: showGrip
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [tab, const SizedBox(height: 4), grip],
                )
              : tab,
        ),
      ];
    }
    return [
      ...handles,
      follower(
        link: _blockLink,
        target: Alignment.topLeft,
        anchor: Alignment.bottomLeft,
        offset: Offset(-4 / scale, -5 / scale),
        child: tab,
      ),
      if (showGrip)
        follower(
          link: _rowLink,
          target: Alignment.centerLeft,
          anchor: Alignment.centerRight,
          offset: Offset(-8 / scale, 0),
          child: grip,
        ),
    ];
  }

  Widget _linked(LayerLink link, bool on, Widget child) =>
      on ? CompositedTransformTarget(link: link, child: child) : child;
}

/// The sheet of paper: true size, the document's margins, its font and size,
/// and — whatever theme the app is in — white with dark ink.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.metrics,
    required this.fontName,
    required this.fontSize,
    required this.formatter,
    required this.theme,
    required this.child,
  });

  final DesignerPageMetrics metrics;
  final String fontName;
  final double fontSize;
  final Formatter? formatter;
  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The server's body rule: `color: #374151; line-height: 1.5`.
    var style = TextStyle(
      fontSize: fontSize,
      color: const Color(0xFF374151),
      height: 1.5,
    );
    try {
      // Stored as the catalog id (`Abril_Fatface`) or as a name.
      style = GoogleFonts.getFont(
        fontName.replaceAll('_', ' '),
        textStyle: style,
      );
    } catch (_) {
      // Not a Google font this build knows — keep the default face.
    }
    return Container(
      width: metrics.size.width,
      constraints: BoxConstraints(minHeight: metrics.size.height),
      padding: EdgeInsets.fromLTRB(
        metrics.insetLeft,
        metrics.insetTop,
        metrics.insetRight,
        metrics.insetBottom,
      ),
      decoration: BoxDecoration(
        // Paper is white in either theme.
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: metrics.contentWidth,
        // The body's 80% zoom: laid out wider, painted smaller.
        child: FittedBox(
          fit: BoxFit.fitWidth,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: metrics.layoutWidth,
            child: Theme(
              data: theme,
              child: MediaQuery.withNoTextScaling(
                child: DesignerRenderScope(
                  formatter: formatter,
                  sample: DesignerRenderScope.maybeSampleOf(context),
                  customFieldLabels: DesignerRenderScope.customFieldLabelsOf(
                    context,
                  ),
                  child: DefaultTextStyle(style: style, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPage extends StatelessWidget {
  const _EmptyPage();

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 120),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 56,
            color: tokens.ink3,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('start_with_a_block'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: tokens.ink3, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _RowView extends StatelessWidget {
  const _RowView({
    super.key,
    required this.row,
    required this.vm,
    required this.sample,
    required this.scale,
    required this.accent,
    required this.selectedId,
    required this.selectedCellKey,
    required this.blockLink,
    required this.hovered,
    required this.dragging,
    required this.onSelect,
    required this.onMenu,
  });

  final _DisplayRow row;
  final WysiwygDesignViewModel vm;
  final DesignerSampleData sample;
  final double scale;
  final Color accent;
  final String? selectedId;
  final GlobalKey selectedCellKey;
  final LayerLink blockLink;
  final ValueNotifier<String?> hovered;
  final ValueNotifier<bool> dragging;
  final ValueChanged<String> onSelect;
  final void Function(String id, Offset globalPosition) onMenu;

  @override
  Widget build(BuildContext context) {
    final hasSelection = row.cells.any((c) => c.id == selectedId);
    final inline = <Widget>[];
    final overlays = <Widget>[];
    var x = 0.0;
    for (var i = 0; i < row.slots.length; i++) {
      final slot = row.slots[i];
      final block = slot.block;
      if (slot.left > x) inline.add(SizedBox(width: slot.left - x));
      x = slot.right;

      if (isGapBlock(block)) {
        inline.add(SizedBox(width: slot.width));
        overlays.add(
          Positioned(
            left: slot.left,
            width: slot.width,
            top: 0,
            bottom: 0,
            child: _GapCell(
              dragging: dragging,
              alwaysShown: hasSelection,
              scale: scale,
              accent: accent,
            ),
          ),
        );
        continue;
      }

      final selected = block.id == selectedId;
      Widget cell = _BlockCell(
        key: selected ? selectedCellKey : ValueKey('cell-${block.id}'),
        vm: vm,
        block: block,
        rowNumber: row.index + 1,
        sample: sample,
        scale: scale,
        accent: accent,
        selected: selected,
        hovered: hovered,
        dragging: dragging,
        onSelect: onSelect,
        onMenu: onMenu,
      );
      if (selected) {
        cell = CompositedTransformTarget(link: blockLink, child: cell);
      }
      inline.add(SizedBox(width: slot.width, child: cell));
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: inline),
        ...overlays,
      ],
    );
  }
}

/// Empty space in a row. Invisible on the page — it is nothing — and shown,
/// faintly, only when it matters: while something is being dragged (it is a
/// place to drop) and while its row holds the selection (its edge can be
/// moved).
class _GapCell extends StatelessWidget {
  const _GapCell({
    required this.dragging,
    required this.alwaysShown,
    required this.scale,
    required this.accent,
  });

  final ValueNotifier<bool> dragging;
  final bool alwaysShown;
  final double scale;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: dragging,
        builder: (context, isDragging, _) {
          if (!isDragging && !alwaysShown) return const SizedBox.shrink();
          return Semantics(
            label: context.tr('empty_space'),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                border: Border.all(
                  color: accent.withValues(alpha: 0.35),
                  width: 1 / scale,
                ),
                borderRadius: BorderRadius.circular(InRadii.r1 / scale),
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

class _BlockCell extends StatelessWidget {
  const _BlockCell({
    super.key,
    required this.vm,
    required this.block,
    required this.rowNumber,
    required this.sample,
    required this.scale,
    required this.accent,
    required this.selected,
    required this.hovered,
    required this.dragging,
    required this.onSelect,
    required this.onMenu,
  });

  final WysiwygDesignViewModel vm;
  final DesignBlock block;
  final int rowNumber;
  final DesignerSampleData sample;
  final double scale;
  final Color accent;
  final bool selected;
  final ValueNotifier<String?> hovered;
  final ValueNotifier<bool> dragging;
  final ValueChanged<String> onSelect;
  final void Function(String id, Offset globalPosition) onMenu;

  @override
  Widget build(BuildContext context) {
    final spec = blockSpecFor(block.type);
    final label = spec != null ? context.tr(spec.labelKey) : block.type;

    // Drawn just *outside* the block's box. Inside, it sat on the first
    // column of pixels of left-aligned text and shaved the first letter.
    final outlined = ValueListenableBuilder<String?>(
      valueListenable: hovered,
      child: BlockPreview(block: block, sample: sample),
      builder: (context, hoveredId, child) => CustomPaint(
        foregroundPainter: _OutlinePainter(
          color: selected
              ? accent
              : hoveredId == block.id
              ? accent.withValues(alpha: 0.5)
              : null,
          width: (selected ? 2 : 1.5) / scale,
          gap: 3 / scale,
          radius: InRadii.r1 / scale,
        ),
        child: child,
      ),
    );

    final interactive = MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => hovered.value = block.id,
      onExit: (_) {
        if (hovered.value == block.id) hovered.value = null;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(block.id),
        onSecondaryTapUp: (d) => onMenu(block.id, d.globalPosition),
        child: outlined,
      ),
    );

    final feedback = _DragChip(icon: spec?.icon, label: label);
    final whenDragging = Opacity(opacity: 0.35, child: outlined);
    void started() => dragging.value = true;
    void ended() => dragging.value = false;
    final payload = BlockMovePayload(block.id);

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label:
          '$label, ${context.tr('row')} $rowNumber, '
          '${block.gridPosition.w}/$kDesignerGridCols',
      onTap: () => onSelect(block.id),
      // On touch a drag starts with a long press, so the page still scrolls
      // under a finger; on a pointer it starts at once.
      child: Env.isTouchPrimary
          ? LongPressDraggable<CanvasDropPayload>(
              data: payload,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: feedback,
              childWhenDragging: whenDragging,
              onDragStarted: started,
              onDragEnd: (_) => ended(),
              onDraggableCanceled: (_, _) => ended(),
              child: interactive,
            )
          : Draggable<CanvasDropPayload>(
              data: payload,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: feedback,
              childWhenDragging: whenDragging,
              onDragStarted: started,
              onDragEnd: (_) => ended(),
              onDraggableCanceled: (_, _) => ended(),
              child: interactive,
            ),
    );
  }
}

/// What follows the pointer during a drag: the block's name, not a ghost of
/// the block. The bar on the page says where it will land; a full-size ghost
/// would only cover it.
class _DragChip extends StatelessWidget {
  const _DragChip({required this.icon, required this.label});

  final IconData? icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Transform.translate(
      offset: const Offset(12, 12),
      child: Material(
        elevation: 6,
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: tokens.ink2),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: tokens.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A draggable edge of the selected block. Moves in whole columns.
///
/// It reports the end of a drag it never finished: a recognizer that is
/// disposed mid-drag fires neither `onEnd` nor `onCancel`, and pressing Esc
/// or Delete while dragging unmounts the handle. Left open, the gesture
/// swallowed every later change's undo step — and the next drag replayed
/// from the stale start, reverting whatever had been done in between.
class _WidthHandle extends StatefulWidget {
  const _WidthHandle({
    required this.accent,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final Color accent;
  final ValueChanged<double> onStart;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;

  @override
  State<_WidthHandle> createState() => _WidthHandleState();
}

class _WidthHandleState extends State<_WidthHandle> {
  bool _dragging = false;

  void _end() {
    if (!_dragging) return;
    _dragging = false;
    widget.onEnd();
  }

  @override
  void dispose() {
    _end();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final touch = Env.isTouchPrimary;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Swallowed: a press that is not a drag used to fall through to the
        // page's background, which deselects.
        onTap: () {},
        onHorizontalDragStart: (d) {
          _dragging = true;
          widget.onStart(d.globalPosition.dx);
        },
        onHorizontalDragUpdate: (d) => widget.onUpdate(d.globalPosition.dx),
        onHorizontalDragEnd: (_) => _end(),
        onHorizontalDragCancel: _end,
        child: SizedBox(
          width: touch ? InSizes.touchTarget : 14,
          height: touch ? InSizes.touchTarget : 36,
          child: Center(
            child: Container(
              width: 5,
              height: 30,
              decoration: BoxDecoration(
                color: widget.accent,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The selected block's tab, just above its top-left corner: its icon, and
/// the button for its menu.
///
/// Deliberately small. It sits over whatever is above the block — rows are
/// only a few pixels apart — and a tab with the block's name across it hid a
/// whole line of the row above. The name is in the property panel's header.
class _BlockChip extends StatelessWidget {
  const _BlockChip({required this.vm, required this.block});

  final WysiwygDesignViewModel vm;
  final DesignBlock block;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final spec = blockSpecFor(block.type);
    final label = spec != null ? context.tr(spec.labelKey) : block.type;
    final touch = Env.isTouchPrimary;
    return Material(
      color: tokens.accent,
      borderRadius: BorderRadius.circular(InRadii.r1),
      clipBehavior: Clip.antiAlias,
      child: Builder(
        builder: (buttonContext) => InkWell(
          onTap: () {
            final box = buttonContext.findRenderObject()! as RenderBox;
            showBlockMenu(
              context,
              vm,
              block.id,
              globalPosition: box.localToGlobal(
                box.size.bottomLeft(Offset.zero),
              ),
            );
          },
          child: Semantics(
            button: true,
            label: '$label, ${context.tr('more_actions')}',
            child: SizedBox(
              height: touch ? InSizes.touchTarget : 20,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: touch ? 9 : 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (spec != null) ...[
                      Icon(spec.icon, size: 13, color: tokens.onAccent),
                      const SizedBox(width: 2),
                    ],
                    Icon(Icons.more_vert, size: 14, color: tokens.onAccent),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The handle of a row that holds more than one cell: drag it to move the
/// whole row, press it for the row's menu.
class _RowGrip extends StatelessWidget {
  const _RowGrip({required this.vm, required this.rowIndex});

  final WysiwygDesignViewModel vm;
  final int rowIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final grip = Material(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: tokens.border),
        borderRadius: BorderRadius.circular(InRadii.r1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Builder(
        builder: (gripContext) => InkWell(
          onTap: () {
            final box = gripContext.findRenderObject()! as RenderBox;
            showRowMenu(
              context,
              vm,
              rowIndex,
              globalPosition: box.localToGlobal(
                box.size.bottomLeft(Offset.zero),
              ),
            );
          },
          child: Semantics(
            button: true,
            label: context.tr('row'),
            child: SizedBox(
              width: Env.isTouchPrimary ? InSizes.touchTarget : 18,
              height: Env.isTouchPrimary ? InSizes.touchTarget : 26,
              child: Icon(Icons.drag_indicator, size: 15, color: tokens.ink3),
            ),
          ),
        ),
      ),
    );
    final feedback = _DragChip(
      icon: Icons.table_rows_outlined,
      label: context.tr('row'),
    );
    final payload = RowMovePayload(rowIndex);
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Env.isTouchPrimary
          ? LongPressDraggable<CanvasDropPayload>(
              data: payload,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: feedback,
              child: grip,
            )
          : Draggable<CanvasDropPayload>(
              data: payload,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: feedback,
              child: grip,
            ),
    );
  }
}

class _DropPainter extends CustomPainter {
  _DropPainter(this.rect, this.color);

  final Rect rect;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(rect.shortestSide / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_DropPainter old) =>
      old.rect != rect || old.color != color;
}

/// A rounded outline [gap] outside the box it is painted on.
class _OutlinePainter extends CustomPainter {
  _OutlinePainter({
    required this.color,
    required this.width,
    required this.gap,
    required this.radius,
  });

  final Color? color;
  final double width;
  final double gap;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final color = this.color;
    if (color == null) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(gap),
        Radius.circular(radius),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_OutlinePainter old) =>
      old.color != color ||
      old.width != width ||
      old.gap != gap ||
      old.radius != radius;
}
