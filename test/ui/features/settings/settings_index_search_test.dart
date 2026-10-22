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

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/search_focus_registry.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/features/settings/settings_search_catalog.dart';
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

  // The index claims `/` for its search.
  @override
  final SearchFocusRegistry searchFocus = SearchFocusRegistry();

  // The search watches the active company for its PEPPOL gate.
  @override
  final CompanyRepository company = _FakeCompanyRepo();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

/// No company record: the search's PEPPOL gate then fails open.
class _FakeCompanyRepo implements CompanyRepository {
  @override
  Stream<Company?> watchCompany(String companyId) => Stream.value(null);

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
  late _FakeServices services;

  Widget wrap(WidgetTester tester, Widget child) {
    final auth = _FakeAuth();
    addTearDown(auth.session.dispose);
    final level = SettingsLevelController();
    addTearDown(level.dispose);
    services = _FakeServices(auth);
    return MultiProvider(
      providers: [
        Provider<Services>.value(value: services),
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
                // Any other section or tab a hit can open.
                GoRoute(
                  path: ':section',
                  builder: (_, state) =>
                      Scaffold(body: Text('PAGE ${state.uri.path}')),
                  routes: [
                    GoRoute(
                      path: ':tab',
                      builder: (_, state) =>
                          Scaffold(body: Text('PAGE ${state.uri.path}')),
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

    // 'postal' matches exactly one field label in the whole catalog. The
    // title is a rich text now (the match is bold), so find it by its text.
    expect(find.text('Postal Code', findRichText: true), findsOneWidget);
    // The subtitle names the tab the hit opens.
    expect(find.text('Company Details › Address'), findsOneWidget);
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

  testWidgets('the wide pane owns its own title + affordance and pins them '
      'above the scroll area — it has no AppBar to host them', (tester) async {
    await pumpBarePane(tester);

    // Present, and outside the ListView: same invariant, different chrome.
    expect(find.widgetWithIcon(IconButton, Icons.search), findsOneWidget);
    expect(searchButton(within: find.byType(ListView)), findsNothing);
    // The screen title the narrow layout gets from its AppBar. Exactly one, so
    // the pane can't grow a second copy inside the list.
    expect(find.text('Settings'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(find.text('Advanced Settings'), findsOneWidget);
    expect(
      find.widgetWithIcon(IconButton, Icons.search),
      findsOneWidget,
      reason: 'the pinned strip keeps it reachable at any scroll position',
    );
    expect(
      find.text('Settings'),
      findsOneWidget,
      reason: 'the screen title is pinned, so it survives any scroll position',
    );
    expect(
      find.text('Basic Settings'),
      findsNothing,
      reason:
          'the pinned strip carries the SCREEN title, never a group label — '
          'hoisting "Basic Settings" would leave it claiming Basic down here '
          'in Advanced',
    );

    // And it still opens the in-pane field row.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.search));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithIcon(IconButton, Icons.close), findsOneWidget);
  });

  group('keyboard and empty query', () {
    /// What the list shows for [query] with this test's signed-out session:
    /// every module off, not an admin, hosted (the not-loaded fail-open).
    List<SettingsSearchHit> expectedHits(String query) => searchSettings(
      query,
      bundledLocalization(),
      scope: const SettingsSearchScope(
        enabledModules: 0,
        isAdminOrOwner: false,
        isCascade: false,
        isHosted: true,
      ),
    );

    testWidgets('an open search with nothing typed still lists the sections', (
      tester,
    ) async {
      // It used to list every field in the catalog — hundreds of rows.
      await pumpIndex(tester);
      await tester.tap(searchButton());
      await tester.pumpAndSettle();

      expect(find.text('Basic Settings'), findsOneWidget);
      expect(find.text('Company Details'), findsOneWidget);
    });

    testWidgets('a section name leads with the section itself', (tester) async {
      await pumpIndex(tester);
      await tester.tap(searchButton());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'tax settings');
      await tester.pumpAndSettle();

      final first = tester.widget<ListTile>(find.byType(ListTile).first);
      expect(((first.title! as Text).textSpan!).toPlainText(), 'Tax Settings');
    });

    testWidgets('Enter opens the field\'s tab', (tester) async {
      final router = await pumpIndex(tester);
      await tester.tap(searchButton());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'postal');
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(currentUri(router), '/settings/company_details/address');
    });

    testWidgets('↓ then Enter opens the second row, and Esc closes', (
      tester,
    ) async {
      final router = await pumpIndex(tester);
      await tester.tap(searchButton());
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'number');
      await tester.pumpAndSettle();

      final hits = expectedHits('number');
      expect(hits.length, greaterThan(2));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .elementAt(1)
            .selected,
        isTrue,
      );
      // The selected row's title takes the tile's selected colour — a styled
      // span with its own colour used to keep it in body ink.
      final hit1 = hits[1];
      final title = tester.widget<RichText>(
        find.descendant(
          of: find.byType(ListTile).at(1),
          matching: find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText() ==
                    bundledLocalization().lookup(hit1.fieldKey),
          ),
        ),
      );
      expect(_leafColor(title.text), InTheme.light.accentInk);

      // Up wraps from the top to the last row and back down again.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(currentUri(router), hits[1].route);

      // Back on the index, reopen and close with Esc.
      router.go('/settings');
      await tester.pumpAndSettle();
      await tester.tap(searchButton());
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(searchButton(), findsOneWidget);
    });

    testWidgets('`/` opens the search on the settings index', (tester) async {
      await pumpIndex(tester);
      expect(find.byType(TextField), findsNothing);

      services.searchFocus.activate();
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.focusNode?.hasFocus, isTrue);
    });
  });
}

/// The colour the first non-empty run of [span] is painted in, with every
/// ancestor span's style merged in — what the user sees, not just the root.
Color? _leafColor(InlineSpan span, [TextStyle? inherited]) {
  final style = inherited == null
      ? span.style
      : (span.style == null ? inherited : inherited.merge(span.style));
  if (span is TextSpan) {
    if (span.text?.isNotEmpty ?? false) return style?.color;
    for (final child in span.children ?? const <InlineSpan>[]) {
      final c = _leafColor(child, style);
      if (c != null) return c;
    }
  }
  return null;
}
