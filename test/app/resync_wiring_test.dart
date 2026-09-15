import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/dashboard_cache_dao.dart';
import 'package:admin/data/repositories/dashboard_repository.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/token_storage.dart';

import '../ui/features/shell/_shell_test_helpers.dart';

/// Guards the issue #14 logout wiring.
///
/// `AuthRepository.onBeforeLogout` is a **single-slot** callback that
/// `Services.build` assigns twice — once to `sync.cancel` (services.dart:1251)
/// and again ~150 lines later to a wrapper that cancels the resync/contacts
/// passes (services.dart:1396). The second assignment is responsible for
/// capturing the first and re-invoking it:
///
/// ```dart
/// final priorOnBeforeLogout = auth.onBeforeLogout;
/// auth.onBeforeLogout = () async { …; await priorOnBeforeLogout?.call(); };
/// ```
///
/// A third registration that forgets that capture silently drops
/// `sync.cancel()`, and `logout()` awaits this hook specifically so an in-flight
/// outbox drain settles *before* the Drift wipe — otherwise a send lands using
/// the credentials of the user who just logged out. Nothing else catches it:
/// it analyzes clean and every other test passes.
void main() {
  group('logout cancels in-flight work', () {
    late AppDatabase db;
    late Services services;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      services = Services.build(
        db: db,
        tokenStorage: InMemoryTokenStorage(),
        connectivityWatcher: ConnectivityWatcher.fixed(online: false),
        // `onActiveCompanyChanged` (exercised below) fires three
        // fire-and-forget chains — the sidebar prefetch across ~14 entities,
        // the Formatter warm, and a tag refresh. Without this they run against
        // a real `http.Client()` (`ApiClient`'s default), so a unit test opens
        // sockets and can surface an unhandled async error *after* it passes.
        // `{"data":[]}` parses as an empty page on every list endpoint, so
        // each chain resolves quietly instead of throwing.
        httpClient: MockClient((_) async => http.Response('{"data":[]}', 200)),
      );
    });

    tearDown(() async {
      // `onActiveCompanyChanged` also starts `RefreshScheduler`'s
      // `Timer.periodic`, which nothing else here cancels — a leaked timer
      // outlives the test and fires against a closed database.
      services.refreshScheduler.stop();
      await services.auth.dispose();
      await db.close();
    });

    /// A row whose `entityType` has no registry entry: an *uncancelled* drain
    /// reaches `_attempt`, finds no dispatcher and marks it dead. So "still
    /// pending" is proof the drain never ran, with no network in the picture.
    Future<int> enqueueUndispatchableRow(String companyId) =>
        db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: companyId,
            entityType: '__no_such_entity__',
            entityId: 'e_1',
            mutationKind: 'update',
            payload: '{}',
            idempotencyKey: 'idem-1',
            nextAttemptAt: 0,
            createdAt: 0,
            requiresPassword: const Value(false),
          ),
        );

    test(
      'the composed onBeforeLogout hook still reaches sync.cancel()',
      () async {
        const companyId = 'company-1';
        final rowId = await enqueueUndispatchableRow(companyId);

        final hook = services.auth.onBeforeLogout;
        expect(hook, isNotNull, reason: 'Services.build must install the hook');
        await hook!();

        await services.sync.drainOnce(companyId: companyId);
        final afterCancel = await db.outboxDao.byId(rowId);
        expect(
          afterCancel?.state,
          'pending',
          reason:
              'onBeforeLogout must leave the sync engine cancelled so the '
              'Drift wipe cannot race a drain. If this row was touched, the '
              '`priorOnBeforeLogout` chain in Services.build dropped '
              'sync.cancel — see this file’s header.',
        );
        expect(afterCancel?.attempts, 0);

        // Two-sided: prove the drain *would* have moved the row, so the
        // assertion above is measuring cancellation and not an unreachable row.
        services.sync.resume();
        await services.sync.drainOnce(companyId: companyId);
        expect(
          (await db.outboxDao.byId(rowId))?.state,
          'dead',
          reason:
              'an uncancelled drain must reach this row — otherwise the check '
              'above is vacuous',
        );
      },
    );

    test('onActiveCompanyChanged resumes the engine after a cancel', () async {
      const companyId = 'company-1';
      final rowId = await enqueueUndispatchableRow(companyId);
      await services.auth.onBeforeLogout!();

      // `resume()` is reached only via onActiveCompanyChanged — the same
      // two-assignment shape, so it has the same dropped-chain failure mode.
      services.auth.onActiveCompanyChanged!(companyId);
      await services.sync.drainOnce(companyId: companyId);
      expect(
        (await db.outboxDao.byId(rowId))?.state,
        'dead',
        reason:
            'without resume() on company activate the engine stays latched '
            'and no mutation ever drains again after a logout',
      );
    });
  });

  /// Still a source scan: `ResyncController.cancel()` is a no-op unless a pass
  /// is already in flight (`if (_inFlight != null)`), and starting one means
  /// driving a full network resync. The behavioural half above covers the
  /// dropped-chain failure mode this pair exists for.
  group('resync controller wiring (issue #14)', () {
    final source = File('lib/app/services.dart').readAsStringSync();

    test('the onBeforeLogout wrap calls resync.cancel()', () {
      final hook = source.indexOf('auth.onBeforeLogout = () async {');
      expect(hook, isNot(-1), reason: 'onBeforeLogout wrap not found');
      final body = source.substring(hook, (hook + 600).clamp(0, source.length));
      expect(
        body.contains('resync.cancel()'),
        isTrue,
        reason:
            'logout wipes every Drift table — without this the rest of the '
            'download keeps writing rows into the wiped database behind the '
            'login screen.',
      );
    });

    test(
      'the resync controller is driven by syncNow, not the raw download',
      () {
        expect(
          source.contains('services.syncNow('),
          isTrue,
          reason:
              'ResyncController must run syncNow so queued offline edits are '
              'pushed before the download, per issue #14.',
        );
      },
    );
  });

  // The header's own layout (stacking, height match, overflow, tap routing) is
  // pumped directly in `sidebar_header_test.dart`. What that test *can't* see
  // is whether `InSidebar` actually threads the rail's state into it — hence
  // this scan.
  group('sidebar Sync button wiring (issue #14)', () {
    final sidebar = File(
      'lib/ui/features/shell/widgets/in_sidebar.dart',
    ).readAsStringSync();

    test('InSidebar mounts SidebarHeader with compact, touch and resync', () {
      const marker = 'SidebarHeader(';
      final start = sidebar.indexOf(marker);
      expect(start, isNot(-1), reason: 'no SidebarHeader construction?');
      final body = sidebar.substring(
        start,
        (start + 900).clamp(0, sidebar.length),
      );
      expect(
        body.contains('compact: collapsed'),
        isTrue,
        reason: 'without compact the header overflows the 64-px collapsed rail',
      );
      expect(
        body.contains('touch: touch'),
        isTrue,
        reason: 'without touch the Sync button keeps the 36-px pointer size',
      );
      expect(
        body.contains('resync: services.resync'),
        isTrue,
        reason:
            'the header must read the shared controller, not a local flag, or '
            'a pass started elsewhere leaves the rail showing an idle button.',
      );
    });
  });

  _syncTailTests();
}

