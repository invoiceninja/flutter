import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/list/master_detail_nav_scope.dart';

/// One tab in an [EntityDetailTabs] strip. `label` is the rendered string
/// (already localized + optionally suffixed with a count badge); the body
/// is built lazily via [bodyBuilder] so per-tab data fetches don't fire
/// until the user first activates the tab.
class EntityDetailTab {
  const EntityDetailTab({
    required this.label,
    required this.icon,
    required this.bodyBuilder,
  });

  final String label;
  final IconData icon;
  final WidgetBuilder bodyBuilder;
}

/// Host-owned request channel for [EntityDetailTabs.selectTab].
///
/// A plain `ValueNotifier` goes silent on a repeat request: tap the Comments
/// card's `View All`, switch tabs by hand, tap it again — the value never
/// changed, so nothing happens. [select] notifies either way.
class TabSelectionController extends ValueNotifier<int> {
  TabSelectionController([super.initialIndex = 0]);

  void select(int index) {
    if (value == index) {
      notifyListeners();
    } else {
      value = index;
    }
  }
}

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

  /// The remembered index, but only when it still means the same tab — see
  /// [MasterDetailNavController.lastTab].
  int? _restoredIndex() {
    final last = _tabMemory?.lastTab;
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
    _controller
      ..removeListener(_onTabChanged)
      ..dispose();
    _controller = _newController(previousIndex);
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

  /// Move to the requested tab and bring the strip into view.
  void _onSelectRequested() {
    final requested = widget.selectTab?.value;
    if (requested == null || widget.tabs.isEmpty || !mounted) return;
    final resolved = requested < 0 ? widget.tabs.length + requested : requested;
    final index = resolved.clamp(0, widget.tabs.length - 1);
    if (_controller.index != index) _controller.animateTo(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 200),
      );
    });
  }

  void _onTabChanged() {
    _tabMemory?.lastTab = (index: _controller.index, count: widget.tabs.length);
    if (_activated.add(_controller.index)) setState(() {});
  }

  @override
  void dispose() {
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TabStrip(
          controller: _controller,
          tabs: widget.tabs,
          revealRequest: widget.selectTab,
        ),
        Divider(height: 1, thickness: 1, color: tokens.border),
        AnimatedBuilder(
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
                      offstage: i != active,
                      child: TickerMode(
                        enabled: i == active,
                        child: Builder(builder: widget.tabs[i].bodyBuilder),
                      ),
                    ),
              ],
            );
          },
        ),
      ],
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

  int _lastIndex = 0;

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
    // The parent REPLACES the controller when the tab count changes (toggling a
    // module in Account Management does exactly that), so re-subscribe or the
    // auto-scroll dies silently from then on.
    if (identical(oldWidget.controller, widget.controller)) return;
    oldWidget.controller.removeListener(_onControllerTick);
    widget.controller.addListener(_onControllerTick);
    _lastIndex = widget.controller.index;
    _scheduleFirstFrame();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerTick);
    widget.revealRequest?.removeListener(_onRevealRequested);
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());
  }

  /// A host asked for a tab, whether or not that changes the index. Runs after
  /// the parent's own listener has had its chance to `animateTo`, so the
  /// post-frame read of `controller.index` sees the destination either way.
  void _onRevealRequested() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _revealActive());

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
    final bounds = box.paintBounds;
    final withGutter = Rect.fromLTRB(
      bounds.left - _kStripEdgeFade,
      bounds.top,
      bounds.right + _kStripEdgeFade,
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
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
            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: InSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < widget.tabs.length; i++)
                        _TabButton(
                          boxKey: _keys.putIfAbsent(i, GlobalKey.new),
                          label: widget.tabs[i].label,
                          icon: widget.tabs[i].icon,
                          active: i == activeIndex,
                          tokens: tokens,
                          onTap: () {
                            if (widget.controller.index != i) {
                              widget.controller.animateTo(i);
                            }
                          },
                        ),
                    ],
                  ),
                ),
                // Fades hinting that more tabs scroll off-screen (~15 tabs on a
                // client, and the 440-560 px master-detail pane shows about
                // three, so the strip almost always overflows). That count is
                // also why this is a fade rather than a scrollbar. Each edge is
                // gated on there being something to reveal that way: an
                // unconditional fade veils the first or last tab's own label
                // once the strip is scrolled to that end, and both are absent
                // when the strip fits. Their own builder, so a scroll frame
                // repaints two gradients rather than fifteen buttons.
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
                        final atEnd =
                            p == null || p.pixels >= p.maxScrollExtent;
                        return Stack(
                          children: [
                            if (!atStart) _edgeFade(tokens, leading: true),
                            if (!atEnd) _edgeFade(tokens, leading: false),
                          ],
                        );
                      },
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

  Widget _edgeFade(InTheme tokens, {required bool leading}) => Positioned(
    top: 0,
    bottom: 0,
    left: leading ? 0 : null,
    right: leading ? null : 0,
    child: Container(
      width: _kStripEdgeFade,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: leading ? Alignment.centerRight : Alignment.centerLeft,
          end: leading ? Alignment.centerLeft : Alignment.centerRight,
          colors: [tokens.bg.withValues(alpha: 0), tokens.bg],
        ),
      ),
    ),
  );
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.boxKey,
    required this.label,
    required this.icon,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

  /// On the [Container], not the [InkWell] — `findRenderObject` has to reach a
  /// real `RenderBox` for `_TabStripState._revealActive` to measure.
  final Key boxKey;

  final String label;
  final IconData icon;
  final bool active;
  final InTheme tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Inactive uses `ink2`, not `ink3`. ink3 was reading too light on a
    // surface bg; ink2 is muted-but-clearly-readable and keeps a clean
    // contrast against the active state.
    final color = active ? tokens.ink : tokens.ink2;
    return InkWell(
      onTap: onTap,
      child: Container(
        key: boxKey,
        padding: EdgeInsets.symmetric(
          horizontal: InSpacing.md(context),
          vertical: InSpacing.md(context),
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? tokens.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: InSpacing.sm),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
