import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/default_items_tab_controller.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/list_density_controller.dart';
import 'package:admin/app/resync_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/show_seconds_controller.dart';
import 'package:admin/app/spell_check_controller.dart';
import 'package:admin/app/text_scale_controller.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/widgets/spell_check.dart';
import 'package:admin/ui/core/widgets/watch_builder.dart';
import 'package:admin/ui/features/settings/settings_actions.dart';
import 'package:admin/ui/features/settings/views/advanced/e_invoice/e_invoice_constants.dart';
import 'package:admin/ui/features/settings/widgets/assigned_users_section.dart';
import 'package:admin/ui/features/settings/widgets/biometric_toggle_tile.dart';
import 'package:admin/ui/features/settings/widgets/confirm_actions_tile.dart';
import 'package:admin/ui/features/settings/widgets/card_reader_section.dart';
import 'package:admin/ui/features/settings/widgets/contacts_sync_section.dart';
import 'package:admin/ui/features/settings/widgets/customize_colors_section.dart';
import 'package:admin/ui/features/settings/widgets/dashboard_panels_section.dart';
import 'package:admin/ui/features/settings/widgets/downloads_folder_section.dart';
import 'package:admin/ui/features/settings/widgets/form_section.dart';
import 'package:admin/ui/features/settings/widgets/home_widgets_section.dart';
import 'package:admin/ui/features/settings/widgets/list_status_tabs_section.dart';
import 'package:admin/ui/features/settings/widgets/local_data_copies.dart';
import 'package:admin/ui/features/settings/widgets/mobile_app_section.dart';
import 'package:admin/ui/features/settings/widgets/phone_actions_section.dart';
import 'package:admin/ui/features/settings/widgets/plain_radio_field.dart';
import 'package:admin/ui/features/settings/widgets/segmented_setting_row.dart';
import 'package:admin/ui/features/settings/widgets/settings_form_shell.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/sidebar_counters_section.dart';
import 'package:admin/ui/features/settings/widgets/sidebar_menu_section.dart';
import 'package:admin/ui/features/settings/widgets/theme_tile.dart';
import 'package:admin/ui/features/settings/widgets/trusted_certificates_section.dart';
import 'package:admin/utils/formatting.dart';

// Search keys for the settings search, one list per tab. Colocated with the
// screen so adding / renaming a field updates both ends in one place (see
// `search_catalog_consistency_test`). A tab's own label (`appearance`,
// `security`, …) is its `SettingsSearchTab.titleKey`, so it is not repeated
// here.

/// Appearance tab (the bare URL): theme, what a list shows, the dashboard and
/// the rail.
const kDeviceSettingsAppearanceSearchKeys = <String>[
  'theme',
  'font_size',
  'list_density',
  'customize_colors',
  ...kListStatusTabsSearchKeys,
  'show_seconds',
  'hide_peppol_sent_status',
  ...kDashboardPanelsSearchKeys,
  ...kSidebarMenuSearchKeys,
  ...kSidebarCountersSearchKeys,
  ...kSidebarBadgeModeSearchKeys,
];

/// Security tab: the guard rails, and the certificates trusted past a refusal.
const kDeviceSettingsSecuritySearchKeys = <String>[
  'confirm_actions',
  'confirm_actions_help',
  'biometric_authentication',
  ...kTrustedCertificatesSearchKeys,
];

/// Phone tab: outgoing calls, incoming calls, the home screen, and — away from
/// a phone — the way to the phone app.
const kDeviceSettingsPhoneSearchKeys = <String>[
  ...kPhoneActionsSearchKeys,
  ...kContactsSyncSearchKeys,
  ...kHomeWidgetsSearchKeys,
  ...kCardReaderSearchKeys,
  ...kMobileAppSearchKeys,
];

/// Forms tab: what an edit screen offers.
const kDeviceSettingsFormsSearchKeys = <String>[
  'default_tab',
  'spell_check',
  ...kAssignedUsersSearchKeys,
];

/// Data tab: Sync, the kept copies, and where a download is written.
const kDeviceSettingsDataSearchKeys = <String>[
  'sync',
  // Absorbed from Account Management → Overview, which used to carry its own
  // Data card firing the same action (invoiceninja/flutter#71). Kept
  // searchable under the old name so "force full sync" still finds it.
  'force_full_sync',
  ...kLocalDataCopiesSearchKeys,
  ...kDownloadsFolderSearchKeys,
];

/// The tab slugs below the bare URL, in display order — the `:tab(…)`
/// alternation `settings_routes.dart` registers. The first tab (Appearance)
/// is the bare `/settings/device_settings`.
const kDeviceSettingsTabSlugs = <String>['security', 'phone', 'forms', 'data'];

