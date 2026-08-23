// Regression tests for the Settings index search affordance (issue #42).
//
// The magnifying glass used to be the `trailing:` of the in-list "Basic
// Settings" group header — the first child of the section `ListView` — so on a
// phone it scrolled away and the only way back to it was to fling to the top,
// even though the AppBar above stayed pinned the whole time.
//
// The rule under test: the trigger lives in the pinned chrome, never in the
// scrolling body. On narrow that chrome is `SettingsScreen`'s AppBar (icon in
// `actions:`, field in a 56 px `bottom:`); on the wide 280 px pane, which has
// no AppBar, it's a group header lifted out of the scroll area.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/views/settings_screen.dart';
import 'package:admin/ui/features/settings/widgets/settings_two_pane_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';

/// The section list and the results both watch the auth session for module /
/// plan gating. A null session is enough — 23 ungated sections still render,
/// which is more than a 900 px viewport holds, so the list really scrolls.
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

  // A search hit's `onTap` runs the dirty guard before navigating.
  @override
  final UnsavedChangesGuard unsavedChangesGuard = UnsavedChangesGuard();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// Android's system back press, as the platform delivers it.
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
  Widget wrap(WidgetTester tester, Widget child) {
    final auth = _FakeAuth();
    addTearDown(auth.session.dispose);
    final level = SettingsLevelController();
    addTearDown(level.dispose);
    return MultiProvider(
      providers: [
        Provider<Services>.value(value: _FakeServices(auth)),
        ChangeNotifierProvider<SettingsLevelController>.value(value: level),
      ],
      child: child,
    );
  }

  void sizeTo(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// The real `/settings` index inside the shell that publishes the two-pane
  /// decision — production's exact shape on a phone.
  Future<GoRouter> pumpIndex(
    WidgetTester tester, {
    Size size = const Size(400, 900),
  }) async {
    sizeTo(tester, size);
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        ShellRoute(
          builder: (context, state, child) => LayoutBuilder(
            builder: (context, constraints) => SettingsTwoPaneScope(
              isTwoPane: constraints.maxWidth >= Breakpoints.settingsTwoPane,
              child: child,
            ),
          ),
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
              routes: [
                GoRoute(
                  path: 'company_details',
                  builder: (_, _) => const Scaffold(body: Text('COMPANY')),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      wrap(
        tester,
        MaterialApp.router(
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

  /// The bare section list with no host controller — how `SettingsShell`
  /// mounts it in the wide 280 px pane.
  Future<void> pumpBarePane(WidgetTester tester) async {
    sizeTo(tester, const Size(280, 900));
    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, _) =>
              const Scaffold(body: Material(child: SettingsListSidebar())),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      wrap(
        tester,
        MaterialApp.router(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // `widgetWithIcon(IconButton, ...)`, never `byIcon`: the search field's own
  // `prefixIcon` is also `Icons.search`.
  Finder searchButton({Finder? within}) => find.descendant(
    of: within ?? find.byType(AppBar),
    matching: find.widgetWithIcon(IconButton, Icons.search),
  );

  String currentUri(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  testWidgets('the search trigger lives in the pinned AppBar, so scrolling '
      'the section list cannot take it away (issue #42)', (tester) async {
    await pumpIndex(tester);

    expect(
      searchButton(),
      findsOneWidget,
      reason: 'before the fix the trigger was a child of the ListView',
    );
    expect(
      searchButton(within: find.byType(ListView)),
      findsNothing,
      reason: 'a second, scroll-away trigger is exactly the reported bug',
    );

    // Scroll well past the "Basic Settings" header — this is the exact gesture
    // in the reporter's second screenshot.
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Settings'), findsOneWidget);
    expect(searchButton(), findsOneWidget);
  });

  testWidgets('tapping it opens the field in the AppBar bottom strip and '
      'swaps the action to close', (tester) async {
    await pumpIndex(tester);

    await tester.tap(searchButton());
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(TextField),
      ),
      findsOneWidget,
      reason: 'the field is pinned in the header, not in the scrolling body',
    );
    expect(searchButton(), findsNothing);
    expect(find.widgetWithIcon(IconButton, Icons.close), findsOneWidget);
    // `AppBar` derives this from `bottom` — nothing to hand-maintain.
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).preferredSize.height,
      kToolbarHeight + 56,
    );
  });

  testWidgets('typing filters the catalog down to matching fields', (
    tester,
  ) async {
    await pumpIndex(tester);
    await tester.tap(searchButton());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'postal');
    await tester.pumpAndSettle();

    // 'postal' matches exactly one field label in the whole catalog.
    expect(find.text('Postal Code'), findsOneWidget);
    expect(find.text('Company Details'), findsOneWidget); // the hit's subtitle
    expect(
      find.text('Advanced Settings'),
      findsNothing,
      reason: 'the section list is replaced by results while searching',
    );
  });

  testWidgets('closing restores the section list and clears the query', (
    tester,
  ) async {
    await pumpIndex(tester);
    await tester.tap(searchButton());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'postal');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithIcon(IconButton, Icons.close));
    await tester.pumpAndSettle();

    expect(searchButton(), findsOneWidget);
    expect(find.text('Basic Settings'), findsOneWidget);

    // Reopen: the query must not have survived.
    await tester.tap(searchButton());
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller?.text,
      '',
    );
  });

  testWidgets(
    'Android back closes an open search instead of leaving Settings',
    (tester) async {
      final router = await pumpIndex(tester);
      await tester.tap(searchButton());
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(TextField),
        ),
        findsOneWidget,
      );

      await simulateSystemBack(tester);
      await tester.pumpAndSettle();

      expect(currentUri(router), '/settings');
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(TextField),
        ),
        findsNothing,
      );
      expect(searchButton(), findsOneWidget);
      expect(find.text('Basic Settings'), findsOneWidget);
    },
  );

  testWidgets('the wide pane owns its own affordance and pins it above the '
      'scroll area — it has no AppBar to host one', (tester) async {
    await pumpBarePane(tester);

    // Present, and outside the ListView: same invariant, different chrome.
    expect(find.widgetWithIcon(IconButton, Icons.search), findsOneWidget);
    expect(searchButton(within: find.byType(ListView)), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Settings'), findsOneWidget);
    expect(
      find.widgetWithIcon(IconButton, Icons.search),
      findsOneWidget,
      reason: 'the pinned strip keeps it reachable at any scroll position',
    );
    expect(
      find.text('Basic Settings'),
      findsNothing,
      reason:
          'the pinned strip is icon-only on purpose — hoisting the group '
          'label into it would leave it claiming Basic down here in Advanced',
    );

    // And it still opens the in-pane field row.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.close), findsOneWidget);
  });
}
