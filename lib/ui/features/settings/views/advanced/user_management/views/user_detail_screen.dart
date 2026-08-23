import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/mdi_icons.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/dashboard/dashboard_activity.dart';
import 'package:admin/data/models/domain/user.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/custom_field_detail_rows.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/dashboard/helpers/activity_formatter.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

/// Read-only User detail screen. Reached from `/settings/users/:id`.
///
/// Action chips: edit, resend email, detach, archive/restore, delete, purge.
/// Owner-protection: every action no-ops with a toast when the target is the
/// owner or the currently-authenticated user.
class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final session = services.auth.session.value;
    final companyId = session?.currentCompanyId;
    final authUserId = session?.userId ?? '';

    if (companyId == null || companyId.isEmpty) {
      return SettingsScreenScaffold(
        titleKey: 'user',
        leading: const BackButton(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return SettingsScreenScaffold(
      titleKey: 'user',
      leading: const BackButton(),
      body: StreamBuilder<User?>(
        stream: services.user.watch(companyId: companyId, id: widget.id),
        builder: (context, snapshot) {
          final user = snapshot.data;
          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final isSelf = user.id == authUserId;
          final isOwner = user.companyUser.isOwner;
          final canModify = !isOwner && !isSelf;
          return SettingsFormShell(
            sections: [
              if (user.isPending)
                FormSection(
                  title: context.tr('invitation'),
                  children: [
                    _Banner(
                      icon: Icons.email_outlined,
                      message: context.tr('email_sent_to_confirm_email'),
                    ),
                  ],
                ),
              FormSection(
                title: context.tr('details'),
                children: [
                  _SummaryRow(
                    labelKey: 'name',
                    value: user.displayName.isNotEmpty
                        ? user.displayName
                        : context.tr('blank'),
                  ),
                  _SummaryRow(labelKey: 'email', value: user.email),
                  if (user.phone.isNotEmpty)
                    _SummaryRow(labelKey: 'phone', value: user.phone),
                  _SummaryRow(
                    labelKey: 'role',
                    value: context.tr(
                      isOwner
                          ? 'owner'
                          : user.companyUser.isAdmin
                          ? 'administrator'
                          : 'user',
                    ),
                  ),
                  if (user.companyUser.isLocked)
                    _SummaryRow(
                      labelKey: 'status',
                      value: context.tr('locked'),
                    ),
                  if (user.oauthProviderId.isNotEmpty)
                    _SummaryRow(
                      labelKey: 'sign_in_method',
                      value: user.oauthProviderId,
                    ),
                  if (user.googleTwoFactorEnabled)
                    _SummaryRow(
                      labelKey: 'two_factor_authentication',
                      value: context.tr('enabled'),
                    ),
                ],
              ),
              if (user.customValue1.isNotEmpty ||
                  user.customValue2.isNotEmpty ||
                  user.customValue3.isNotEmpty ||
                  user.customValue4.isNotEmpty)
                _UserCustomFieldsSection(user: user, companyId: companyId),
              FormSection(
                // "Recent", not "Activity": the feed is the actor's slice of a
                // bounded scan window (kUserActivityScanRows), so an empty list
                // means "nothing recent", not "nothing ever".
                title: context.tr('recent_activity'),
                children: [
                  // Keyed so a user → user navigation that reuses this
                  // element re-runs initState and refetches, instead of
                  // showing the previous user's feed.
                  _UserActivitySection(
                    key: ValueKey(user.id),
                    userId: user.id,
                    companyId: companyId,
                  ),
                ],
              ),
              FormSection(
                title: context.tr('actions'),
                children: [
                  ListTile(
                    leading: const Icon(MdiIcons.circleEditOutline),
                    title: Text(context.tr('edit_user')),
                    onTap: canModify
                        ? () => context.go('/settings/users/${user.id}/edit')
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.email_outlined),
                    title: Text(context.tr('resend_email')),
                    onTap: canModify
                        ? () => _resendEmail(services, companyId, user)
                        : null,
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_remove_outlined),
                    title: Text(context.tr('remove_user')),
                    onTap: canModify
                        ? () => _detach(services, companyId, user)
                        : null,
                  ),
                  if (!isOwner) ...[
                    if (user.archivedAt == 0 && !user.isDeleted)
                      ListTile(
                        leading: const Icon(Icons.archive_outlined),
                        title: Text(context.tr('archive')),
                        onTap: canModify
                            ? () => _archive(services, companyId, user)
                            : null,
                      ),
                    if (user.archivedAt > 0 || user.isDeleted)
                      ListTile(
                        leading: const Icon(Icons.unarchive_outlined),
                        title: Text(context.tr('restore')),
                        onTap: canModify
                            ? () => _restore(services, companyId, user)
                            : null,
                      ),
                    if (!user.isDeleted)
                      ListTile(
                        leading: const Icon(Icons.delete_outline),
                        title: Text(context.tr('delete')),
                        onTap: canModify
                            ? () => _delete(services, companyId, user)
                            : null,
                      ),
                    if (user.isDeleted || user.archivedAt > 0)
                      ListTile(
                        leading: const Icon(Icons.delete_forever_outlined),
                        title: Text(context.tr('purge')),
                        onTap: canModify
                            ? () => _purge(services, companyId, user)
                            : null,
                      ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _resendEmail(
    Services services,
    String companyId,
    User user,
  ) async {
    await services.user.resendEmail(companyId: companyId, userId: user.id);
    if (mounted) {
      Notify.success(
        context,
        // Param keys carry no leading colon — `lookup` prefixes one itself.
        context.tr('sent_invitation_email', {'email': user.email}),
      );
    }
  }

  Future<void> _detach(Services services, String companyId, User user) async {
    final confirmed = await _confirmAction(
      context: context,
      title: 'remove_user',
      body: 'confirm_detach_user_body',
      user: user,
    );
    if (!confirmed) return;
    await services.user.detachFromCompany(
      companyId: companyId,
      userId: user.id,
    );
    if (mounted) context.go('/settings/users');
  }

  Future<void> _archive(Services services, String companyId, User user) async {
    await services.user.archive(companyId: companyId, id: user.id);
    if (mounted) Notify.success(context, context.tr('archived_user'));
  }

  Future<void> _restore(Services services, String companyId, User user) async {
    await services.user.restore(companyId: companyId, id: user.id);
    if (mounted) Notify.success(context, context.tr('restored_user'));
  }

  Future<void> _delete(Services services, String companyId, User user) async {
    final confirmed = await _confirmAction(
      context: context,
      title: 'delete',
      body: 'confirm_delete_user_body',
      user: user,
    );
    if (!confirmed) return;
    await services.user.delete(companyId: companyId, id: user.id);
    if (mounted) context.go('/settings/users');
  }

  Future<void> _purge(Services services, String companyId, User user) async {
    final confirmed = await _confirmAction(
      context: context,
      title: 'purge',
      body: 'confirm_purge_user_body',
      user: user,
    );
    if (!confirmed) return;
    await services.user.purge(companyId: companyId, id: user.id);
    if (mounted) context.go('/settings/users');
  }

  Future<bool> _confirmAction({
    required BuildContext context,
    required String title,
    required String body,
    User? user,
  }) async {
    final services = context.read<Services>();
    final company = services.auth.session.value?.currentCompany;
    // Bare names, no leading `:` — `Localization.lookup` prepends the colon
    // itself, so `':user'` would search for `'::user'` and the dialogs would
    // render the raw `:user` / `:company` tokens.
    final params = <String, String>{
      'user': user?.displayName ?? '',
      'company': company?.displayName ?? company?.name ?? '',
    };
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr(title)),
        content: Text(ctx.tr(body, params)),
        actions: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size(64, 40)),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr('cancel')),
          ),
          const SizedBox(width: 8),
          PrimaryDialogAction(
            label: ctx.tr('continue'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Read-only actor-scoped activity feed for this user.
///
/// `ActivitiesApi.fetchUserActivities` does the actor scoping client-side —
/// the server has no `user_id` filter on `/activities` (invoiceninja/flutter#45)
/// — and returns rows carrying their own `user` label, so every row here is
/// genuinely this user's and names the real actor. Rendered through the shared
/// dashboard `ActivityFormatter`.
class _UserActivitySection extends StatefulWidget {
  const _UserActivitySection({
    super.key,
    required this.userId,
    required this.companyId,
  });

  final String userId;
  final String companyId;

  @override
  State<_UserActivitySection> createState() => _UserActivitySectionState();
}

class _UserActivitySectionState extends State<_UserActivitySection> {
  late Future<List<DashboardActivity>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<Services>().activities.fetchUserActivities(
      widget.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DashboardActivity>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              context.tr('an_error_occurred'),
              style: TextStyle(color: context.inTheme.ink3),
            ),
          );
        }
        final rows = snapshot.data ?? const <DashboardActivity>[];
        if (rows.isEmpty) {
          return EmptyState(
            icon: Icons.history_toggle_off_outlined,
            title: context.tr('no_records_found'),
          );
        }
        final formatter = ActivityFormatter(context);
        final dateFmt = context.read<Services>().formatterIfReady(
          widget.companyId,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final a in rows)
              _ActivityRow(
                render: formatter.format(a),
                timestamp: dateFmt?.date(
                  DateTime.fromMillisecondsSinceEpoch(
                    a.createdAt * 1000,
                    isUtc: true,
                  ).toIso8601String(),
                  showTime: true,
                  showSeconds: false,
                ),
                ip: (a.raw['ip'] ?? '').toString(),
              ),
          ],
        );
      },
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.render,
    required this.timestamp,
    required this.ip,
  });

  final ActivityRender render;

  /// Absolute, company-formatted timestamp for the audit lens. Null until the
  /// company `Formatter` is ready — fall back to the relative `render.meta`.
  final String? timestamp;
  final String ip;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final (bg, fg) = activityToneColors(tokens, render.tone);
    final when = timestamp ?? render.meta;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: InSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(InRadii.r2),
            ),
            child: Icon(render.icon, size: 16, color: fg),
          ),
          SizedBox(width: InSpacing.md(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(render.title, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  ip.isNotEmpty ? '$when · $ip' : when,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: tokens.ink3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.labelKey, required this.value})
    : _literalLabel = null;

  /// Variant for a label that is already resolved text (not a localization
  /// key) — used for configured custom-field labels.
  const _SummaryRow.literal({required String label, required this.value})
    : labelKey = '',
      _literalLabel = label;

  final String labelKey;
  final String? _literalLabel;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    final label = Text(
      _literalLabel ?? context.tr(labelKey),
      style: theme.textTheme.bodySmall?.copyWith(color: tokens.ink3),
    );
    final valueText = Text(value, style: theme.textTheme.bodyMedium);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6, horizontal: InSpacing.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Narrow phones: stack label above value so the fixed label column
          // doesn't crush the value. Wide: side-by-side label / value.
          if (constraints.maxWidth < 480) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [label, const SizedBox(height: 2), valueText],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 140, child: label),
              Expanded(child: valueText),
            ],
          );
        },
      ),
    );
  }
}

/// Read-only custom-field rows for this user, rendered in the settings-page
/// idiom (a [FormSection] of [_SummaryRow]s) rather than the entity-detail
/// card so it sits flush with the surrounding sections. Streams the company
/// for the configured `user1..4` labels/types; collapses when none apply.
class _UserCustomFieldsSection extends StatelessWidget {
  const _UserCustomFieldsSection({required this.user, required this.companyId});

  final User user;
  final String companyId;

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return StreamBuilder<Company?>(
      stream: services.company.watchCompany(companyId),
      builder: (context, snapshot) {
        final rows = customFieldDetailRows(
          company: snapshot.data,
          prefix: 'user',
          values: [
            user.customValue1,
            user.customValue2,
            user.customValue3,
            user.customValue4,
          ],
          formatter: services.formatterIfReady(companyId),
          yes: context.tr('yes'),
          no: context.tr('no'),
        );
        if (rows.isEmpty) return const SizedBox.shrink();
        return FormSection(
          title: context.tr('custom_fields'),
          children: [
            for (final r in rows)
              _SummaryRow.literal(label: r.label, value: r.value),
          ],
        );
      },
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.overdueSoft,
        borderRadius: BorderRadius.circular(InRadii.r2),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tokens.overdue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.overdue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
