import 'package:flutter/material.dart';

import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Ask for the name of a record about to be created inline — the empty-query
/// path of a picker's "New Vendor" / "New Expense Category" row.
///
/// That path exists because on touch a picker with ≤ 6 options suppresses the
/// keyboard (`SearchableDropdownField._suppressKeyboard`), so "type a name and
/// pick Create" is unreachable there and the plain "New …" row is the only way
/// in. Resolves to the trimmed name, or null when cancelled or left blank.
Future<String?> showEntityNameDialog(
  BuildContext context, {
  required String titleKey,
  String initialName = '',
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) =>
        _EntityNameDialog(titleKey: titleKey, initialName: initialName),
  );
  final trimmed = name?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Stateful so the controller is disposed in `State.dispose()`, after the
/// route's exit transition — see `_RenameSavedViewDialog`.
class _EntityNameDialog extends StatefulWidget {
  const _EntityNameDialog({required this.titleKey, required this.initialName});

  final String titleKey;
  final String initialName;

  @override
  State<_EntityNameDialog> createState() => _EntityNameDialogState();
}

class _EntityNameDialogState extends State<_EntityNameDialog> {
  late final _controller = TextEditingController(text: widget.initialName);

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

  void _onChanged() => setState(() {});

  bool get _canSave => _controller.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSave) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr(widget.titleKey)),
      // Scoped like `TypeToConfirmDialog`: the field fires `_submit` itself,
      // which refuses a blank name, and the scope carries the same gate.
      content: FormSaveScope(
        onSubmit: _submit,
        enabled: _canSave,
        child: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: context.tr('name')),
          onSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('save'),
          // The name field owns focus and Enter; the button starts disabled
          // for a blank name, so no Enter hint either.
          autofocus: false,
          showEnterHint: false,
          onPressed: _canSave ? _submit : null,
        ),
      ],
    );
  }
}
