import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/upgrade/upgrade_launcher.dart';
import 'package:admin/domain/upgrade/white_label.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/form_save_scope.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Search keys for the Plan tab, spread into `kSettingsSearchCatalog` so this
/// list is the single source (it used to be duplicated there by hand, and had
/// already drifted — that is how `purchase_license` outlived the button it
/// named).
///
/// Deliberately NOT registered in `search_catalog_consistency_test`: that
/// harness is a text scan for `context.tr('<key>')` literals, and most labels
/// here are looked up through a computed key (`planHeadlineKey`, the
/// upgrade/change `labelKey`), which it cannot see and has no allowlist for.
/// `plan_headline_test` asserts the computed side instead.
const kAccountManagementPlanSearchKeys = <String>[
  'plan',
  'free',
  'pro',
  'enterprise',
  'free_trial',
  'change_plan',
  'expires_on',
  // The rendered string is `days_left` (":days days left") with the count
  // substituted; search shows a field key raw, so it indexes the plain label.
  'days_left_label',
  // Self-hosted White Label card. `white_label_button` ("Purchase White
  // Label") is the string on the button — NOT `purchase_license`, which this
  // screen stopped rendering when the card moved off the Overview tab.
  'white_label',
  'white_label_button',
  'renew_license',
  'apply_license',
  'white_label_expired',
  'license',
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
/// license expiry when one is applied, and — this is what makes the tab worth
/// visiting on a self-hosted install (issue #41) — the White Label card that
/// owns Purchase / Renew / Apply License. That card used to sit two tabs away
/// on Overview, leaving Plan with a single line of text and nothing to do.
/// React puts it here too (`Plan.tsx:70`).
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
            // Self-hosted only, and mutually exclusive with the hosted card
            // below — `showWhiteLabelCard` owns that guard, because
            // `isWhiteLabeled` alone is true on hosted too.
            if (showWhiteLabelCard(value))
              _SelfHostedLicenseCard(session: value),
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
    // expiry — the one actionable date self-hosted has (renew from the White
    // Label card below). An unlicensed self-host has no usable `plan_expires`
    // (see `AuthSession.planExpiresDate` for the sentinel dates). The
    // self-hosted branch deliberately skips the `isTrial` check above, or the
    // date would disappear during the exact fortnight it matters most.
    final showExpiry =
        session.planExpires.isNotEmpty &&
        (session.isHosted
            ? (!session.isTrial && session.plan.isNotEmpty)
            // Lapsed counts too: the card below says the license expired, and
            // "expired" without a date is the less useful half of that.
            : (session.isWhiteLabeled || session.isWhiteLabelLapsed));

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
        // Self-hosted: nothing more to render on this card — the White Label
        // section below owns Purchase/Renew/Apply License, and there's no
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

/// Self-hosted white-label license: buy one, renew a lapsed one, or redeem a
/// key. Moved here from Account Management → Overview (issue #41) so the Plan
/// tab isn't a dead end on self-hosted; React renders the same pair on its
/// Plan tab (`Licence.tsx` via `Plan.tsx:70`).
///
/// **No price is shown, deliberately.** The server exposes none, and every
/// Transifex string that describes the offer carries a placeholder we cannot
/// fill — `white_label_text` (`:price`), `white_label_custom_css`
/// (`:link`/`:price`), `license_expiring` (`:count`/`:link`),
/// `reseller_text` (`:email`). Rendering one leaks the raw token and
/// `no_unsubstituted_placeholders_test` fails the build; hardcoding a price
/// would go stale the moment billing changes it. The checkout page states the
/// price. `white_label_expired` is the one placeholder-free line, so it's the
/// only prose here.
class _SelfHostedLicenseCard extends StatefulWidget {
  const _SelfHostedLicenseCard({required this.session});

  final AuthSession session;

  @override
  State<_SelfHostedLicenseCard> createState() => _SelfHostedLicenseCardState();
}

class _SelfHostedLicenseCardState extends State<_SelfHostedLicenseCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final session = widget.session;
    // `isWhiteLabeled` is the server-authoritative signal; `isWhiteLabelLapsed`
    // reads the past `plan_expires` the transformer still sends after the slug
    // has been blanked, which is the only way to tell "renew" from "buy".
    final licensed = session.isWhiteLabeled;
    final lapsed = session.isWhiteLabelLapsed;

    return FormSection(
      title: context.tr('white_label'),
      children: [
        if (lapsed)
          Text(
            context.tr('white_label_expired'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: tokens.ink2),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: InSpacing.md(context),
            runSpacing: InSpacing.sm,
            children: [
              // A licensed install has nothing to buy — only a key to re-apply
              // once they've renewed upstream.
              if (!licensed)
                FilledButton.icon(
                  // Explicit minimumSize: the theme default is
                  // `Size.fromHeight(44)` (= infinite width), which stretches
                  // edge-to-edge inside a Wrap.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(160, 44),
                  ),
                  // The external-link glyph is the whole icon slot: a second
                  // decorative icon plus this label is wider than a phone once
                  // the string is translated (see the ellipsis note below).
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(
                    context.tr(lapsed ? 'renew_license' : 'white_label_button'),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: _busy
                      ? null
                      : () => unawaited(launchWhiteLabelPurchase(context)),
                ),
              OutlinedButton(
                // Stable identity: on the licensed transition the Wrap's
                // children go [Filled, Outlined] -> [Outlined], so without a
                // key index 0 changes runtimeType and this button is torn
                // down and rebuilt rather than moved.
                key: const ValueKey('apply_license'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 44),
                ),
                onPressed: _busy ? null : () => _onApply(context),
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        context.tr('apply_license'),
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onApply(BuildContext context) async {
    final licenseKey = await _promptLicenseKey(context);
    if (licenseKey == null || licenseKey.isEmpty) return;
    if (!context.mounted) return;
    final services = context.read<Services>();
    final successMsg = context.tr('bought_white_label');
    final errorMsg = context.tr('error_refresh_page');
    // Captured before the await, not read from `context` after it. This
    // awaits `refresh(fullSync: true)` (10-30 s on a large install), and a
    // `TabBarView` tab switch during that window disposes this State — with a
    // plain `if (!mounted) return` the user would be told *nothing* about a
    // license that did or didn't apply. The toast host is global and outlives
    // the context; both strings are `tr()`-derived, which the captured path
    // requires (it has no blank-message fallback).
    final toasts = Notify.capture(context);
    setState(() => _busy = true);
    try {
      await services.auth.applyLicense(licenseKey);
      toasts?.success(successMsg);
    } catch (e) {
      toasts?.error(errorMsg, detail: formatNotifyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Inline single-field input dialog. Returns the trimmed entered value, or
/// null when the user cancels. Kept private to this screen — if a second
/// place ever needs it, lift to `lib/ui/core/widgets/`.
Future<String?> _promptLicenseKey(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) {
      void submit() {
        final v = controller.text.trim();
        if (v.isEmpty) return;
        Navigator.of(ctx).pop(v);
      }

      return AlertDialog(
        title: Text(ctx.tr('apply_license')),
        content: SizedBox(
          width: 360,
          child: FormSaveScope(
            enabled: true,
            onSubmit: submit,
            child: TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                labelText: ctx.tr('license'),
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.tr('cancel')),
          ),
          PrimaryDialogAction(
            label: ctx.tr('submit'),
            autofocus: false,
            onPressed: submit,
          ),
        ],
      );
    },
  );
  controller.dispose();
  return result;
}
