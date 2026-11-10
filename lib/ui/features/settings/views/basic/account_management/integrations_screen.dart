import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/domain/companion_apps.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/utils/external_url.dart';
import 'package:admin/ui/features/mobile_promo/mobile_app_promo_dialog.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/mobile_app_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

/// Searchable labels on this tab, spread into
/// `kSettingsSearchCatalog['account_management']`'s `integrations` tab. The
/// companion-app keys are gated there on the same predicates as the card.
const kAccountManagementIntegrationsSearchKeys = <String>[
  'api_docs',
  'companion_apps_section',
  'wordpress_plugin',
  'chrome_extension',
];

/// External URLs the Integrations tab opens. Matched against admin-portal's
/// `kApiDocsUrl` / `kZapierUrl` so the docs target stays consistent across
/// clients.
const String _kApiDocsUrl =
    'https://invoiceninja.github.io/docs/api-reference/invoice-ninja-api-reference/';
const String _kZapierUrl = 'https://zapier.com/apps/invoice-ninja/integrations';

/// Account Management → Integrations. A pure hub of link tiles — API Tokens /
/// API Webhooks / Zapier / Analytics / QuickBooks — with the API Docs link
/// beneath the list rather than in it. Mirrors React's Integrations hub; the
/// Google Analytics / Matomo editor lives on its own page at
/// `/settings/account_management/integrations/analytics` (reached via the
/// Analytics tile), so there's a single source of truth for those fields.
///
/// Below them, "More from Invoice Ninja": the WordPress plugin, the Chrome
/// extension and the phone app, each where this session can use it
/// (docs/companion-apps.md). The card is left out entirely when none is.
class AccountManagementIntegrationsScreen extends StatelessWidget {
  const AccountManagementIntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.read<Services>().auth.session.value;
    // The same tiles as the Integrations card above, so the two cards share
    // one icon column and one trailing column and read as settings, not as a
    // promotion; the line under each title says what the app does.
    final companionRows = <Widget>[
      if (wordPressPluginOffered(session))
        _IntegrationTile(
          icon: Icons.storefront_outlined,
          labelKey: 'wordpress_plugin',
          subtitleKey: 'wordpress_plugin_body',
          external: true,
          onTap: () => _openExternal(context, kWordPressPluginUrl),
        ),
      if (chromeExtensionOffered(session))
        _IntegrationTile(
          icon: Icons.extension_outlined,
          labelKey: 'chrome_extension',
          subtitleKey: 'chrome_extension_body',
          external: true,
          onTap: () => _openExternal(context, kChromeExtensionUrl),
        ),
      if (mobileAppSectionShown(session))
        _IntegrationTile(
          icon: Icons.smartphone_outlined,
          labelKey: 'mobile_app_promo_section',
          subtitleKey: 'mobile_app_hub_body',
          onTap: () =>
              unawaited(showMobileAppPromoDialog(context, isManual: true)),
        ),
    ];
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('integrations'),
          spacing: 0,
          children: [
            // Pro / self-hosted gates live at each destination (TokenListScreen
            // / WebhookListScreen → PlanGateBanner), so the tiles stay visible
            // for everyone — matching the sibling QuickBooks tile.
            _IntegrationTile(
              icon: Icons.lock_outline,
              labelKey: 'api_tokens',
              onTap: () => context.go(
                '/settings/account_management/integrations/api_tokens',
              ),
            ),
            _IntegrationTile(
              icon: Icons.webhook_outlined,
              labelKey: 'api_webhooks',
              onTap: () => context.go(
                '/settings/account_management/integrations/api_webhooks',
              ),
            ),
            _IntegrationTile(
              icon: Icons.electrical_services_outlined,
              label: 'Zapier',
              external: true,
              onTap: () => _openExternal(context, _kZapierUrl),
            ),
            _IntegrationTile(
              icon: Icons.analytics_outlined,
              labelKey: 'analytics',
              onTap: () => context.go(
                '/settings/account_management/integrations/analytics',
              ),
            ),
            _IntegrationTile(
              icon: Icons.account_balance_outlined,
              labelKey: 'quickbooks',
              onTap: () => context.go(
                '/settings/account_management/integrations/quickbooks',
              ),
            ),
          ],
        ),
        // "Further reading" sits beneath the list of actionable integrations,
        // matching the View Docs button on Templates & Reminders
        // (invoiceninja/flutter#76).
        // Its own bottom gap, as a FormSection has, so a card after it
        // doesn't sit flush against it.
        Padding(
          padding: EdgeInsets.only(bottom: InSpacing.lg(context)),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton.icon(
              onPressed: () => _openExternal(context, _kApiDocsUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text(context.tr('api_docs')),
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            ),
          ),
        ),
        // A hidden card still costs a gap in the shell, so it is left out of
        // the list rather than drawn empty.
        if (companionRows.isNotEmpty)
          FormSection(
            title: context.tr('companion_apps_section'),
            spacing: 0,
            children: companionRows,
          ),
      ],
    );
  }
}

class _IntegrationTile extends StatelessWidget {
  const _IntegrationTile({
    required this.icon,
    required this.onTap,
    this.labelKey,
    this.label,
    this.subtitleKey,
    this.external = false,
  }) : assert(labelKey != null || label != null);

  final IconData icon;
  final VoidCallback onTap;
  final String? labelKey;
  final String? label;

  /// A line under the title, for a tile whose name alone doesn't say what
  /// it is (the "More from Invoice Ninja" apps).
  final String? subtitleKey;
  final bool external;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final subtitle = subtitleKey;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: tokens.ink2),
      title: Text(label ?? context.tr(labelKey!)),
      subtitle: subtitle == null
          ? null
          : Text(
              context.tr(subtitle),
              style: TextStyle(fontSize: 13, height: 1.4, color: tokens.ink2),
            ),
      trailing: external
          ? Icon(Icons.open_in_new, size: 18, color: tokens.ink3)
          : Icon(Icons.chevron_right, color: tokens.ink3),
      onTap: onTap,
    );
  }
}

Future<void> _openExternal(BuildContext context, String url) async {
  await openExternalUrl(context, url);
}
