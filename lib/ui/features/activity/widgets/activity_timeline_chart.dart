import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/env.dart';
import 'package:admin/domain/activity/activity_timeline.dart';
import 'package:admin/l10n/localization.dart';
import 'package:admin/ui/features/activity/widgets/activity_period_labels.dart';
import 'package:admin/utils/formatting.dart';

/// The `/activity` window drawn as one bar per period — and the date filter.
///
/// Tap a bar to keep only that period; drag across bars to keep a run of
/// them; tap the selected bar again (or Clear) to let go. The bars count rows
/// that pass every *other* filter (`ActivityViewModel.timeline`), so they
/// keep their context while a range is picked, and the rows below are this
/// chart's table view.
///
/// **One series, one colour.** Stacking by category would need seven
/// separable hues and the tone palette paints two of them the same grey; the
/// category filter redraws these bars as that category instead.
///
/// **The readout replaces a tooltip.** Hovering or dragging rewrites the line
/// above the plot, which a finger mid-drag can still read — a floating
/// tooltip would sit under it.
class ActivityTimelineChart extends StatefulWidget {
  const ActivityTimelineChart({
    super.key,
    required this.timeline,
    required this.from,
    required this.until,
    required this.oldestAt,
    required this.selectionCount,
    required this.formatter,
    required this.onSelect,
    required this.onClear,
    this.onLoadMore,
    this.loadingMore = false,
    this.compact = false,
  });

  final ActivityTimeline timeline;

  /// The active date range, `[from, until)`; both null when none.
  final DateTime? from;
  final DateTime? until;

  /// Where the window starts — the "since" in the resting readout.
  final DateTime? oldestAt;

  /// Rows the feed is showing under the range — the readout's count while a
  /// range is held. Exact, where summing overlapped bars would not be.
  final int selectionCount;

  final Formatter? formatter;
  final void Function(DateTime from, DateTime until) onSelect;
  final VoidCallback onClear;

  /// Grows the window (`ActivityViewModel.loadMore`); null when there is
  /// nothing older to load. Offered here as well as under the feed because
  /// the chart is where the window visibly *ends*.
  final VoidCallback? onLoadMore;
  final bool loadingMore;

  /// The phone strip: a shorter plot. Same behaviour.
  final bool compact;

  @override
  State<ActivityTimelineChart> createState() => _ActivityTimelineChartState();
}

class _ActivityTimelineChartState extends State<ActivityTimelineChart> {
  int? _hover;
  int? _dragAnchor;
  int? _dragEnd;

  List<TimelineBucket> get _buckets => widget.timeline.buckets;

  /// Drops a drag or hover whose indices belong to the old buckets. A refresh
  /// can land mid-drag and re-bucket the window (52 weeks becoming ~21 days),
  /// and every index below would then run past the end, or silently select
  /// other periods. Same buckets — a rebuild with an equal timeline — keep it.
  @override
  void didUpdateWidget(ActivityTimelineChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.timeline.buckets;
    final after = _buckets;
    final same =
        before.length == after.length &&
        (after.isEmpty ||
            (before.first.start == after.first.start &&
                before.last.end == after.last.end));
    if (!same) {
      _hover = null;
      _dragAnchor = null;
      _dragEnd = null;
    }
  }

  bool get _hasRange => widget.from != null || widget.until != null;

  bool _inRange(int i) {
    if (_dragAnchor != null && _dragEnd != null) {
      final lo = _dragAnchor! < _dragEnd! ? _dragAnchor! : _dragEnd!;
      final hi = _dragAnchor! < _dragEnd! ? _dragEnd! : _dragAnchor!;
      return i >= lo && i <= hi;
    }
    if (!_hasRange) return true;
    final b = _buckets[i];
    final from = widget.from;
    final until = widget.until;
    return (from == null || b.end.isAfter(from)) &&
        (until == null || b.start.isBefore(until));
  }

  /// The bucket under [dx], counted from the left — the plot is pinned LTR
  /// (see `build`), so this holds in every locale.
  int _indexAt(double dx, double width) {
    final n = _buckets.length;
    final i = (dx / (width / n)).floor();
    return i.clamp(0, n - 1);
  }

