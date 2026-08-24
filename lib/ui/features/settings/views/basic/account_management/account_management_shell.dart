import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/danger_zone_screen.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/enabled_modules_screen.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/integrations_screen.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/overview_screen.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/plan_screen.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/referral_program_screen.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/security_settings_screen.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';

const String _kBasePath = '/settings/account_management';

/// The Account Management tab slug encoded in [path]: `''` for the bare base
/// path (the Plan tab), or the first segment after it — so a sub-route such as
/// `…/integrations/analytics` still resolves to the `integrations` tab. Returns
/// null when [path] is not under the shell at all.
///
/// The shell can't just read `:tab` off the route: go_router hands every page
/// in the stack the *whole match list's* `pathParameters`, so once a
/// `tabSubRoutes` child is the terminal match `:tab` is null — and a shell that
/// trusted it would snap back to the Plan tab and navigate the child the user
/// is looking at away. Same shape as `_activeSlug` in `settings_screen.dart`.
@visibleForTesting
String? accountManagementTabSlug(String path) {
  if (!path.startsWith(_kBasePath)) return null;
  final rest = path.substring(_kBasePath.length);
  if (rest.isEmpty) return '';
  // Guard against a sibling route that merely shares the prefix.
  if (!rest.startsWith('/')) return null;
  final segments = rest.split('/').where((s) => s.isNotEmpty);
  return segments.isEmpty ? '' : segments.first;
}

/// Every Account Management tab, in display order. Not `const` — each entry
/// carries a builder closure, and closures aren't const expressions.
final List<_TabDef> _kAllTabs = <_TabDef>[
  _TabDef(
    slug: '',
    labelKey: 'plan',
    builder: () => AccountManagementPlanScreen(),
  ),
  _TabDef(
    slug: 'overview',
    labelKey: 'overview',
    builder: () => AccountManagementOverviewScreen(),
  ),
  _TabDef(
    // Slug stays `enabled_modules` — it is a URL segment and a persisted
    // `nav_state` value; only the label changed. The tab lists disabled
    // modules too, so "Enabled Modules" misnamed half of it
    // (invoiceninja/flutter#81).
    slug: 'enabled_modules',
    labelKey: 'modules',
    builder: () => AccountManagementEnabledModulesScreen(),
  ),
  _TabDef(
    slug: 'integrations',
    labelKey: 'integrations',
    builder: () => AccountManagementIntegrationsScreen(),
  ),
  _TabDef(
    slug: 'security_settings',
    labelKey: 'security_settings',
    builder: () => AccountManagementSecuritySettingsScreen(),
  ),
  _TabDef(
    slug: 'referral_program',
    labelKey: 'referral_program',
    builder: () => AccountManagementReferralProgramScreen(),
    hostedOnly: true,
  ),
  _TabDef(
    slug: 'danger_zone',
    labelKey: 'danger_zone',
    builder: () => AccountManagementDangerZoneScreen(),
  ),
];

List<_TabDef> _visibleTabs({required bool isHosted}) => [
  for (final tab in _kAllTabs)
    if (isHosted || !tab.hostedOnly) tab,
];

/// Slugs of the Account Management tabs a session actually sees, in display
/// order (`''` = Plan). Referral Program is hosted-only — a self-hosted account
/// can't earn referrals, so the tab is hidden outright rather than rendered as
/// an explanatory dead end (issue #27). That matches every other SaaS-only
/// surface in the app (PEPPOL buy-credits links, Connect Calendar, the hosted
/// upgrade card, bank "Refresh accounts") and React's own
/// `useAccountManagementTabs`.
@visibleForTesting
List<String> visibleAccountManagementTabSlugs({required bool isHosted}) => [
  for (final tab in _visibleTabs(isHosted: isHosted)) tab.slug,
];

