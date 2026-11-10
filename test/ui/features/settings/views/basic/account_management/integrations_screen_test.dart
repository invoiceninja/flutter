import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/models/domain/enabled_modules.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/features/settings/views/basic/account_management/integrations_screen.dart';

import '../../../../../../_localization_helper.dart';

class _FakeAuth implements AuthRepository {
  _FakeAuth(AuthSession session) : _session = ValueNotifier(session);
  final ValueNotifier<AuthSession?> _session;
  @override
  ValueListenable<AuthSession?> get session => _session;
  @override
  Object? noSuchMethod(Invocation invocation) =>
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

final int _allModules = kEnabledModulesOrder.fold<int>(
  0,
  (mask, m) => mask | m.bitmask,
);

AuthSession _session({bool admin = true, bool pro = true, bool tasks = true}) =>
    AuthSession(
      baseUrl: 'https://invoicing.co',
      isHosted: true,
      accountId: 'acct',
      plan: pro ? 'pro' : '',
      companies: [
        AuthCompany(
          id: 'co',
          name: 'Co',
          displayName: 'Co',
          permissions: '',
          isAdmin: admin,
          isOwner: false,
          enabledModules: tasks
              ? _allModules
              : _allModules & ~EnabledModule.tasks.bitmask,
        ),
      ],
      currentCompanyId: 'co',
    );

/// Settings → Account Management → Integrations: the "More from Invoice
/// Ninja" card shows each companion app only where it is offered
/// (docs/companion-apps.md), and is left out when none is.
void main() {
  Future<void> pump(WidgetTester tester, AuthSession session) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(_FakeAuth(session)),
        child: MaterialApp(
          theme: buildInTheme(InTheme.light),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          home: const Scaffold(body: AccountManagementIntegrationsScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  final l10n = bundledLocalization();
  String t(String key) => l10n.lookup(key);

  Finder row(String titleKey) => find.widgetWithText(ListTile, t(titleKey));

  Future<void> on(
    WidgetTester tester,
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('Windows, a Pro admin: all three, the store links marked as '
      'leaving the app', (tester) async {
    await on(tester, TargetPlatform.windows, () async {
      await pump(tester, _session());
      expect(find.text(t('companion_apps_section')), findsOneWidget);
      expect(row('wordpress_plugin'), findsOneWidget);
      expect(row('chrome_extension'), findsOneWidget);
      expect(row('mobile_app_promo_section'), findsOneWidget);
      expect(
        find.descendant(
          of: row('wordpress_plugin'),
          matching: find.byIcon(Icons.open_in_new),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row('chrome_extension'),
          matching: find.byIcon(Icons.open_in_new),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row('mobile_app_promo_section'),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
      );
    });
  });

  testWidgets('native macOS never names Chrome', (tester) async {
    await on(tester, TargetPlatform.macOS, () async {
      await pump(tester, _session());
      expect(row('wordpress_plugin'), findsOneWidget);
      expect(row('chrome_extension'), findsNothing);
      expect(find.textContaining('Chrome'), findsNothing);
      expect(row('mobile_app_promo_section'), findsOneWidget);
    });
  });

  testWidgets('a member on a free plan sees no WordPress row', (tester) async {
    await on(tester, TargetPlatform.windows, () async {
      await pump(tester, _session(admin: false, pro: false));
      expect(row('wordpress_plugin'), findsNothing);
      expect(row('chrome_extension'), findsOneWidget);
    });
  });

  testWidgets('no Chrome row with the Tasks module off', (tester) async {
    await on(tester, TargetPlatform.linux, () async {
      await pump(tester, _session(tasks: false));
      expect(row('wordpress_plugin'), findsOneWidget);
      expect(row('chrome_extension'), findsNothing);
    });
  });

  testWidgets('the phone app: WordPress only, for a Pro admin', (tester) async {
    await on(tester, TargetPlatform.iOS, () async {
      await pump(tester, _session());
      expect(row('wordpress_plugin'), findsOneWidget);
      expect(row('chrome_extension'), findsNothing);
      expect(row('mobile_app_promo_section'), findsNothing);
    });
  });

  testWidgets('nothing offered: no card at all, API Docs still there', (
    tester,
  ) async {
    await on(tester, TargetPlatform.android, () async {
      await pump(tester, _session(admin: false, pro: false));
      expect(find.text(t('companion_apps_section')), findsNothing);
      expect(row('wordpress_plugin'), findsNothing);
      expect(row('mobile_app_promo_section'), findsNothing);
      expect(find.text(t('api_docs')), findsOneWidget);
    });
  });
}
