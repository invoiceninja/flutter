import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:admin/app/deep_link_router.dart';
import 'package:admin/app/entity_modules.dart' show DisabledEntityDispatcher;
import 'package:admin/app/services.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/repositories/sync_repository.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
import 'package:admin/ui/core/unsaved_changes/unsaved_changes_guard.dart';
import 'package:admin/ui/core/widgets/toast_controller.dart';

import '../_localization_helper.dart';

/// Arrival choreography for an incoming deep link.
///
/// The failures guarded here are all invisible ones: a link handled twice
/// (Android hands the launch link over on two channels), a link acted on
/// before the user has signed in or passed the biometric lock, and a link
/// dropped because it landed before the first frame.

EntityHandlers _handler(EntityType type, String wire, String routePath) =>
    EntityHandlers(
      type: type,
      wireName: wire,
      apiPath: '/api/v1/$wire',
      routePath: routePath,
      icon: Icons.circle,
      dispatcher: DisabledEntityDispatcher(type),
      detailBuilder: (_, _) => const SizedBox.shrink(),
    );

EntityRegistry _registry() => EntityRegistry({
  EntityType.client: _handler(EntityType.client, 'client', '/clients'),
  EntityType.invoice: _handler(EntityType.invoice, 'invoice', '/invoices'),
});

const _co1 = AuthCompany(
  id: 'co1',
  name: 'One',
  displayName: 'One',
  permissions: '',
  isAdmin: true,
  isOwner: true,
);

const _co2 = AuthCompany(
  id: 'co2',
  name: 'Two',
  displayName: 'Two',
  permissions: '',
  isAdmin: true,
  isOwner: true,
);

AuthSession _session({
  String currentCompanyId = 'co1',
  List<AuthCompany> companies = const [_co1],
}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acc-1',
  companies: companies,
  currentCompanyId: currentCompanyId,
);

/// The slices of `Services` a company switch reads: the unsaved-changes guard,
/// the outbox count, and the switch itself.
class _SwitchingAuth implements AuthRepository {
  _SwitchingAuth(this.session);

  @override
  final ValueListenable<AuthSession?> session;

  final switchedTo = <String>[];

  @override
  Future<SwitchCompanyResult> switchCompany(String companyId) async {
    switchedTo.add(companyId);
    return SwitchCompanyResult.ok;
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NothingPendingSync implements SyncRepository {
  @override
  Future<int> pendingCountFor(String companyId) async => 0;

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _SwitchServices implements Services {
  _SwitchServices({required this.auth, required this.toasts});

  @override
  final AuthRepository auth;
  @override
  final ToastController toasts;
  @override
  final UnsavedChangesGuard unsavedChangesGuard = UnsavedChangesGuard();
  @override
  final SyncRepository sync = _NothingPendingSync();

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _credentials = ApiCredentials(
  baseUrl: 'https://example.test',
  token: 'tok',
);

class _Harness {
  _Harness({bool authenticated = true, bool locked = false})
    : session = ValueNotifier<AuthSession?>(authenticated ? _session() : null),
      credentials = ValueNotifier<ApiCredentials?>(
        authenticated ? _credentials : null,
      ),
      lockedNotifier = ValueNotifier<bool>(locked) {
    toasts = ToastController();
    router = DeepLinkRouter(
      session: session,
      credentials: credentials,
      requiresBiometricUnlock: lockedNotifier,
      registry: _registry(),
      toasts: toasts,
    );
  }

  /// Assign in the order `AuthRepository` does — `_session` first
  /// (`_persistAndActivate:1697`, `restore:1009`), `_credentials` second
  /// (`:1731`, `:1017`). A harness that flips these hides the bug where the
  /// gate reads credentials but listens only to the session.
  void signIn() {
    session.value = _session();
    credentials.value = _credentials;
  }

  final ValueNotifier<AuthSession?> session;
  final ValueNotifier<ApiCredentials?> credentials;
  final ValueNotifier<bool> lockedNotifier;
  late final ToastController toasts;
  late final DeepLinkRouter router;

  final List<String> navigations = [];

  BuildContext? context;

  void attach() => router.attach(go: navigations.add, contextOf: () => context);

  /// Mount a throwaway tree so `Localization.of` resolves — the toasts are
  /// localized off a context even though the queue itself is context-free.
  Future<void> mountContext(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: kTestLocalizationsDelegates,
        supportedLocales: kTestSupportedLocales,
        home: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  void dispose() {
    router.dispose();
    session.dispose();
    credentials.dispose();
    lockedNotifier.dispose();
    toasts.dispose();
  }
}

void main() {
  test('navigates to the record', () async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.router.open(Uri.parse('invoiceninja://app/clients/abc'));
    expect(h.navigations, ['/clients/abc']);
  });

  test('the https form navigates exactly like the custom scheme', () async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    // The session's own host — this is what a colleague on the same instance
    // shares once Copy Link emits https.
    await h.router.open(
      Uri.parse('https://example.test/app/invoices/xyz?company=co1'),
    );
    expect(h.navigations, ['/invoices/xyz']);
  });

  testWidgets('a link from ANOTHER install never navigates, however well its '
      'company id happens to resolve here — hashids are per-instance, so two '
      'self-hosted servers number their companies identically', (tester) async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);

    await h.router.open(
      Uri.parse('https://elsewhere.test/app/clients/abc?company=co1'),
    );

    expect(h.navigations, isEmpty);
    expect(h.toasts.toasts, hasLength(1));
    h.toasts.clearAll();
  });

  testWidgets('…and the bridge page\'s custom-scheme hand-off is caught by the '
      'same check, which is the only thing that can see it', (tester) async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.mountContext(tester);

    // `server=` is what the server-side bridge forwards; without it a custom
    // scheme URL says nothing about where it came from.
    await h.router.open(
      Uri.parse(
        'invoiceninja://app/clients/abc?company=co1&server=https://elsewhere.test',
      ),
    );
    expect(h.navigations, isEmpty);
    expect(h.toasts.toasts, hasLength(1));
    h.toasts.clearAll();

    // The same instance, spelled with a trailing slash and an /api/v1 suffix
    // the way a user may have typed it at login, still matches.
    await h.router.open(
      Uri.parse(
        'invoiceninja://app/clients/abc?company=co1&server=https://example.test/api/v1/',
      ),
    );
    expect(h.navigations, ['/clients/abc']);
  });

