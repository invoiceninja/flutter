import 'package:flutter/widgets.dart';

/// Whether [primary] is somewhere the host considers stale — focus that is
/// technically below [FocusOwnerKeeper.node] but belongs to a surface the user
/// is no longer looking at. Optional; hosts with no such notion omit it.
typedef StaleFocusTest = bool Function(FocusNode? primary);

/// Keeps [node] as a surface's resting focus owner, so the `Shortcuts` mounted
/// above it cannot be switched off by a focus change nobody made on purpose.
///
/// Flutter dispatches a key event **only** from `FocusManager.primaryFocus`
/// *upward* (`focus_manager.dart` `_handleKeyMessage`: an early `return false`
/// when it is null, then a walk over `[primaryFocus, ...primaryFocus.ancestors]`
/// — ancestors, never descendants). A `Shortcuts` widget is therefore only ever
/// *walked past*: it mounts a `Focus(canRequestFocus: false, skipTraversal:
/// true)`, so it needs something **below** it holding primary focus and can
/// never supply that itself. Two surfaces in this app depend on that and had no
/// reliable owner:
///
///  * `ScaffoldWithNav`, whose leader `Focus` carries the whole app's keyboard
///    layer — the global `Shortcuts` map, the `G` chords, and every per-screen
///    `Shortcuts` below them. On macOS a key that reaches nothing falls through
///    to `[super keyDown:]` → `NSResponder.noResponderFor:` → **NSBeep**, which
///    is the only outward sign.
///  * `EntityListScreenScaffold`, whose `N` / `↑` / `↓` / per-entity
///    `selectionShortcuts` only ever fired after the user had clicked or tabbed
///    into the list, because a freshly opened list focuses nothing and primary
///    focus sits on an *ancestor* — the shell's node, or the branch route's
///    `FocusScopeNode`.
///
/// **`Focus(autofocus: true)` is not enough, and that is the whole reason this
/// exists.** `_FocusState` applies autofocus exactly once (`_didAutofocus`) and
/// `_Autofocus.applyIfValid` additionally requires the enclosing scope to have
/// no focused child — so it is silently dropped whenever the surface mounts
/// into a scope that has already focused something (a hot reload, a list
/// rebuilt under a route that already existed), and it can never re-fire after
/// focus is lost. Four ordinary framework paths lose it and none come back:
///
///  1. **A focused node is disposed.** `_markDetached` nulls `_primaryFocus`
///     and `applyFocusChangesIfNeeded` falls back to `rootScope`, whose
///     `ancestors` is empty. Closing a detail pane disposes `_PaneRoot`'s own
///     autofocus node; any route pop disposes its `_ModalScope` focus scope.
///  2. **`FocusNode.unfocus()`**, whose default `UnfocusDisposition.scope`
///     clears the scope's remembered children and parks focus *on the scope
///     itself* — both edit-save paths call it to flush an unblurred field, and
///     navigating away then disposes that scope, i.e. case 1.
///  3. **A route popped off the root navigator**, where `_ModalScopeState`'s
///     `setFirstFocus` resolves to the shell page's own `FocusScopeNode` once
///     its remembered `focusedChild` is gone.
///  4. **App-lifecycle suspend**, which parks focus on `rootScope` and restores
///     `_suspendedNode` on resume only if that node is still alive.
///
/// Four things here are load-bearing. **The escape test asks for the
/// *direction* focus went, never just "is it below me"** — see [_escaped]: focus
/// above the node (an ancestor scope, the root scope, a detached node) is the
/// failure this repairs, while focus *beside* it (a dialog or sheet on any
/// navigator, the master-detail pane, a create form) belongs to a surface that
/// chose it. A test of the form `!primary.ancestors.contains(node)` answers both
/// with "escaped" and makes the keeper steal from whatever is beside it.
/// **It stands down while the app is not `resumed`**, or it would beat the
/// framework's own suspend/restore and blur whatever the user was typing in when
/// they switched away. **It also stands down while a route above [node] is
/// current** — a cheap extra guard, and deliberately *not* the one that protects
/// a dialog: `ModalRoute.of` resolves to the nearest navigator, so for a host
/// inside a `StatefulShellRoute` branch it never sees a `showDialog` on the root
/// navigator at all. The direction test is what covers that, on every navigator.
/// And it re-checks **post-frame, one pending check at a time**, because focus
/// moves in bursts: a route push lifts it above the host and drops it back
/// inside the same frame, and acting on the intermediate state would fight the
/// framework.
///
/// There is no loop risk, and no fight between two keepers: a `requestFocus`
/// that cannot land fires no `FocusManager` notification, and a nested keeper
/// claiming its own node necessarily satisfies every keeper above it (its node
/// is below theirs). Two keepers that could both claim over the *same* focus
/// must therefore never be [enabled] at once — which is what the list's gate on
/// `TickerMode` (one branch on stage) and on an open pane is for.
///
/// Pure passthrough — no layout, no painting.
class FocusOwnerKeeper extends StatefulWidget {
  const FocusOwnerKeeper({
    required this.node,
    required this.child,
    this.enabled = true,
    this.revision = 0,
    this.focusIsStale,
    this.canClaim,
    super.key,
  });

