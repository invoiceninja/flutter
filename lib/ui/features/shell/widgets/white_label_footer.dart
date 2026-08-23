import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/upgrade/white_label.dart';
import 'package:admin/l10n/localization.dart';

/// Sidebar upsell for the self-hosted white-label license — the v2 counterpart
/// to React's top-bar `white_label_button` (`Default.tsx:219`) and
/// admin-portal's dashboard rocket icon (`dashboard_screen.dart:236-251`).
///
/// Sits beside [TrialFooter] in the sidebar footer, and the two are mutually
/// exclusive by construction: this one requires self-hosted, that one requires
/// hosted. Visibility is entirely [shouldNagForWhiteLabel]'s call, so the demo
/// build and non-admins never see it.
///
/// Like both reference apps' versions, it is not dismissible — a self-hosted
/// user who never intends to buy carries it. Revisit if that grates.
class WhiteLabelFooter extends StatelessWidget {
  const WhiteLabelFooter({this.compact = false, super.key});

  /// Hidden entirely when true (collapsed rail — the label doesn't fit in
  /// 64 px and this is the least critical thing in the footer).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return const SizedBox.shrink();
    final session = context.read<Services>().auth.session;
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: session,
      builder: (context, value, _) {
        if (!shouldNagForWhiteLabel(value)) return const SizedBox.shrink();
        final tokens = context.inTheme;
        return Padding(
          padding: const EdgeInsets.all(12),
          // `Ink`, not a `Container`: a Material paints its ink features
          // *beneath* its child, so an opaque `Container` inside the `InkWell`
          // would hide the ripple and hover highlight entirely — the card's
          // whole job is to look tappable. `Ink` paints the decoration into
          // the Material itself so the splash composites above it.
          child: Ink(
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(InRadii.r2),
              border: Border.all(color: tokens.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(InRadii.r2),
              onTap: () => unawaited(launchWhiteLabelPurchase(context)),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(
                      Icons.rocket_launch_outlined,
                      size: 16,
                      color: tokens.accent,
                    ),
                    const SizedBox(width: InSpacing.sm),
                    Expanded(
                      child: Text(
                        context.tr('white_label_button'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tokens.ink,
                        ),
                      ),
                    ),
                    Icon(Icons.open_in_new, size: 14, color: tokens.ink3),
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
