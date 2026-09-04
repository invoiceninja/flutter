import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart' show CompanyRow;
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/models/domain/saved_view.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/domain/sidebar_badge_modes.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart'
    show goToCreateRoute;
import 'package:admin/ui/core/list/saved_view_dialogs.dart';
import 'package:admin/ui/core/list/saved_view_icons.dart';
import 'package:admin/ui/features/settings/settings_actions.dart';
import 'package:admin/ui/features/shell/widgets/command_palette.dart';
import 'package:admin/ui/features/shell/widgets/nav_history_buttons.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_footer_actions.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_nav_item.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_search_box.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_sync_button.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_header.dart';
import 'package:admin/ui/features/shell/widgets/show_company_picker.dart';
import 'package:admin/ui/features/shell/widgets/sidebar_section_header.dart';
import 'package:admin/ui/features/shell/widgets/trial_footer.dart';
import 'package:admin/ui/features/shell/widgets/white_label_footer.dart';
import 'package:admin/ui/features/shell/widgets/window_caption_strip.dart';

/// Width of the persistent sidebar used by `ScaffoldWithNav` on wide
/// layouts. Exposed so overlay-based widgets (e.g. the date-range picker
/// popover) can reserve this width and not render beneath the rail.
const double kInSidebarWidth = 232.0;

/// Collapsed width — matches Material's standard `NavigationRail` width,
/// wide enough for a centered 18-px icon and a 44-ish-px tap target.
const double kInSidebarCollapsedWidth = 64.0;

/// Sidebar height below which the footer's white-label upsell card is dropped
/// (invoiceninja/flutter#124). A phone in landscape is a ~890x412 window, and
/// the sidebar's fixed chrome already costs ~243 px of that — header 111,
/// footer 132 — leaving the nav list about three and a half of its ~12 rows.
/// The card is ~49 px of that footer, so dropping it is worth roughly one row.
///
/// 480 is Material 3's compact-height window class, and it clears the whole
/// reported population: every phone **in landscape** is below it (iPhone SE
/// 375, Pixel 8 412, iPhone 15 Pro Max 430). Above it the band is mostly
/// deliberately-short desktop windows (a half-screen 1080p snap is 1920x540),
/// which is why the gate also requires touch — see [sidebarShowsUpsell].
///
/// Deliberately local rather than a `Breakpoints` member: `Breakpoints` holds
/// *width* thresholds, so `height < wide` would read as nonsense at the call
/// site, and there is exactly one call site. Nothing is stranded by the gate —
/// Settings -> Account Management -> Plan renders the same offer through
/// `showWhiteLabelCard`.
const double _kUpsellMinHeight = 480.0;

