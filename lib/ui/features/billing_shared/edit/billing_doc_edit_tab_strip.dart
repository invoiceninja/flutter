import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/widgets/scroll_edge_fades.dart';

/// One tab of a narrow billing-doc edit strip: its label and its body,
/// together.
///
/// A record rather than two parallel lists, because the `tabs:` / `children:`
/// pair this replaced could lose an entry from one and not the other — and a
/// `TabBar` whose length disagrees with its `TabBarView`'s throws at runtime,
/// not at compile time.
typedef BillingDocEditTab = ({String label, Widget body});

/// The narrow (below `Breakpoints.wide`) tab strip and body shared by all five
/// billing-doc edit layouts — invoice, quote, credit, purchase order and
/// recurring invoice.
///
/// Mount it as the `Expanded` child of the layout's `Column`; the layout keeps
/// its own trailing divider and sticky totals below.
///
/// It exists because the alternative is five hand-copied controller
/// lifecycles. What lives in here is not markup — it is the
/// dispose-before-rebuild ordering, the plural ticker and the index clamp
/// below, and CLAUDE.md records that shape being paid for twice already (eight
/// hand-copied KPI strips returning `RangeError`, fourteen hand-rolled
/// `created` columns of which three painted 1 Jan 1970). Five copies pinned by
/// a lint is weaker than one type.
///
/// Two pieces of chrome are deliberate and documented at their use sites:
/// `TabAlignment.start`, which reclaims the 52 px `_kStartOffset` that M3
/// defaults a scrollable `TabBar` to, and [ScrollEdgeFades], which is what
/// tells the user a strip that still overflows (German, a 360 px phone, large
/// text, recurring invoices) has more beyond the edge.
class BillingDocEditTabStrip extends StatefulWidget {
  const BillingDocEditTabStrip({
    super.key,
    required this.tabs,
    this.excludeInactiveFocus = false,
  });

  /// The tabs, in order. The list's **length** drives the controller, so a
  /// conditional tab is expressed by leaving it out rather than by any second
  /// count that could go stale.
  final List<BillingDocEditTab> tabs;

  /// Wrap each page in `ExcludeFocusTraversal` so inactive tabs are out of
  /// directional (arrow-key) traversal.
  ///
  /// Off by default and on only for recurring invoices, which is where it was
  /// needed: a kept-alive off-stage tab whose `RenderObject` is NEEDS-LAYOUT
  /// crashes `findFirstFocusInDirection` on a `hasSize` assert. Turning it on
  /// for the other four would be a behaviour change nobody asked for — and it
  /// is not free, since keeping `excluding:` current costs a rebuild of the
  /// whole view on every tab change.
  final bool excludeInactiveFocus;

  @override
  State<BillingDocEditTabStrip> createState() => _BillingDocEditTabStripState();
}

class _BillingDocEditTabStripState extends State<BillingDocEditTabStrip>
        // PLURAL `TickerProviderStateMixin`: the controller is rebuilt when the
        // tab count changes and every `TabController` eagerly builds its own
        // `AnimationController`, i.e. its own ticker.
        // `SingleTickerProviderStateMixin.createTicker` asserts `_ticker == null`
        // and never resets it, so the second controller throws "multiple tickers
        // were created" on exactly the rebuild this exists to handle.
        // `EntityDetailTabs` and `BillingDocItemsTabs` do the same.
        with
        TickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: widget.tabs.length, vsync: this);
  }

  /// Rebuild the controller when the tab COUNT changes.
  ///
  /// Two things move it: a resize across `Breakpoints.wide`, which drops the
  /// `PDF` tab, and the E-Invoice gate resolving a frame or two after mount.
  /// With a fixed length, shrinking leaves `index` past the end so every body
  /// is off-stage with nothing underlined, and growing trips
  /// `TabController._changeIndex`'s range assert on the new last tab.
  ///
  /// Disposing the outgoing controller *before* building the replacement is
  /// safe and is the order `EntityDetailTabs` uses: `TabBar` and `TabBarView`
  /// both detach behind `_controllerIsValid`, which reads
  /// `_controller?.animation != null` and so skips a disposed one.
  @override
  void didUpdateWidget(BillingDocEditTabStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final length = widget.tabs.length;
    if (_tab.length == length) return;
    final previousIndex = _tab.index;
    _tab.dispose();
    _tab = TabController(
      length: length,
      vsync: this,
      initialIndex: previousIndex.clamp(0, length - 1),
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Widget _view() => TabBarView(
    controller: _tab,
    children: [
      for (var i = 0; i < widget.tabs.length; i++)
        if (widget.excludeInactiveFocus)
          ExcludeFocusTraversal(
            excluding: i != _tab.index,
            child: widget.tabs[i].body,
          )
        else
          widget.tabs[i].body,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: tokens.surface,
          child: ScrollEdgeFades(
            color: tokens.surface,
            child: TabBar(
              controller: _tab,
              isScrollable: true,
              // M3 defaults a scrollable TabBar to `TabAlignment.startOffset`
              // — a 52 px leading indent (`_kStartOffset`) meant for a bar
              // with room to spare. On a 412 px phone that is 12.6% of the
              // viewport spent on nothing, and it de-aligns the first tab from
              // the content under it. NOT settable in `theme.dart`:
              // `TabAlignment.start` asserts on a NON-scrollable TabBar, and
              // the app has three.
              tabAlignment: TabAlignment.start,
              tabs: [for (final tab in widget.tabs) Tab(text: tab.label)],
            ),
          ),
        ),
        Divider(height: 1, color: tokens.border),
        Expanded(
          // Embedded / pane mode has no Scaffold of its own, so the page
          // bodies would otherwise have no Material ancestor and every
          // TextField / RawAutocomplete in a narrow tab throws "No Material
          // widget found". A transparency Material supplies it with zero
          // visual change, and is inert where an ancestor already provides
          // one.
          child: Material(
            type: MaterialType.transparency,
            // Only the focus-traversal flag needs the view rebuilt on a tab
            // change; without it the `AnimatedBuilder` would be a rebuild of
            // every page's element tree for nothing.
            child: widget.excludeInactiveFocus
                ? AnimatedBuilder(
                    animation: _tab,
                    builder: (context, _) => _view(),
                  )
                : _view(),
          ),
        ),
      ],
    );
  }
}
