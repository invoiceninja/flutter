import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/data/repositories/ensure_loaded_outcome.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';
import 'package:admin/ui/core/detail/detail_tab_navigator.dart';
import 'package:admin/ui/core/detail/entity_detail_actions_row.dart';
import 'package:admin/ui/core/detail/generic_detail_view_model.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/utils/text_input_focus.dart';
import 'package:admin/ui/core/widgets/empty_state.dart';
import 'package:admin/ui/core/widgets/focus_owner_keeper.dart';

/// Shared chrome for an entity detail screen.
///
/// Owns the Scaffold + AppBar + loading/empty/content states that every
/// entity detail page wants. Concrete screens supply:
///   * a [GenericDetailViewModel] (`ClientDetailViewModel`, …)
///   * [actionsForItem]   — the AppBar title/actions widget per item
///     (typically the entity's actions row)
///   * [emptyTitle] + [emptyIcon] — shown when the watch stream resolves
///     to null (entity deleted, deep-linked to nonexistent id)
///   * [bodyBuilder] — renders the cards/sections for a resolved item
class EntityDetailScaffold<T> extends StatefulWidget {
  const EntityDetailScaffold({
    super.key,
    required this.id,
    required this.vm,
    required this.bodyBuilder,
    required this.emptyTitle,
    this.emptySubtitle,
    this.emptyIcon = Icons.search_off_outlined,
    this.emptyAction,
    this.hydrate,
    this.actionsForItem,
    this.compactTitleForItem,
    this.bannerForItem,
    this.isReadOnly,
    this.onRefresh,
    this.embedded = false,
  });

  /// The record's id. Used ONLY to look up a synchronous first-frame seed
  /// from the master-detail list snapshot (see [_EntityDetailScaffoldState.
  /// _seed]) — the screen still binds its own VM from its own id, and
  /// nothing else here reads this.
  final String id;

  final GenericDetailViewModel<T> vm;
  final Widget Function(BuildContext context, T item) bodyBuilder;
  final String emptyTitle;
  final String? emptySubtitle;
  final IconData emptyIcon;

  /// Optional escape hatch rendered under the empty state — typically a
  /// `Go to <list>` button. A record can legitimately not resolve (deleted
  /// server-side, outside this user's permissions, a stale shared link), and
  /// without this the screen is a dead end.
  final Widget? emptyAction;

  /// Optional one-shot fetch for a record that isn't in the local cache,
  /// invoked once from `initState` (typically `repo.ensureLoaded`).
  ///
  /// The scaffold shows its resolving spinner for the duration instead of the
  /// empty state. That matters more than it looks: [GenericDetailViewModel]
  /// clears `isResolving` on the FIRST Drift emission, and for an uncached
  /// record that emission is `null` — so without this the screen flashes
  /// "not found" for the length of the network round-trip and then flips to
  /// content. A deep-link recipient hits that path every time, since the whole
  /// point is that they have never browsed to the record.
  ///
  /// Typed `Future<Object?>` so a repository's `ensureLoaded` — declared
  /// `Future<void>`, but returning an [EnsureLoadedOutcome] — can say what
  /// happened. When the record does not turn up, that is the difference
  /// between "not found" and "could not reach the server, Retry". A hydrate
  /// that returns anything else is treated as before.
  final Future<Object?> Function()? hydrate;

  /// A strip pinned above the scrolling body — outside it, so it does not
  /// scroll away — for a state the whole record is in: deleted, archived, not
  /// yet synced. Return null for the ordinary record.
  final Widget? Function(BuildContext context, T item)? bannerForItem;

  /// Whether [item] cannot be edited (a soft-deleted record). Gates the `E`
  /// shortcut, which used to open the edit screen on a record the server
  /// would then refuse to save.
  final bool Function(T item)? isReadOnly;

  /// Re-fetches the record. Bound to `R` here; the body wires the same
  /// callback to its pull-to-refresh.
  final Future<void> Function()? onRefresh;

  /// Optional builder for the AppBar's title slot — usually an entity
  /// actions row. Receives the resolved item; not called while resolving
  /// or in the empty state. In embedded mode this widget is rendered as
  /// a thin header strip in place of the AppBar.
  final Widget Function(BuildContext context, T item)? actionsForItem;

