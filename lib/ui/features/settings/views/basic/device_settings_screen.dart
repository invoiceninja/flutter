import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/resync_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/text_scale_controller.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/settings_actions.dart';
import 'package:admin/ui/features/settings/widgets/biometric_toggle_tile.dart';
import 'package:admin/ui/features/settings/widgets/confirm_actions_tile.dart';
import 'package:admin/ui/features/settings/widgets/contacts_sync_section.dart';
import 'package:admin/ui/features/settings/widgets/customize_colors_section.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/phone_actions_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/list_status_tabs_section.dart';
import 'package:admin/ui/features/settings/widgets/sidebar_counters_section.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/theme_tile.dart';
import 'package:admin/utils/formatting.dart';

/// Search keys for the settings sidebar search. Colocated with the screen so
/// adding / renaming a field updates both ends in one place (see
/// `search_catalog_consistency_test`).
const kDeviceSettingsSearchKeys = <String>[
  'theme',
  'font_size',
  'customize_colors',
  'sync',
  // Absorbed from Account Management → Overview, which used to carry its own
  // Data card firing the same action (invoiceninja/flutter#71). Kept
  // searchable under the old name so "force full sync" still finds it.
  'force_full_sync',
  'security',
  'confirm_actions',
  'confirm_actions_help',
  'biometric_authentication',
  ...kPhoneActionsSearchKeys,
  ...kContactsSyncSearchKeys,
  ...kListStatusTabsSearchKeys,
  ...kSidebarCountersSearchKeys,
  ...kSidebarBadgeModeSearchKeys,
];

/// Top-level "Device Settings" page. Holds the device-local, no-save controls:
/// theme (mode + palette), the per-preset colour overrides, the action-confirm
/// + biometric guards, and the Sync action. Unlike most settings screens this has no
/// cascade and no save bar — every control writes immediately to a
/// device-local store (`nav_state`). Only the accent colour is server-synced;
/// it lives on User Details → Preferences with the save bar.
class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key});

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen> {
  // Resolved once on mount so the Security section shows the biometric row
  // only where it means something. The section itself always renders now that
  // "Confirm actions" lives in it — both are guard rails (one against
  // unintended access, one against unintended changes), and on desktop, where
  // biometrics are unavailable, the card would otherwise vanish entirely.
  late final Future<bool> _biometricAvailable;

  @override
  void initState() {
    super.initState();
    _biometricAvailable = context.read<Services>().biometric.isAvailable();
  }

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return SettingsScreenScaffold(
      titleKey: 'device_settings',
      body: FutureBuilder<bool>(
        future: _biometricAvailable,
        builder: (context, snap) {
          final showBiometric = snap.data == true;
          return SettingsFormShell(
            sections: [
              FormSection(
                title: context.tr('theme'),
                spacing: 0,
                children: [
                  ThemeTile(controller: services.theme),
                  _FontSizeRow(controller: services.textScale),
                  const Divider(height: 1),
                  CustomizeColorsSection(controller: services.theme),
                ],
              ),
              FormSection(
                title: context.tr('security'),
                children: [
                  const ConfirmActionsTile(),
                  if (showBiometric) const BiometricToggleTile(),
                ],
              ),
              // Outgoing calls above, incoming below: the two phone cards sit
              // together deliberately.
              const PhoneActionsSection(),
              // Native mobile only — hides itself where the app can't write
              // the address book (desktop, web).
              const ContactsSyncSection(),
              const ListStatusTabsSection(),
              const SidebarCountersSection(),
              const _DataSection(),
            ],
          );
        },
      ),
    );
  }
}

/// Device-local UI text-scale picker (Small / Normal / Large / Extra Large).
/// A compact dropdown in the trailing slot of a [ListTile], matching the
/// leading-icon + title shape of the theme mode/palette rows above it.
class _FontSizeRow extends StatelessWidget {
  const _FontSizeRow({required this.controller});

