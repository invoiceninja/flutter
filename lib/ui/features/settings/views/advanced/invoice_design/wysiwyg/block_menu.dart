import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/models/domain/design_block_layout.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/designer_pane.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Everything that can be done to a block without dragging it.
///
/// One menu for every surface: the chip on a selected block, a right-click on
/// the canvas, and the phone outline's rows. A drag is the fast way to move a
/// block, but it is not available to a keyboard, to a screen reader, or
/// comfortably on a phone — so each move the canvas can make by dragging has
/// an entry here, and the three input styles share one path.
///
/// `showMenu` is a route, so Android's back closes it with no extra wiring.
Future<void> showBlockMenu(
  BuildContext context,
  WysiwygDesignViewModel vm,
  String blockId, {
  required Offset globalPosition,
}) async {
  final rows = vm.rows;
  final at = locateBlock(rows, blockId);
  if (at == null) return;
  vm.selectBlock(blockId);

  final row = rows[at.row];
  final alone = !row.any((b) => b.id != blockId && !isGapBlock(b));
  final position = positionInRowOf(rows, blockId);
  final hasRowAbove = at.row > 0;
  final hasRowBelow = at.row < rows.length - 1;

  // Taken now: [context] may not outlive the menu. Selecting the block above
  // re-keys a canvas cell, so a cell that opened this on itself is unmounted
  // by the time an entry is picked — which used to drop the pick entirely.
  final toasts = Notify.capture(context);
  final removed = context.tr('block_removed');
  final undo = context.tr('undo');
  final picked = await showMenu<_BlockAction>(
    context: context,
    position: menuAnchor(context, globalPosition & Size.zero),
    items: [
      _item(
        context,
        _BlockAction.moveUp,
        Icons.arrow_upward,
        'move_up',
        enabled: !alone || hasRowAbove,
      ),
      _item(
        context,
        _BlockAction.moveDown,
        Icons.arrow_downward,
        'move_down',
        enabled: !alone || hasRowBelow,
      ),
      if (hasRowAbove)
        _item(
          context,
          _BlockAction.joinAbove,
          Icons.vertical_align_top,
          'join_row_above',
          enabled: vm.canPlaceBeside(
            _lastSolid(rows[at.row - 1]),
            movingId: blockId,
          ),
        ),
      if (hasRowBelow)
        _item(
          context,
          _BlockAction.joinBelow,
          Icons.vertical_align_bottom,
          'join_row_below',
          enabled: vm.canPlaceBeside(
            _lastSolid(rows[at.row + 1]),
            movingId: blockId,
          ),
        ),
      if (!alone)
        _item(
          context,
          _BlockAction.ownRow,
          Icons.horizontal_split_outlined,
          'own_row',
        ),
      const PopupMenuDivider(),
      _item(
        context,
        _BlockAction.wider,
        Icons.unfold_more,
        'wider',
        quarterTurns: 1,
      ),
      _item(
        context,
        _BlockAction.narrower,
        Icons.unfold_less,
        'narrower',
        quarterTurns: 1,
      ),
      if (position != null) ...[
        const PopupMenuDivider(),
        _item(
          context,
          _BlockAction.left,
          Icons.format_align_left,
          'left',
          checked: position == RowPosition.left,
        ),
        _item(
          context,
          _BlockAction.center,
          Icons.format_align_center,
          'center',
          checked: position == RowPosition.center,
        ),
        _item(
          context,
          _BlockAction.right,
          Icons.format_align_right,
          'right',
          checked: position == RowPosition.right,
        ),
      ],
      const PopupMenuDivider(),
      _item(context, _BlockAction.duplicate, Icons.copy_outlined, 'duplicate'),
      _item(context, _BlockAction.delete, Icons.delete_outline, 'delete'),
    ],
  );
  if (picked == null) return;
  switch (picked) {
    case _BlockAction.moveUp:
      vm.moveBlockVertically(blockId, -1);
    case _BlockAction.moveDown:
      vm.moveBlockVertically(blockId, 1);
    case _BlockAction.joinAbove:
      vm.joinNeighbourRow(blockId, -1);
    case _BlockAction.joinBelow:
      vm.joinNeighbourRow(blockId, 1);
    case _BlockAction.ownRow:
      vm.moveBlockToNewRow(blockId, at.row + 1);
    case _BlockAction.wider:
      vm.nudgeWidth(blockId, 1);
    case _BlockAction.narrower:
      vm.nudgeWidth(blockId, -1);
    case _BlockAction.left:
      vm.positionBlock(blockId, RowPosition.left);
    case _BlockAction.center:
      vm.positionBlock(blockId, RowPosition.center);
    case _BlockAction.right:
      vm.positionBlock(blockId, RowPosition.right);
    case _BlockAction.duplicate:
      vm.duplicateBlock(blockId);
    case _BlockAction.delete:
      final deleted = vm.deleteBlock(blockId);
      if (deleted != null) {
        toasts?.success(
          removed,
          action: NotifyAction(undo, () => vm.restoreDeleted(deleted)),
        );
      }
  }
}

