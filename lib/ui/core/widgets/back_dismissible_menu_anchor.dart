import 'package:flutter/material.dart';

/// A [MenuAnchor] that Android's **back** gesture closes, instead of navigating
/// away from the screen underneath it.
///
/// `MenuAnchor` binds Escape (`DismissMenuAction`, `raw_menu_anchor.dart`) and
/// Flutter wraps its panel in a `TapRegion` that closes on an outside tap — so
/// desktop and touch-tap both work. But it is **not a route** and carries no
/// back handling whatsoever: there is no `PopScope`, `BackButtonListener` or
/// `NavigatorPopHandler` anywhere in `menu_anchor.dart` or
/// `raw_menu_anchor.dart`. `PopupMenuButton`, which these menus replaced, is a
/// `_PopupMenuRoute extends PopupRoute`, so back closed it for free. Matching
/// its outside-tap semantics (`consumeOutsideTap: true`) while silently
/// dropping its back semantics is what left every entity list row's `⋮` in a
/// state where Android's back navigated off the list rather than closing the
/// menu — invisible on a reviewer's desktop, which has Escape.
///
/// **A `PopScope` cannot fix this.** `ModalRoute.onPopInvokedWithResult`
/// notifies *every* registered `PopEntry`, so a `canPop: false` entry here
/// would stop nothing: `SystemBackGate`'s entry (`system_back_gate.dart`) is
/// registered on the same route and its handler would still run
/// `NavHistoryController.back()`. The fix has to sit **above** route popping,
/// which is what a `ChildBackButtonDispatcher` is: `Router` consults its
/// children before it calls `popRoute()` at all.
///
/// Registered only while the menu is open, and **imperatively rather than
/// through `BackButtonListener`**. That widget registers in
/// `didChangeDependencies`, which leaves two bad options: mount it always and
/// every visible list row puts a dispatcher in the parent's child list (each
/// re-taking priority on any `Router` notification, since `Router.of`
/// establishes a dependency), or mount it only while open and the tree depth
/// around `MenuAnchor` changes — which re-inflates its element, disposing the
/// very menu the listener exists to close.
///
/// The `Router` is looked up with `maybeOf`, so a host without one (a widget
/// test that pumps a bare `MaterialApp`, a widget preview) degrades to plain
/// `MenuAnchor` behaviour rather than throwing.
///
/// `test/lint/menu_anchor_back_dismiss_test.dart` fails the build on a bare
/// `MenuAnchor` in `lib/`.
class BackDismissibleMenuAnchor extends StatefulWidget {
  const BackDismissibleMenuAnchor({
    super.key,
    required this.menuChildren,
    required this.builder,
    this.consumeOutsideTap = false,
  });

  /// Passed through to [MenuAnchor.menuChildren].
  final List<Widget> menuChildren;

  /// Passed through to [MenuAnchor.builder]. The `MenuController` handed to it
  /// is this widget's own, so the usual
  /// `controller.isOpen ? controller.close() : controller.open()` trigger works
  /// unchanged.
  final MenuAnchorChildBuilder builder;

  /// Passed through to [MenuAnchor.consumeOutsideTap] — `true` where an outside
  /// tap should only dismiss the menu rather than also activating whatever it
  /// landed on.
  final bool consumeOutsideTap;

  @override
  State<BackDismissibleMenuAnchor> createState() =>
      _BackDismissibleMenuAnchorState();
}

class _BackDismissibleMenuAnchorState extends State<BackDismissibleMenuAnchor> {
  final MenuController _controller = MenuController();

  /// Cached in [didChangeDependencies] rather than read on open: `Router.of`
  /// depends on an inherited widget, and taking that dependency lazily from a
  /// callback is what makes the framework complain about it.
  BackButtonDispatcher? _root;
  ChildBackButtonDispatcher? _child;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _root = Router.maybeOf(context)?.backButtonDispatcher;
  }

  @override
  void dispose() {
    // A menu open at dispose never gets its `onClose`.
    _release();
    super.dispose();
  }

  void _claim() {
    if (_child != null) return;
    final root = _root;
    if (root == null) return;
    _child = root.createChildBackButtonDispatcher()
      ..addCallback(_onBack)
      ..takePriority();
  }

  void _release() {
    // `removeCallback` is what un-registers us: the child forgets itself from
    // its parent once it has no callbacks left.
    _child?.removeCallback(_onBack);
    _child = null;
  }

  Future<bool> _onBack() async {
    // Defensive: `onClose` should always have released us first, but a stale
    // registration must never swallow the user's back.
    if (!_controller.isOpen) return false;
    _controller.close();
    return true; // handled — the Router does not pop
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _controller,
      consumeOutsideTap: widget.consumeOutsideTap,
      menuChildren: widget.menuChildren,
      onOpen: _claim,
      onClose: _release,
      builder: widget.builder,
    );
  }
}
