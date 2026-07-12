import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Shows the "Add comment" modal and returns the trimmed text the user
/// entered, or null if they cancelled / left the field empty.
///
/// Used by every billing-doc detail screen (invoice / quote / credit /
/// purchase_order / recurring_invoice) — the modal itself is identical;
/// only the caller's `repo.addComment(...)` wiring differs.
///
/// The dialog uses side-by-side `Outlined` + `Filled` buttons per the
/// design-system rule (CLAUDE.md § Design system v2). `minimumSize` is
/// set inline on both buttons because the global FilledButton theme
/// defaults to `Size.fromHeight(44)` which expands to infinity when used
/// inside a `Row`.
Future<String?> showAddCommentPrompt(BuildContext context) async {
  final controller = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Text(ctx.tr('add_comment')),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(hintText: ctx.tr('notes')),
        ),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(ctx.tr('cancel')),
              ),
              const SizedBox(width: 8),
              PrimaryDialogAction(
                label: ctx.tr('save'),
                onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                autofocus: false,
                showEnterHint: false,
              ),
            ],
          ),
        ],
      );
    },
  );
  if (text == null || text.isEmpty) return null;
  return text;
}
