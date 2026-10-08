import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/block_library.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/canvas/wysiwyg_canvas.dart'
    show CanvasDropPayload, PalettePayload;
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Block types a page normally has one of. The palette ticks one that is
/// already on the page — it can still be added again.
const _kSingleUse = <String>{
  'logo',
  'company-info',
  'client-info',
  'client-shipping-info',
  'invoice-details',
  'table',
  'total',
  'public-notes',
  'terms',
  'footer',
};

/// The designer's palette: the blocks that can be put on the page, grouped by
/// [BlockCategory]. A tile is dragged onto the page, or pressed to add its
/// block below the selected one.
///
/// A block the server cannot print is not offered ([BlockSpec.printed]).
class ComponentPalette extends StatelessWidget {
  const ComponentPalette({super.key, required this.vm, this.onAdded});

  final WysiwygDesignViewModel vm;

  /// Called after a press added a block — the phone's sheet closes on it.
  final VoidCallback? onAdded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final groups = <BlockCategory, List<BlockSpec>>{};
    for (final s in kBlockLibrary) {
      if (!s.printed) continue;
      groups.putIfAbsent(s.category, () => <BlockSpec>[]).add(s);
    }
    final onPage = {for (final b in vm.blocks) b.type};

    // A `Material`, not a coloured `Container`: a `ListTile` paints its ink
    // on the nearest Material, and one hidden behind a `ColoredBox` asserts
    // on every tile.
    return Material(
      color: tokens.surface,
      child: SizedBox(
        width: 240,
        child: ListView(
          padding: EdgeInsets.symmetric(vertical: InSpacing.md(context)),
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                InSpacing.lg(context),
                InSpacing.md(context),
                InSpacing.lg(context),
                0,
              ),
              child: Text(
                context.tr('components'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            // In the phone's sheet there is nothing to drag onto.
            if (onAdded == null)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: InSpacing.lg(context),
                  vertical: InSpacing.sm,
                ),
                child: Text(
                  context.tr('drag_or_click_to_add'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
                ),
              ),
            for (final category in BlockCategory.values)
              if (groups[category] case final specs?) ...[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    InSpacing.lg(context),
                    InSpacing.md(context),
                    InSpacing.lg(context),
                    InSpacing.sm,
                  ),
                  child: Text(
                    context.tr(_labelKeyFor(category)),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: tokens.ink3,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                for (final spec in specs)
                  _PaletteTile(
                    spec: spec,
                    onPage:
                        _kSingleUse.contains(spec.type) &&
                        onPage.contains(spec.type),
                    onAdd: () {
                      vm.addBlock(spec);
                      onAdded?.call();
                    },
                  ),
              ],
          ],
        ),
      ),
    );
  }

  String _labelKeyFor(BlockCategory c) => switch (c) {
    BlockCategory.branding => 'branding',
    BlockCategory.content => 'content',
    BlockCategory.data => 'data',
    BlockCategory.layout => 'layout',
  };
}

class _PaletteTile extends StatelessWidget {
  const _PaletteTile({
    required this.spec,
    required this.onPage,
    required this.onAdd,
  });

  final BlockSpec spec;
  final bool onPage;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final touch = Env.isTouchPrimary;
    final label = context.tr(spec.labelKey);
    final tile = ListTile(
      dense: true,
      leading: Icon(spec.icon, size: 20, color: tokens.ink),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onPage)
            Padding(
              padding: EdgeInsets.only(right: InSpacing.sm),
              child: Tooltip(
                message: context.tr('on_page'),
                child: Icon(Icons.check, size: 16, color: tokens.ink3),
              ),
            ),
          // A finger adds by pressing; a pointer can also drag.
          Icon(
            touch ? Icons.add : Icons.drag_indicator,
            size: 16,
            color: tokens.ink3,
          ),
        ],
      ),
      onTap: onAdd,
    );
    final described = Tooltip(
      message: context.tr('block_hint_${spec.type}'),
      waitDuration: const Duration(milliseconds: 600),
      child: tile,
    );
    final feedback = Material(
      elevation: 6,
      color: tokens.surface,
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(spec.icon, size: 16, color: tokens.ink2),
            const SizedBox(width: 8),
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
    );
    final whenDragging = Opacity(opacity: 0.4, child: tile);
    final payload = PalettePayload(spec);
    // The pointer, not the tile's corner, is where the block lands: with the
    // default anchor it landed left of the cursor by however far along the
    // tile it had been grabbed.
    if (touch) {
      // A long press, so the list still scrolls under a finger. And the
      // bare tile, with no tooltip: a `Tooltip` is shown by a long press on
      // touch too, so the hint and the drag both answered the same gesture.
      return LongPressDraggable<CanvasDropPayload>(
        data: payload,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: feedback,
        childWhenDragging: whenDragging,
        child: tile,
      );
    }
    return Draggable<CanvasDropPayload>(
      data: payload,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: feedback,
      childWhenDragging: whenDragging,
      child: described,
    );
  }
}
