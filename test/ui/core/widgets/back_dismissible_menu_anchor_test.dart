import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:admin/ui/core/widgets/back_dismissible_menu_anchor.dart';

/// `MenuAnchor` is not a route, and carries no back handling of its own — no
/// `PopScope`, no `BackButtonListener`, nothing. `PopupMenuButton`, which the
/// app's menus replaced, was a `PopupRoute`, so back closed it for free.
/// Without [BackDismissibleMenuAnchor], pressing back with an entity row's `⋮`
/// open navigated off the list instead of closing the menu.
///
/// These drive a real `MaterialApp.router` + `GoRouter`, because the fix hangs
/// off `Router.backButtonDispatcher` — a bare `MaterialApp` has none, and the
/// widget deliberately degrades to plain `MenuAnchor` there, so a test pumped
/// that way would pass either way and prove nothing.
void main() {
  /// The platform's back gesture. `WidgetsBinding.handlePopRoute` is what the
  /// engine calls on Android; `RootBackButtonDispatcher` observes it.
  Future<void> pressBack(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<GoRouter> pumpMenu(
    WidgetTester tester, {
    required List<String> log,
  }) async {
    final router = GoRouter(
      initialLocation: '/two',
      routes: [
        GoRoute(path: '/one', builder: (_, _) => const Text('page one')),
        GoRoute(
          path: '/two',
          builder: (_, _) => Scaffold(
            body: Center(
              child: BackDismissibleMenuAnchor(
                consumeOutsideTap: true,
                menuChildren: [
                  MenuItemButton(
                    onPressed: () => log.add('picked'),
                    child: const Text('Archive'),
                  ),
                ],
                builder: (context, controller, _) => TextButton(
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                  child: const Text('open menu'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('back closes an open menu instead of navigating', (tester) async {
    final log = <String>[];
    final router = await pumpMenu(tester, log: log);

    await tester.tap(find.text('open menu'));
    await tester.pumpAndSettle();
    expect(find.text('Archive'), findsOneWidget);

    await pressBack(tester);

    expect(find.text('Archive'), findsNothing, reason: 'the menu must close');
    expect(
      router.state.uri.path,
      '/two',
      reason: 'and back must NOT have left the screen underneath it',
    );
    expect(log, isEmpty, reason: 'closing is not picking');
  });

  testWidgets('back still navigates when no menu is open', (tester) async {
    // The other half: the dispatcher is registered only while the menu is up,
    // so an ordinary back is untouched. Without this a fix for the first test
    // could simply swallow every back press on the screen.
    //
    // `push`, not `go` — the app itself only ever calls `go`, which REPLACES
    // the location, so there is nothing to pop and `SystemBackGate` +
    // `NavHistoryController` do the work instead (CLAUDE.md § Strict rules).
    // Neither is in this harness, so a pushed route is what gives back
    // something observable to do here.
    final log = <String>[];
    final router = await pumpMenu(tester, log: log);
    unawaited(router.push('/one'));
    await tester.pumpAndSettle();
    expect(find.text('page one'), findsOneWidget);

    await pressBack(tester);

    expect(find.text('open menu'), findsOneWidget);
  });

  testWidgets('a menu closed by picking releases its back handler', (
    tester,
  ) async {
    // `onClose` fires for every close path, not just ours — if it didn't, a
    // stale registration would keep eating back after the menu was gone.
    final log = <String>[];
    final router = await pumpMenu(tester, log: log);

    await tester.tap(find.text('open menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(log, ['picked']);

    unawaited(router.push('/one'));
    await tester.pumpAndSettle();
    await pressBack(tester);

    expect(
      find.text('open menu'),
      findsOneWidget,
      reason: 'back must work normally once the menu has been dismissed',
    );
  });
}