/// Minimal `/api/v1/refresh` body for company `c1`. Without a valid envelope
/// `_persistAndActivate` finds no company and the pass aborts before ever
/// reaching the tail these tests are about.
String _refreshEnvelope() => jsonEncode({
  'data': [
    {
      'is_owner': true,
      'is_admin': true,
      'company': {'id': 'c1', 'name': 'Acme Co'},
      'token': {'token': 'tok'},
      'account': {
        'id': 'acct1',
        'default_company_id': 'c1',
        'plan': 'pro',
        'hosted_company_count': 10,
      },
    },
  ],
});

/// invoiceninja/flutter#160 — a Sync pass used to walk the fourteen entity
/// tables and nothing else, leaving three caches that hang off exactly those
/// rows on pre-sync state: the `dashboard_cache` row both activity surfaces
/// watch, the in-memory per-record feed cache, and the memoized `Formatter`.
///
/// Neither activity screen re-runs its constructor — the shell is a
/// `StatefulShellRoute.indexedStack`, so it stays mounted for the session — so
/// the AppBar refresh button was the only way to see a row the sync had
/// already earned.
void _syncTailTests() {
  group('a Sync pass re-seeds the caches hanging off the entity tables', () {
    late ShellFixture fixture;
    late List<String> paths;

    Future<void> buildWith({Set<String> failPaths = const {}}) async {
      paths = <String>[];
      fixture = await buildFixture(
        companies: const [FakeCompany(id: 'c1', name: 'Acme Co')],
        currentCompanyId: 'c1',
        httpClient: MockClient((req) async {
          paths.add(req.url.path);
          if (failPaths.any(req.url.path.contains)) {
            return http.Response('{"message":"boom"}', 500);
          }
          if (req.url.path.contains('/api/v1/refresh')) {
            return http.Response(_refreshEnvelope(), 200);
          }
          return http.Response('{"data":[]}', 200);
        }),
      );
    }

    tearDown(() => fixture.dispose());

    Future<dynamic> readList(String kind) => fixture.db.dashboardCacheDao.read(
      companyId: 'c1',
      kind: kind,
      filterHash: kDashboardListFilterHash,
    );

    test('refreshes the activity feed both activity surfaces watch', () async {
      await buildWith();

      await fixture.services.syncNow(companyId: 'c1');

      expect(paths, contains('/api/v1/activities'));
      expect(
        await readList(DashboardKind.activities),
        isNotNull,
        reason:
            'the exact `(company, activities, _)` row that the /activity '
            'screen and the dashboard Activity card both watch',
      );
      expect(
        await readList(DashboardKind.recentPayments),
        isNotNull,
        reason:
            'the fix is the whole filter-free list-card set, not activities '
            'alone — a sibling card left stale would be the same bug reported '
            'again from the dashboard',
      );
    });

    test('drops the per-record activity cache', () async {
      await buildWith();
      final api = fixture.services.activities;
      await api.fetchForEntity(entity: 'client', entityId: 'cl_1');
      expect(api.peekForEntity(entity: 'client', entityId: 'cl_1'), isNotNull);

      await fixture.services.syncNow(companyId: 'c1');

      expect(
        api.peekForEntity(entity: 'client', entityId: 'cl_1'),
        isNull,
        reason:
            'a record opened after the sync must not paint its first frame '
            'from a peek that predates the sync',
      );
    });

    test('rebuilds the memoized Formatter', () async {
      await buildWith();
      await fixture.services.formatterFor('c1');
      expect(fixture.services.formatterIfReady('c1'), isNotNull);

      await fixture.services.syncNow(companyId: 'c1');

      expect(
        fixture.services.formatterIfReady('c1'),
        isNull,
        reason:
            'the pass rewrote the companies row this Formatter is derived '
            'from, and nothing else invalidates it: onSettingsWritten fires '
            'only on a local save, and the company-activation hooks are gated '
            'on an actual company change',
      );
    });

    test('a cancelled pass leaves the caches alone', () async {
      await buildWith();
      // False on the first poll (so the pass starts), true on every later one
      // — which is the shape logout and a company switch produce.
      var polls = 0;
      await fixture.services.syncNow(
        companyId: 'c1',
        isCancelled: () => polls++ > 0,
      );

      expect(
        paths,
        isNot(contains('/api/v1/activities')),
        reason:
            'cancellation means the Drift wipe is imminent (logout) or the '
            'next request goes out under another company token — either way '
            'the write must not happen',
      );
      expect(await readList(DashboardKind.activities), isNull);
    });

    test('a failing list-card refresh does not fail the pass', () async {
      await buildWith(failPaths: {'/api/v1/activities'});

      final failed = await fixture.services.syncNow(companyId: 'c1');

      expect(
        failed,
        isEmpty,
        reason:
            'the returned list names entity downloads and drives the '
            'sync_failed toast — a 500 from one dashboard card endpoint must '
            'not report the whole sync as failed',
      );
    });
  });

  group('sync tail wiring (issue #160)', () {
    final source = File('lib/app/services.dart').readAsStringSync();

    test('syncNow re-seeds all three caches', () {
      expect(
        source.contains('dashboard.refreshListCards('),
        isTrue,
        reason:
            'without it the /activity screen and every dashboard list card '
            'keep painting pre-sync rows (#160)',
      );
      expect(
        source.contains('activities.clearCache()'),
        isTrue,
        reason: 'a per-record Activity tab would seed from a stale peek (#160)',
      );
      expect(
        source.contains('invalidateFormatter(companyId)'),
        isTrue,
        reason:
            'the pass rewrites the companies row the Formatter is derived '
            'from, and nothing else invalidates it (#160)',
      );
    });
  });
}
