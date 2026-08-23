// Regression tests for the Settings AppBar leading widget (issue #40).
//
// On Android a settings sub-page showed a hamburger, so getting back to the
// Settings menu meant opening the drawer and tapping Settings again. The
// leading slot is decided by `SettingsScreenScaffold`, which ~40 screens funnel
// through; it used to key off window width alone and never asked whether it was
// on the index or a sub-page.
//
// The rule under test: a back arrow appears whenever the settings section list
// is NOT beside the page (`SettingsTwoPaneScope`) and the route can pop.
// Nothing here pumps wide-only — that blind spot is why this shipped.

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/ui/core/adaptive.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/models/domain/company_settings.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/views/settings_screen.dart';
import 'package:admin/ui/features/settings/view_models/settings_draft_view_model.dart';
import 'package:admin/ui/features/settings/widgets/settings_page_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_screen_scaffold.dart';
import 'package:admin/ui/features/settings/widgets/settings_two_pane_scope.dart';
import 'package:admin/ui/features/shell/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../_localization_helper.dart';

/// Minimal dirty settings VM: enough for `SettingsPageScaffold`'s `PopScope`
/// discard guard to engage.
class _DirtyHost extends SettingsDraftHost {
  bool wasReset = false;

  @override
  Future<Object?> save() async => 1;
  @override
  CompanySettings get settings => const CompanySettings();
  @override
  CompanySettings get draftSettings => const CompanySettings();
  @override
  Company? get draft => Company();
  @override
  Map<String, List<String>> get fieldErrors => const {};
  @override
  void updateSettings(CompanySettings Function(CompanySettings) edit) {}
  @override
  bool get isLoaded => true;
  @override
  bool get isDirty => !wasReset;
  @override
  bool get isSaving => false;
  @override
  String? get loadError => null;
  @override
  String? get submitError => null;
  @override
  void reset() {
    wasReset = true;
    notifyListeners();
  }

  @override
  Future<void> load() async {}
}

