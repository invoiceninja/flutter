import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/group_setting.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/unsynced_pill.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_entity_list_scaffold.dart';

/// Search keys exported for the settings sidebar search. Colocated with the
/// screen so adding / renaming a field updates both ends in one place.
const kGroupSettingsSearchKeys = <String>['groups', 'name'];

/// `/settings/group_settings` — list every group with a leading "New group"
/// affordance. Tapping a row opens the edit screen. A "Show archived" toggle
/// surfaces archived groups so they stay restorable (the edit overflow can
/// archive them).
class GroupSettingsScreen extends StatelessWidget {
  const GroupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final companyId = session?.currentCompanyId ?? '';
    // Trial-aware (parity with the other Pro gates) — a trialing hosted
    // user must keep Group Settings access.
    final hasAccess = session?.hasProAccess ?? false;
    final repo = services.groupSettings;

    return SettingsEntityListScaffold<GroupSetting>(
      titleKey: 'group_settings',
      sectionTitleKey: 'groups',
      newRoute: '/settings/group_settings/new',
      newLabelKey: 'new_group',
      emptyIcon: Icons.group_work_outlined,
      emptyTitleKey: 'no_groups_yet',
      emptyHintKey: 'no_groups_yet_subtitle',
      refreshAll: () async {
        if (companyId.isEmpty) return;
        await repo.refreshAll(companyId: companyId);
      },
      supportsArchive: true,
      streamKey: companyId,
      stream: () => repo.watchAllIncludingArchived(companyId: companyId),
      isArchivedOf: (g) => g.archivedAt != null,
      isDeletedOf: (g) => g.isDeleted,
      rowBuilder: (g) => _GroupRow(key: ValueKey(g.id), group: g),
      archivedRowBuilder: (g) =>
          _GroupRow.archived(key: ValueKey(g.id), group: g),
      banner: const PlanGateBanner(style: PlanGateStyle.stripe),
      canCreate: hasAccess,
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, super.key}) : _isArchived = false;

  /// Variant rendered inside the "Archived" section — swaps the trailing
  /// chevron for a muted "Archived" pill. Tapping still opens the edit
  /// screen, where the overflow menu offers Restore.
  const _GroupRow.archived({required this.group, super.key})
    : _isArchived = true;

  final GroupSetting group;
  final bool _isArchived;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(group.name.isEmpty ? context.tr('untitled') : group.name),
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
              // An unsynced row takes the state slot rather than sitting
              // beside the chevron — see UnsyncedPill on the width budget.
              : group.isDirty
              ? const UnsyncedPill()
              : const Icon(Icons.chevron_right),
          onTap: () => context.go('/settings/group_settings/${group.id}'),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
