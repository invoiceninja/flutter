import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/ui/core/widgets/hidden_shell_navigator.dart';

/// Lightweight shared state between `MasterDetailLayout` and the list
/// scaffold mounted inside it. The list scaffold writes the visible
/// item ids + the URL-derived `selectedId` here on every rebuild; the
/// pane's keyboard shortcuts (`J` / `K` / `↓` / `↑`) read it to compute
/// the next / previous row to navigate to.
///
/// Why a controller instead of a callback: the layout doesn't have
/// access to the list's VM (the list is an opaque widget), and the
/// scaffold doesn't know about the layout's keyboard handlers. A
/// shared object pushed into the InheritedWidget tree lets each side
/// touch only what it needs.
class MasterDetailNavController {
  String? _selectedId;
  List<String> _itemIds = const <String>[];

  /// Animated close hook bound by the layout's State in `initState`.
  /// Called by list tiles via [MasterDetailNavScope.requestClose] so
  /// row-click-deselect plays the same slide-out as the X button —
  /// the URL only changes after the reverse animation finishes.
  Future<void> Function()? closePane;

  void update({required String? selectedId, required List<String> itemIds}) {
    _selectedId = selectedId;
    _itemIds = itemIds;
  }

  String? nextId() {
    if (_itemIds.isEmpty) return null;
    if (_selectedId == null) return _itemIds.first;
    final i = _itemIds.indexOf(_selectedId!);
    if (i < 0 || i >= _itemIds.length - 1) return null;
    return _itemIds[i + 1];
  }

  String? prevId() {
    if (_itemIds.isEmpty) return null;
    if (_selectedId == null) return _itemIds.last;
    final i = _itemIds.indexOf(_selectedId!);
    if (i <= 0) return null;
    return _itemIds[i - 1];
  }
}

/// InheritedWidget that publishes the layout's
/// [MasterDetailNavController] to descendants without triggering
/// rebuilds — descendants read the controller object once and call
/// methods on it; the controller's internal state isn't observable
/// (the keyboard handlers don't need to react to changes, they just
/// need the latest value at key-press time).
class MasterDetailNavScope extends InheritedWidget {
  const MasterDetailNavScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final MasterDetailNavController controller;

