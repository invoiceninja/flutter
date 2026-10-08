import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/data/models/domain/design_block_layout.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_menu.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/palette/component_palette.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_panel.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// The phone (<600 px) layout: the page as an outline.
///
/// A phone is too narrow to show the page at a size anyone could drag things
/// around on, so it shows the page's *structure* instead — one card per row,
/// each card split into its blocks in proportion to their widths. A card is
/// dragged to reorder its row; a block is tapped to edit it, or held for the
/// same menu the canvas has (move up, into the row above, wider…).
///
/// It used to be a flat list of blocks in the order they were added, and its
/// one gesture — a reorder — rewrote every block on the page to full width.
/// Here nothing changes that the user did not move.
class MobileReorderView extends StatelessWidget {
  const MobileReorderView({super.key, required this.vm, this.onPageSettings});

  final WysiwygDesignViewModel vm;

  /// Opens the page's settings. The toolbar has its own button for them;
  /// this is for the "Page" tab of a block's sheet, which has to close the
  /// sheet and open the page's instead.
  final VoidCallback? onPageSettings;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final (index, row) in vm.rows.indexed)
        (index: index, cells: explicitRow(row, (_) => 'outline-gap-$index')),
    ].where((r) => r.cells.isNotEmpty).toList();
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        if (rows.isEmpty)
          _EmptyOutline(vm: vm)
        else
          ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: rows.length,
            onReorderItem: (from, to) =>
                vm.moveRow(rows[from].index, rows[to].index),
            header: const _OutlineHint(),
            // Room for the add button over the last card.
            padding: EdgeInsets.only(bottom: 88 + bottomInset),
            itemBuilder: (context, i) => _RowCard(
              key: ValueKey('row-${rows[i].cells.first.id}'),
              vm: vm,
              onPageSettings: onPageSettings,
              listIndex: i,
              rowIndex: rows[i].index,
              cells: rows[i].cells,
            ),
          ),
        Positioned(
          right: InSpacing.lg(context),
          bottom: InSpacing.lg(context) + bottomInset,
          child: FloatingActionButton(
            onPressed: () => showDesignerPaletteSheet(context, vm),
            tooltip: context.tr('add_block'),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _OutlineHint extends StatelessWidget {
  const _OutlineHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        InSpacing.lg(context),
        InSpacing.md(context),
        InSpacing.lg(context),
        InSpacing.sm,
      ),
      child: Text(
        context.tr('outline_hint'),
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.inTheme.ink3),
      ),
    );
  }
}

/// One row of the page: a drag handle, then its cells side by side in
/// proportion to their widths.
class _RowCard extends StatelessWidget {
  const _RowCard({
    super.key,
    required this.vm,
    required this.listIndex,
    required this.rowIndex,
    required this.cells,
    this.onPageSettings,
  });

