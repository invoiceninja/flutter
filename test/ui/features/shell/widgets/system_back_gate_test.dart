// Regression tests for `SystemBackGate` (issue #39): the Android system back
// gesture used to drop the user on their launcher instead of navigating back
// in-app.
//
// The entity route block registers `<base>`, `<base>/new` and `<base>/:id` as
// SIBLINGS inside one `ShellRoute` (`buildEntityRouteBlock`), so a detail URL
// matches a single page and no navigator anywhere can pop. The harness below
// reproduces that exact shape — nesting `/quotes/:id` under `/quotes` would
// make these tests pass for the wrong reason.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/nav_history_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/ui/core/list/master_detail_layout.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/features/shell/widgets/system_back_gate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../_localization_helper.dart';

class _FakeServices implements Services {
  _FakeServices(this.unsavedChangesGuard);

  @override
  final UnsavedChangesGuard unsavedChangesGuard;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session() => AuthSession(
  baseUrl: 'https://example.com',
  isHosted: true,
  accountId: 'acc',
  companies: const [],
  currentCompanyId: 'co_1',
);

/// The platform message the engine sends on an Android back gesture. Mirrors
/// Flutter's own `simulateSystemBack` test helper
/// (packages/flutter/test/widgets/navigator_utils.dart). `handlePopRoute()` is
/// `@protected`, so calling it directly would trip the analyzer.
Future<void> simulateSystemBack(WidgetTester tester) {
  return tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMessageCodec().encodeMessage(<String, dynamic>{
      'method': 'popRoute',
    }),
    (ByteData? _) {},
  );
}

