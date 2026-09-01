import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/plan_gate.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/settings/settings_search_catalog.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/state/settings_search_controller.dart';
import 'package:admin/ui/features/settings/widgets/settings_two_pane_scope.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';

// `PlanTier` (the tier surfaced on a locked sidebar row / search hit) now
// comes from `package:admin/domain/plan_gate.dart` — imported above.

/// Master list of settings sections — pure list, no `Scaffold`. Used as the
/// left pane on wide screens (mounted by `SettingsShell`) and as the body of
/// `SettingsScreen` on narrow screens. Reads the current go_router location
/// to highlight whichever top-level section is active.
///
/// Tapping the search affordance swaps the section list for a flat list of
/// matching fields drawn from `kSettingsSearchCatalog`. **Where that
/// affordance lives depends on who owns the state** — see [searchController].
class SettingsListSidebar extends StatefulWidget {
  const SettingsListSidebar({super.key, this.searchController});

  /// Search state owned by the **host** — non-null only when that host also
  /// renders the trigger and the text field. Today that is [SettingsScreen],
  /// which pins both in its AppBar so they can't scroll away (issue #42), and
  /// this widget renders only the section list / results.
  ///
  /// Leave null — the wide 280 px pane, which has no AppBar of its own — and
  /// this widget owns the state *and* the affordance: a "Settings" title row
  /// carrying the search icon, pinned above the scroll area, plus the field row
  /// that replaces the pane while searching. Those go together on purpose: the
  /// controller is the ownership token, so there is exactly one trigger and
  /// exactly one field at any width.
  final SettingsSearchController? searchController;

  @override
  State<SettingsListSidebar> createState() => _SettingsListSidebarState();
}

class _SettingsListSidebarState extends State<SettingsListSidebar> {
  /// Non-null only when no host supplied one. Never dispose the host's.
  SettingsSearchController? _own;

  SettingsSearchController get _search => widget.searchController ?? _own!;
  bool get _hostOwned => widget.searchController != null;

  @override
  void initState() {
    super.initState();
    if (widget.searchController == null) _own = SettingsSearchController();
  }

