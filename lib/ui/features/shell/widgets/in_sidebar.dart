import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/models/domain/saved_view.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart'
    show goToCreateRoute;
import 'package:admin/ui/core/list/saved_view_dialogs.dart';
import 'package:admin/ui/core/list/saved_view_icons.dart';
import 'package:admin/ui/features/shell/widgets/command_palette.dart';
import 'package:admin/ui/features/shell/widgets/company_switcher_button.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_footer_actions.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_nav_item.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_section_header.dart';
import 'package:admin/ui/features/shell/widgets/trial_footer.dart';
import 'package:admin/ui/features/shell/widgets/window_caption_strip.dart';

/// Width of the persistent sidebar used by `ScaffoldWithNav` on wide
/// layouts. Exposed so overlay-based widgets (e.g. the date-range picker
/// popover) can reserve this width and not render beneath the rail.
const double kInSidebarWidth = 232.0;

/// Collapsed width — matches Material's standard `NavigationRail` width,
/// wide enough for a centered 18-px icon and a 44-ish-px tap target.
const double kInSidebarCollapsedWidth = 64.0;

/// 232 px sidebar used in the wide (desktop / tablet) layout of the
/// authenticated shell.
///
/// The workspace section is derived from `services.entityRegistry.sidebarTop`
/// — adding an entity is one registry entry. The fixed nav rows (Dashboard,
/// Settings, Outbox) stay declared inline here because they're features,
/// not entities; their branch indices come from `EntityRegistry.branchOrder`
/// (lookup via [_findFixedBranch]).
///
/// On the wide layout the user can collapse it to [kInSidebarCollapsedWidth]
/// via the bottom toggle button; the choice is owned by
/// `Services.sidebar` and persists across restarts. Inside `AppDrawer` the
/// collapse mode never engages — the drawer passes its own `width` and the
/// `ValueListenableBuilder` simply doesn't constrain anything in that case.
class InSidebar extends StatefulWidget {
  const InSidebar({
    required this.currentBranch,
    required this.onSelectBranch,
    this.width = kInSidebarWidth,
    this.onBeforeCompanyPicker,
    super.key,
  });

  final int currentBranch;
  final ValueChanged<int> onSelectBranch;

  /// Fixed width of the sidebar. The persistent desktop rail uses the
  /// default 232 px; `AppDrawer` passes `null` so the sidebar fills the
  /// drawer's own (wider) width.
  final double? width;

  /// Fires before the company picker opens (when the user taps the
  /// switcher header). Used by `AppDrawer` to pop itself first so the
  /// picker doesn't stack on top of an open drawer.
  final VoidCallback? onBeforeCompanyPicker;

  @override
  State<InSidebar> createState() => _InSidebarState();
}

class _InSidebarState extends State<InSidebar> {
  // --- Cached Drift watch streams ------------------------------------------
  //
  // The streams the sidebar listens to (`watchActiveView`, `watchAll`, and
  // every entity / outbox badge `.watch()`) used to be rebuilt on *every*
  // `build()` — including the collapse toggle — which tore down and
  // re-subscribed each `StreamBuilder` (waiting-state flicker, the
  // saved-views section collapsing to nothing mid-animation, and N+2
  // redundant DB queries per click).
  //
  // They're memoized here behind [_CachedStream], which owns a broadcast
  // controller fed by a single source subscription so the underlying Drift
  // query is deterministically cancelled when a generation is replaced or
  // the State is disposed. (A bare `.asBroadcastStream()` would *not*
  // cancel its single-subscription source when listeners drop, leaking a
  // live Drift query per dropped generation.)
  //
  // Keys are split by what each slot actually depends on so unrelated
  // navigation doesn't churn streams (which would re-introduce the
  // saved-views/badges blink on every cross-entity nav):
  //   * `_activeView`  → (companyId, active branch entity type)
  //   * `_savedViews`  → companyId only
  //   * `_badgeStreams`→ companyId only (entries are per-key & lazy)
  // `enabledModules` / `view_reports` only gate *which* rows call
  // `_cachedBadge` in `_buildItems`; they are not stream-cache keys.
  String? _avCompanyId;
  EntityType? _avEntityType;
  String? _svCompanyId;

