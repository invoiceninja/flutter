import 'package:flutter/material.dart';

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

/// Bordered card with a horizontal tab strip on top and an [IndexedStack]
/// of tab bodies below. Extracted from `ClientDetailTabs` so other entity
/// detail screens (Product, Invoice, …) can reuse the same scaffolding.
///
/// Lazy-mount semantics: a tab body is only built the first time the user
/// activates it, then stays alive for the rest of the screen's lifetime
/// (so scroll position + sub-VM state survive tab switches).
class EntityDetailTabs extends StatefulWidget {
  const EntityDetailTabs({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
  });

  final List<EntityDetailTab> tabs;
  final int initialIndex;

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
    // detail screens. No caller passes `initialIndex` today; if one ever needs
    // to deep-link to a tab, make it nullable so an explicit value can outrank
    // the memory.
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
  }

  void _onTabChanged() {
    _tabMemory?.lastTab = (index: _controller.index, count: widget.tabs.length);
    if (_activated.add(_controller.index)) setState(() {});
  }

  @override
  void dispose() {
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
        _TabStrip(controller: _controller, tabs: widget.tabs),
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
class _TabStrip extends StatelessWidget {
  const _TabStrip({required this.controller, required this.tabs});

  final TabController controller;
  final List<EntityDetailTab> tabs;

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    // Material ancestor required so each _TabButton's InkWell renders its
    // ink/splash; transparency = no visual change. EntityDetailTabs can be
    // hosted without a Scaffold (EntityDetailScaffold skips its own in
    // embedded mode), so the strip supplies the Material itself.
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final activeIndex = controller.index;
          return Stack(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: InSpacing.sm),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      _TabButton(
                        label: tabs[i].label,
                        icon: tabs[i].icon,
                        active: i == activeIndex,
                        tokens: tokens,
                        onTap: () {
                          if (controller.index != i) controller.animateTo(i);
                        },
                      ),
                  ],
                ),
              ),
              // Trailing fade hinting that more tabs scroll off-screen
              // (~11 tabs on a client; the strip almost always overflows).
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(
                    width: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [tokens.bg.withValues(alpha: 0), tokens.bg],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

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
