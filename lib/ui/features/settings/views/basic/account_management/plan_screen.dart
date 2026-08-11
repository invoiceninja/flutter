import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/upgrade/upgrade_launcher.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Search keys for the Plan tab. Colocated so the search catalog stays in
/// sync with what this screen actually renders.
const kAccountManagementPlanSearchKeys = <String>[
  'plan',
  'free',
  'pro',
  'enterprise',
  'free_trial',
  'change_plan',
  'expires_on',
  'days_left',
];

/// Localization key for the plan headline. Shared by this tab's status card
/// and the Overview tab's plan card, which sit two tabs apart and must not
/// disagree about the same account.
///
/// Hosted reads the plan slug. Self-hosted has no hosted plan, so it reports
/// *license* state instead — the bare "Free" this used to render read as a
/// downgrade on an install where every feature is in fact unlocked, and said
/// nothing about the white-label license the user may have bought (issue #27).
/// React does the same in its `Plan.tsx`, labelling a live license `licensed`;
/// we use the more explicit `plan_white_label` ("Self Hosted (White labeled)")
/// against `plan_free_self_hosted` ("Self Hosted (Free)"). Both keys already
/// ship in every bundled locale.
String planHeadlineKey(AuthSession session) {
  if (session.isSelfHosted) {
    return session.isWhiteLabeled
        ? 'plan_white_label'
        : 'plan_free_self_hosted';
  }
  return session.plan.isEmpty ? 'free' : session.plan;
}

/// Account Management → Plan. Read-mostly surface. The server pre-computes
/// `ninja_portal_url` (per-user hosted-billing URL); the screen displays the
/// current plan state and routes hosted users to that URL for upgrades /
/// downgrades / payment-method management. We do not render plan tiles or
/// payment methods in-app — the hosted page already does both natively and
/// pulling them client-side requires `account_key` plumbing that's not worth
/// the round-trip.
///
/// Self-hosted users see their license state (see [planHeadlineKey]) plus the
/// license expiry when one is applied; the Purchase / Apply License actions
/// live on the Overview tab's license card.
class AccountManagementPlanScreen extends StatelessWidget {
  const AccountManagementPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Services>().auth.session;
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: session,
      builder: (context, value, _) {
        if (value == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return SettingsFormShell(
          sections: [
            _PlanStatusCard(session: value),
            if (value.isHosted) _HostedActionsCard(session: value),
          ],
        );
      },
    );
  }
}

/// Plan-expiry display: format through the active company's [Formatter] so it
/// honors `date_format_id`, falling back to the raw date-only prefix when that
/// company's formatter isn't cached yet (rare — the active company's formatter
/// is loaded on company switch).
String _expiryDisplay(BuildContext context, AuthSession session) {
  final fmt = context.read<Services>().formatterIfReady(
    session.currentCompanyId,
  );
  final formatted = fmt?.date(session.planExpires) ?? '';
  return formatted.isNotEmpty
      ? formatted
      : session.planExpires.split(' ').first;
}

class _PlanStatusCard extends StatelessWidget {
  const _PlanStatusCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;

    // A trial is a hosted-only concept, and `session.isTrial` must NOT be
    // trusted on self-hosted. The server sends
    // `trial_days_left = isSelfHost() ? getTrialDays() : 0`
    // (`AccountTransformer`), and `Account::getTrialDays()` returns the days
    // remaining until `plan_expires` whenever that is within 14 — so on a
    // self-hosted install the field is a *white-label license* countdown, and
    // `isTrial` flips true for the last fortnight of a valid license. Gating
    // the trial chrome on `isHosted` keeps a licensed self-host from being
    // told it's on a free trial (with a bogus bar: the transformer never
    // sends `num_trial_days`, so the progress math clamps to 0).
    final isTrialing = session.isHosted && session.isTrial;
    final planLabel = context.tr(planHeadlineKey(session));
    final headline = isTrialing
        ? '$planLabel • ${context.tr('free_trial')}'
        : planLabel;
    // Hosted: the plan's renewal date. Self-hosted: the white-label license's
    // expiry — the one actionable date self-hosted has (renew via Overview →
    // License). An unlicensed self-host has no `plan_expires` at all. The
    // self-hosted branch deliberately skips the `isTrial` check above, or the
    // date would disappear during the exact fortnight it matters most.
    final showExpiry =
        session.planExpires.isNotEmpty &&
        (session.isHosted
            ? (!session.isTrial && session.plan.isNotEmpty)
            : session.isWhiteLabeled);