  @override
  void dispose() {
    // Only what we created — the host disposes what it created, matching how
    // `TextField` treats a passed-in controller.
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _search,
      builder: (context, _) =>
          _search.isActive ? _buildSearch(context) : _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    final list = _buildSectionList(context);
    if (_hostOwned) return list;
    // Self-owned (the wide pane): lift the trigger out of the scroll area so it
    // stays reachable at any scroll position — issue #42 in the layout that has
    // no AppBar to host it.
    //
    // The screen title rides along, `titleLarge` to match what M3's AppBar
    // gives the narrow layout — so both widths open on the same "Settings"
    // heading above "Basic Settings", and this pane isn't the one layout that
    // starts cold on a group header. A *group* label would not belong up here:
    // the strip is pinned, so hoisting "Basic Settings" would leave it claiming
    // Basic while the user has scrolled into Advanced. Both group headers stay
    // inside the list, exactly as they render on narrow.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr('settings'),
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search),
                tooltip: context.tr('search_settings'),
                onPressed: _search.open,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: list),
      ],
    );
  }

  Widget _buildSectionList(BuildContext context) {
    final activeSlug = _activeSlug(GoRouterState.of(context).uri.path);
    // Group and client are both non-company cascade levels — they show the
    // same overridable (cascade-aware) sections, hiding company-only ones.
    final settingsLevel = context.watch<SettingsLevelController>();
    final isCascade = settingsLevel.isClient || settingsLevel.isGroup;
    // Listen to session so the lock icons appear / disappear when a fresh
    // refresh lands (e.g. after the user upgrades in the portal and lands
    // back in the app), and so module-gated sections drop out reactively
    // when the company toggles a module. Only the list body wraps — search
    // state lives above this builder.
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: context.read<Services>().auth.session,
      builder: (context, session, _) {
        final modules = session?.currentCompany?.enabledModules ?? 0;
        final me = session?.currentCompany;
        final isAdminOrOwner = me?.isAdmin == true || me?.isOwner == true;
        bool inScope(SettingsSectionDef s) =>
            (!isCascade || s.clientEditable) &&
            s.isVisibleFor(modules) &&
            (!s.adminOnly || isAdminOrOwner);
        final basic = kSettingsSections.where((s) => s.isBasic && inScope(s));
        final advanced = kSettingsSections.where(
          (s) => !s.isBasic && inScope(s),
        );
        return ListView(
          children: [
            // No `trailing:` at either width — the trigger is pinned in the
            // chrome above (the AppBar on narrow, a strip on the wide pane).
            // An in-list copy would be a second trigger that scrolls away, and
            // that IS issue #42.
            _GroupHeader(context.tr('basic_settings')),
            for (final s in basic) _tile(context, s, activeSlug, session),
            const Divider(height: 1),
            _GroupHeader(context.tr('advanced_settings')),
            for (final s in advanced) _tile(context, s, activeSlug, session),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildSearch(BuildContext context) {
    // Rebuild results on company switch so a now-disabled section drops
    // out of an open search without the user having to retype.
    final results = ValueListenableBuilder<AuthSession?>(
      valueListenable: context.read<Services>().auth.session,
      builder: (context, _, _) => ListenableBuilder(
        // The query is its own `Listenable`, so a keystroke rebuilds the hit
        // list and nothing else. The old `onChanged: setState` rebuilt this
        // whole pane — host-side it would have rebuilt the AppBar per
        // character.
        listenable: _search.query,
        builder: (context, _) =>
            _buildResults(context, Localization.of(context)),
      ),
    );
    // The host renders the field (pinned in its AppBar), so results are all
    // that's left for the body.
    if (_hostOwned) return results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
          child: Row(
            children: [
              Expanded(child: SettingsSearchField(controller: _search)),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.tr('cancel'),
                onPressed: _search.close,
              ),
            ],
          ),
        ),
        Expanded(child: results),
      ],
    );
  }

  Widget _buildResults(BuildContext context, Localization? l10n) {
    if (l10n == null) return const SizedBox.shrink();
    final session = context.read<Services>().auth.session.value;
    final modules = session?.currentCompany?.enabledModules ?? 0;
    final me = session?.currentCompany;
    final isAdminOrOwner = me?.isAdmin == true || me?.isOwner == true;
    final settingsLevel = context.read<SettingsLevelController>();
    final isCascade = settingsLevel.isClient || settingsLevel.isGroup;
    // Fail open on a not-yet-loaded session, matching AccountManagementShell.
    final isHosted = session?.isHosted ?? true;
    // Filter at query time — not by trimming the catalog — so a module-gated
    // (or admin-only) section never surfaces as a dead link, while
    // `kSettingsSearchCatalog` stays complete (search_catalog_consistency_test
    // enforces parity). The cascade gate mirrors `_buildSectionList`'s
    // `inScope`: at client/group scope, a company-only page reached through
    // search renders under the "editing client X" banner with checked override
    // boxes wired to the COMPANY draft — the user's "per-client override"
    // edit would silently change the company-wide default. The hosted gate is
    // per-FIELD, not per-section: Account Management is always visible, but
    // its Referral Program tab isn't (issue #27).
    final hits = searchSettings(_search.query.text, l10n)
        .where((h) => !isCascade || h.section.clientEditable)
        .where((h) => h.section.isVisibleFor(modules))
        .where((h) => !h.section.adminOnly || isAdminOrOwner)
        .where(
          (h) => isHosted || !kHostedOnlySettingsFields.contains(h.fieldKey),
        )
        .toList();
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.tr('no_results'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final hit = hits[i];
        final gate = _gateLevelFor(hit.section.slug, session);
        return ListTile(
          leading: Icon(hit.section.icon),
          title: Text(
            l10n.lookup(hit.fieldKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            l10n.lookup(hit.section.titleKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // Same compact gate affordance the sidebar `_tile` uses — a wide
          // "Pro"/"Enterprise" text chip here overflows the ~232 px settings
          // sidebar (RenderFlex overflowed on the right).
          trailing: gate == null
              ? null
              : Tooltip(
                  message: context.tr(
                    gate == PlanTier.enterprise
                        ? 'enterprise_plan'
                        : 'pro_plan',
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: context.inTheme.ink3,
                  ),
                ),
          onTap: () async {
            if (!await _confirmIfDirty(context)) return;
            if (!context.mounted) return;
            context.go(hit.section.route);
            _search.close();
          },
        );
      },
    );
  }

  Future<bool> _confirmIfDirty(BuildContext context) {
    return context.read<Services>().unsavedChangesGuard.confirmIfDirty(context);
  }

  Widget _tile(
    BuildContext context,
    SettingsSectionDef section,
    String? activeSlug,
    AuthSession? session,
  ) {
    final tokens = context.inTheme;
    final selected = section.slug == activeSlug;
    final gate = _gateLevelFor(section.slug, session);
    return ListTile(
      leading: Icon(section.icon),
      title: Text(context.tr(section.titleKey)),
      trailing: gate == null
          ? null
          : Tooltip(
              message: context.tr(
                gate == PlanTier.enterprise ? 'enterprise_plan' : 'pro_plan',
              ),
              child: Icon(Icons.lock_outline, size: 16, color: tokens.ink3),
            ),
      selected: selected,
      selectedTileColor: tokens.accentSoft,
      // Drives both leading icon + title color when `selected` is true.
      // Matches the SidebarNavItem active-state pattern.
      selectedColor: tokens.accentInk,
      iconColor: tokens.ink3,
      textColor: tokens.ink2,
      onTap: () async {
        if (!await _confirmIfDirty(context)) return;
        if (!context.mounted) return;
        context.go(section.route);
      },
    );
  }

  /// Decides whether to render a trailing lock icon on a sidebar / search row.
  /// Returns the gate tier when the active session lacks access, null when
  /// the section is ungated or the user already qualifies (incl. self-hosted).
  static PlanTier? _gateLevelFor(String slug, AuthSession? session) =>
      planGateFor(session, settingsSlug: slug);

  /// Extract the top-level section slug from a path like
  /// `/settings/user_details/preferences` → `user_details`. Returns null when
  /// the user is on `/settings` itself (no section selected).
  static String? _activeSlug(String path) {
    if (!path.startsWith('/settings')) return null;
    final rest = path.substring('/settings'.length);
    if (rest.isEmpty || rest == '/') return null;
    final segments = rest.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? null : segments.first;
  }
}

/// The settings search input. Shared so the AppBar-hosted (narrow) copy and
/// the in-pane (wide) copy can't drift apart.
class SettingsSearchField extends StatelessWidget {
  const SettingsSearchField({super.key, required this.controller});

  final SettingsSearchController controller;

  @override
  Widget build(BuildContext context) {
    // A floor, not a fixed height. The `prefixIcon` alone gives this field a
    // 48 px intrinsic height (icon minimums don't shrink with
    // `contentPadding: vertical: 0`), so pinning the box to 40 clipped it
    // silently at every text scale. Same reason the narrow copy hangs in the
    // AppBar's 56 px `bottom:` rather than its `title:` slot, which clamps to
    // `kToolbarHeight` and would re-create exactly that clipping.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 40),
      child: TextField(
        controller: controller.query,
        focusNode: controller.focus,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.tr('search_settings'),
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 12,
          ),
        ),
      ),
    );
  }
}

