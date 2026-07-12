import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';

/// Opens the Contact Us dialog from the sidebar footer.
///
/// Captures the active [AuthSession] and the parent [ScaffoldMessenger] before
/// `showDialog` so a logout / drawer-pop mid-flight can't strand the post-send
/// toast on a defunct context. Bails silently when there's no session (the
/// sidebar shouldn't render in that case anyway).
Future<void> showContactUsDialog(BuildContext context) {
  final session = context.read<Services>().auth.session.value;
  if (session == null) return Future.value();
  final messenger = ScaffoldMessenger.maybeOf(context);
  return showDialog<void>(
    context: context,
    // Locked from open: a mid-flight POST must complete (or fail) before the
    // dialog can disappear, otherwise the post-await setState fires on a
    // disposed widget.
    barrierDismissible: false,
    builder: (ctx) => _ContactUsDialog(session: session, messenger: messenger),
  );
}

class _ContactUsDialog extends StatefulWidget {
  const _ContactUsDialog({required this.session, required this.messenger});

  final AuthSession session;
  final ScaffoldMessengerState? messenger;

  @override
  State<_ContactUsDialog> createState() => _ContactUsDialogState();
}

class _ContactUsDialogState extends State<_ContactUsDialog> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    // setState is cheap here and trivially correct — drives Send's enabled
    // state off the trimmed length.
    setState(() {});
  }

  bool get _canSend => _controller.text.trim().isNotEmpty && !_isSending;

  Future<void> _send() async {
    if (!_canSend) return;
    setState(() => _isSending = true);
    final services = context.read<Services>();
    final navigator = Navigator.of(context);
    final loc = Localization.of(context);
    String tr(String key) => loc?.lookup(key) ?? key;
    String version;
    try {
      final info = await PackageInfo.fromPlatform();
      version = '${info.version}+${info.buildNumber}';
    } catch (_) {
      version = 'unknown';
    }
    try {
      await services.support.sendMessage(
        message: _controller.text.trim(),
        appVersion: version,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      Notify.error(context, tr('error'), error: e, messenger: widget.messenger);
      return;
    }
    if (!mounted) return;
    navigator.pop();
    final m = widget.messenger;
    if (m != null) {
      Notify.success(
        navigator.context,
        tr('your_message_has_been_received'),
        messenger: m,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final identity = widget.session.userEmail;
    return PopScope(
      // Block Android back / Escape while a POST is in flight.
      canPop: !_isSending,
      child: AlertDialog(
        title: Text(context.tr('contact_us')),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 420,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (identity.isNotEmpty)
                  Text(
                    identity,
                    style: TextStyle(fontSize: 12, color: tokens.ink3),
                  ),
                SizedBox(height: InSpacing.md(context)),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  maxLines: 6,
                  minLines: 4,
                  enabled: !_isSending,
                  keyboardType: TextInputType.multiline,
                  // Multi-line: Enter inserts a newline (per CLAUDE.md form
                  // conventions). No FormSaveScope wiring here.
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    labelText: context.tr('message'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          OutlinedButton(
            // Override the theme's full-width minimumSize so Cancel fits
            // beside Send instead of stacking.
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: _isSending ? null : () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: context.tr('send'),
            enabled: _canSend,
            busy: _isSending,
            // Multi-line message field: Enter inserts a newline, so it owns
            // focus and there's no Enter-to-submit path — no hint.
            autofocus: false,
            showEnterHint: false,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}