  _CachedStream<SavedView?>? _activeView;
  _CachedStream<List<SavedView>>? _savedViews;
  final Map<Object, _CachedStream<int>> _badgeStreams =
      <Object, _CachedStream<int>>{};

  /// The entity owning the active branch, or `null` for a fixed branch
  /// (Dashboard / Settings / Outbox / Reports). Drives the active-view
  /// highlight scope.
  EntityType? _currentEntityType(EntityRegistry registry) {
    final order = registry.branchOrder;
    final b = widget.currentBranch;
    if (b < 0 || b >= order.length) return null;
    final spec = order[b];
    return spec is EntityBranch ? spec.type : null;
  }

  /// Stream of the saved view currently reflected by the list state of the
  /// active branch's entity (or a constant `null` on a fixed branch). The
  /// sidebar highlights that row instead of the entity row.
  Stream<SavedView?> _buildActiveViewStream(
    Services services,
    String companyId,
  ) {
    final entityType = _currentEntityType(services.entityRegistry);
    if (entityType == null) return Stream<SavedView?>.value(null);
    return services.savedViews.watchActiveView(
      companyId: companyId,
      entityType: entityType,
    );
  }

  /// Rebuild only the cached slots whose inputs changed. Called during
  /// `build` inside the session `ValueListenableBuilder` — pure
  /// memoization keyed on its inputs, so it never calls `setState`. Old
  /// generations are closed (Drift query cancelled) before replacement.
  void _syncStreams(Services services, AuthSession session) {
    final companyId = session.currentCompanyId;
    final entityType = _currentEntityType(services.entityRegistry);

    // active-view: company + active branch entity type.
    if (companyId != _avCompanyId || entityType != _avEntityType) {
      _avCompanyId = companyId;
      _avEntityType = entityType;
      _activeView?.close();
      _activeView = _CachedStream<SavedView?>(
        _buildActiveViewStream(services, companyId),
      );
    }

    // saved-views + badges: company only.
    if (companyId != _svCompanyId) {
      _svCompanyId = companyId;
      _savedViews?.close();
      _savedViews = _CachedStream<List<SavedView>>(
        services.savedViews.watchAll(companyId),
      );
      for (final s in _badgeStreams.values) {
        s.close();
      }
      _badgeStreams.clear();
    }
  }

  /// Memoize a badge stream within the current company generation. Cleared
  /// (and closed) wholesale by [_syncStreams] when the company changes.
  Stream<int> _cachedBadge(Object key, Stream<int> Function() factory) =>
      _badgeStreams
          .putIfAbsent(key, () => _CachedStream<int>(factory()))
          .stream;

