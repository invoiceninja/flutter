import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'package:admin/app/env.dart';

/// A [SelectionArea] for a read-only surface (a record's detail body, the
/// activity feed), on **every** platform — long-press selects on touch, drag
/// selects with a mouse (invoiceninja/flutter#188).
///
/// With a mouse (`!Env.isTouchPrimary`) it **is** a bare [SelectionArea] —
/// nothing else is built, so desktop behaves exactly as it did. On touch it
/// adds the two dismissals a native selection has and Flutter's does not:
///
/// * **A tap anywhere that the region did not handle.** `SelectableRegion`
///   clears its selection on a tap only when *it* wins the tap. A tap on a
///   row, a tab, a tap-to-copy value — or on the app bar, outside the region
///   altogether — is won by someone else, and the selection and its menu
///   stayed up over whatever the tap did. While a selection shows, a global
///   pointer route sees every tap in the app, and after the next frame a
///   selection that is still there, over the same range, with its menu in the
///   same state, was not touched by the tap: it is dismissed. A changed range
///   is the menu's own Select all; a changed menu is iOS toggling it on a tap
///   on the selection; a gone selection is Android's own collapse.
/// * **Android's back.** A selection is not a route, so back would leave the
///   page under it. While one shows, a [ChildBackButtonDispatcher] takes back
///   first and clears it — the `BackDismissibleMenuAnchor` pattern, claimed
///   imperatively and only while there is something to dismiss.
///
/// Whether a selection shows is read live from a [SelectionListener] — never
/// remembered: a selection can vanish with no gesture at all (its text
/// unmounts on a tab switch or a record refresh), and a remembered flag then
/// swallowed the next back and the next tap-to-copy.
///
/// `CopyableValue`'s tap-to-copy calls [dismissSelection] first, so a tap on a
/// value while a selection shows dismisses it rather than also copying.
///
/// **Android only, upstream:** the region's touch recognizer claims a
/// horizontal drag at `kTouchSlop` (18) even though a touch drag never
/// selects. A `GestureDetector` under it reads the device's slop from
/// `MediaQuery` (~8 dp on Android, so a pan accepts at ~16) and still wins; a
/// recognizer built without gesture settings waits for `kPanSlop` (36) and
/// loses — fl_chart's, so a horizontal scrub across a chart in a detail body
/// does nothing there (a tap or a long-press-and-drag still reaches it). See
/// `docs/selecting-and-copying-text.md`.
class AppSelectionArea extends StatefulWidget {
  const AppSelectionArea({super.key, required this.child});

  final Widget child;

  /// Dismisses the selection showing in the nearest [AppSelectionArea] above
  /// [context]. True when there was one — the caller's tap was spent on it.
  static bool dismissSelection(BuildContext context) =>
      context.findAncestorStateOfType<_AppSelectionAreaState>()?._dismiss() ??
      false;

  @override
  State<AppSelectionArea> createState() => _AppSelectionAreaState();
}

class _AppSelectionAreaState extends State<AppSelectionArea> {
  final GlobalKey<SelectionAreaState> _areaKey = GlobalKey();
  final SelectionListenerNotifier _selection = SelectionListenerNotifier();

  BackButtonDispatcher? _root;
  ChildBackButtonDispatcher? _back;
  bool _routed = false;

  int? _tapPointer;
  Offset _tapDownAt = Offset.zero;
  Duration _tapDownTime = Duration.zero;
  bool _toolbarAtDown = false;
  (int, int)? _rangeAtDown;

  /// How many of the selection's context menus are mounted — counted by the
  /// menu's own mount and unmount ([_ToolbarPresence]), since the region's
  /// overlay is `@visibleForTesting`. A count, not a flag: a re-shown menu can
  /// mount its replacement before the old one is disposed.
  int _toolbars = 0;
  bool get _toolbarVisible => _toolbars > 0;

