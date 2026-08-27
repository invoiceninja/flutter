@TestOn('vm')
library;

import 'dart:io';

import 'package:admin/data/db/app_database.dart';
// `pruneBrokenDbFiles` is native-only (takes a `dart:io` Directory); it lives
// in the io variant of the database-opener seam. This test is `@TestOn('vm')`.
import 'package:admin/data/db/database_opener_io.dart' show pruneBrokenDbFiles;
import 'package:admin/domain/columns/ids/client_column_ids.dart';
import 'package:admin/domain/entity_state.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  group('AppDatabase', () {
    test('CompanyScopedDao isolates rows across companies', () async {
      await db.clientDao.upsert(
        ClientsCompanion.insert(
          id: 'a',
          companyId: 'co1',
          name: 'In company 1',
          number: '',
          email: '',
          displayName: '',
          balance: '0',
          updatedAt: 1,
          payload: '{}',
        ),
      );
      await db.clientDao.upsert(
        ClientsCompanion.insert(
          id: 'b',
          companyId: 'co2',
          name: 'In company 2',
          number: '',
          email: '',
          displayName: '',
          balance: '0',
          updatedAt: 1,
          payload: '{}',
        ),
      );

      final co1 = await db.clientDao
          .watchPage(companyId: 'co1', offset: 0, limit: 50)
          .first;
      final co2 = await db.clientDao
          .watchPage(companyId: 'co2', offset: 0, limit: 50)
          .first;
      expect(co1.map((c) => c.id), ['a']);
      expect(co2.map((c) => c.id), ['b']);
    });

    test('search matches on name, number, and email via LIKE', () async {
      await db.clientDao.upsertAll([
        ClientsCompanion.insert(
          id: '1',
          companyId: 'co',
          name: 'Stark Industries',
          number: 'C-1',
          email: 'tony@stark.test',
          displayName: '',
          balance: '0',
          updatedAt: 1,
          payload: '{}',
        ),
        ClientsCompanion.insert(
          id: '2',
          companyId: 'co',
          name: 'Wayne Enterprises',
          number: 'C-2',
          email: 'bruce@wayne.test',
          displayName: '',
          balance: '0',
          updatedAt: 1,
          payload: '{}',
        ),
      ]);

      final byName = await db.clientDao
          .watchPage(companyId: 'co', offset: 0, limit: 50, search: 'stark')
          .first;
      expect(byName.map((c) => c.id), ['1']);

      final byEmail = await db.clientDao
          .watchPage(
            companyId: 'co',
            offset: 0,
            limit: 50,
            search: 'wayne.test',
          )
          .first;
      expect(byEmail.map((c) => c.id), ['2']);
    });

    test('id_remap remember+resolve round-trips', () async {
      await db.idRemapDao.remember(
        entityType: 'client',
        tempId: 'tmp_xyz',
        realId: 'real_123',
        now: 1,
      );
      final real = await db.idRemapDao.resolve(
        entityType: 'client',
        tempId: 'tmp_xyz',
      );
      expect(real, 'real_123');
    });

    test('outbox enqueue + nextReady honors next_attempt_at', () async {
      await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'client',
          entityId: 'tmp_a',
          mutationKind: 'create',
          payload: '{}',
          idempotencyKey: 'k1',
          nextAttemptAt: 100,
          createdAt: 0,
        ),
      );
      final tooEarly = await db.outboxDao.nextReady(companyId: 'co', now: 50);
      expect(tooEarly, isEmpty);

      final ready = await db.outboxDao.nextReady(companyId: 'co', now: 200);
      expect(ready, hasLength(1));
      expect(ready.first.entityId, 'tmp_a');
    });

    test('outbox pruneDead only removes dead rows past the cutoff', () async {
      Future<int> seed({
        required String entityId,
        required int createdAt,
        required String state,
      }) async {
        final id = await db.outboxDao.enqueue(
          OutboxCompanion.insert(
            companyId: 'co',
            entityType: 'client',
            entityId: entityId,
            mutationKind: 'update',
            payload: '{"pii":"sensitive"}',
            idempotencyKey: entityId,
            nextAttemptAt: 0,
            createdAt: createdAt,
          ),
        );
        if (state != 'pending') {
          await db.outboxDao.markDead(id: id, error: 'x');
        }
        return id;
      }

      final oldDead = await seed(
        entityId: 'old_dead',
        createdAt: 100,
        state: 'dead',
      );
      final freshDead = await seed(
        entityId: 'fresh_dead',
        createdAt: 1_000,
        state: 'dead',
      );
      final oldPending = await seed(
        entityId: 'old_pending',
        createdAt: 100,
        state: 'pending',
      );

      final removed = await db.outboxDao.pruneDead(olderThanMs: 500);

      expect(removed, 1, reason: 'only old_dead matches');
      final remaining = await (db.select(
        db.outbox,
      )).get().then((r) => r.map((x) => x.id));
      expect(
        remaining,
        unorderedEquals([freshDead, oldPending]),
        reason: 'fresh_dead is past the cutoff; old_pending is not dead',
      );
      // Silence unused-var lint; the id was needed to confirm removal.
      expect(oldDead, isNot(equals(freshDead)));
    });

    Future<void> seedRow(
      String id, {
      String companyId = 'co',
      String name = '',
      String balance = '0',
      int updatedAt = 1,
      int createdAt = 1,
      int? archivedAt,
      bool isDeleted = false,
      String customValue1 = '',
      String customValue2 = '',
      String customValue3 = '',
      String customValue4 = '',
    }) async {
      await db.clientDao.upsert(
        ClientsCompanion.insert(
          id: id,
          companyId: companyId,
          name: name.isEmpty ? id : name,
          number: '',
          email: '',
          displayName: '',
          balance: balance,
          updatedAt: updatedAt,
          createdAt: Value(createdAt),
          archivedAt: archivedAt == null
              ? const Value.absent()
              : Value(archivedAt),
          isDeleted: Value(isDeleted),
          customValue1: Value(customValue1),
          customValue2: Value(customValue2),
          customValue3: Value(customValue3),
          customValue4: Value(customValue4),
          payload: '{}',
        ),
      );
    }

    test('state filter: active excludes archived and deleted', () async {
      await seedRow('a-active');
      await seedRow('b-archived', archivedAt: 100);
      await seedRow('c-deleted', isDeleted: true);

      final activeOnly = await db.clientDao
          .watchPage(
            companyId: 'co',
            offset: 0,
            limit: 50,
            states: {EntityState.active},
          )
          .first;
      expect(activeOnly.map((c) => c.id), ['a-active']);
    });

    test('state filter: archived honors archivedAt + not deleted', () async {
      await seedRow('a-active');
      await seedRow('b-archived', archivedAt: 100);
      await seedRow('c-deleted', isDeleted: true);

      final archived = await db.clientDao
          .watchPage(
            companyId: 'co',
            offset: 0,
            limit: 50,
            states: {EntityState.archived},
          )
          .first;
      expect(archived.map((c) => c.id), ['b-archived']);
    });

    test('state filter: multi-select unions the conditions', () async {
      await seedRow('a-active');
      await seedRow('b-archived', archivedAt: 100);
      await seedRow('c-deleted', isDeleted: true);

      final combined = await db.clientDao
          .watchPage(
            companyId: 'co',
            offset: 0,
            limit: 50,
            states: {EntityState.archived, EntityState.deleted},
          )
          .first;
      expect(combined.map((c) => c.id).toSet(), {'b-archived', 'c-deleted'});
    });

    test('state filter: empty set means "no restriction" (show all)', () async {
      await seedRow('a-active');
      await seedRow('b-archived', archivedAt: 5);
      await seedRow('c-deleted', isDeleted: true);
      final rows = await db.clientDao
          .watchPage(
            companyId: 'co',
            offset: 0,
            limit: 50,
            states: const <EntityState>{},
          )
          .first;
      expect(rows.map((c) => c.id).toSet(), {
        'a-active',
        'b-archived',
        'c-deleted',
      });
    });

    test('sort: balance orders numerically, not lexically', () async {
      await seedRow('a', balance: '9');
      await seedRow('b', balance: '1000');
      await seedRow('c', balance: '100');

      final asc = await db.clientDao
          .watchPage(
            companyId: 'co',
            offset: 0,
            limit: 50,
            sortField: ClientFieldIds.balance,
            sortAscending: true,
          )
          .first;
      expect(asc.map((c) => c.id), ['a', 'c', 'b']);

      final desc = await db.clientDao
          .watchPage(
            companyId: 'co',
            offset: 0,
            limit: 50,
            sortField: ClientFieldIds.balance,
            sortAscending: false,
          )
          .first;
      expect(desc.map((c) => c.id), ['b', 'c', 'a']);
    });

    test('sort: createdAt descending', () async {
      await seedRow('old', createdAt: 100);
      await seedRow('mid', createdAt: 200);
      await seedRow('new', createdAt: 300);

      final desc = await db.clientDao
          .watchPage(
            companyId: 'co',
            offset: 0,
            limit: 50,
            sortField: ClientFieldIds.createdAt,
            sortAscending: false,
          )
          .first;
      expect(desc.map((c) => c.id), ['new', 'mid', 'old']);
    });

    test(
      'custom value filter: matches rows whose column is in the set',
      () async {
        await seedRow('vip', customValue1: 'VIP');
        await seedRow('reg', customValue1: 'Regular');
        await seedRow('blank');

        final rows = await db.clientDao
            .watchPage(
              companyId: 'co',
              offset: 0,
              limit: 50,
              customValues1: {'VIP'},
            )
            .first;
        expect(rows.map((c) => c.id), ['vip']);
      },
    );

    test('search composes (AND) with state filter', () async {
      await seedRow('a-active', name: 'Acme');
      await seedRow('b-archived', name: 'Acme', archivedAt: 100);

      final rows = await db.clientDao
          .watchPage(
            companyId: 'co',
            offset: 0,
            limit: 50,
            search: 'Acme',
            states: {EntityState.archived},
          )
          .first;
      expect(rows.map((c) => c.id), ['b-archived']);
    });

    test(
      'watchDistinctCustomValues returns ordered unique non-empty values',
      () async {
        await seedRow('a', customValue2: 'VIP');
        await seedRow('b', customValue2: 'Regular');
        await seedRow('c', customValue2: 'VIP');
        await seedRow('d');

        final values = await db.clientDao
            .watchDistinctCustomValues(companyId: 'co', columnIndex: 2)
            .first;
        expect(values, ['Regular', 'VIP']);
      },
    );

    test('outbox rewriteTempIdInPayloads patches pending rows', () async {
      await db.outboxDao.enqueue(
        OutboxCompanion.insert(
          companyId: 'co',
          entityType: 'invoice',
          entityId: 'tmp_inv',
          mutationKind: 'create',
          payload: '{"client_id":"tmp_client"}',
          idempotencyKey: 'k',
          nextAttemptAt: 0,
          createdAt: 0,
        ),
      );

      await db.outboxDao.rewriteTempIdInPayloads(
        companyId: 'co',
        entityType: 'client',
        tempId: 'tmp_client',
        realId: 'real_c',
      );

      final rows = await db.outboxDao.nextReady(companyId: 'co', now: 1);
      expect(rows.single.payload, '{"client_id":"real_c"}');
    });
  });

  group('isSchemaIntact', () {
    // The schema-drift backstop in `openAppDatabase` exists because at least
    // one user has been observed running a build whose `companies` table is
    // missing the `logo_url` column — every subsequent write throws
    // `SqliteException: no such column: logo_url` deep inside login. The
    // check below probes every table via `PRAGMA table_info`, so a missing
    // column is detected and the opener resets the file instead of letting
    // the crash propagate.

    test('returns true on a freshly created database', () async {
      expect(await isSchemaIntact(db), isTrue);
    });

    test('returns false when a column the code expects is missing', () async {
      // Simulate a schema-drift state: drop a `logo_url` column the code
      // expects. SQLite 3.35+ supports DROP COLUMN, which the sqlite3 native
      // bundle this project uses provides.
      await db.customStatement('ALTER TABLE companies DROP COLUMN logo_url');
      expect(
        await isSchemaIntact(db),
        isFalse,
        reason: 'a missing column must trip the schema-drift detector',
      );
    });

    test('returns false when an entire table is missing', () async {
      await db.customStatement('DROP TABLE dashboard_cache');
      expect(await isSchemaIntact(db), isFalse);
    });
  });

  group('pruneBrokenDbFiles', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('admin_broken_sweep_');
    });
    tearDown(() => tmp.delete(recursive: true));

    File seedBroken(int ts) {
      final f = File(p.join(tmp.path, 'invoiceninja.sqlite.broken.$ts'));
      f.writeAsBytesSync([0]);
      return f;
    }

    File seedOther(String name) {
      final f = File(p.join(tmp.path, name));
      f.writeAsBytesSync([0]);
      return f;
    }

    test('keeps the two newest snapshots, deletes the rest', () async {
      final old1 = seedBroken(100);
      final old2 = seedBroken(200);
      final mid = seedBroken(300);
      final new1 = seedBroken(400);
      final new2 = seedBroken(500);

      await pruneBrokenDbFiles(tmp);

      expect(old1.existsSync(), isFalse);
      expect(old2.existsSync(), isFalse);
      expect(mid.existsSync(), isFalse);
      expect(new1.existsSync(), isTrue);
      expect(new2.existsSync(), isTrue);
    });

    test('leaves the live DB and unrelated files alone', () async {
      final live = seedOther('invoiceninja.sqlite');
      final journal = seedOther('invoiceninja.sqlite-journal');
      final unrelated = seedOther('other.db');
      seedBroken(100);
      seedBroken(200);
      seedBroken(300);

      await pruneBrokenDbFiles(tmp);

      expect(live.existsSync(), isTrue);
      expect(journal.existsSync(), isTrue);
      expect(unrelated.existsSync(), isTrue);
    });

    test('does nothing when count is below the keep threshold', () async {
      final only = seedBroken(100);
      await pruneBrokenDbFiles(tmp);
      expect(only.existsSync(), isTrue);
    });

    test('respects a custom keep count', () async {
      seedBroken(100);
      seedBroken(200);
      final newest = seedBroken(300);

      await pruneBrokenDbFiles(tmp, keep: 1);

      expect(newest.existsSync(), isTrue);
      expect(tmp.listSync().length, 1);
    });
  });
}
