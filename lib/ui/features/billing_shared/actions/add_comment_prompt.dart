import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Shows the "Add comment" modal and returns the trimmed text the user
/// entered, or null if they cancelled / left the field empty.
///
/// The single implementation for every entity that supports comments —
/// billing docs (invoice / quote / credit / purchase_order /
/// recurring_invoice), payments, expenses and recurring expenses. Those all
/// used to inline their own byte-identical copy; only the caller's
/// `repo.addComment(...)` wiring differs.
///
/// The dialog uses side-by-side `Outlined` + `Filled` buttons per the
/// design-system rule (CLAUDE.md § Design system v2). `minimumSize` is
/// set inline on both buttons because the global FilledButton theme
/// defaults to `Size.fromHeight(44)` which expands to infinity when used
/// inside a `Row`.
Future<String?> showAddCommentPrompt(BuildContext context) async {
  final text = await showDialog<String>(
    context: context,
    builder: (_) => const _AddCommentPrompt(),
  );
  if (text == null || text.isEmpty) return null;
  return text;
}

/// Stateful so the `TextEditingController` is owned by an element and disposed
/// in `State.dispose()`.
///
/// Disposing it after `await showDialog(...)` instead looks equivalent but is
/// not: `Route.didPop` resolves that future *immediately*, and Flutter's own
/// doc says routes "should not wait for their exit animation to complete
/// before doing so". The `TextField` — and its live `TextInputConnection`,
/// since the field is `autofocus` — therefore stays mounted for the whole
/// reverse transition, and a final `updateEditingValue` from the platform
/// during IME teardown would write to a disposed `ChangeNotifier`.
/// `State.dispose()` runs after `finalizeRoute`, so it cannot race that.
class _AddCommentPrompt extends StatefulWidget {
  const _AddCommentPrompt();

  @override
  State<_AddCommentPrompt> createState() => _AddCommentPromptState();
}

class _AddCommentPromptState extends State<_AddCommentPrompt> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('add_comment')),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(hintText: context.tr('notes')),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.tr('cancel')),
            ),
            const SizedBox(width: 8),
            PrimaryDialogAction(
              label: context.tr('save'),
              onPressed: () =>
                  Navigator.of(context).pop(_controller.text.trim()),
              // Multi-line field owns Enter (newline), so there is no
              // Enter-to-submit path to advertise.
              autofocus: false,
              showEnterHint: false,
            ),
          ],
        ),
      ],
    );
  }
}
