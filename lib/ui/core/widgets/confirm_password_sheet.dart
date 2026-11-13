import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/services/apple_sign_in.dart';
import 'package:admin/data/services/password_cache.dart';
import 'package:admin/data/services/web_oauth.dart';
import 'package:admin/data/services/web_sign_in.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/field_text_direction.dart';
import 'package:admin/ui/core/widgets/microsoft_logo.dart';
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
///  * an Apple user where Apple sign-in works can "Confirm with Apple", and a
///    Microsoft user on web "Confirm with Microsoft" (docs/web-deploy.md §
///    Web sign-in) — the provider's token is cached for
///    `X-API-OAUTH-PASSWORD`. Google has no such button: the server's Google
///    branch can't accept one (docs/passkeys.md § Google re-authentication);
///  * a user with no password and no such route gets "Please set an account
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
  final reauth = _reauthFor(subject);
  final hasPassword = subject?.hasPassword ?? true;
  if (!hasPassword && reauth == null) {
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
        reauth: reauth,
        onConfirmWithProvider: (token) {
          cache.setOAuthToken(token);
          Navigator.of(ctx).pop(true);
        },
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

/// How a user without a usable password can confirm with their sign-in
/// provider instead: the button's glyph and label, and the token to send.
typedef _Reauth = ({
  Widget icon,
  String labelKey,
  Future<String?> Function() token,
});

_Reauth? _reauthFor(PasswordSubject? subject) {
  if (subject == null) return null;
  if (subject.isApple && AppleSignIn.isSupported) {
    return (
      icon: const Icon(Icons.apple),
      labelKey: 'confirm_with_apple',
      token: AppleSignIn.identityToken,
    );
  }
  if (subject.isMicrosoft && WebSignIn.microsoftEnabled) {
    return (
      icon: const MicrosoftLogo(),
      labelKey: 'confirm_with_microsoft',
      token: WebSignIn.microsoftAccessToken,
    );
  }
  return null;
}

class _ConfirmPasswordDialog extends StatefulWidget {
  const _ConfirmPasswordDialog({
    required this.message,
    required this.showPasswordField,
    required this.onConfirm,
    required this.reauth,
    required this.onConfirmWithProvider,
    required this.onCancel,
  });

  final String message;
  final bool showPasswordField;
  final void Function(String password) onConfirm;

  /// Non-null when the user can re-authenticate with their provider instead.
  final _Reauth? reauth;
  final void Function(String token) onConfirmWithProvider;
  final VoidCallback onCancel;

  @override
  State<_ConfirmPasswordDialog> createState() => _ConfirmPasswordDialogState();
}

class _ConfirmPasswordDialogState extends State<_ConfirmPasswordDialog> {
  bool _obscure = true;
  bool _providerBusy = false;
  String? _providerError;

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

  Future<void> _confirmWithProvider() async {
    final reauth = widget.reauth;
    if (reauth == null || _providerBusy) return;
    setState(() {
      _providerBusy = true;
      _providerError = null;
    });
    // Read before the await: the window can take a minute.
    final blocked = context.tr('web_sign_in_blocked');
    final loading = context.tr('web_sign_in_loading');
    final unavailable = context.tr('web_sign_in_unavailable');
    String? token;
    String? error;
    try {
      // On web this opens the provider's window: nothing is awaited first.
      token = await reauth.token();
    } on WebOAuthException catch (e) {
      error = switch (e.failure) {
        WebOAuthFailure.blocked => blocked,
        WebOAuthFailure.notLoaded => loading,
        WebOAuthFailure.unavailable => unavailable,
        WebOAuthFailure.failed => e.message.isEmpty ? '$e' : e.message,
      };
    } on Object catch (e) {
      error = formatNotifyError(e);
    }
    if (!mounted) return;
    setState(() {
      _providerBusy = false;
      _providerError = error;
    });
    if (token != null && token.isNotEmpty) widget.onConfirmWithProvider(token);
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
            if (widget.reauth case final reauth?) ...[
              SizedBox(height: InSpacing.md(context)),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(64, 40),
                ),
                icon: _providerBusy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : reauth.icon,
                label: Text(context.tr(reauth.labelKey)),
                onPressed: _providerBusy ? null : _confirmWithProvider,
              ),
              if (_providerError != null) ...[
                SizedBox(height: InSpacing.sm),
                Text(
                  _providerError!,
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
        // With no field to fill, the provider is the only way to confirm —
        // the button above is the primary, and a Confirm that can never enable would
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
      textDirection: TextDirection.ltr,
      textAlign: ltrValueAlign(context, ltr: true),
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