  void _tap(int i) {
    final b = _buckets[i];
    if (widget.from == b.start && widget.until == b.end) {
      widget.onClear();
    } else {
      widget.onSelect(b.start, b.end);
    }
  }

  void _commitDrag() {
    final a = _dragAnchor;
    final e = _dragEnd;
    setState(() {
      _dragAnchor = null;
      _dragEnd = null;
    });
    if (a == null || e == null) return;
    final lo = a < e ? a : e;
    final hi = a < e ? e : a;
    widget.onSelect(_buckets[lo].start, _buckets[hi].end);
  }

  String _bucketLabel(BuildContext context, TimelineBucket b) =>
      activityRangeLabel(
        context,
        from: b.start,
        until: b.end,
        formatter: widget.formatter,
      );

  String _readout(BuildContext context) {
    final f = widget.formatter;
    if (_dragAnchor != null && _dragEnd != null) {
      final lo = _dragAnchor! < _dragEnd! ? _dragAnchor! : _dragEnd!;
      final hi = _dragAnchor! < _dragEnd! ? _dragEnd! : _dragAnchor!;
      var sum = 0;
      for (var i = lo; i <= hi; i++) {
        sum += _buckets[i].count;
      }
      final label = activityRangeLabel(
        context,
        from: _buckets[lo].start,
        until: _buckets[hi].end,
        formatter: f,
      );
      return '$label · ${activityEventCount(context, sum)}';
    }
    final hover = _hover;
    if (hover != null && hover < _buckets.length) {
      final b = _buckets[hover];
      return '${_bucketLabel(context, b)} · '
          '${activityEventCount(context, b.count)}';
    }
    if (_hasRange) {
      final label = activityRangeLabel(
        context,
        from: widget.from,
        until: widget.until,
        formatter: f,
      );
      return '$label · ${activityEventCount(context, widget.selectionCount)}';
    }
    final total = _buckets.fold<int>(0, (s, b) => s + b.count);
    final oldest = widget.oldestAt;
    if (oldest == null) return activityEventCount(context, total);
    return context.tr('activity_timeline_since', {
      'events': activityEventCount(context, total),
      'date': activityDayLabel(oldest, f),
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final plotHeight = widget.compact ? 40.0 : 88.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: Env.isTouchPrimary ? InSizes.touchTarget : 32,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _readout(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: tokens.ink2),
                ),
              ),
              if (_hasRange)
                TextButton.icon(
                  onPressed: widget.onClear,
                  icon: const Icon(Icons.close, size: 14),
                  label: Text(context.tr('clear')),
                )
              else if (widget.onLoadMore != null)
                TextButton.icon(
                  onPressed: widget.loadingMore ? null : widget.onLoadMore,
                  icon: widget.loadingMore
                      ? const SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.history, size: 14),
                  label: Text(context.tr('load_more')),
                ),
            ],
          ),
        ),
        // Time runs left → right in every locale, as on the fl_chart
        // charts: the bars, the hit test (`_indexAt` reads `dx` from the
        // left) and the tick labels all sit under one LTR wrap, so an RTL
        // `Row` can't mirror the bars away from the index a tap resolves to.
        // The readout above stays in the ambient direction.
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: plotHeight,
                child: LayoutBuilder(
                  builder: (context, c) =>
                      _plot(context, c.maxWidth, plotHeight),
                ),
              ),
              const SizedBox(height: InSpacing.xs),
              LayoutBuilder(
                builder: (context, c) => _axis(context, c.maxWidth),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _plot(BuildContext context, double width, double height) {
    final tokens = context.inTheme;
    final buckets = _buckets;
    if (buckets.isEmpty || width <= 0) return const SizedBox.shrink();
    final max = widget.timeline.maxCount;
    final slot = width / buckets.length;
    // ≤ 24 px a bar, and a 2 px gap between neighbours (the dataviz mark
    // spec); a 63-bar window on a 320 px phone still gets ~2.6 px bars.
    final barWidth = (slot - 2).clamp(1.0, 24.0);
    final emphasise = _hasRange || _dragAnchor != null;

    final bars = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < buckets.length; i++)
          Expanded(
            child: MouseRegion(
              onEnter: (_) => setState(() => _hover = i),
              onExit: (_) {
                if (_hover == i) setState(() => _hover = null);
              },
              child: Semantics(
                button: true,
                selected: emphasise && _inRange(i),
                label:
                    '${_bucketLabel(context, buckets[i])}: '
                    '${activityEventCount(context, buckets[i].count)}',
                onTap: () => _tap(i),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _hover == i ? tokens.surfaceAlt : null,
                    borderRadius: BorderRadius.circular(InRadii.r1),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _bar(
                      tokens,
                      count: buckets[i].count,
                      max: max,
                      width: barWidth,
                      height: height - 4,
                      on: !emphasise || _inRange(i),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Each bar carries its own semantics tap; the drag has no
        // screen-reader equivalent beyond the range picker in Filters.
        excludeFromSemantics: true,
        onTapUp: (d) => _tap(_indexAt(d.localPosition.dx, width)),
        onHorizontalDragStart: (d) {
          final i = _indexAt(d.localPosition.dx, width);
          setState(() {
            _dragAnchor = i;
            _dragEnd = i;
          });
        },
        onHorizontalDragUpdate: (d) {
          final i = _indexAt(d.localPosition.dx, width);
          if (i != _dragEnd) setState(() => _dragEnd = i);
        },
        onHorizontalDragEnd: (_) => _commitDrag(),
        onHorizontalDragCancel: () => setState(() {
          _dragAnchor = null;
          _dragEnd = null;
        }),
        child: DecoratedBox(
          // The baseline: a zero bar draws nothing, so without it a quiet
          // month reads as missing rather than empty.
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: bars,
        ),
      ),
    );
  }

  Widget _bar(
    InTheme tokens, {
    required int count,
    required int max,
    required double width,
    required double height,
    required bool on,
  }) {
    if (count == 0 || max == 0) return const SizedBox.shrink();
    final h = (count / max * height).clamp(2.0, height);
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: on ? tokens.accent : tokens.ink4,
        // Rounded at the data end, square on the baseline.
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(width < 8 ? width / 2 : 4),
        ),
      ),
    );
  }

  /// Thinned tick labels: as many as fit at ~72 px apiece, evenly stepped,
  /// each centred on its bar and clamped inside the plot.
  Widget _axis(BuildContext context, double width) {
    final tokens = context.inTheme;
    final buckets = _buckets;
    if (buckets.isEmpty || width <= 0) return const SizedBox(height: 14);
    const labelWidth = 72.0;
    final fit = (width / labelWidth).floor().clamp(1, buckets.length);
    final step = (buckets.length / fit).ceil();
    final slot = width / buckets.length;
    final style = TextStyle(fontSize: 10.5, color: tokens.ink3);
    return SizedBox(
      height: 14 * MediaQuery.textScalerOf(context).scale(1),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < buckets.length; i += step)
            _tick(
              context,
              index: i,
              slot: slot,
              width: width,
              labelWidth: labelWidth,
              style: style,
            ),
        ],
      ),
    );
  }

  /// A tick label centred on its bar — or, where centring would push it past
  /// an edge, pinned to that edge and aligned to it, so the first and last
  /// dates stay whole and still start at their bar.
  Widget _tick(
    BuildContext context, {
    required int index,
    required double slot,
    required double width,
    required double labelWidth,
    required TextStyle style,
  }) {
    final centred = slot * index + slot / 2 - labelWidth / 2;
    final maxLeft = (width - labelWidth).clamp(0.0, double.infinity);
    final align = centred < 0
        ? TextAlign.start
        : (centred > maxLeft ? TextAlign.end : TextAlign.center);
    // rtl: physical time axis (under the plot's LTR wrap)
    return Positioned(
      left: centred.clamp(0.0, maxLeft),
      width: labelWidth,
      top: 0,
      child: ExcludeSemantics(
        child: Text(
          activityAxisLabel(
            _buckets[index].start,
            widget.timeline.size,
            widget.formatter,
          ),
          maxLines: 1,
          overflow: TextOverflow.clip,
          textAlign: align,
          style: style,
        ),
      ),
    );
  }
}
