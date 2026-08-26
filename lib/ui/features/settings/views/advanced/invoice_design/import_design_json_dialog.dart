import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// "Paste design JSON" prompt. Returns the raw text, or null on cancel.
///
/// Shared by the Custom Designs list and the WYSIWYG editor, which each used to
/// inline their own copy — and each disposed the controller on the route
/// future (`finally` / `whenComplete`). That races the exit transition:
/// `Route.didPop` resolves that future immediately, and Flutter's own doc says
/// routes "should not wait for their exit animation to complete before doing
/// so", so the `TextField` is still mounted. Owning the controller in a `State`
/// disposes it after `finalizeRoute` instead.
Future<String?> showImportDesignJsonDialog(BuildContext context) =>
    showDialog<String>(
      context: context,
      builder: (_) => const _ImportDesignJsonDialog(),
    );

class _ImportDesignJsonDialog extends StatefulWidget {
  const _ImportDesignJsonDialog();

  @override
  State<_ImportDesignJsonDialog> createState() =>
      _ImportDesignJsonDialogState();
}

class _ImportDesignJsonDialogState extends State<_ImportDesignJsonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('import_design')),
      content: TextField(
        controller: _controller,
        maxLines: 8,
        decoration: InputDecoration(
          hintText: context.tr('paste_design_json'),
          border: const OutlineInputBorder(),
        ),
        style: const TextStyle(fontFamily: kMonoFontFamily, fontSize: 12),
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
              label: context.tr('import'),
              // Multi-line field owns Enter, so there is no submit shortcut.
              autofocus: false,
              showEnterHint: false,
              onPressed: () => Navigator.of(context).pop(_controller.text),
            ),
          ],
        ),
      ],
    );
  }
}
