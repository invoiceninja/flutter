import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/contacts_sync_controller.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/services/device_contacts_service.dart';
import 'package:admin/domain/contacts_sync/contacts_sync_service.dart';
import 'package:admin/domain/contacts_sync/contacts_sync_types.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/dialogs/confirm_action_dialog.dart';
import 'package:admin/ui/core/widgets/notify.dart';
import 'package:admin/ui/core/widgets/primary_dialog_action.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/segmented_setting_row.dart';
import 'package:admin/utils/formatting.dart';

/// Search keys for the settings sidebar search. Colocated with the section so
/// adding a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
const kContactsSyncSearchKeys = <String>[
  'contacts',
  'sync_contacts_to_device',
  'sync_contacts_to_device_help',
  'all_clients',
  'assigned_to_me',
  'remove_synced_contacts',
];

/// Device Settings card for pushing client contacts into this device's address
/// book (invoiceninja/flutter#54 — "know who was calling at any given moment").
///
/// Renders **only where the app can actually write contacts** — native iOS and
/// Android. On desktop and web `canSync` is false and the whole card is absent
/// rather than disabled, because there is nothing the user could do about it.
///
/// Deliberately more explicit than the other device toggles: this one writes to
/// something outside the app that the user also uses for everything else, so it
/// states the label name up front, shows the card count before the first write,
/// and keeps a one-tap way to undo the whole thing.
class ContactsSyncSection extends StatefulWidget {
  const ContactsSyncSection({super.key});

  @override
  State<ContactsSyncSection> createState() => _ContactsSyncSectionState();
}

