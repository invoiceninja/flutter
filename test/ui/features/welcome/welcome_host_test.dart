// The first-run Welcome (docs/first-run-welcome.md): when it opens on its
// own, what each kind of user sees, and how a close is remembered. Like the
// What's New host test it takes a light Services fake rather than the shell
// fixture, whose live Drift watch streams never settle.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/services.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/app/welcome_controller.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth/auth_session.dart'
    show kDemoBaseUrl;
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/domain/release_notes.dart';
import 'package:admin/domain/welcome.dart';
import 'package:admin/domain/welcome_content.dart';
import 'package:admin/ui/core/dialogs/automatic_dialogs.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/features/welcome/welcome_dialog.dart';
import 'package:admin/ui/features/welcome/welcome_host.dart';

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

const _userKey = 'https://invoicing.co#u1';

AuthSession _session({bool demo = false, bool admin = true}) => AuthSession(
  baseUrl: demo ? kDemoBaseUrl : 'https://invoicing.co',
  isHosted: true,
  accountId: 'acct',
  userId: 'u1',
  userFirstName: 'Ada',
  companies: [
    AuthCompany(
      id: 'co',
      name: 'Co',
      displayName: 'Co',
      permissions: '',
      isAdmin: admin,
      isOwner: admin,
      enabledModules: 0x7fffffff,
    ),
  ],
  currentCompanyId: 'co',
  userEmail: 'ada@example.com',
);

const _title = 'Welcome to the new Invoice Ninja, Ada';