  /// Optional compact identity for the fixed bar — a name and the one figure
  /// that matters — faded in once the page has scrolled the real header away
  /// and out again at the top. Tapping it scrolls back to the top.
  ///
  /// With a long embedded list the header is several screens up, and without
  /// this nothing on screen says whose list it is.
  ///
  /// Its width is reserved whether or not it is showing. The action cluster
  /// beside it decides between its spread and compact forms from the width it
  /// is given, so a title that only took room while visible would reshuffle
  /// the buttons every time the user scrolled past the threshold.
  final Widget Function(BuildContext context, T item)? compactTitleForItem;

  /// When `true`, the scaffold returns only the body — no outer
  /// `Scaffold`, no `AppBar`. Used when this screen is hosted inside
  /// another container (e.g. the `MasterDetailLayout` right pane on
  /// wide desktop) so the parent's chrome isn't duplicated. The actions
  /// row, if any, renders as an inline header strip above the body.
  final bool embedded;

  @override
  State<EntityDetailScaffold<T>> createState() =>
      _EntityDetailScaffoldState<T>();
}

class _EntityDetailScaffoldState<T> extends State<EntityDetailScaffold<T>> {
  // Owns the detail page's scroll. Published via [DetailScrollScope] so an
  // embedded related-entity list can drive its pagination off this scroll
  // (the embedded list shrink-wraps and no longer scrolls itself).
  final ScrollController _outerScroll = ScrollController();

  /// True while [EntityDetailScaffold.hydrate] is in flight.
  bool _hydrating = false;

  /// The `[` / `]` channel to whichever tab strip the body mounts.
  final DetailTabNavigator _tabNavigator = DetailTabNavigator();

  /// Whether the page has scrolled far enough to hide the header — drives
  /// [EntityDetailScaffold.compactTitleForItem]. A notifier so a scroll frame
  /// rebuilds one opacity, not the scaffold.
  final ValueNotifier<bool> _headerScrolledAway = ValueNotifier<bool>(false);

  void _onOuterScroll() {
    if (!_outerScroll.hasClients) return;
    _headerScrolledAway.value =
        _outerScroll.offset > kDetailCompactTitleRevealOffset;
  }

  /// The row the user just clicked, read synchronously from the list's last
  /// snapshot so a row-to-row swap in the master-detail pane paints the new
  /// record in the SAME frame.
  ///
  /// Without it the pane blinks on every click: the router re-keys this
  /// subtree per `:id` (`router.dart`), so a click builds a fresh VM whose
  /// item is null until Drift's first (asynchronous) emission — which means
  /// a full-pane spinner, and a header that collapses to bare padding and
  /// re-grows as the action cluster leaves and returns.
  ///
  /// Null when the list never rendered this row (deep link, command palette,
  /// cold start) or when there's no master-detail layout at all (the
  /// settings-hosted detail screens); those keep the spinner.
  T? _seed;

  @override
  void initState() {
    super.initState();
    // `maybeOf` uses `getInheritedWidgetOfExactType`, which registers no
    // dependency and is therefore legal here. `is T` rather than a cast:
    // the scope is per entity branch, but a bad seed must degrade to "no
    // seed", never throw.
    final seed = MasterDetailNavScope.maybeOf(context)?.itemById(widget.id);
    _seed = seed is T ? seed : null;
    _outerScroll.addListener(_onOuterScroll);
    _runHydrate();
  }

  /// What the last hydrate reported, when it reported anything — see
  /// [EntityDetailScaffold.hydrate].
  EnsureLoadedOutcome? _outcome;

