import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Open the Add Comment dialog. Returns the trimmed comment text on save,
/// or null when the user cancels. The caller is responsible for the actual
/// repo call — keeps a failed mutation's snackbar against the underlying
/// detail screen instead of a dismissed dialog.
///
/// The **only** add-comment dialog. There used to be a second, near-identical
/// one under `billing_shared/actions/`, and the two diverged in ways a user
/// could see: 3 lines vs 4-6, `notes` vs `comment` as the hint, an underline
/// vs an outline border, and — the one that mattered — no Save gate, so the
/// billing copy let you save an empty comment. Everything now routes through
/// `promptAddCommentFor` (`lib/ui/core/detail/activity_note_actions.dart`),
/// which calls this. It lives under `clients/` only because that is where it
/// was written; it is not client-specific.
Future<String?> showAddCommentDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    // A stray tap outside would otherwise destroy a typed comment with no
    // confirmation — the worst failure a note surface can have, and the most
    // likely one on a phone. Cancel, Esc and system back still close it.
    barrierDismissible: false,
    builder: (_) => const _AddCommentDialog(),
  );
}

class _AddCommentDialog extends StatefulWidget {
  const _AddCommentDialog();

  @override
  State<_AddCommentDialog> createState() => _AddCommentDialogState();
}

class _AddCommentDialogState extends State<_AddCommentDialog> {
  final _controller = TextEditingController();
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final canSave = _controller.text.trim().isNotEmpty;
    if (canSave != _canSave) setState(() => _canSave = canSave);
  }

  void _onSave() {
    if (!_canSave) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('add_comment')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: TextField(
          controller: _controller,
          autofocus: true,
          // Multi-line: Enter inserts a newline. Save fires only via the
          // primary button — matches the legacy admin-portal dialog and the
          // app's § Forms rule (no Enter-to-save on `maxLines > 1`).
          maxLines: 6,
          minLines: 4,
          // Without this every comment typed on a phone starts lowercase.
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: context.tr('comment'),
            border: const OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('save'),
          enabled: _canSave,
          // Multi-line comment field: Enter inserts a newline, so it owns focus
          // and there's no Enter-to-submit path — no hint.
          autofocus: false,
          showEnterHint: false,
          onPressed: _onSave,
        ),
      ],
    );
  }
}
