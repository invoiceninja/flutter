import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

/// Single global renderer for [ToastController]. Mounted once near the app
/// root (see `main.dart`), it floats above every route AND modal dialog/sheet
/// because it's a later sibling in the root `Stack` (Flutter compositing is
/// tree-order; a dialog living inside the route navigator can't escape above
/// it). It lays out only a small corner column, so taps outside a toast fall
/// through to whatever is behind (including a dialog barrier).
///
/// Responsive:
/// * **Wide (≥ [Breakpoints.wide])** — top-right, newest nearest the corner,
///   older stacking downward; each card carries a close button (mouse users
///   can't swipe) and pauses its auto-dismiss timer while hovered.
/// * **Narrow** — a single bottom toast, swipe-to-dismiss.
class ToastHost extends StatefulWidget {
  const ToastHost({required this.controller, super.key});

  final ToastController controller;

  @override
  State<ToastHost> createState() => _ToastHostState();
}

class _ToastHostState extends State<ToastHost> {
  /// Rendered toasts — a superset of the controller's live list: a toast
  /// removed from the controller lingers here (flagged in [_exiting]) until
  /// its exit animation finishes, so it can animate out instead of snapping.
  final List<ToastData> _rendered = [];
  final Set<int> _exiting = {};

  /// Ids painted in the previous frame. `_sync` only animates out a departed
  /// toast that was actually on screen; toasts dismissed while unpainted
  /// (queued past the cap, or any non-newest toast on mobile) have no entry to
  /// drive their exit, so they're dropped immediately instead of lingering.
  final Set<int> _painted = {};

  @override
  void initState() {
    super.initState();
    _rendered.addAll(widget.controller.toasts);
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(ToastHost old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    // The host is the sole renderer and is mounted once at the app root, so it
    // only unmounts at teardown — cancel pending auto-dismiss timers so they
    // don't outlive the tree (and so widget tests don't trip the pending-timer
    // check). `removeListener` above means this clear won't re-enter `_sync`.
    widget.controller.clearAll();
    super.dispose();
  }

  void _sync() {
    final live = widget.controller.toasts;
    final liveIds = {for (final t in live) t.id};
    setState(() {
      for (final t in live) {
        final i = _rendered.indexWhere((e) => e.id == t.id);
        if (i == -1) {
          _rendered.add(t);
        } else {
          _rendered[i] = t; // pick up a dedup ×N bump
          _exiting.remove(t.id);
        }
      }
      // Departed toasts: animate out the ones that were on screen last frame;
      // drop the rest immediately (no `_ToastEntry` exists to call `_onExited`,
      // so keeping them would leak in `_rendered` and could resurface as a
      // stale ghost on mobile).
      _rendered.removeWhere((r) {
        if (liveIds.contains(r.id)) return false;
        if (_painted.contains(r.id)) {
          _exiting.add(r.id);
          return false;
        }
        _exiting.remove(r.id);
        return true;
      });
    });
  }

  void _onExited(int id) {
    if (!mounted) return;
    setState(() {
      _rendered.removeWhere((e) => e.id == id);
      _exiting.remove(id);
    });
  }

  /// Record which toast ids are painted this frame, and schedule removal of any
  /// `_exiting` toast that has no painted entry to animate it out (the rare
  /// case where a card is pushed past the cap by newer toasts mid-exit). Without
  /// this its `_ToastEntry` unmounts before firing `_onExited`, so it would
  /// linger in `_rendered`.
  void _trackPainted(Set<int> ids) {
    _painted
      ..clear()
      ..addAll(ids);
    final orphans = _exiting.where((id) => !ids.contains(id)).toList();
    if (orphans.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        for (final id in orphans) {
          _rendered.removeWhere((e) => e.id == id);
          _exiting.remove(id);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_rendered.isEmpty) {
      _painted.clear();
      return const SizedBox.shrink();
    }
    final isWide = MediaQuery.sizeOf(context).width >= Breakpoints.wide;
    final padding = MediaQuery.paddingOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);

    if (isWide) {
      // Top-right, newest at the top. Cap how many we actually paint to the
      // available height so a tall stack can't run off-screen (the controller
      // bounds its own list too).
      final maxCards = ((MediaQuery.sizeOf(context).height - 120) / 76)
          .floor()
          .clamp(1, _rendered.length);
      final newestFirst = _rendered.reversed.take(maxCards).toList();
      _trackPainted({for (final t in newestFirst) t.id});
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 16 + padding.top,
            right: 16,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final t in newestFirst)
                    Padding(
                      key: ValueKey(t.id),
                      padding: const EdgeInsets.only(bottom: InSpacing.sm),
                      child: _ToastEntry(
                        data: t,
                        isWide: true,
                        exiting: _exiting.contains(t.id),
                        onExited: () => _onExited(t.id),
                        controller: widget.controller,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Narrow: a single bottom toast (the newest), swipe-to-dismiss.
    final current = _rendered.last;
    _trackPainted({current.id});
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 12,
          right: 12,
          bottom: 12 + padding.bottom + viewInsets.bottom,
          child: Dismissible(
            key: ValueKey('toast_${current.id}'),
            direction: DismissDirection.horizontal,
            // Dismissible owns the swipe-out animation and requires the widget
            // gone from the tree afterward — drop it from `_rendered` right
            // away (don't route through the exit-animation path) and cancel
            // its timer.
            onDismissed: (_) {
              _onExited(current.id);
              widget.controller.dismiss(current.id);
            },
            child: _ToastEntry(
              key: ValueKey(current.id),
              data: current,
              isWide: false,
              exiting: _exiting.contains(current.id),
              onExited: () => _onExited(current.id),
              controller: widget.controller,
            ),
          ),
        ),
      ],
    );
  }
}

