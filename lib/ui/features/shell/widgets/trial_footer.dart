import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/l10n/localization.dart';

/// Small trial-info card pinned to the bottom of the sidebar. Auto-hides
/// when there isn't an active trial to advertise — reads
/// [AuthSession.isTrial] (which factors in `trialStarted`, `numTrialDays`
/// and the countdown) so an expired trial doesn't keep nagging.
///
/// Displays [AuthSession.trialDaysRemaining] (not `numTrialDays` — that's
/// the full provisioned length, which always reads "14 days" until the
/// trial ends). At ≤3 days the card escalates: tinted background, warning
/// border, and a "Manage Plan" link so the user can act without leaving
/// the page.
class TrialFooter extends StatelessWidget {
  const TrialFooter({this.compact = false, super.key});

  /// Hidden entirely when true (collapsed wide sidebar — the trial copy
  /// doesn't fit in 64 px and isn't critical).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return const SizedBox.shrink();
    final session = context.read<Services>().auth.session;
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: session,
      builder: (context, value, _) {
        // `isHosted &&`, not a bare `isTrial`: a trial is a hosted-only
        // concept, but the server reuses `trial_days_left` on self-hosted as a
        // *white-label license* countdown (`AccountTransformer`:
        // `isSelfHost() ? getTrialDays() : 0`), so `isTrial` flips true for the
        // last fortnight of a perfectly valid license. Without this guard a
        // licensed self-hosted user is told their free trial expires in 7 days
        // — escalating to the red urgent card at <=3. `_PlanStatusCard` and
        // `_PlanCard` already carry the same guard.
        //
        // Caveat worth knowing before "fixing" this: hosted sends a literal 0
        // for `trial_days_left` and never sends `num_trial_days`, so
        // `AuthSession.isTrial` is currently unreachable on hosted too and this
        // card renders nowhere. That is a separate defect in `isTrial` (it also
        // costs trialing users their Pro feature access) — do not paper over it
        // by reverting the guard here.
        if (value == null || !value.isHosted || !value.isTrial) {
          return const SizedBox.shrink();
        }
        final tokens = context.inTheme;
        final days = value.trialDaysRemaining;
        final urgent = days <= 3;
        // Shares its slot with `WhiteLabelFooter`, so the two must carry the
        // same insets: no top (the footer icon row above already ends with
        // 8 px — invoiceninja/flutter#124), 12 at the bottom.
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: urgent ? tokens.overdueSoft : tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(InRadii.r2),
              border: Border.all(
                color: urgent ? tokens.overdue : tokens.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(
                    days == 1
                        ? 'trial_days_left_singular'
                        : 'trial_days_left_plural',
                    {'count': days.toString()},
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: urgent ? tokens.overdue : tokens.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr('upgrade_pitch'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: urgent ? tokens.overdue : tokens.ink3,
                  ),
                ),
                if (urgent) ...[
                  const SizedBox(height: 6),
                  // The `Material` is not decoration: an `InkWell` paints its
                  // splash and highlight onto the nearest ancestor `Material`,
                  // which draws its ink features *below* its whole child
                  // subtree — and there are two opaque boxes between this and
                  // the Scaffold's: the `Container` just above, and
                  // `InSidebar`'s `AnimatedContainer(color: tokens.surface)`.
                  // Without a local ink layer the tap is completely silent.
                  // Same mechanism as invoiceninja/flutter#124's third defect,
                  // and the reason every other InkWell in the sidebar carries
                  // one (`sidebar_nav_item.dart`, `sidebar_footer_actions.dart`).
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      // Plan is the shell's bare-URL default tab — `/plan` is
                      // not a matchable route.
                      onTap: () => context.go('/settings/account_management'),
                      child: Text(
                        context.tr('plan_change'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: tokens.overdue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
