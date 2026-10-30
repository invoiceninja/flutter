import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/mobile_app_promo_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/mobile_app_promo.dart';
import 'package:admin/domain/upgrade/white_label.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/mobile_promo/mobile_app_promo_dialog.dart';
import 'package:admin/ui/features/shell/widgets/plan_expired_footer.dart';
import 'package:admin/ui/features/shell/widgets/update_available_footer.dart';

/// "Get the mobile app" — the sidebar's way back to the mobile-app promo
/// (docs/mobile-app-promo.md), in `WhiteLabelFooter`'s shape.
///
/// The least important card in the footer, so it yields: to a trial, an
/// expired plan, an available server update or the white-label offer (one
/// card at a time), to a viewport too short for optional chrome
/// ([affordable], `sidebarShowsUpsell`), and to the collapsed rail, where an
/// unlabelled phone glyph would read as "call".
/// It goes for good once the user says "Don't show again", takes the app, or
/// lets every automatic reminder pass — About and Device Settings still open
/// the promo after that.
class MobileAppPromoFooter extends StatelessWidget {
  const MobileAppPromoFooter({
    this.compact = false,
    this.touch = false,
    this.affordable = true,
    this.onBeforeOpen,
    super.key,
  });

  final bool compact;

  /// Floors the card at the touch target.
  final bool touch;

  /// The viewport has room for optional chrome — `sidebarShowsUpsell`.
  final bool affordable;

  /// Closes the mobile drawer before the dialog opens over it.
  final VoidCallback? onBeforeOpen;

  /// Whether one of the footer's other cards is showing — they all outrank
  /// this one.
  static bool otherCardShows(AuthSession? s, {required bool affordable}) =>
      s != null &&
      ((s.isHosted && s.isTrial) ||
          PlanExpiredFooter.shows(s) ||
          (affordable &&
              (shouldNagForWhiteLabel(s) || UpdateAvailableFooter.shows(s))));

  @override
  Widget build(BuildContext context) {
    if (compact || !affordable) return const SizedBox.shrink();
    final controller = context.read<MobileAppPromoController?>();
    // Unasked chrome, so only in a build that promotes the phone app — not
    // in a harness, where it would shorten the nav list a test taps.
    if (controller == null ||
        !controller.promote ||
        currentMobilePromoTargets().isEmpty) {
      return const SizedBox.shrink();
    }
    final session = context.read<Services>().auth.session;
    return ListenableBuilder(
      listenable: Listenable.merge([session, controller]),
      builder: (context, _) {
        final value = session.value;
        if (!controller.showsSidebarCard ||
            !mobilePromoEligible(value) ||
            otherCardShows(value, affordable: affordable)) {
          return const SizedBox.shrink();
        }
        final tokens = context.inTheme;
        // Same insets as `WhiteLabelFooter`, whose slot this shares, and the
        // same local `Material` + `InkWell` — never `Ink`, which painted under
        // the sidebar's opaque background (invoiceninja/flutter#124).
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Material(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(InRadii.r2),
            child: InkWell(
              borderRadius: BorderRadius.circular(InRadii.r2),
              onTap: () {
                onBeforeOpen?.call();
                unawaited(showMobileAppPromoDialog(context, isManual: true));
              },
              child: Container(
                constraints: BoxConstraints(
                  minHeight: touch ? InSizes.touchTarget : 0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(InRadii.r2),
                  border: Border.all(color: tokens.border),
                ),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(
                      Icons.smartphone_outlined,
                      size: 16,
                      color: tokens.accent,
                    ),
                    const SizedBox(width: InSpacing.sm),
                    Expanded(
                      child: Text(
                        context.tr('mobile_app_promo_entry'),
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
