import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/features/settings/views/advanced/client_portal/widgets/portal_url_display.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

const String _kReferralBaseUrl = 'https://app.invoicing.co/#/register?rc=';
const String _kReferralLearnMoreUrl = 'https://invoiceninja.com/referrals/';

/// Canonical plan tiers shown in the referral stats strip, in display order.
/// We always render these three (defaulting to 0) so a brand-new user with no
/// referrals still sees the categories; any extra tier the server sends is
/// appended after them. Iterating `referralMeta.entries` directly would render
/// whatever order the payload arrived in (alphabetical in practice).
const List<String> _kReferralTierOrder = ['free', 'pro', 'enterprise'];

/// Account Management → Referral Program. Hosted-only display screen: shows the
/// referral value proposition, the user's referral URL (copy / open via the
/// shared [PortalUrlDisplay]) and per-plan referral counts pulled from
/// `AuthSession.referralCode` / `referralMeta`.
///
/// The shell hides this tab outright on self-hosted sessions (issue #27), so
/// the [EmptyState] below is a fallback, not the normal self-hosted path — it
/// covers the shell's fail-open case, where a session that hasn't loaded yet
/// keeps the tab visible rather than risk hiding it from a hosted user.
class AccountManagementReferralProgramScreen extends StatelessWidget {
  const AccountManagementReferralProgramScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Services>().auth.session.value;
    if (!(session?.isHosted ?? false)) {
      return EmptyState(
        icon: Icons.public,
        title: context.tr('referral_program'),
        subtitle: context.tr('referral_program_hosted_only'),
        action: FilledButton.tonal(
          // Centered single-action button must constrain its own width or it
          // renders edge-to-edge (Size.fromHeight default = infinite width).
          style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
          onPressed: () => _openUrl(context, _kReferralLearnMoreUrl),
          child: Text(context.tr('learn_more')),
        ),
      );
    }
    return _ReferralBody(
      code: session!.referralCode,
      meta: session.referralMeta,
    );
  }
}

class _ReferralBody extends StatelessWidget {
  const _ReferralBody({required this.code, required this.meta});

  final String code;
  final Map<String, int> meta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    final url = '$_kReferralBaseUrl$code';
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('referral_program'),
          children: [
            Text(
              context.tr('referral_code_help'),
              style: theme.textTheme.bodyMedium?.copyWith(color: tokens.ink2),
            ),
            PortalUrlDisplay(label: context.tr('referral_code'), url: url),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
                onPressed: () => _openUrl(context, _kReferralLearnMoreUrl),
                child: Text(context.tr('learn_more')),
              ),
            ),
          ],
        ),
        FormSection(
          title: context.tr('referral_signups'),
          spacing: 0,
          children: [_ReferralStatsStrip(meta: meta)],
        ),
      ],
    );
  }
}

/// Per-plan referral counts. On wide layouts the tiles sit side-by-side as an
/// equal-width row; on narrow layouts they stack. Order is fixed
/// ([_kReferralTierOrder]) with the three core tiers always shown (default 0)
/// and any unknown server tier appended.
class _ReferralStatsStrip extends StatelessWidget {
  const _ReferralStatsStrip({required this.meta});

  final Map<String, int> meta;

  @override
  Widget build(BuildContext context) {
    final tiles = _orderedTiles(meta);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!Breakpoints.isWide(constraints)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) SizedBox(height: InSpacing.md(context)),
                _ReferralStatTile(planKey: tiles[i].key, count: tiles[i].count),
              ],
            ],
          );
        }
        return Row(
          // Top-align rather than stretch: the strip lives in a vertically
          // unbounded scroll, so `stretch` would force an infinite-height
          // constraint. Tiles share uniform content, so heights match anyway.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) SizedBox(width: InSpacing.md(context)),
              Expanded(
                child: _ReferralStatTile(
                  planKey: tiles[i].key,
                  count: tiles[i].count,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  static List<({String key, int count})> _orderedTiles(Map<String, int> meta) {
    final out = <({String key, int count})>[];
    for (final tier in _kReferralTierOrder) {
      out.add((key: tier, count: meta[tier] ?? 0));
    }
    for (final entry in meta.entries) {
      if (!_kReferralTierOrder.contains(entry.key)) {
        out.add((key: entry.key, count: entry.value));
      }
    }
    return out;
  }
}

/// Flat stat tile (no shadow) — it lives inside a [FormSection] card, so a
/// raised card here would read as a card-in-card. Counts use the sans face,
/// not `moneyTextStyle`, since they're integers, not currency.
class _ReferralStatTile extends StatelessWidget {
  const _ReferralStatTile({required this.planKey, required this.count});

  final String planKey;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.inTheme;
    return Container(
      padding: EdgeInsets.all(InSpacing.lg(context)),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r2),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.tr(planKey),
            style: theme.textTheme.labelLarge?.copyWith(color: tokens.ink3),
          ),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens [url] in an external browser, surfacing a toast on failure. Shared by
/// the self-hosted empty-state action and the hosted "Learn more" button.
Future<void> _openUrl(BuildContext context, String url) async {
  await openExternalUrl(context, url);
}
