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

  // ---------------------------------------------------------------------
  // Structural "up" navigation (issue #39).
  //
  // Every back affordance in the app navigates with `go()` rather than
  // popping — the pane's leading arrow (`entityCloseTargetPath`),
  // `_closePaneAnimated`, and the inner-navigator pop from `/x/:id/edit` back
  // to `/x/:id`. Appending those would leave the screen the user just closed
  // one step *forward* of the cursor, so the next back — now also the Android
  // system back gesture — would walk right back into it.
  // ---------------------------------------------------------------------

  group('isUpNavigation', () {
    test('a URL-parent is up; a sibling or a lateral jump is not', () {
      expect(isUpNavigation(from: '/quotes/q_1', to: '/quotes'), isTrue);
      expect(
        isUpNavigation(from: '/quotes/q_1/edit', to: '/quotes/q_1'),
        isTrue,
      );
      expect(isUpNavigation(from: '/quotes/q_1/edit', to: '/quotes'), isTrue);

      expect(isUpNavigation(from: '/invoices', to: '/clients'), isFalse);
      expect(isUpNavigation(from: '/quotes/q_1', to: '/quotes/q_2'), isFalse);
      expect(isUpNavigation(from: '/quotes', to: '/quotes/q_1'), isFalse);
      expect(isUpNavigation(from: '/quotes', to: '/quotes'), isFalse);
      // Prefix-but-not-parent: `/quote` must not swallow `/quotes`.
      expect(isUpNavigation(from: '/quotes', to: '/quote'), isFalse);
    });

    test('compares paths only, so ?view=full still matches', () {
      // In-cell links append `?view=full` (`goEntityFullDetail`); the close
      // target may or may not carry it.
      expect(
        isUpNavigation(from: '/clients/c_1?view=full', to: '/clients'),
        isTrue,
      );
    });
  });

  test(
    'the pane back arrow replaces the detail entry instead of appending',
    () {
      final c = build();
      addTearDown(c.dispose);

      router.go('/quotes');
      router.go('/quotes/q_1');
      router.go('/quotes'); // pane leading arrow -> entityCloseTargetPath

      // Without the replace rule this is ['/quotes', '/quotes/q_1', '/quotes']
      // and the next system back re-opens the quote the user just closed.
      expect(c.stack, ['/quotes']);
      expect(c.index, 0);
      expect(c.canGoBack, isFalse);
      expect(c.canGoForward, isFalse);
    },
  );

  test('edit -> detail (inner navigator pop) replaces the edit entry', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/quotes');
    router.go('/quotes/q_1');
    router.go('/quotes/q_1/edit');
    router.go('/quotes/q_1'); // system back pops the nested edit page

    expect(c.stack, ['/quotes', '/quotes/q_1']);
    expect(c.index, 1);
    c.back();
    expect(router.path, '/quotes');
  });

  test('a lateral branch jump still appends (back is not up)', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/clients');
    router.go('/invoices');
    router.go('/clients'); // sidebar, not a back affordance

    expect(c.stack, ['/clients', '/invoices', '/clients']);
    c.back();
    expect(router.path, '/invoices');
  });

  test(
    'closing a cross-entity detail leaves the referrer as the back target',
    () {
      final c = build();
      addTearDown(c.dispose);

      router.go('/invoices/i_1');
      router.go('/clients/c_1?view=full'); // in-cell client link
      router.go('/clients'); // pane leading arrow -> structural up

      expect(c.stack, ['/invoices/i_1', '/clients']);
      c.back();
      expect(router.path, '/invoices/i_1');
    },
  );

  test('an up navigation as the very first entry does not underflow', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/quotes/q_1');
    router.go('/quotes');

    expect(c.stack, ['/quotes']);
    expect(c.index, 0);
  });

  test('a multi-level up collapses the subtree it came out of', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/settings/bank_accounts');
    router.go('/settings/bank_accounts/transaction_rules');
    router.go('/settings/bank_accounts/transaction_rules/tr_1');
    router.go('/settings/bank_accounts'); // up two levels at once

    // Collapsing only one slot would leave `.../transaction_rules` *behind*
    // the cursor, so the next back would descend into a child of where the
    // user now is.
    expect(c.stack, ['/settings/bank_accounts']);
    expect(c.index, 0);
  });

  test('the wide-viewport ?view=full promotion does not double-record', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/quotes');
    router.go('/quotes/q_1');
    router.go('/quotes/q_1/edit');
    // `MasterDetailLayout` auto-promotes an editor to full-screen with a
    // second `go()` one frame later. It is a display mode, not a place.
    router.go('/quotes/q_1/edit?view=full');
    expect(c.stack, ['/quotes', '/quotes/q_1', '/quotes/q_1/edit']);

    // Closing the editor: `entityCloseTargetPath` carries the pane mode.
    router.go('/quotes/q_1?view=full');

    expect(c.stack, ['/quotes', '/quotes/q_1']);
    c.back();
    expect(router.path, '/quotes');
  });

  test('leaving a create form replaces it — back never lands on a blank New '
      'screen', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/quotes');
    router.go('/quotes/new');
    router.go('/quotes/q_new'); // goAfterEntitySave on a create

    expect(c.stack, ['/quotes', '/quotes/q_new']);
    c.back();
    expect(router.path, '/quotes');
  });

  test('abandoning a create form for an unrelated screen also replaces it', () {
    final c = build();
    addTearDown(c.dispose);

    router.go('/quotes');
    router.go('/quotes/new');
    router.go('/clients'); // sidebar, form abandoned

    expect(c.stack, ['/quotes', '/clients']);
    c.back();
    expect(router.path, '/quotes');
  });

  test('a redirected back() re-sync appends, it never overwrites a visited '
      'entry', () {
    final r = _RedirectRouter();
    final c = NavHistoryController(
      changes: r,
      currentPath: () => r.path,
      navigate: r.go,
      session: session,
    );
    addTearDown(c.dispose);

    r.go('/quotes');
    r.go('/quotes/q_1');
    r.go('/quotes/q_1/edit');
    // Backing out of the editor gets bounced somewhere not in the stack.
    r.redirects['/quotes/q_1'] = '/dashboard';
    c.back();

    // The cursor was already moved by back(); the replace rules must not fire
    // on that path or `/quotes/q_1` would be overwritten and lost.
    expect(r.path, '/dashboard');
    expect(c.stack, ['/quotes', '/quotes/q_1', '/dashboard']);
    expect(c.index, 2);
  });

  group('isTransientCreateRoute', () {
    test('matches create forms, with or without a query', () {
      expect(isTransientCreateRoute('/quotes/new'), isTrue);
      expect(isTransientCreateRoute('/quotes/new?view=full'), isTrue);
      expect(isTransientCreateRoute('/quotes'), isFalse);
      expect(isTransientCreateRoute('/quotes/q_1'), isFalse);
      // A record whose id merely ends in "new" is not a create form.
      expect(isTransientCreateRoute('/quotes/renew'), isFalse);
    });
  });
}