void main() {
  tearDown(AutomaticDialogs.resetForTest);

  Future<WelcomeController> pump(
    WidgetTester tester, {
    SignInFacts? signIn,
    Size size = const Size(1280, 900),
    AuthSession? session,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = WelcomeController(
      prefs: DevicePrefsStore(null),
      currentUserKey: () => _userKey,
      isDemoBuild: false,
      demoMode: false,
    );
    addTearDown(controller.dispose);
    if (signIn != null) controller.noteSignIn(signIn);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Provider<Services>.value(
          value: _FakeServices(session ?? _session()),
          child: ChangeNotifierProvider<WelcomeController?>.value(
            value: controller,
            child: const WelcomeHost(child: Scaffold(body: SizedBox())),
          ),
        ),
      ),
    );
    await tester.pump();
    return controller;
  }

  /// Past the arrival beat, the entrance and the half-second arm delay.
  Future<void> arrive(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));
  }

  const existing = SignInFacts(userKey: _userKey, isSignup: false);
  const fromOldApp = SignInFacts(
    userKey: _userKey,
    isSignup: false,
    companyUserSettings: [
      {'dashboard_fields_per_row_mobile': 2},
    ],
  );

  testWidgets('greets an existing account on arrival, on Get started', (
    tester,
  ) async {
    final c = await pump(tester, signIn: existing);
    await arrive(tester);
    expect(find.text(_title), findsOneWidget);
    expect(find.text('Find anything fast'), findsOneWidget);
    expect(find.text('All your data is already here'), findsNothing);
    expect(c.shownThisLaunch, isTrue);
    expect(AutomaticDialogs.shownThisLaunch, isTrue);

    await tester.tap(find.byKey(const ValueKey('welcome_lets_go')));
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(c.autoOpens, isFalse, reason: 'closing it is reading it');
  });

  testWidgets('a previous-app user lands on What\'s changed, and can switch', (
    tester,
  ) async {
    await pump(tester, signIn: fromOldApp);
    await arrive(tester);
    expect(find.text('All your data is already here'), findsOneWidget);
    expect(find.text('Reports, rebuilt'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome_switch_list')));
    await tester.pumpAndSettle();
    expect(find.text('Find anything fast'), findsOneWidget);
    expect(find.text('All your data is already here'), findsNothing);
  });

  testWidgets('"Can\'t find something?" folds out where things went', (
    tester,
  ) async {
    await pump(tester, signIn: fromOldApp);
    await arrive(tester);
    expect(
      find.text('Dashboard settings are now above the figures.'),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('welcome_cant_find')));
    await tester.pumpAndSettle();
    expect(
      find.text('Dashboard settings are now above the figures.'),
      findsOneWidget,
    );
  });

  testWidgets('a sign-up is never greeted — the wizard was its welcome', (
    tester,
  ) async {
    await pump(
      tester,
      signIn: const SignInFacts(userKey: _userKey, isSignup: true),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(find.text(_title), findsNothing);
  });

  testWidgets('nothing decided, nothing shown', (tester) async {
    await pump(tester);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text(_title), findsNothing);
  });

  testWidgets('the demo account is not greeted', (tester) async {
    await pump(tester, signIn: existing, session: _session(demo: true));
    await tester.pump(const Duration(seconds: 6));
    expect(find.text(_title), findsNothing);
  });

  testWidgets('arrives even when the decision lands after the shell', (
    tester,
  ) async {
    final c = await pump(tester);
    c.noteSignIn(existing);
    await arrive(tester);
    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('a phone gets a bottom sheet, and a swipe down is a close', (
    tester,
  ) async {
    final c = await pump(tester, signIn: existing, size: const Size(390, 844));
    await arrive(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.fling(find.text(_title), const Offset(0, 900), 2000);
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(c.autoOpens, isFalse);
  });

  testWidgets('the first half-second ignores a click already in flight', (
    tester,
  ) async {
    await pump(tester, signIn: existing);
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('welcome_lets_go')));
    await tester.pump();
    expect(find.text(_title), findsOneWidget);
  });

  testWidgets('a launch the user was busy in stays quiet, even after the '
      'shell is rebuilt', (tester) async {
    final c = await pump(tester, signIn: existing);
    // Busy: a tap within the arrival beat, and again on every retry.
    for (var i = 0; i < 12; i++) {
      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text(_title), findsNothing);
    expect(c.stoodDownThisLaunch, isTrue);
    expect(c.state.users[_userKey]?.attempts, 1);
    // The shell — and a new host in it — comes back after an unlock.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Provider<Services>.value(
          value: _FakeServices(_session()),
          child: ChangeNotifierProvider<WelcomeController?>.value(
            value: c,
            child: const WelcomeHost(child: Scaffold(body: SizedBox())),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 6));
    expect(find.text(_title), findsNothing);
    expect(c.state.users[_userKey]?.attempts, 1, reason: 'no second attempt');
  });

  testWidgets('a teardown under the Welcome leaves it unread', (tester) async {
    // go_router replacing the shell page (a 401, the idle lock) completes
    // the Welcome's route without popping it — no swipe-close is counted.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = WelcomeController(
      prefs: DevicePrefsStore(null),
      currentUserKey: () => _userKey,
      isDemoBuild: false,
      demoMode: false,
    )..noteSignIn(existing);
    addTearDown(c.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const WelcomeHost(child: Scaffold(body: SizedBox())),
        ),
        GoRoute(path: '/login', builder: (_, _) => const Scaffold()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      Provider<Services>.value(
        value: _FakeServices(_session()),
        child: ChangeNotifierProvider<WelcomeController?>.value(
          value: c,
          child: MaterialApp.router(
            theme: buildInTheme(InTheme.light),
            localizationsDelegates: kTestLocalizationsDelegates,
            supportedLocales: kTestSupportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await arrive(tester);
    expect(find.text(_title), findsOneWidget);
    router.go('/login');
    await tester.pumpAndSettle();
    expect(find.text(_title), findsNothing);
    expect(c.currentPending, isTrue);
  });

  testWidgets('a landscape phone gets the sheet, not a cramped dialog', (
    tester,
  ) async {
    await pump(tester, signIn: existing, size: const Size(852, 393));
    await arrive(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('"Can\'t find something?" scrolls itself into view', (
    tester,
  ) async {
    await pump(tester, signIn: fromOldApp, size: const Size(393, 852));
    await arrive(tester);
    // As a user would: it may sit behind the footer until scrolled to.
    await tester.ensureVisible(find.byKey(const ValueKey('welcome_cant_find')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const ValueKey('welcome_cant_find')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final position = tester
        .widget<SingleChildScrollView>(
          find.descendant(
            of: find.byType(WelcomeCard),
            matching: find.byType(SingleChildScrollView),
          ),
        )
        .controller!
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    expect(position.pixels, position.maxScrollExtent);
  });

  group('the card', () {
    Future<void> pumpCard(
      WidgetTester tester, {
      required WelcomeList list,
      bool Function(WelcomeAction)? reachable,
      Size size = const Size(800, 900),
      double textScale = 1,
      TextDirection direction = TextDirection.ltr,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildInTheme(InTheme.dark),
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Directionality(textDirection: direction, child: child!),
          ),
          home: Provider<Services>.value(
            value: _FakeServices(_session()),
            child: Scaffold(
              body: WelcomeCard(
                initialList: list,
                session: _session(),
                surfaces: const {ReleaseNoteSurface.nativePhone},
                reachable: reachable ?? (_) => true,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('shows at most three rows', (tester) async {
      await pumpCard(tester, list: WelcomeList.whatsChanged);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('welcome_item_'),
        ),
        findsNWidgets(3),
      );
    });

    testWidgets('leaves out a row this user cannot reach', (tester) async {
      await pumpCard(
        tester,
        list: WelcomeList.whatsChanged,
        reachable: (a) => a is! WelcomeRoute || !a.adminOnly,
      );
      expect(find.text('Drag-and-drop invoice designer'), findsNothing);
      expect(find.text('Tasks your way'), findsOneWidget);
    });

    for (final (name, size, scale, dir) in [
      (
        'a small phone at 2x text',
        const Size(360, 720),
        2.0,
        TextDirection.ltr,
      ),
      ('a landscape phone', const Size(740, 360), 1.4, TextDirection.ltr),
      ('right-to-left', const Size(800, 900), 1.0, TextDirection.rtl),
    ]) {
      testWidgets('lays out on $name', (tester) async {
        await pumpCard(
          tester,
          list: WelcomeList.whatsChanged,
          size: size,
          textScale: scale,
          direction: dir,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