  /// Runs [EntityDetailScaffold.hydrate], from `initState` and again from the
  /// Retry button.
  void _runHydrate() {
    final hydrate = widget.hydrate;
    if (hydrate == null) return;
    _hydrating = true;
    _outcome = null;
    // `ensureLoaded` handles its own errors, but `hydrate` is a public
    // parameter — a caller that passes something else must not turn a failed
    // *prefetch* into an unhandled async error (a zone error, a diagnostics
    // entry and a Sentry report from a screen that merely didn't warm up).
    // A cache hit is fast but not synchronous: it still awaits one Drift read.
    hydrate()
        .then<void>((value) {
          if (value is EnsureLoadedOutcome) _outcome = value;
        })
        .catchError((Object _) {
          _outcome = EnsureLoadedOutcome.failed;
        })
        .whenComplete(() {
          if (!mounted) return;
          // `_hydrating` is read by the spinner gate ONLY while the item is
          // null. Once content has painted, a setState here changes nothing
          // visible but re-runs every descendant that builds a Drift stream
          // inside `build` — each fresh stream resets its StreamBuilder to
          // `AsyncSnapshot.nothing()` and blanks rows that were already
          // correct.
          if (_resolveItem() == null) {
            setState(() => _hydrating = false);
          } else {
            _hydrating = false;
          }
        });
  }

  @override
  void didUpdateWidget(EntityDetailScaffold<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The seed is valid only for the VM's FIRST resolving cycle, so the
    // condition that actually matters is a new `vm` — a caller handing over a
    // fresh one (same id) would restart `isResolving` and re-show the stale
    // seed. An id change implies it; both are checked because neither happens
    // today (both route trees re-key on `:id`, so a change arrives as a fresh
    // State) and the cheap guard is the one that survives that changing.
    if (oldWidget.id != widget.id || oldWidget.vm != widget.vm) _seed = null;
  }

  /// The record to render. [_seed] is consulted ONLY before the watch
  /// stream's first emission, so a record that genuinely resolves to null
  /// (deleted server-side, no permission) still falls through to the empty
  /// state instead of being resurrected from the list snapshot.
  T? _resolveItem() => widget.vm.item ?? (widget.vm.isResolving ? _seed : null);

  /// This screen's resting focus owner — see the `FocusOwnerKeeper` in
  /// [build]. Retained, because an anonymous node cannot be re-focused.
  final FocusNode _bodyFocus = FocusNode(debugLabel: 'entity-detail');

  /// True while a refresh started from the keyboard is in flight.
  bool _refreshing = false;

  /// `R`. One at a time: the refresh is a handful of requests, and a second
  /// press before the first lands would only repeat them.
  void _refreshFromKey() {
    final refresh = widget.onRefresh;
    if (refresh == null || _refreshing) return;
    _refreshing = true;
    // `onRefresh` is the host's; a throw must not become an unhandled async
    // error from a key press (`_runHydrate` defends `hydrate` the same way).
    refresh().catchError((Object _) {}).whenComplete(() => _refreshing = false);
  }

