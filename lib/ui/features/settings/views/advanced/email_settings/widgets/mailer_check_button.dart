import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/services/api_exception.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/views/advanced/email_settings/mailer_check.dart';

/// "Send Test Email" for the API and OAuth mailers (React #3357) — the twin
/// of the SMTP card's button, in the same trailing slot of the provider's
/// section. Sends a real email, from the configured mailer, to the signed-in
/// user.
///
/// Disabled, with the reason as a tooltip, until it can work: a required
/// credential is blank, or (OAuth) the sending user on screen isn't the one
/// saved — the server tests the SAVED user, so testing an unsaved pick would
/// report on the wrong mailbox. A 429 keeps it disabled for `Retry-After`.
class MailerCheckButton extends StatefulWidget {
  const MailerCheckButton({
    required this.method,
    this.expand = false,
    super.key,
  });

  /// The `email_sending_method` being tested.
  final String method;

  /// Full width — the narrow layout's placement below the fields.
  final bool expand;

  @override
  State<MailerCheckButton> createState() => _MailerCheckButtonState();
}

class _MailerCheckButtonState extends State<MailerCheckButton> {
  bool _busy = false;
  DateTime? _coolingUntil;
  Timer? _cooldown;

  @override
  void dispose() {
    _cooldown?.cancel();
    super.dispose();
  }

  void _coolFor(Duration wait) {
    _cooldown?.cancel();
    setState(() => _coolingUntil = DateTime.now().add(wait));
    _cooldown = Timer(wait, () {
      if (mounted) setState(() => _coolingUntil = null);
    });
  }

  Future<void> _run(Map<String, dynamic> payload, String userEmail) async {
    setState(() => _busy = true);
    final services = context.read<Services>();
    try {
      await services.smtp.checkMailer(payload: payload);
      if (!mounted) return;
      Notify.success(
        context,
        context.tr('test_email_sent'),
        detail: userEmail.isEmpty ? null : userEmail,
      );
    } on RateLimitedException catch (e) {
      if (!mounted) return;
      _coolFor(e.retryAfter ?? const Duration(minutes: 1));
      Notify.error(context, context.tr('too_many_requests'));
    } on ValidationException catch (e) {
      if (!mounted) return;
      final first = e.fieldErrors.values.expand((v) => v).firstOrNull;
      Notify.error(context, context.tr('error'), detail: first ?? e.message);
    } on ApiException catch (e) {
      // A failed send is a 400 with untranslated English — the detail line.
      if (!mounted) return;
      Notify.error(context, context.tr('error'), detail: e.message);
    } catch (e) {
      if (!mounted) return;
      Notify.error(context, context.tr('error'), error: e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<SettingsDraftHost>();
    final userEmail =
        context.read<Services>().auth.session.value?.userEmail ?? '';
    final built = buildMailerCheckPayload(
      method: widget.method,
      settings: host.draftSettings,
      userEmail: userEmail,
    );
    final oauthUnsaved =
        kOAuthMailers.contains(widget.method) &&
        (host.draftSettings.gmailSendingUserId ?? '') !=
            (host.initialSettings.gmailSendingUserId ?? '');
    final String? blockedBy = oauthUnsaved
        ? context.tr('unsaved_changes')
        : built.missing.isNotEmpty
        ? context.tr('please_enter_a_value')
        : _coolingUntil != null
        ? context.tr('too_many_requests')
        : null;

    Widget button = OutlinedButton.icon(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
      icon: _busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_outlined),
      label: Text(context.tr('send_test_email')),
      onPressed: _busy || blockedBy != null
          ? null
          : () => _run(built.payload, userEmail),
    );
    if (blockedBy != null) button = Tooltip(message: blockedBy, child: button);
    return widget.expand
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