/// Settings → Account Management. Seven URL-driven tabs (six on self-hosted —
/// see [visibleAccountManagementTabSlugs]):
///
/// * `/settings/account_management` → Plan (default).
/// * `/settings/account_management/overview` → Overview.
/// * `/settings/account_management/enabled_modules` → Enabled Modules.
/// * `/settings/account_management/integrations` → Integrations.
/// * `/settings/account_management/security_settings` → Security Settings.
/// * `/settings/account_management/referral_program` → Referral Program
///   (hosted only).
/// * `/settings/account_management/danger_zone` → Danger Zone.
///
/// Pairs with `tabbedSettingsRoutePair(...)` in `settings_routes.dart` — both
/// the bare URL and per-tab URL resolve to a single Navigator Page so
/// swiping a tab doesn't remount the shell.
///
/// Modeled on `BackupRestoreShell` (`widgets/backup_restore_shell.dart`):
/// no VM scaffolding because each tab fires its writes through
/// `services.company.updateCompany` independently — there is no unified Save
/// button. The `TabbedSettingsShell<V extends SettingsDraftHost>` machinery
/// would be pure overhead here.
///
/// The Integrations tab's destinations (API Tokens, API Webhooks, Analytics,
/// QuickBooks) are `tabSubRoutes` children of
/// `/settings/account_management/integrations`, so this shell stays on the back
/// stack underneath them and system back returns here with the Integrations tab
/// still selected. The active tab therefore comes from the path (see
/// [accountManagementTabSlug]), not from the `:tab` path parameter.
class AccountManagementShell extends StatefulWidget {
  const AccountManagementShell({super.key, this.initialTab});

  /// The tab to mount on: the `:tab` path-parameter for a tab URL, the fixed
  /// slug for a tab that owns sub-routes (see `tabSubRoutes`), or null on the
  /// bare URL (defaults to the Plan tab). Only read at mount — afterwards the
  /// active tab tracks the location via [accountManagementTabSlug].
  final String? initialTab;

  @override
  State<AccountManagementShell> createState() => _AccountManagementShellState();
}