/// Whether [company] sends by PEPPOL — the one case the Hide Peppol Sent
/// Status row renders, and so the one case settings search offers it.
bool peppolStatusSectionShown(Company? company) =>
    company?.settings.eInvoiceType == kEInvoiceTypePEPPOL;

const String _kBasePath = '/settings/device_settings';

class _TabDef {
  const _TabDef({required this.slug, required this.labelKey});
  final String slug;
  final String labelKey;
}

const _kTabs = <_TabDef>[
  _TabDef(slug: '', labelKey: 'appearance'),
  _TabDef(slug: 'security', labelKey: 'security'),
  _TabDef(slug: 'phone', labelKey: 'phone'),
  _TabDef(slug: 'forms', labelKey: 'forms'),
  _TabDef(slug: 'data', labelKey: 'data'),
];

/// Settings → Device Settings: the device-local, no-save controls. Unlike most
/// settings screens it has no cascade and no save bar — every control writes
/// immediately to a device-local store (`DevicePrefsStore`). Only the accent
/// colour is server-synced; it lives on User Details → Preferences with the
/// save bar.
///
/// Five URL-driven tabs (`docs/settings-screens.md` § Device Settings is
/// tabbed, and every tab opens with a card that always renders):
///
/// * `/settings/device_settings` → Appearance (default).
/// * `/settings/device_settings/security` → Security.
/// * `/settings/device_settings/phone` → Phone.
/// * `/settings/device_settings/forms` → Forms.
/// * `/settings/device_settings/data` → Data.
///
/// Pairs with `tabbedSettingsRoutePair(...)` in `settings_routes.dart`, so the
/// tab is the route — restored on restart like every tabbed settings screen's.
/// Modeled on `BackupRestoreShell`: no VM, because no tab has a draft to save.
class DeviceSettingsScreen extends StatefulWidget {
  const DeviceSettingsScreen({super.key, this.initialTab});

  /// The `:tab` path-parameter from the route, or null on the bare URL
  /// (defaults to Appearance).
  final String? initialTab;

  @override
  State<DeviceSettingsScreen> createState() => _DeviceSettingsScreenState();
}

class _DeviceSettingsScreenState extends State<DeviceSettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: _kTabs.length,
      vsync: this,
      initialIndex: _indexForSlug(widget.initialTab),
    );
    _controller.addListener(_onTabSettled);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTabSettled);
    _controller.dispose();
    super.dispose();
  }

  void _onTabSettled() {
    if (_controller.indexIsChanging) return;
    final tab = _kTabs[_controller.index];
    final desired = tab.slug.isEmpty ? _kBasePath : '$_kBasePath/${tab.slug}';
    final current = GoRouterState.of(context).uri.path;
    if (current == desired) return;
    context.go(desired);
  }

  int _indexForSlug(String? slug) {
    if (slug == null || slug.isEmpty) return 0;
    for (var i = 0; i < _kTabs.length; i++) {
      if (_kTabs[i].slug == slug) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Keep the controller in sync if the URL changed externally (back
    // button, deep link, settings search). The `!=` guard prevents the
    // controller listener (which pushes URL updates) from looping back.
    final currentTab = GoRouterState.of(context).pathParameters['tab'];
    final urlIndex = _indexForSlug(currentTab);
    if (urlIndex != _controller.index && !_controller.indexIsChanging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (urlIndex != _controller.index) _controller.animateTo(urlIndex);
      });
    }

    final tokens = context.inTheme;
    return SettingsScreenScaffold(
      titleKey: 'device_settings',
      bottom: TabBar(
        controller: _controller,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        // 12 a side, not Material's 16: five tabs at 16 ran 6 px past a 390 px
        // phone, so the strip scrolled to hide a sliver of "Data". At 12 they
        // fit down to a 360 px phone in English (docs/pane-width-and-overflow.md
        // § A tab strip is a width budget); longer translations still scroll.
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        labelColor: tokens.ink,
        unselectedLabelColor: tokens.ink3,
        indicatorColor: tokens.accent,
        indicatorWeight: 2,
        tabs: [for (final tab in _kTabs) Tab(text: context.tr(tab.labelKey))],
      ),
      // Every tab opens with a card that renders on every platform, so none
      // is ever empty when the platform-gated cards hide themselves.
      body: TabBarView(
        controller: _controller,
        children: const [
          _AppearanceTab(),
          _SecurityTab(),
          _PhoneTab(),
          _FormsTab(),
          _DataTab(),
        ],
      ),
    );
  }
}

