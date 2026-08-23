// Regression test for the settings two-pane shell (issue #39 follow-up).
//
// `SettingsShell` renders a "select a section" hint instead of the route's
// content on a wide `/settings` index. That content IS this ShellRoute's
// Navigator, and go_router resolves every shell's `navigatorKey` with a bang
// while looking for a route to pop (`_findCurrentNavigators`), so swapping it
// out made any platform back press throw. `settingsIndexRedirect` usually
// bounces the user off the index while wide, but it only runs on *navigation*:
// resizing narrow → wide while sitting on `/settings` lands here.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/views/settings_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';

/// The wide branch renders the real settings sidebar + scope banner, which
/// want an auth session and the cascade-level controller. A signed-out session
/// is enough — the assertions are about the ShellRoute child, not the list.
class _FakeAuth implements AuthRepository {
  @override
  final ValueNotifier<AuthSession?> session = ValueNotifier<AuthSession?>(null);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices(this.auth);
  @override
  final AuthRepository auth;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  Future<GoRouter> pumpApp(WidgetTester tester, {required Size size}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        ShellRoute(
          builder: (context, state, child) => SettingsShell(child: child),
          routes: [
            GoRoute(
              path: '/settings',
              // Keyed so the test can prove the Navigator that renders it is
              // still mounted even when the hint pane is showing instead.
              builder: (_, _) =>
                  const SizedBox.shrink(key: ValueKey('settings_route_probe')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final auth = _FakeAuth();
    addTearDown(auth.session.dispose);
    final level = SettingsLevelController();
    addTearDown(level.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: _FakeServices(auth)),
          ChangeNotifierProvider<SettingsLevelController>.value(value: level),
        ],
        child: MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('the settings shell keeps its Navigator mounted on the wide '
      'index, where it shows the select-a-section hint instead', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: const Size(Breakpoints.settingsTwoPane + 200, 900),
    );

    expect(
      find.byKey(const ValueKey('settings_route_probe'), skipOffstage: false),
      findsOneWidget,
      reason: 'dropping the ShellRoute child strands its navigatorKey',
    );
    expect(
      find.byKey(const ValueKey('settings_route_probe')),
      findsNothing,
      reason: 'the hint pane is what the user sees; the route stays hidden',
    );
  });

  testWidgets('narrow passes the route through untouched', (tester) async {
    await pumpApp(tester, size: const Size(500, 900));

    expect(
      find.byKey(const ValueKey('settings_route_probe')),
      findsOneWidget,
      reason: 'single-pane renders the route itself, nothing hidden',
    );
  });
}
