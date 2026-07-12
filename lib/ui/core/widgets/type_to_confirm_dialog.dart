import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Result of [showTypeToConfirmDialog]: whether the user confirmed, and the
/// optional reason text they entered (empty when no reason field was shown,
/// or when the field was left blank).
class TypeToConfirmResult {
  const TypeToConfirmResult({required this.confirmed, this.reason});

  final bool confirmed;
  final String? reason;
}

/// Modal that requires the user to type a specific word ([typeToConfirm],
/// case-insensitive) before the primary action enables. Mirrors
/// admin-portal `dialogs.dart::confirmCallback` — used by destructive
/// account-level ops ("purge", "delete") so a slip of the finger can't fire
/// the action.
///
/// When [reasonLabel] is non-null, a multi-line text field is appended for
/// optional free-text feedback (used by Cancel Account → "Why are you
/// leaving?"). The body is returned in [TypeToConfirmResult.reason]; null
/// means no field was shown, empty means the user left it blank.
///
/// Returns `confirmed: false` when the user cancels or dismisses.
Future<TypeToConfirmResult> showTypeToConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String typeToConfirm,
  String? reasonLabel,
}) async {
  final result = await showDialog<TypeToConfirmResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _TypeToConfirmDialog(
      title: title,
      message: message,
      typeToConfirm: typeToConfirm,
      reasonLabel: reasonLabel,
    ),
  );
  return result ?? const TypeToConfirmResult(confirmed: false);
}

class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog({
    required this.title,
    required this.message,
    required this.typeToConfirm,
    required this.reasonLabel,
  });

  final String title;
  final String message;
  final String typeToConfirm;
  final String? reasonLabel;

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _typeCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  bool get _canSubmit =>
      _typeCtrl.text.trim().toLowerCase() ==
      widget.typeToConfirm.trim().toLowerCase();

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(
      TypeToConfirmResult(
        confirmed: true,
        reason: widget.reasonLabel == null ? null : _reasonCtrl.text.trim(),
      ),
    );
  }

  void _cancel() {
    Navigator.of(context).pop(const TypeToConfirmResult(confirmed: false));
  }

  @override
  void dispose() {
    _typeCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final hint = context
        .tr('please_type_to_confirm')
        .replaceAll(':value', widget.typeToConfirm);
    return AlertDialog(
      title: Text(widget.title),
      content: FormSaveScope(
        enabled: _canSubmit,
        onSubmit: _submit,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.message, style: TextStyle(color: tokens.ink2)),
              SizedBox(height: InSpacing.md(context)),
              TextField(
                controller: _typeCtrl,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                textInputAction: widget.reasonLabel == null
                    ? TextInputAction.done
                    : TextInputAction.next,
                decoration: InputDecoration(
                  labelText: hint,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (widget.reasonLabel != null) ...[
                SizedBox(height: InSpacing.md(context)),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: widget.reasonLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: Text(context.tr('cancel'))),
        PrimaryDialogAction(
          variant: DialogActionVariant.destructive,
          label: context.tr('continue'),
          enabled: _canSubmit,
          // The type-to-confirm field owns focus + fires Enter via onSubmitted.
          autofocus: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}