  /// The surface's resting focus owner — the same node the `Focus` below this
  /// widget is built with.
  final FocusNode node;

  /// Whether this surface should own focus at all. A host that can be off
  /// stage, covered, or otherwise not the thing the user is looking at passes
  /// `false` there; the keeper then does nothing until it flips back.
  final bool enabled;

  /// Bump to force a re-check. Only a *trigger*, for a change that need not
  /// move focus at all and so would prompt nothing on its own — the shell
  /// passes its active branch index. The tests below are stateless, so there is
  /// no flag to leave armed.
  final int revision;

  /// See [StaleFocusTest]. Null means focus below [node] is always fine.
  final StaleFocusTest? focusIsStale;

  /// A last guard, evaluated **at check time** rather than at build time — for
  /// a condition the host would rather not subscribe to. The list passes
  /// "no master-detail pane is open": subscribing to that would rebuild the
  /// whole list scaffold on every row click, and it does not need to, because
  /// the check is only ever reached from a `FocusManager` notification and
  /// closing a pane always moves focus.
  final bool Function()? canClaim;

  final Widget child;

  @override
  State<FocusOwnerKeeper> createState() => _FocusOwnerKeeperState();
}

class _FocusOwnerKeeperState extends State<FocusOwnerKeeper>
    with WidgetsBindingObserver {
  bool _scheduled = false;

  /// Whether the nearest enclosing route is the current one. False while a
  /// dialog / sheet / palette is open above this surface.
  bool _routeIsCurrent = true;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
    // A route closing above us is precisely when focus needs rescuing, and it
    // does not necessarily move focus at all (case 3 above leaves it on a scope
    // that is merely an ancestor) — so re-check on the transition. Reading
    // `ModalRoute.of` here is also what subscribes us to it.
    _schedule();
  }

  @override
  void didUpdateWidget(FocusOwnerKeeper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision ||
        oldWidget.enabled != widget.enabled ||
        !identical(oldWidget.node, widget.node)) {
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // While suspended the framework deliberately parks focus on `rootScope`
    // and will restore `_suspendedNode` on resume, so [_reclaim] stands down
    // there. Re-check once we are back: if that stashed node was disposed in
    // the meantime the framework gives up silently and leaves us stranded.
    if (state == AppLifecycleState.resumed) _schedule();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() => _schedule();

  /// True when primary focus has drifted somewhere the handlers above
  /// [FocusOwnerKeeper.node] can never see it, *and* nobody else owns it.
  ///
  /// The distinction is the whole correctness of this widget, because "focus is
  /// not below me" covers two situations that want opposite treatment:
  ///
  ///  * **Above** — an ancestor scope, the root scope, or a node detached from
  ///    the tree (`parent == null`). Key dispatch walks up from `primaryFocus`
  ///    and never down, so nothing below this point can see a key again. That
  ///    is the failure this widget exists to repair, and nobody chose it.
  ///  * **Beside** — a dialog or sheet on *any* navigator, the master-detail
  ///    pane, a create form. A real surface owns focus there on purpose, and
  ///    stealing it blurs a field the user is typing in.
  ///
  /// This used to be the single expression `!primary.ancestors.contains(node)`,
  /// which returns true for both, leaving [_routeIsCurrent] as the only thing
  /// standing between the keeper and a surface beside it. That check reads
  /// `ModalRoute.of(context)`, which resolves to the **nearest** navigator — and
  /// the entity list's nearest route is its `StatefulShellRoute` branch page,
  /// whose `isCurrent` is per-navigator and so stays true for the whole life of
  /// a `showDialog` (which defaults to `useRootNavigator: true`). Note the
  /// inversion that produced: `showModalBottomSheet` defaults to the nearest
  /// navigator, so sheets disarmed the keeper and dialogs did not. Asking the
  /// direction question here fixes every navigator at once and needs nothing
  /// from the host. Pinned by the `a nested navigator` group in
  /// `focus_owner_keeper_test.dart`.
  bool _escaped(FocusNode? primary) {
    if (primary == null) return true;
    if (identical(primary, widget.node)) return false;
    // Below us: the resting state, and anything this surface focused itself.
    if (primary.ancestors.contains(widget.node)) return false;
    // **Our own node is not attached yet, so the direction cannot be read.**
    // [_schedule] evaluates this synchronously from [didChangeDependencies] —
    // during this widget's first build, before the child `Focus` has reparented
    // the node — and an unattached node has no `parent` and an empty
    // `ancestors`, so the "above" arm below would answer "beside" for a *live
    // ancestor* and decline. Nothing would re-arm: `didChangeDependencies` does
    // not re-run, `didUpdateWidget` sees no change, and attaching a node fires
    // no `FocusManager` notification.
    //
    // Answering "escaped" here is free — [_reclaim] re-runs this test post-frame
    // with the node attached — and it is what keeps the surface-mounts-with-focus
    // -already-above case working: a list rebuilt under a route that already
    // existed, which is how the Tasks view toggle swaps its body (it `go`s an
    // unchanged location, so there is no route push and no focus change at all).
    if (widget.node.parent == null) return true;
    // Above us, or orphaned. `parent == null` is both the root scope and a node
    // that has been detached, which is where `_markDetached` can leave things.
    if (primary.parent == null || widget.node.ancestors.contains(primary)) {
      return true;
    }
    // Beside us. Left alone — [FocusOwnerKeeper.focusIsStale] is how a host
    // says that a *particular* sibling is nonetheless stale (the shell uses it
    // for focus left behind in an off-stage branch).
    return false;
  }

  bool _needsCheck() {
    final primary = FocusManager.instance.primaryFocus;
    return _escaped(primary) || (widget.focusIsStale?.call(primary) ?? false);
  }

  /// The states in which focus outside this surface is somebody else's on
  /// purpose. Checked before scheduling as well as inside the callback: each
  /// has an event that re-runs the check when it clears ([didChangeDependencies]
  /// for the route, [didUpdateWidget] for [enabled], [didChangeAppLifecycleState]
  /// for the lifecycle), and `SchedulerBinding` disables frames outright while
  /// paused, so a scheduled check would not run there anyway.
  bool get _canReclaimNow {
    if (!widget.enabled || !_routeIsCurrent) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return false;
    }
    return widget.canClaim?.call() ?? true;
  }

  void _schedule() {
    if (_scheduled || !_canReclaimNow || !_needsCheck()) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _reclaim();
    });
    // A post-frame callback only runs after a frame, and a focus change on an
    // idle screen need not schedule one.
    WidgetsBinding.instance.scheduleFrame();
  }

  void _reclaim() {
    if (!mounted) return;
    if (!_canReclaimNow) return;
    if (!widget.node.canRequestFocus) return;
    if (!_needsCheck()) return;
    // Safe before the `Focus` below has attached the node: `_doRequestFocus`
    // latches `_requestFocusWhenReparented` and applies it on reparent.
    widget.node.requestFocus();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