  @override
  void dispose() {
    _activeView?.close();
    _savedViews?.close();
    for (final s in _badgeStreams.values) {
      s.close();
    }
    _badgeStreams.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final services = context.read<Services>();
    return ValueListenableBuilder<AuthSession?>(
      valueListenable: services.auth.session,
      builder: (context, session, _) {
        if (session == null) return const SizedBox.shrink();
        _syncStreams(services, session);
        return ValueListenableBuilder<bool>(
          valueListenable: services.sidebar,
          builder: (context, collapsedPref, _) {
            // The drawer passes `width: null` to fill its own container —
            // the collapse toggle is wide-layout-only, so ignore the
            // preference when there's no fixed width.
            final canCollapse = widget.width != null;
            final collapsed = canCollapse && collapsedPref;
            final effectiveWidth = canCollapse
                ? (collapsed ? kInSidebarCollapsedWidth : kInSidebarWidth)
                : null;
            // SafeArea (top-only): both hosts reach the window's top edge
            // with no AppBar — the mobile drawer (Flutter's `Drawer` adds no
            // inset of its own) and the iPad persistent rail (Positioned at
            // top: 0). The surface decoration below still paints behind the
            // status bar. Horizontal insets are deliberately OFF: SafeArea
            // applies *window-level* padding regardless of widget position,
            // and the rail / drawer widths are pinned (232 / 64 / 280) — on
            // iPhone landscape (~59px inset per side, and landscape widths
            // are ≥600 so the rail shows) the defaults would crush the
            // collapsed 64px rail to zero usable width. Bottom is already
            // handled by SidebarFooterActions' own SafeArea(top: false). On
            // macOS every inset is 0, so desktop layout is unchanged.
            final content = SafeArea(
              left: false,
              right: false,
              bottom: false,
              child: Column(
                children: [
                  // Desktop hidden-title-bar caption strip — macOS today:
                  // reserves space for the floating traffic lights and drags
                  // the window. Persistent sidebar only — the mobile drawer
                  // (width == null) sits below the narrow-layout strip, so it
                  // needs none.
                  if (widget.width != null)
                    WindowCaptionStrip(controller: services.screenshotWindow),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: CompanySwitcherButton(
                      session: session,
                      onBeforeOpen: widget.onBeforeCompanyPicker,
                      compact: collapsed,
                    ),
                  ),
                  Container(height: 1, color: tokens.border),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                      child: StreamBuilder<SavedView?>(
                        stream: _activeView?.stream,
                        builder: (context, snap) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildItems(
                            context,
                            services,
                            session.currentCompanyId,
                            compact: collapsed,
                            activeViewId: snap.data?.id,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(height: 1, color: tokens.border),
                  SidebarFooterActions(
                    compact: collapsed,
                    showCollapseToggle: canCollapse,
                  ),
                  TrialFooter(compact: collapsed),
                ],
              ),
            );
            // RepaintBoundary isolates the 150 ms width-tween repaint from
            // the content area (the Stack sibling in scaffold_with_nav).
            return RepaintBoundary(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                width: effectiveWidth,
                decoration: BoxDecoration(
                  color: tokens.surface,
                  border: Border(right: BorderSide(color: tokens.border)),
                ),
                // The AnimatedContainer box + ClipRect animate the visible
                // reveal; OverflowBox pins the content to the *destination*
                // width (`effectiveWidth` — snapped, only changes when the
                // collapse bool toggles) so the rows lay out once at their
                // final width with the matching `compact`, never at an
                // intermediate width. Without this the `compact:false` rows
                // re-layout every tween frame at a narrower width and the
                // RenderFlex reports a (ClipRect-hidden but still logged)
                // right overflow. `width == null` (AppDrawer) keeps the
                // original fills-the-drawer behaviour untouched.
                child: ClipRect(
                  child: effectiveWidth == null
                      ? content
                      : OverflowBox(
                          alignment: Alignment.centerLeft,
                          minWidth: effectiveWidth,
                          maxWidth: effectiveWidth,
                          child: content,
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildItems(
    BuildContext context,
    Services services,
    String companyId, {
    required bool compact,
    required String? activeViewId,
  }) {
    final registry = services.entityRegistry;
    // Modules disabled for the active company hide their sidebar row entirely
    // (mirrors admin-portal — removed, not greyed). Reactive via the outer
    // `ValueListenableBuilder<AuthSession?>` like the `view_reports` gate below.
    final enabledModules =
        services.auth.session.value?.currentCompany?.enabledModules ?? 0;
    final widgets = <Widget>[
      // Fixed: Dashboard. Branch index comes from the registry's branchOrder
      // so reordering the router doesn't desync the sidebar.
      _fixedNav(
        context,
        services,
        compact: compact,
        labelKey: 'dashboard',
        icon: Icons.dashboard_outlined,
        kind: FixedBranchKind.dashboard,
        trailingHover: const _SidebarSearchButton(),
      ),
      // Entities — Clients, Products, and the per-module entities. Rows whose
      // module is disabled for this company are omitted entirely; client /
      // product (and any always-on entity) always pass. Order driven by
      // sidebarOrder.
      for (final h in registry.sidebarTop)
        if (isEntityModuleEnabledForCompany(h.type, enabledModules))
          _entityNav(
            context,
            services,
            h,
            companyId,
            compact: compact,
            activeViewId: activeViewId,
          ),
      // Reports — hidden when the active company lacks `view_reports`.
      // Rendered after the entity list to match the React app's order
      // (Dashboard → entities → Reports → Settings). Reactivity comes from
      // the outer `ValueListenableBuilder<AuthSession?>` on
      // `services.auth.session` (see `build` above) — when the session
      // changes (sign-out / company switch / permission update),
      // `_buildItems` is invoked fresh and this check re-evaluates.
      // The branch index lives at the end of `kBranchOrder`; visual order
      // here is independent of branch index.
      if (services.auth.session.value?.currentCompany?.can('view_reports') ??
          false)
        _fixedNav(
          context,
          services,
          compact: compact,
          labelKey: 'reports',
          icon: Icons.bar_chart_outlined,
          kind: FixedBranchKind.reports,
          // Discoverability parity with the settings sidebar: Reports is Pro
          // on hosted, so show a lock before the user taps in (trial-aware;
          // no lock once they have access).
          trailing:
              (services.auth.session.value?.isHosted ?? false) &&
                  !(services.auth.session.value?.hasProAccess ?? false)
              ? Tooltip(
                  message: context.tr('pro_plan'),
                  child: Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: context.inTheme.ink3,
                  ),
                )
              : null,
        ),
      // Saved views — reactive section that disappears when empty. Owns its
      // own trailing spacer so the Reports→Settings gap stays uniform with
      // the rest of the sidebar when there are no saved views.
      _SavedViewsSection(
        companyId: companyId,
        currentBranch: widget.currentBranch,
        onSelectBranch: widget.onSelectBranch,
        compact: compact,
        activeViewId: activeViewId,
        savedViewsStream: _savedViews!.stream,
      ),
      _fixedNav(
        context,
        services,
        compact: compact,
        labelKey: 'settings',
        icon: Icons.settings_outlined,
        kind: FixedBranchKind.settings,
      ),
      _fixedNav(
        context,
        services,
        compact: compact,
        labelKey: 'outbox',
        icon: Icons.outbox_outlined,
        kind: FixedBranchKind.outbox,
        badgeStream: (s, c) =>
            _combineOutboxCounts(s.watchOutboxPending(c), s.watchOutboxDead(c)),
        hideWhenZero: true,
      ),
    ];
    return widgets;
  }

  Widget _entityNav(
    BuildContext context,
    Services services,
    EntityHandlers handlers,
    String companyId, {
    required bool compact,
    required String? activeViewId,
  }) {
    final branch = services.entityRegistry.branchIndexFor(handlers.type);
    // The current-branch entity row yields its highlight to the active
    // saved view when one matches the live list state. Non-current-branch
    // rows are never active regardless.
    final isActive =
        branch != null &&
        branch == widget.currentBranch &&
        activeViewId == null;
    final label = context.tr(handlers.effectiveLabelKey);
    // Hover affordance — `+` shortcut to the entity's /new route. Only
    // surfaces on rows that have a `newRoute` configured AND in expanded
    // mode (compact rail has no horizontal room).
    final Widget? hoverAdd = (!compact && handlers.newRoute != null)
        ? _HoverAddButton(route: handlers.newRoute!)
        : null;
    final onTap = handlers.disabled || branch == null
        ? null
        : () async {
            // Dirty-form gate first — `clearAppliedViewFilters` mutates
            // nav_state, so don't run it if the user cancels out. Mirrors
            // `_SavedViewsSection._onTap`.
            final guard = services.unsavedChangesGuard;
            if (!await guard.confirmIfDirty(context)) return;
            if (!context.mounted) return;
            // No-op unless the entity's live list state currently reflects
            // a saved view; in that case clears the slot so the list
            // reverts to default and the highlight returns to this row.
            await services.savedViews.clearAppliedViewFilters(
              companyId: companyId,
              entityType: handlers.type,
            );
            if (!context.mounted) return;
            widget.onSelectBranch(branch);
          };
    final tile = SidebarNavItem(
      label: label,
      icon: handlers.effectiveOutlinedIcon,
      active: isActive,
      disabled: handlers.disabled,
      compact: compact,
      onTap: onTap,
      trailingHover: hoverAdd,
      leaderKey: branch == null ? null : _entityLeaderKey(handlers.type),
    );
    final badge = handlers.badgeStream;
    if (badge == null) return tile;
    return StreamBuilder<int>(
      stream: _cachedBadge(handlers.type, () => badge(services, companyId)),
      builder: (context, snap) => SidebarNavItem(
        label: label,
        icon: handlers.effectiveOutlinedIcon,
        active: isActive,
        disabled: handlers.disabled,
        compact: compact,
        count: snap.data,
        onTap: onTap,
        trailingHover: hoverAdd,
        leaderKey: branch == null ? null : _entityLeaderKey(handlers.type),
      ),
    );
  }

  Widget _fixedNav(
    BuildContext context,
    Services services, {
    required bool compact,
    required String labelKey,
    required IconData icon,
    required FixedBranchKind kind,
    Stream<int> Function(Services, String)? badgeStream,
    bool hideWhenZero = false,
    Widget? trailingHover,
    Widget? trailing,
  }) {
    final branch = _findFixedBranch(services.entityRegistry, kind);
    final isActive = branch != null && branch == widget.currentBranch;
    final label = context.tr(labelKey);
    Widget tile({int? count}) => SidebarNavItem(
      label: label,
      icon: icon,
      active: isActive,
      compact: compact,
      count: count,
      trailing: trailing,
      trailingHover: trailingHover,
      onTap: branch == null ? null : () => widget.onSelectBranch(branch),
      leaderKey: branch == null ? null : _fixedLeaderKey(kind),
    );
    if (badgeStream == null) return tile();
    final companyId = services.auth.session.value?.currentCompanyId ?? '';
    if (companyId.isEmpty) return tile();
    return StreamBuilder<int>(
      stream: _cachedBadge(kind, () => badgeStream(services, companyId)),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        if (hideWhenZero && count == 0) return const SizedBox.shrink();
        return tile(count: count);
      },
    );
  }
}

/// Owns a broadcast controller fed by a single subscription to a
/// (single-subscription) source stream, so the sidebar's stream cache can
/// deterministically tear the source down — `Stream.asBroadcastStream()`
/// does not cancel its source when listeners drop, which would leak a live
/// Drift query per replaced cache generation.
class _CachedStream<T> {
  _CachedStream(Stream<T> source)
    : _controller = StreamController<T>.broadcast() {
    _sub = source.listen(
      _controller.add,
      onError: _controller.addError,
      onDone: _controller.close,
    );
  }

  final StreamController<T> _controller;
  late final StreamSubscription<T> _sub;

  Stream<T> get stream => _controller.stream;

  void close() {
    unawaited(_sub.cancel());
    unawaited(_controller.close());
  }
}

/// The `G`-leader second key for the sidebar entity rows that have one
/// (mirrors `_leaderTarget` in scaffold_with_nav.dart). Null → no leader
/// jump, so the row shows no shortcut hint.
String? _entityLeaderKey(EntityType type) {
  switch (type) {
    case EntityType.client:
      return 'C';
    case EntityType.invoice:
      return 'I';
    case EntityType.product:
      return 'P';
    case EntityType.task:
      return 'T';
    default:
      return null;
  }
}

/// The `G`-leader second key for the fixed sidebar rows that have one.
String? _fixedLeaderKey(FixedBranchKind kind) {
  switch (kind) {
    case FixedBranchKind.dashboard:
      return 'D';
    case FixedBranchKind.settings:
      return 'S';
    default:
      return null;
  }
}

int? _findFixedBranch(EntityRegistry registry, FixedBranchKind kind) {
  final branches = registry.branchOrder;
  for (var i = 0; i < branches.length; i++) {
    final spec = branches[i];
    if (spec is FixedBranch && spec.kind == kind) return i;
  }
  return null;
}

/// Hover-revealed `+` shortcut that jumps to an entity's `/new` route.
/// Runs the global dirty-form guard first so unsaved edits aren't silently
/// discarded — mirrors the saved-view sidebar tap and `_goBranch`.
class _HoverAddButton extends StatelessWidget {
  const _HoverAddButton({required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('add_new'),
      iconSize: 16,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 18, height: 18),
      icon: Icon(Icons.add_circle_outline, color: context.inTheme.ink3),
      onPressed: () async {
        final guard = context.read<Services>().unsavedChangesGuard;
        if (!await guard.confirmIfDirty(context)) return;
        if (!context.mounted) return;
        goToCreateRoute(context, route);
      },
    );
  }
}

/// Hover-revealed search affordance on the right of the Dashboard row
/// (desktop, expanded rail only — mirrors the entity-row `+` button).
/// Opens the command palette — the same target as the `⌘/` shortcut.
class _SidebarSearchButton extends StatelessWidget {
  const _SidebarSearchButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('search'),
      iconSize: 16,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 18, height: 18),
      icon: Icon(Icons.search, color: context.inTheme.ink3),
      onPressed: () => showCommandPalette(context),
    );
  }
}

/// Merge the pending and dead outbox-count streams. Emits the sum on every
/// emission from either source — the user wants one badge that reflects
/// total mutations awaiting action.
Stream<int> _combineOutboxCounts(Stream<int> pending, Stream<int> dead) async* {
  int p = 0;
  int d = 0;
  final controller = StreamController<int>();
  final subP = pending.listen((v) {
    p = v;
    controller.add(p + d);
  });
  final subD = dead.listen((v) {
    d = v;
    controller.add(p + d);
  });
  try {
    yield* controller.stream;
  } finally {
    await subP.cancel();
    await subD.cancel();
    await controller.close();
  }
}

/// "Saved" section. Driven by `services.savedViews.watchAll` — items group
/// by entity (clients first, then products) and sort alphabetically within
/// each group. When the user has no saved views yet, render the section
/// header + a small muted hint so the feature is discoverable rather than
/// invisible.
class _SavedViewsSection extends StatelessWidget {
  const _SavedViewsSection({
    required this.companyId,
    required this.currentBranch,
    required this.onSelectBranch,
    required this.compact,
    required this.activeViewId,
    required this.savedViewsStream,
  });

  final String companyId;
  final int currentBranch;
  final ValueChanged<int> onSelectBranch;
  final bool compact;

  /// Id of the saved view whose snapshot currently matches the live list
  /// state of the active branch's entity (`null` when none / fixed branch).
  final String? activeViewId;

  /// Cached (broadcast) `watchAll` stream owned by `_InSidebarState` — kept
  /// stable across collapse toggles so this section doesn't blink to
  /// `SizedBox.shrink()` and back mid-animation.
  final Stream<List<SavedView>> savedViewsStream;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SavedView>>(
      stream: savedViewsStream,
      builder: (context, snap) {
        final views = snap.data ?? const <SavedView>[];
        if (views.isEmpty) {
          // Section disappears entirely when there's nothing to show — the
          // toolbar bookmark button is the discovery surface.
          return const SizedBox.shrink();
        }
        // Stable group order: list every entity's views together. Ordering by
        // entity then name keeps the rail scannable as the user accumulates
        // views.
        final ordered = [...views]
          ..sort((a, b) {
            final byEntity = a.entityType.index.compareTo(b.entityType.index);
            if (byEntity != 0) return byEntity;
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          });
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SidebarSectionHeader(
              compact ? null : context.tr('section_saved'),
              compact: compact,
            ),
            for (final view in ordered)
              _SavedViewNavItem(
                view: view,
                compact: compact,
                active: view.id == activeViewId,
                onTap: () => _onTap(context, view),
              ),
            // Trailing spacer separating the saved list from the bottom
            // group (Settings / Outbox). Lives inside the section so when
            // there are no saved views the whole group collapses to
            // SizedBox.shrink() and the Reports→Settings gap matches the
            // gap between all other adjacent rows.
            const SidebarSectionHeader(null),
          ],
        );
      },
    );
  }

