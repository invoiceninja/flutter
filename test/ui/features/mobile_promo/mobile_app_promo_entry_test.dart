// The mobile-app promo's sidebar card and its automatic opener
// (docs/mobile-app-promo.md). Both read only `auth` and, for the host, the
// unsaved-changes guard — so they take a light fake rather than the shell
// fixture, whose live Drift watch streams never settle.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/mobile_app_promo_controller.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/ui/core/dialogs/automatic_dialogs.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/features/mobile_promo/mobile_app_promo_host.dart';
import 'package:admin/ui/features/settings/widgets/mobile_app_section.dart';
import 'package:admin/ui/features/shell/widgets/mobile_app_promo_footer.dart';
import 'package:admin/ui/features/shell/widgets/plan_expired_footer.dart';

import '../../../_localization_helper.dart';

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
  _FakeServices(AuthSession? session)
    : auth = _FakeAuth(ValueNotifier(session));
  @override
  final AuthRepository auth;
  @override
  final UnsavedChangesGuard unsavedChangesGuard = UnsavedChangesGuard();
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthSession _session({
  bool isHosted = true,
  String baseUrl = 'https://invoicing.co',
  String planExpires = '',
}) => AuthSession(
  baseUrl: baseUrl,
  isHosted: isHosted,
  accountId: 'acct',
  companies: [
    AuthCompany(
      id: 'co',
      name: 'Co',
      displayName: 'Co',
      permissions: '',
      isAdmin: true,
      isOwner: true,
      enabledModules: 0x7fffffff,
    ),
  ],
  currentCompanyId: 'co',
  userEmail: 'me@example.com',
  planExpires: planExpires,
);

const _entry = 'Get the mobile app';

