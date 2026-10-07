import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/core/detail/detail_tab_navigator.dart';
import 'package:admin/ui/core/list/master_detail_nav_scope.dart';
import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';

/// One tab in an [EntityDetailTabs] strip. `label` is the rendered string
/// (already localized); the body is built lazily via [bodyBuilder] so per-tab
/// data fetches don't fire until the user first activates the tab.
class EntityDetailTab {
  const EntityDetailTab({
    required this.label,
    required this.icon,
    required this.bodyBuilder,
    this.id,
    this.count,
  });

  final String label;
  final IconData icon;
  final WidgetBuilder bodyBuilder;

  /// A stable name for this tab (`kInvoicesTabId`, …), so a host can ask for it
  /// by identity instead of by an index that module gating shifts. Optional: a
  /// strip without ids keeps working by position exactly as before.
  final String? id;

  /// How many records sit behind this tab, rendered as a badge beside the
  /// label. **Null means unknown, not zero** — a zero is printed, so the two
  /// never look alike. Pass it only when the number is exact.
  final int? count;
}

/// Host-owned request channel for [EntityDetailTabs.selectTab].
///
/// A plain `ValueNotifier` goes silent on a repeat request: tap the Comments
/// card's `View All`, switch tabs by hand, tap it again — the value never
/// changed, so nothing happens. [select] notifies either way.
class TabSelectionController extends ValueNotifier<int> {
  TabSelectionController([super.initialIndex = 0]);

  String? _requestedId;

  /// The id the last request named, or null when it was positional.
  String? get requestedId => _requestedId;

  void select(int index) {
    _requestedId = null;
    if (value == index) {
      notifyListeners();
    } else {
      value = index;
    }
  }

  /// Asks for the tab whose [EntityDetailTab.id] is [id]. A strip that has no
  /// such tab (its module is off) ignores the request — which is why a caller
  /// that draws an affordance for this should gate it on the same list of ids
  /// the strip was built from.
  ///
  /// A separate method rather than an overload of [select] on purpose:
  /// `comments_surface_wiring_test` reads every `.select(` argument under
  /// `lib/ui` and requires one of the two named index constants.
  void selectId(String id) {
    _requestedId = id;
    notifyListeners();
  }
}

/// Places the strip and the active body. The default stacks them; a host that
/// wants the strip pinned while the body scrolls (`EntityRecordPage`) puts each
/// in its own sliver.
typedef EntityDetailTabsLayoutBuilder =
    Widget Function(BuildContext context, Widget strip, Widget body);

/// A horizontal tab strip with the active tab's body flush below it (no card
/// chrome — see `build`, and `_TabStrip` for why the strip scrolls itself).
/// Extracted from `ClientDetailTabs` so other entity detail screens
/// (Product, Invoice, …) can reuse the same scaffolding.
///
/// Lazy-mount semantics: a tab body is only built the first time the user
/// activates it, then stays alive for the rest of the screen's lifetime
/// (so scroll position + sub-VM state survive tab switches).
class EntityDetailTabs extends StatefulWidget {
  const EntityDetailTabs({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.selectTab,
    this.layoutBuilder,
    this.onReveal,
  });

  final List<EntityDetailTab> tabs;

  /// Which tab a *fresh* pane opens on, when there is no remembered one.
  ///
  /// A structural default, deliberately outranked by
  /// `MasterDetailNavController.lastTab` — all eleven entities that lead with
  /// the Comments + Activity pair pass 2 so the landing tab stays whatever used
  /// to be first, while a user who has picked a tab keeps getting it back. A
  /// real deep-link-to-a-tab would want the opposite precedence and needs this
  /// made nullable so an explicit value can outrank the memory.
  ///
  /// The memory is session-only and keyed on the tab *count*, so reordering a
  /// strip needs no migration: a fresh process has no memory to be off by one.
  /// A strip whose tabs carry ids is remembered by id instead, which survives
  /// the count changing too.
  final int initialIndex;

  /// Pushed-to by a host that wants to move the user to a tab — the Comments
  /// card's `View All` is the first caller.
  ///
  /// A **negative index counts from the end**, so a host whose tab list is
  /// module-gated can say "second to last" without recomputing the gates. The
  /// value is clamped, never thrown on. No production caller needs it since
  /// Comments took index 0 on Project and Task too
  /// (invoiceninja/flutter#122); it stays supported, and pinned by
  /// `entity_detail_tabs_test.dart`, for the next module-gated host.
  ///
  /// The *strip* is scrolled into view alongside, without which tapping a link
  /// on a phone changes a tab several hundred pixels below the fold and
  /// nothing visibly happens.
  final ValueListenable<int>? selectTab;