  Future<void> _onTap(BuildContext context, SavedView view) async {
    final services = context.read<Services>();
    // Dirty-form gate first — `apply` would otherwise mutate
    // `nav_state.filters_json` even when the user cancels the upcoming
    // branch switch from the discard dialog.
    final guard = services.unsavedChangesGuard;
    if (!await guard.confirmIfDirty(context)) return;
    if (!context.mounted) return;
    try {
      await services.savedViews.apply(view.id);
    } catch (_) {
      // Apply is best-effort; swallow and let the user retry.
      return;
    }
    if (!context.mounted) return;
    final branch = services.entityRegistry.branchIndexFor(view.entityType);
    if (branch != null && branch != currentBranch) {
      onSelectBranch(branch);
    }
  }
}

enum _SavedViewMenuAction { chooseIcon, rename, delete }

List<PopupMenuEntry<_SavedViewMenuAction>> _savedViewMenuItems(
  BuildContext context,
) => [
  PopupMenuItem(
    value: _SavedViewMenuAction.chooseIcon,
    child: Text(context.tr('choose_icon')),
  ),
  PopupMenuItem(
    value: _SavedViewMenuAction.rename,
    child: Text(context.tr('rename')),
  ),
  PopupMenuItem(
    value: _SavedViewMenuAction.delete,
    child: Text(context.tr('delete')),
  ),
];