void main() {
  String currentUri(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          platformCalls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  bool? lastFrameworkHandlesBack() {
    for (final call in platformCalls.reversed) {
      if (call.method == 'SystemNavigator.setFrameworkHandlesBack') {
        return call.arguments as bool;
      }
    }
    return null;
  }

  bool didRequestAppExit() =>
      platformCalls.any((c) => c.method == 'SystemNavigator.pop');

  Future<(GoRouter, NavHistoryController)> pumpApp(
    WidgetTester tester, {
    String initialLocation = '/dashboard',
  }) async {
    tester.view.physicalSize = const Size(800, 1400); // narrow: phone-shaped
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        // Stands in for the app's `StatefulShellRoute` page: the ROOT
        // navigator's route, which is where the gate has to live so every
        // inner navigator is consulted before it.
        ShellRoute(
          builder: (context, state, child) => SystemBackGate(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, _) => const Scaffold(body: Text('DASHBOARD')),
            ),
            ShellRoute(
              pageBuilder: (context, state, child) => NoTransitionPage<void>(
                key: const ValueKey('master_detail:/quotes'),
                child: MasterDetailLayout(
                  basePath: '/quotes',
                  list: const Scaffold(body: Center(child: Text('LIST'))),
                  rightPane: child,
                  hasPane: state.matchedLocation != '/quotes',
                  viewMode: state.uri.queryParameters['view'],
                ),
              ),
              routes: [
                GoRoute(
                  path: '/quotes',
                  builder: (_, _) => const SizedBox.shrink(),
                ),
                GoRoute(
                  path: '/quotes/:id',
                  builder: (_, state) => Scaffold(
                    body: Text('DETAIL ${state.pathParameters['id']}'),
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (_, _) => const Scaffold(body: Text('EDIT')),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    final session = ValueNotifier<AuthSession?>(_session());
    addTearDown(session.dispose);
    final history = NavHistoryController.fromRouter(
      router: router,
      session: session,
    );
    addTearDown(history.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Services>.value(value: _FakeServices(UnsavedChangesGuard())),
          ChangeNotifierProvider<NavHistoryController>.value(value: history),
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
    return (router, history);
  }

  testWidgets('system back on a detail route returns to the list, '
      'not the launcher', (tester) async {
    final (router, _) = await pumpApp(tester);

    // Seeded with explicit navigations rather than relying on the router's
    // initial configuration reaching the controller before it subscribed.
    router.go('/quotes');
    await tester.pumpAndSettle();
    router.go('/quotes/q_1');
    await tester.pumpAndSettle();
    expect(find.text('DETAIL q_1'), findsOneWidget);

    await simulateSystemBack(tester);
    await tester.pumpAndSettle();

    expect(currentUri(router), '/quotes');
    expect(
      didRequestAppExit(),
      isFalse,
      reason: 'back had somewhere to go in-app, so the app must not exit',
    );
  });

  testWidgets('system back walks the history from a bare list URL', (
    tester,
  ) async {
    final (router, history) = await pumpApp(tester);

    router.go('/quotes');
    await tester.pumpAndSettle();
    router.go('/dashboard');
    await tester.pumpAndSettle();
    router.go('/quotes');
    await tester.pumpAndSettle();
    expect(history.canGoBack, isTrue);

    // A bare list URL leaves the entity ShellRoute's Navigator with nothing to
    // show. It must stay mounted anyway: go_router dereferences its
    // navigatorKey with a bang while looking for something to pop, so an
    // unmounted one makes the whole gesture throw.
    await simulateSystemBack(tester);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(currentUri(router), '/dashboard');
  });

  testWidgets('system back exits the app once history is exhausted', (
    tester,
  ) async {
    final (router, history) = await pumpApp(tester, initialLocation: '/quotes');
    expect(history.canGoBack, isFalse);

    await simulateSystemBack(tester);
    await tester.pumpAndSettle();

    expect(currentUri(router), '/quotes');
    expect(
      didRequestAppExit(),
      isTrue,
      reason: 'back must always be able to leave the app',
    );
  });

  testWidgets('an inner navigator still wins: edit pops to its detail', (
    tester,
  ) async {
    final (router, _) = await pumpApp(tester);

    router.go('/quotes');
    await tester.pumpAndSettle();
    router.go('/quotes/q_1');
    await tester.pumpAndSettle();
    router.go('/quotes/q_1/edit');
    await tester.pumpAndSettle();

    // `edit` nests under `:id`, so the entity shell's Navigator holds two
    // pages and pops natively — the gate must not get in front of that.
    await simulateSystemBack(tester);
    await tester.pumpAndSettle();
    expect(currentUri(router), '/quotes/q_1');

    // …and that pop is recorded as structural "up", so the next back does not
    // walk forward into the editor the user just left.
    await simulateSystemBack(tester);
    await tester.pumpAndSettle();
    expect(currentUri(router), '/quotes');
  });

  testWidgets('an open dialog consumes back before the gate does', (
    tester,
  ) async {
    final (router, _) = await pumpApp(tester);

    router.go('/quotes');
    await tester.pumpAndSettle();
    router.go('/quotes/q_1');
    await tester.pumpAndSettle();

    final context = tester.element(find.text('DETAIL q_1'));
    unawaitedShowDialog(context);
    await tester.pumpAndSettle();
    expect(find.text('DIALOG'), findsOneWidget);

    await simulateSystemBack(tester);
    await tester.pumpAndSettle();

    expect(find.text('DIALOG'), findsNothing);
    expect(currentUri(router), '/quotes/q_1');
  });

  testWidgets('the platform keeps being told we handle back after a '
      'row-to-row jump', (tester) async {
    // Reset inside the body, not via addTearDown: the framework asserts every
    // foundation debug variable is back to null before the tear-downs run.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final (router, _) = await pumpApp(tester);
    // WidgetsApp ignores NavigationNotifications until it has a lifecycle
    // state, which a test binding does not supply on its own.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    router.go('/quotes');
    await tester.pumpAndSettle();
    router.go('/quotes/q_1');
    await tester.pumpAndSettle();
    // The entity shell's Navigator swaps its single page here and announces
    // `canHandlePop: false`. Unswallowed, that stale answer reaches WidgetsApp
    // and Android goes back to killing the Activity — the fix would work
    // exactly once per screen.
    router.go('/quotes/q_2');
    await tester.pumpAndSettle();

    expect(lastFrameworkHandlesBack(), isTrue);

    await simulateSystemBack(tester);
    await tester.pumpAndSettle();
    expect(currentUri(router), '/quotes/q_1');

    debugDefaultTargetPlatformOverride = null;
  });
}

void unawaitedShowDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (_) => const AlertDialog(content: Text('DIALOG')),
  );
}
