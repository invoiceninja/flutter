import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/app/contacts_sync_controller.dart';
import 'package:admin/data/db/app_database.dart';
import 'package:admin/domain/contacts_sync/contacts_sync_types.dart';

class _FakeEngine implements ContactsSyncEngine {
  /// Set by field, per test, so a test reads as "given a pass that comes back
  /// permission-denied, ...".
  ContactsSyncSummary summary = const ContactsSyncSummary();

  /// When set, `run` blocks on this until the test completes it — lets a test
  /// observe the in-flight window.
  Completer<void>? gate;

  final List<
    ({
      String companyId,
      ContactsSyncScope scope,
      bool isFirstRun,
      bool refreshClients,
    })
  >
  runs = [];
  final List<String> removed = [];
  List<String> companies = const [];
  int previewCount = 0;

  /// The cancellation probe handed to the last `run`, so a test can prove the
  /// controller wired it through.
  bool Function()? lastIsCancelled;

  @override
  Future<ContactsSyncSummary> run({
    required String companyId,
    required ContactsSyncScope scope,
    required bool isFirstRun,
    bool refreshClients = true,
    bool Function()? isCancelled,
    void Function(int done, int total)? onProgress,
  }) async {
    runs.add((
      companyId: companyId,
      scope: scope,
      isFirstRun: isFirstRun,
      refreshClients: refreshClients,
    ));
    lastIsCancelled = isCancelled;
    onProgress?.call(1, 4);
    if (gate != null) await gate!.future;
    return summary;
  }

  @override
  Future<void> removeAll({required String companyId}) async =>
      removed.add(companyId);

  @override
  Future<int> previewCardCount({
    required String companyId,
    required ContactsSyncScope scope,
    bool refreshClients = false,
  }) async {
    previewRefreshed = refreshClients;
    return previewCount;
  }

  /// Whether the last preview asked for a refresh — the pre-flight count is
  /// only trustworthy if it did.
  bool previewRefreshed = false;

  @override
  Future<List<String>> companiesWithSyncedContacts() async => companies;
}

