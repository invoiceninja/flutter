import 'package:admin/app/nav_state_persister.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests target NavStatePersister's contract:
///   * route changes are debounced into a single write at the trailing edge
///   * `/login` is filtered so it doesn't clobber a previously-saved deep link
/// They DON'T re-test GoRouter or Drift — the persister is decoupled via a
/// [Listenable] + `currentPath` getter, so the tests drive those directly.

class _FakeRouter extends ChangeNotifier {
  String path = '/';
  void go(String next) {
    path = next;
    notifyListeners();
  }
}

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  test('debounces rapid route changes into one write', () async {
    final router = _FakeRouter();
    final persister = NavStatePersister(
      changes: router,
      currentPath: () => router.path,
      db: db,
      debounce: const Duration(milliseconds: 20),
    );
    addTearDown(persister.dispose);

    router.go('/settings');
    router.go('/clients');

    // Before the timer fires nothing is persisted.
    expect((await db.navStateDao.current())?.currentRoute, isNull);

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(
      (await db.navStateDao.current())?.currentRoute,
      '/clients',
      reason: 'only the trailing value should be persisted',
    );
  });

  test(
    '/login is filtered so it does not overwrite a saved deep link',
    () async {
      final router = _FakeRouter();
      final persister = NavStatePersister(
        changes: router,
        currentPath: () => router.path,
        db: db,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(persister.dispose);

      // Land somewhere real first.
      router.go('/settings');
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect((await db.navStateDao.current())?.currentRoute, '/settings');

      // Simulate logout: router lands at /login. The persister must refuse
      // so the user comes back to /settings on next launch.
      router.go('/login');
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(
        (await db.navStateDao.current())?.currentRoute,
        '/settings',
        reason: '/login must not clobber the user\'s prior real location',
      );
    },
  );

  test(
    'strips the transient module_off query param before persisting',
    () async {
      final router = _FakeRouter();
      final persister = NavStatePersister(
        changes: router,
        currentPath: () => router.path,
        db: db,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(persister.dispose);

      // Router bounced the user off a disabled module to /dashboard with the
      // one-time notice flag — only the bare path should be saved.
      router.go('/dashboard?module_off=invoices');
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect((await db.navStateDao.current())?.currentRoute, '/dashboard');
    },
  );

  test(
    'strips the view query param so full-screen never survives a restart',
    () async {
      final router = _FakeRouter();
      final persister = NavStatePersister(
        changes: router,
        currentPath: () => router.path,
        db: db,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(persister.dispose);

      // The full-screen pane choice is deliberately not remembered: a cold
      // launch always resolves the per-screen default (sidebar preview).
      // A non-create route on purpose: `/x/new` routes are filtered out
      // entirely (never persisted), so the old `/invoices/new?...` input
      // asserted a route the persister now deliberately drops.
      router.go('/invoices/abc123/edit?view=full&client_id=abc');
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(
        (await db.navStateDao.current())?.currentRoute,
        '/invoices/abc123/edit?client_id=abc',
      );
    },
  );

  test('preserves a Tasks layout view mode (view=calendar) across a restart — '
      'only the master-detail view=full pane flag is transient', () async {
    final router = _FakeRouter();
    final persister = NavStatePersister(
      changes: router,
      currentPath: () => router.path,
      db: db,
      debounce: const Duration(milliseconds: 10),
    );
    addTearDown(persister.dispose);

    router.go('/tasks?view=calendar');
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(
      (await db.navStateDao.current())?.currentRoute,
      '/tasks?view=calendar',
      reason: 'leaving Tasks on a layout mode must resume that mode',
    );
  });

  test(
    'never persists /calendar_connection/complete — its one-time handoff token '
    'must not be written to disk or replayed on the next cold start',
    () async {
      final router = _FakeRouter();
      final persister = NavStatePersister(
        changes: router,
        currentPath: () => router.path,
        db: db,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(persister.dispose);

      router.go('/tasks'); // a real prior location
      await Future<void>.delayed(const Duration(milliseconds: 25));
      router.go('/calendar_connection/complete?provider=google&handoff=secret');
      await Future<void>.delayed(const Duration(milliseconds: 25));

      expect(
        (await db.navStateDao.current())?.currentRoute,
        '/tasks',
        reason: 'the OAuth landing gate is skipped; the prior route stands',
      );
    },
  );

  test('keeps non-transient query params (e.g. client_id)', () async {
    final router = _FakeRouter();
    final persister = NavStatePersister(
      changes: router,
      currentPath: () => router.path,
      db: db,
      debounce: const Duration(milliseconds: 10),
    );
    addTearDown(persister.dispose);

    router.go('/invoices?client_id=abc&module_off=quotes');
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(
      (await db.navStateDao.current())?.currentRoute,
      '/invoices?client_id=abc',
    );
  });

  test('never persists ?company= — a record link opened in the web build is '
      'consumed once at boot, and replaying the workspace switch on every cold '
      'start would land in a company the user may since have left', () async {
    final router = _FakeRouter();
    final persister = NavStatePersister(
      changes: router,
      currentPath: () => router.path,
      db: db,
      debounce: const Duration(milliseconds: 10),
    );
    addTearDown(persister.dispose);

    router.go('/clients/abc?company=co1');
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect((await db.navStateDao.current())?.currentRoute, '/clients/abc');
  });

  test('never persists the Outbox of another company either', () async {
    final router = _FakeRouter();
    final persister = NavStatePersister(
      changes: router,
      currentPath: () => router.path,
      db: db,
      debounce: const Duration(milliseconds: 10),
    );
    addTearDown(persister.dispose);

    router.go('/sync/outbox?company=co2');
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect((await db.navStateDao.current())?.currentRoute, '/sync/outbox');
  });

  test(
    'a path that merely contains the word company is untouched — the removal, '
    'not the substring check, is what decides',
    () async {
      final router = _FakeRouter();
      final persister = NavStatePersister(
        changes: router,
        currentPath: () => router.path,
        db: db,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(persister.dispose);

      router.go('/settings/company_details?tab=address');
      await Future<void>.delayed(const Duration(milliseconds: 25));
      expect(
        (await db.navStateDao.current())?.currentRoute,
        '/settings/company_details?tab=address',
      );
    },
  );

  test('repeated navigation to the same route writes only once', () async {
    final router = _FakeRouter();
    final persister = NavStatePersister(
      changes: router,
      currentPath: () => router.path,
      db: db,
      debounce: const Duration(milliseconds: 10),
    );
    addTearDown(persister.dispose);

    router.go('/clients');
    await Future<void>.delayed(const Duration(milliseconds: 25));
    final firstUpdate = (await db.navStateDao.current())!.updatedAt;

    // Same path again — should not produce a fresh write.
    router.go('/clients');
    await Future<void>.delayed(const Duration(milliseconds: 25));
    final secondUpdate = (await db.navStateDao.current())!.updatedAt;
    expect(secondUpdate, firstUpdate, reason: 'no-op when path is unchanged');
  });
}
