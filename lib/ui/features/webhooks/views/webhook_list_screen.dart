import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/webhook.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_list_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

/// `/settings/account_management/integrations/api_webhooks` — list every webhook. Tap a row to
/// edit; tap "+ New Webhook" to create.
class WebhookListScreen extends StatelessWidget {
  const WebhookListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    // Webhooks require the API feature, which the server grants only to
    // self-hosted or paid plans (Account::FEATURE_API). Gate at the
    // destination — mirrors TokenListScreen — so the Integrations tile stays
    // visible while a free hosted user hits the upgrade banner instead of a
    // 403 dead-end on save. Trial-aware via hasProAccess.
    final session = services.auth.session.value;
    final allowed =
        session != null && (session.isSelfHosted || session.hasProAccess);
    if (!allowed) {
      return SettingsScreenScaffold(
        titleKey: 'api_webhooks',
        body: const SingleChildScrollView(
          child: PlanGateBanner(style: PlanGateStyle.inset),
        ),
      );
    }
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.webhooks;

    return SettingsEntityListScaffold<Webhook>(
      titleKey: 'api_webhooks',
      sectionTitleKey: 'api_webhooks',
      newRoute: '/settings/account_management/integrations/api_webhooks/new',
      newLabelKey: 'new_webhook',
      emptyIcon: Icons.webhook_outlined,
      emptyTitleKey: 'no_webhooks',
      emptyHintKey: 'no_webhooks_hint',
      supportsArchive: true,
      refreshAll: () async {
        if (companyId.isEmpty) return;
        await repo.refreshAll(companyId: companyId);
      },
      stream: ({required includeArchived}) => repo.watchPage(
        companyId: companyId,
        loadedPages: 4,
        states: includeArchived
            ? const {EntityState.active, EntityState.archived}
            : const {EntityState.active},
      ),
      isArchivedOf: (w) => w.archivedAt != null,
      isDeletedOf: (w) => w.isDeleted,
      rowBuilder: (w) => _WebhookRow(key: ValueKey(w.id), webhook: w),
      archivedRowBuilder: (w) =>
          _WebhookRow.archived(key: ValueKey(w.id), webhook: w),
    );
  }
}

class _WebhookRow extends StatelessWidget {
  const _WebhookRow({required this.webhook, super.key}) : _isArchived = false;

  const _WebhookRow.archived({required this.webhook, super.key})
    : _isArchived = true;

  final Webhook webhook;
  final bool _isArchived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final displayName = webhook.targetUrl.trim().isEmpty
        ? context.tr('untitled')
        : webhook.targetUrl;
    final eventName = kWebhookEventNames[webhook.eventId];
    final subtitle = <String>[
      webhook.restMethod.toUpperCase(),
      if (eventName != null) context.tr(eventName),
    ].join(' · ');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(Icons.webhook_outlined, color: tokens.ink2),
          title: Text(displayName, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            subtitle,
            style: TextStyle(color: tokens.ink2, fontSize: 12),
          ),
          trailing: _isArchived
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.draftSoft,
                    borderRadius: BorderRadius.circular(InRadii.r1),
                  ),
                  child: Text(
                    context.tr('archived'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.draft,
                    ),
                  ),
                )
              : const Icon(Icons.chevron_right),
          onTap: () => context.go(
            '/settings/account_management/integrations/api_webhooks/${webhook.id}',
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
