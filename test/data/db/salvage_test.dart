@TestOn('vm')
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as raw;

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/database_opener_io.dart'
    show
        pruneBrokenDbFiles,
        quarantineDatabaseFile,
        readPendingSalvage,
        readQuarantinedStoreFrom,
        retainQuarantinedStore;
import 'package:admin/data/db/db_open_exception.dart';
import 'package:admin/data/db/nav_state_prefs_carry.dart';
import 'package:admin/data/db/salvage.dart';
import 'package:admin/data/prefs/device_pref_keys.dart';
import 'package:admin/data/prefs/device_prefs_store.dart';

/// A reset used to destroy the store whole, the outbox with it: the user's
/// queued and failed edits, the temp-id map they rewrite through, local-only
/// saved views and device preferences — none of which exist anywhere else.
/// The reset now quarantines the store, reads those tables back out without
/// running its migrations, and carries them into the fresh one.

Future<int> seedOutbox(AppDatabase db, {String key = 'k1'}) =>
    db.outboxDao.enqueue(
      OutboxCompanion.insert(
        companyId: 'co',
        entityType: 'client',
        entityId: 'tmp_1',
        mutationKind: 'create',
        payload: '{"name":"Acme"}',
        idempotencyKey: key,
        nextAttemptAt: 0,
        createdAt: 0,
      ),
    );

Future<void> seedDurableAndCache(AppDatabase db) async {
  await seedOutbox(db);
  await db.customStatement(
    'INSERT INTO id_remap (entity_type, temp_id, real_id, created_at) '
    "VALUES ('client', 'tmp_0', 'real_0', 1)",
  );
  await db.customStatement(
    'INSERT INTO nav_state (id, current_route, updated_at) '
    "VALUES (0, '/clients', 1)",
  );
  await db.customStatement(
    'INSERT INTO companies (id, name, settings, permissions, account_id, '
    'token, updated_at, last_sync_at) '
    "VALUES ('co', 'Acme', '{}', '', 'a', 't', 1, 99)",
  );
  await db.clientDao.upsert(
    ClientsCompanion.insert(
      id: 'c1',
      companyId: 'co',
      name: 'Cached',
      number: '',
      email: '',
      displayName: '',
      balance: '0',
      updatedAt: 1,
      payload: '{}',
    ),
  );
}

/// Every row of [table] in [db], column → value — the shape the raw reader
/// hands back.
Future<List<Map<String, Object?>>> rowsOf(AppDatabase db, String table) async {
  return [
    for (final row in await db.customSelect('SELECT * FROM "$table"').get())
      row.data,
  ];
}

Future<int> count(AppDatabase db, String table) async =>
    (await db.customSelect('SELECT COUNT(*) AS n FROM "$table"').getSingle())
        .read<int>('n');

/// A fresh, empty store with its schema created.
Future<AppDatabase> freshDb() async {
  final db = AppDatabase(NativeDatabase.memory());
  await db.customSelect('SELECT 1').get();
  return db;
}

/// SQLITE_NOTADB on the first open — a corrupt store; every later open is a
/// fresh in-memory one.
Future<QueryExecutor> Function() corruptThenFresh() {
  var calls = 0;
  return () async {
    if (++calls == 1) {
      throw SqliteException(
        extendedResultCode: 26,
        message: 'file is not a database',
      );
    }
    return NativeDatabase.memory();
  };
}