  @override
  void dispose() {
    _outerScroll
      ..removeListener(_onOuterScroll)
      ..dispose();
    _headerScrolledAway.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Auto-detect when mounted inside the master-detail right pane —
    // concrete screens never need to pass `embedded: true`. Matches
    // the same convention `EntityEditScaffold` uses.
    final inPane = MasterDetailPaneScope.isInPane(context);
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyE): _EditCurrentIntent(),
        SingleActivator(LogicalKeyboardKey.bracketLeft): _StepTabIntent(-1),
        SingleActivator(LogicalKeyboardKey.bracketRight): _StepTabIntent(1),
        // The same two keys **by character**. On a German, French or Nordic
        // layout a bracket is typed with a modifier — Option on a Mac, AltGr
        // (which arrives as Ctrl+Alt) on Windows and Linux — and a
        // `SingleActivator` accepts neither the physical key nor the
        // modifier, so the bindings above never fire there.
        CharacterActivator('['): _StepTabIntent(-1),
        CharacterActivator('[', alt: true): _StepTabIntent(-1),
        CharacterActivator('[', alt: true, control: true): _StepTabIntent(-1),
        CharacterActivator(']'): _StepTabIntent(1),
        CharacterActivator(']', alt: true): _StepTabIntent(1),
        CharacterActivator(']', alt: true, control: true): _StepTabIntent(1),
        // Not on key-repeat: holding the key would re-run the whole refresh
        // on every repeat event.
        SingleActivator(LogicalKeyboardKey.keyR, includeRepeats: false):
            _RefreshIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          // `[` / `]`: previous / next tab. Disabled — so the key falls
          // through — on a screen whose body mounts no strip.
          _StepTabIntent: _TabStepAction(_tabNavigator),
          // `R`: re-fetch the record. Disabled, so the key falls through, on a
          // screen that has not wired a refresh.
          _RefreshIntent: _RefreshAction(
            canRefresh: () => widget.onRefresh != null,
            refresh: _refreshFromKey,
          ),
          // Single-key `e` shortcut: disable while typing so the
          // keystroke falls through and inserts `e` instead of
          // navigating to the edit screen.
          _EditCurrentIntent: GuardedShortcutAction<_EditCurrentIntent>(
            onInvoke: (_) {
              final item = _resolveItem();
              if (item == null) return null;
              // A deleted record cannot be saved; do not open a form for it.
              if (widget.isReadOnly?.call(item) ?? false) return null;
              // Universal: detail routes follow `/<entity>/:id`, edit is
              // the sibling `/<entity>/:id/edit`. Appending `/edit` to
              // the current URL is correct for every entity that goes
              // through `_entityRoutes` in `lib/app/router.dart`. The
              // scaffold isn't mounted on `/new` or `/edit` paths, so
              // this can't produce `/edit/edit`.
              final state = GoRouterState.of(context);
              context.go('${state.uri.path}/edit');
              return null;
            },
          ),
        },
        // **The map above is never consulted without this.** Flutter offers a
        // key to `primaryFocus` and its ancestors, never to descendants, and
        // a record opens with focus on the route's own scope or the pane's
        // root node — both *above* this `Shortcuts`. So `E`, `[`, `]` and `R`
        // did nothing until the user happened to click into the body. A
        // retained node behind a keeper, not `autofocus: true`, which fires
        // once and is dropped whenever the scope already focused something
        // (`docs/keyboard.md` § The whole keyboard layer hangs off one focus
        // node). The keeper only takes back focus that went *up*; a field, a
        // dialog or a sheet keeps what it took. Gated on `TickerMode` so a
        // record left mounted behind another branch does not claim.
        child: FocusOwnerKeeper(
          node: _bodyFocus,
          enabled: TickerMode.valuesOf(context).enabled,
          child: Focus(
            focusNode: _bodyFocus,
            child: ListenableBuilder(
              listenable: widget.vm,
              builder: (context, _) {
                final item = _resolveItem();
                if (widget.embedded || inPane) {
                  return _embeddedBody(context, item);
                }
                return Scaffold(
                  appBar: AppBar(
                    titleSpacing: InSpacing.lg(context),
                    title: (item != null && widget.actionsForItem != null)
                        ? _withCompactTitle(
                            context,
                            item,
                            widget.actionsForItem!(context, item),
                          )
                        : null,
                  ),
                  body: _stateBody(context, item),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Embedded variant: stack a thin actions header above the same body
  /// switcher. No Scaffold / AppBar — the host shell owns the chrome.
  /// When mounted inside the slide-over pane, the pane's X + full-
  /// screen icons published via [MasterDetailPaneScope] are appended
  /// to the right of the row so they share the strip with the
  /// entity's own action buttons.
  Widget _embeddedBody(BuildContext context, T? item) {
    final tokens = context.inTheme;
    final paneActions = MasterDetailPaneScope.paneActionsOf(context);
    // Narrow viewport: the pane publishes a leading back arrow (and no
    // trailing X / full-screen toggle). Render it at the start of the header.
    final paneLeading = MasterDetailPaneScope.paneLeadingOf(context);
    final hasHeaderContent = item != null && widget.actionsForItem != null;
    final showHeader =
        hasHeaderContent || paneActions != null || paneLeading != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader)
          Container(
            padding: EdgeInsetsDirectional.only(
              start: paneLeading != null ? 4 : InSpacing.lg(context),
              end: InSpacing.lg(context),
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: tokens.border)),
            ),
            child: Row(
              children: [
                if (paneLeading != null) paneLeading,
                if (hasHeaderContent)
                  Expanded(
                    child: _withCompactTitle(
                      context,
                      item,
                      widget.actionsForItem!(context, item),
                    ),
                  )
                else
                  const Spacer(),
                if (paneActions != null) paneActions,
              ],
            ),
          ),
        Expanded(child: _stateBody(context, item)),
      ],
    );
  }

  /// Lays the compact title to the left of the action cluster — see
  /// [EntityDetailScaffold.compactTitleForItem].
  ///
  /// Two regimes, split on the form the cluster takes:
  ///
  ///  * **Spread** (the cluster's share is wide): the title's width is
  ///    reserved up front. The spread bar counts how many buttons fit the
  ///    width it is given, so a title that only took room while visible would
  ///    reshuffle them every time the user scrolled past the threshold.
  ///  * **Compact** (a pane or a phone): the cluster is one primary button and
  ///    `⋮`, a fixed size, so it is laid out first **at its own width** and
  ///    the title gets what is left — or is not offered when that is too
  ///    little. The title's width used to be reserved here too, on the
  ///    assumption that the primary is "Edit"; an invoice's is "Enter
  ///    Payment", and on a small phone at large text the reservation pushed
  ///    it off the bar.
  Widget _withCompactTitle(BuildContext context, T item, Widget actions) {
    final builder = widget.compactTitleForItem;
    if (builder == null) return actions;
    final title = ValueListenableBuilder<bool>(
      valueListenable: _headerScrolledAway,
      builder: (context, shown, child) => IgnorePointer(
        ignoring: !shown,
        child: ExcludeSemantics(
          excluding: !shown,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: child,
          ),
        ),
      ),
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!_outerScroll.hasClients) return;
            _outerScroll.animateTo(
              0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          },
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: builder(context, item),
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final reserved = (constraints.maxWidth * 0.34).clamp(
          kDetailCompactTitleMinWidth,
          kDetailCompactTitleMaxWidth,
        );
        final spread = Breakpoints.isWide(
          BoxConstraints(maxWidth: constraints.maxWidth - reserved),
        );
        if (spread) {
          return Row(
            children: [
              SizedBox(width: reserved, child: title),
              Expanded(child: actions),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, slot) {
                  // Too little left to name anything in: the cluster keeps
                  // the bar and the title is simply not offered.
                  if (slot.maxWidth < kDetailCompactTitleMinWidth) {
                    return const SizedBox.shrink();
                  }
                  return Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: kDetailCompactTitleMaxWidth,
                      ),
                      child: title,
                    ),
                  );
                },
              ),
            ),
            // Told which form to take, and to hug its content, rather than
            // asked to fill a width it is not being given. Capped at the bar,
            // so a cluster wider than that shortens its primary instead of
            // overflowing.
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: ActionBarLayoutScope(wide: false, child: actions),
            ),
          ],
        );
      },
    );
  }

  Widget _stateBody(BuildContext context, T? item) {
    if (item == null && (widget.vm.isResolving || _hydrating)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (item == null) {
      final outcome = _outcome;
      if (outcome != null && outcome.isRetryable) {
        // The record may well exist — it just could not be fetched. Saying
        // "not found" here sent a user with a good link and no signal looking
        // for a record that was never missing.
        final unreachable = outcome == EnsureLoadedOutcome.unreachable;
        return EmptyState(
          icon: unreachable ? Icons.cloud_off_outlined : Icons.error_outline,
          title: context.tr(
            unreachable ? 'no_internet_connection' : 'an_error_occurred',
          ),
          subtitle: unreachable ? context.tr('network_error') : null,
          // Retry beside the host's own way onward ("go to the list"), which
          // a full-page host has no other route to.
          action: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: InSpacing.md(context),
            runSpacing: InSpacing.sm,
            children: [
              FilledButton.tonal(
                // Centred: constrain the width, or the theme's full-width
                // default stretches it edge to edge.
                style: FilledButton.styleFrom(minimumSize: const Size(64, 44)),
                onPressed: () => setState(_runHydrate),
                child: Text(context.tr('retry')),
              ),
              ?widget.emptyAction,
            ],
          ),
        );
      }
      return EmptyState(
        icon: widget.emptyIcon,
        title: widget.emptyTitle,
        subtitle: widget.emptySubtitle,
        action: widget.emptyAction,
      );
    }
    // The record is here, so whatever the last hydrate reported is history.
    // Left set, a record that later disappeared would read "could not be
    // reached" when the truth is that it is gone.
    _outcome = null;
    final bannerFor = widget.bannerForItem;
    final banner = bannerFor?.call(context, item);
    // Publish the page scroll so an embedded related-entity list (rendered
    // inside a detail tab) can drive its pagination off this scroll. Wraps
    // both the standalone and master-detail-embedded body paths. The
    // Builder gives `bodyBuilder` a context *below* the scope so its
    // SingleChildScrollView's `DetailScrollScope.maybeOf` resolves.
    final scoped = DetailTabNavigatorScope(
      navigator: _tabNavigator,
      child: DetailScrollScope(
        controller: _outerScroll,
        child: Builder(
          builder: (context) {
            final body = widget.bodyBuilder(context, item);
            // Desktop/web a11y + keyboard path: make the body's text selectable
            // so keyboard and screen-reader users can select and Cmd/Ctrl+C (the
            // hover copy icon is mouse-only). Skipped on touch, where the value's
            // own tap-to-copy is the path and selection handles would fight it.
            return Env.isMobile ? body : SelectionArea(child: body);
          },
        ),
      ),
    );
    // A host that can show a banner gets this shape **whether or not one is
    // showing**. Returning `scoped` bare when there was none changed the
    // widget under the body the moment a record was archived or restored —
    // which remounted the whole page: scroll back to the top, every tab's
    // filter, search and selection gone, every list refetched.
    if (bannerFor == null) return scoped;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?banner,
        Expanded(child: scoped),
      ],
    );
  }
}