  static MasterDetailNavController? maybeOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MasterDetailNavScope>();
    return scope?.controller;
  }

  /// Close the pane from a descendant (e.g. a list tile's
  /// click-to-deselect). Runs the layout's animated close when hosted
  /// inside a master-detail pane; falls back to plain
  /// `GoRouter.go(basePath)` otherwise (narrow viewports, tests).
  static void requestClose(BuildContext context, {required String basePath}) {
    final close = maybeOf(context)?.closePane;
    if (close != null) {
      close();
    } else {
      GoRouter.of(context).go(basePath);
    }
  }

  // Marker only — descendants treat the controller as a stable ref.
  @override
  bool updateShouldNotify(MasterDetailNavScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Slide-over master-detail used by every entity route block on wide
/// desktop windows. The list **always** renders at full width; the
/// detail / edit / create floats above it as a pane pinned to the
/// right edge — Notion / Slack-thread / iOS-Files style.
///
///   * `/<entity>`               → bare URL, no pane, list full width.
///   * `/<entity>/:id`           → list full width + detail pane on top.
///   * `/<entity>/:id/edit`      → list full width + edit pane on top.
///   * `/<entity>/new`           → list full width + create pane on top.
///   * `?view=full`              → pane fills the window, list hidden
///                                  (mounted offstage so its State
///                                  survives a toggle back).
///
/// On narrow viewports (`< Breakpoints.slideOver`) the layout falls
/// back to today's full-page navigation — same as before this widget
/// existed.
class MasterDetailLayout extends StatefulWidget {
  const MasterDetailLayout({
    super.key,
    required this.basePath,
    required this.list,
    required this.rightPane,
    required this.hasPane,
    this.viewMode,
  });

  /// Base entity URL — `/transactions`, `/clients`, etc. Used by the
  /// pane's close button to route back to the bare list URL.
  final String basePath;

  /// The list widget. Built once by the enclosing `ShellRoute`'s
  /// pageBuilder and reused across every child route inside this
  /// entity's branch.
  final Widget list;

  /// The right-pane host — go_router's `ShellRoute` `child`, i.e. the
  /// **Navigator** that renders `/x/:id`, `/x/:id/edit` and `/x/new`.
  ///
  /// Always supplied, even on the bare list URL where there is nothing to
  /// show. [hasPane] — not a null check — decides whether it is visible; see
  /// [_hiddenPaneHost] for why it must stay mounted regardless.
  final Widget rightPane;

  /// Whether the URL has navigated past the bare list path, i.e. whether
  /// [rightPane] currently has something to render. Derived from
  /// `state.matchedLocation` by `buildEntityRouteBlock` — the same signal
  /// that used to be encoded as a null [rightPane].
  final bool hasPane;

  /// `?view=full` flag from the URL. Null = slide-over. `'full'` =
  /// list hidden, pane fills window.
  final String? viewMode;

  @override
  State<MasterDetailLayout> createState() => _MasterDetailLayoutState();
}

/// Entities whose Edit / Create screens default to the slide-over
/// sidebar panel instead of the full-width editor. These have narrow
/// forms that work well alongside the master table; *every other*
/// entity opens Edit / Create full-width on desktop.
///
/// The full-screen choice is deliberately **never remembered** — neither
/// across an app restart nor row-to-row within a session. The user's
/// explicit F-key / expand toggle ([_toggleFullScreenInUrl]) only
/// rewrites the current URL; the next screen resolves fresh from this
/// table.
const Set<String> _kEditDefaultsToSlide = <String>{
  '/products',
  '/transactions',
  '/payments',
};

/// Whether navigating to [basePath]'s Edit / Create route opens a
/// **full-width** editor (vs. the slide-over panel). Single source of truth
/// shared by [_MasterDetailLayoutState._resolveDesiredMode] and the route
/// block's selected-row suppression (`router.dart`) — a full-width editor
/// covers the list, so the row must not paint "selected" on the way there.
bool editOpensFullWidth(String basePath) =>
    !_kEditDefaultsToSlide.contains(basePath);

/// Where the pane's close/back chrome should navigate. An **edit** form
/// returns to its read-only **detail** parent (`/x/:id`), preserving the pane
/// mode (`?view=full`) so the close reads as an in-pane edit→view content swap
/// with no geometry change. A **detail** (`/x/:id`) or **create** (`/x/new`)
/// form returns to the bare **list** ([basePath]). Every master-detail entity
/// has a detail screen (`buildEntityRouteBlock` asserts it), so an `/edit`
/// route always has a real `/x/:id` parent. Pure for unit testing.
String entityCloseTargetPath({
  required String basePath,
  required String currentPath, // GoRouterState uri.path (no query)
  required bool isFullView, // current uri ?view == 'full'
}) {
  const editSuffix = '/edit';
  if (currentPath.endsWith(editSuffix)) {
    final detail = currentPath.substring(
      0,
      currentPath.length - editSuffix.length,
    );
    return isFullView ? '$detail?view=full' : detail;
  }
  return basePath;
}

/// The entity base path an editor URL sits under: `/quotes/new` → `/quotes`,
/// `/quotes/q_1/edit` → `/quotes`. Companion to [entityCloseTargetPath] for
/// callers that only hold the current URL — notably `EntityEditScaffold`,
/// which lives inside the pane and never receives `basePath`. Pure for
/// unit testing.
String entityBasePathFromEditorPath(String path) {
  const editSuffix = '/edit';
  const newSuffix = '/new';
  if (path.endsWith(newSuffix)) {
    return path.substring(0, path.length - newSuffix.length);
  }
  if (path.endsWith(editSuffix)) {
    final detail = path.substring(0, path.length - editSuffix.length);
    final slash = detail.lastIndexOf('/');
    return slash <= 0 ? detail : detail.substring(0, slash);
  }
  return path;
}

class _MasterDetailLayoutState extends State<MasterDetailLayout>
    with TickerProviderStateMixin {
  final MasterDetailNavController _navController = MasterDetailNavController();

  /// Tracks whether we've already fired the sticky-mode redirect for
  /// the *current* (basePath, selectedId) tuple. Reset whenever either
  /// changes so each new pane entry gets one redirect attempt — without
  /// this we'd loop redirecting forever on every rebuild.
  String? _lastRedirectKey;

  /// Drives the slide-over's IN / OUT translate. `0` = pane fully
  /// off-screen to the right (or unmounted); `1` = docked. Created in
  /// [initState] (not a lazy field) so the Ticker is never built during
  /// dispose.
  late final AnimationController _slide;
  late final Animation<Offset> _slideOffset;

  /// Drives the slide-over ⇄ full-screen geometry. `0` = slide-over
  /// rect pinned to the right edge; `1` = the pane fills the layout
  /// area. The expand / collapse toggle animates this; row-to-row and
  /// fresh opens snap it.
  late final AnimationController _expand;
  late final Animation<double> _expandCurve;

  /// First-paint flag. Cold-start with a deep-linked pane URL
  /// (`/transactions/tx_42` on app launch) snaps the pane open without
  /// animating — the user didn't click anything, so the slide-in would
  /// feel unmotivated. Subsequent opens animate.
  bool _didFirstSync = false;

  bool get _hasPane => widget.hasPane;
  bool get _isFullScreen => widget.viewMode == 'full';

  /// Whether the pane should be **docked** (`_slide` at 1) vs
  /// translated off-screen (0). True whenever a pane exists on a wide
  /// viewport — deliberately independent of full-screen: [_expand]
  /// (not [_slide]) owns the slide-over ⇄ full-screen geometry, so
  /// entering full-screen must NOT slide the (single, unified) pane
  /// away.
  bool _shouldPaneBeDocked() => Breakpoints.isSlideOver(context) && _hasPane;

  /// Resolve the desired pane mode (`'full'` or `'slide'`) for the
  /// current URL. The redirect logic in [_buildTree] uses this to
  /// decide whether to snap the URL into `?view=full` after the user
  /// opens a row.
  ///
  /// Per-screen-type default (the choice is never remembered — see
  /// [_kEditDefaultsToSlide]):
  ///   - **Edit / Create** (`/edit`, `/new`): full-width on desktop for
  ///     every entity *except* [_kEditDefaultsToSlide] (products, bank
  ///     transactions, payments), whose narrow forms stay in the sidebar
  ///     panel.
  ///   - **Detail**: the sidebar preview.
  ///
  /// An explicit `?view=full` (in-cell link, or the user's F-toggle /
  /// expand button for this exact screen) still wins for that URL only.
  String _resolveDesiredMode(String matchedLocation) {
    final isEditOrNew =
        matchedLocation.endsWith('/edit') || matchedLocation.endsWith('/new');
    if (isEditOrNew) {
      return editOpensFullWidth(widget.basePath) ? 'full' : 'slide';
    }
    return 'slide';
  }

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slideOffset = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _slide,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          ),
        );
    _expand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandCurve = CurvedAnimation(
      parent: _expand,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    // Hand the animated-close path to the controller so list-tile
    // clicks can request a slide-out via `MasterDetailNavScope.
    // requestClose` (matches the X / Esc behavior).
    _navController.closePane = _closePaneAnimated;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only reconcile the open/close translate here. `_expand` (slide ⇄
    // full geometry) is NOT synced from didChangeDependencies: a `?view`
    // toggle changes the GoRouterState inherited dependency, so this
    // fires on the same frame as didUpdateWidget — and a null-oldWidget
    // `_syncExpand` would snap `_expand` to the target, clobbering the
    // forward()/reverse() the didUpdateWidget path just started. Cold
    // start is handled by _syncSlideVisibility's first-sync snap;
    // every later change goes through didUpdateWidget's _syncExpand.
    _syncSlideVisibility();
  }

  @override
  void didUpdateWidget(MasterDetailLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sticky-mode writes are explicit — they only fire from
    // [_toggleFullScreenInUrl]. URL changes here (opening a row,
    // clicking the X, switching entities) reflect routing state and
    // must NOT overwrite the user's last toggle preference, or
    // clicking a fresh row would clobber the sticky map back to null.
    _syncSlideVisibility();
    _syncExpand(oldWidget);
  }

  @override
  void dispose() {
    _slide.dispose();
    _expand.dispose();
    super.dispose();
  }

  /// Reconcile the pane's dock/undock translate ([_slide]) with the
  /// current URL + viewport. Called from both [didChangeDependencies]
  /// (viewport resize) and [didUpdateWidget] (URL change). Geometry
  /// (slide-over ⇄ full-screen) is handled separately by [_syncExpand].
  ///
  /// **Snap-or-forward only.** The user-initiated close animation
  /// (X button, Esc) runs through [_closePaneAnimated] — which confirms
  /// any unsaved edits first — *before* the URL changes, so by the time
  /// this sync sees `shouldShow == false`,
  /// the controller is already at 0. External closes (sidebar click,
  /// back button, URL bar) land here with the controller still at 1
  /// and the detail Element already torn down by go_router; snapping
  /// to 0 is the only safe option (animating would render a freshly
  /// re-mounted, empty-state widget for 220 ms — the v4 bug).
  void _syncSlideVisibility() {
    final shouldBeDocked = _shouldPaneBeDocked();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (!_didFirstSync) {
      // Cold start — snap regardless of state. Animations are reserved
      // for transitions, not initial paint. A deep link to `?view=full`
      // opens full with no grow.
      _didFirstSync = true;
      _slide.value = shouldBeDocked ? 1 : 0;
      _expand.value = _isFullScreen ? 1 : 0;
      return;
    }
    if (shouldBeDocked && _slide.value < 1) {
      if (reduceMotion) {
        _slide.value = 1;
      } else {
        _slide.forward();
      }
    } else if (!shouldBeDocked && _slide.value > 0) {
      _slide.value = 0;
    }
  }

  /// Reconcile the slide-over ⇄ full-screen geometry animation
  /// ([_expand]) with the current URL.
  ///
  /// Snap (no animation) on a fresh open, a close, a viewport resize,
  /// or a row-to-row / content change — only **animate** when the pane
  /// stays mounted and `viewMode` flips (the user pressed the expand /
  /// collapse control, or an auto edit-default promoted the route).
  /// Cold start is handled by [_syncSlideVisibility]'s first-sync snap.
  void _syncExpand(MasterDetailLayout? oldWidget) {
    if (!_didFirstSync) return; // first-sync snap owns the initial value
    final target = _isFullScreen ? 1.0 : 0.0;
    final modeFlip =
        oldWidget != null &&
        oldWidget.hasPane &&
        widget.hasPane &&
        oldWidget.viewMode != widget.viewMode;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (modeFlip && !reduceMotion) {
      if (target == 1.0) {
        _expand.forward();
      } else {
        _expand.reverse();
      }
    } else if (_expand.value != target && !_expand.isAnimating) {
      // Defense-in-depth: never hard-snap while a grow/shrink is in
      // flight, so a stray non-flip caller can't clobber the animation.
      _expand.value = target;
    }
  }

  /// User-initiated close. Confirms any unsaved edits *before* navigating
  /// so the "Discard changes?" dialog appears over the still-visible form.
  ///
  /// [toParent] (the pane's X / Esc / back chrome): an edit form closes to
  /// its read-only detail parent (preserving `?view`), every other route to
  /// the bare list. Default `false` (the list-tile *deselect* gesture wired
  /// through [MasterDetailNavController.closePane]) always collapses to the
  /// list — clicking the open row again is "close the pane", not "view it".
  ///
  /// Closing **to the list** slides the pane out first (while it's still
  /// mounted, URL unchanged), then navigates; if the user navigated away
  /// mid-animation (e.g. clicked another row) we skip the final `go` so we
  /// don't clobber their new destination. Closing **edit → detail** keeps the
  /// pane docked and just swaps content (no slide-out) — an instant edit→view
  /// swap like the J/K row nav; sliding out then back in would visibly jank.
  Future<void> _closePaneAnimated({bool toParent = false}) async {
    final fromUri = GoRouterState.of(context).uri;
    final fromLoc = GoRouterState.of(context).matchedLocation;

    // Only edit/create routes carry the `onExit` discard guard
    // (`buildEntityRouteBlock` in router.dart — the app's only
    // `GoRoute.onExit` guards). Run that same guard up-front so the
    // dialog shows over the form instead of after it has slid away. On
    // Discard `confirmIfDirty` resets the editor (its `onDiscard`), so
    // the `go` below re-enters `onExit` against a clean VM and doesn't
    // double-prompt. Detail panes (`/:id`) have no guard, so we skip the
    // check — closing them stays identical to today (no prompt, even when
    // an unrelated editor in another branch is dirty).
    final isGuarded = fromLoc.endsWith('/edit') || fromLoc.endsWith('/new');
    if (isGuarded) {
      final guard = context.read<Services>().unsavedChangesGuard;
      if (!await guard.confirmIfDirty(context)) return; // user kept editing
      if (!mounted) return;
    }

    final target = toParent
        ? entityCloseTargetPath(
            basePath: widget.basePath,
            currentPath: fromUri.path,
            isFullView: fromUri.queryParameters['view'] == 'full',
          )
        : widget.basePath;
    final closingToList = Uri.parse(target).path == widget.basePath;

    if (closingToList) {
      final reduceMotion =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (!reduceMotion && _slide.status != AnimationStatus.dismissed) {
        await _slide.reverse();
      }
      if (!mounted) return;
      final nowLoc = GoRouterState.of(context).matchedLocation;
      // User navigated somewhere else mid-animation (e.g. clicked a
      // different row) — their navigation wins; don't clobber it.
      if (nowLoc != fromLoc) return;
      if (nowLoc == widget.basePath) return; // already where we'd go
    }
    // Edit → detail keeps the pane docked: navigate for an instant content
    // swap (no slide-out). The geometry is unchanged because `?view` carries.
    GoRouter.of(context).go(target);
  }

  @override
  Widget build(BuildContext context) {
    return MasterDetailNavScope(
      controller: _navController,
      child: _buildTree(context),
    );
  }

  /// The shell's Navigator on the bare list URL, mounted but invisible.
  /// [HiddenShellNavigator] carries the full rationale; the short version is
  /// that dropping it strands `navigatorKey.currentState` and makes every
  /// platform back press throw inside go_router (issue #39).
  ///
  /// Both mount points below hand it the **same constraints the visible pane
  /// would get** — `Offstage` lays its child out, and the pane subtree holds
  /// real routes mid-transition while a pane closes, so a 0×0 box would run
  /// their `LayoutBuilder`s and scroll positions at zero width on the way out.
  Widget _hiddenPaneHost() => HiddenShellNavigator(child: widget.rightPane);

  Widget _buildTree(BuildContext context) {
    final isWide = Breakpoints.isSlideOver(context);

    // Forget the last promoted location as soon as the pane closes, so
    // re-opening the *same* edit URL (edit a row, close, edit it again)
    // gets a fresh promotion attempt instead of being deduped into the
    // slide-over. The redirect block below is a no-op without a pane, so
    // clearing here has no other side effect; a successful promotion
    // keeps the pane mounted (`_hasPane` stays true) so it never loops.
    if (!_hasPane) _lastRedirectKey = null;

    // Desired-mode redirect: every URL with a pane gets one chance to
    // be promoted to full-screen, based on the per-screen-type default
    // (Edit / Create default to full for every entity except products
    // and bank transactions — see [_resolveDesiredMode] and
    // [_kEditDefaultsToSlide]).
    //
    // Dedup key is `matchedLocation` rather than `(basePath, :id)` so
    // detail (`/clients/c_42`) and edit (`/clients/c_42/edit`) are
    // independent — the redirect re-evaluates when the user clicks
    // Edit, picking up the edit-defaults-to-full rule even when the
    // detail already settled. Cross-entity nav lives in a different
    // State, so no cross-entity leak.
    if (isWide && _hasPane && widget.viewMode == null) {
      final loc = GoRouterState.of(context).matchedLocation;
      if (_lastRedirectKey != loc) {
        _lastRedirectKey = loc;
        if (_resolveDesiredMode(loc) == 'full') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _toggleFullScreenInUrl(context, isFullScreen: false);
          });
        }
      }
    }

    // Narrow viewport: full-page navigation, exactly today's behavior.
    // The list is wrapped in `Offstage` so its State survives a
    // resize back to wide.
    if (!isWide) {
      if (!_hasPane) {
        return Stack(children: [widget.list, _hiddenPaneHost()]);
      }
      return Stack(
        children: [
          Offstage(offstage: true, child: widget.list),
          // Full-page pane on narrow. This IS the full-page screen at this
          // viewport, so it owns the `Scaffold` — `ScaffoldWithNav`'s narrow
          // branch is a deliberate passthrough with no outer one, and the list's
          // Scaffold is a *sibling* in this Stack (Offstage), never an ancestor.
          // Two things ride on that:
          //
          //  * `resizeToAvoidBottomInset` (the default — spelled out because it
          //    is the whole reason this is a Scaffold and not the `Material` it
          //    replaces). Nothing in the pane's own chrome or in an entity form
          //    consumes `MediaQuery.viewInsets.bottom` (a modal sheet opened
          //    from in here does, but it mounts in the Navigator *below* this
          //    Scaffold and so reads 0 — correctly, since the body has already
          //    been inset). Without it a form's viewport keeps full height
          //    under the on-screen keyboard, `EditableText`
          //    sees the caret as already visible and never scrolls, and a field
          //    low in the form stays behind the keyboard
          //    (invoiceninja/flutter#105 — payment Private Notes). Geometry is
          //    unchanged with no keyboard up, and the 600–1024 band can't
          //    double-inset: the wide shell Scaffold already zeroed the inset
          //    for its body.
          //  * the Material ancestor the embedded detail/edit body needs
          //    (`Scaffold` builds one from `backgroundColor`) — without it,
          //    plain-Container cards inherit the fallback DefaultTextStyle and
          //    paint the "missing Material" yellow underlines + oversized text
          //    (which also overflows the time-log rows).
          //
          // The SafeArea sits *inside* so `bg` still paints behind the status
          // bar while the header strip starts below it — the narrow twin of the
          // wide branch's Positioned `top: MediaQuery.paddingOf(context).top`.
          // Bottom stays free: the body scrolls and nothing docks at the bottom
          // edge.
          Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: context.inTheme.bg,
            body: SafeArea(
              bottom: false,
              child: _PaneRoot(
                basePath: widget.basePath,
                isFullScreen: true,
                isNarrow: true,
                navController: _navController,
                child: widget.rightPane,
              ),
            ),
          ),
        ],
      );
    }

    // Wide viewport. The list always renders full-width; a single
    // pane floats on top via a Stack and animates its geometry between
    // the slide-over rect (pinned to the right edge) and the
    // full-screen rect (fills the layout area) via [_expand]. Only ONE
    // `_PaneRoot` (it carries the Navigator's GlobalKey) is ever
    // mounted, so the edit-form State survives the grow / shrink and
    // there is no key collision. The list stays painted until the pane
    // is fully settled full-screen AND docked, so it is visibly
    // revealed as the pane grows, shrinks, or slides away on close.
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: Listenable.merge([_slide, _expand]),
          builder: (context, _) {
            final t = _expandCurve.value;
            // Hide the list only while the full-screen pane fully
            // covers it. The moment a close starts (`_slide` reverses
            // below 1) the table must paint underneath so it's
            // revealed as the pane slides away — not pop in after.
            final listHidden =
                _hasPane &&
                _isFullScreen &&
                _expand.status == AnimationStatus.completed &&
                _slide.value >= 1;
            return Stack(
              children: [
                Positioned.fill(
                  child: Offstage(offstage: listHidden, child: widget.list),
                ),
                // *Positioned*, so this Stack keeps sizing itself from
                // `constraints.biggest`: a non-positioned child would flip it
                // to sizing from its children and collapse the layout.
                if (!_hasPane) Positioned.fill(child: _hiddenPaneHost()),
                if (_hasPane)
                  Positioned(
                    left: _lerp(
                      constraints.maxWidth - _paneWidth(context),
                      0,
                      t,
                    ),
                    // Full height in both states (safe-area inset only;
                    // 0 on desktop) so the expand reads as a clean
                    // horizontal widen to fill the whole screen.
                    top: MediaQuery.paddingOf(context).top,
                    width: _lerp(_paneWidth(context), constraints.maxWidth, t),
                    bottom: 0,
                    child: SlideTransition(
                      position: _slideOffset,
                      child: Material(
                        elevation: _lerp(8, 0, t),
                        color: context.inTheme.bg,
                        child: _PaneRoot(
                          basePath: widget.basePath,
                          isFullScreen: _isFullScreen,
                          isNarrow: false,
                          navController: _navController,
                          onClose: () => _closePaneAnimated(toParent: true),
                          child: widget.rightPane,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── Pane root (chrome + a11y + keyboard + content swap) ────────────────

/// Common chrome wrapped around either the slide-over pane or the
/// full-screen pane:
///   * [MasterDetailPaneScope] — suppresses the embedded screen's
///     outer `Scaffold` / `AppBar` AND publishes the close + full-
///     screen icons so the screen renders them inline in its own
///     header strip. Both slide-over and full-screen variants use
///     this path; the embedded scaffold's inline header reserves a
///     slot for them.
///   * `CallbackShortcuts` + autofocus so Esc / F / J / K work.
///   * `Semantics(announce:)` for screen readers.
///
/// Content swaps (detail ↔ edit, row-to-row) are instant. An
/// `AnimatedSwitcher` cross-fade isn't safe here — the [child] is the
/// Navigator from `ShellRoute.pageBuilder`, which carries a
/// `GlobalKey<NavigatorState>`. Cross-fading would mount both old and
/// new subtrees simultaneously, colliding the key.
class _PaneRoot extends StatelessWidget {
  const _PaneRoot({
    required this.basePath,
    required this.isFullScreen,
    required this.isNarrow,
    required this.navController,
    required this.child,
    this.onClose,
  });

  final String basePath;
  final bool isFullScreen;

  /// Narrow viewport (`< Breakpoints.slideOver`): the pane is rendered
  /// full-page, so the chrome is a mobile-standard leading back arrow
  /// instead of the desktop trailing full-screen-toggle + X.
  final bool isNarrow;
  final MasterDetailNavController navController;
  final Widget child;

  /// Optional close handler used by the X button and the Esc shortcut.
  /// When null (the narrow full-page pane), close falls back to a direct
  /// `go` to the [entityCloseTargetPath] — an edit form to its detail
  /// parent, everything else to the list. The slide-over passes its
  /// layout-state `_closePaneAnimated` so closing runs the slide-out
  /// animation before the URL changes.
  final VoidCallback? onClose;

  void _close(BuildContext context) {
    final handler = onClose;
    if (handler != null) {
      handler();
    } else {
      // Narrow full-page pane: no slide animation, so navigate straight to
      // the close target (edit → detail parent; detail/create → list). The
      // edit route's `onExit` guard still fires on this `go`, so a dirty edit
      // still prompts before navigating.
      final uri = GoRouterState.of(context).uri;
      GoRouter.of(context).go(
        entityCloseTargetPath(
          basePath: basePath,
          currentPath: uri.path,
          isFullView: uri.queryParameters['view'] == 'full',
        ),
      );
    }
  }

  void _navigateRelative(BuildContext context, String? targetId) {
    if (targetId == null) return;
    final uri = GoRouterState.of(context).uri;
    // Preserve the current screen mode while keyboard-stepping rows: if
    // we're on an edit form, the next/prev row should open its edit
    // form too (not silently flip to the read-only detail screen).
    // `uri.replace(path:)` already carries the `?view` query param.
    final isEdit = uri.path.endsWith('/edit');
    final newPath = isEdit ? '$basePath/$targetId/edit' : '$basePath/$targetId';
    final next = uri.replace(path: newPath);
    GoRouter.of(context).go(next.toString());
  }

  @override
  Widget build(BuildContext context) {
    // Edit / create forms vs the read-only detail screen. Used only for
    // the screen-reader announcement (no visible verb in the chrome).
    final path = GoRouterState.of(context).uri.path;
    final isEditing = path.endsWith('/edit') || path.endsWith('/new');
    // Viewport-aware chrome. On a narrow viewport the pane is full-page, so
    // the desktop full-screen toggle is meaningless and the X is replaced by
    // a mobile-standard leading back arrow. On wide the pane floats as a
    // slide-over and keeps the trailing full-screen-toggle + X.
    final Widget? actionsRow = isNarrow
        ? null
        : _PaneActionsRow(
            basePath: basePath,
            isFullScreen: isFullScreen,
            onClose: () => _close(context),
          );
    final Widget? leading = isNarrow
        ? IconButton(
            tooltip: context.tr('back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _close(context),
          )
        : null;
    // Publish the chrome through the scope so the embedded screen's inline
    // header places it alongside its own actions (Edit / Archive / Save).
    // One unified pane handles both slide-over and full-screen.
    return MasterDetailPaneScope(
      paneActions: actionsRow,
      paneLeading: leading,
      // Single-key pane shortcuts (F / J / K / ↑ / ↓ / Esc). Routed
      // through Shortcuts + Actions rather than a bare CallbackShortcuts
      // so they can stand down while a text input has focus — otherwise
      // typing `f` in the embedded edit form would toggle full-screen
      // instead of inserting the letter. `_PaneAction` is *disabled*
      // (not merely no-op) when an EditableText is focused, which makes
      // ShortcutManager return KeyEventResult.ignored so the keystroke
      // falls through to the field. See the plan write-up for the
      // Flutter-source rationale (consumesKey defaults to true).
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): _PaneCloseIntent(),
          SingleActivator(LogicalKeyboardKey.keyF):
              _PaneToggleFullScreenIntent(),
          SingleActivator(LogicalKeyboardKey.keyJ): _PaneNextIntent(),
          SingleActivator(LogicalKeyboardKey.arrowDown): _PaneNextIntent(),
          SingleActivator(LogicalKeyboardKey.keyK): _PanePrevIntent(),
          SingleActivator(LogicalKeyboardKey.arrowUp): _PanePrevIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _PaneCloseIntent: GuardedShortcutAction<_PaneCloseIntent>(
              onInvoke: (_) {
                _close(context);
                return null;
              },
            ),
            _PaneToggleFullScreenIntent:
                GuardedShortcutAction<_PaneToggleFullScreenIntent>(
                  onInvoke: (_) {
                    _toggleFullScreenInUrl(context, isFullScreen: isFullScreen);
                    return null;
                  },
                ),
            _PaneNextIntent: GuardedShortcutAction<_PaneNextIntent>(
              onInvoke: (_) {
                _navigateRelative(context, navController.nextId());
                return null;
              },
            ),
            _PanePrevIntent: GuardedShortcutAction<_PanePrevIntent>(
              onInvoke: (_) {
                _navigateRelative(context, navController.prevId());
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Semantics(
              container: true,
              label: context.tr(
                isEditing ? 'editing_pane_opened' : 'viewing_pane_opened',
              ),
              // The embedded screen content. Mounted directly — no
              // AnimatedSwitcher (see class-level doc for why) and no
              // floating chrome overlay (the embedded scaffold owns
              // the inline header that hosts our pane actions).
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _PaneActionsRow extends StatelessWidget {
  const _PaneActionsRow({
    required this.basePath,
    required this.isFullScreen,
    required this.onClose,
  });

  final String basePath;
  final bool isFullScreen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Material(
      color: tokens.bg.withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(InRadii.r2),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: isFullScreen
                  ? context.tr('exit_full_screen')
                  : context.tr('open_in_full_screen'),
              icon: Icon(
                isFullScreen ? Icons.close_fullscreen : Icons.open_in_full,
                size: 18,
              ),
              onPressed: () =>
                  _toggleFullScreenInUrl(context, isFullScreen: isFullScreen),
              splashRadius: 18,
            ),
            IconButton(
              tooltip: context.tr('close'),
              icon: const Icon(Icons.close, size: 18),
              onPressed: onClose,
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared URL helpers ─────────────────────────────────────────────────

/// Flip the `?view=full` query param on the active URL. Used by the
/// pane's `F` keyboard shortcut, the `open_in_full` / `close_fullscreen`
/// icon button, and the automatic screen-type-default redirect — all
/// must produce identical URLs.
///
/// The choice is **not** remembered: it only rewrites the current URL
/// for this exact screen. There is no per-entity stickiness, and the
/// `view` param is stripped before the route is persisted (see
/// `NavStatePersister`), so the next screen / next launch always
/// resolves fresh from [_resolveDesiredMode].
///
/// `Uri.replace(queryParameters: null)` *keeps* the existing query params
/// (per Dart's docs — it only "replaces" non-null fields). Pass the map
/// directly: an empty map clears the query string.
///
/// **Propagates `state.extra` through the internal `go(...)`.** Cross-
/// entity and clone callers seed the edit draft via the route's `extra`
/// payload (e.g. Client → "New Invoice" passes `emptyInvoice().copyWith(
/// clientId: ...)`); a bare `go(next)` here would silently drop the
/// seed when the auto-promote post-frame redirect fires, opening an
/// empty form. Re-attach the current state's extra so the rewritten URL
/// carries the same payload it arrived with.
void _toggleFullScreenInUrl(
  BuildContext context, {
  required bool isFullScreen,
}) {
  final state = GoRouterState.of(context);
  final uri = state.uri;
  final params = Map<String, String>.from(uri.queryParameters);
  if (isFullScreen) {
    params.remove('view');
  } else {
    params['view'] = 'full';
  }
  // `uri.replace(queryParameters: {})` leaves an empty query in the resulting
  // URI — `toString()` then emits a bare trailing `?`. Drop the trailing
  // separator by re-building the URI without a query when the map is empty,
  // so de-promotion to slide yields `/things/1/edit`, not `/things/1/edit?`.
  final next = params.isEmpty
      ? Uri(path: uri.path, fragment: uri.hasFragment ? uri.fragment : null)
      : uri.replace(queryParameters: params);
  GoRouter.of(context).go(next.toString(), extra: state.extra);
}

/// Navigate to an entity's create route. No-op when the create route is
/// already the active screen — re-issuing a bare `go(route)` would strip
/// the auto-applied `?view=full` and degrade the full-screen editor to the
/// slide-over panel (the redirect dedup won't re-promote it). `route`
/// carries no query, so compare against `matchedLocation`.
void goToCreateRoute(BuildContext context, String route) {
  // Bump the create route's seed generation (and clear any stale staged draft)
  // so the keyed `/new` route recreates the create screen — a blank "New" even
  // when a seeded create was left mounted (go_router would reuse it otherwise).
  final basePath = route.endsWith('/new')
      ? route.substring(0, route.length - '/new'.length)
      : route;
  context.read<Services>().stageCreateDraft(basePath, null);
  if (GoRouterState.of(context).matchedLocation == route) return;
  GoRouter.of(context).go(route);
}

/// Post-save navigation for an entity edit/create screen hosted in a
/// [MasterDetailLayout]. After a **create**, route to the new row's detail
/// screen — full-width (`?view=full`) when this entity's editor opened
/// full-width (see [editOpensFullWidth]), so the record stays on the wide
/// canvas the user just saved from instead of collapsing into the narrow
/// slide-over preview. After an **edit**, pop back where they came from.
///
/// `?view=full` is harmless for the slide-over entities (we don't append it)
/// and on narrow viewports (the layout ignores `viewMode` there and always
/// renders full-page); `NavStatePersister` strips `view` before persisting,
/// so a restart still resolves the detail fresh to the slide-over preview.
void goAfterEntitySave(
  BuildContext context, {
  required bool isCreate,
  required String basePath,
  required String savedId,
}) {
  if (!isCreate) {
    context.pop();
    return;
  }
  final detail = '$basePath/$savedId';
  context.go(editOpensFullWidth(basePath) ? '$detail?view=full' : detail);
}

// ─── Width math + pane scope marker ──────────────────────────────────────

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _paneWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return (w * 0.45).clamp(440.0, 560.0);
}

/// [InheritedWidget] published by `_PaneRoot` so embedded scaffolds
/// (`EntityDetailScaffold`, `EntityEditScaffold`, …) can both detect
/// that they're rendered inside a master-detail pane and read the
/// chrome they're expected to surface — the X + full-screen toggle
/// icons. When the scope is present:
///   * Scaffolds suppress their outer `Scaffold` + `AppBar` (see
///     [isInPane]).
///   * Scaffolds append [paneActions] to the right end of their inline
///     header row so the icons live in the same strip as Save / Edit
///     and don't float on top of the screen's content (see
///     [paneActionsOf]).
class MasterDetailPaneScope extends InheritedWidget {
  const MasterDetailPaneScope({
    super.key,
    this.paneActions,
    this.paneLeading,
    required super.child,
  });

  /// The full-screen toggle + X row that embedded scaffolds should place at
  /// the trailing end of their inline header. Supplied by `_PaneRoot` on wide
  /// viewports; null on narrow (where [paneLeading] carries the chrome).
  final Widget? paneActions;

  /// The mobile-standard leading back arrow that embedded scaffolds should
  /// place at the **start** of their inline header. Supplied by `_PaneRoot` on
  /// narrow viewports (the pane is full-page there); null on wide (where
  /// [paneActions] carries the trailing chrome).
  final Widget? paneLeading;

  static bool isInPane(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MasterDetailPaneScope>() !=
      null;

  static Widget? paneActionsOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MasterDetailPaneScope>()
      ?.paneActions;

  static Widget? paneLeadingOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MasterDetailPaneScope>()
      ?.paneLeading;

  @override
  bool updateShouldNotify(MasterDetailPaneScope oldWidget) =>
      paneActions != oldWidget.paneActions ||
      paneLeading != oldWidget.paneLeading;
}

// ─── Pane keyboard shortcuts ─────────────────────────────────────────────

// Single-key pane shortcuts (F / J / K / arrows / Esc) stand down while
// the user is typing — typing `f` in the embedded edit form must insert
// `f`, not toggle full-screen. The actions wrap [GuardedShortcutAction]
// from `lib/ui/core/utils/text_input_focus.dart`, which disables itself
// (and overrides `consumesKey`) whenever a text input has focus. See
// the comment on the `Shortcuts` widget above for the Flutter-source
// rationale (consumesKey defaults to true, so a no-op `onInvoke` is
// not enough — the action must report as *disabled*).

class _PaneCloseIntent extends Intent {
  const _PaneCloseIntent();
}

class _PaneToggleFullScreenIntent extends Intent {
  const _PaneToggleFullScreenIntent();
}

class _PaneNextIntent extends Intent {
  const _PaneNextIntent();
}

class _PanePrevIntent extends Intent {
  const _PanePrevIntent();
}
