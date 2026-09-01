import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/palette/component_palette.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/property_panel/property_panel.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Phone (<600 px) layout. Replaces the unusable 12-col canvas with a
/// `ReorderableListView` of full-width block previews; tap to edit
/// properties in a bottom sheet; "+" FAB opens the categorized block
/// palette as a sheet. Switching back to desktop preserves the layout
/// (each block has `gridPosition.x = 0`, `w = 12`, `y` = row index ×
/// height).
class MobileReorderView extends StatelessWidget {
  const MobileReorderView({super.key, required this.vm});

  final WysiwygDesignViewModel vm;

  @override
  Widget build(BuildContext context) {
    final blocks = vm.blocks;
    return Stack(
      children: [
        Column(
          children: [
            _HintBanner(),
            Expanded(
              child: blocks.isEmpty
                  ? _EmptyState(vm: vm)
                  : _ReorderableList(vm: vm, blocks: blocks),
            ),
          ],
        ),
        Positioned(
          right: InSpacing.lg(context),
          bottom: InSpacing.lg(context) + MediaQuery.of(context).padding.bottom,
          child: FloatingActionButton(
            onPressed: () => _showPaletteSheet(context, vm),
            tooltip: context.tr('add_block'),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _HintBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Container(
      width: double.infinity,
      color: tokens.accentSoft,
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.md(context),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: tokens.ink),
          SizedBox(width: InSpacing.sm),
          Expanded(
            child: Text(
              context.tr('mobile_reorder_hint'),
              style: TextStyle(fontSize: 12, color: tokens.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderableList extends StatelessWidget {
  const _ReorderableList({required this.vm, required this.blocks});

  final WysiwygDesignViewModel vm;
  final List<DesignBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      itemCount: blocks.length,
      onReorderItem: vm.reorderBlocks,
      // Add bottom padding so the FAB doesn't cover the last row.
      padding: EdgeInsets.only(
        top: InSpacing.md(context),
        bottom: 88 + MediaQuery.of(context).padding.bottom,
      ),
      itemBuilder: (context, index) {
        final block = blocks[index];
        return _MobileBlockRow(
          key: ValueKey(block.id),
          vm: vm,
          block: block,
          index: index,
        );
      },
    );
  }
}

/// Compact row for the mobile reorder list — icon + label + drag handle +
/// delete. The full `BlockPreview` is too tall for a list row at 320 px;
/// we lean on the palette spec's icon + label, plus a small subtitle
/// showing the block's grid position so the user has spatial context.
class _MobileBlockRow extends StatelessWidget {
  const _MobileBlockRow({
    super.key,
    required this.vm,
    required this.block,
    required this.index,
  });

  final WysiwygDesignViewModel vm;
  final DesignBlock block;
  final int index;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final spec = blockSpecFor(block.type);
    final label = spec != null ? context.tr(spec.labelKey) : block.type;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: InSpacing.lg(context),
        vertical: InSpacing.sm,
      ),
      child: Material(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(InRadii.r2),
        elevation: 1,
        child: InkWell(
          borderRadius: BorderRadius.circular(InRadii.r2),
          onTap: () => _openPropertySheet(context, vm, block),
          child: Padding(
            padding: EdgeInsets.all(InSpacing.md(context)),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_handle, color: tokens.ink3, size: 24),
                ),
                SizedBox(width: InSpacing.md(context)),
                Icon(
                  spec?.icon ?? Icons.crop_square,
                  size: 24,
                  color: tokens.ink,
                ),
                SizedBox(width: InSpacing.md(context)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${block.gridPosition.w}×${block.gridPosition.h}'
                        '${block.locked ? '  ·  ${context.tr('locked')}' : ''}',
                        style: TextStyle(fontSize: 11, color: tokens.ink3),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => vm.deleteBlock(block.id),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.vm});
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
            SizedBox(height: InSpacing.md(context)),
            Text(
              context.tr('drag_and_drop_to_add'),
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.ink3),
            ),
            SizedBox(height: InSpacing.lg(context)),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(context.tr('add_block')),
              style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
              onPressed: () => _showPaletteSheet(context, vm),
            ),
          ],
        ),
      ),
    );
  }
}

void _openPropertySheet(
  BuildContext context,
  WysiwygDesignViewModel vm,
  DesignBlock block,
) {
  vm.selectBlock(block.id);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
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
          child: PropertyPanel(vm: vm),
        ),
      );
    },
  );
}

void _showPaletteSheet(BuildContext context, WysiwygDesignViewModel vm) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // No text input here, so no keyboard inset to take — but read the height
    // from the *builder's* context for the same reason its sibling above does:
    // the outer one was captured before the sheet opened and never sees a
    // rotation.
    builder: (ctx) => SizedBox(
      height: MediaQuery.sizeOf(ctx).height * 0.7,
      child: ComponentPalette(vm: vm),
    ),
  );
}
