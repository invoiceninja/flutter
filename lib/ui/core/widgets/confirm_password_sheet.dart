import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Modal that captures the user's password for destructive server endpoints
/// (`delete`, `purge`, …). Writes to [PasswordCache] on Confirm; the sync
/// engine retries the parked outbox row once the cache is populated.
///
/// Triggered by the shell listening for [PasswordRequiredEvent] on the
/// [SyncRepository.events] stream. Also callable directly from any UI that
/// wants to prime the cache before a destructive action.
///
/// Returns `true` if the user confirmed (cache is populated), `false` if
/// they cancelled (cache untouched).
Future<bool> showConfirmPasswordSheet(
  BuildContext context, {
  required PasswordCache cache,
  String? message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return _ConfirmPasswordDialog(
        message: message ?? ctx.tr('confirm_password_message'),
        onConfirm: (pw) {
          cache.set(pw);
          Navigator.of(ctx).pop(true);
        },
        onCancel: () => Navigator.of(ctx).pop(false),
      );
    },
  );
  return confirmed ?? false;
}

class _ConfirmPasswordDialog extends StatefulWidget {
  const _ConfirmPasswordDialog({
    required this.message,
    required this.onConfirm,
    required this.onCancel,
  });

  final String message;
  final void Function(String password) onConfirm;
  final VoidCallback onCancel;

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  bool _obscure = true;

  /// Owned here, not by the caller. Disposing after `await showDialog(...)`
  /// races the exit transition: `Route.didPop` resolves that future
  /// immediately (routes deliberately "should not wait for their exit
  /// animation"), so this autofocused, obscured field — and its live
  /// `TextInputConnection` — is still mounted when the caller would have
  /// disposed. `State.dispose()` runs after `finalizeRoute`.
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => _controller.text.isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    widget.onConfirm(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return AlertDialog(
      title: Text(context.tr('confirm_password_title')),
      content: FormSaveScope(
        enabled: true,
        onSubmit: _submit,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.message, style: TextStyle(color: tokens.ink2)),
            SizedBox(height: InSpacing.md(context)),
            _PasswordField(
              controller: _controller,
              obscure: _obscure,
              onObscureToggle: () => setState(() => _obscure = !_obscure),
              onChanged: (_) => setState(() {}),
              onSubmitted: _submit,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('confirm'),
          enabled: _canSubmit,
          // The password field owns focus + fires Enter via onSubmitted.
          autofocus: false,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.obscure,
    required this.onObscureToggle,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onObscureToggle;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      autofocus: true,
      decoration: InputDecoration(
        labelText: context.tr('password'),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: onObscureToggle,
        ),
      ),
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmitted(),
    );
  }
}