/// The real `/settings` index renders the section list, which watches the auth
/// session for module gating. Signed-out is enough — the assertions are about
/// the AppBar, not the list.
class _NoAuth implements AuthRepository {
  const _NoAuth();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeAuth implements AuthRepository {
  @override
  final ValueNotifier<AuthSession?> session = ValueNotifier<AuthSession?>(null);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices({this.auth = const _NoAuth()});

  @override
  final AuthRepository auth;

  // `SettingsPageScaffold` wraps itself in an `UnsavedChangesScope`, which
  // registers with the app-wide guard.
  @override
  final UnsavedChangesGuard unsavedChangesGuard = UnsavedChangesGuard();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  /// `SettingsScreenScaffold` renders a `SettingsScopeBanner` in its body,
  /// which watches the cascade-level controller.
  Widget wrap(WidgetTester tester, Widget child, {AuthRepository? auth}) {
    final level = SettingsLevelController();
    addTearDown(level.dispose);
    return MultiProvider(
      providers: [
        Provider<Services>.value(
          value: auth == null ? _FakeServices() : _FakeServices(auth: auth),
        ),
        ChangeNotifierProvider<SettingsLevelController>.value(value: level),
      ],
      child: child,
    );
  }

  String currentUri(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  /// Mirrors production: a `/settings` index page with a nested sub-page, both
  /// inside `SettingsShell` (which publishes the two-pane decision).
  Future<GoRouter> pumpSettings(
    WidgetTester tester, {
    required Size size,
    String initialLocation = '/settings/tax_rates',
    Widget index = const SettingsScreenScaffold(
      titleKey: 'settings',
      body: Text('INDEX'),
    ),
    AuthRepository? auth,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          // The real shell would pull in the whole settings sidebar; the only
          // thing this test needs from it is the two-pane signal it publishes.
          builder: (context, state, child) => LayoutBuilder(
            builder: (context, constraints) => SettingsTwoPaneScope(
              isTwoPane: constraints.maxWidth >= Breakpoints.settingsTwoPane,
              child: child,
            ),
          ),
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => index,
              routes: [
                GoRoute(
                  path: 'tax_rates',
                  builder: (_, _) => const SettingsScreenScaffold(
                    titleKey: 'tax_rates',
                    body: Text('SUB'),
                  ),
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
        auth: auth,
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a settings sub-page on a phone shows a back arrow that returns '
      'to the Settings menu', (tester) async {
    final router = await pumpSettings(tester, size: const Size(400, 900));

    expect(find.byType(BackButton), findsOneWidget);
    expect(
      find.byType(DrawerHamburger),
      findsNothing,
      reason: 'the hamburger used to own this slot — that IS issue #40',
    );

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(currentUri(router), '/settings');
    expect(find.text('INDEX'), findsOneWidget);
  });

  testWidgets('the Settings menu itself keeps the hamburger — it is a nav '
      'root, not a sub-page', (tester) async {
    // The REAL `SettingsScreen`, not a `SettingsScreenScaffold` standing in for
    // it: the index owns its own Scaffold, so hand-rolling one here would pin a
    // shape production never builds.
    final auth = _FakeAuth();
    addTearDown(auth.session.dispose);

    await pumpSettings(
      tester,
      size: const Size(400, 900),
      initialLocation: '/settings',
      index: const SettingsScreen(),
      auth: auth,
    );

    expect(find.byType(DrawerHamburger), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('the 600-880 band gets the arrow too — it has no section list '
      'either, so a sub-page is just as much a dead end', (tester) async {
    // A landscape phone / small window: the global rail is visible, so there
    // is no hamburger, but the settings two-pane has not kicked in yet.
    await pumpSettings(tester, size: const Size(800, 500));

    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(DrawerHamburger), findsNothing);
  });

  testWidgets('two-pane keeps an empty leading slot — the section list is '
      'already on screen, and /settings would redirect back out', (
    tester,
  ) async {
    await pumpSettings(tester, size: const Size(1400, 900));

    expect(find.byType(BackButton), findsNothing);
    expect(find.byType(DrawerHamburger), findsNothing);
    // Guards `automaticallyImplyLeading: false`: AppBar would otherwise
    // synthesize its own back button from `impliesAppBarDismissal`, which is
    // true on every nested settings page.
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).automaticallyImplyLeading,
      isFalse,
    );
  });

  testWidgets('an explicit leading still wins at every width', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap(
        tester,
        MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: const SettingsTwoPaneScope(
            isTwoPane: true,
            child: SettingsScreenScaffold(
              titleKey: 'settings',
              leading: BackButton(),
              body: Text('DRILL-IN'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('a dirty settings page prompts, then the arrow actually leaves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final host = _DirtyHost();
    final router = GoRouter(
      initialLocation: '/settings/tax_rates',
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              SettingsTwoPaneScope(isTwoPane: false, child: child),
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreenScaffold(
                titleKey: 'settings',
                body: Text('INDEX'),
              ),
              routes: [
                GoRoute(
                  path: 'tax_rates',
                  builder: (_, _) => SettingsPageScaffold<_DirtyHost>(
                    titleKey: 'tax_rates',
                    viewModel: host,
                    body: const Text('SUB'),
                  ),
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

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    // The guard used to call `maybePop`, whose disposition still read the
    // pre-reset `canPop: false` — so it re-entered its own callback, took the
    // `!isDirty` early-return, and stranded the user on the page they had just
    // discarded.
    expect(currentUri(router), '/settings');
    expect(find.text('INDEX'), findsOneWidget);
  });

  group('settingsBackTargetFor', () {
    test('sends each settings-hosted entity list up to the Settings menu', () {
      for (final routePath in const [
        '/settings/company_gateways',
        '/settings/payment_links',
        '/settings/expense_categories',
      ]) {
        expect(
          settingsBackTargetFor(routePath: routePath, menuVisible: true),
          '/settings',
          reason: routePath,
        );
      }
    });

    test('takes the entity registry route, so an open pane cannot move the '
        'target onto the list the user is already looking at', () {
      // The list stays mounted under a master-detail pane, so a live-URL input
      // would read `/settings/expense_categories/cat_1` here and point the
      // arrow at the list itself. The registry route never changes.
      expect(
        settingsBackTargetFor(
          routePath: '/settings/expense_categories',
          menuVisible: true,
        ),
        '/settings',
      );
    });

    test('leaves ordinary entity lists alone', () {
      expect(
        settingsBackTargetFor(routePath: '/clients', menuVisible: true),
        isNull,
      );
      expect(
        settingsBackTargetFor(routePath: '/invoices', menuVisible: true),
        isNull,
      );
    });

    test('stays out of the way at widths where /settings does not show the '
        'menu', () {
      // Above `Breakpoints.settingsTwoPane` the index redirects to Company
      // Details, so an arrow promising "back to Settings" would strand the
      // user somewhere they never were.
      for (final routePath in const [
        '/settings/company_gateways',
        '/settings/payment_links',
        '/settings/expense_categories',
      ]) {
        expect(
          settingsBackTargetFor(routePath: routePath, menuVisible: false),
          isNull,
          reason: routePath,
        );
      }
    });
  });
}