/// How far the page scrolls before the fixed bar takes over the identity —
/// roughly the header's own height, so the two never show at once.
const double kDetailCompactTitleRevealOffset = 72;

/// Bounds on the compact title's width: what is reserved for it beside the
/// spread action bar, and the least (and most) it is given beside the compact
/// one — under the floor there is no room to name anything, and it is not
/// offered.
const double kDetailCompactTitleMinWidth = 120;
const double kDetailCompactTitleMaxWidth = 260;

class _EditCurrentIntent extends Intent {
  const _EditCurrentIntent();
}

class _StepTabIntent extends Intent {
  const _StepTabIntent(this.delta);
  final int delta;
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

/// `R` re-fetches the record — the pointer's answer to pull-to-refresh, which
/// a mouse wheel cannot perform. Takes getters rather than values so it always
/// reads the widget's current callback; the single-flight guard and the error
/// handling live in the state (`_refreshFromKey`).
class _RefreshAction extends GuardedShortcutAction<_RefreshIntent> {
  _RefreshAction({required this.canRefresh, required VoidCallback refresh})
    : super(
        onInvoke: (_) {
          refresh();
          return null;
        },
      );

  final bool Function() canRefresh;

  @override
  bool isEnabled(_RefreshIntent intent) =>
      canRefresh() && super.isEnabled(intent);

  @override
  bool consumesKey(_RefreshIntent intent) =>
      canRefresh() && super.consumesKey(intent);
}

/// [GuardedShortcutAction]'s rules — stand down while typing or mid leader
/// sequence — plus one more: no tab strip, no action. Disabled rather than a
/// no-op for the reason given there: only a *disabled* action lets the key
/// fall through to whoever else might want it.
class _TabStepAction extends GuardedShortcutAction<_StepTabIntent> {
  _TabStepAction(this.navigator)
    : super(
        onInvoke: (intent) {
          navigator.step(intent.delta);
          return null;
        },
      );

  final DetailTabNavigator navigator;

  @override
  bool isEnabled(_StepTabIntent intent) =>
      navigator.hasTabs && super.isEnabled(intent);

  @override
  bool consumesKey(_StepTabIntent intent) =>
      navigator.hasTabs && super.consumesKey(intent);
}