class _ContactsSyncSectionState extends State<ContactsSyncSection> {
  DeviceContactsPermission? _permission;
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshPermission());
    // Keep the relative "last synced" label honest while the screen is open
    // ("just now" → "2m ago"), same as the Data section above.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refreshPermission() async {
    final permission = await context
        .read<Services>()
        .deviceContacts
        .checkPermission();
    if (mounted) setState(() => _permission = permission);
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    if (!services.deviceContacts.canSync) return const SizedBox.shrink();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (companyId.isEmpty) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: services.contactsSync,
      builder: (context, _) {
        final controller = services.contactsSync;
        return FormSection(
          title: context.tr('contacts'),
          children: [
            _ToggleTile(
              enabled: controller.enabled,
              busy: _busy,
              label: _label(services, companyId),
              onChanged: (value) => _onToggle(value, companyId),
            ),
            // Counting the cards for the pre-flight re-downloads the whole
            // client list, which is not instant on a large account. `_busy`
            // alone only greys the controls out, which reads as a dead tap.
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            if (controller.enabled) ...[
              _ScopeRow(
                scope: controller.scope,
                onChanged: _busy ? null : (s) => _onScopeChanged(s, companyId),
              ),
              if (_permission != DeviceContactsPermission.granted)
                _PermissionNotice(
                  permission: _permission,
                  label: _label(services, companyId),
                  onGrant: _busy ? null : _onGrant,
                  onOpenSettings: () async {
                    await services.deviceContacts.openSystemSettings();
                    // The user comes back from Settings without any lifecycle
                    // signal we subscribe to here, so re-probe on return.
                    await _refreshPermission();
                  },
                )
              else
                _StatusRow(
                  controller: controller,
                  companyId: companyId,
                  busy: _busy,
                  onSyncNow: () => _run(companyId),
                  onRemove: () => _onRemove(companyId),
                ),
            ]
            // Switched off, but cards from an earlier pass are still on the
            // device. "Stop syncing" isn't "delete", so they stay — but the
            // only affordance for removing them must not disappear with the
            // toggle, or the user has to re-enable (and re-sync) to reach it.
            else if (controller.hasRunFor(companyId))
              _StatusRow(
                controller: controller,
                companyId: companyId,
                busy: _busy,
                onSyncNow: null,
                onRemove: () => _onRemove(companyId),
              ),
          ],
        );
      },
    );
  }

  String _label(Services services, String companyId) {
    final name =
        services.auth.session.value?.currentCompany?.displayName.trim() ?? '';
    return ContactsSyncService.labelFor(name);
  }

  /// Switching on is a three-step flow — permission, then a pre-flight that
  /// names the number of cards, then the first pass — because the first thing
  /// this feature does is add potentially thousands of entries to something the
  /// user did not hand over for that purpose. Switching off is immediate.
  Future<void> _onToggle(bool value, String companyId) async {
    final services = context.read<Services>();
    if (!value) {
      await services.contactsSync.setEnabled(false);
      return;
    }

    setState(() => _busy = true);
    try {
      var permission = await services.deviceContacts.checkPermission();
      if (permission == DeviceContactsPermission.denied) {
        permission = await services.deviceContacts.requestPermission();
      }
      if (!mounted) return;
      setState(() => _permission = permission);
      if (permission != DeviceContactsPermission.granted) {
        // Leave the switch on: the permission notice below now explains what
        // to do, and flipping it back would look like the tap did nothing.
        await services.contactsSync.setEnabled(true);
        return;
      }

      final count = await services.contactsSync.previewCardCount(companyId);
      if (!mounted) return;
      final confirmed = await _confirmPreflight(
        count,
        _label(services, companyId),
      );
      if (!confirmed || !mounted) return;

      await services.contactsSync.setEnabled(true);
      // The pre-flight count above just did a full client re-download; letting
      // the pass do it again would page the whole list twice back to back.
      await _run(companyId, refreshClients: false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmPreflight(int count, String label) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('sync_contacts_to_device')),
        content: Text(
          ctx.tr('contacts_sync_preflight', {
            'count': '$count',
            'label': label,
          }),
        ),
        actions: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(ctx.tr('cancel')),
              ),
              SizedBox(width: InSpacing.md(ctx)),
              PrimaryDialogAction(
                label: ctx.tr('continue'),
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _onScopeChanged(
    ContactsSyncScope scope,
    String companyId,
  ) async {
    final services = context.read<Services>();
    await services.contactsSync.setScope(scope);
    if (!mounted) return;
    // Narrowing the scope means deleting cards; widening means adding them.
    // Either way the address book is now wrong until a pass runs, so run one
    // rather than leaving the user to notice and press the button.
    if (_permission == DeviceContactsPermission.granted) {
      await _run(companyId);
    }
  }

  Future<void> _onGrant() async {
    final services = context.read<Services>();
    setState(() => _busy = true);
    try {
      final permission = await services.deviceContacts.requestPermission();
      if (!mounted) return;
      setState(() => _permission = permission);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(String companyId, {bool refreshClients = true}) async {
    final services = context.read<Services>();
    final toasts = Notify.capture(context);
    final failure = context.tr('an_error_occurred');
    final noLabel = context.tr('contacts_sync_no_label_help');

    final summary = await services.contactsSync.run(
      companyId,
      refreshClients: refreshClients,
    );
    switch (summary.outcome) {
      case ContactsSyncOutcome.ok:
        // A pass that changed nothing needs no toast — the "last synced" label
        // below already moved, and this runs on every Sync.
        if (!summary.labelled) toasts?.warning(noLabel);
      case ContactsSyncOutcome.permissionMissing:
        await _refreshPermission();
      case ContactsSyncOutcome.failed:
        toasts?.error(failure);
      case ContactsSyncOutcome.noUser:
        // Scope is "assigned to me" but the session carries no user id. The
        // pass refused to widen to every client; say so rather than looking
        // like a no-op.
        toasts?.error(failure);
      case ContactsSyncOutcome.unsupported:
      case ContactsSyncOutcome.noCompany:
      case ContactsSyncOutcome.cancelled:
        break;
    }
  }

  Future<void> _onRemove(String companyId) async {
    final services = context.read<Services>();
    final label = _label(services, companyId);
    final confirmed = await showConfirmActionDialog(
      context,
      title: context.tr('remove_synced_contacts'),
      message: context.tr('remove_synced_contacts_help', {'label': label}),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await services.contactsSync.removeAll(companyId);
      await services.contactsSync.setEnabled(false);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.enabled,
    required this.busy,
    required this.label,
    required this.onChanged,
  });

  final bool enabled;
  final bool busy;
  final String label;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: const Icon(Icons.contacts_outlined),
      title: Text(context.tr('sync_contacts_to_device')),
      // Two lines, not one: `sync_contacts_to_device_help` is in the settings
      // search catalog, which renders a key's raw translation with no params —
      // so it has to stay placeholder-free (`settings_search_catalog_test`
      // fails the build otherwise). The label name is what the user goes
      // looking for in the Contacts app, so it keeps its own parameterised
      // line rather than being dropped.
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('sync_contacts_to_device_help')),
          const SizedBox(height: InSpacing.xs),
          Text(context.tr('contacts_sync_label_name', {'label': label})),
        ],
      ),
      value: enabled,
      onChanged: busy ? null : onChanged,
    );
  }
}

class _ScopeRow extends StatelessWidget {
  const _ScopeRow({required this.scope, required this.onChanged});

  final ContactsSyncScope scope;
  final ValueChanged<ContactsSyncScope>? onChanged;