/// Narrow-only route target for `/settings`. On wide screens the shell shows
/// `SettingsListSidebar` directly in the left pane, so this screen never gets
/// rendered — but it remains the route's `builder` so the back-button on
/// narrow lands on the list cleanly.
///
/// Owns the search chrome: the trigger in the AppBar's `actions:` and the
/// field in its 56 px `bottom:` strip, mirroring `EntityListNormalAppBar`'s
/// narrow layout. Neither may live in the scrolling body — that was issue #42.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsSearchController _search = SettingsSearchController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final globalNav = Breakpoints.isGlobalNavVisible(context);
    // A resize past `Breakpoints.settingsTwoPane` leaves this screen mounted
    // but `Offstage` inside `SettingsShell`'s wide branch
    // (`HiddenShellNavigator`) — `settingsIndexRedirect` only runs on
    // *navigation*. Never intercept back from there: the pane's own sidebar is
    // what the user is looking at, and an invisible open search would swallow
    // the press.
    final twoPane = SettingsTwoPaneScope.of(context);
    return ListenableBuilder(
      listenable: _search,
      builder: (context, _) => PopScope(
        // Android convention: back collapses an open search before leaving the
        // screen. `canPop` is read at build time, which is safe here because
        // the flag is this screen's own state — a rebuild always precedes the
        // next press, unlike the navigation-lag cases `SystemBackGate` warns
        // about. When true, `Route.popDisposition` returns `bubble` (this
        // route is `isFirst` in the settings shell's navigator) and back falls
        // through to `SystemBackGate` exactly as it does today.
        //
        // This out-ranks an open `AppDrawer`'s `LocalHistoryEntry`:
        // `ModalRoute.popDisposition` checks `PopScope` entries before
        // `LocalHistoryRoute`'s. So back with both open closes search and
        // leaves the drawer up — contrived, and the drawer still has its scrim
        // and swipe, so it isn't worth an `onDrawerChanged` rebuild to chase.
        canPop: !(_search.isActive && !twoPane),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _search.close();
        },
        child: Scaffold(
          drawer: globalNav ? null : const AppDrawer(),
          appBar: AppBar(
            title: Text(context.tr('settings')),
            leading: globalNav ? null : const DrawerHamburger(),
            automaticallyImplyLeading: !globalNav,
            // Mirrors `EntityListNormalAppBar`'s narrow chrome: the affordance
            // in `actions:`, the field pinned in a 56 px `bottom:`. No
            // `preferredSize` to keep in sync — this is a real `AppBar`, so it
            // derives `kToolbarHeight + 56` from `bottom` itself. Don't wrap it
            // in a custom `PreferredSizeWidget`; that's what forces
            // `EntityListNormalAppBar` to hand-maintain the number twice.
            actions: [
              if (_search.isActive)
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.tr('cancel'),
                  onPressed: _search.close,
                )
              else
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: context.tr('search_settings'),
                  onPressed: _search.open,
                ),
            ],
            bottom: _search.isActive
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(56),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SettingsSearchField(controller: _search),
                    ),
                  )
                : null,
          ),
          body: SettingsListSidebar(searchController: _search),
        ),
      ),
    );
  }
}

/// A settings group label. Deliberately label-only: the search trigger used to
/// ride in a `trailing:` slot here, which is what made it scroll away (issue
/// #42). It now lives in the pinned chrome at both widths, so both groups
/// render identically.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
