import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/detail/detail_refresh_scope.dart';
import 'package:admin/ui/core/detail/detail_scroll_scope.dart';

/// Lets a host bring the page's pinned tab strip into view — the Comments
/// card's `View All`, or a standing figure that opens its tab.
///
/// A plain object rather than a `GlobalKey` on the page: the host hands the
/// same instance to `EntityDetailTabs.onReveal` and to [EntityRecordPage], and
/// neither needs to know the other's `State`.
class EntityRecordPageController {
  VoidCallback? _revealTabs;

  /// Scrolls so the tab strip — and some of the body under it — is on screen.
  /// Does nothing when it already is.
  void revealTabs() => _revealTabs?.call();

  /// Told when the user refreshes the record, so the list embedded in the
  /// visible tab re-fetches with it. The host fires this from its own refresh
  /// (which `R` reaches without going through the page); the page publishes
  /// it to the lists.
  final DetailRefreshSignal refreshSignal = DetailRefreshSignal();

  void dispose() => refreshSignal.dispose();
}

/// The scrolling shell of a record screen: whatever sits above
/// the tabs, the tab strip **pinned** once it reaches the top, and the active
/// tab's body under it.
///
/// One scroll view, so the page keeps its single scrollbar and an embedded
/// list still pages off this scroll (`DetailScrollScope`). The strip is its
/// own sliver for one reason: with a long embedded list the strip used to
/// scroll away, and switching tab meant scrolling all the way back up first.
///
/// [tabStrip] and [tabBody] come from `EntityDetailTabs.layoutBuilder`, which
/// is what lets one `TabController` drive two slivers. That also means the
/// tabs widget *wraps* this one, so the default page reveal has nothing to
/// find — pass [controller] and wire `EntityDetailTabs.onReveal` to
/// [EntityRecordPageController.revealTabs].
///
/// A host that cannot give up the page (the billing documents, whose scroll
/// view is one half of a row beside the PDF pane) uses `EntityRecordColumn` on
/// its own instead.
class EntityRecordPage extends StatefulWidget {
  const EntityRecordPage({
    super.key,
    required this.top,
    required this.tabStrip,
    required this.tabBody,
    this.controller,
    this.onRefresh,
  });

  /// Pull-to-refresh. Null leaves the page with no indicator.
  ///
  /// A record screen had no way to refresh at all: opening a cached record
  /// makes no request, so a balance that changed on the server stayed stale
  /// until the next full sync.
  final Future<void> Function()? onRefresh;

  /// Everything above the tabs — normally an `EntityRecordColumn`.
  final Widget top;

  final Widget tabStrip;
  final Widget tabBody;
  final EntityRecordPageController? controller;

  @override
  State<EntityRecordPage> createState() => _EntityRecordPageState();
}

/// How much of the tab body has to be on screen for the strip to count as
/// "in view". Without it a request that leaves the strip on the last visible
/// row would be answered by a tab changing under the user's thumb with none of
/// its content showing.
const double _kBodyPeek = 160;

class _EntityRecordPageState extends State<EntityRecordPage> {
  final GlobalKey _topKey = GlobalKey();
  final GlobalKey _stripKey = GlobalKey();

  /// Only for a host with no `DetailScrollScope` above it (a widget test, a
  /// settings-hosted screen); `EntityDetailScaffold` normally supplies one.
  ScrollController? _ownScroll;
  ScrollController? _scroll;

  @override
  void initState() {
    super.initState();
    widget.controller?._revealTabs = _revealTabs;
  }

  @override
  void didUpdateWidget(EntityRecordPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.controller, widget.controller)) return;
    if (oldWidget.controller?._revealTabs == _revealTabs) {
      oldWidget.controller?._revealTabs = null;
    }
    widget.controller?._revealTabs = _revealTabs;
  }

  @override
  void dispose() {
    if (widget.controller?._revealTabs == _revealTabs) {
      widget.controller?._revealTabs = null;
    }
    _ownScroll?.dispose();
    super.dispose();
  }

  void _revealTabs() {
    final scroll = _scroll;
    if (!mounted || scroll == null || !scroll.hasClients) return;
    final top = _topKey.currentContext?.findRenderObject();
    final strip = _stripKey.currentContext?.findRenderObject();
    if (top is! RenderBox || !top.hasSize) return;
    if (strip is! RenderBox || !strip.hasSize) return;
    final position = scroll.position;
    // The offset at which the strip reaches the top of the viewport, i.e. the
    // height of everything above it.
    final pinnedAt = top.size.height;
    // Already pinned: the strip is on screen by definition.
    if (position.pixels >= pinnedAt) return;
    final stripBottom = pinnedAt - position.pixels + strip.size.height;
    if (stripBottom + _kBodyPeek <= position.viewportDimension) return;
    position.animateTo(
      math.min(pinnedAt, position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final pad = InSpacing.lg(context);
    _scroll =
        DetailScrollScope.maybeOf(context) ??
        (_ownScroll ??= ScrollController());
    final page = CustomScrollView(
      controller: _scroll,
      // A scroll view handed a controller is not always-scrollable by default,
      // and a record shorter than its viewport could then never be pulled.
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          // The key is on the padded box, so its height is exactly the scroll
          // offset at which the strip pins.
          child: Padding(
            key: _topKey,
            padding: EdgeInsets.fromLTRB(pad, pad, pad, pad),
            child: widget.top,
          ),
        ),
        PinnedHeaderSliver(
          // Opaque: the body scrolls *under* a pinned strip, and the strip's
          // own fades already dissolve into this colour.
          child: ColoredBox(
            key: _stripKey,
            color: tokens.bg,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: pad),
              child: widget.tabStrip,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
            child: widget.tabBody,
          ),
        ),
      ],
    );
    final refresh = widget.onRefresh;
    final scoped = widget.controller == null
        ? page
        : DetailRefreshScope(
            signal: widget.controller!.refreshSignal,
            child: page,
          );
    if (refresh == null) return scoped;
    return RefreshIndicator(onRefresh: refresh, child: scoped);
  }
}
