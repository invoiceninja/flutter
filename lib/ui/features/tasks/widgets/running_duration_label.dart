import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/utils/formatting.dart';

/// Ticking duration label for the currently-running entry of a task.
///
/// Self-contained ticker — mirrors `freshness_label.dart`'s pattern but at
/// 1 second by default (or [precision], for the kanban cards where every
/// visible card ticking is wasteful). Cancels in `dispose`.
///
/// Optionally renders a pulsing dot alongside the duration text. The same
/// ticker drives both so they stay in lockstep without separate state.
class RunningDurationLabel extends StatefulWidget {
  const RunningDurationLabel({
    super.key,
    required this.start,
    this.base = Duration.zero,
    this.precision = const Duration(seconds: 1),
    this.showDot = true,
    this.compactDays = true,
    this.style,
    this.dotSize = 8,
  });

  /// Timestamp of the running entry's start. The label renders
  /// `base + (now − start)` against the current frame's wall clock.
  final DateTime start;

  /// A fixed offset added to the live elapsed time. Zero (the default) shows
  /// just the current run — what the compact surfaces (narrow list, kanban,
  /// KPI, pill) want. The wide-table duration column passes the sum of the
  /// task's already-stopped entries so it ticks the full cumulative total
  /// (prior + current) instead of appearing to reset to 0 when a timer starts.
  final Duration base;

  /// How often the label refreshes. 1s for the edit screen, 1min for the
  /// kanban cards (the human eye doesn't follow seconds on a card).
  final Duration precision;

  /// Render the pulsing accent dot before the label.
  final bool showDot;

  /// When elapsed exceeds 24h, format as `Xd HHh MMm` instead of
  /// `HH:MM:SS` (which gets unreadable past 24 hours).
  final bool compactDays;

  /// Override the label text style. Defaults to the screen's body small.
  final TextStyle? style;

  final double dotSize;

  @override
  State<RunningDurationLabel> createState() => _RunningDurationLabelState();
}

class _RunningDurationLabelState extends State<RunningDurationLabel>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;

  /// Null when [RunningDurationLabel.showDot] is false — no dot means no
  /// pulse, so we don't spin up a ticker that would keep scheduling frames
  /// for nothing (the wide duration column is the `showDot:false` caller).
  AnimationController? _pulse;

  /// The rendered duration string. Driven by the ticker via a notifier so
  /// a tick repaints *only* the label `Text` (not the Row / dot /
  /// AnimatedBuilder), and only when the formatted value actually
  /// changed. This widget is mounted app-wide (the shell's running-timer
  /// pill) and one per kanban card, so a per-tick full rebuild here is
  /// disproportionately expensive.
  late final ValueNotifier<String> _label;

  String _compute() {
    // When the ticker fires less often than once a second, the seconds
    // field would freeze for ~60s at a time — looks like a bug. Drop
    // seconds from the rendered text in that case (kanban cards opt in).
    final showSeconds = widget.precision < const Duration(minutes: 1);
    return formatDuration(
      widget.base + DateTime.now().difference(widget.start),
      compactDays: widget.compactDays,
      showSeconds: showSeconds,
    );
  }

  @override
  void initState() {
    super.initState();
    _label = ValueNotifier<String>(_compute());
    _ticker = Timer.periodic(widget.precision, (_) {
      if (!mounted) return;
      final next = _compute();
      if (next != _label.value) _label.value = next;
    });
    if (widget.showDot) {
      _pulse = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1000),
      )..repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(RunningDurationLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.start != widget.start ||
        oldWidget.precision != widget.precision) {
      _label.value = _compute();
      if (oldWidget.precision != widget.precision) {
        _ticker?.cancel();
        _ticker = Timer.periodic(widget.precision, (_) {
          if (!mounted) return;
          final next = _compute();
          if (next != _label.value) _label.value = next;
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse?.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.inTheme;
    final style =
        widget.style ??
        TextStyle(
          color: tokens.ink,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDot && _pulse != null) ...[
          AnimatedBuilder(
            animation: _pulse!,
            builder: (_, _) => Opacity(
              opacity: 0.45 + (_pulse!.value * 0.55),
              child: Container(
                width: widget.dotSize,
                height: widget.dotSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tokens.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        ValueListenableBuilder<String>(
          valueListenable: _label,
          builder: (_, label, _) => Text(label, style: style),
        ),
      ],
    );
  }
}
