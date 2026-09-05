import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/deep_link_router.dart';
import 'package:admin/app/entity_modules.dart' show DisabledEntityDispatcher;
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_credentials.dart';
import 'package:admin/domain/entity_registry.dart';
import 'package:admin/domain/entity_type.dart';
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

AuthSession _session({String currentCompanyId = 'co1'}) => AuthSession(
  baseUrl: 'https://example.test',
  isHosted: false,
  accountId: 'acc-1',
  companies: const [
    AuthCompany(
      id: 'co1',
      name: 'One',
      displayName: 'One',
      permissions: '',
      isAdmin: true,
      isOwner: true,
    ),
  ],
  currentCompanyId: currentCompanyId,
);

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

  test('signed out: held silently, then replayed on sign-in — in the order '
      'AuthRepository actually assigns, session before credentials', () async {
    final h = _Harness(authenticated: false)..attach();
    addTearDown(h.dispose);
    await h.router.open(Uri.parse('invoiceninja://app/clients/abc'));
    expect(h.navigations, isEmpty);
    expect(h.toasts.toasts, isEmpty, reason: 'nothing to report yet');

    // The session lands first and is NOT yet enough — `isAuthenticated` reads
    // credentials. A gate that woke here and gave up would strand the link.
    h.session.value = _session();
    await pumpEventQueue();
    expect(h.navigations, isEmpty, reason: 'session alone is not signed in');

    h.credentials.value = _credentials;
    await pumpEventQueue();
    expect(h.navigations, ['/clients/abc']);
  });

  test('a link held for one account is dropped on logout, never replayed '
      'into the next one', () async {
    final h = _Harness(authenticated: false)..attach();
    addTearDown(h.dispose);
    await h.router.open(
      Uri.parse('invoiceninja://app/clients/abc?company=co1'),
    );
    expect(h.navigations, isEmpty);

    h.router.reset(); // what `auth.onBeforeLogout` calls
    h.signIn();
    await pumpEventQueue();
    expect(h.navigations, isEmpty);
  });

  test('…including a link still QUEUED behind another one at logout', () async {
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
    await pumpEventQueue();
    expect(h.navigations, isEmpty);

    // A different user signs in on the same install.
    h.signIn();
    await pumpEventQueue();
    expect(
      h.navigations,
      isEmpty,
      reason: 'a queued link outlived the session it belonged to',
    );
  });

  test(
    'biometric-locked: held, and NOTHING happens until unlock — acting '
    'now would run the company-switch dialogs over the lock screen',
    () async {
      final h = _Harness(locked: true)..attach();
      addTearDown(h.dispose);
      await h.router.open(Uri.parse('invoiceninja://app/clients/abc'));
      expect(h.navigations, isEmpty);

      h.lockedNotifier.value = false;
      await pumpEventQueue();
      expect(h.navigations, ['/clients/abc']);
    },
  );

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
}