void main() {
  group('importSalvaged', () {
    late AppDatabase old;
    late AppDatabase fresh;

    setUp(() async {
      old = await freshDb();
      fresh = await freshDb();
    });
    tearDown(() async {
      await old.close();
      await fresh.close();
    });

    Future<QuarantinedStore> storeOf(AppDatabase db) async => QuarantinedStore(
      source: 'old.sqlite.broken.1',
      tables: {for (final t in kSalvagedTables) t: await rowsOf(db, t)},
    );

    test('carries the durable and anchor tables with their ids and keys, '
        'leaves the cache, and resets the sync cursor', () async {
      await seedDurableAndCache(old);
      final store = await storeOf(old);
      // A reader that over-reads must still not carry a cache table across.
      store.tables['clients'] = await rowsOf(old, 'clients');

      final result = await importSalvaged(fresh, store);

      expect(result.incompleteTables, isEmpty);
      expect(result.rowsByTable, {
        'outbox': 1,
        'id_remap': 1,
        'nav_state': 1,
        'companies': 1,
      });
      final outbox = await fresh.outboxDao.byId(1);
      expect(outbox?.idempotencyKey, 'k1', reason: 'the same mutation');
      expect(outbox?.payload, '{"name":"Acme"}');
      expect(await count(fresh, 'clients'), 0, reason: 'cache re-downloads');
      final company = (await rowsOf(fresh, 'companies')).single;
      expect(company['last_sync_at'], 0, reason: 'the cache it named is gone');
    });

    test('copies only the columns both schemas have', () async {
      final store = QuarantinedStore(
        source: 's',
        tables: {
          'id_remap': [
            // A newer build's extra column, and no `created_at`… which is
            // required, so this table is skipped rather than half-imported.
            {
              'entity_type': 'client',
              'temp_id': 'tmp_1',
              'real_id': 'r1',
              'from_the_future': 'x',
            },
          ],
          'nav_state': [
            // An older build's row: no `tasks_view` (nullable) and no
            // `status_tabs` (defaulted) — both fine.
            {'id': 0, 'current_route': '/tasks', 'updated_at': 1},
          ],
        },
      );

      final result = await importSalvaged(fresh, store);

      expect(result.rowsByTable, {'nav_state': 1});
      expect(result.incompleteTables, ['id_remap']);
      final nav = await fresh.navStateDao.current();
      expect(nav?.currentRoute, '/tasks');
      expect(nav?.statusTabs, isTrue, reason: 'the column default');
    });

    test('a row the new constraints refuse is reported, and the rest still '
        'import', () async {
      await seedOutbox(old);
      final store = await storeOf(old);
      final row = store.tables['outbox']!.single;
      store.tables['outbox'] = [
        row,
        {...row, 'idempotency_key': 'dup'}, // same id — refused
        {...row, 'id': 7, 'idempotency_key': 'k7'},
      ];

      final result = await importSalvaged(fresh, store);

      expect(result.rowsByTable['outbox'], 2);
      expect(result.incompleteTables, ['outbox']);
      expect((await fresh.outboxDao.byId(1))?.idempotencyKey, 'k1');
      expect((await fresh.outboxDao.byId(7))?.idempotencyKey, 'k7');
    });

    test('a store older than v12 has its nav_state preferences carried into '
        'device_prefs', () async {
      // Before v12 the preferences were `nav_state` columns, and a store that
      // old has no `device_prefs` table for the reader to find.
      final store = QuarantinedStore(
        source: 's',
        tables: {
          'nav_state': [
            {
              'id': 0,
              'theme_mode': 'dark',
              'status_tabs': 0,
              'tasks_view': 'kanban',
              'updated_at': 1,
            },
          ],
        },
      );

      await importSalvaged(fresh, store);

      final prefs = DevicePrefsStore(fresh);
      await prefs.load();
      expect(prefs.read(DevicePrefKeys.themeMode), 'dark');
      expect(prefs.read(DevicePrefKeys.statusTabs), isFalse);
      expect(prefs.read(DevicePrefKeys.tasksView), 'kanban');
    });

    test('a v12 store\'s preferences come across as they were — the stale '
        'nav_state column never brings back one the user reset', () async {
      final store = QuarantinedStore(
        source: 's',
        tables: {
          'nav_state': [
            {'id': 0, 'tasks_view': 'kanban', 'updated_at': 1},
          ],
          'device_prefs': [
            {'key': kPrefsCarriedFromNavState, 'value': '1', 'updated_at': 1},
            {'key': 'theme_mode', 'value': 'light', 'updated_at': 2},
          ],
        },
      );

      await importSalvaged(fresh, store);

      final prefs = DevicePrefsStore(fresh);
      await prefs.load();
      expect(prefs.read(DevicePrefKeys.themeMode), 'light');
      expect(
        prefs.read(DevicePrefKeys.tasksView),
        isNull,
        reason: 'the user put the Tasks layout back on the list after v12',
      );
    });

    test('a v12 store whose device_prefs could not be read brings back no '
        'stale nav_state column — now or on a later reset', () async {
      // The carry's once-per-store marker is a device_prefs row, so here it
      // is in the table that could not be read: the carry copied the columns
      // as they stood at the v12 upgrade over whatever the user chose since.
      final store = QuarantinedStore(
        source: 's',
        tables: {
          'nav_state': [
            {'id': 0, 'tasks_view': 'kanban', 'updated_at': 1},
          ],
        },
        unreadableTables: const ['device_prefs'],
      );

      final result = await importSalvaged(fresh, store);
      // What a salvage of this store would run next time.
      await carryNavStatePrefs(fresh);

      expect(result.incompleteTables, ['device_prefs']);
      final prefs = DevicePrefsStore(fresh);
      await prefs.load();
      expect(prefs.read(DevicePrefKeys.tasksView), isNull);
    });
  });

  group('openAppDatabase salvage', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('salvage_'));
    tearDown(() => dir.delete(recursive: true));

    test('a corrupt store\'s unsynced work reaches the fresh store', () async {
      final old = await freshDb();
      await seedDurableAndCache(old);
      final store = QuarantinedStore(
        source: 'invoiceninja.sqlite.broken.1',
        tables: {for (final t in kSalvagedTables) t: await rowsOf(old, t)},
      );
      await old.close();

      final opened = await openAppDatabase(
        openExecutor: corruptThenFresh(),
        destroyStore: () async => true,
        readQuarantined: () async => store,
      );

      expect(opened.wasReset, isTrue);
      final recovery = opened.recovery;
      expect(recovery, isA<LocalDataSalvaged>());
      expect((recovery! as LocalDataSalvaged).unsyncedChanges, 1);
      expect((await opened.db.outboxDao.byId(1))?.idempotencyKey, 'k1');
      expect(
        await opened.db.companiesDao.byId('co'),
        isNotNull,
        reason: 'restore() resumes the session from it',
      );
      await opened.db.close();
    });

    test('an unreadable store is reported with where it was kept', () async {
      final opened = await openAppDatabase(
        openExecutor: corruptThenFresh(),
        destroyStore: () async => true,
        readQuarantined: () async => const QuarantinedStore(
          source: 'invoiceninja.sqlite.unrecovered.1',
          error: 'file is not a database',
        ),
      );

      expect(
        opened.recovery,
        isA<LocalDataUnrecoverable>().having(
          (r) => r.retainedAt,
          'retainedAt',
          'invoiceninja.sqlite.unrecovered.1',
        ),
      );
      expect(await isSchemaIntact(opened.db), isTrue);
      await opened.db.close();
    });

    test('a reader that throws still opens a usable store', () async {
      final opened = await openAppDatabase(
        openExecutor: corruptThenFresh(),
        destroyStore: () async => true,
        readQuarantined: () async => throw StateError('keychain'),
      );

      expect(opened.recovery, isA<LocalDataUnrecoverable>());
      expect(await isSchemaIntact(opened.db), isTrue);
      await opened.db.close();
    });

    /// A quarantined snapshot on disk, so retention can rename it.
    File snapshotFile(int ts) =>
        File(p.join(dir.path, 'invoiceninja.sqlite.broken.$ts'))
          ..writeAsStringSync('old');

    test('rows left behind keep the old store out of the pruning', () async {
      final snapshot = snapshotFile(5);
      final opened = await openAppDatabase(
        openExecutor: corruptThenFresh(),
        destroyStore: () async => true,
        readQuarantined: () async => QuarantinedStore(
          source: snapshot.path,
          tables: {
            'outbox': [
              {'id': 1}, // lacks every required column — skipped
            ],
          },
        ),
      );

      final kept = p.join(dir.path, 'invoiceninja.sqlite.unrecovered.5');
      expect(
        opened.recovery,
        isA<LocalDataSalvaged>()
            .having((r) => r.incompleteTables, 'incomplete', ['outbox'])
            .having((r) => r.source, 'source', kept),
      );
      expect(File(kept).existsSync(), isTrue);
      await opened.db.close();
    });

    test(
      'a failed import keeps the old store too, and imports nothing',
      () async {
        final old = await freshDb();
        await seedDurableAndCache(old);
        final outbox = await rowsOf(old, 'outbox');
        final nav = await rowsOf(old, 'nav_state');
        await old.close();
        final snapshot = snapshotFile(6);

        final opened = await openAppDatabase(
          openExecutor: corruptThenFresh(),
          destroyStore: () async => true,
          readQuarantined: () async => QuarantinedStore(
            source: snapshot.path,
            tables: {
              'nav_state': nav,
              // Unbindable — the import throws and the transaction rolls back.
              'outbox': [
                {...outbox.single, 'payload': Object()},
              ],
            },
          ),
        );

        final kept = p.join(dir.path, 'invoiceninja.sqlite.unrecovered.6');
        expect(
          opened.recovery,
          isA<LocalDataUnrecoverable>().having(
            (r) => r.retainedAt,
            'retainedAt',
            kept,
          ),
        );
        expect(File(kept).existsSync(), isTrue);
        expect(
          await count(opened.db, 'nav_state'),
          0,
          reason: 'all or nothing',
        );
        expect(await isSchemaIntact(opened.db), isTrue);
        await opened.db.close();
      },
    );

    test(
      'a store that opens with nothing pending reports no recovery',
      () async {
        var reads = 0;
        final opened = await openAppDatabase(
          openExecutor: () async => NativeDatabase.memory(),
          destroyStore: () async => true,
          readQuarantined: () async {
            reads++;
            return null;
          },
        );

        expect(opened.recovery, isNull);
        expect(reads, 1, reason: 'every open looks for a pending salvage');
        await opened.db.close();
      },
    );

    test('a store that opens still takes a salvage an earlier launch left '
        'pending', () async {
      // The launch that quarantined the store died before importing it — or
      // the boot screen's Reset ran and the user relaunched.
      final old = await freshDb();
      await seedOutbox(old);
      final outbox = await rowsOf(old, 'outbox');
      await old.close();

      final opened = await openAppDatabase(
        openExecutor: () async => NativeDatabase.memory(),
        destroyStore: () async => true,
        readQuarantined: () async => QuarantinedStore(
          source: 'invoiceninja.sqlite.broken.1',
          tables: {'outbox': outbox},
        ),
      );

      expect(opened.wasReset, isFalse);
      expect(opened.recovery, isA<LocalDataSalvaged>());
      expect((await opened.db.outboxDao.byId(1))?.idempotencyKey, 'k1');
      await opened.db.close();
    });
  });

  group('native quarantine reader', () {
    late Directory dir;
    late File file;
    const key =
        '00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff';
    const otherKey =
        'ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100';

    setUp(() {
      dir = Directory.systemTemp.createTempSync('quarantine_');
      file = File(p.join(dir.path, 'invoiceninja.sqlite'));
    });
    tearDown(() => dir.delete(recursive: true));

    /// The same three pragmas `openDatabaseExecutor` runs.
    QueryExecutor encrypted(File f, String k) => NativeDatabase(
      f,
      setup: (raw) {
        raw.execute("PRAGMA cipher = 'sqlcipher'");
        raw.execute('PRAGMA legacy = 4');
        raw.execute("PRAGMA key = \"x'$k'\"");
      },
    );

    Future<void> seedEncryptedStore() async {
      final db = AppDatabase(encrypted(file, key));
      await seedDurableAndCache(db);
      await db.close();
    }

    test('reads the durable and anchor tables of an encrypted store, and '
        'nothing else', () async {
      await seedEncryptedStore();
      final snapshot = await quarantineDatabaseFile(file);
      expect(snapshot, isNotNull);
      expect(file.existsSync(), isFalse);

      final store = readQuarantinedStoreFrom(File(snapshot!), key: key);

      expect(store.readable, isTrue, reason: '${store.error}');
      expect(store.tables['outbox'], hasLength(1));
      expect(store.tables['outbox']!.single['idempotency_key'], 'k1');
      expect(store.tables['nav_state']!.single['current_route'], '/clients');
      expect(store.tables['companies'], hasLength(1));
      expect(store.tables.containsKey('clients'), isFalse);
    });

    test('the wrong key reads as unreadable, not as an empty store', () async {
      await seedEncryptedStore();
      final snapshot = await quarantineDatabaseFile(file);

      final store = readQuarantinedStoreFrom(File(snapshot!), key: otherKey);

      expect(store.readable, isFalse);
      expect(store.tables, isEmpty);
    });

    test(
      'a round trip: read, import, and the mutation is the same one',
      () async {
        await seedEncryptedStore();
        final snapshot = await quarantineDatabaseFile(file);
        final fresh = AppDatabase(encrypted(file, key));
        await fresh.customSelect('SELECT 1').get();

        final result = await importSalvaged(
          fresh,
          readQuarantinedStoreFrom(File(snapshot!), key: key),
        );

        expect(result.incompleteTables, isEmpty);
        final row = await fresh.outboxDao.byId(1);
        expect(row?.idempotencyKey, 'k1');
        expect(row?.entityId, 'tmp_1');
        await fresh.close();
      },
    );

    File marker() => File(p.join(dir.path, 'invoiceninja.sqlite.salvage'));

    test(
      'a quarantine marks its snapshot, and the mark is taken once',
      () async {
        await seedEncryptedStore();
        await quarantineDatabaseFile(file);
        expect(marker().existsSync(), isTrue);

        final store = await readPendingSalvage(dir, key: () async => key);

        expect(store?.tables['outbox'], hasLength(1));
        expect(marker().existsSync(), isFalse);
        expect(
          await readPendingSalvage(dir, key: () async => key),
          isNull,
          reason: 'a second import would resurrect rows delivered since',
        );
      },
    );

    test('an older snapshot is never re-read', () async {
      await seedEncryptedStore();
      await quarantineDatabaseFile(file);
      marker().deleteSync(); // its salvage already ran

      expect(await readPendingSalvage(dir, key: () async => key), isNull);
    });

    test('no store, nothing to mark', () async {
      expect(await quarantineDatabaseFile(file), isNull);
      expect(marker().existsSync(), isFalse);
    });

    test('a mark naming a snapshot that never appeared is dropped', () async {
      // The process died between writing the mark and moving the store.
      marker().writeAsStringSync('invoiceninja.sqlite.broken.1');

      expect(await readPendingSalvage(dir, key: () async => key), isNull);
      expect(marker().existsSync(), isFalse);
    });

    test('an unreadable snapshot is kept, and a lost key says so', () async {
      await seedEncryptedStore();
      await quarantineDatabaseFile(file);

      final store = await readPendingSalvage(
        dir,
        key: () async => otherKey,
        keyLost: true,
      );

      expect(store?.readable, isFalse);
      expect(store?.error, isA<DatabaseKeyLostException>());
      expect(p.basename(store!.source), contains('.unrecovered.'));
      expect(File(store.source).existsSync(), isTrue);
    });

    test('a second quarantine before the salvage keeps the first one '
        'marked', () async {
      // The reset's fresh store failed too, and the boot screen's Reset moved
      // that one aside as well. Re-marking it orphaned the snapshot holding
      // the unsynced work: the next launch imported an empty store, said
      // everything was rebuilt, and pruning later deleted the real one.
      await seedEncryptedStore();
      final first = await quarantineDatabaseFile(file);
      final fresh = AppDatabase(encrypted(file, key));
      await fresh.customSelect('SELECT 1').get();
      await fresh.close();
      // Distinct timestamps, so the second snapshot can't land on the first.
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final second = await quarantineDatabaseFile(file);

      expect(marker().readAsStringSync(), p.basename(first!));
      // Never finished an open, so it holds no work — but kept out of the
      // pruning rather than trusted to be empty.
      expect(
        p.basename(second!),
        startsWith('invoiceninja.sqlite.unrecovered.'),
      );
      final store = await readPendingSalvage(dir, key: () async => key);
      expect(store?.tables['outbox'], hasLength(1));
    });

    test('pruning never deletes the snapshot awaiting its salvage', () async {
      await seedEncryptedStore();
      final marked = await quarantineDatabaseFile(file);
      final newer = File(
        p.join(
          dir.path,
          'invoiceninja.sqlite.broken.'
          '${DateTime.now().millisecondsSinceEpoch + 60000}',
        ),
      )..writeAsStringSync('x');

      await pruneBrokenDbFiles(dir, keep: 0);

      expect(File(marked!).existsSync(), isTrue);
      expect(newer.existsSync(), isFalse);
    });

    test('a table that fails to read is left behind, not taken for an empty '
        'one', () async {
      // The reader logged the failure and skipped the table, and the import
      // then had no outbox rows to carry: the user was told everything came
      // across, and the copy still holding their unsynced work stayed
      // prunable. A virtual column that overflows on read stands in for a
      // damaged table: the store opens, the other tables read.
      final db = AppDatabase(NativeDatabase(file));
      await seedDurableAndCache(db);
      await db.close();
      raw.sqlite3.open(file.path)
        ..execute(
          'ALTER TABLE outbox ADD COLUMN boom INTEGER GENERATED ALWAYS AS '
          '(abs(-9223372036854775807 - 1)) VIRTUAL',
        )
        ..close();

      final store = readQuarantinedStoreFrom(file);
      final fresh = await freshDb();
      addTearDown(fresh.close);
      final result = await importSalvaged(fresh, store);

      expect(store.readable, isTrue);
      expect(result.incompleteTables, ['outbox']);
      expect(result.rowsByTable['id_remap'], 1, reason: 'the rest still come');
    });

    test('a retained store survives snapshot pruning', () async {
      await seedEncryptedStore();
      final snapshot = await quarantineDatabaseFile(file);

      final kept = await retainQuarantinedStore(snapshot!);
      await pruneBrokenDbFiles(dir, keep: 0);

      expect(p.basename(kept), startsWith('invoiceninja.sqlite.unrecovered.'));
      expect(File(kept).existsSync(), isTrue);
      expect(File(snapshot).existsSync(), isFalse);
    });
  });
}
