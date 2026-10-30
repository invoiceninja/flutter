import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/self_update.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/shell/widgets/self_update_dialog.dart';

/// "Update Available" — tells a self-hosted admin their server has a newer
/// release, and opens [showSelfUpdateDialog]. The v2 counterpart to
/// admin-portal's sidebar warning icon and React's help-bar download icon.
///
/// In `WhiteLabelFooter`'s shape, and like it gated by `InSidebar` on
/// `sidebarShowsUpsell`: on a viewport too short for optional chrome it
/// stands down, and About → Update App still reaches the dialog.
class UpdateAvailableFooter extends StatelessWidget {
  const UpdateAvailableFooter({
    this.compact = false,
    this.onBeforeOpen,
    super.key,
  });

  /// Hidden when the wide sidebar is collapsed — the label doesn't fit.
  final bool compact;

  /// Closes the mobile drawer before the dialog opens over it.
  final VoidCallback? onBeforeOpen;

  /// Pure so the gate is testable without a widget tree.
  static bool shows(AuthSession? s) =>
      selfUpdateOffer(s) == SelfUpdateOffer.update;

  @override
  Widget build(BuildContext context) {
    if (compact) return const SizedBox.shrink();
    final session = context.read<Services>().auth.session;
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: session,
      builder: (context, value, _) {
        if (!shows(value)) return const SizedBox.shrink();
        final tokens = context.inTheme;
        // A local Material carries the fill — see `WhiteLabelFooter` for why
        // an `Ink` here would paint under the sidebar's background.
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Material(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(InRadii.r2),
            child: InkWell(
              borderRadius: BorderRadius.circular(InRadii.r2),
              onTap: () {
                onBeforeOpen?.call();
                unawaited(showSelfUpdateDialog(context));
              },
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(InRadii.r2),
                  border: Border.all(color: tokens.border),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(
                      Icons.system_update_alt,
                      size: 16,
                      color: tokens.accent,
                    ),
                    const SizedBox(width: InSpacing.sm),
                    Expanded(
                      child: Text(
                        context.tr('update_available'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: tokens.ink3),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