void main() {
  // `flutter test` runs as Android, where the promo has nothing to offer.
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);
  tearDown(AutomaticDialogs.resetForTest);

  Future<MobileAppPromoController> pump(
    WidgetTester tester,
    Widget child, {
    AuthSession? session,
    bool provideController = true,
    bool promote = true,
    MobileAppPromoState state = const MobileAppPromoState(),
  }) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final prefs = DevicePrefsStore(null);
    await prefs.write(DevicePrefKeys.mobileAppPromo, state.encode());
    final controller = MobileAppPromoController(prefs: prefs, promote: promote);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Provider<Services>.value(
          value: _FakeServices(session ?? _session()),
          child: provideController
              ? ChangeNotifierProvider.value(value: controller, child: child)
              : child,
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  group('MobileAppPromoFooter', () {
    Widget footer({bool compact = false, bool affordable = true}) => Scaffold(
      body: SizedBox(
        width: 232,
        child: Column(
          children: [
            MobileAppPromoFooter(
              compact: compact,
              affordable: affordable,
              touch: true,
            ),
          ],
        ),
      ),
    );

    testWidgets('shown, at a full touch target, and opens the promo', (
      tester,
    ) async {
      await pump(tester, footer());
      expect(find.text(_entry), findsOneWidget);
      expect(
        tester.getSize(find.byType(InkWell)).height,
        greaterThanOrEqualTo(InSizes.touchTarget),
      );

      await tester.tap(find.text(_entry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Invoice Ninja on your phone'), findsOneWidget);
      expect(
        find.text('Close'),
        findsOneWidget,
        reason: 'a manual open never offers to snooze',
      );
    }, variant: windows);

    testWidgets('yields to the collapsed rail and a short viewport', (
      tester,
    ) async {
      await pump(tester, footer(compact: true));
      expect(find.text(_entry), findsNothing);
      await pump(tester, footer(affordable: false));
      expect(find.text(_entry), findsNothing);
    }, variant: windows);

    testWidgets('yields to the white-label offer — one card at a time', (
      tester,
    ) async {
      await pump(
        tester,
        footer(),
        session: _session(isHosted: false, baseUrl: 'https://in.example.com'),
      );
      expect(find.text(_entry), findsNothing);
    }, variant: windows);

    testWidgets('yields to an expired plan too', (tester) async {
      final expired = _session(planExpires: '2020-01-31');
      expect(PlanExpiredFooter.shows(expired), isTrue, reason: 'precondition');
      await pump(tester, footer(), session: expired);
      expect(find.text(_entry), findsNothing);
    }, variant: windows);

    testWidgets('absent in a build that does not promote the app — every '
        'harness, so the web smoke test keeps its nav rows', (tester) async {
      await pump(tester, footer(), promote: false);
      expect(find.text(_entry), findsNothing);
    }, variant: windows);

    testWidgets('gone once the user said no, or took the app', (tester) async {
      final c = await pump(tester, footer());
      await c.finish();
      await tester.pump();
      expect(find.text(_entry), findsNothing);

      final d = await pump(tester, footer());
      await d.markEngaged();
      await tester.pump();
      expect(find.text(_entry), findsNothing);
    }, variant: windows);

    testWidgets('absent without a controller — every other harness', (
      tester,
    ) async {
      await pump(tester, footer(), provideController: false);
      expect(find.text(_entry), findsNothing);
    }, variant: windows);

    testWidgets('absent on the phone apps', (tester) async {
      await pump(tester, footer());
      expect(find.text(_entry), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });

  group('MobileAppPromoHost', () {
    const due = MobileAppPromoState(daysSeen: 3, lastDay: '2000-01-01');
    Widget host() => const MobileAppPromoHost(
      child: Scaffold(body: Center(child: TextField())),
    );

    testWidgets('opens on its own once due, and a close snoozes it', (
      tester,
    ) async {
      final c = await pump(tester, host(), state: due);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Invoice Ninja on your phone'), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Invoice Ninja on your phone'), findsOneWidget);
      expect(c.shownThisLaunch, isTrue);

      await tester.tap(find.text('Remind me later'));
      await tester.pumpAndSettle();
      expect(c.state.closes, 1);
      expect(c.isDue(DateTime.now()), isFalse);
    }, variant: windows);

    testWidgets('never opens unless the app asked for it', (tester) async {
      await pump(tester, host(), promote: false, state: due);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Invoice Ninja on your phone'), findsNothing);
    }, variant: windows);

    testWidgets('waits while a form has unsaved changes', (tester) async {
      await pump(tester, host(), state: due);
      final services = tester
          .element(find.byType(MobileAppPromoHost))
          .read<Services>();
      var dirty = true;
      final unregister = services.unsavedChangesGuard.register(
        isDirty: () => dirty,
        source: ValueNotifier(0),
      );
      addTearDown(unregister);
      await tester.pump(const Duration(seconds: 20));
      expect(find.text('Invoice Ninja on your phone'), findsNothing);

      dirty = false;
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Invoice Ninja on your phone'), findsOneWidget);
    }, variant: windows);

    testWidgets('a launch that already showed an automatic dialog is left '
        'alone', (tester) async {
      AutomaticDialogs.noteShown();
      await pump(tester, host(), state: due);
      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Invoice Ninja on your phone'), findsNothing);
    }, variant: windows);

    testWidgets(
      'waits while the user is typing, then gives up for the launch',
      (tester) async {
        final c = await pump(tester, host(), state: due);
        await tester.showKeyboard(find.byType(TextField));
        await tester.pump(const Duration(seconds: 30));
        expect(find.text('Invoice Ninja on your phone'), findsNothing);

        // Typing ends after the 60-second window: nothing this launch.
        await tester.pump(const Duration(seconds: 31));
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(seconds: 10));
        expect(find.text('Invoice Ninja on your phone'), findsNothing);
        expect(c.state.closes, 0, reason: 'never shown, so never snoozed');
      },
      variant: windows,
    );
  });

  group('MobileAppSection (Device Settings)', () {
    Widget section() =>
        const Scaffold(body: SingleChildScrollView(child: MobileAppSection()));

    testWidgets('offers the promo on a desktop, opened as a request', (
      tester,
    ) async {
      await pump(tester, section(), promote: false);
      expect(find.text('Mobile app'), findsOneWidget);
      await tester.tap(find.text(_entry));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Invoice Ninja on your phone'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('absent for the demo and for a server only this machine '
        'reaches', (tester) async {
      for (final url in [kDemoBaseUrl, 'http://localhost:8000']) {
        await pump(
          tester,
          section(),
          session: _session(isHosted: false, baseUrl: url),
        );
        expect(find.text('Mobile app'), findsNothing, reason: url);
      }
    }, variant: windows);

    testWidgets('absent on the phone apps', (tester) async {
      await pump(tester, section());
      expect(find.text('Mobile app'), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