  /// Null stacks the strip over the body. See [EntityDetailTabsLayoutBuilder].
  final EntityDetailTabsLayoutBuilder? layoutBuilder;

  /// Brings the strip into view after a [selectTab] request, in place of the
  /// default `Scrollable.ensureVisible`. A host that supplies [layoutBuilder]
  /// must supply this too: with the page built *inside* this widget there is
  /// no enclosing scrollable for the default to find, so it would do nothing.
  final VoidCallback? onReveal;

  @override
  State<EntityDetailTabs> createState() => _EntityDetailTabsState();
}

class _EntityDetailTabsState extends State<EntityDetailTabs>
        // PLURAL `TickerProviderStateMixin`: the controller is rebuilt when the tab
        // count changes, and every `TabController` eagerly builds its own
        // `AnimationController`, i.e. its own ticker.
        // `SingleTickerProviderStateMixin.createTicker` asserts `_ticker == null`
        // and never resets it — not on dispose, not when the ticker is disposed —
        // so a second controller throws "multiple tickers were created" on exactly
        // the rebuild this exists to handle. `BillingDocItemsTabs` (which rebuilds
        // its controller the same way) uses the plural mixin for the same reason.
        with
        TickerProviderStateMixin {
  late TabController _controller = _newController(
    // Restore the tab the user last picked on this entity's pane, so clicking
    // down a list doesn't snap back to the first tab on every row. The router
    // re-keys this subtree per `:id`, so the memory has to live outside it —
    // `MasterDetailNavController` already outlives the swap. Null (and so
    // `initialIndex`) outside a master-detail layout, e.g. the settings-hosted
    // detail screens. See `initialIndex` for why the memory deliberately wins.
    _restoredIndex() ?? widget.initialIndex,
  );

  /// Null when there's no master-detail layout above us.
  MasterDetailNavController? get _tabMemory =>
      MasterDetailNavScope.maybeOf(context);

  /// The scaffold's `[` / `]` channel, bound while this strip is mounted.
  DetailTabNavigator? _navigator;

  /// The remembered tab, but only when it still means the same tab — see
  /// [MasterDetailNavController.lastTab]. An id is tried first: it names the
  /// tab itself, so it stays right across a module-gated count change that
  /// would make the remembered *index* point somewhere else.
  int? _restoredIndex() {
    final memory = _tabMemory;
    if (memory == null) return null;
    final id = memory.lastTabId;
    if (id != null) {
      final byId = widget.tabs.indexWhere((t) => t.id == id);
      if (byId >= 0) return byId;
    }
    final last = memory.lastTab;
    if (last == null || last.count != widget.tabs.length) return null;
    return last.index;
  }

  /// Build a controller and wire it up. Every construction goes through here so
  /// the `_onTabChanged` subscription can never be forgotten — without it
  /// `_activated` stops growing and the body `Stack` renders nothing for any
  /// tab the user opens afterwards.
  TabController _newController(int index) {
    final controller = TabController(
      length: widget.tabs.length,
      vsync: this,
      initialIndex: widget.tabs.isEmpty
          ? 0
          : index.clamp(0, widget.tabs.length - 1),
    );
    controller.addListener(_onTabChanged);
    return controller;
  }

  /// Rebuild the controller when the tab COUNT changes.
  ///
  /// `ClientDetailTabs` builds a variable-length list — eight of its tabs are
  /// gated on `me?.moduleEnabled(...)` — and toggling a module in Account
  /// Management rebuilds the branch in place (the shell keeps it mounted, and
  /// the module write updates `session`, which is the router's
  /// `refreshListenable`). With a `late final` controller the length went
  /// stale: shrinking left `_controller.index` past the end so every body was
  /// `Offstage` and no tab underlined, and growing made a tap on the new last
  /// tab trip `TabController._changeIndex`'s range assert.
  @override
  void didUpdateWidget(EntityDetailTabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.selectTab, widget.selectTab)) {
      oldWidget.selectTab?.removeListener(_onSelectRequested);
      widget.selectTab?.addListener(_onSelectRequested);
    }
    if (oldWidget.tabs.length == widget.tabs.length) return;
    // Dispose FIRST, then build — the plural mixin allows both orders, but this
    // is the order `BillingDocItemsTabs` uses and it keeps at most one live
    // ticker.
    final previousIndex = _controller.index;
    // Follow the tab the user was on when it has an id: the count changing
    // means every later index now names a different tab.
    final previousId = previousIndex < oldWidget.tabs.length
        ? oldWidget.tabs[previousIndex].id
        : null;
    final byId = previousId == null
        ? -1
        : widget.tabs.indexWhere((t) => t.id == previousId);
    _controller
      ..removeListener(_onTabChanged)
      ..dispose();
    _controller = _newController(byId >= 0 ? byId : previousIndex);
    // `_activated` is deliberately NOT cleared. Indices shift when the count
    // changes, so some entries now point at a different tab — but the set only
    // gates *eager mounting*, so the cost of a stale entry is a body mounted
    // early, while clearing tears down every already-live tab's list VM and
    // scroll position, which this class's own contract promises to preserve.
    // Out-of-range entries are simply never consulted by the body `Stack`.
    _activated.add(_controller.index);
  }

  // Tabs the user has activated at least once. `IndexedStack` mounts every
  // child eagerly, which would fire each tab's data fetches before the user
  // ever looked at them — gate on this set so a tab's `initState` only
  // runs after first activation, then stays alive for the rest of the
  // screen's lifetime.
  final Set<int> _activated = <int>{};

  @override
  void initState() {
    super.initState();
    // The listener is attached by `_newController`.
    _activated.add(_controller.index);
    widget.selectTab?.addListener(_onSelectRequested);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigator = DetailTabNavigatorScope.maybeOf(context);
    if (identical(navigator, _navigator)) return;
    _navigator?.unbind(_stepBy);
    _navigator = navigator?..bind(_stepBy);
  }

  /// `[` / `]` from the scaffold: move along the strip, stopping at the ends.
  void _stepBy(int delta) {
    if (!mounted || widget.tabs.isEmpty) return;
    final next = (_controller.index + delta).clamp(0, widget.tabs.length - 1);
    if (next != _controller.index) _controller.animateTo(next);
  }

  /// Move to the requested tab and bring the strip into view.
  void _onSelectRequested() {
    final select = widget.selectTab;
    if (select == null || widget.tabs.isEmpty || !mounted) return;
    final int index;
    final id = select is TabSelectionController ? select.requestedId : null;
    if (id != null) {
      index = widget.tabs.indexWhere((t) => t.id == id);
      // Gated away (module off): there is nothing to move to.
      if (index < 0) return;
    } else {
      final requested = select.value;
      final resolved = requested < 0
          ? widget.tabs.length + requested
          : requested;
      index = resolved.clamp(0, widget.tabs.length - 1);
    }
    if (_controller.index != index) _controller.animateTo(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reveal = widget.onReveal;
      if (reveal != null) {
        reveal();
        return;
      }
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 200),
      );
    });
    // A repeat request for the active tab dirties nothing — see
    // `_TabStripState._onRevealRequested`.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _onTabChanged() {
    final memory = _tabMemory;
    if (memory != null && widget.tabs.isNotEmpty) {
      memory
        ..lastTab = (index: _controller.index, count: widget.tabs.length)
        // Written even when null, so a host without ids clears an id a
        // different strip left behind rather than restoring against it.
        ..lastTabId = widget.tabs[_controller.index].id;
    }
    if (_activated.add(_controller.index)) setState(() {});
  }

  @override
  void dispose() {
    _navigator?.unbind(_stepBy);
    widget.selectTab?.removeListener(_onSelectRequested);
    _controller.removeListener(_onTabChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // No card chrome: the strip is a standalone row with a full-width
    // underline, the active tab body sits flush below (React-like). The
    // detail page owns the single scrollbar.
    final strip = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TabStrip(
          controller: _controller,
          tabs: widget.tabs,
          revealRequest: widget.selectTab,
        ),
        Divider(height: 1, thickness: 1, color: tokens.border),
      ],
    );
    final body = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final active = _controller.index;
        // Not IndexedStack: it lays out *all* children and sizes to
        // the tallest, which leaves a huge gap under a short tab once
        // bodies grow to intrinsic height. Offstage keeps activated
        // tabs alive (sub-VM state + scroll preserved) but contributes
        // zero size, so height tracks the active tab only. TickerMode
        // lets an embedded list detect whether it's the visible tab
        // (only the visible one consumes the page-scroll pagination
        // signal).
        return Stack(
          children: [
            for (var i = 0; i < widget.tabs.length; i++)
              if (_activated.contains(i))
                Offstage(
                  // Keyed, because this list has holes: only the tabs opened
                  // so far are in it, so opening an *earlier* one shifts
                  // every later body down a slot. Unkeyed, Flutter matched
                  // them by position — the Invoices body's element was handed
                  // the Comments tab, and Invoices was built again from
                  // nothing: its filter, search, selection and scroll gone
                  // and page 1 fetched again. That is the opposite of "an
                  // opened tab stays alive", and it happened on the comments
                  // card's View All, on `[`, and on any tap to the left of
                  // the landing tab. By id where there is one, so the body
                  // also follows its tab when a module switching on or off
                  // moves the indices.
                  key: ValueKey<Object>(widget.tabs[i].id ?? i),
                  offstage: i != active,
                  child: TickerMode(
                    enabled: i == active,
                    // `Offstage` hides a body; it does not take focus from
                    // it ("can receive focus and have keyboard input directed
                    // to them", in its own words — `Visibility` adds exactly
                    // this). On native touch a text field does not unfocus on
                    // an outside tap, so a field in the tab the user just
                    // left kept the keyboard, and their typing went into a
                    // box they could no longer see. On desktop, every tab
                    // ever opened stayed in the Tab order.
                    child: ExcludeFocus(
                      excluding: i != active,
                      child: Builder(builder: widget.tabs[i].bodyBuilder),
                    ),
                  ),
                ),
          ],
        );
      },
    );
    final layout = widget.layoutBuilder;
    if (layout != null) return layout(context, strip, body);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [strip, body],
    );
  }
}