    return FormSection(
      title: context.tr('plan'),
      spacing: 0,
      children: [
        Text(
          headline,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: tokens.ink,
          ),
        ),
        if (showExpiry) ...[
          SizedBox(height: InSpacing.sm),
          Text(
            '${context.tr('expires_on')} ${_expiryDisplay(context, session)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink2),
          ),
        ],
        if (isTrialing) ...[
          SizedBox(height: InSpacing.md(context)),
          _TrialProgress(session: session),
        ],
        // Self-hosted: nothing more to render on this card — the license
        // section on Overview owns Purchase/Apply License, and there's no
        // hosted-billing portal to link to.
      ],
    );
  }
}

class _TrialProgress extends StatelessWidget {
  const _TrialProgress({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final total = session.numTrialDays <= 0 ? 1 : session.numTrialDays;
    final remaining = session.trialDaysRemaining;
    final progress = ((total - remaining) / total).clamp(0.0, 1.0);
    final label = context
        .tr('days_left')
        .replaceAll(':days', remaining.toString());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(InRadii.r1),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: tokens.border,
          ),
        ),
        SizedBox(height: InSpacing.sm),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink2),
        ),
      ],
    );
  }
}

class _HostedActionsCard extends StatelessWidget {
  const _HostedActionsCard({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final hasPortalUrl = session.ninjaPortalUrl.isNotEmpty;
    // On iOS / Android the button drives in-app purchase and needs no portal
    // URL; everywhere else it opens the hosted billing portal, so with no URL
    // there's nowhere to send the user (launchUpgrade would otherwise fall
    // back to this same screen). Disable it in that dead-end case.
    final isStore =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    final canUpgrade = isStore || hasPortalUrl;
    // Decide button label: free → "Upgrade Plan"; paid → "Change Plan";
    // trial → "Upgrade Plan" so the user knows they're paying.
    final labelKey = session.isPaidPlanSlug && !session.isTrial
        ? 'change_plan'
        : 'upgrade_plan';

    return FormSection(
      title: context.tr('change_plan'),
      children: [
        if (session.hasIapPlan)
          // Plan was purchased via in-app purchase — it can only be managed in
          // the store's subscription settings, not here. Show guidance and no
          // action button (mirrors admin-portal's `isProPlan && hasIapPlan`
          // branch). Showing this unconditionally would tell every web/desktop
          // and non-IAP user to "use their phone", which is wrong.
          Text(
            context.tr('use_mobile_to_manage_plan'),
            style: TextStyle(color: tokens.ink2),
          )
        else ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: InSpacing.md(context),
              runSpacing: InSpacing.sm,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 44),
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(context.tr(labelKey)),
                  // Store IAP on iOS/Android; hosted portal on web/desktop.
                  // Disabled only on the web/desktop dead-end where no portal
                  // URL is available yet (transient pre-refresh state).
                  onPressed: canUpgrade ? () => launchUpgrade(context) : null,
                ),
              ],
            ),
          ),
          if (!canUpgrade)
            Padding(
              padding: EdgeInsets.only(top: InSpacing.sm),
              child: Text(
                context.tr('error_refresh_page'),
                style: TextStyle(color: tokens.ink3),
              ),
            ),
        ],
      ],
    );
  }
}