/// How the app looks and what its screens show: theme, the list switches, the
/// dashboard, and the rail. Sidebar counters closes the tab — it alone can
/// render 14 rows, so anything after it is a long way down on a phone.
class _AppearanceTab extends StatelessWidget {
  const _AppearanceTab();

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    return SettingsFormShell(
      sections: [
        FormSection(
          title: context.tr('theme'),
          spacing: 0,
          children: [
            ThemeTile(controller: services.theme),
            _FontSizeRow(controller: services.textScale),
            _ListDensityRow(controller: services.listDensity),
            const Divider(height: 1),
            CustomizeColorsSection(controller: services.theme),
          ],
        ),
        const _ListsSection(),
        const DashboardPanelsSection(),
        // Both are about the rail, but one is what the rows *are* and the
        // other is what their numbers count — see ListStatusTabsTile.
        const SidebarMenuSection(),
        const SidebarCountersSection(),
      ],
    );
  }
}

/// The guard rails, then the certificates trusted past a refusal.
class _SecurityTab extends StatefulWidget {
  const _SecurityTab();

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  // Resolved once on mount so the card shows the biometric row only where it
  // means something. The card itself always renders now that "Confirm
  // actions" lives in it — both are guard rails (one against unintended
  // access, one against unintended changes), and on desktop, where biometrics
  // are unavailable, the tab would otherwise be empty.
  late final Future<bool> _biometricAvailable = context
      .read<Services>()
      .biometric
      .isAvailable();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _biometricAvailable,
      builder: (context, snap) => SettingsFormShell(
        sections: [
          // Untitled: "Security" would only repeat the tab.
          FormSection(
            title: null,
            children: [
              const ConfirmActionsTile(),
              if (snap.data == true) const BiometricToggleTile(),
            ],
          ),
          // Hides itself unless a server certificate has been trusted — and
          // always on web, where the browser owns certificates.
          const TrustedCertificatesSection(),
        ],
      ),
    );
  }
}

/// The phone cards, together: outgoing calls, incoming calls, the home screen,
/// and — everywhere but a phone — the way to the phone app.
class _PhoneTab extends StatelessWidget {
  const _PhoneTab();

  @override
  Widget build(BuildContext context) {
    return const SettingsFormShell(
      sections: [
        // Renders everywhere, so the tab is never empty: a macOS user with
        // FaceTime, or Windows with Phone Link, has a working dialer too.
        PhoneActionsSection(),
        // Native mobile only — hides itself where the app can't write the
        // address book (desktop, web).
        ContactsSyncSection(),
        // iOS, Android and macOS: how to add the home-screen widgets, which
        // nothing else in the app mentions.
        HomeWidgetsSection(),
        // The store build of the mobile app: Tap to Pay and card readers for
        // in-person card payments.
        CardReaderSection(),
        // Everywhere *but* a phone: the way to the phone app that does the
        // cards above.
        MobileAppSection(),
      ],
    );
  }
}

/// What an edit screen offers: the items table, and who an assignee field
/// lists.
class _FormsTab extends StatelessWidget {
  const _FormsTab();

  @override
  Widget build(BuildContext context) {
    return const SettingsFormShell(
      sections: [_ItemsSection(), AssignedUsersSection()],
    );
  }
}

/// Sync and the kept copies, then where a desktop download is written.
class _DataTab extends StatelessWidget {
  const _DataTab();

  @override
  Widget build(BuildContext context) {
    return const SettingsFormShell(
      sections: [
        _DataSection(),
        // Desktop only: where a download is written.
        DownloadsFolderSection(),
      ],
    );
  }
}

/// "Items": the two settings about a billing document's items table — which
/// items tab it opens on (React #3355) and whether its line items underline
/// spelling mistakes (docs/spell-check.md). One card, since both act on the
/// same table; they used to be two cards of one control each.
class _ItemsSection extends StatelessWidget {
  const _ItemsSection();

  @override
  Widget build(BuildContext context) {
    final defaultTab = context.read<Services>().defaultItemsTab;
    final spellCheck = context.read<SpellCheckController?>();
    return FormSection(
      title: context.tr('items'),
      children: [
        // "Default tab": which items tab (Products / Tasks) an invoice, quote
        // or recurring invoice opens on when its own lines don't decide. Two
        // choices, so a radio (CLAUDE.md § Two-choice fields).
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr('default_tab'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            ValueListenableBuilder<String>(
              valueListenable: defaultTab,
              builder: (context, _, _) => PlainRadioField<String>(
                label: context.tr('default_tab_help'),
                // Derived from `prefersTasks`, so a stored value this build
                // doesn't know still selects a choice (Products) rather than
                // none.
                value: defaultTab.prefersTasks
                    ? kItemsTabTasks
                    : kItemsTabProducts,
                options: [
                  (value: kItemsTabProducts, label: context.tr('products')),
                  (value: kItemsTabTasks, label: context.tr('tasks')),
                ],
                onChanged: defaultTab.set,
              ),
            ),
          ],
        ),
        // Only where the platform has a checker (not Linux, not web) —
        // elsewhere the switch would toggle nothing.
        if (spellCheck != null && platformSupportsSpellCheck)
          ValueListenableBuilder<bool>(
            valueListenable: spellCheck,
            builder: (context, enabled, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.spellcheck_outlined),
              title: Text(context.tr('spell_check')),
              subtitle: Text(context.tr('spell_check_help')),
              value: enabled,
              onChanged: spellCheck.set,
            ),
          ),
      ],
    );
  }
}