  final WysiwygDesignViewModel vm;
  final VoidCallback? onPageSettings;
  final int listIndex;
  final int rowIndex;
  final DesignRow cells;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.xs,
      ),
      child: Material(
        color: tokens.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: tokens.border),
          borderRadius: BorderRadius.circular(InRadii.r2),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ReorderableDragStartListener(
                index: listIndex,
                child: Semantics(
                  label: '${context.tr('row')} ${rowIndex + 1}',
                  child: SizedBox(
                    width: InSizes.touchTarget,
                    child: Icon(
                      Icons.drag_handle,
                      color: tokens.ink3,
                      size: 22,
                    ),
                  ),
                ),
              ),
              VerticalDivider(width: 1, color: tokens.border),
              for (final (i, cell) in cells.indexed) ...[
                if (i > 0) VerticalDivider(width: 1, color: tokens.border),
                Expanded(
                  flex: cell.gridPosition.w,
                  child: isGapBlock(cell)
                      ? const _GapCell()
                      : _BlockCell(
                          vm: vm,
                          block: cell,
                          alone: cells.length == 1,
                          onPageSettings: onPageSettings,
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GapCell extends StatelessWidget {
  const _GapCell();

  @override
  Widget build(BuildContext context) => Semantics(
    label: context.tr('empty_space'),
    child: ColoredBox(
      color: context.inTheme.surfaceAlt,
      child: const SizedBox(height: 56),
    ),
  );
}

class _BlockCell extends StatelessWidget {
  const _BlockCell({
    required this.vm,
    required this.block,
    required this.alone,
    this.onPageSettings,
  });

  final WysiwygDesignViewModel vm;
  final DesignBlock block;
  final VoidCallback? onPageSettings;

  /// The only cell of its row — it then has room for a menu button of its
  /// own. A cell that shares its row keeps the whole width for its name and
  /// answers a long press with the same menu.
  final bool alone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final spec = blockSpecFor(block.type);
    final label = spec != null ? context.tr(spec.labelKey) : block.type;
    return InkWell(
      onTap: () => showDesignerBlockSheet(
        context,
        vm,
        block.id,
        onPageSettings: onPageSettings,
      ),
      onLongPress: () => _menu(context),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: EdgeInsets.only(left: InSpacing.md(context)),
          child: Row(
            children: [
              Icon(
                spec?.icon ?? Icons.extension_outlined,
                size: 20,
                color: spec?.printed == false ? tokens.overdue : tokens.ink2,
              ),
              SizedBox(width: InSpacing.sm),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (!alone)
                      Text(
                        '${block.gridPosition.w}/$kDesignerGridCols',
                        style: TextStyle(fontSize: 11, color: tokens.ink3),
                      ),
                  ],
                ),
              ),
              if (alone)
                Builder(
                  builder: (buttonContext) => IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: context.tr('more_actions'),
                    onPressed: () => _menu(buttonContext),
                  ),
                )
              else
                SizedBox(width: InSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  void _menu(BuildContext anchor) {
    final box = anchor.findRenderObject()! as RenderBox;
    showBlockMenu(
      anchor,
      vm,
      block.id,
      globalPosition: box.localToGlobal(box.size.centerRight(Offset.zero)),
    );
  }
}

class _EmptyOutline extends StatelessWidget {
  const _EmptyOutline({required this.vm});
  final WysiwygDesignViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(InSpacing.lg(context)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.dashboard_customize_outlined,
              size: 48,
              color: tokens.ink3,
            ),
            SizedBox(height: InSpacing.lg(context)),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(context.tr('add_block')),
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: () => showDesignerPaletteSheet(context, vm),
            ),
          ],
        ),
      ),
    );
  }
}

/// The property panel for one block, as a sheet.
///
/// The sheet closes itself when its block is gone — deleted from the panel's
/// own header, or moved out from under it. It does so **once**: the builder
/// below re-runs on every frame of a closing keyboard, and a second
/// `maybePop()` after the sheet has started to leave lands on the route
/// beneath it — the designer — closing it, or raising "Discard changes?".
void showDesignerBlockSheet(
  BuildContext context,
  WysiwygDesignViewModel vm,
  String blockId, {
  VoidCallback? onPageSettings,
}) {
  vm.selectBlock(blockId);
  var leaving = false;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // The property panel is mostly text fields, and `showModalBottomSheet`
    // lifts nothing by itself — pad by the keyboard inset. The height also
    // reads the *builder's* context: the outer one was captured before the
    // sheet opened, so it never saw the keyboard (or a rotation) at all.
    builder: (ctx) {
      final insets = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: insets),
        child: SizedBox(
          height: (MediaQuery.sizeOf(ctx).height - insets) * 0.8,
          child: ListenableBuilder(
            listenable: vm,
            builder: (sheetContext, _) {
              if (vm.selectedBlock == null) {
                if (!leaving) {
                  leaving = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (sheetContext.mounted &&
                        (ModalRoute.of(sheetContext)?.isCurrent ?? false)) {
                      Navigator.of(sheetContext).pop();
                    }
                  });
                }
                return const SizedBox.shrink();
              }
              return PropertyPanel(
                vm: vm,
                // A sheet for a block has no page to show: the Page tab
                // closes it and opens the page's own sheet.
                onShowPage: onPageSettings == null
                    ? null
                    : () {
                        leaving = true;
                        Navigator.of(sheetContext).pop();
                        onPageSettings();
                      },
              );
            },
          ),
        ),
      );
    },
  );
}

/// The palette, as a sheet that closes once a block is picked.
void showDesignerPaletteSheet(BuildContext context, WysiwygDesignViewModel vm) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // A list of names: on a wide pane it does not want the pane's width.
    constraints: const BoxConstraints(maxWidth: 480),
    // Read the height from the *builder's* context, as its sibling above
    // does: the outer one never sees a rotation.
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.7,
      child: ComponentPalette(
        vm: vm,
        onAdded: () => Navigator.of(ctx).maybePop(),
      ),
    ),
  );
}