/// What can be done to a whole row: the menu behind the row's grip.
Future<void> showRowMenu(
  BuildContext context,
  WysiwygDesignViewModel vm,
  int rowIndex, {
  required Offset globalPosition,
}) async {
  final rows = vm.rows;
  if (rowIndex < 0 || rowIndex >= rows.length) return;
  final toasts = Notify.capture(context);
  final removed = context.tr('row_removed');
  final undo = context.tr('undo');
  final picked = await showMenu<_RowAction>(
    context: context,
    position: menuAnchor(context, globalPosition & Size.zero),
    items: [
      _item(
        context,
        _RowAction.moveUp,
        Icons.arrow_upward,
        'move_up',
        enabled: rowIndex > 0,
      ),
      _item(
        context,
        _RowAction.moveDown,
        Icons.arrow_downward,
        'move_down',
        enabled: rowIndex < rows.length - 1,
      ),
      if (rowHasGaps(rows[rowIndex]))
        _item(
          context,
          _RowAction.removeGaps,
          Icons.width_full_outlined,
          'remove_gaps',
        ),
      const PopupMenuDivider(),
      _item(
        context,
        _RowAction.duplicate,
        Icons.copy_outlined,
        'duplicate_row',
      ),
      _item(context, _RowAction.delete, Icons.delete_outline, 'delete_row'),
    ],
  );
  if (picked == null) return;
  switch (picked) {
    case _RowAction.moveUp:
      vm.moveRow(rowIndex, rowIndex - 1);
    case _RowAction.moveDown:
      vm.moveRow(rowIndex, rowIndex + 1);
    case _RowAction.removeGaps:
      vm.removeGaps(rowIndex);
    case _RowAction.duplicate:
      vm.duplicateRow(rowIndex);
    case _RowAction.delete:
      // A row goes with one press, like a block: the toast is the way back.
      final before = vm.draft.template;
      vm.deleteRow(rowIndex);
      final after = vm.draft.template;
      if (after != before) {
        toasts?.success(
          removed,
          action: NotifyAction(undo, () {
            // Only while nothing has happened since — otherwise this would
            // undo whatever did.
            if (vm.draft.template == after) vm.undo();
          }),
        );
      }
  }
}

String _lastSolid(DesignRow row) =>
    row.lastWhere((b) => !isGapBlock(b), orElse: () => row.last).id;

enum _BlockAction {
  moveUp,
  moveDown,
  joinAbove,
  joinBelow,
  ownRow,
  wider,
  narrower,
  left,
  center,
  right,
  duplicate,
  delete,
}

enum _RowAction { moveUp, moveDown, removeGaps, duplicate, delete }

PopupMenuItem<T> _item<T>(
  BuildContext context,
  T value,
  IconData icon,
  String labelKey, {
  bool enabled = true,
  bool checked = false,
  int quarterTurns = 0,
}) {
  final tokens = context.inTheme;
  return PopupMenuItem<T>(
    value: value,
    enabled: enabled,
    child: Row(
      children: [
        RotatedBox(
          quarterTurns: quarterTurns,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? tokens.ink2 : tokens.ink3,
          ),
        ),
        SizedBox(width: InSpacing.md(context)),
        Expanded(child: Text(context.tr(labelKey))),
        if (checked) Icon(Icons.check, size: 16, color: tokens.accent),
      ],
    ),
  );
}
