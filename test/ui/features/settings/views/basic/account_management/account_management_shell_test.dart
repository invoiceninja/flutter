// Pins how AccountManagementShell reacts to a hosted-only tab.
//
// The unit test next door (account_management_tabs_test.dart) covers the slug
// filter itself; this covers the two things only the live shell can get wrong:
// the TabBar rendering the filtered set, and the shell rewriting a URL that
// names a tab it no longer shows. Without that rewrite a self-hosted session
// deep-linked to `…/referral_program` sits on the Plan tab while the location
// still claims otherwise — `_indexForSlug` falls back to 0, so the controller
// index never changes and the tab listener never fires.
//
// The surface is kept wide so `SettingsScreenScaffold` skips the AppDrawer, and
// the session carries no company so the shell's mount-time company refresh
// short-circuits before touching `Services.company`.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/app/design_tokens.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/features/settings/settings_routes.dart';
import 'package:admin/ui/features/settings/state/settings_level_controller.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/account_management_shell.dart';

import '../../../../../../_localization_helper.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(this._session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeServices implements Services {
  _FakeServices({required this.auth});
  @override
  final AuthRepository auth;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session({required bool isHosted}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: isHosted,
  accountId: 'acct',
  companies: const [],
  // Empty so `_refreshCompany` returns before reaching `Services.company`.
  currentCompanyId: '',
);

/// Pumps the shell behind the REAL `tabbedSettingsRoutePair` wiring, returning
/// the router so tests can read the resolved location. Using the production
/// helper matters: it emits the bare path and the `:tab` path as *sibling*
/// routes sharing one page key, so both resolve to a single Navigator Page. A
/// hand-rolled parent/child nesting instead stacks two shells, and the covered
/// one then fights the visible one over the tab index.
Future<GoRouter> _pump(
  WidgetTester tester, {
  required bool isHosted,
  String initialLocation = '/settings/account_management',
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final services = _FakeServices(
    auth: _FakeAuth(ValueNotifier(_session(isHosted: isHosted))),
  );
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/settings',
        builder: (_, _) => const Text('settings-list'),
        routes: tabbedSettingsRoutePair(
          path: 'account_management',
          pageKey: 'account_management_shell',
          tabSlugs: const [
            'overview',
            'enabled_modules',
            'integrations',
            'security_settings',
            'referral_program',
            'danger_zone',
          ],
          shellBuilder: (initialTab) =>
              AccountManagementShell(initialTab: initialTab),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<Services>.value(value: services),
        ChangeNotifierProvider(create: (_) => SettingsLevelController()),
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

void main() {
  testWidgets('hosted renders the Referral Program tab', (tester) async {
    await _pump(tester, isHosted: true);

    expect(find.widgetWithText(TabBar, 'Referral Program'), findsOneWidget);
    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs, hasLength(7));
  });

  testWidgets('self-hosted renders six tabs, none of them Referral Program', (
    tester,
  ) async {
    await _pump(tester, isHosted: false);

    expect(find.text('Referral Program'), findsNothing);
    expect(tester.widget<TabBar>(find.byType(TabBar)).tabs, hasLength(6));
    // The surrounding tabs are untouched.
    for (final label in ['Plan', 'Overview', 'Danger Zone']) {
      expect(find.widgetWithText(TabBar, label), findsOneWidget);
    }
  });

  testWidgets('self-hosted deep link to the hidden tab rewrites to the base '
      'path', (tester) async {
    final router = await _pump(
      tester,
      isHosted: false,
      initialLocation: '/settings/account_management/referral_program',
    );

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/settings/account_management',
    );
    expect(find.text('Referral Program'), findsNothing);
  });

  testWidgets('hosted deep link to the referral tab is left alone', (
    tester,
  ) async {
    final router = await _pump(
      tester,
      isHosted: true,
      initialLocation: '/settings/account_management/referral_program',
    );

    expect(
      router.routerDelegate.currentConfiguration.uri.path,
      '/settings/account_management/referral_program',
    );
  });
}
