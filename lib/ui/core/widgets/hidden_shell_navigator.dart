import 'package:flutter/widgets.dart';

/// A `ShellRoute`'s Navigator, kept mounted but invisible.
///
/// go_router hands a `ShellRoute`'s builder a `child` that **is** the Navigator
/// for that shell's sub-routes. A shell whose layout renders something else
/// instead — `MasterDetailLayout` on a bare list URL, `SettingsShell` on the
/// wide `/settings` index — used to drop that child entirely, leaving
/// `navigatorKey.currentState` null. go_router dereferences that key with a
/// bang while walking for a route to pop (`_findCurrentNavigators`,
/// `go_router/src/delegate.dart`), so **any** platform back — the Android
/// gesture, and anything else that reaches `popRoute` — threw instead of
/// popping. That is why back could not dismiss a filter sheet or the app
/// drawer from a list screen (issue #39). Wrap the child in this instead of
/// dropping it.
///
/// What each layer is for, and one that is deliberately absent:
///
///  * `Offstage` — no paint, no hit-test, and the subtree leaves the semantics
///    tree, so a screen reader never sees a phantom screen. It still *lays
///    out* its child (`RenderOffstage.performLayout` forwards the incoming
///    constraints verbatim), which is why callers should hand it the same
///    constraints the visible pane would get rather than a 0×0 box.
///  * `FocusScope` — the framework grabs `navigator.focusNode.enclosingScope`
///    on route add/remove (`navigator.dart` `didAdd`/`didPush`,
///    `routes.dart` `setFirstFocus`). That lookup walks *up*, so an
///    `ExcludeFocus` alone can't contain it: without a scope of its own the
///    hidden Navigator's bookkeeping reaches the shell page's scope and can
///    yank focus out of whatever the user was typing in.
///  * `ExcludeFocus` — belt to the scope's braces: nothing inside can take
///    focus by traversal either.
///  * **No `TickerMode`.** Muting looks like a free saving and is not:
///    `NavigatorState` is a `TickerProviderStateMixin`, so a disabled
///    `TickerMode` mutes every route's exit `AnimationController`. The pop
///    that ran as the pane closed would never finish, `finalizeRoute` would
///    never fire, and the route the user just left would sit mounted and
///    undisposed — State, view-model, Drift subscriptions and timers alive —
///    for as long as they stayed on the list. Let the invisible transition
///    run; it disposes itself a few hundred milliseconds later.
class HiddenShellNavigator extends StatelessWidget {
  const HiddenShellNavigator({required this.child, super.key});

  /// The `ShellRoute` builder's `child` — the Navigator itself.
  final Widget child;

  @override
  Widget build(BuildContext context) => Offstage(
    child: ExcludeFocus(child: FocusScope(child: child)),
  );
}