  @override
  void initState() {
    super.initState();
    _selection.addListener(_onSelectionChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Cached here, not on claim: claiming happens from a selection callback,
    // where taking an inherited dependency is not allowed. A swapped root
    // takes a standing claim with it.
    final root = Router.maybeOf(context)?.backButtonDispatcher;
    if (root == _root) return;
    final claimed = _back != null;
    _releaseBack();
    _root = root;
    if (claimed) _claimBack();
  }

  @override
  void dispose() {
    _release();
    _selection
      ..removeListener(_onSelectionChanged)
      ..dispose();
    super.dispose();
  }

  /// The selection the user can see: a non-empty one. Android collapses the
  /// selection on a tap rather than removing it, so "has a selection" alone
  /// reads true after any tap on plain text.
  bool get _selectionShowing =>
      _selection.registered &&
      _selection.selection.status == SelectionStatus.uncollapsed;

  (int, int)? get _range {
    if (!_selection.registered) return null;
    final range = _selection.selection.range;
    return range == null ? null : (range.startOffset, range.endOffset);
  }

  void _onSelectionChanged() => _selectionShowing ? _claim() : _release();

  bool _dismiss() {
    if (!_selectionShowing) return false;
    final region = _areaKey.currentState?.selectableRegion;
    if (region == null) return false;
    region
      ..hideToolbar()
      ..clearSelection();
    return true;
  }

  void _claim() {
    _claimBack();
    if (!_routed) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
      _routed = true;
    }
  }

  void _release() {
    _releaseBack();
    if (_routed) {
      GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
      _routed = false;
    }
    _tapPointer = null;
  }

  void _claimBack() {
    if (_back != null) return;
    final root = _root;
    if (root == null) return;
    _back = root.createChildBackButtonDispatcher()
      ..addCallback(_onBack)
      ..takePriority();
  }

  void _releaseBack() {
    // The child forgets itself from its parent once it has no callbacks.
    _back?.removeCallback(_onBack);
    _back = null;
  }

  Future<bool> _onBack() async {
    // Read live: a stale claim must never swallow the user's back.
    if (_dismiss()) return true;
    _release();
    return false;
  }

  void _onPointer(PointerEvent event) {
    switch (event) {
      case PointerDownEvent():
        // A second finger makes this a pinch or a two-finger scroll.
        if (_tapPointer != null || event.kind == PointerDeviceKind.mouse) {
          _tapPointer = null;
          return;
        }
        _tapPointer = event.pointer;
        _tapDownAt = event.position;
        _tapDownTime = event.timeStamp;
        _toolbarAtDown = _toolbarVisible;
        _rangeAtDown = _range;
      case PointerMoveEvent():
        if (event.pointer == _tapPointer &&
            (event.position - _tapDownAt).distance > kTouchSlop) {
          _tapPointer = null;
        }
      case PointerUpEvent():
        if (event.pointer != _tapPointer) return;
        _tapPointer = null;
        if (event.timeStamp - _tapDownTime >= kLongPressTimeout) return;
        _afterTap();
      case PointerCancelEvent():
        if (event.pointer == _tapPointer) _tapPointer = null;
      default:
        break;
    }
  }

  void _afterTap() {
    final toolbarAtDown = _toolbarAtDown;
    final rangeAtDown = _rangeAtDown;
    // After the next frame, not a microtask: by then the arena has given the
    // tap to someone and what it did has landed. A menu the region hid has
    // its overlay entry removed synchronously but disposed only when the frame
    // finalizes, so a microtask still counted it and read iOS's toggle-off as
    // "unchanged", dismissing a selection the user was tapping to keep.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_selectionShowing) {
          _release();
          return;
        }
        if (_toolbarVisible != toolbarAtDown || _range != rangeAtDown) return;
        _dismiss();
      })
      ..scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    if (!Env.isTouchPrimary) return SelectionArea(child: widget.child);
    return SelectionArea(
      key: _areaKey,
      // SelectionArea's own default, wrapped so its presence is known.
      contextMenuBuilder: (context, region) => _ToolbarPresence(
        onChanged: (mounted) => _toolbars += mounted ? 1 : -1,
        child: AdaptiveTextSelectionToolbar.selectableRegion(
          selectableRegionState: region,
        ),
      ),
      child: SelectionListener(
        selectionNotifier: _selection,
        child: widget.child,
      ),
    );
  }
}

/// Reports whether the context menu it wraps is mounted.
class _ToolbarPresence extends StatefulWidget {
  const _ToolbarPresence({required this.onChanged, required this.child});

  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  State<_ToolbarPresence> createState() => _ToolbarPresenceState();
}

class _ToolbarPresenceState extends State<_ToolbarPresence> {
  @override
  void initState() {
    super.initState();
    widget.onChanged(true);
  }

  @override
  void dispose() {
    widget.onChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