/// Horizontal, scrollable strip — adapted from the route-based strip in
/// `company_details_shell.dart` but driven by a [TabController] instead.
/// Active tab gets the `accent` underline + `ink` text; inactive tabs use
/// `ink2`.
///
/// Stateful only because it owns the horizontal [ScrollController]. With ~15
/// tabs on a client and about three of them visible in a 440-560 px pane, a tab
/// can be *selected without being on screen* — by a restored
/// `MasterDetailNavController.lastTab`, or by the Comments card's `View All`,
/// whose destination sits at the far left. Until this the strip had no
/// controller at all and so never moved: the body changed under an unchanged,
/// un-underlined strip, which is the horizontal twin of the "nothing visibly
/// happens" bug [_EntityDetailTabsState._onSelectRequested] fixes on the page
/// axis.
/// Width of each edge fade, and so also the slack [_TabStripState._revealActive]
/// leaves around the tab it reveals: land a button flush against the viewport
/// edge and the fade above it veils the last 24 px of its own label.
const double _kStripEdgeFade = 32;

/// The "all tabs" button's side: the touch floor on touch, the app's compact
/// icon-button size with a pointer. Mirrors `actionButtonSize()` without
/// importing the list layer into this file.
double _allTabsButtonSize() => Env.isTouchPrimary ? InSizes.touchTarget : 32;

