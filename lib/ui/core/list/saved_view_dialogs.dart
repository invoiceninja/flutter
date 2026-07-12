import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/saved_view.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/saved_view_icons.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Prompt the user to rename [view] and write the change through
/// `services.savedViews.rename`. Reused by the bookmark sheet's per-row
/// edit pencil and by the sidebar's hover-menu Rename action.
///
/// Shape matches every other "name + Cancel/Save" dialog in the app —
/// `AlertDialog` with side-by-side actions and the `Size(64, 44)` minimum
/// override required by the global FilledButton theme (CLAUDE.md).
Future<void> showRenameSavedViewDialog(
  BuildContext context,
  SavedView view,
) async {
  final controller = TextEditingController(text: view.name);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(ctx.tr('rename')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: ctx.tr('view_name')),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: ctx.tr('save'),
            // The name field owns focus + fires Enter via its onSubmitted.
            autofocus: false,
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          ),
        ],
      );
    },
  );
  controller.dispose();
  if (result == null || result.isEmpty || result == view.name) return;
  if (!context.mounted) return;
  final services = context.read<Services>();
  // Capture the messenger before await so the toast can still fire after
  // the host (sheet, sidebar item) unmounts.
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await services.savedViews.rename(viewId: view.id, newName: result);
    if (!context.mounted) return;
    Notify.success(context, context.tr('saved'), messenger: messenger);
  } catch (e) {
    if (!context.mounted) return;
    Notify.error(
      context,
      context.tr('could_not_save'),
      error: e,
      messenger: messenger,
    );
  }
}

/// Confirm + delete [view] via `services.savedViews.delete`. Reused by the
/// bookmark sheet's per-row trash icon and by the sidebar's hover-menu
/// Delete action.
Future<void> showDeleteSavedViewDialog(
  BuildContext context,
  SavedView view,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('delete_view')),
      content: Text(ctx.tr('confirm_delete_view')),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.tr('cancel')),
        ),
        PrimaryDialogAction(
          variant: DialogActionVariant.tonal,
          label: ctx.tr('delete'),
          onPressed: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final services = context.read<Services>();
  try {
    await services.savedViews.delete(view.id);
    if (!context.mounted) return;
    Notify.success(context, context.tr('view_deleted'), messenger: messenger);
  } catch (e) {
    if (!context.mounted) return;
    Notify.error(
      context,
      context.tr('could_not_save'),
      error: e,
      messenger: messenger,
    );
  }
}

/// A user's icon selection. A non-null [SavedViewIconChoice] means the user
/// committed a choice; its [key] may still be `null` (the "Default" tile,
/// i.e. clear to the bookmark). A `null` future result means the picker was
/// dismissed without choosing — distinguishing "chose Default" from
/// "cancelled" (which a bare `String?` could not).
@immutable
class SavedViewIconChoice {
  const SavedViewIconChoice(this.key);
  final String? key;
}

/// Modal grid picker over [kSavedViewIcons]. Shared by the saved-view context
/// menu's "Choose icon" action and the create row in the bookmark sheet.
/// Mirrors the color preset picker's `AlertDialog` + `Wrap` shape.
Future<SavedViewIconChoice?> showSavedViewIconPicker(
  BuildContext context, {
  required String? current,
}) {
  return showDialog<SavedViewIconChoice>(
    context: context,
    builder: (ctx) {
      final tokens = ctx.inTheme;
      Widget tile({
        required IconData icon,
        required bool selected,
        required VoidCallback onTap,
        String? tooltip,
      }) {
        final cell = InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(InRadii.r2),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(InRadii.r2),
              border: Border.all(
                color: selected ? tokens.accent : tokens.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              size: 21,
              color: selected ? tokens.accent : tokens.ink2,
            ),
          ),
        );
        return tooltip == null ? cell : Tooltip(message: tooltip, child: cell);
      }

      return AlertDialog(
        title: Text(ctx.tr('choose_icon')),
        content: SizedBox(
          width: 320,
          // AlertDialog content doesn't scroll on its own — cap the height
          // and scroll so the full curated grid never overflows the dialog.
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Default (clear) tile first — the most common reset
                  // action, where the eye lands.
                  tile(
                    icon: kSavedViewDefaultIcon,
                    selected: current == null,
                    tooltip: ctx.tr('default'),
                    onTap: () =>
                        Navigator.pop(ctx, const SavedViewIconChoice(null)),
                  ),
                  for (final entry in kSavedViewIcons.entries)
                    tile(
                      icon: entry.value,
                      selected: entry.key == current,
                      onTap: () =>
                          Navigator.pop(ctx, SavedViewIconChoice(entry.key)),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.tr('cancel')),
          ),
        ],
      );
    },
  );
}

/// Prompt for an icon and persist it via `services.savedViews.setIcon`.
/// Reused by the sidebar context menu and the bookmark sheet's per-row icon.
Future<void> showChooseSavedViewIconDialog(
  BuildContext context,
  SavedView view,
) async {
  final choice = await showSavedViewIconPicker(context, current: view.iconKey);
  if (choice == null || !context.mounted) return;
  if (choice.key == view.iconKey) return;
  final services = context.read<Services>();
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await services.savedViews.setIcon(viewId: view.id, iconKey: choice.key);
    if (!context.mounted) return;
    Notify.success(context, context.tr('saved'), messenger: messenger);
  } catch (e) {
    if (!context.mounted) return;
    Notify.error(
      context,
      context.tr('could_not_save'),
      error: e,
      messenger: messenger,
    );
  }
}
