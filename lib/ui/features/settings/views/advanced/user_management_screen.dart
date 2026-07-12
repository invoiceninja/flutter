import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/plan_gate_banner.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';
import 'package:admin/domain/entity_state.dart';

/// Settings → User Management.
///
/// Lists every company user except the owner and the currently-authenticated
/// user (the latter manages themselves via `/settings/user_details`). Renders
/// inside [SettingsFormShell] so the layout matches the rest of the settings
/// area; pagination caps at 5 pages (≈ 250 users — beyond that, a future
/// scroll-edge fetch can extend the cap).
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _showArchived = false;
  bool _hasKickedFetch = false;
  final Set<String> _selected = <String>{};

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  void _clearSelection() => setState(_selected.clear);

  Future<void> _runBulk(
    String successKey,
    Future<void> Function(String id) op, {
    bool destructive = false,
  }) async {
    if (_selected.isEmpty) return;
    final ids = _selected.toList(growable: false);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final tr = context.tr;
    if (destructive) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('delete_user')),
          content: Text(ctx.tr('are_you_sure')),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.tr('cancel')),
            ),
            PrimaryDialogAction(
              label: ctx.tr('delete'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    var failed = 0;
    for (final id in ids) {
      try {
        await op(id);
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _clearSelection();
    if (failed == 0) {
      Notify.success(context, tr(successKey), messenger: messenger);
    } else {
      Notify.error(context, tr('error_title'), messenger: messenger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final companyId = session?.currentCompanyId;
    final authUserId = session?.userId ?? '';
    final hasAccess = session?.hasEnterpriseAccess ?? false;

    if (companyId == null || companyId.isEmpty) {
      return SettingsScreenScaffold(
        titleKey: 'user_management',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasKickedFetch) {
      _hasKickedFetch = true;
      // Background fetch — load up to the watch cap (5 pages × 50 = 250)
      // so a 50–250-user company sees the whole roster on first open. The
      // loop short-circuits as soon as the server returns a partial page.
      // Errors surface in the global sync log; the watch stream handles
      // empty-state in the UI.
      Future.microtask(() async {
        for (var page = 1; page <= 5; page++) {
          final hasMore = await services.user.ensurePageLoaded(
            companyId: companyId,
            page: page,
            authUserId: authUserId,
            // Load every lifecycle state so the "Show archived" toggle can
            // surface server-archived users from Drift (an all-states set
            // sends no `status` filter; the server returns withTrashed()).
            // Mirrors UserRepository.refreshAll + SettingsEntityListScaffold.
            states: EntityState.values.toSet(),
            ignoreCursor: page == 1,
          );
          if (!hasMore) break;
        }
      });
    }

    final states = _showArchived
        ? const <EntityState>{EntityState.active, EntityState.archived}
        : const <EntityState>{EntityState.active};

    return SettingsScreenScaffold(
      titleKey: 'user_management',
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextButton.icon(
            icon: Icon(
              _showArchived
                  ? Icons.visibility_off_outlined
                  : Icons.archive_outlined,
              size: 18,
            ),
            label: Text(
              context.tr(_showArchived ? 'show_active' : 'show_archived'),
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
        ),
      ],
      body: Column(
        children: [
          const PlanGateBanner(
            style: PlanGateStyle.stripe,
            level: PlanGateLevel.enterprise,
          ),
          if (_selected.isNotEmpty)
            _BulkBar(
              count: _selected.length,
              enabled: hasAccess,
              onClear: _clearSelection,
              onArchive: () => _runBulk(
                'archived_users',
                (id) => services.user.archive(companyId: companyId, id: id),
              ),
              onRestore: () => _runBulk(
                'restored_users',
                (id) => services.user.restore(companyId: companyId, id: id),
              ),
              onDelete: () => _runBulk(
                'deleted_users',
                (id) => services.user.delete(companyId: companyId, id: id),
                destructive: true,
              ),
            ),
          Expanded(
            child: StreamBuilder<List<User>>(
              stream: services.user.watchPage(
                companyId: companyId,
                loadedPages: 5,
                states: states,
                excludeAuthUserId: authUserId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    snapshot.data == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                final all = snapshot.data ?? const <User>[];
                final active = all
                    .where((u) => u.archivedAt == 0 && !u.isDeleted)
                    .toList(growable: false);
                final archived = all
                    .where((u) => u.archivedAt > 0 && !u.isDeleted)
                    .toList(growable: false);

                if (active.isEmpty && archived.isEmpty) {
                  return EmptyState(
                    icon: Icons.supervised_user_circle_outlined,
                    title: context.tr('no_users'),
                    subtitle: context.tr('no_users_found_invite'),
                    action: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 44),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(context.tr('new_user')),
                      onPressed: hasAccess
                          ? () => context.go('/settings/users/new')
                          : null,
                    ),
                  );
                }

                return SettingsFormShell(
                  sections: [
                    FormSection(
                      title: context.tr('user_management'),
                      spacing: 0,
                      children: [
                        if (active.isNotEmpty)
                          for (final user in active)
                            _UserRow(
                              user: user,
                              selected: _selected.contains(user.id),
                              selectionActive: _selected.isNotEmpty,
                              onToggle: () => _toggle(user.id),
                            ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: Text(context.tr('new_user')),
                          enabled: hasAccess,
                          onTap: hasAccess
                              ? () => context.go('/settings/users/new')
                              : null,
                        ),
                      ],
                    ),
                    if (_showArchived && archived.isNotEmpty)
                      FormSection(
                        title: context.tr('archived'),
                        spacing: 0,
                        children: [
                          for (final user in archived)
                            _UserRow(
                              user: user,
                              isArchived: true,
                              selected: _selected.contains(user.id),
                              selectionActive: _selected.isNotEmpty,
                              onToggle: () => _toggle(user.id),
                            ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({
    required this.count,
    required this.enabled,
    required this.onClear,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
  });

  final int count;
  final bool enabled;
  final VoidCallback onClear;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Material(
      color: tokens.accentSoft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Three labeled buttons + count overflow a narrow phone, so drop
            // to icon-only (tooltip-labeled) below ~420 px.
            final compact = constraints.maxWidth < 420;

            Widget action({
              required IconData icon,
              required String labelKey,
              required VoidCallback onPressed,
              Color? color,
            }) {
              final label = context.tr(labelKey);
              final fg = enabled ? color : null;
              if (compact) {
                return IconButton(
                  icon: Icon(icon, size: 20, color: fg),
                  tooltip: label,
                  onPressed: enabled ? onPressed : null,
                );
              }
              return TextButton.icon(
                icon: Icon(icon, size: 18, color: fg),
                label: Text(label, style: TextStyle(color: fg)),
                onPressed: enabled ? onPressed : null,
              );
            }

            return Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: context.tr('cancel'),
                  onPressed: onClear,
                ),
                Expanded(
                  child: Text(
                    context.tr('count_selected').replaceAll(':count', '$count'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.accentInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                action(
                  icon: Icons.archive_outlined,
                  labelKey: 'archive',
                  onPressed: onArchive,
                ),
                action(
                  icon: Icons.unarchive_outlined,
                  labelKey: 'restore',
                  onPressed: onRestore,
                ),
                action(
                  icon: Icons.delete_outline,
                  labelKey: 'delete',
                  onPressed: onDelete,
                  color: tokens.overdue,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    this.isArchived = false,
    this.selected = false,
    this.selectionActive = false,
    this.onToggle,
  });

  final User user;
  final bool isArchived;
  final bool selected;
  final bool selectionActive;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final roleKey = user.companyUser.isOwner
        ? 'owner'
        : user.companyUser.isAdmin
        ? 'administrator'
        : 'user';
    final subtitle = user.email.isNotEmpty ? user.email : user.phone;
    final badges = <Widget>[
      _Badge(labelKey: roleKey),
      if (user.isPending)
        _Badge(labelKey: 'pending_invite', tone: _BadgeTone.warning),
      if (isArchived) _Badge(labelKey: 'archived', tone: _BadgeTone.muted),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Below ~480 px the role + pending badges in `trailing` crush the name
        // into ellipsis, so move them onto a second line under the subtitle and
        // leave only the chevron in `trailing`. Wide layout keeps badges inline.
        final narrow = constraints.maxWidth < 480;
        final chevron = !selectionActive
            ? const Icon(Icons.chevron_right, size: 18)
            : null;
        final trailing = narrow
            ? chevron
            : Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [...badges, if (chevron != null) chevron],
              );

        return ListTile(
          key: ValueKey(user.id),
          selected: selected,
          selectedTileColor: tokens.accentSoft,
          leading: selectionActive
              ? Checkbox(
                  value: selected,
                  onChanged: onToggle == null ? null : (_) => onToggle!(),
                )
              : CircleAvatar(
                  backgroundColor: tokens.surfaceAlt,
                  foregroundColor: tokens.ink2,
                  child: Text(
                    _initialsOf(user),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
          title: Text(
            user.displayName.isNotEmpty ? user.displayName : user.email,
            style: theme.textTheme.bodyLarge,
          ),
          subtitle: (subtitle.isNotEmpty || narrow)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    if (narrow)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: badges,
                        ),
                      ),
                  ],
                )
              : null,
          trailing: trailing,
          onLongPress: onToggle,
          onTap: selectionActive
              ? onToggle
              : () => context.go('/settings/users/${user.id}'),
        );
      },
    );
  }

  static String _initialsOf(User u) {
    final first = u.firstName.isNotEmpty ? u.firstName[0] : '';
    final last = u.lastName.isNotEmpty ? u.lastName[0] : '';
    final initials = (first + last).toUpperCase();
    if (initials.isNotEmpty) return initials;
    return u.email.isNotEmpty ? u.email[0].toUpperCase() : '?';
  }
}

enum _BadgeTone { neutral, warning, muted }

class _Badge extends StatelessWidget {
  const _Badge({required this.labelKey, this.tone = _BadgeTone.neutral});

  final String labelKey;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final (bg, fg) = switch (tone) {
      _BadgeTone.warning => (tokens.overdueSoft, tokens.overdue),
      _BadgeTone.muted => (tokens.surfaceAlt, tokens.ink3),
      _BadgeTone.neutral => (tokens.accentSoft, tokens.accentInk),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Text(
        context.tr(labelKey),
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