class _TabStrip extends StatefulWidget {
  const _TabStrip({
    required this.controller,
    required this.tabs,
    this.revealRequest,
  });

  final TabController controller;
  final List<EntityDetailTab> tabs;

  /// The host's [EntityDetailTabs.selectTab], listened to *here as well* as in
  /// the parent. The parent skips `animateTo` when the requested tab is already
  /// active, so the controller never ticks and a reveal hung off that tick alone
  /// would not run — which is exactly the repeat request
  /// [TabSelectionController.select] exists to deliver: tap `View All`, scroll
  /// the strip away by hand, tap `View All` again.
  final ValueListenable<int>? revealRequest;

  @override
  State<_TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<_TabStrip> {
  final ScrollController _scroll = ScrollController();

  /// One per tab index. Positional, so an index keeps naming the button at that
  /// position however the tab list changes; entries past a shrunken list are
  /// simply never looked up (`currentContext` would be null anyway).
  final Map<int, GlobalKey> _keys = <int, GlobalKey>{};

  /// The strip is ONE tab stop: only the active button can take focus, and it
  /// always takes it through this node, so arrowing along the strip carries
  /// the focus with the selection instead of leaving it on a tab that is no
  /// longer the active one.
  final FocusNode _activeFocus = FocusNode(debugLabel: 'detail tab');

  int _lastIndex = 0;

  /// Whether the "all tabs" button was drawn on the last build. Needed to
  /// recover the strip's full slot width from the scroll metrics — see
  /// [_overflows].
  bool _allTabsShown = false;

  @override
  void initState() {
    super.initState();
    _lastIndex = widget.controller.index;
    widget.controller.addListener(_onControllerTick);
    widget.revealRequest?.addListener(_onRevealRequested);
    _scheduleFirstFrame();
  }

  @override
  void didUpdateWidget(_TabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.revealRequest, widget.revealRequest)) {
      oldWidget.revealRequest?.removeListener(_onRevealRequested);
      widget.revealRequest?.addListener(_onRevealRequested);
    }
    // A count that arrives after the strip is on screen widens its tab, and
    // the tabs after it move along. If that pushed the *active* tab's tail
    // under the all-tabs button — on a phone it does, the landing tab's own
    // badge is what gets cut off — bring it back. `_revealActive` moves the
    // strip only as far as it must, so a strip the user has scrolled
    // elsewhere is not yanked back unless the active tab is actually clipped.
    if (_countsChanged(oldWidget.tabs, widget.tabs)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealActive(animate: false);
      });
    }
    // The parent REPLACES the controller when the tab count changes (toggling a
    // module in Account Management does exactly that), so re-subscribe or the
    // auto-scroll dies silently from then on.
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_onControllerTick);
    widget.controller.addListener(_onControllerTick);
    _lastIndex = widget.controller.index;
    _scheduleFirstFrame();
  }

  static bool _countsChanged(
    List<EntityDetailTab> before,
    List<EntityDetailTab> after,
  ) {
    if (before.length != after.length) return false;
    for (var i = 0; i < after.length; i++) {
      if (before[i].count != after[i].count) return true;
    }
    return false;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTick);
    widget.revealRequest?.removeListener(_onRevealRequested);
    _activeFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Reveal the restored tab, then rebuild once so the edge fades can read a
  /// scroll position that only exists after the first layout — `attach` adds
  /// the listener but does not itself notify, so without this a strip nobody
  /// scrolls never paints its trailing fade.
  void _scheduleFirstFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealActive(animate: false);
      setState(() {});
    });
  }

  /// The controller notifies on every animation tick as well; only a change of
  /// *index* is a reason to move the strip.
  void _onControllerTick() {
    if (widget.controller.index == _lastIndex) return;
    _lastIndex = widget.controller.index;
    // The roving node moves to the newly active button during the rebuild.
    // When that button comes *later* in the row, the old one gives the node
    // up first — `FocusAttachment.detach` then unfocuses it, and focus lands
    // on whatever held it before (a tile, a search field), so the next Enter
    // goes there. Read "the strip had focus" now, before that rebuild, and
    // take it back after. Here rather than in `_onKey`, because `]`, a click
    // and the all-tabs list change the tab too, and only arrows went through
    // there.
    final hadFocus = _activeFocus.hasFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _revealActive();
      if (hadFocus) _activeFocus.requestFocus();
    });
  }

  /// A host asked for a tab, whether or not that changes the index. Runs after
  /// the parent's own listener has had its chance to `animateTo`, so the
  /// post-frame read of `controller.index` sees the destination either way.
  ///
  /// `ensureVisualUpdate` because a post-frame callback does not ask for a
  /// frame: a request for the tab that is *already* active changes nothing, so
  /// with no frame otherwise due the reveal would wait for the next unrelated
  /// repaint.
  void _onRevealRequested() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  /// Scroll the active tab into view — **minimally**, and only when it is not
  /// already fully visible.
  ///
  /// Neither flavour of `ensureVisible` does this job. The static
  /// `Scrollable.ensureVisible` walks *every* enclosing scrollable, so on this
  /// context it would drag the detail page's vertical scroll down to the strip
  /// on each tab change and on restore. (The parent calls it deliberately, for
  /// exactly that vertical effect, from
  /// [_EntityDetailTabsState._onSelectRequested] — but it is the wrong tool
  /// *here*.) And `ScrollPosition.ensureVisible` always travels to the
  /// alignment it is given, so centring the way Material's own `TabBar` does
  /// would centre the **landing** tab and scroll the head of the strip out of
  /// view: with the Comments + Activity pair leading, `initialIndex: 2` would
  /// arrive with "Comments" already clipped off the left edge — exactly the
  /// visibility the pair is there to buy (invoiceninja/flutter#122). The
  /// `the landing tab leaves the head of the strip visible` test pins that;
  /// no measurement is quoted here because the widths move with the font,
  /// the text scale and the locale.
  void _revealActive({bool animate = true}) {
    if (!mounted || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions) return;
    final ctx = _keys[widget.controller.index]?.currentContext;
    final box = ctx?.findRenderObject();
    // A pane that has not been laid out yet (or a key whose tab has just been
    // gated away) measures nothing; `getOffsetToReveal` would assert.
    if (box is! RenderBox || !box.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;

    // Reveal the button with a full [_kStripEdgeFade] of slack, not the strip's
    // 8 px padding: a mid-strip target landed flush against the viewport edge
    // sits *under* the fade drawn there, which veils the last 24 px of the very
    // label just revealed (75% opaque at its tail) — invisible in the tests,
    // which only assert the button is on screen. At the ends the extra slack
    // costs nothing, because the clamp below pins tab 0 to `minScrollExtent`
    // (whereupon the leading fade is not drawn at all) and the last tab to
    // `maxScrollExtent`.
    // On the trailing side the "all tabs" button stands where the fade would
    // be, so that is what the revealed tab has to clear there.
    final bounds = box.paintBounds;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final endGutter = _allTabsShown ? _allTabsSlot : _kStripEdgeFade;
    final withGutter = Rect.fromLTRB(
      bounds.left - (rtl ? endGutter : _kStripEdgeFade),
      bounds.top,
      bounds.right + (rtl ? _kStripEdgeFade : endGutter),
      bounds.bottom,
    );
    final leading = viewport
        .getOffsetToReveal(box, 0.0, rect: withGutter)
        .offset;
    final trailing = viewport
        .getOffsetToReveal(box, 1.0, rect: withGutter)
        .offset;
    final double? target = position.pixels > leading
        ? leading
        : position.pixels < trailing
        ? trailing
        : null;
    if (target == null) return;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (clamped == position.pixels) return;
    if (animate) {
      position.animateTo(
        clamped,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      position.jumpTo(clamped);
    }
  }

  /// Whether the tabs run past the strip's **full** slot, i.e. whether the
  /// "all tabs" button is needed.
  ///
  /// Measured on the tabs alone: while the button is showing, the strip pads
  /// its content by the button's width so the last tab can scroll clear of it,
  /// and counting that padding would latch — a strip that only overflows
  /// *because* the button is there would never lose it.
  bool _overflows() {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) {
      return false;
    }
    final p = _scroll.position;
    final content =
        p.maxScrollExtent +
        p.viewportDimension -
        (_allTabsShown ? _allTabsSlot : 0);
    // Half a pixel of slack: the two sides come from different layout passes.
    return content > p.viewportDimension + 0.5;
  }

  double get _allTabsSlot => _allTabsButtonSize() + InSpacing.xs;

  void _select(int index) {
    // Reached after an `await` from the all-tabs sheet, by which time the
    // strip — and its controller — may be gone.
    if (!mounted) return;
    if (widget.controller.index != index) widget.controller.animateTo(index);
  }

  /// Arrow keys walk the strip while one of its buttons has focus. Handled
  /// here, below the app's `Shortcuts`, so they never reach the framework's
  /// directional-focus traversal.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || widget.tabs.isEmpty) {
      return KeyEventResult.ignored;
    }
    // A chord is somebody else's: ⌘← / Alt+← are history back, and on web
    // swallowing them here also cancels the browser's own.
    final keys = HardwareKeyboard.instance;
    if (keys.isMetaPressed || keys.isAltPressed || keys.isControlPressed) {
      return KeyEventResult.ignored;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final key = event.logicalKey;
    final last = widget.tabs.length - 1;
    final current = widget.controller.index;
    final int next;
    if (key == LogicalKeyboardKey.arrowLeft) {
      next = current + (rtl ? 1 : -1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      next = current + (rtl ? -1 : 1);
    } else if (key == LogicalKeyboardKey.home) {
      next = 0;
    } else if (key == LogicalKeyboardKey.end) {
      next = last;
    } else {
      return KeyEventResult.ignored;
    }
    // Focus follows the new active button from `_onControllerTick`.
    _select(next.clamp(0, last));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final overflows = _overflows();
    if (overflows != _allTabsShown) {
      _allTabsShown = overflows;
      // The button just took (or gave back) part of the viewport, so a tab that
      // was fully revealed a frame ago may now sit under the edge.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revealActive(animate: false),
      );
    }
    // Material ancestor required so each _TabButton's InkWell renders its
    // ink/splash; transparency = no visual change. EntityDetailTabs can be
    // hosted without a Scaffold (EntityDetailScaffold skips its own in
    // embedded mode), so the strip supplies the Material itself.
    return Material(
      type: MaterialType.transparency,
      // The fades below read `min`/`maxScrollExtent`, and a change to those
      // that leaves `pixels` alone — a window resize, a rotation, the pane
      // widening until the strip fits — does NOT reach a `ScrollController`
      // listener: `applyContentDimensions` only schedules a
      // `ScrollMetricsNotification` (its own comment says listeners "have, by
      // definition, already been built this frame"). Without this the strip
      // keeps whichever fades the *previous* width called for, and once it
      // fits there is no scroll left that could ever correct them.
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) {
          if (mounted) setState(() {});
          return false;
        },
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final activeIndex = widget.controller.index;
            // One `Stack` whether or not the button shows: moving the
            // scroller under a different parent would re-inflate it, and a
            // fresh `ScrollPosition` starts at 0 — throwing away the reveal
            // that ran on the very frame the overflow was first measured.
            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  // The extra trailing room lets the last tab scroll clear of
                  // the button laid over that edge.
                  padding: EdgeInsetsDirectional.only(
                    start: InSpacing.sm,
                    end: InSpacing.sm + (overflows ? _allTabsSlot : 0),
                  ),
                  child: Focus(
                    canRequestFocus: false,
                    skipTraversal: true,
                    onKeyEvent: _onKey,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < widget.tabs.length; i++)
                          _TabButton(
                            boxKey: _keys.putIfAbsent(i, GlobalKey.new),
                            tab: widget.tabs[i],
                            active: i == activeIndex,
                            focusNode: i == activeIndex ? _activeFocus : null,
                            tokens: tokens,
                            onTap: () => _select(i),
                          ),
                      ],
                    ),
                  ),
                ),
                // A fade hinting that tabs have scrolled off the LEADING edge.
                // The trailing edge needs none: a strip that runs past it
                // shows the "all tabs" button there instead, which says the
                // same thing and also lists them. (~15 tabs on a client, and
                // the 440-560 px master-detail pane shows about three, so the
                // strip almost always overflows — which is also why this is a
                // fade rather than a scrollbar.) Gated on there being
                // something to reveal: an unconditional fade veils the first
                // tab's own label once the strip is scrolled back to the
                // start. Its own builder, so a scroll frame repaints one
                // gradient rather than fifteen buttons.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _scroll,
                      builder: (context, _) {
                        // `hasContentDimensions`, not just `hasClients`: the
                        // position is attached on the first build but its
                        // extents are only set after layout, and reading one
                        // early throws a null-check straight out of
                        // `ScrollPosition.minScrollExtent`.
                        final p =
                            _scroll.hasClients &&
                                _scroll.position.hasContentDimensions
                            ? _scroll.position
                            : null;
                        final atStart =
                            p == null || p.pixels <= p.minScrollExtent;
                        return Stack(
                          children: [if (!atStart) _leadingFade(tokens)],
                        );
                      },
                    ),
                  ),
                ),
                if (overflows)
                  PositionedDirectional(
                    top: 0,
                    bottom: 0,
                    end: 0,
                    width: _allTabsSlot,
                    // Opaque, so tabs slide under it rather than through it.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: tokens.bg,
                        border: BorderDirectional(
                          start: BorderSide(color: tokens.border),
                        ),
                      ),
                      child: Center(
                        child: _AllTabsButton(
                          tabs: widget.tabs,
                          activeIndex: activeIndex,
                          onSelected: _select,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Directional, so it lands on the correct physical edge in a right-to-left
  /// locale.
  Widget _leadingFade(InTheme tokens) => PositionedDirectional(
    top: 0,
    bottom: 0,
    start: 0,
    child: Container(
      width: _kStripEdgeFade,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerEnd,
          end: AlignmentDirectional.centerStart,
          colors: [tokens.bg.withValues(alpha: 0), tokens.bg],
        ),
      ),
    ),
  );
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.boxKey,
    required this.tab,
    required this.active,
    required this.focusNode,
    required this.tokens,
    required this.onTap,
  });

  /// On the [Container], not the [InkWell] — `findRenderObject` has to reach a
  /// real `RenderBox` for `_TabStripState._revealActive` to measure.
  final Key boxKey;

  final EntityDetailTab tab;
  final bool active;

  /// Non-null on the active button only — see `_TabStripState._activeFocus`.
  final FocusNode? focusNode;
  final InTheme tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Inactive uses `ink2`, not `ink3`. ink3 was reading too light on a
    // surface bg; ink2 is muted-but-clearly-readable and keeps a clean
    // contrast against the active state.
    final color = active ? tokens.ink : tokens.ink2;
    final vertical = InSpacing.md(context);
    // The strip's rows were ~36 px tall on a phone. A floor, not a height, so
    // a large text scale still grows the row rather than clipping the label.
    final floor = Env.isTouchPrimary ? InSizes.touchTarget : 0.0;
    final contentFloor = (floor - vertical * 2 - 2).clamp(0.0, double.infinity);
    final count = tab.count;
    return MergeSemantics(
      child: Semantics(
        selected: active,
        button: true,
        child: InkWell(
          onTap: onTap,
          focusNode: focusNode,
          canRequestFocus: active,
          child: Container(
            key: boxKey,
            padding: EdgeInsets.symmetric(
              horizontal: InSpacing.md(context),
              vertical: vertical,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: active ? tokens.accent : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: contentFloor),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 16, color: color),
                  const SizedBox(width: InSpacing.sm),
                  Text(
                    tab.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    _TabCount(count: count, tokens: tokens),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The count beside a tab label. A zero stays muted whatever the tab — it is
/// the one number that means there is nothing to look at.
class _TabCount extends StatelessWidget {
  const _TabCount({required this.count, required this.tokens});

  final int count;
  final InTheme tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(InRadii.r1),
        border: Border.all(color: tokens.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: count == 0 ? tokens.ink3 : tokens.ink2,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Lists every tab, for a strip too long to see at once. A menu with a
/// pointer; a bottom sheet on touch, where fifteen menu rows would run off a
/// phone screen.
class _AllTabsButton extends StatelessWidget {
  const _AllTabsButton({
    required this.tabs,
    required this.activeIndex,
    required this.onSelected,
  });

  final List<EntityDetailTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final size = _allTabsButtonSize();
    // Pinned on both axes: left to the theme, an `IconButton` is floored at the
    // 48 px tap target on touch and would push the strip taller than its tabs.
    final style = IconButton.styleFrom(
      fixedSize: Size.square(size),
      minimumSize: Size.zero,
      maximumSize: Size.infinite,
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (Env.isTouchPrimary) {
      return IconButton(
        style: style,
        tooltip: context.tr('more'),
        icon: const Icon(Icons.arrow_drop_down),
        onPressed: () => _openSheet(context),
      );
    }
    return BackDismissibleMenuAnchor(
      consumeOutsideTap: true,
      menuChildren: [
        for (var i = 0; i < tabs.length; i++)
          // The tick is the only visible mark of the current tab; say it too.
          Semantics(
            selected: i == activeIndex,
            child: MenuItemButton(
              leadingIcon: Icon(tabs[i].icon, size: 18),
              trailingIcon: i == activeIndex
                  ? const Icon(Icons.check, size: 18)
                  : null,
              onPressed: () => onSelected(i),
              child: Text(_menuLabel(tabs[i])),
            ),
          ),
      ],
      builder: (context, controller, _) => IconButton(
        style: style,
        tooltip: context.tr('more'),
        icon: const Icon(Icons.arrow_drop_down),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }

  static String _menuLabel(EntityDetailTab tab) =>
      tab.count == null ? tab.label : '${tab.label}  ${tab.count}';

  Future<void> _openSheet(BuildContext context) async {
    // Root navigator: inside the master-detail pane the nearest one is the
    // pane's own, and the sheet would be a slab pinned under a ~500 px column.
    final picked = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final tokens = sheetContext.inTheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: InSpacing.sm),
              children: [
                for (var i = 0; i < tabs.length; i++)
                  // `MergeSemantics` + `selected`: the tick and the heavier
                  // weight are the only marks of the current tab, and neither
                  // is spoken.
                  MergeSemantics(
                    child: Semantics(
                      selected: i == activeIndex,
                      button: true,
                      child: InkWell(
                        onTap: () => Navigator.of(sheetContext).pop(i),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: InSizes.touchTarget,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: InSpacing.lg(sheetContext),
                              vertical: InSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  tabs[i].icon,
                                  size: 18,
                                  color: i == activeIndex
                                      ? tokens.ink
                                      : tokens.ink2,
                                ),
                                SizedBox(width: InSpacing.md(sheetContext)),
                                Expanded(
                                  child: Text(
                                    tabs[i].label,
                                    style: TextStyle(
                                      fontWeight: i == activeIndex
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: tokens.ink,
                                    ),
                                  ),
                                ),
                                if (tabs[i].count != null)
                                  _TabCount(
                                    count: tabs[i].count!,
                                    tokens: tokens,
                                  ),
                                if (i == activeIndex) ...[
                                  const SizedBox(width: InSpacing.sm),
                                  Icon(
                                    Icons.check,
                                    size: 18,
                                    color: tokens.ink,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null) onSelected(picked);
  }
}
