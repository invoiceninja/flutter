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
/// hosted. Who may see it at all is entirely [shouldNagForWhiteLabel]'s call,
/// so the demo build and non-admins never do — but that is not the only gate
/// any more; see the viewport note below.
///
/// Not dismissible, like both reference apps' versions — a self-hosted user
/// who never intends to buy carries it. The one place it stands down is a
/// viewport too short to afford it: `InSidebar` skips it when
/// `sidebarShowsUpsell` says no (a landscape phone), where it would cost about
/// a nav row out of three and a half. That gate lives at the call site, not
/// here, so this widget stays pure and directly pumpable.
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
        // No top inset: `SidebarFooterActions` above already ends with 8 px,
        // and paying its 8 plus a 12 here is half of what made the gap in
        // invoiceninja/flutter#124 read as a layout failure. The 12 at the
        // bottom is the card's own breathing room; the gesture-bar inset is a
        // separate gutter the sidebar's outer SafeArea pays below it.
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          // The fill rides on a **local `Material`**, and the border on a
          // colour-less `Container` inside the `InkWell`. This was an `Ink`,
          // which was invoiceninja/flutter#124's third defect: `Ink` registers
          // an `InkDecoration` on the *nearest ancestor* `Material` — here the
          // Scaffold's or the Drawer's, since `InSidebar` has none of its own —
          // and `_RenderInkFeatures.paint` draws every ink feature *before* its
          // child subtree. `InSidebar`'s opaque `AnimatedContainer(color:
          // tokens.surface)` sits in that subtree, so the fill, the border and
          // the tap ripple were all painted and then covered: the card had
          // rendered as a bare line of text since the day it shipped.
          //
          // A local Material has its own ink layer above that background, and
          // the border-only `Container` isn't opaque, so the ripple still shows
          // through it. This is the shape `sidebar_search_box.dart`,
          // `sidebar_sync_button.dart` and `company_switcher_button.dart`
          // already use — which is why *their* fills were never affected. No
          // `clipBehavior`: `InkWell.borderRadius` already clips the splash and
          // the highlight to the same radius.
          child: Material(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(InRadii.r2),
            child: InkWell(
              borderRadius: BorderRadius.circular(InRadii.r2),
              onTap: () => unawaited(launchWhiteLabelPurchase(context)),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(InRadii.r2),
                  border: Border.all(color: tokens.border),
                ),
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
