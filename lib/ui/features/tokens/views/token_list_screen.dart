import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/token.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_list_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

const kTokensListSearchKeys = <String>['api_tokens', 'token', 'new_token'];

/// `/settings/account_management/integrations/api_tokens` — list every API token. Tap a row
/// to rename; tap "+ New Token" to create. System tokens (`is_system`)
/// render as locked rows that can't be edited or deleted.
///
/// The one-time raw bearer secret minted on create is surfaced app-wide by
/// the shell `SyncEventListener` (which drains `services.tokens.newSecrets`),
/// so it shows even if the create finishes while the user is on another
/// screen — there is no per-screen subscription here.
class TokenListScreen extends StatelessWidget {
  const TokenListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    // API Tokens is a Pro / self-hosted feature (parity with React + the old
    // app). Gate at the destination — mirrors quickbooks_screen — so the
    // Integrations tile stays visible (no orphaned section title) while free
    // hosted users hit the upgrade banner here. Trial-aware via hasProAccess.
    final session = services.auth.session.value;
    final allowed =
        session != null && (session.isSelfHosted || session.hasProAccess);
    if (!allowed) {
      return SettingsScreenScaffold(
        titleKey: 'api_tokens',
        body: const SingleChildScrollView(
          child: PlanGateBanner(style: PlanGateStyle.inset),
        ),
      );
    }
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    final repo = services.tokens;

    return SettingsEntityListScaffold<Token>(
      titleKey: 'api_tokens',
      sectionTitleKey: 'api_tokens',
      newRoute: '/settings/account_management/integrations/api_tokens/new',
      newLabelKey: 'new_token',
      emptyIcon: Icons.key_outlined,
      emptyTitleKey: 'no_api_tokens',
      emptyHintKey: 'no_api_tokens_hint',
      supportsArchive: true,
      refreshAll: () async {
        if (companyId.isEmpty) return;
        await repo.refreshAll(companyId: companyId);
      },
      stream: ({required includeArchived}) => repo
          .watchPage(
            companyId: companyId,
            loadedPages: 4,
            states: includeArchived
                ? const {EntityState.active, EntityState.archived}
                : const {EntityState.active},
          )
          .map(
            (list) => list.where((t) => !t.isSystem).toList(growable: false),
          ),
      isArchivedOf: (t) => t.archivedAt != null,
      isDeletedOf: (t) => t.isDeleted,
      rowBuilder: (t) => _TokenRow(key: ValueKey(t.id), token: t),
      archivedRowBuilder: (t) =>
          _TokenRow.archived(key: ValueKey(t.id), token: t),
    );
  }
}

class _TokenRow extends StatelessWidget {
  const _TokenRow({required this.token, super.key}) : _isArchived = false;

  const _TokenRow.archived({required this.token, super.key})
    : _isArchived = true;

  final Token token;
  final bool _isArchived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final displayName = token.name.trim().isEmpty
        ? context.tr('untitled')
        : token.name;
    final subtitleParts = <String>[
      token.tokenHint,
      if (token.isSystem) context.tr('system'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: Icon(
            token.isSystem ? Icons.lock_outline : Icons.key_outlined,
            color: tokens.ink2,
          ),
          title: Text(displayName),
          subtitle: Text(
            subtitleParts.join(' · '),
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
              : token.isSystem
              ? Icon(Icons.lock_outline, color: tokens.ink3)
              : const Icon(Icons.chevron_right),
          onTap: token.isSystem
              ? null
              : () => context.go(
                  '/settings/account_management/integrations/api_tokens/${token.id}',
                ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
