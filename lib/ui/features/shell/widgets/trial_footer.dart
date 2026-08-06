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
        if (value == null || !value.isTrial) {
          return const SizedBox.shrink();
        }
        final tokens = context.inTheme;
        final days = value.trialDaysRemaining;
        final urgent = days <= 3;
        return Padding(
          padding: const EdgeInsets.all(12),
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
                  InkWell(
                    // Plan is the shell's bare-URL default tab — `/plan` is not
                    // a matchable route.
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
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