class _AccountManagementShellState extends State<AccountManagementShell>
    with SingleTickerProviderStateMixin {
  late final List<_TabDef> _tabs;
  late final TabController _controller;
  late final Services _services;
  String _scopedCompanyId = '';

  @override
  void initState() {
    super.initState();
    // The Overview / Security / Enabled-Modules / Integrations tabs save the
    // WHOLE company via `services.company.updateCompany` (no SettingsDraftViewModel
    // and so no `kickRefresh`). After a full sync the login envelope omits the
    // SMTP/expense/task/payment-conversion columns, so the cached row holds Drift
    // defaults; PUTting that draft would clobber the server's real values. Pull
    // the canonical company on mount (GET /companies/{id} -> applyUpdateResponse)
    // before the user can toggle anything, mirroring DraftStreamHost.load()'s
    // `kickRefresh()` and system_logs_screen's refresh-on-mount.
    _services = context.read<Services>();
    // `isHosted` can't change without a re-login, which tears this shell down,
    // so the visible set is resolved once — a TabController's length is fixed
    // at construction. Fail OPEN on a not-yet-loaded session (`?? true`):
    // showing the tab lets the screen's own guard explain itself, whereas
    // failing closed would strand a hosted user with no way back short of a
    // remount.
    _tabs = _visibleTabs(
      isHosted: _services.auth.session.value?.isHosted ?? true,
    );
    _controller = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: _indexForSlug(widget.initialTab),
    );
    _controller.addListener(_onTabSettled);
    _scopedCompanyId = _services.auth.session.value?.currentCompanyId ?? '';
    _services.auth.session.addListener(_onSession);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCompany());
  }

  @override
  void dispose() {
    _services.auth.session.removeListener(_onSession);
    _controller.removeListener(_onTabSettled);
    _controller.dispose();
    super.dispose();
  }

  // Re-pull the canonical company when the user switches company while this
  // shell stays mounted. The session notifier also fires on unrelated
  // companies-table writes, so guard on the id to make those no-ops (same
  // pattern as system_logs_screen._onSession).
  void _onSession() {
    if (!mounted) return;
    final id = _services.auth.session.value?.currentCompanyId ?? '';
    if (id == _scopedCompanyId) return;
    _scopedCompanyId = id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshCompany());
  }

  void _refreshCompany() {
    if (!mounted) return;
    final companyId = _services.auth.session.value?.currentCompanyId ?? '';
    if (companyId.isEmpty) return;
    // Fire-and-forget; errors are swallowed inside CompanyRepository.refresh
    // (the tabs still render from the cached row when offline).
    _services.company.refresh(companyId);
  }

  void _onTabSettled() {
    if (!mounted) return;
    if (_controller.indexIsChanging) return;
    final tab = _tabs[_controller.index];
    final current = GoRouterState.of(context).uri.path;
    // A sub-route of this tab (e.g. `…/integrations/analytics`) already counts
    // as "on this tab" — rewriting the URL there would pop the child away.
    if (accountManagementTabSlug(current) == tab.slug) return;
    final desired = tab.slug.isEmpty ? _kBasePath : '$_kBasePath/${tab.slug}';
    context.go(desired);
  }

  int _indexForSlug(String? slug) {
    if (slug == null || slug.isEmpty) return 0;
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].slug == slug) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Keep the controller in sync if the URL changed externally (back button,
    // deep link, settings search). The `!=` guard prevents the controller
    // listener (which pushes URL updates) from looping back into another
    // `animateTo`. A null slug means the location left this shell entirely
    // (the page is being torn down) — leave the tab alone.
    final currentTab = accountManagementTabSlug(
      GoRouterState.of(context).uri.path,
    );
    final urlIndex = _indexForSlug(currentTab);
    final knownTab =
        currentTab != null &&
        (currentTab.isEmpty || _tabs.any((t) => t.slug == currentTab));
    if (currentTab != null && !knownTab) {
      // A hidden (or stale) tab URL — e.g. restored nav state pointing at
      // `…/referral_program` from a previous hosted login. `_indexForSlug`
      // falls back to the Plan tab, and because the controller index never
      // changes `_onTabSettled` won't rewrite the URL — so do it here, or the
      // location keeps naming a tab that isn't on screen.
      //
      // `Router.neglect` matters on web: this is a URL *correction*, not a
      // navigation. A plain `context.go` reports `navigate`, which go_router
      // turns into a pushed browser history entry — so Back would return to
      // the hidden tab's URL, which normalizes forward again, trapping the
      // user. Neglecting reports `replace`, overwriting the entry instead.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Router.neglect(context, () => context.go(_kBasePath));
      });
    } else if (knownTab &&
        urlIndex != _controller.index &&
        !_controller.indexIsChanging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (urlIndex != _controller.index) {
          _controller.animateTo(urlIndex);
        }
      });
    }

    final tokens = context.inTheme;
    return SettingsScreenScaffold(
      titleKey: 'account_management',
      bottom: TabBar(
        controller: _controller,
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        labelColor: tokens.ink,
        unselectedLabelColor: tokens.ink3,
        indicatorColor: tokens.accent,
        indicatorWeight: 2,
        tabs: [for (final tab in _tabs) Tab(text: context.tr(tab.labelKey))],
      ),
      body: TabBarView(
        controller: _controller,
        children: [for (final tab in _tabs) tab.builder()],
      ),
    );
  }
}

class _TabDef {
  const _TabDef({
    required this.slug,
    required this.labelKey,
    required this.builder,
    this.hostedOnly = false,
  });

  final String slug;
  final String labelKey;

  /// Called on every build, so each rebuild yields a FRESH instance: when
  /// external state changes (e.g. session re-emits) and the shell rebuilds,
  /// a new widget lets `Element.updateChild` walk into the subtree instead of
  /// short-circuiting on identity.
  final Widget Function() builder;

  /// Hidden entirely on self-hosted sessions — see
  /// [visibleAccountManagementTabSlugs].
  final bool hostedOnly;
}
