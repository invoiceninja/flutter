import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/idle_timeout_controller.dart';
import 'package:admin/l10n/localization.dart';

/// Slim strip across the top of the authenticated shell for the last couple of
/// minutes before the company's Web Session Timeout signs the user out
/// (`IdleTimeoutController.expiringSoon` — web only, so this never shows in
/// the native apps). Stay Logged In counts as activity; so does any pointer or
/// key event, which clears the strip just the same.
class SessionExpiryBanner extends StatelessWidget {
  const SessionExpiryBanner({super.key});

  @override
  Widget build(BuildContext context) {
    // A shell pumped without the root provider (a widget test) shows nothing.
    final controller = context.read<IdleTimeoutController?>();
    if (controller == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: controller.expiringSoon,
      builder: (context, expiring, _) => expiring
          ? _SessionExpiryStrip(onStay: controller.poke)
          : const SizedBox.shrink(),
    );
  }
}

class _SessionExpiryStrip extends StatelessWidget {
  const _SessionExpiryStrip({required this.onStay});

  final VoidCallback onStay;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Material(
      key: const ValueKey('session_expiry_banner'),
      color: tokens.partialSoft,
      // The same inset handling as `OfflineBanner`.
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: InSpacing.lg(context),
            vertical: InSpacing.xs,
          ),
          child: Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: tokens.partial),
              const SizedBox(width: InSpacing.sm),
              Expanded(
                child: Text(
                  context.tr('session_about_to_expire'),
                  style: TextStyle(color: tokens.ink2, fontSize: 13),
                ),
              ),
              const SizedBox(width: InSpacing.sm),
              TextButton(
                key: const ValueKey('session_expiry_stay'),
                onPressed: onStay,
                child: Text(context.tr('stay_logged_in')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