/// "Lists": the switches about what a list shows — the status tab strip,
/// seconds on the task surfaces, and (for a PEPPOL company) the sent mark on
/// the invoice and credit lists. They used to be three cards of one control
/// each.
class _ListsSection extends StatelessWidget {
  const _ListsSection();

  @override
  Widget build(BuildContext context) {
    final showSeconds = context.read<ShowSecondsController?>();
    return FormSection(
      title: context.tr('lists'),
      // Row-tiles carry their own padding, and the PEPPOL row renders nothing
      // for most companies — with a gap per child it would still cost one.
      spacing: 0,
      children: [
        const ListStatusTabsTile(),
        // "Show Seconds": add seconds where the Tasks surfaces leave them out
        // — the kanban cards, a timer past a day, a time entry's start and end
        // (docs/tasks-views.md). Running timers tick seconds either way.
        if (showSeconds != null)
          ValueListenableBuilder<bool>(
            valueListenable: showSeconds,
            builder: (context, enabled, _) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.timer_outlined),
              title: Text(context.tr('show_seconds')),
              subtitle: Text(context.tr('show_seconds_help')),
              value: enabled,
              onChanged: showSeconds.set,
            ),
          ),
        const _PeppolStatusTile(),
      ],
    );
  }
}

/// "Hide Peppol Sent Status": the sent / failed mark beside the status on the
/// invoice and credit lists (React ui#3410). The row shows only while the
/// active company sends by PEPPOL, the one case where there is a mark to hide.
class _PeppolStatusTile extends StatelessWidget {
  const _PeppolStatusTile();

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();
    final companyId = services.auth.session.value?.currentCompanyId;
    if (companyId == null || companyId.isEmpty) return const SizedBox.shrink();
    return WatchBuilder<Company?>(
      cacheKey: companyId,
      create: () => services.company.watchCompany(companyId),
      builder: (context, snapshot) {
        if (!peppolStatusSectionShown(snapshot.data)) {
          return const SizedBox.shrink();
        }
        final controller = services.hidePeppolStatus;
        return ValueListenableBuilder<bool>(
          valueListenable: controller,
          builder: (context, hidden, _) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.send_outlined),
            title: Text(context.tr('hide_peppol_sent_status')),
            value: hidden,
            onChanged: controller.set,
          ),
        );
      },
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

/// Device-local list density (Normal / Compact) — how tightly entity lists
/// pack their rows. Next to Font Size, the other "how much fits on screen"
/// control; the same preference as the toggle beside a list's Columns button.
/// Same shape as the theme rows above so the segments line up; the subtitle
/// says what the setting is for, since the selected segment already says which
/// one is on. See `docs/list-density.md`.
class _ListDensityRow extends StatelessWidget {
  const _ListDensityRow({required this.controller});

  final ListDensityController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: controller,
      builder: (context, _, _) => SegmentedSettingRow(
        leading: const Icon(Icons.density_medium_outlined),
        title: context.tr('list_density'),
        subtitle: context.tr('list_density_help'),
        control: SegmentedButton<bool>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: false, label: segmentLabel(context, 'normal')),
            ButtonSegment(value: true, label: segmentLabel(context, 'compact')),
          ],
          // Derived from `isCompact`, so a stored value this build doesn't
          // know still selects a segment (Normal) rather than none.
          selected: {controller.isCompact},
          onSelectionChanged: (s) => controller.setCompact(s.first),
        ),
      ),
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
    // Untitled: "Data" would only repeat the tab. "Force full sync" leads it.
    return FormSection(
      title: null,
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
        // One child, not two: the kept copies render nothing when there are
        // none, and as a child of their own they would still cost the card a
        // gap (§ A card that hides itself still costs a gap).
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
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
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(64, 44),
                    ),
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
            const LocalDataCopies(),
          ],
        ),
      ],
    );
  }
}
