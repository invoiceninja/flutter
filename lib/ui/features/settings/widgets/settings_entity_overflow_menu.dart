import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/standard_entity_actions.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Archive / Restore / Delete `PopupMenuButton` for the AppBar of a settings
/// edit screen (payment terms, task statuses, group settings, tax rates, …).
/// Delete is gated by a confirm `AlertDialog` whose button sizing matches the
/// design-system convention for side-by-side dialog actions (CLAUDE.md
/// § Design system v2).
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
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(ctx.tr('delete')),
                content: Text(ctx.tr('are_you_sure')),
                actions: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(64, 40),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text(ctx.tr('cancel')),
                  ),
                  PrimaryDialogAction(
                    label: ctx.tr('delete'),
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ],
              ),
            );
            if (confirmed != true || !context.mounted) return;
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
