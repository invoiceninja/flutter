import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:super_editor/super_editor.dart';

import 'package:admin/app/design_tokens.dart';
import 'package:admin/app/idle_timeout_controller.dart';
import 'package:admin/app/sign_out_notice.dart';
import 'package:admin/app/theme.dart';
import 'package:admin/app/user_activity_notification.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/company_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/ui/core/widgets/markdown_text_field.dart';
import 'package:admin/ui/core/widgets/session_expiry_banner.dart';

import '../_localization_helper.dart';

/// Unit tests for the idle-timeout preserve-vs-wipe DECISION
/// ([IdleTimeoutController.shouldPreserveOnTimeout]). This is the load-bearing
/// branch that decides whether an idle timeout keeps the user's unsynced offline
/// edits (re-lock) or does a destructive full logout. A regression here would
/// silently destroy offline work, so it is pinned directly.
///
/// The controller takes concrete repos; a `null` session keeps construction
/// inert (no company watch) so the decision method — which only reads `sync` —
/// can be exercised with a single fake.
void main() {
  // The controller subscribes to `HardwareKeyboard` and `FocusManager`, which
  // hang off the bindings.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuth auth;
  late _FakeCompany company;
  late _FakeSync sync;
  late IdleTimeoutController controller;

  setUp(() {
    auth = _FakeAuth();
    company = _FakeCompany();
    sync = _FakeSync();
    controller = IdleTimeoutController(
      auth: auth,
      company: company,
      sync: sync,
      now: () => DateTime.utc(2026),
    );
  });

  tearDown(() => controller.dispose());

  group('shouldPreserveOnTimeout', () {
    test('preserves when any company has active outbox rows — the set comes '
        'from the OUTBOX, so even a company missing from the session '
        'envelope protects its rows', () async {
      sync.activeCompanies = ['co2'];
      expect(await controller.shouldPreserveOnTimeout(), isTrue);
    });

    test(
      'does NOT preserve (clean full logout) when nothing is pending',
      () async {
        sync.activeCompanies = const [];
        expect(await controller.shouldPreserveOnTimeout(), isFalse);
      },
    );

    test('errs toward preserving when the outbox read throws', () async {
      sync.throwOnCount = true;
      expect(await controller.shouldPreserveOnTimeout(), isTrue);
    });
  });

  // Activity used to be pointer events only (the root `Listener` in
  // `main.dart`), so typing — a long note on a hardware keyboard, anything at
  // all on a soft keyboard — counted as idle, and the session ended under the
  // user's hands. A 60 s timeout, checked every 30 s.
  group('what counts as activity', () {
    late _TimedHarness h;

    setUp(() {
      h = _TimedHarness();
    });

    testWidgets('with no activity the session expires on time', (tester) async {
      await h.start(tester);
      await h.advance(tester, const Duration(seconds: 30));
      expect(h.auth.logouts, isEmpty);
      await h.advance(tester, const Duration(seconds: 30));
      expect(h.auth.logouts, hasLength(1));
      h.dispose();
    });

    testWidgets('a hardware key press delays expiry', (tester) async {
      await h.start(tester);
      await h.advance(tester, const Duration(seconds: 30));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await h.advance(tester, const Duration(seconds: 30));
      expect(h.auth.logouts, isEmpty, reason: 'idle for 30 s, not 60');
      await h.advance(tester, const Duration(seconds: 30));
      expect(h.auth.logouts, hasLength(1), reason: 'still enforced');
      h.dispose();
    });

    testWidgets('typing into a text field delays expiry, with no key events', (
      tester,
    ) async {
      await h.start(tester, child: const Material(child: TextField()));
      await tester.showKeyboard(find.byType(TextField));
      await h.advance(tester, const Duration(seconds: 30));
      // What a soft keyboard does: an editing-value update, no `KeyEvent`.
      tester.testTextInput.enterText('a long note');
      await tester.pump();
      await h.advance(tester, const Duration(seconds: 30));
      expect(h.auth.logouts, isEmpty);
      await h.advance(tester, const Duration(seconds: 30));
      expect(h.auth.logouts, hasLength(1));
      h.dispose();
    });

    testWidgets('an edit in a markdown field delays expiry', (tester) async {
      await h.start(
        tester,
        child: Scaffold(
          body: Center(
            child: SizedBox(
              width: 480,
              child: MarkdownTextField(
                label: 'Notes',
                initialValue: 'Hello',
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      final host = tester.getRect(
        find.descendant(
          of: find.byType(MarkdownTextField),
          matching: find.byType(CustomScrollView),
        ),
      );
      await tester.tapAt(host.bottomLeft + const Offset(24, -12));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(h.notifications, 0, reason: 'promoting to the editor is no edit');

      await h.advance(tester, const Duration(seconds: 30));
      tester.widget<SuperEditor>(find.byType(SuperEditor)).editor.execute([
        InsertCharacterAtCaretRequest(character: 'X'),
      ]);
      expect(h.notifications, 1);
      await h.advance(tester, const Duration(seconds: 30));
      expect(h.auth.logouts, isEmpty);
      await h.advance(tester, const Duration(seconds: 30));
      expect(h.auth.logouts, hasLength(1));
      h.dispose();
    });

    testWidgets('a background change does not keep the session alive', (
      tester,
    ) async {
      // The rejected design was the unsaved-changes guard, which background
      // Drift re-emits flip too. None of these is the user: the company row
      // re-emitting (every /refresh bumps `last_sync_at`), a programmatic
      // write to an UNFOCUSED text field, a markdown field reseeded from
      // outside.
      final unfocused = TextEditingController();
      addTearDown(unfocused.dispose);
      var externalKey = 0;
      late StateSetter reseed;
      await h.start(
        tester,
        child: Scaffold(
          body: Column(
            children: [
              TextField(controller: unfocused),
              StatefulBuilder(
                builder: (context, setState) {
                  reseed = setState;
                  return SizedBox(
                    width: 480,
                    child: MarkdownTextField(
                      label: 'Notes',
                      initialValue: 'v$externalKey',
                      externalValueKey: externalKey,
                      onChanged: (_) {},
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
      await h.advance(tester, const Duration(seconds: 30));
      h.companyRows.add(const Company(id: 'co1', sessionTimeout: 60000));
      unfocused.text = 'synced from the server';
      reseed(() => externalKey++);
      await tester.pump();
      expect(h.notifications, 0);

      await h.advance(tester, const Duration(seconds: 30));
      expect(h.auth.logouts, hasLength(1));
      h.dispose();
    });
  });

  // The setting is the *Web* Session Timeout. Enforced in the native apps, it
  // signed people out while a task timer ran: nobody touches the app then, and
  // time in the background counted as idle, so coming back to stop the timer
  // was itself the sign-out.
  group('web only', () {
    late _TimedHarness h;

    setUp(() {
      h = _TimedHarness();
    });

    testWidgets('off the web the timeout never ends a session', (tester) async {
      await h.start(tester, enforced: false);
      await h.advance(tester, const Duration(minutes: 3));
      h.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(h.auth.logouts, isEmpty);
      expect(h.controller.expiringSoon.value, isFalse);
      h.dispose();
    });
  });

  group('the expiry warning', () {
    const timeout = Duration(minutes: 30);
    late _TimedHarness h;

    setUp(() {
      h = _TimedHarness();
    });

    testWidgets('warns two minutes before expiry, then expires on time', (
      tester,
    ) async {
      await h.start(tester, timeout: timeout);
      await h.advance(tester, const Duration(minutes: 27, seconds: 30));
      expect(h.controller.expiringSoon.value, isFalse);
      await h.advance(tester, const Duration(seconds: 30));
      expect(h.controller.expiringSoon.value, isTrue);
      expect(h.auth.logouts, isEmpty);
      await h.advance(tester, const Duration(minutes: 2));
      expect(h.auth.logouts, hasLength(1));
      expect(h.controller.expiringSoon.value, isFalse);
      h.dispose();
    });

    testWidgets('activity clears the warning and restarts the clock', (
      tester,
    ) async {
      await h.start(tester, timeout: timeout);
      await h.advance(tester, const Duration(minutes: 28));
      expect(h.controller.expiringSoon.value, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      expect(h.controller.expiringSoon.value, isFalse);
      await h.advance(tester, const Duration(minutes: 29));
      expect(h.auth.logouts, isEmpty, reason: 'idle for 29 min, not 30');
      expect(
        h.controller.expiringSoon.value,
        isTrue,
        reason: 'counted from the key press',
      );
      h.dispose();
    });

    testWidgets('the banner shows the warning, and Stay Logged In keeps the '
        'session', (tester) async {
      await h.start(
        tester,
        timeout: timeout,
        child: const Scaffold(body: Column(children: [SessionExpiryBanner()])),
      );
      final banner = find.byKey(const ValueKey('session_expiry_banner'));
      await h.advance(tester, const Duration(minutes: 27, seconds: 30));
      expect(banner, findsNothing);
      await h.advance(tester, const Duration(seconds: 30));
      expect(banner, findsOneWidget);
      expect(find.text('Warning: Your session is about to expire'), findsOne);

      await tester.tap(find.byKey(const ValueKey('session_expiry_stay')));
      await tester.pump();
      expect(banner, findsNothing);
      await h.advance(tester, const Duration(minutes: 2));
      expect(h.auth.logouts, isEmpty);
      h.dispose();
    });

    testWidgets('the sign-in screen is told why', (tester) async {
      final notice = SignOutNotice(
        prefs: DevicePrefsStore(null),
        credentials: ValueNotifier<ApiCredentials?>(null),
      );
      addTearDown(notice.dispose);
      await h.start(tester, notice: notice);
      await h.advance(tester, const Duration(seconds: 60));
      expect(h.auth.logouts, hasLength(1));
      expect(notice.pending?.reason, SignOutReason.inactivity);
      h.dispose();
    });

    testWidgets('without the provider the banner renders nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SessionExpiryBanner())),
      );
      expect(find.byKey(const ValueKey('session_expiry_banner')), findsNothing);
    });
  });
}

/// A controller armed with a 60 s timeout for company `co1`, a hand-driven
/// clock, and a tree that routes [UserActivityNotification] to [poke] the way
/// `main.dart` does. Timers are the test binding's fake ones, so [advance]
/// moves both clocks together.
class _TimedHarness {
  final auth = _FakeAuth();
  final company = _FakeCompany();
  final sync = _FakeSync();
  final companyRows = StreamController<Company?>.broadcast();
  var clock = DateTime.utc(2026, 3, 1, 12);
  var notifications = 0;
  late IdleTimeoutController controller;

  /// [enforced] is the web gate — tests run with `kIsWeb == false`, so every
  /// test of the timeout itself opts in.
  Future<void> start(
    WidgetTester tester, {
    Widget? child,
    Duration timeout = const Duration(seconds: 60),
    bool enforced = true,
    SignOutNotice? notice,
  }) async {
    company.rows = companyRows.stream;
    auth.session.value = const AuthSession(
      baseUrl: 'https://example.com',
      isHosted: true,
      accountId: 'acct1',
      companies: [],
      currentCompanyId: 'co1',
    );
    controller = enforced
        ? IdleTimeoutController(
            auth: auth,
            company: company,
            sync: sync,
            enforced: true,
            notice: notice,
            now: () => clock,
          )
        // The production default, which is what a native build gets.
        : IdleTimeoutController(
            auth: auth,
            company: company,
            sync: sync,
            now: () => clock,
          );
    companyRows.add(Company(id: 'co1', sessionTimeout: timeout.inMilliseconds));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildInTheme(InTheme.light),
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        // Provided the way `main.dart` provides it, for `SessionExpiryBanner`.
        builder: (context, routed) => Provider<IdleTimeoutController>.value(
          value: controller,
          child: NotificationListener<UserActivityNotification>(
            onNotification: (_) {
              notifications++;
              controller.poke();
              return true;
            },
            child: routed!,
          ),
        ),
        home: child ?? const SizedBox.shrink(),
      ),
    );
    await tester.pump();
  }

  Future<void> advance(WidgetTester tester, Duration d) async {
    clock = clock.add(d);
    await tester.pump(d);
  }

  /// In the test body, not a tear-down: the binding checks for pending
  /// timers before tear-downs run, and the ticker is periodic.
  void dispose() {
    controller.dispose();
    unawaited(companyRows.close());
  }
}

class _FakeAuth implements AuthRepository {
  // A null session makes the controller's constructor inert (it disables itself
  // without touching `company`), so the decision method can be tested alone.
  @override
  final ValueNotifier<AuthSession?> session = ValueNotifier<AuthSession?>(null);

  final logouts = <LocalDataPolicy>[];

  @override
  Future<void> logout({required LocalDataPolicy data}) async {
    logouts.add(data);
    session.value = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCompany implements CompanyRepository {
  Stream<Company?> rows = const Stream<Company?>.empty();

  @override
  Stream<Company?> watchCompany(String companyId) => rows;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSync implements SyncRepository {
  int pending = 0;
  List<String> activeCompanies = const [];
  bool throwOnCount = false;

  @override
  Future<int> pendingCountFor(String companyId) async {
    if (throwOnCount) throw StateError('pending count unavailable');
    return pending;
  }

  @override
  Future<List<String>> companiesWithActiveRows() async {
    if (throwOnCount) throw StateError('outbox unavailable');
    return activeCompanies;
  }

  // Mirrors the real `SyncRepository.hasUnsyncedWork` (errs toward preserving)
  // so the controller's delegation is exercised end-to-end.
  @override
  Future<bool> hasUnsyncedWork() async {
    try {
      return (await companiesWithActiveRows()).isNotEmpty;
    } catch (_) {
      return true;
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