  test('a plain custom-scheme link is untouched by the origin check — it '
      'carries no origin, and refusing every one of them would break every '
      'link already in the wild', () async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.router.open(Uri.parse('invoiceninja://app/clients/abc'));
    expect(h.navigations, ['/clients/abc']);
  });

  test('a cold-start link delivered twice is handled once — every native '
      'plugin replays the launch link into the stream AND returns it from '
      'getInitialLink, and the bridge subscribes to both', () async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    final uri = Uri.parse('invoiceninja://app/clients/abc');
    // Both deliveries land before either is handled, as they do at boot.
    await Future.wait([h.router.open(uri), h.router.open(uri)]);
    expect(h.navigations, ['/clients/abc']);
  });

  test('two different links arriving together are serialised, not '
      'interleaved — the point of the _inFlight chain', () async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    // Deliberately NOT awaited between the two: awaiting the first would make
    // this pass even with the chain removed.
    final first = h.router.open(Uri.parse('invoiceninja://app/clients/abc'));
    final second = h.router.open(Uri.parse('invoiceninja://app/invoices/xyz'));
    await Future.wait([first, second]);
    expect(h.navigations, ['/clients/abc', '/invoices/xyz']);
  });

  test('the same link can be followed again later — the dedup covers the '
      'duplicate cold-start delivery, not the user re-pasting into the '
      'command palette', () async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    final uri = Uri.parse('invoiceninja://app/clients/abc');
    await h.router.open(uri);
    await h.router.open(uri);
    expect(h.navigations, ['/clients/abc', '/clients/abc']);
  });

  test('the calendar OAuth return keeps its single-use handoff', () async {
    final h = _Harness()..attach();
    addTearDown(h.dispose);
    await h.router.open(
      Uri.parse('invoiceninja://calendar_connection/complete?handoff=abc'),
    );
    expect(h.navigations, ['/calendar_connection/complete?handoff=abc']);
  });

  testWidgets('an unroutable link navigates nowhere and reports itself', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.mountContext(tester);
    h.attach();
    await h.router.open(Uri.parse('invoiceninja://app/widgets/abc'));
    expect(h.navigations, isEmpty);
    expect(h.toasts.toasts, hasLength(1));
    h.toasts.clearAll(); // cancel the auto-dismiss timers before the test ends
  });

  test(
    'a link that arrives before attach() is replayed, not dropped',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.router.open(Uri.parse('invoiceninja://app/clients/abc'));
      expect(h.navigations, isEmpty);
      h.attach();
      await pumpEventQueue();
      expect(h.navigations, ['/clients/abc']);
    },
  );

  testWidgets(
    'signed out: held silently, then replayed on sign-in — in the order '
    'AuthRepository actually assigns, session before credentials',
    (tester) async {
      final h = _Harness(authenticated: false)..attach();
      addTearDown(h.dispose);
      await h.router.open(Uri.parse('invoiceninja://app/clients/abc'));
      expect(h.navigations, isEmpty);
      expect(h.toasts.toasts, isEmpty, reason: 'nothing to report yet');

      // The session lands first and is NOT yet enough — `isAuthenticated` reads
      // credentials. A gate that woke here and gave up would strand the link.
      h.session.value = _session();
      await tester.pump();
      expect(h.navigations, isEmpty, reason: 'session alone is not signed in');

      h.credentials.value = _credentials;
      await tester.pump();
      expect(h.navigations, ['/clients/abc']);
    },
  );

  testWidgets(
    'a link held for one account is dropped on logout, never replayed '
    'into the next one',
    (tester) async {
      final h = _Harness(authenticated: false)..attach();
      addTearDown(h.dispose);
      await h.router.open(
        Uri.parse('invoiceninja://app/clients/abc?company=co1'),
      );
      expect(h.navigations, isEmpty);

      h.router.reset(); // what `auth.onBeforeLogout` calls
      h.signIn();
      await tester.pump();
      expect(h.navigations, isEmpty);
    },
  );

  testWidgets('…including a link still QUEUED behind another one at logout', (
    tester,
  ) async {
    // `reset()` can clear the deferred slot and the pending set, but it cannot
    // cancel a `.then` already scheduled on the `_inFlight` chain. Such a link
    // used to run after the wipe, find the gate shut, re-defer itself and
    // re-arm the gate listener — surviving into the next account's session,
    // which is the one thing `reset()` exists to prevent.
    final h = _Harness()..attach();
    addTearDown(h.dispose);

    // Two links queued in the same turn: neither `.then` has run yet.
    unawaited(h.router.open(Uri.parse('invoiceninja://app/clients/first')));
    unawaited(h.router.open(Uri.parse('invoiceninja://app/invoices/second')));

    // Logout, in the order `AuthRepository` does it.
    h.router.reset();
    h.session.value = null;
    h.credentials.value = null;
    await tester.pump();
    expect(h.navigations, isEmpty);

    // A different user signs in on the same install.
    h.signIn();
    await tester.pump();
    expect(
      h.navigations,
      isEmpty,
      reason: 'a queued link outlived the session it belonged to',
    );
  });

  testWidgets(
    'biometric-locked: held, and NOTHING happens until unlock — acting '
    'now would run the company-switch dialogs over the lock screen',
    (tester) async {
      final h = _Harness(locked: true)..attach();
      addTearDown(h.dispose);
      await h.router.open(Uri.parse('invoiceninja://app/clients/abc'));
      expect(h.navigations, isEmpty);

      h.lockedNotifier.value = false;
      await tester.pump();
      expect(h.navigations, ['/clients/abc']);
    },
  );

  testWidgets('a cross-company link held under the lock asks its question over '
      'the page that replaces /lock — pushed onto /lock, it went with that '
      'page', (tester) async {
    // Replayed the moment the lock lifted, the switch's prompt landed on
    // `/lock` before the router swapped that page out, went with it, and the
    // switch read as cancelled: the link did nothing at all.
    final h = _Harness(locked: true);
    addTearDown(h.dispose);
    h.session.value = _session(companies: const [_co1, _co2]);
    final auth = _SwitchingAuth(h.session);
    final services = _SwitchServices(auth: auth, toasts: h.toasts);
    final edits = ValueNotifier<int>(0);
    addTearDown(edits.dispose);
    // A form with unsaved edits, so the switch has to ask first.
    services.unsavedChangesGuard.register(isDirty: () => true, source: edits);
    final router = GoRouter(
      initialLocation: '/home',
      refreshListenable: h.lockedNotifier,
      redirect: (_, state) {
        final atLock = state.matchedLocation == '/lock';
        if (h.lockedNotifier.value) return atLock ? null : '/lock';
        return atLock ? '/home' : null;
      },
      routes: [
        GoRoute(path: '/lock', builder: (_, _) => const Text('locked')),
        GoRoute(path: '/home', builder: (_, _) => const Text('home')),
        GoRoute(
          path: '/clients/:id',
          builder: (_, state) => Text('client ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      Provider<Services>.value(
        value: services,
        child: MaterialApp.router(
          localizationsDelegates: kTestLocalizationsDelegates,
          supportedLocales: kTestSupportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    h.router.attach(
      go: router.go,
      contextOf: () => router.routerDelegate.navigatorKey.currentContext,
    );
    await h.router.open(
      Uri.parse('invoiceninja://app/clients/abc?company=co2'),
    );
    await tester.pumpAndSettle();
    expect(find.text('locked'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    h.lockedNotifier.value = false;
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(auth.switchedTo, ['co2']);
    expect(find.text('client abc'), findsOneWidget);
    h.toasts.clearAll();
  });

  testWidgets(
    'a link for a company this account does not have never navigates — '
    'checked up front, since switchCompany would otherwise burn a full '
    'healing /refresh before failing',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.mountContext(tester);
      h.attach();
      await h.router.open(
        Uri.parse('invoiceninja://app/clients/abc?company=someone-elses'),
      );
      expect(h.navigations, isEmpty);
      expect(h.toasts.toasts, hasLength(1));
      h.toasts.clearAll();
    },
  );

  testWidgets(
    'a cross-company link with no context yet is deferred, never switched '
    'behind the guards',
    (tester) async {
      final h = _Harness()..attach(); // contextOf() returns null
      addTearDown(h.dispose);
      await h.router.open(
        Uri.parse('invoiceninja://app/clients/abc?company=someone-elses'),
      );
      expect(h.navigations, isEmpty);
      expect(h.toasts.toasts, isEmpty);
    },
  );

  test(
    'a link for the company already active skips the switch entirely',
    () async {
      final h = _Harness()..attach();
      addTearDown(h.dispose);
      await h.router.open(
        Uri.parse('invoiceninja://app/clients/abc?company=co1'),
      );
      expect(h.navigations, ['/clients/abc']);
    },
  );

  group('the web build, where the link IS the page URL', () {
    test(
      'the company in the fragment is honoured, and the record opens',
      () async {
        final h = _Harness()..attach();
        addTearDown(h.dispose);
        await h.router.openWebInitialLocation(
          Uri.parse('https://example.test/#/clients/abc?company=co1'),
        );
        // Navigated WITHOUT the query: `go()` takes the parsed path, so nothing
        // is left for `nav_state` to persist and replay.
        expect(h.navigations, ['/clients/abc']);
      },
    );

    test('a `company` written ahead of the `#` works too — go_router cannot '
        'see it there either', () async {
      final h = _Harness()..attach();
      addTearDown(h.dispose);
      await h.router.openWebInitialLocation(
        Uri.parse('https://example.test/?company=co1#/invoices/xyz'),
      );
      expect(h.navigations, ['/invoices/xyz']);
    });

    test('an ordinary page load is left entirely alone', () async {
      final h = _Harness()..attach();
      addTearDown(h.dispose);
      // No fragment at all, and a record route with no company: go_router is
      // already routing these, and a second navigation would be a duplicate.
      await h.router.openWebInitialLocation(Uri.parse('https://example.test/'));
      await h.router.openWebInitialLocation(
        Uri.parse('https://example.test/#/clients/abc'),
      );
      expect(h.navigations, isEmpty);
    });

    testWidgets('a company on a route that is not a record is ignored in '
        'silence — nobody typed this URL', (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.mountContext(tester);
      h.attach();
      await h.router.openWebInitialLocation(
        Uri.parse('https://example.test/#/dashboard?company=co1'),
      );
      expect(h.navigations, isEmpty);
      expect(h.toasts.toasts, isEmpty);
    });

    testWidgets('a page URL loaded while signed out is held, not dropped', (
      tester,
    ) async {
      final h = _Harness(authenticated: false)..attach();
      addTearDown(h.dispose);
      await h.router.openWebInitialLocation(
        Uri.parse('https://example.test/#/clients/abc?company=co1'),
      );
      expect(h.navigations, isEmpty);

      h.signIn();
      await tester.pump();
      expect(h.navigations, ['/clients/abc']);
    });

    test('the page host is not treated as an instance claim — the web build '
        'is not always served from the instance it talks to', () async {
      final h = _Harness()..attach();
      addTearDown(h.dispose);
      // Session is https://example.test; the page is somewhere else entirely
      // (the demo build). A pasted *link* from another install is still
      // refused — that check is on `open`, and this is not one.
      await h.router.openWebInitialLocation(
        Uri.parse(
          'https://hillelcoren.github.io/admin/#/clients/abc?company=co1',
        ),
      );
      expect(h.navigations, ['/clients/abc']);
    });
  });
}
