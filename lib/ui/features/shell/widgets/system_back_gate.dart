import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/nav_history_controller.dart';
import 'package:admin/app/services.dart';

/// Binds the platform back event (Android's back gesture / back key) to
/// [NavHistoryController] — the app's own browser-style history.
///
/// The app navigates exclusively with `context.go()`, which replaces the
/// location instead of pushing it, and an entity's list / detail / create
/// routes are *siblings* inside one `ShellRoute` (`buildEntityRouteBlock`).
/// So `/quotes/q_1` matches a single page, nothing anywhere can pop, and
/// Android used to finish the Activity — swiping back on a quote dropped the
/// user on their launcher instead of the quotes list (issue #39).
///
/// Mounted once, as the outermost wrapper of `ScaffoldWithNav` — the
/// `StatefulShellRoute` page, i.e. the **root** navigator's route. go_router
/// walks navigators innermost-first when the platform asks it to pop
/// (`_findCurrentNavigators`), so this is genuinely the last resort: dialogs,
/// bottom sheets, pushed modal sub-flows, an open `AppDrawer` (a
/// `LocalHistoryEntry`), every `/settings/**` sub-page, and `/x/:id/edit` all
/// still consume back first, discard guards included.
///
/// This is *history* back — return to the exact previous location, matching
/// the sidebar arrows and `Cmd/Alt+←`. The pane's leading `←` keeps performing
/// structural "up" (`entityCloseTargetPath`); together they are Android's
/// usual Back / Up pair.
class SystemBackGate extends StatelessWidget {
  const SystemBackGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Deliberately unconditional rather than `!canGoBack`: `PopScope` reads
      // `canPop` at build time, so a value lagging one navigation would let
      // back exit the app at exactly the moment it should navigate. The
      // handler below decides instead, and calls `SystemNavigator.pop()`
      // itself when there is genuinely nothing left to go back to.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _handleBack(context, didPop),
      child: NotificationListener<NavigationNotification>(
        // Keeps `SystemNavigator.setFrameworkHandlesBack` honest. `WidgetsApp`
        // applies whichever `NavigationNotification` reaches it last, and every
        // `NavigatorState` dispatches one on any history change — including the
        // entity shell's navigator swapping its single page (`/quotes/q_1` →
        // `/quotes/q_2`), which reports `canHandlePop: false`. A `PopScope`
        // only re-dispatches when its own `canPop` *flips*, so that stale
        // `false` would win and Android would go back to killing the Activity.
        // Same upgrade `Navigator.build` performs for itself.
        //
        // Don't remove this: without it the fix works exactly once per screen.
        onNotification: (notification) {
          if (notification.canHandlePop) return false; // propagate as-is
          const NavigationNotification(canHandlePop: true).dispatch(context);
          return true; // swallow the stale one
        },
        child: child,
      ),
    );
  }

  Future<void> _handleBack(BuildContext context, bool didPop) async {
    if (didPop) return;
    final history = context.read<NavHistoryController>();
    if (!history.canGoBack) {
      // Nothing left in-app — hand the gesture back to Android, which is what
      // it would have done unaided. Back must always be able to leave.
      await SystemNavigator.pop();
      return;
    }
    // Run the discard prompt up-front on the routes that carry the router's
    // `onExit` guard, exactly as `MasterDetailLayout._closePaneAnimated` does.
    // Letting `onExit` veto mid-navigation instead would strand
    // `NavHistoryController`'s cursor, which moves before it navigates.
    // `uri` (the full location), not `matchedLocation` — at the shell level
    // the latter is only the shell route's own slice of the path.
    final location = GoRouterState.of(context).uri.path;
    if (location.endsWith('/edit') || location.endsWith('/new')) {
      final guard = context.read<Services>().unsavedChangesGuard;
      if (!await guard.confirmIfDirty(context)) return; // user kept editing
      if (!context.mounted) return;
    }
    history.back();
  }
}
