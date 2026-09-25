import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/services/apple_sign_in.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart' show formatNotifyError;
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Modal that captures the user's password for destructive server endpoints
/// (`delete`, `purge`, …). Writes to [PasswordCache] on Confirm; the sync
/// engine retries the parked outbox row once the cache is populated.
///
/// Triggered by the shell listening for [PasswordRequiredEvent] on the
/// [SyncRepository.events] stream. Also callable directly from any UI that
/// wants to prime the cache before a destructive action.
///
/// Who is asking decides what is asked ([PasswordCache.currentSubject],
/// mirroring admin-portal's `passwordCallback`):
///
///  * an OAuth user the server lets through without a credential
///    ([PasswordCache.isExempt]) is not asked at all — returns `true` at once.
///    [afterRejection] turns that off: the server has just refused the
///    request without one, so the session's copy of the setting is stale;
///  * an Apple user on iOS / macOS can "Confirm with Apple" — the identity
///    token is cached for `X-API-OAUTH-PASSWORD`;
///  * a user with no password and no Apple route gets "Please set an account
///    password" with a way to the Password tab, never a field they cannot
///    fill.
///
/// Returns `true` if the user confirmed (cache is populated), `false` if
/// they cancelled (cache untouched).
Future<bool> showConfirmPasswordSheet(
  BuildContext context, {
  required PasswordCache cache,
  String? message,
  bool afterRejection = false,
}) async {
  if (!afterRejection && cache.isExempt) return true;
  final subject = cache.currentSubject;
  final canApple =
      subject != null && subject.isApple && AppleSignIn.isSupported;
  final hasPassword = subject?.hasPassword ?? true;
  if (!hasPassword && !canApple) {
    final goSet = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _SetPasswordDialog(),
    );
    if (goSet == true && context.mounted) {
      GoRouter.of(context).go('/settings/user_details/password');
    }
    return false;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return _ConfirmPasswordDialog(
        message: message ?? ctx.tr('confirm_password_message'),
        showPasswordField: hasPassword,
        onConfirm: (pw) {
          cache.set(pw);
          Navigator.of(ctx).pop(true);
        },
        onConfirmWithApple: canApple
            ? (token) {
                cache.setOAuthToken(token);
                Navigator.of(ctx).pop(true);
              }
            : null,
        onCancel: () => Navigator.of(ctx).pop(false),
      );
    },
  );
  return confirmed ?? false;
}

/// For a user with no password to type (an OAuth sign-up) and no OAuth route
/// the server accepts: say so, and offer the Password tab.
class _SetPasswordDialog extends StatelessWidget {
  const _SetPasswordDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('confirm_password_title')),
      content: Text(
        context.tr('please_set_a_password'),
        style: TextStyle(color: context.inTheme.ink2),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          label: context.tr('set_password'),
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}

class _ConfirmPasswordDialog extends StatefulWidget {
  const _ConfirmPasswordDialog({
    required this.message,
    required this.showPasswordField,
    required this.onConfirm,
    required this.onConfirmWithApple,
    required this.onCancel,
  });

  final String message;
  final bool showPasswordField;
  final void Function(String password) onConfirm;

  /// Non-null when the user can re-authenticate with Apple instead.
  final void Function(String identityToken)? onConfirmWithApple;
  final VoidCallback onCancel;

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  bool _obscure = true;
  bool _appleBusy = false;
  String? _appleError;

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

  Future<void> _confirmWithApple() async {
    final onApple = widget.onConfirmWithApple;
    if (onApple == null || _appleBusy) return;
    setState(() {
      _appleBusy = true;
      _appleError = null;
    });
    String? token;
    String? error;
    try {
      token = await AppleSignIn.identityToken();
    } on Object catch (e) {
      error = formatNotifyError(e);
    }
    if (!mounted) return;
    setState(() {
      _appleBusy = false;
      _appleError = error;
    });
    if (token != null) onApple(token);
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
            if (widget.showPasswordField) ...[
              SizedBox(height: InSpacing.md(context)),
              _PasswordField(
                controller: _controller,
                obscure: _obscure,
                onObscureToggle: () => setState(() => _obscure = !_obscure),
                onChanged: (_) => setState(() {}),
                onSubmitted: _submit,
              ),
            ],
            if (widget.onConfirmWithApple != null) ...[
              SizedBox(height: InSpacing.md(context)),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                icon: _appleBusy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.apple),
                label: Text(context.tr('confirm_with_apple')),
                onPressed: _appleBusy ? null : _confirmWithApple,
              ),
              if (_appleError != null) ...[
                SizedBox(height: InSpacing.sm),
                Text(
                  _appleError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: Text(context.tr('cancel')),
        ),
        // With no field to fill, Apple is the only way to confirm — the button
        // above is the primary, and a Confirm that can never enable would
        // only suggest a password exists.
        if (widget.showPasswordField)
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
      keyboardType: TextInputType.visiblePassword,
      autocorrect: false,
      enableSuggestions: false,
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