void _handleSavedViewMenuAction(
  BuildContext context,
  SavedView view,
  _SavedViewMenuAction action,
) {
  switch (action) {
    case _SavedViewMenuAction.chooseIcon:
      unawaited(showChooseSavedViewIconDialog(context, view));
    case _SavedViewMenuAction.rename:
      unawaited(showRenameSavedViewDialog(context, view));
    case _SavedViewMenuAction.delete:
      unawaited(showDeleteSavedViewDialog(context, view));
  }
}

/// Single menu implementation shared by all three triggers (the `⋮` button,
/// row right-click, row long-press). `showMenu` renders a correctly-sized
/// overlay — unlike `PopupMenuButton.constraints`, which sizes the *menu*
/// and clipped it to the button's footprint.
Future<void> _openSavedViewMenu(
  BuildContext context,
  SavedView view,
  RelativeRect position,
) async {
  final action = await showMenu<_SavedViewMenuAction>(
    context: context,
    position: position,
    items: _savedViewMenuItems(context),
  );
  if (action != null && context.mounted) {
    _handleSavedViewMenuAction(context, view, action);
  }
}

/// A saved-view sidebar row. Wraps [SidebarNavItem] so the row's curated
/// icon shows (also differentiating the collapsed rail, where every saved
/// view used to be an identical bookmark), and exposes the context menu via
/// three reinforcing affordances: an always-visible (but subdued) `⋮`
/// button, right-click, and long-press — so it's discoverable and
/// keyboard-reachable, unlike the old hover-only version.
class _SavedViewNavItem extends StatelessWidget {
  const _SavedViewNavItem({
    required this.view,
    required this.compact,
    required this.active,
    required this.onTap,
  });