const Duration _kEnterExit = Duration(milliseconds: 120);

/// One animated toast card: grows + fades + slides in on mount, and reverses
/// when [exiting] flips true, then calls [onExited]. Honors reduced motion.
class _ToastEntry extends StatefulWidget {
  const _ToastEntry({
    required this.data,
    required this.isWide,
    required this.exiting,
    required this.onExited,
    required this.controller,
    super.key,
  });

  final ToastData data;
  final bool isWide;
  final bool exiting;
  final VoidCallback onExited;
  final ToastController controller;

  @override
  State<_ToastEntry> createState() => _ToastEntryState();
}

class _ToastEntryState extends State<_ToastEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _kEnterExit,
    value: 0,
  );
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    _anim.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && widget.exiting) {
        widget.onExited();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.exiting) _anim.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Screen-reader announcement once per toast — a custom overlay (unlike
    // SnackBar) has no built-in a11y signal; errors are sometimes the only
    // notice a background save failed.
    if (!_announced) {
      _announced = true;
      final d = widget.data;
      final text = d.detail == null || d.detail!.isEmpty
          ? d.message
          : '${d.message}. ${d.detail}';
      SemanticsService.sendAnnouncement(
        View.of(context),
        text,
        Directionality.of(context),
      );
    }
  }

  @override
  void didUpdateWidget(_ToastEntry old) {
    super.didUpdateWidget(old);
    if (widget.exiting && !old.exiting) {
      _anim.reverse();
    } else if (!widget.exiting && old.exiting) {
      _anim.forward();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _anim.duration = reduceMotion ? Duration.zero : _kEnterExit;
    final curved = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    final slide = widget.isWide
        ? Tween<Offset>(begin: const Offset(0.12, 0), end: Offset.zero)
        : Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero);

    Widget card = _NotifyCard(
      data: widget.data,
      showClose: widget.isWide,
      onClose: () => widget.controller.dismiss(widget.data.id),
      onAction: widget.data.action == null
          ? null
          : () {
              widget.controller.dismiss(widget.data.id);
              widget.data.action!.onPressed();
            },
    );

    if (widget.isWide) {
      card = MouseRegion(
        onEnter: (_) => widget.controller.pause(widget.data.id),
        onExit: (_) => widget.controller.resume(widget.data.id),
        child: card,
      );
    }

    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(position: slide.animate(curved), child: card),
      ),
    );
  }
}

extension _VariantStyle on NotifyVariant {
  IconData get icon {
    switch (this) {
      case NotifyVariant.success:
        return Icons.check_circle_outline;
      case NotifyVariant.error:
        return Icons.error_outline;
      case NotifyVariant.warning:
        return Icons.warning_amber_outlined;
      case NotifyVariant.info:
        return Icons.info_outline;
    }
  }

  Color accent(InTheme t) {
    switch (this) {
      case NotifyVariant.success:
        return t.paid;
      case NotifyVariant.error:
        return t.overdue;
      case NotifyVariant.warning:
        return t.sent;
      case NotifyVariant.info:
        return t.partial;
    }
  }
}

/// The toast card visual — ported from the old `_NotifyCard` in `notify.dart`
/// (same tokens), plus a `×N` dedup badge and an optional desktop close button.
class _NotifyCard extends StatelessWidget {
  const _NotifyCard({
    required this.data,
    required this.showClose,
    required this.onClose,
    required this.onAction,
  });

  final ToastData data;
  final bool showClose;
  final VoidCallback onClose;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    final accent = data.variant.accent(t);
    final textTheme = Theme.of(context).textTheme;
    final titleStyle = textTheme.bodyMedium?.copyWith(
      color: t.ink,
      fontWeight: FontWeight.w600,
    );
    final detailStyle = textTheme.bodySmall?.copyWith(color: t.ink3);
    final action = data.action;

    return Material(
      type: MaterialType.transparency,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(InRadii.r2),
          border: Border.all(color: t.border),
          boxShadow: t.shadow2,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(InRadii.r2),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: InSpacing.md(context),
                    vertical: InSpacing.md(context),
                  ),
                  child: Icon(data.variant.icon, color: accent, size: 20),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: InSpacing.md(context),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                data.message,
                                style: titleStyle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (data.count > 1) ...[
                              const SizedBox(width: InSpacing.sm),
                              _CountBadge(count: data.count, accent: accent),
                            ],
                          ],
                        ),
                        if (data.detail != null && data.detail!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            data.detail!,
                            style: detailStyle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(left: InSpacing.xs),
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: accent,
                        textStyle: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(action.label.toUpperCase()),
                    ),
                  ),
                if (showClose)
                  Padding(
                    padding: const EdgeInsets.only(
                      right: InSpacing.xs,
                      left: InSpacing.xs,
                    ),
                    // No IconButton `tooltip:` here — ToastHost mounts ABOVE
                    // the root Navigator (Stack sibling of the router child in
                    // MaterialApp.builder), so there is no Overlay ancestor and
                    // Material's Tooltip asserts in debug / throws on hover in
                    // release. Semantics carries the accessibility label
                    // instead.
                    child: Semantics(
                      label: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      button: true,
                      child: IconButton(
                        onPressed: onClose,
                        iconSize: 16,
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        color: t.ink3,
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.accent});

  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final t = context.inTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(InRadii.r1),
      ),
      child: Text(
        '×$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: t.ink3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
