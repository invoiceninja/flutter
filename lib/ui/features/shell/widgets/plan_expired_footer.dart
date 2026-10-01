import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/upgrade/upgrade_launcher.dart';
import 'package:admin/l10n/localization.dart';

/// "Account plan expired — Pay now" for the account owner of a hosted paid
/// plan that has lapsed (React #3222's `AccountPlanExpired` banner), pinned in
/// the sidebar's footer slot beside [TrialFooter] — the app's standing home
/// for plan state, reachable from the drawer on a phone. The settings pages'
/// `PlanGateBanner` says the same thing in context; this is the one surface
/// that says it everywhere else.
///
/// Same condition as React and `PlanGateBanner`: hosted, owner, a paid slug
/// still on the session, and [AuthSession.isPlanExpired] — mutually exclusive
/// with the trial card, which needs an active trial. Pay Now goes through
/// [launchUpgrade], the one platform-aware upgrade seam (store billing on
/// iOS / Android, the portal elsewhere).
class PlanExpiredFooter extends StatelessWidget {
  const PlanExpiredFooter({this.compact = false, super.key});

  /// Hidden when the wide sidebar is collapsed — the copy doesn't fit.
  final bool compact;

  /// Pure so the gate is testable without a widget tree.
  ///
  /// No `plan` check, unlike React's banner: the server reports `plan` as
  /// `''` from the moment `plan_expires` passes (`Account::getPlan`), so
  /// requiring it would hide the footer from exactly the accounts it is for.
  /// [AuthSession.isPlanExpired] needs a `plan_expires` date, so an account
  /// that never had a plan or a trial never sees it; an ended trial does.
  static bool shows(AuthSession? s) =>
      s != null &&
      s.isHosted &&
      (s.currentCompany?.isOwner ?? false) &&
      s.isPlanExpired;

  @override
  Widget build(BuildContext context) {
    if (compact) return const SizedBox.shrink();
    final session = context.read<Services>().auth.session;
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: session,
      builder: (context, value, _) {
        if (!shows(value)) return const SizedBox.shrink();
        final tokens = context.inTheme;
        // Same insets as `TrialFooter`, whose slot this shares.
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tokens.overdueSoft,
              borderRadius: BorderRadius.circular(InRadii.r2),
              border: Border.all(color: tokens.overdue),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('account_plan_expired'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.overdue,
                  ),
                ),
                const SizedBox(height: 6),
                // A local ink layer — see `TrialFooter` for why the sidebar's
                // opaque boxes would otherwise swallow the splash.
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => launchUpgrade(context),
                    child: Text(
                      context.tr('pay_now'),
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
            ),
          ),
        );
      },
    );
  }
}