  final SavedView view;
  final bool compact;
  final bool active;
  final VoidCallback onTap;

  void _showMenuAt(BuildContext context, Offset globalPosition) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    unawaited(
      _openSavedViewMenu(
        context,
        view,
        RelativeRect.fromRect(
          globalPosition & const Size(40, 40),
          Offset.zero & overlay.size,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = SidebarNavItem(
      label: view.name,
      icon: savedViewIcon(view.iconKey),
      active: active,
      compact: compact,
      onTap: onTap,
      // Always-visible (not hover-gated) so the menu is discoverable; the
      // collapsed rail has no room for it (handled by SidebarNavItem).
      trailing: compact ? null : _SavedViewMenuButton(view: view),
    );
    if (compact) return item;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (d) => _showMenuAt(context, d.globalPosition),
      onLongPressStart: (d) => _showMenuAt(context, d.globalPosition),
      child: item,
    );
  }
}

/// Always-visible (subdued) `⋮` on saved-view rows opening the Choose icon /
/// Rename / Delete menu. An `IconButton` (not `PopupMenuButton`): its
/// `constraints` sizes the *button* so it fits the 18-px row exactly like
/// the peer `_HoverAddButton`, and it opens the menu via the shared
/// `showMenu` path (correctly sized — `PopupMenuButton.constraints` sizes
/// the menu and clipped it). Still keyboard-focusable.
class _SavedViewMenuButton extends StatelessWidget {
  const _SavedViewMenuButton({required this.view});

  final SavedView view;

  void _open(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final rect = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    unawaited(_openSavedViewMenu(context, view, rect));
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.tr('view_options'),
      iconSize: 16,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      // `constraints` here sizes the IconButton itself — the wide-mode
      // sidebar row body is wrapped in SizedBox(height: 18), so match the
      // proven `_HoverAddButton` footprint. `ink3` is the established weight
      // for sidebar trailing affordances (the entity-row `+`).
      constraints: const BoxConstraints.tightFor(width: 18, height: 18),
      icon: Icon(Icons.more_vert, color: context.inTheme.ink3),
      onPressed: () => _open(context),
    );
  }
}