  @override
  Widget build(BuildContext context) {
    // Two choices, so both stay visible — a dropdown would hide the one the
    // user isn't on, and "am I syncing the whole company?" is exactly the
    // question this row exists to answer at a glance.
    return SegmentedSettingRow(
      leading: const Icon(Icons.filter_alt_outlined),
      title: context.tr('clients'),
      subtitle: context.tr('sync_settings'),
      // Natural width, not the fixed 80px `segmentLabel` the theme rows use:
      // there's only one segmented row in this card so there's nothing to line
      // up with, and "Assigned to me" would ellipsise inside 80px at anything
      // past the default text scale. `scrollableTrailing` handles the overflow
      // that natural width can cause, same as the font-size row.
      scrollableTrailing: true,
      control: SegmentedButton<ContactsSyncScope>(
        segments: [
          ButtonSegment(
            value: ContactsSyncScope.all,
            label: Text(context.tr('all_clients')),
          ),
          ButtonSegment(
            value: ContactsSyncScope.assignedToMe,
            label: Text(context.tr('assigned_to_me')),
          ),
        ],
        selected: {scope},
        showSelectedIcon: false,
        onSelectionChanged: onChanged == null
            ? null
            : (values) => onChanged!(values.first),
      ),
    );
  }
}

class _PermissionNotice extends StatelessWidget {
  const _PermissionNotice({
    required this.permission,
    required this.label,
    required this.onGrant,
    required this.onOpenSettings,
  });

  final DeviceContactsPermission? permission;
  final String label;
  final VoidCallback? onGrant;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // `denied` can still be re-prompted in-app; everything else has to go
    // through system settings, so offering "Grant" there would be a button
    // that visibly does nothing.
    final canAsk = permission == DeviceContactsPermission.denied;
    final help = switch (permission) {
      DeviceContactsPermission.limited => context.tr(
        'contacts_sync_permission_limited_help',
        {'label': label},
      ),
      DeviceContactsPermission.denied => context.tr(
        'contacts_sync_permission_help',
      ),
      _ => context.tr('contacts_sync_permission_blocked_help'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 18, color: tokens.ink3),
            SizedBox(width: InSpacing.md(context)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('contacts_sync_permission_required'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: InSpacing.xs),
                  Text(
                    help,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: tokens.ink2),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: InSpacing.md(context)),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            // Content-sized: the theme's `Size.fromHeight(44)` default means
            // infinite min-width, which would stretch this edge to edge and
            // defeat the alignment.
            style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
            onPressed: canAsk ? onGrant : onOpenSettings,
            child: Text(
              context.tr(canAsk ? 'grant_permission' : 'open_settings'),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.controller,
    required this.companyId,
    required this.busy,
    required this.onSyncNow,
    required this.onRemove,
  });

  final ContactsSyncController controller;
  final String companyId;
  final bool busy;

  /// Null when the toggle is off — the card is then only a way to remove what
  /// an earlier pass left behind, not a way to sync more.
  final VoidCallback? onSyncNow;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final lastRun = controller.lastRunAt(companyId);
    final progress = controller.progress;
    final running = progress.isRunningFor(companyId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lastRun == null
              ? context.tr('contacts_sync_never_run')
              : '${context.tr('last_updated')}: '
                    '${formatRelativeTime(context, DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastRun)))}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
        ),
        if (controller.lastSummaryFor(companyId) case final summary?
            when summary.outcome == ContactsSyncOutcome.ok &&
                summary.didWrite) ...[
          const SizedBox(height: InSpacing.xs),
          Text(
            context.tr('contacts_sync_result', {
              'added': '${summary.created}',
              'updated': '${summary.updated}',
              'removed': '${summary.deleted}',
            }),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
          ),
        ],
        SizedBox(height: InSpacing.md(context)),
        // Wrap, not Row: "Remove synced contacts" beside "Sync now" needs more
        // width than a 360px handset has once the shell and card padding are
        // taken out — and this section only ever renders on a handset. Wrap
        // keeps them side by side wherever there's room (the design-system
        // rule) and stacks them, still right-aligned, where there isn't.
        Wrap(
          alignment: WrapAlignment.end,
          spacing: InSpacing.md(context),
          runSpacing: InSpacing.sm,
          children: [
            TextButton(
              onPressed: busy || running ? null : onRemove,
              child: Text(context.tr('remove_synced_contacts')),
            ),
            if (onSyncNow != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                onPressed: busy || running ? null : onSyncNow,
                icon: running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  running && progress.total > 0
                      ? context.tr('syncing_progress', {
                          'count': '${progress.done}',
                          'total': '${progress.total}',
                        })
                      : context.tr('sync_now'),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