/// Whether the sidebar footer mounts the white-label upsell card.
///
/// Extracted as a pure function so the threshold is testable without pumping
/// `InSidebar` — which deadlocks (`sidebar_search_box_test.dart` records why).
/// Pinning the gate by scanning the source for its expression is worse than
/// useless: it goes red on a rename that changes nothing, which is an incident
/// `sidebar_search_box_test.dart` already has a comment about.
///
/// [touch] is `Env.isTouchPrimary` and is what keeps a *pointer* window that
/// merely happens to be short — a half-screen desktop snap — from losing a CTA
/// it has room for. It is not a proxy for "handset": `Env.isTouchPrimary` is
/// true for every `TargetPlatform.android`, which includes ChromeOS containers,
/// Samsung DeX and Android desktop mode, so a short window there does lose the
/// card. Accepted: those are rare, resizable, and the offer is still one click
/// away in Settings -> Account Management -> Plan. The converse gap is Android
/// vertical split-screen, which can hand a real phone ~450-540 px and so keep
/// the card on a viewport this rule would rather not have — also accepted, for
/// the same reason.
///
/// [height] is the **window** height (`MediaQuery.sizeOf`), not the sidebar's
/// own box. They agree on the rail; in the drawer host the offline banner and
/// the debug panel can make the box shorter. Measuring the box instead would
/// mean a `LayoutBuilder`, and the rail's box shrinks by `viewInsets.bottom`
/// when a keyboard opens in the *content* pane — which would drop and restore
/// the card mid-typing. The window is the stabler of the two wrong answers.
@visibleForTesting
bool sidebarShowsUpsell({required bool touch, required double height}) =>
    !(touch && height < _kUpsellMinHeight);

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
    this.onBeforeModal,
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
  final VoidCallback? onBeforeModal;

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

  /// The active company row. Only the product stock counters care about it
  /// (`track_inventory` gates whether those modes are offered at all), but the
  /// menu has to know before it renders — so it rides the same per-company
  /// cached-stream generation as the saved views.
  _CachedStream<CompanyRow?>? _company;
  final Map<Object, _CachedStream<int>> _badgeStreams =
      <Object, _CachedStream<int>>{};

  /// Last-seen counter mode per entity, so [_syncStreams] can tear down the
  /// stream a row just switched away from. Only entities that have rendered a
  /// badge appear here.
  final Map<EntityType, String> _badgeModes = <EntityType, String>{};

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
      _company?.close();
      _company = _CachedStream<CompanyRow?>(
        services.db.companiesDao.watchById(companyId),
      );
      for (final s in _badgeStreams.values) {
        s.close();
      }
      _badgeStreams.clear();
      _badgeModes.clear();
    }
  }

  /// Record the counter mode [type]'s row is rendering with, and tear down the
  /// stream it just switched away from.
  ///
  /// Badge streams are keyed by `(entity, mode)`, so a switch misses the cache
  /// and builds a fresh query — but without this the superseded entry would
  /// keep a live Drift query open for the rest of the session. Called from
  /// `_entityNav` rather than [_syncStreams] so it compares against the mode
  /// actually rendered (which may have fallen back to `total` because the
  /// stored one isn't offered for this company), not a freshly-resolved one.
  void _noteBadgeMode(EntityType type, String modeId) {
    final previous = _badgeModes[type];
    if (previous == modeId) return;
    if (previous != null) _badgeStreams.remove((type, previous))?.close();
    _badgeModes[type] = modeId;
  }

  /// Memoize a badge stream within the current company generation. Cleared
  /// (and closed) wholesale by [_syncStreams] when the company changes, and
  /// per-entity when its counter mode changes.
  Stream<int> _cachedBadge(Object key, Stream<int> Function() factory) =>
      _badgeStreams
          .putIfAbsent(key, () => _CachedStream<int>(factory()))
          .stream;

  @override
  void dispose() {
    _activeView?.close();
    _savedViews?.close();
    _company?.close();
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
            // Touch pointers get bigger hit areas throughout the sidebar —
            // both hosts (the 280-px drawer and the persistent rail a tablet
            // shows at >=600 px). Read once and threaded like `compact` so the
            // leaf widgets stay pure and directly pumpable in tests.
            final touch = Env.isTouchPrimary;
            // See [sidebarShowsUpsell] for why this is the window height and
            // why it is gated on touch.
            final showsUpsell = sidebarShowsUpsell(
              touch: touch,
              height: MediaQuery.sizeOf(context).height,
            );
            final collapsed = canCollapse && collapsedPref;
            final effectiveWidth = canCollapse
                ? (collapsed ? kInSidebarCollapsedWidth : kInSidebarWidth)
                : null;
            // Issue #104: a single-company account has nothing to switch
            // *between*, so in the drawer the header row is pure overhead —
            // Sync moves up into the toolbar row and the switcher moves into
            // the footer, handing the nav list ~54 px (about 1.2 rows at the
            // 44-px touch pitch) back. That is the *net*: the block removed
            // below is 8 + 46 + 8 = 62, of which 8 comes straight back as the
            // toolbar row's new bottom inset. 46, not 44, because
            // `CompanySwitcherButton`'s `Container` folds its 1-px border into
            // its 8-px padding, so the switcher is 28 + 2x9 and its
            // `minHeight: 44` never bites.
            //
            // Drawer only (`!canCollapse`, so `collapsed` can never be true
            // here). The 232-px rail cannot absorb it, though **not** because
            // anything overflows — an earlier version of this comment said so
            // and was wrong. Its content box is 208 and the fixed children are
            // 88 + 4 + 44 = 136, so the `Expanded` search box gets 72, well
            // over its 44 minimum. What breaks is the *label*: 72 less the
            // box's own 38 px of border/padding/icon/gap leaves 34 px for a
            // ~42-px "Search", so it ellipsizes at 1.0x text scale, before a
            // user has changed anything. The rail is also always on screen and
            // never scrolled past, so it has none of the drawer's pressure.
            //
            // `<= 1` deliberately covers the empty roster too. Issue #16's
            // dead end was a roster that had wrongly *shrunk*, and the footer
            // entry keeps `CompanyPicker` — the app's only "New company", and
            // its Sign out — reachable in exactly that state.
            final hideHeader = !canCollapse && session.companies.length <= 1;
            // One callback, two possible mount points for the Sync button.
            void onSync() => unawaited(SettingsActions.forceResync(context));
            final showSearch = touch && !collapsed;
            // macOS hoists the arrows into the window-caption row beside the
            // traffic lights (see below). Only where such a row exists, and
            // only on the expanded persistent rail: the collapsed 64-px rail is
            // narrower than the traffic-light span itself, and the drawer has
            // no caption row of its own. `showSearch` / `hideHeader` can't be
            // true on a macOS desktop rail — both are touch- or drawer-only —
            // but gating on them keeps the "arrows alone in the row" invariant
            // explicit rather than incidental.
            final captionHostsArrows =
                widget.width != null &&
                !collapsed &&
                !showSearch &&
                !hideHeader &&
                WindowCaptionStrip.hostsCaptionRow();
            // SafeArea (top AND bottom): the sidebar has no AppBar in either
            // host — the mobile drawer (Flutter's `Drawer` adds no inset of its
            // own) and the iPad persistent rail (Positioned at top: 0) — so
            // this one widget owns both vertical insets. The surface decoration
            // below still paints behind the status bar and the gesture bar.
            //
            // The rail genuinely spans the window. The *drawer* does not: it
            // belongs to the per-screen Scaffold, which sits in an `Expanded`
            // with `OfflineBanner` above it and `_DebugPanelBand` below
            // (`scaffold_with_nav.dart`). So with the banner up the top inset
            // is paid twice (pre-existing — the banner has its own
            // `SafeArea(bottom: false)`), and with the debug panel revealed the
            // drawer's bottom edge is nowhere near the gesture bar and the
            // gutter below is dead space. Both are cosmetic and confined to
            // states that are themselves temporary; the alternative — measuring
            // the box instead of the window — costs a keyboard flicker (see the
            // note on the height gate above).
            //
            // Bottom used to be `false`, ceded to `SidebarFooterActions`' own
            // SafeArea. That was invoiceninja/flutter#124: the footer renders
            // three siblings — the icon row, then TrialFooter, then
            // WhiteLabelFooter — so an inset owned by the *first* of them
            // padded the middle of the footer instead of the end of it. On a
            // 24-dp Android gesture bar that put 8 + 24 + 12 = 44 px of dead
            // space between the icons and the upsell card, and left the card
            // itself painting inside the gesture strip with only its own 12 px
            // below it. Geometrically this is identical to wrapping just the
            // footer group (RenderPadding deflates the constraints, so every
            // child above keeps its position and the Expanded nav list absorbs
            // the inset either way) — it is here because one owner is the
            // whole point, and because a group wrapper stops working the
            // moment the group renders nothing.
            //
            // Consequence to know before adding a SafeArea inside the rail:
            // `bottom: true` also runs removePadding(removeBottom: true) over
            // the entire sidebar subtree, so a descendant reading
            // `padding.bottom` now sees 0. Nothing does today.
            //
            // Horizontal insets are deliberately OFF: SafeArea applies
            // *window-level* padding regardless of widget position, and the
            // rail / drawer widths are pinned (232 / 64 / 280) — on iPhone
            // landscape (~59px inset per side, and landscape widths are ≥600 so
            // the rail shows) the defaults would crush the collapsed 64px rail
            // to zero usable width. On macOS every inset is 0, so desktop
            // layout is unchanged.
            NavHistoryButtons navHistoryOfHeight(double? height) =>
                NavHistoryButtons(
                  compact: collapsed,
                  popDrawerFirst: widget.width == null,
                  touch: touch,
                  height: height,
                );
            final navHistory = navHistoryOfHeight(null);
            final content = SafeArea(
              left: false,
              right: false,
              child: Column(
                children: [
                  // Desktop hidden-title-bar caption strip — macOS today:
                  // reserves space for the floating traffic lights and drags
                  // the window. Persistent sidebar only — the mobile drawer
                  // (width == null) sits below the narrow-layout strip, so it
                  // needs none.
                  if (widget.width != null)
                    WindowCaptionStrip(
                      controller: services.screenshotWindow,
                      // Trailing-aligned in the caption row: level with the
                      // traffic lights, clear of them, and lined up with the
                      // Sync button in the header row below. The strip hands
                      // down the height, since it owns the measured band — the
                      // pair must fit it or it grows the band and drops below
                      // the buttons it should sit level with.
                      trailingBuilder: captionHostsArrows
                          ? navHistoryOfHeight
                          : null,
                    ),
                  // Browser-style back/forward — the visible handle on the
                  // Cmd/Alt+←/→ history. Top-left like a browser toolbar.
                  // Its own row only where the caption row above didn't take
                  // them (everywhere but the expanded macOS rail).
                  //
                  // Load-bearing on touch: the shortcuts need a hardware
                  // keyboard and `NavHistoryMouseListener` needs thumb
                  // buttons, so without these a tablet/phone user who follows
                  // a cross-entity link has no way back.
                  if (!captionHostsArrows)
                    Padding(
                      // left 10 is an alignment, not a leftover: with touch
                      // sizing the back arrow's 18-px glyph starts at
                      // 10 + (44 − 18) / 2 = 23 — exactly the company avatar's
                      // left edge below it (14 outer + 1 border + 8 padding).
                      //
                      // The right inset has two answers because both of the
                      // things it used to line up with move under `hideHeader`:
                      // 14 lines the search box's trailing edge up with the Sync
                      // button *in the header row below*, but with no header
                      // below there is nothing to line up with — so the merged
                      // row takes the nav list's own 12 instead, which is both
                      // the correct alignment and 2 px the search label needs
                      // (see the width note on the row itself). The bottom inset
                      // likewise only exists when this row is the last thing
                      // before the divider.
                      padding: collapsed
                          ? const EdgeInsets.only(top: 4)
                          : EdgeInsets.fromLTRB(
                              10,
                              4,
                              hideHeader ? 12 : 14,
                              hideHeader ? 8 : 0,
                            ),
                      // Global search (issue #101) shares this row when there is
                      // room for it. Touch-only: desktop reaches the palette via
                      // ⌘/ and the Dashboard row's hover icon. Absent from the
                      // collapsed rail — 2×32 arrows fill its 64 px exactly.
                      //
                      // Sync joins it under `hideHeader` (issue #104), and the
                      // label slot is the thing to watch: at 280 the row is
                      // 258 wide, arrows take 88 and Sync 44, leaving the box
                      // 122 and its label 84 px — a hair more than the 232-px
                      // rail's 82, which `sidebar_search_box.dart` calls the
                      // tightest surface in the app. Don't spend those pixels.
                      // `InSpacing.xs`, not `sm`: two bordered boxes need *some*
                      // daylight (unlike the bare-glyph arrows, which carry 13 px
                      // of optical separation inside their own 44-px boxes), but
                      // 4 is enough and 8 would put the label under the rail.
                      //
                      // The arrows stay a *direct* child when nothing shares the
                      // row rather than always sitting in a `Row`. A Row hands a
                      // non-flex child an unbounded main axis, which makes
                      // `NavHistoryButtons` shrink-wrap and leaves its own
                      // `mainAxisAlignment: compact ? center : start` with no
                      // free space to work in — so the collapsed rail's centring
                      // would silently become a no-op that only looks right
                      // because 2×32 == 64 exactly.
                      child: showSearch || hideHeader
                          ? Row(
                              children: [
                                navHistory,
                                // Deliberately no gap widget: `_HistoryButton`
                                // centres an 18-px glyph in a 44-px box, so 13 px
                                // of optical separation is already built in, and
                                // the box needs every pixel it can get on the
                                // 232-px rail.
                                if (showSearch)
                                  Expanded(
                                    child: SidebarSearchBox(
                                      // Unlike Sync this *does* pop the mobile
                                      // drawer first — the palette is a modal the
                                      // user then types into, and leaving the
                                      // drawer open behind it stacks two overlays.
                                      onTap: () {
                                        widget.onBeforeModal?.call();
                                        showCommandPalette(context);
                                      },
                                    ),
                                  ),
                                if (hideHeader) ...[
                                  SizedBox(width: InSpacing.xs),
                                  // Left-aligned beside the arrows on a pointer
                                  // drawer (no search box to push it out): three
                                  // controls in a row read as a toolbar, whereas
                                  // a lone button pinned 150 px away at the right
                                  // edge reads as a stray.
                                  SidebarSyncButton(
                                    progress: services.resync,
                                    companyId: session.currentCompanyId,
                                    touch: touch,
                                    onSync: onSync,
                                  ),
                                ],
                              ],
                            )
                          : navHistory,
                    ),
                  // Dropped entirely by `hideHeader` — the switcher then lives
                  // in the footer and Sync in the row above. Deliberately not
                  // wrapped in an `AnimatedSize`: the 1 -> 2 transition never
                  // happens on screen (the add-company flow pops the drawer and
                  // routes to Company Details), and 2 -> 1 only arrives with a
                  // roster that has wrongly shrunk — the issue #16 state, where
                  // the layout changing is information rather than jank.
                  if (!hideHeader)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: SidebarHeader(
                        session: session,
                        onBeforeModal: widget.onBeforeModal,
                        compact: collapsed,
                        touch: touch,
                        resync: services.resync,
                        // Deliberately does not pop the mobile drawer the way
                        // the company switcher does: closing it would hide the
                        // spinner the user just started. The toast host paints
                        // above the drawer either way.
                        onSync: onSync,
                      ),
                    ),
                  Container(height: 1, color: tokens.border),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      // Counter choices repaint the rail: a badge switching
                      // from a grey total to a red overdue count changes the
                      // row, not just the number.
                      child: ListenableBuilder(
                        listenable: services.sidebarBadgeModes,
                        builder: (context, _) => StreamBuilder<CompanyRow?>(
                          stream: _company?.stream,
                          builder: (context, companySnap) =>
                              StreamBuilder<SavedView?>(
                                stream: _activeView?.stream,
                                builder: (context, snap) => Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: _buildItems(
                                    context,
                                    services,
                                    session.currentCompanyId,
                                    compact: collapsed,
                                    touch: touch,
                                    activeViewId: snap.data?.id,
                                    trackInventory:
                                        companySnap.data?.trackInventory ??
                                        false,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                  Container(height: 1, color: tokens.border),
                  SidebarFooterActions(
                    compact: collapsed,
                    showCollapseToggle: canCollapse,
                    touch: touch,
                    // The single-company drawer's company switcher. Pops the
                    // drawer first, exactly like the header switcher does, then
                    // opens the picker — which is always the bottom sheet here,
                    // since `showCompanyPicker` forks at `Breakpoints.wide` and
                    // the drawer only exists below it. No anchor key for the
                    // same reason: the sheet ignores one.
                    leading: hideHeader
                        ? SidebarCompanyFooterAction(
                            company: session.currentCompany,
                            touch: touch,
                            onTap: () {
                              widget.onBeforeModal?.call();
                              showCompanyPicker(context);
                            },
                          )
                        : null,
                  ),
                  // An expiring trial is time-critical and has no second home,
                  // so it is never gated on height; the standing white-label
                  // offer is, and always reachable from Settings -> Account
                  // Management -> Plan. (The two are mutually exclusive anyway
                  // — hosted vs self-hosted — so at most one ever renders.)
                  TrialFooter(compact: collapsed),
                  if (showsUpsell) WhiteLabelFooter(compact: collapsed),
                  // Nothing goes below this line. The sidebar's bottom inset is
                  // the outer SafeArea's (see its comment above), so a widget
                  // appended here would paint inside the Android gesture bar /
                  // iPhone home indicator — which is exactly the half of
                  // invoiceninja/flutter#124 that was hardest to see.
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
    required bool touch,
    required String? activeViewId,
    required bool trackInventory,
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
        touch: touch,
        labelKey: 'dashboard',
        icon: Icons.dashboard_outlined,
        kind: FixedBranchKind.dashboard,
        trailingHover: const _DashboardRowSearchButton(),
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
            touch: touch,
            activeViewId: activeViewId,
            trackInventory: trackInventory,
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
          touch: touch,
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
      // Activity — the company-wide feed at `/activity` (invoiceninja/flutter#53).
      // Deliberately *navigation*, not a feed embedded in this sidebar: the
      // whitespace above the footer only exists on a tall device with few
      // modules (every touch row is floored at `InSizes.touchTarget`, so a
      // full module set already overflows the scroll view on a normal phone),
      // the drawer closes on the first tap, and the 64 px collapsed rail has
      // no room at all.
      //
      // Ungated. There is no `view_activity` in our permission set, and the
      // server already scopes the feed for us — `ActivityController::index`
      // narrows the `?reactv2` branch to `user_id = auth()->user()->id` for a
      // non-admin, so a staff user simply sees their own rows.
      _fixedNav(
        context,
        services,
        compact: compact,
        touch: touch,
        labelKey: 'activity',
        // Deliberately filled where the other rows are outlined: this is the
        // workspace-level Activity branch, not a detail tab. (The detail tabs
        // all use `Icons.history_outlined`, which does exist — an older
        // version of this comment claimed otherwise.)
        icon: Icons.history,
        kind: FixedBranchKind.activity,
      ),
      // Saved views — reactive section that disappears when empty. Owns its
      // own trailing spacer so the Activity→Settings gap stays uniform with
      // the rest of the sidebar when there are no saved views.
      _SavedViewsSection(
        companyId: companyId,
        currentBranch: widget.currentBranch,
        onSelectBranch: widget.onSelectBranch,
        compact: compact,
        touch: touch,
        activeViewId: activeViewId,
        savedViewsStream: _savedViews!.stream,
      ),
      _fixedNav(
        context,
        services,
        compact: compact,
        touch: touch,
        labelKey: 'settings',
        icon: Icons.settings_outlined,
        kind: FixedBranchKind.settings,
      ),
      _fixedNav(
        context,
        services,
        compact: compact,
        touch: touch,
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
    required bool touch,
    required String? activeViewId,
    required bool trackInventory,
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
    SidebarNavItem buildTile({
      int? count,
      SidebarBadgeTone tone = SidebarBadgeTone.neutral,
      String? countLabel,
    }) => SidebarNavItem(
      label: label,
      icon: handlers.effectiveOutlinedIcon,
      active: isActive,
      disabled: handlers.disabled,
      compact: compact,
      touch: touch,
      count: count,
      countTone: tone,
      countLabel: countLabel,
      onTap: onTap,
      trailingHover: hoverAdd,
      leaderKey: branch == null ? null : _entityLeaderKey(handlers.type),
    );

    final badge = handlers.badgeStream;
    final offered = availableBadgeModes(
      handlers.badgeModes,
      trackInventory: trackInventory,
    );
    final modeId = services.sidebarBadgeModes.modeFor(
      handlers.type,
      available: offered,
    );
    _noteBadgeMode(handlers.type, modeId);

    Widget withMenu(Widget child) {
      // Right-click / long-press to change what this row counts. Mirrors the
      // saved-view rows' menu (see `_openSavedViewMenu`); skipped in compact
      // mode and on disabled rows for the same reasons they skip it.
      if (compact || handlers.disabled || offered.length < 2) return child;
      return _BadgeModeMenuTarget(
        entityType: handlers.type,
        modes: offered,
        selectedId: modeId,
        child: child,
      );
    }

    if (badge == null || modeId == kBadgeModeNone) {
      return withMenu(buildTile());
    }
    final mode = offered.firstWhere(
      (m) => m.id == modeId,
      orElse: () => offered.first,
    );
    return withMenu(
      StreamBuilder<int>(
        // Keyed by (entity, mode): keying by entity alone would hand a row that
        // just switched to "Overdue" the previously-cached total.
        stream: _cachedBadge((
          handlers.type,
          modeId,
        ), () => badge(services, companyId, modeId)),
        builder: (context, snap) => buildTile(
          count: snap.data,
          tone: mode.tone,
          // A plain total needs no explaining; a status count does.
          countLabel: modeId == kBadgeModeTotal
              ? null
              : context.tr(mode.labelKey),
        ),
      ),
    );
  }

  Widget _fixedNav(
    BuildContext context,
    Services services, {
    required bool compact,
    required bool touch,
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
      touch: touch,
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
class _DashboardRowSearchButton extends StatelessWidget {
  const _DashboardRowSearchButton();

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
    required this.touch,
    required this.activeViewId,
    required this.savedViewsStream,
  });

  final String companyId;
  final int currentBranch;
  final ValueChanged<int> onSelectBranch;
  final bool compact;
  final bool touch;

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
                touch: touch,
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
    required this.touch,
    required this.active,
    required this.onTap,
  });

  final SavedView view;
  final bool compact;
  final bool touch;
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
      touch: touch,
      onTap: onTap,
      // Always-visible (not hover-gated) so the menu is discoverable; the
      // collapsed rail has no room for it (handled by SidebarNavItem).
      trailing: compact ? null : _SavedViewMenuButton(view: view, touch: touch),
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
  const _SavedViewMenuButton({required this.view, required this.touch});

  final SavedView view;
  final bool touch;

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
      // Without this the `constraints` below are advisory on touch platforms:
      // `ThemeData.materialTapTargetSize` is `padded` on android/iOS, which
      // wraps the button in `_InputPadding` and inflates its *layout* size
      // (not just its hit area) to `kMinInteractiveDimension` = 48 — so the row
      // would be 48 + 14 padding = 62 px. Matches the explicit `shrinkWrap` the
      // sibling `_CollapseToggleButton` and `_HistoryButton` already carry.
      // No-op on desktop, where the theme default is already `shrinkWrap`.
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      // Deliberately unset on touch. Under Material 3 `IconButton` converts
      // `constraints` into ButtonStyle `minimumSize`/`maximumSize`, and
      // `ButtonStyleButton` runs *those* through
      // `visualDensity.effectiveConstraints` — so `compact`'s -8 would turn the
      // width below into a 36..44 range that the 16-px icon collapses back to
      // 36, silently undoing the bigger target. (The `effectiveConstraints`
      // call inside `icon_button.dart` is on the legacy pre-M3 branch and never
      // runs here.) Unset falls back to `ThemeData.visualDensity`, which is
      // `standard` — zero adjustment — on exactly the platforms `touch` covers.
      visualDensity: touch ? null : VisualDensity.compact,
      // `constraints` here sizes the IconButton itself — matching the proven
      // `_HoverAddButton` footprint against the row's 18-px icon. `ink3` is the
      // established weight for sidebar trailing affordances (the entity-row
      // `+`). This one is always visible rather than hover-gated, so on touch
      // it is a real target and widens to the full 44.
      //
      // Height stays at the row's *content* box (44 floor − 7/7 padding = 30),
      // not 44: `trailing` sits inside the row's Row, so a 44-tall button would
      // drive the Row to 44 and the row's own padding would stack on top for a
      // 58-px row — 32% taller than every other row in the sidebar. Width is
      // the axis a thumb misses on in a vertical list anyway, and the row's own
      // 44-px floor still governs what the finger lands in.
      constraints: touch
          ? const BoxConstraints.tightFor(
              width: InSizes.touchTarget,
              height: 30,
            )
          : const BoxConstraints.tightFor(width: 18, height: 18),
      icon: Icon(Icons.more_vert, color: context.inTheme.ink3),
      onPressed: () => _open(context),
    );
  }
}

/// Wraps an entity sidebar row with a right-click / long-press menu for
/// choosing what its badge counts. Mirrors the saved-view rows' menu
/// ([_openSavedViewMenu]) — `showMenu` rather than `PopupMenuButton`, which
/// sizes the menu to the trigger's footprint and clips it.
///
/// Unlike saved-view rows there's no always-visible `⋮` trigger: the entity
/// row's right edge already belongs to the hover `+`. Settings → Device
/// Settings → Sidebar counters is the discoverable (and keyboard-reachable)
/// path; this is the shortcut for people who already know it's here.
class _BadgeModeMenuTarget extends StatelessWidget {
  const _BadgeModeMenuTarget({
    required this.entityType,
    required this.modes,
    required this.selectedId,
    required this.child,
  });

  final EntityType entityType;
  final List<SidebarBadgeMode> modes;
  final String selectedId;
  final Widget child;

  Future<void> _open(BuildContext context, Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final controller = context.read<Services>().sidebarBadgeModes;
    final picked = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        for (final mode in modes)
          CheckedPopupMenuItem<String>(
            value: mode.id,
            checked: mode.id == selectedId,
            child: Text(context.tr(mode.labelKey)),
          ),
      ],
    );
    if (picked == null) return;
    await controller.set(entityType, picked);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (d) => unawaited(_open(context, d.globalPosition)),
      onLongPressStart: (d) => unawaited(_open(context, d.globalPosition)),
      child: child,
    );
  }
}
