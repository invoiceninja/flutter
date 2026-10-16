import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/search_focus_registry.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/domain/plan_gate.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/settings/settings_search_catalog.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/state/settings_search_controller.dart';
import 'package:admin/ui/features/settings/views/settings_shell.dart'
    show hideSettingsListSidebar;
import 'package:admin/ui/features/settings/widgets/settings_search_result.dart';
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

  /// Held only while this pane owns its search — see [didChangeDependencies].
  SearchFocusRegistry? _searchFocus;

  @override
  void initState() {
    super.initState();
    if (widget.searchController == null) _own = SettingsSearchController();
    _search.onSubmit = _openSelected;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The wide pane owns its search, so it answers `/` too. Claimed only while
    // on stage — go_router keeps the settings branch mounted behind every
    // other one — exactly as `TokenSearchField` claims (see
    // `SearchFocusRegistry`). A host-owned controller is claimed by its host.
    final own = _own;
    if (own == null) return;
    _searchFocus ??= context.read<Services>().searchFocus;
    // A fallback: a list's own search field in the pane beside this one
    // (Payment Links) is what `/` should reach while it is on screen.
    if (TickerMode.valuesOf(context).enabled) {
      _searchFocus!.claim(
        own.focus,
        onActivate: _activateOwnSearch,
        fallback: true,
      );
    } else {
      _searchFocus!.release(own.focus);
    }
  }

  void _activateOwnSearch() {
    // The custom-design editor slides this pane off to zero width; opening a
    // search nobody can see would only steal the keyboard.
    if (hideSettingsListSidebar.value) return;
    _search.activate();
  }

  @override
  void dispose() {
    final own = _own;
    if (own != null) _searchFocus?.release(own.focus);
    if (_search.onSubmit == _openSelected) _search.onSubmit = null;
    // Only what we created — the host disposes what it created, matching how
    // `TextField` treats a passed-in controller.
    own?.dispose();
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

  /// The rows for the current query, filtered to what this user can open.
  List<SettingsSearchHit> _hitsFor(Localization l10n) => searchSettings(
    _search.query.text,
    l10n,
    scope: SettingsSearchScope.from(
      context.read<Services>().auth.session.value,
      context.read<SettingsLevelController>(),
    ),
  );

  Widget _buildResults(BuildContext context, Localization? l10n) {
    if (l10n == null) return const SizedBox.shrink();
    // Nothing typed yet: the sections themselves are the most useful list —
    // the old resting state was every field in the catalog, hundreds of rows.
    if (_search.query.text.trim().isEmpty) {
      _search.resultCount = 0;
      return _buildSectionList(context);
    }
    final session = context.read<Services>().auth.session.value;
    // Filtered at query time — not by trimming the catalog — so a gated
    // section or tab never surfaces as a dead link, while
    // `kSettingsSearchCatalog` stays complete for the consistency tests.
    // `SettingsSearchScope` is the one copy of that rule; the command palette
    // reads the same one.
    final hits = _hitsFor(l10n);
    _search.resultCount = hits.length;
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
    final tokens = context.inTheme;
    final query = _search.query.text;
    return ValueListenableBuilder<int>(
      valueListenable: _search.selected,
      builder: (context, selected, _) {
        final sel = selected.clamp(0, hits.length - 1);
        _revealSelectedRow();
        return ListView.builder(
          itemCount: hits.length,
          itemBuilder: (context, i) {
            final hit = hits[i];
            final gate = _gateLevelFor(hit.section.slug, session);
            return ListTile(
              key: i == sel ? _selectedRowKey : null,
              leading: Icon(hit.section.icon),
              title: Text.rich(
                // No base style: the span inherits the tile's own text style
                // and colour, so the selected row's title turns `accentInk`
                // with its icon.
                highlightedMatch(l10n.lookup(hit.fieldKey), query),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                settingsHitSubtitle(hit, l10n),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Same compact gate affordance the sidebar `_tile` uses — a wide
              // "Pro"/"Enterprise" text chip here overflows the ~232 px
              // settings sidebar (RenderFlex overflowed on the right).
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
                        color: tokens.ink3,
                      ),
                    ),
              // The keyboard selection. Enter opens this row; on touch it is
              // only ever the first row, which Enter on the soft keyboard
              // opens too.
              selected: i == sel,
              selectedTileColor: tokens.accentSoft,
              selectedColor: tokens.accentInk,
              iconColor: tokens.ink3,
              textColor: tokens.ink2,
              onTap: () => _openHit(hit),
            );
          },
        );
      },
    );
  }

  /// On the selected row only, so ↑ / ↓ can follow it off-screen.
  final GlobalKey _selectedRowKey = GlobalKey();

  void _revealSelectedRow() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _selectedRowKey.currentContext;
      if (row == null) return;
      Scrollable.ensureVisible(
        row,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: const Duration(milliseconds: 120),
      );
      Scrollable.ensureVisible(
        row,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        duration: const Duration(milliseconds: 120),
      );
    });
  }

  /// Enter in the field: the keyboard-selected row, which is the first one
  /// until ↑ / ↓ moves it.
  void _openSelected() {
    final l10n = Localization.of(context);
    if (l10n == null || _search.query.text.trim().isEmpty) return;
    final hits = _hitsFor(l10n);
    if (hits.isEmpty) return;
    unawaited(_openHit(hits[_search.selected.value.clamp(0, hits.length - 1)]));
  }

  Future<void> _openHit(SettingsSearchHit hit) async {
    if (!await _confirmIfDirty(context)) return;
    if (!mounted) return;
    openSettingsSearchHit(context, hit);
    _search.close();
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
        // An open search with nothing typed lists the sections too; picking
        // one is the end of that search.
        _search.close();
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
    // ↑ / ↓ walk the results and Esc closes, as in the command palette.
    // Bound on the field itself, so they only act while it has focus — a bare
    // arrow anywhere else on the page stays the page's.
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            controller.moveSelection(1),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            controller.moveSelection(-1),
        const SingleActivator(LogicalKeyboardKey.escape): controller.close,
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: TextField(
          controller: controller.query,
          focusNode: controller.focus,
          // Search queries are names and numbers, not prose — iOS
          // autocorrecting "Acme" to "Acne" mid-search is the failure.
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.search,
          // Enter opens the selected row. Keep focus here rather than take the
          // default blur: the hit navigates and closes the search, and a blur
          // first would park focus on the scope (docs/keyboard.md).
          onSubmitted: (_) => controller.submit(),
          onEditingComplete: () {},
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
/// field in its 56 px `bottom:` strip — the same shape as
/// `EntityListAppBar`'s narrow layout, a toolbar over a 56 px search row.
/// Neither may live in the scrolling body — that was issue #42.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsSearchController _search = SettingsSearchController();
  SearchFocusRegistry? _searchFocus;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This screen owns the search chrome, so it answers `/`. On stage only:
    // a covered route (a section pushed over the index) and an inactive
    // branch both mute `TickerMode`, and a resize to two panes leaves this
    // screen mounted behind the wide pane, which then answers `/` itself.
    _searchFocus ??= context.read<Services>().searchFocus;
    if (TickerMode.valuesOf(context).enabled &&
        !SettingsTwoPaneScope.of(context)) {
      _searchFocus!.claim(
        _search.focus,
        onActivate: _search.activate,
        fallback: true,
      );
    } else {
      _searchFocus!.release(_search.focus);
    }
  }

  @override
  void dispose() {
    _searchFocus?.release(_search.focus);
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
            // The same shape as `EntityListAppBar`'s narrow chrome: the
            // affordance in `actions:`, the field pinned in a 56 px row
            // under the toolbar. No `preferredSize` to keep in sync — this is
            // a real `AppBar`, so it derives `kToolbarHeight + 56` from
            // `bottom` itself. Don't wrap it in a custom
            // `PreferredSizeWidget` unless, like the list header, the row has
            // to GROW: a settings search field is one line, always.
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