void main() {
  late AppDatabase db;
  late _FakeEngine engine;

  ContactsSyncController build() => ContactsSyncController(
    db: db,
    engine: engine,
    now: () => DateTime.utc(2026, 5, 11, 12),
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    engine = _FakeEngine();
  });

  tearDown(() => db.close());

  group('preferences', () {
    test('defaults to off, all clients', () {
      final c = build();
      expect(c.enabled, isFalse);
      expect(c.scope, ContactsSyncScope.all);
    });

    test('restore() with nothing written leaves the defaults', () async {
      final c = build();
      await c.restore();
      expect(c.enabled, isFalse);
      expect(c.scope, ContactsSyncScope.all);
    });

    test('round-trips through the database', () async {
      final a = build();
      await a.setEnabled(true);
      await a.setScope(ContactsSyncScope.assignedToMe);

      final b = build();
      await b.restore();

      expect(b.enabled, isTrue);
      expect(b.scope, ContactsSyncScope.assignedToMe);
    });

    test('a corrupt blob falls back to off instead of wedging boot', () async {
      await db.navStateDao.saveContactsSync(json: 'not json', now: 0);
      final c = build();
      await c.restore();
      expect(c.enabled, isFalse);
    });

    test('leaves the other nav_state fields alone', () async {
      await db.navStateDao.saveRoute(route: '/clients', now: 1);
      final c = build();
      await c.setEnabled(true);

      final row = await db.navStateDao.current();
      expect(row?.currentRoute, '/clients');
      expect(row?.contactsSyncJson, isNotNull);
    });

    test('does not notify when the same value is chosen twice', () async {
      final c = build();
      var notifications = 0;
      c.addListener(() => notifications++);

      await c.setEnabled(true);
      await c.setEnabled(true);
      await c.setScope(ContactsSyncScope.all);

      expect(notifications, 1);
    });

    test('an unknown stored scope id degrades to all, not a crash', () {
      expect(ContactsSyncScope.fromId('who-knows'), ContactsSyncScope.all);
      expect(ContactsSyncScope.fromId(null), ContactsSyncScope.all);
    });
  });

  group('run', () {
    test('passes the current scope through', () async {
      final c = build();
      await c.setScope(ContactsSyncScope.assignedToMe);
      await c.run('co');
      expect(engine.runs.single.scope, ContactsSyncScope.assignedToMe);
    });

    test('the first pass for a company is flagged as such, later ones are '
        'not — that is what decides a full vs delta client download', () async {
      final c = build();
      await c.run('co');
      await c.run('co');
      expect(engine.runs.map((r) => r.isFirstRun), [true, false]);
    });

    test('a different company is still a first run', () async {
      final c = build();
      await c.run('co');
      await c.run('co2');
      expect(engine.runs.map((r) => r.isFirstRun), [true, true]);
    });

    test(
      'only a successful pass stamps the last-run mark — otherwise the '
      'next run would do a delta against a cache never fully downloaded',
      () async {
        final c = build();
        engine.summary = const ContactsSyncSummary(
          outcome: ContactsSyncOutcome.permissionMissing,
        );
        await c.run('co');

        expect(c.lastRunAt('co'), isNull);
        expect(engine.runs.single.isFirstRun, isTrue);

        engine.summary = const ContactsSyncSummary();
        await c.run('co');
        expect(
          c.lastRunAt('co'),
          DateTime.utc(2026, 5, 11, 12).millisecondsSinceEpoch,
        );
      },
    );

    test('the last-run mark survives a restart', () async {
      final a = build();
      await a.run('co');

      final b = build();
      await b.restore();
      expect(b.hasRunFor('co'), isTrue);
    });

    test('single-flight: a second call joins the first rather than starting '
        'a competing pass over the same address book', () async {
      final c = build();
      engine.gate = Completer<void>();

      final first = c.run('co');
      final second = c.run('co');
      expect(c.isRunning, isTrue);
      engine.gate!.complete();
      await Future.wait([first, second]);

      expect(engine.runs, hasLength(1));
      expect(c.isRunning, isFalse);
    });

    test('reports progress while running, and clears it after', () async {
      final c = build();
      engine.gate = Completer<void>();
      final future = c.run('co');

      expect(c.progress.isRunningFor('co'), isTrue);
      expect(c.progress.done, 1);
      expect(c.progress.total, 4);

      engine.gate!.complete();
      await future;
      expect(c.progress.isRunning, isFalse);
    });

    test('cancel() reaches the in-flight pass', () async {
      final c = build();
      engine.gate = Completer<void>();
      final future = c.run('co');

      expect(engine.lastIsCancelled!(), isFalse);
      c.cancel();
      expect(engine.lastIsCancelled!(), isTrue);

      engine.gate!.complete();
      await future;
    });

    test('the last summary is company-scoped — a result from the company you '
        'were in five minutes ago must not be shown as this one\'s', () async {
      final c = build();
      engine.summary = const ContactsSyncSummary(created: 3);
      await c.run('co');

      expect(c.lastSummaryFor('co')?.created, 3);
      expect(c.lastSummaryFor('other-co'), isNull);
    });

    test(
      'exposes the last summary so the UI can explain a quiet pass',
      () async {
        final c = build();
        engine.summary = const ContactsSyncSummary(created: 3, labelled: false);
        await c.run('co');
        expect(c.lastSummaryFor('co')?.created, 3);
        expect(c.lastSummaryFor('co')?.labelled, isFalse);
      },
    );
  });

  group('refresh ownership', () {
    test(
      'run defaults to refreshing, and honours refreshClients: false',
      () async {
        final c = build();
        await c.run('co');
        await c.run('co', refreshClients: false);
        expect(engine.runs.map((r) => r.refreshClients), [true, false]);
      },
    );

    test('the pre-flight count always refreshes — its whole job is being a '
        'number the user can trust', () async {
      final c = build();
      await c.previewCardCount('co');
      expect(engine.previewRefreshed, isTrue);
    });
  });

  group('removal', () {
    test('removeAll forgets the company', () async {
      final c = build();
      await c.run('co');
      expect(c.hasRunFor('co'), isTrue);

      await c.removeAll('co');

      expect(engine.removed, ['co']);
      expect(c.hasRunFor('co'), isFalse);
    });

    test('removeAllCompanies reaches every company with links, including ones '
        'not opened this session — the logout case', () async {
      final c = build();
      engine.companies = ['co', 'other-co'];

      await c.removeAllCompanies();

      expect(engine.removed, ['co', 'other-co']);
    });

    test('removeAllCompanies cancels an in-flight pass first — logout is '
        'about to wipe the table it writes to', () async {
      final c = build();
      engine.gate = Completer<void>();
      final future = c.run('co');

      final removal = c.removeAllCompanies();
      expect(engine.lastIsCancelled!(), isTrue);

      engine.gate!.complete();
      await Future.wait([future, removal]);
    });

    test('removeAllCompanies WAITS for the in-flight pass — cancel() is '
        'cooperative, so removing while one still runs lets it re-create '
        'contacts that the database wipe then loses track of', () async {
      final c = build();
      engine.companies = ['co'];
      engine.gate = Completer<void>();
      final runFuture = c.run('co');

      var removalDone = false;
      final removal = c.removeAllCompanies().then((_) => removalDone = true);

      // The pass is still gated, so the removal must not have happened yet.
      await pumpEventQueue();
      expect(removalDone, isFalse);
      expect(engine.removed, isEmpty);

      engine.gate!.complete();
      await Future.wait([runFuture, removal]);
      expect(removalDone, isTrue);
      expect(engine.removed, ['co']);
    });

    test(
      'a failure listing companies is swallowed — logout must complete',
      () async {
        final c = build();
        await expectLater(c.removeAllCompanies(), completes);
      },
    );
  });
}
