import 'package:flutter/widgets.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/views/advanced/invoice_design/wysiwyg/wysiwyg_design_view_model.dart';

/// Remove a block and offer to put it back.
///
/// Every delete affordance in the designer goes through here — a block goes
/// with one tap and no confirmation, so the toast's Undo is what makes that
/// safe. It restores *this* block rather than calling `vm.undo()`, which by
/// the time the user reaches for it may undo something they did afterwards.
void deleteBlockWithUndo(
  BuildContext context,
  WysiwygDesignViewModel vm,
  String blockId,
) {
  final deleted = vm.deleteBlock(blockId);
  if (deleted == null) return;
  Notify.success(
    context,
    context.tr('block_removed'),
    action: NotifyAction(context.tr('undo'), () => vm.restoreDeleted(deleted)),
  );
}
