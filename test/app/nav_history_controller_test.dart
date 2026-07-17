import 'package:admin/app/nav_history_controller.dart';
import 'package:admin/data/repositories/auth/auth_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Targets NavHistoryController's contract — the browser-style back/forward
/// stack. Decoupled from GoRouter the same way NavStatePersister is: a fake
/// [Listenable] + `currentPath` + a recording `navigate`, plus a session
/// notifier so the company-switch/logout reset can be driven directly.

class _FakeRouter extends ChangeNotifier {
  String path = '/';
  void go(String next) {
    path = next;
    notifyListeners();
  }
}

/// Fake router that rewrites a navigation target, simulating a go_router
/// `redirect` firing during a back()/forward() walk.
class _RedirectRouter extends ChangeNotifier {
  String path = '/';
  final Map<String, String> redirects = {};
  void go(String next) {
    path = redirects[next] ?? next;
    notifyListeners();
  }
}

AuthSession _session(String companyId) => AuthSession(
  baseUrl: 'https://example.com',
  isHosted: true,
  accountId: 'acc',
  companies: const [],
  currentCompanyId: companyId,
);

void main() {
  late _FakeRouter router;
  late ValueNotifier<AuthSession?> session;

  NavHistoryController build() => NavHistoryController(
    changes: router,
    currentPath: () => router.path,
    navigate: router.go,
    session: session,
  );

  setUp(() {
    router = _FakeRouter();
    session = ValueNotifier<AuthSession?>(_session('co_1'));
  });

  tearDown(() => session.dispose());

  test('records distinct locations and walks back/forward', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/dashboard');
    router.go('/clients');
    router.go('/clients/c_1');

    expect(c.stack, ['/dashboard', '/clients', '/clients/c_1']);
    expect(c.canGoBack, isTrue);
    expect(c.canGoForward, isFalse);

    c.back();
    expect(router.path, '/clients');
    c.back();
    expect(router.path, '/dashboard');
    expect(c.canGoBack, isFalse);
    expect(c.canGoForward, isTrue);

    c.forward();
    expect(router.path, '/clients');
    expect(c.canGoForward, isTrue);
  });

  test('a fresh navigation after back() prunes the forward branch', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/a');
    router.go('/b');
    router.go('/c');
    c.back(); // at /b
    expect(router.path, '/b');

    router.go('/d'); // fresh branch — /c is dropped
    expect(c.stack, ['/a', '/b', '/d']);
    expect(c.canGoForward, isFalse);
  });

  test('programmatic back/forward does not push a new entry', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/a');
    router.go('/b');
    final lengthBefore = c.stack.length;
    c.back();
    c.forward();
    expect(c.stack.length, lengthBefore);
    expect(c.stack, ['/a', '/b']);
  });

  test('transient gate routes are never recorded', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/clients');
    router.go('/login');
    router.go('/lock');
    router.go('/lock?from=%2Fclients');
    router.go('/setup');

    expect(c.stack, ['/clients']);
  });

  test('consecutive identical locations dedupe', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/clients');
    router.go('/clients');
    router.go('/clients');

    expect(c.stack, ['/clients']);
  });

  test('switching company clears history', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/clients');
    router.go('/clients/c_1');
    expect(c.stack, isNotEmpty);

    session.value = _session('co_2');

    expect(c.stack, isEmpty);
    expect(c.index, -1);
    expect(c.canGoBack, isFalse);
    expect(c.canGoForward, isFalse);
  });

  test('logout (session -> null) clears history', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/clients');
    expect(c.stack, isNotEmpty);

    session.value = null;

    expect(c.stack, isEmpty);
    expect(c.index, -1);
  });

  test('stack is capped at maxEntries', () {
    final c = NavHistoryController(
      changes: router,
      currentPath: () => router.path,
      navigate: router.go,
      session: session,
      maxEntries: 3,
    );
    addTearDown(c.dispose);

    router.go('/a');
    router.go('/b');
    router.go('/c');
    router.go('/d');

    expect(c.stack, ['/b', '/c', '/d']);
    expect(c.index, 2);
  });

  test('redirect during back() re-syncs the cursor (no duplicate)', () {
    final r = _RedirectRouter();
    final c = NavHistoryController(
      changes: r,
      currentPath: () => r.path,
      navigate: r.go,
      session: session,
    );
    addTearDown(c.dispose);

    r.go('/a');
    r.go('/b');
    r.go('/c');
    expect(c.stack, ['/a', '/b', '/c']);

    // Pressing back targets /b, but a guard redirects it to /a.
    r.redirects['/b'] = '/a';
    c.back();

    expect(r.path, '/a');
    expect(c.stack, ['/a', '/b', '/c'], reason: 'stack must not gain an entry');
    expect(c.index, 0, reason: 'cursor re-syncs to where we actually landed');
  });

  test(
    'back() landing on a filtered route does not stick the flag (issue 1)',
    () {
      final r = _RedirectRouter();
      final c = NavHistoryController(
        changes: r,
        currentPath: () => r.path,
        navigate: r.go,
        session: session,
      );
      addTearDown(c.dispose);

      r.go('/x');
      r.go('/a');
      r.go('/b');
      r.go('/c');

      // back() targets /b, but a session-expiry redirect bounces it to
      // /login (a filtered gate route).
      r.redirects['/b'] = '/login';
      c.back();
      expect(r.path, '/login');

      // The user then navigates fresh to an in-stack URL. With the flag
      // stuck this was mistaken for a back/forward result — the forward
      // branch (/a,/b,/c) was wrongly kept. It must be pruned.
      r.redirects.clear();
      r.go('/x');

      expect(c.canGoForward, isFalse);
      expect(c.stack, ['/x', '/a', '/b', '/x']);
    },
  );

  test('back() and forward() notify listeners (visible button state)', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/a');
    router.go('/b');

    // The cursor moves *before* the router change lands, so _onChange takes
    // its "cursor already matches" early-return — which skips notifying.
    // back()/forward() must notify themselves or the sidebar arrow buttons
    // (watching canGoBack/canGoForward) render stale enabled state.
    var notified = 0;
    c.addListener(() => notified++);

    c.back();
    expect(notified, greaterThan(0), reason: 'back() must notify');
    expect(c.canGoBack, isFalse);

    final afterBack = notified;
    c.forward();
    expect(notified, greaterThan(afterBack), reason: 'forward() must notify');
    expect(c.canGoForward, isFalse);
  });
}
