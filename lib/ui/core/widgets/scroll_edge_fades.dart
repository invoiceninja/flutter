import 'package:flutter/material.dart';

/// Leading / trailing gradient fades over a horizontally scrolling [child],
/// so a strip that runs past its viewport says so.
///
/// The app's other two scrollable tab strips (`EntityDetailTabs._TabStrip`,
/// `EntityListStatusTabs`) each own the `ScrollController` they fade against
/// and read `_scroll.position` directly. This leaf deliberately does **not**:
/// staying controller-free is what lets it wrap *any* scrollable — a `TabBar`
/// (which does expose one, `TabBar.scrollController`, but only since a recent
/// Flutter and only for a `TabBar`), a `SingleChildScrollView`, a `ListView` —
/// with no lifecycle for the caller to own, which is the precondition for it
/// ever replacing those two hand-rolled strips. It is also the pattern
/// Material documents for exactly this job (`tabs.dart`'s own
/// `tab_bar.3.dart` sample fades a `TabBar` off these two notifications).
///
/// Two of them, not one:
///
///  * [ScrollNotification] for a position change, and
///  * [ScrollMetricsNotification] for a width change that leaves `pixels`
///    alone — a rotation, a window resize, the pane widening until the strip
///    fits. `applyContentDimensions` only schedules that one, so without it
///    the strip keeps whichever fades the previous width called for. It
///    extends `Notification` where [ScrollNotification] extends
///    `LayoutChangedNotification`, i.e. they are siblings and one listener
///    cannot catch both.
///
/// `setState` from either handler is safe, for two different reasons.
/// [ScrollMetricsNotification] is dispatched from `didUpdateScrollMetrics`,
/// which asserts it is not in `SchedulerPhase.persistentCallbacks` — i.e. it
/// cannot arrive mid-layout. [ScrollNotification]s come from scroll-activity
/// callbacks (pointer handling, animation ticks), which are never the layout
/// phase either.
///
/// The fades are `PositionedDirectional` + `AlignmentDirectional` so they land
/// on the right physical edge in Arabic / Hebrew. That is copied from
/// `EntityListStatusTabs._edgeFade` rather than `EntityDetailTabs._edgeFade`,
/// which is plain `Positioned` + `Alignment` and is not RTL-correct.
class ScrollEdgeFades extends StatefulWidget {
  const ScrollEdgeFades({
    super.key,
    required this.child,
    required this.color,
    this.width = 24,
  });

  /// The horizontally scrolling subtree to fade. Must contain exactly one
  /// scrollable at notification depth 0 (a `TabBar`, a `SingleChildScrollView`);
  /// a nested scrollable's notifications are ignored.
  final Widget child;

  /// The surface the gradient dissolves into — the colour painted *behind*
  /// [child], not a token guess. The edit strips sit on `tokens.surface`
  /// while the list strip sits on `tokens.bg`.
  final Color color;

  final double width;

  /// Test hooks — emptiness is the interesting state here and a gradient has
  /// no other handle.
  static const Key leadingFadeKey = Key('scroll_edge_fade_leading');
  static const Key trailingFadeKey = Key('scroll_edge_fade_trailing');

  @override
  State<ScrollEdgeFades> createState() => _ScrollEdgeFadesState();
}

class _ScrollEdgeFadesState extends State<ScrollEdgeFades> {
  /// Both true until the first notification, i.e. nothing painted — which is
  /// also the right answer for a strip that has not been laid out yet.
  bool _atStart = true;
  bool _atEnd = true;

  /// Always returns false: this reads the metrics, it never consumes the
  /// notification.
  bool _onMetrics(ScrollMetrics m, int depth) {
    // Only the strip's own scrollable. A tab *body* is not inside this
    // subtree today, but a caller that wraps more than the strip would
    // otherwise fade on the wrong axis.
    if (depth != 0) return false;
    if (!m.hasContentDimensions || !m.hasPixels) return false;
    final atStart = m.pixels <= m.minScrollExtent;
    final atEnd = m.pixels >= m.maxScrollExtent;
    if (atStart == _atStart && atEnd == _atEnd) return false;
    if (!mounted) return false;
    setState(() {
      _atStart = atStart;
      _atEnd = atEnd;
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => _onMetrics(n.metrics, n.depth),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => _onMetrics(n.metrics, n.depth),
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(
                  children: [
                    if (!_atStart) _fade(leading: true),
                    if (!_atEnd) _fade(leading: false),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fade({required bool leading}) => PositionedDirectional(
    key: leading
        ? ScrollEdgeFades.leadingFadeKey
        : ScrollEdgeFades.trailingFadeKey,
    top: 0,
    bottom: 0,
    start: leading ? 0 : null,
    end: leading ? null : 0,
    child: Container(
      width: widget.width,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: leading
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          end: leading
              ? AlignmentDirectional.centerStart
              : AlignmentDirectional.centerEnd,
          colors: [widget.color.withValues(alpha: 0), widget.color],
        ),
      ),
    ),
  );
}
