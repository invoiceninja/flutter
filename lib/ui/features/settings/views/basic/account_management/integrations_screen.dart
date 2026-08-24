import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';

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
class AccountManagementIntegrationsScreen extends StatelessWidget {
  const AccountManagementIntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: () => _openExternal(context, _kApiDocsUrl),
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(context.tr('api_docs')),
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
          ),
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
    this.external = false,
  }) : assert(labelKey != null || label != null);

  final IconData icon;
  final VoidCallback onTap;
  final String? labelKey;
  final String? label;
  final bool external;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: tokens.ink2),
      title: Text(label ?? context.tr(labelKey!)),
      trailing: external
          ? Icon(Icons.open_in_new, size: 18, color: tokens.ink3)
          : Icon(Icons.chevron_right, color: tokens.ink3),
      onTap: onTap,
    );
  }
}

Future<void> _openExternal(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final loc = Localization.of(context);
  final errorMessage =
      loc?.lookup('failed_to_open_url') ?? 'failed_to_open_url';
  final uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }
  } catch (_) {
    /* fall through */
  }
  if (messenger == null) return;
  // ignore: use_build_context_synchronously
  Notify.error(messenger.context, errorMessage, messenger: messenger);
}
