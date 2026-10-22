import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/nav_history_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/ui/features/shell/scaffold_with_nav.dart';
import 'package:admin/ui/features/shell/widgets/in_sidebar.dart';

import '../../../_localization_helper.dart';
import '_shell_test_helpers.dart';

/// The wide shell's geometry under each reading direction
/// (`docs/right-to-left-layout.md`). The rail is at the START side — the right
/// in Arabic, Persian and Hebrew, the side the phone drawer opens from — and
/// the content fills the rest. Before the conversion every layer was a
/// physical `Positioned(left: …)`, so an RTL user got the rail on the left
/// with the content's leading edge butted against it.
///
/// No other test mounts `ScaffoldWithNav` itself, so the harness is here: a
/// one-branch `StatefulShellRoute` over the shared `buildFixture` services.
const _kBody = ValueKey('shell.body');

void main() {
  late ShellFixture fixture;

  Future<void> pumpShell(WidgetTester tester, TextDirection direction) async {
    // The wide gate reads the window, which `setSurfaceSize` does not move.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    fixture = await buildFixture(
      companies: const [FakeCompany(id: 'c1', name: 'Acme Co')],
      closeStreamsSynchronously: true,
    );
    addTearDown(fixture.dispose);

    final router = GoRouter(
      initialLocation: '/dashboard',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              ScaffoldWithNav(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/dashboard',
                  builder: (_, _) => const SizedBox.expand(key: _kBody),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    final history = NavHistoryController.fromRouter(
      router: router,
      session: fixture.services.auth.session,
    );
    addTearDown(history.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: fixture.services),
          ChangeNotifierProvider<NavHistoryController>.value(value: history),
        ],
        child: MaterialApp.router(
          theme: ThemeData.light().copyWith(
            extensions: <ThemeExtension<dynamic>>[InTheme.light],
          ),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: router,
          builder: (context, child) =>
              Directionality(textDirection: direction, child: child!),
        ),
      ),
    );
    // Not pumpAndSettle: the fixture's Drift watch streams never settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Unmount before the fixture closes its database, so no watch stream is
  /// still subscribed when `db.close()` runs.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('left-to-right: the rail is at the left, content to its right', (
    tester,
  ) async {
    // The harness's control: the same assertions mirrored.
    await pumpShell(tester, TextDirection.ltr);

    final rail = tester.getRect(find.byType(InSidebar));
    final body = tester.getRect(find.byKey(_kBody));
    expect(rail.left, 0);
    expect(body.left, greaterThanOrEqualTo(rail.right));
    expect(body.right, 1400);
    await unmount(tester);
  });

  testWidgets('right-to-left: the rail is at the RIGHT edge, content to its '
      'left', (tester) async {
    await pumpShell(tester, TextDirection.rtl);

    final rail = tester.getRect(find.byType(InSidebar));
    final body = tester.getRect(find.byKey(_kBody));
    expect(rail.right, 1400);
    expect(rail.width, lessThanOrEqualTo(kInSidebarWidth));
    expect(body.left, 0);
    expect(
      body.right,
      lessThanOrEqualTo(rail.left),
      reason: 'the content must stop where the rail begins, not run under it',
    );
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
