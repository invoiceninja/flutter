import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';

/// Archive / Restore / Delete `PopupMenuButton` for the AppBar of a settings
/// edit screen (payment terms, task statuses, group settings, tax rates, …).
/// Delete always confirms; Archive confirms when the user has **Confirm
/// actions** on (Settings → Device Settings → Security). Both go through the
/// shared [showConfirmActionDialog].
///
/// On success the route pops if the navigator can — that's the right behavior
/// for settings flows where archive/delete naturally returns the user to the
/// list. The repo-side toast comes from [StandardEntityActions] using the
/// `wireName` convention enforced by
/// `test/l10n/entity_translation_completeness_test.dart`.
class SettingsEntityOverflowMenu extends StatelessWidget {
  const SettingsEntityOverflowMenu({
    super.key,
    required this.isArchived,
    required this.isDeleted,
    required this.wireName,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
  });

  /// True when the entity has `archived_at` set.
  final bool isArchived;

  /// True when the entity has `is_deleted` set.
  final bool isDeleted;

  /// Entity slug used for `archived_<name>` / `restored_<name>` /
  /// `deleted_<name>` toast keys — e.g. `'payment_term'`, `'task_status'`,
  /// `'group'`.
  final String wireName;

  final Future<void> Function() onArchive;
  final Future<void> Function() onRestore;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final canArchive = !isArchived && !isDeleted;
    final canRestore = isArchived || isDeleted;

    return PopupMenuButton<String>(
      tooltip: context.tr('more_actions'),
      onSelected: (action) async {
        switch (action) {
          case 'archive':
            if (context.read<Services>().confirmActions.value) {
              final ok = await showConfirmActionDialog(
                context,
                title: context.tr('archive'),
              );
              if (!ok || !context.mounted) return;
            }
            await StandardEntityActions.archive(
              context: context,
              wireName: wireName,
              op: onArchive,
              undoOp: onRestore,
            );
            if (context.mounted && context.canPop()) context.pop();
          case 'restore':
            await StandardEntityActions.restore(
              context: context,
              wireName: wireName,
              op: onRestore,
            );
            if (context.mounted && context.canPop()) context.pop();
          case 'delete':
            // Unconditional: deleting a settings record is destructive and
            // has no Undo here, so it prompts even with the preference off.
            final confirmed = await showConfirmActionDialog(
              context,
              title: context.tr('delete'),
              destructive: true,
            );
            if (!confirmed || !context.mounted) return;
            await StandardEntityActions.delete(
              context: context,
              wireName: wireName,
              op: onDelete,
              undoOp: onRestore,
            );
            if (context.mounted && context.canPop()) context.pop();
        }
      },
      itemBuilder: (context) => [
        if (canArchive)
          PopupMenuItem(value: 'archive', child: Text(context.tr('archive'))),
        if (canRestore)
          PopupMenuItem(value: 'restore', child: Text(context.tr('restore'))),
        PopupMenuItem(value: 'delete', child: Text(context.tr('delete'))),
      ],
    );
  }
}
