import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:admin/app/services.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/services/connectivity_watcher.dart';
import 'package:admin/data/services/token_storage.dart';

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
}