  final TextScaleController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: controller,
      builder: (context, scale, _) {
        return ListTile(
          leading: const Icon(Icons.format_size_outlined),
          title: Text(context.tr('font_size')),
          trailing: DropdownButton<double>(
            // Snap to the nearest preset so an off-by-epsilon stored value
            // can't trip DropdownButton's "exactly one matching item" assert
            // (the labels are threshold-matched for the same float-drift
            // reason — see textScaleLabelKey).
            value: _nearestTextScaleOption(scale),
            isDense: true,
            // Borderless — sits flush in the trailing slot like the rows above.
            underline: const SizedBox.shrink(),
            onChanged: (value) {
              if (value != null) controller.set(value);
            },
            items: [
              for (final option in kTextScaleOptions)
                DropdownMenuItem(
                  value: option,
                  child: Text(context.tr(textScaleLabelKey(option))),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The [kTextScaleOptions] entry closest to [scale] — guards the dropdown
/// against a stored value that isn't exactly one of the four presets.
double _nearestTextScaleOption(double scale) => kTextScaleOptions.reduce(
  (a, b) => (scale - a).abs() <= (scale - b).abs() ? a : b,
);

class _DataSection extends StatefulWidget {
  const _DataSection();

  @override
  State<_DataSection> createState() => _DataSectionState();
}

class _DataSectionState extends State<_DataSection> {
  int? _lastSyncAt;
  Timer? _ticker;
  late final ResyncController _resync;
  late bool _wasRunning;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
    _resync = context.read<Services>().resync;
    _wasRunning = _resync.isRunning;
    _resync.addListener(_onResyncChanged);
    // Keep the relative "last updated" label fresh while the screen is open
    // ("just now" → "2m ago") without needing a manual refresh.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _resync.removeListener(_onResyncChanged);
    _ticker?.cancel();
    super.dispose();
  }

  /// Re-read the high-water mark whenever *any* pass ends, not just one this
  /// screen started — the sidebar Sync button can finish a pass while this
  /// screen is open, and a stale "Last Updated" is exactly the staleness it's
  /// there to report.
  void _onResyncChanged() {
    final running = _resync.isRunning;
    if (_wasRunning && !running) unawaited(_loadLastSync());
    _wasRunning = running;
  }

  /// Read the active company's last-sync high-water mark so the user can see
  /// how stale their local cache is. One-shot (re-read after a pass) — the
  /// value only moves on sync.
  Future<void> _loadLastSync() async {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null) return;
    final row = await services.db.companiesDao.byId(companyId);
    if (mounted) setState(() => _lastSyncAt = row?.lastSyncAt);
  }

  /// In-flight state and the post-run `lastSyncAt` re-read both come from
  /// [_resync] now, so this is just the trigger.
  Future<void> _run() => SettingsActions.forceResync(context);

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final lastSync = _lastSyncAt;
    final companyId =
        context.read<Services>().auth.session.value?.currentCompanyId ?? '';
    return FormSection(
      title: context.tr('data'),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Names the action the button performs. Absorbed from the
            // duplicate Data card on Account Management → Overview, which
            // fired the same `forceResync` from a second place
            // (invoiceninja/flutter#71).
            Text(
              context.tr('force_full_sync'),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: InSpacing.xs),
            Text(
              // App-local key, not Transifex's `download_data` ("Press button
              // below to download the data."): en.json can't be overridden
              // from `_app_pending.json`, and that wording no longer describes
              // the action, which uploads queued edits first.
              context.tr('sync_data_help'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: tokens.ink2),
            ),
            if (lastSync != null && lastSync > 0) ...[
              SizedBox(height: InSpacing.sm),
              Text(
                '${context.tr('last_updated')}: '
                '${formatRelativeTime(context, DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastSync)))}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: tokens.ink3),
              ),
            ],
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ValueListenableBuilder<ResyncProgress>(
            valueListenable: _resync,
            builder: (context, p, _) {
              // Shared with the sidebar Sync button, so a pass started there
              // shows here too — and tapping can't start a competing one.
              final running = p.isRunningFor(companyId);
              return FilledButton.icon(
                // Compact, content-sized button. Without this the themed
                // `Size.fromHeight(44)` default (= infinite min-width) would
                // make the button fill the stretched FormSection column,
                // defeating the centerRight alignment and rendering
                // edge-to-edge.
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                onPressed: running ? null : _run,
                icon: running
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  running && p.total > 0
                      ? context.tr('syncing_progress', {
                          'count': '${p.completed}',
                          'total': '${p.total}',
                        })
                      : context.tr('sync'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
