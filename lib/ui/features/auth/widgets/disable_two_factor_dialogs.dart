import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/auth/view_models/login_view_model.dart';

/// The login screen's lost-authenticator reset — React's `Disable2faModal`:
/// text a code to the phone on file, then verify it, which turns 2FA off.
///
/// Two dialogs rather than one so each has a single primary action. The first
/// pops with the address the code went to (the user may have edited it) and
/// the login screen opens the second with that address, so its "Resend code"
/// texts the same account.
///
/// Differences from React, all deliberate: the email starts filled in with
/// the one on the login form (React's starts empty); both dialogs can be
/// cancelled; and "Resend code" is a link in the body, not a third action —
/// two translated labels plus Cancel don't fit side by side on a phone, and
/// `AlertDialog` stacks actions that don't fit.

/// Opens the "send code" dialog. Resolves to the address the code was sent
/// to, or null when cancelled.
///
/// Neither dialog closes on a barrier tap, and neither can be popped while
/// its request is in flight (`contact_us_dialog.dart`'s pattern): a Send
/// dismissed mid-flight still texts a code — spending one of hosted's twelve
/// daily-verify sends — with no Verify dialog left to type it into.
Future<String?> showSendTwoFactorResetCodeDialog(
  BuildContext context, {
  required LoginViewModel vm,
}) => showDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _SendCodeDialog(vm: vm),
);

/// Opens the "verify code" dialog for [email]. Resolves to true once 2FA has
/// been disabled.
Future<bool> showConfirmTwoFactorResetDialog(
  BuildContext context, {
  required LoginViewModel vm,
  required String email,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _VerifyCodeDialog(vm: vm, email: email),
    ) ??
    false;

/// What to toast for a failed step. A 422's per-field message says more than
/// Laravel's generic top-level one, so it wins.
String _failureText(BuildContext context, TwoFactorResetResult result) {
  if (result.errorKey != null) {
    return context.tr(result.errorKey!, result.errorParams);
  }
  for (final messages in result.fieldErrors.values) {
    if (messages.isNotEmpty) return messages.first;
  }
  return result.errorMessage ?? context.tr('an_error_occurred');
}

class _SendCodeDialog extends StatefulWidget {
  const _SendCodeDialog({required this.vm});

  final LoginViewModel vm;

  @override
  State<_SendCodeDialog> createState() => _SendCodeDialogState();
}

class _SendCodeDialogState extends State<_SendCodeDialog> {
  late final TextEditingController _email = TextEditingController(
    text: widget.vm.email,
  );
  bool _busy = false;

  /// A 422's reason for the address (the server's `exists:users,email`),
  /// shown under the field rather than toasted.
  String? _emailError;

  bool get _canSend => !_busy && _email.text.trim().isNotEmpty;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_canSend) return;
    final target = _email.text.trim();
    setState(() {
      _busy = true;
      _emailError = null;
    });
    final result = await widget.vm.sendTwoFactorResetCode(target);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      final fieldError = result.fieldErrors['email'];
      if (fieldError != null && fieldError.isNotEmpty) {
        setState(() => _emailError = fieldError.first);
      } else {
        Notify.error(context, _failureText(context, result));
      }
      return;
    }
    Notify.success(context, context.tr('code_was_sent'));
    Navigator.of(context).pop(target);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: !_busy, child: _buildDialog(context));
  }

  Widget _buildDialog(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('disable_2fa')),
      content: SizedBox(
        width: 400,
        child: TextField(
          key: const ValueKey('disable_2fa_email'),
          controller: _email,
          autofocus: true,
          // Read-only, not disabled, while sending: a disabled field drops
          // focus, so after a failure the user would have to click back in.
          readOnly: _busy,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.tr('email'),
            errorText: _emailError,
          ),
          onChanged: (_) => setState(() => _emailError = null),
          // Enter sends. The no-op keeps the framework's `done` handling
          // from unfocusing the field first, so after a failure the user
          // can retype straight away.
          onEditingComplete: () {},
          onSubmitted: (_) => _send(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          buttonKey: const ValueKey('disable_2fa_send'),
          label: context.tr('send_code'),
          enabled: _canSend,
          busy: _busy,
          // The email field owns focus; Enter reaches this via onSubmitted.
          autofocus: false,
          onPressed: _send,
        ),
      ],
    );
  }
}

class _VerifyCodeDialog extends StatefulWidget {
  const _VerifyCodeDialog({required this.vm, required this.email});

  final LoginViewModel vm;
  final String email;

  @override
  State<_VerifyCodeDialog> createState() => _VerifyCodeDialogState();
}

class _VerifyCodeDialogState extends State<_VerifyCodeDialog> {
  static const _codeLength = 6;

  final _code = TextEditingController();
  bool _busy = false;
  bool _resending = false;

  bool get _canVerify =>
      !_busy && !_resending && _code.text.length == _codeLength;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_canVerify) return;
    setState(() => _busy = true);
    final result = await widget.vm.confirmTwoFactorReset(
      widget.email,
      _code.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!result.ok) {
      Notify.error(context, _failureText(context, result));
      return;
    }
    Notify.success(context, context.tr('disabled_two_factor'));
    Navigator.of(context).pop(true);
  }

  Future<void> _resend() async {
    if (_busy || _resending) return;
    setState(() => _resending = true);
    final result = await widget.vm.sendTwoFactorResetCode(widget.email);
    if (!mounted) return;
    setState(() => _resending = false);
    if (result.ok) {
      Notify.success(context, context.tr('code_was_sent'));
    } else {
      Notify.error(context, _failureText(context, result));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy && !_resending,
      child: _buildDialog(context),
    );
  }

  Widget _buildDialog(BuildContext context) {
    final tokens = context.inTheme;
    return AlertDialog(
      title: Text(context.tr('disable_two_factor')),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('disable_2fa_code'),
              controller: _code,
              autofocus: true,
              readOnly: _busy,
              keyboardType: TextInputType.number,
              autocorrect: false,
              enableSuggestions: false,
              autofillHints: const [AutofillHints.oneTimeCode],
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(_codeLength),
              ],
              decoration: InputDecoration(labelText: context.tr('sms_code')),
              onChanged: (_) => setState(() {}),
              // See the email field: Enter verifies without unfocusing, so
              // an early Enter (five digits) leaves the user still typing.
              onEditingComplete: () {},
              onSubmitted: (_) => _verify(),
            ),
            SizedBox(height: InSpacing.md(context)),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                key: const ValueKey('disable_2fa_resend'),
                onPressed: (_busy || _resending) ? null : _resend,
                style: TextButton.styleFrom(foregroundColor: tokens.accentInk),
                child: Text(context.tr('resend_code')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          // Disabled during a resend too: `Navigator.pop` ignores `PopScope`.
          onPressed: (_busy || _resending)
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(context.tr('cancel')),
        ),
        PrimaryDialogAction(
          buttonKey: const ValueKey('disable_2fa_verify'),
          label: context.tr('verify'),
          enabled: _canVerify,
          busy: _busy,
          // Starts disabled, so it can't take autofocus; the code field owns
          // focus. The ↵ hint stays despite CLAUDE.md's "starts disabled ⇒
          // showEnterHint: false" rule, because that rule is about a button
          // Enter can never reach — here the code field's `onSubmitted` calls
          // `_verify` directly, which runs once six digits are in.
          autofocus: false,
          onPressed: _verify,
        ),
      ],
    );
  }
}
