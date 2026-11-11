import 'dart:async';

import 'package:flutter/material.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/utils/show_seconds.dart';
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
    this.secondsPastDay = false,
    this.hoursOnly = false,
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
  /// kanban cards (the human eye doesn't follow seconds on a card). The
  /// device's Show Seconds preference overrides a coarser one with 1s.
  final Duration precision;

  /// Render the pulsing accent dot before the label.
  final bool showDot;

  /// When elapsed exceeds 24h, format as `Xd HHh MMm` instead of
  /// `HH:MM:SS` (which gets unreadable past 24 hours).
  final bool compactDays;

  /// Add seconds to the `Xd HHh MMm` form while the device's Show Seconds
  /// preference is on. Only a caller with room for the longer text opts in —
  /// the narrow list row, the wide table's 120 px column and the shell pill
  /// do not.
  final bool secondsPastDay;

  /// Render total hours that run past 24 (`36:30`, never `1d 12h`), with
  /// seconds only while the device's Show Seconds preference is on — the task
  /// list's format, which a stopped row shares (invoiceninja/flutter#183). The
  /// ticker still runs at [precision], so the minute rolls over on time; the
  /// label repaints only when its text changes. Overrides [compactDays] and
  /// [secondsPastDay].
  final bool hoursOnly;

  /// Override the label text style. Defaults to the screen's body small.
  final TextStyle? style;

  final double dotSize;

  @override
  State<RunningDurationLabel> createState() => _RunningDurationLabelState();
}

class _RunningDurationLabelState extends State<RunningDurationLabel>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _ticker;

  /// Null when [RunningDurationLabel.showDot] is false — no dot means no
  /// pulse, so we don't spin up a ticker that would keep scheduling frames
  /// for nothing (the wide duration column is the `showDot:false` caller).
  AnimationController? _pulse;

  /// Whether the user asked the OS for less motion; the dot then holds still.
  bool _reduceMotion = false;

  /// The pulse repeats forever, and a repeating animation is a full frame
  /// sixty times a second for as long as a timer runs — on every screen,
  /// because the shell's pill mounts this label. So it runs only while the app
  /// is `resumed` (on desktop: the window has focus). The framework stops
  /// frames by itself only once the app is `hidden`, and a Wayland compositor
  /// never tells the window it was minimized or covered, so there the pulse
  /// kept the GPU busy in the background for as long as a timer ran
  /// (invoiceninja/flutter#189). Losing focus is the one signal every platform
  /// sends. A null state (no lifecycle reported yet, and every widget test)
  /// counts as resumed.
  bool get _shouldPulse {
    final state = WidgetsBinding.instance.lifecycleState;
    return !_reduceMotion &&
        (state == null || state == AppLifecycleState.resumed);
  }

  /// Starts or parks the pulse to match [_shouldPulse]. Parked, the dot sits
  /// at full strength rather than wherever the fade happened to be.
  void _syncPulse() {
    final pulse = _pulse;
    if (pulse == null) return;
    if (_shouldPulse) {
      if (!pulse.isAnimating) pulse.repeat(reverse: true);
    } else {
      pulse
        ..stop()
        ..value = 1.0;
    }
  }

  AnimationController _newPulse() => AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _syncPulse();

  /// The rendered duration string. Driven by the ticker via a notifier so
  /// a tick repaints *only* the label `Text` (not the Row / dot /
  /// AnimatedBuilder), and only when the formatted value actually
  /// changed. This widget is mounted app-wide (the shell's running-timer
  /// pill) and one per kanban card, so a per-tick full rebuild here is
  /// disproportionately expensive.
  late final ValueNotifier<String> _label;

  /// The device's Show Seconds preference, read in [didChangeDependencies]
  /// so a flip re-ticks the label without rebuilding it from the outside.
  bool _secondsPref = false;

  Duration get _precision =>
      _secondsPref && widget.precision > const Duration(seconds: 1)
      ? const Duration(seconds: 1)
      : widget.precision;

  String _compute() {
    // When the ticker fires less often than once a second, the seconds
    // field would freeze for ~60s at a time — looks like a bug. Drop
    // seconds from the rendered text in that case (kanban cards opt in).
    final showSeconds = _precision < const Duration(minutes: 1);
    // Clamped at zero. `TimeEntryX.durationUpTo` already clamps, so nothing
    // this app writes can get here negative — but a foreign client can store a
    // running entry whose start is in the future, and `formatDuration` renders
    // that as `-0:30` (it splits `Duration.toString()`), on the app's most
    // prominent always-visible surface.
    final elapsed = DateTime.now().difference(widget.start);
    final total = widget.base + (elapsed.isNegative ? Duration.zero : elapsed);
    if (widget.hoursOnly) {
      return formatDuration(total, showSeconds: _secondsPref);
    }
    return formatDuration(
      total,
      compactDays: widget.compactDays,
      showSeconds: showSeconds,
      secondsPastDay: _secondsPref && widget.secondsPastDay,
    );
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_precision, (_) {
      if (!mounted) return;
      final next = _compute();
      if (next != _label.value) _label.value = next;
    });
  }

  @override
  void initState() {
    super.initState();
    _label = ValueNotifier<String>(_compute());
    _startTicker();
    WidgetsBinding.instance.addObserver(this);
    // Started in didChangeDependencies, which runs before the first build.
    if (widget.showDot) _pulse = _newPulse();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncPulse();
    final pref = watchShowSeconds(context);
    if (pref == _secondsPref) return;
    final before = _precision;
    _secondsPref = pref;
    _label.value = _compute();
    if (_precision != before) _startTicker();
  }

  @override
  void didUpdateWidget(RunningDurationLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `_pulse` is created in initState, so a State reused across a `showDot`
    // flip would otherwise be stuck: false→true leaves the dot permanently
    // missing, true→false leaves a repeating controller scheduling frames for
    // a dot that is never painted.
    if (oldWidget.showDot != widget.showDot) {
      _pulse?.dispose();
      _pulse = widget.showDot ? _newPulse() : null;
      _syncPulse();
    }
    if (oldWidget.start != widget.start ||
        oldWidget.base != widget.base ||
        oldWidget.hoursOnly != widget.hoursOnly ||
        oldWidget.precision != widget.precision) {
      _label.value = _compute();
      if (oldWidget.precision != widget.precision) _startTicker();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
