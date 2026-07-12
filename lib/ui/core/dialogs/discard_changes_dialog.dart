import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Shows the standard "Discard changes?" prompt.
///
/// Returns `true` when the user picks Discard, `false` for Keep editing or a
/// barrier dismiss. Used both by per-screen `PopScope` guards and by the
/// global [UnsavedChangesGuard] when navigation routes through the shell.
Future<bool> showDiscardChangesDialog(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('discard_changes_question')),
      content: Text(ctx.tr('discard_changes_warning')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.tr('keep_editing')),
        ),
        PrimaryDialogAction(
          variant: DialogActionVariant.tonal,
          label: ctx.tr('discard'),
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return discard ?? false;
}
