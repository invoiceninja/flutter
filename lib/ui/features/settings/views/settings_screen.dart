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
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';

// `PlanTier` (the tier surfaced on a locked sidebar row / search hit) now
// comes from `package:admin/domain/plan_gate.dart` — imported above.

/// Master list of settings sections — pure list, no `Scaffold`. Used as the
/// left pane on wide screens (mounted by `SettingsShell`) and as the body of
/// `SettingsScreen` on narrow screens. Reads the current go_router location
/// to highlight whichever top-level section is active.
///
/// The basic-settings group header carries a search icon. Tapping it swaps
/// the section list for a TextField + flat list of matching fields drawn
/// from `kSettingsSearchCatalog`.
class SettingsListSidebar extends StatefulWidget {
  const SettingsListSidebar({super.key});

  @override
  State<SettingsListSidebar> createState() => _SettingsListSidebarState();
}

class _SettingsListSidebarState extends State<SettingsListSidebar> {
  bool _searching = false;
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
    // Defer until the TextField is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _closeSearch() {
    _controller.clear();
    setState(() => _searching = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_searching) return _buildSearch(context);
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
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
            _GroupHeader(
              context.tr('basic_settings'),
              trailing: IconButton(
                icon: const Icon(Icons.search),
                tooltip: context.tr('search_settings'),
                onPressed: _openSearch,
              ),
            ),
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
    final l10n = Localization.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    onChanged: (_) => setState(() {}),
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
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: context.tr('cancel'),
                onPressed: _closeSearch,
              ),
            ],
          ),
        ),
        // Rebuild results on company switch so a now-disabled section drops
        // out of an open search without the user having to retype.
        Expanded(
          child: ValueListenableBuilder<AuthSession?>(
            valueListenable: context.read<Services>().auth.session,
            builder: (context, _, _) => _buildResults(context, l10n),
          ),
        ),
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
    // enforces parity). The cascade gate mirrors `_buildList`'s `inScope`:
    // at client/group scope, a company-only page reached through search
    // renders under the "editing client X" banner with checked override
    // boxes wired to the COMPANY draft — the user's "per-client override"
    // edit would silently change the company-wide default. The hosted gate is
    // per-FIELD, not per-section: Account Management is always visible, but
    // its Referral Program tab isn't (issue #27).
    final hits = searchSettings(_controller.text, l10n)
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
            _closeSearch();
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

/// Narrow-only route target for `/settings`. On wide screens the shell shows
/// `SettingsListSidebar` directly in the left pane, so this screen never gets
/// rendered — but it remains the route's `builder` so the back-button on
/// narrow lands on the list cleanly.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final globalNav = Breakpoints.isGlobalNavVisible(context);
    return Scaffold(
      drawer: globalNav ? null : const AppDrawer(),
      appBar: AppBar(
        title: Text(context.tr('settings')),
        leading: globalNav ? null : const DrawerHamburger(),
        automaticallyImplyLeading: !globalNav,
      ),
      body: const SettingsListSidebar(),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.label, {this.trailing});
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontWeight: FontWeight.w600,
    );
    if (trailing == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(label, style: style),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          trailing!,
        ],
      ),
    );
  }
}
