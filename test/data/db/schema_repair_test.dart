@TestOn('vm')
library;

import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/schema_repair.dart';
import 'package:admin/data/db/table_retention.dart';

/// Drop [column] from [table] the way a migration that never landed leaves
/// it — including any index over it, which SQLite would otherwise refuse to
/// orphan.
Future<void> dropColumn(AppDatabase db, String table, String column) async {
  final indexes = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' "
        'AND tbl_name = ? AND sql LIKE ?',
        variables: [
          Variable.withString(table),
          Variable.withString('%$column%'),
        ],
      )
      .get();
  for (final index in indexes) {
    await db.customStatement('DROP INDEX ${index.read<String>('name')}');
  }
  await db.customStatement('ALTER TABLE $table DROP COLUMN $column');
}

Future<void> seedOutbox(AppDatabase db) => db.outboxDao.enqueue(
  OutboxCompanion.insert(
    companyId: 'co',
    entityType: 'client',
    entityId: 'tmp_1',
    mutationKind: 'create',
    payload: '{}',
    idempotencyKey: 'k1',
    nextAttemptAt: 0,
    createdAt: 0,
  ),
);

Future<void> seedCursor(AppDatabase db) => db.customStatement(
  'INSERT INTO sync_state_rows (company_id, entity_type, last_updated_at) '
  "VALUES ('co', 'client', 42)",
);

Future<int> count(AppDatabase db, String table) async =>
    (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
        .read<int>('n');

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.customSelect('SELECT 1').get(); // create the schema
  });
  tearDown(() => db.close());

  test(
    'every table is classified — a new one must say what losing it costs',
    () {
      final unclassified = [
        for (final t in db.allTables)
          if (!kTableRetention.containsKey(t.actualTableName))
            t.actualTableName,
      ];
      expect(unclassified, isEmpty);
      expect(retentionOf('outbox'), TableRetention.durable);
      expect(retentionOf('a_table_nobody_classified'), TableRetention.durable);
    },
  );

  test('a missing nullable column is added in place; rows and cursors are '
      'kept for a non-cache table', () async {
    // The drift actually seen in the field: `companies.logo_url` missing.
    await db.customStatement(
      'INSERT INTO companies (id, name, settings, permissions, account_id, '
      "token, updated_at) VALUES ('co', 'Acme', '{}', '', 'a', 't', 1)",
    );
    await seedCursor(db);
    await dropColumn(db, 'companies', 'logo_url');
    expect(await isSchemaIntact(db), isFalse);

    final report = await repairSchema(db);

    expect(report.addedColumns, ['companies.logo_url']);
    expect(await isSchemaIntact(db), isTrue);
    expect(await count(db, 'companies'), 1, reason: 'rows kept');
    expect(await count(db, 'sync_state_rows'), 1, reason: 'no cache changed');
  });

  test('a cache table missing a column it can\'t add is rebuilt; the outbox '
      'survives and the cursors reset so it re-downloads', () async {
    await seedOutbox(db);
    await seedCursor(db);
    await dropColumn(db, 'clients', 'balance'); // NOT NULL, no default

    final report = await repairSchema(db);

    expect(report.rebuiltTables, ['clients']);
    expect(await isSchemaIntact(db), isTrue);
    expect(await count(db, 'outbox'), 1, reason: 'the user\'s queued work');
    expect(await count(db, 'sync_state_rows'), 0, reason: 're-download');
  });

  test('a missing table is created', () async {
    await db.customStatement('DROP TABLE dashboard_cache');
    final report = await repairSchema(db);
    expect(report.createdTables, ['dashboard_cache']);
    expect(await isSchemaIntact(db), isTrue);
  });

  test('a durable table missing a column it can\'t add is refused, and '
      'nothing is changed', () async {
    await seedOutbox(db);
    await dropColumn(db, 'outbox', 'payload');
    await dropColumn(db, 'clients', 'balance'); // would be rebuilt…

    await expectLater(
      repairSchema(db),
      throwsA(isA<SchemaUnrepairableException>()),
    );
    // …but the whole repair is one transaction.
    final clientColumns = [
      for (final row
          in await db.customSelect('PRAGMA table_info(clients)').get())
        row.read<String>('name'),
    ];
    expect(clientColumns, isNot(contains('balance')));
    expect(await count(db, 'outbox'), 1);
  });

  group('through openAppDatabase', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('schema_repair_');
      file = File(p.join(dir.path, 'app.sqlite'));
    });
    tearDown(() => dir.delete(recursive: true));

    /// Build a current-schema store on disk, then damage it with [damage].
    Future<void> storeWith(Future<void> Function(AppDatabase db) damage) async {
      final seed = AppDatabase(NativeDatabase(file));
      await seed.customSelect('SELECT 1').get();
      await seedOutbox(seed);
      await damage(seed);
      await seed.close();
    }

    test('a drifted but repairable store opens without a reset', () async {
      await storeWith((db) => dropColumn(db, 'companies', 'logo_url'));
      var destroyed = 0;

      final opened = await openAppDatabase(
        openExecutor: () async => NativeDatabase(file),
        destroyStore: () async {
          destroyed++;
          return true;
        },
      );

      expect(destroyed, 0, reason: 'the reset used to take the outbox too');
      expect(opened.wasReset, isFalse);
      expect(await count(opened.db, 'outbox'), 1);
      await opened.db.close();
    });

    test(
      'an upgrade whose own step fails is repaired instead of reset',
      () async {
        // A v10 store whose `clients` lacks `updated_at`: the upgrade's index
        // pass (`CREATE INDEX … (company_id, updated_at)`) fails, the steps
        // roll back, and the repair rebuilds the cache table instead.
        await storeWith((db) async {
          await dropColumn(db, 'clients', 'updated_at');
          await db.customStatement('PRAGMA user_version = 10');
        });
        var destroyed = 0;

        final opened = await openAppDatabase(
          openExecutor: () async => NativeDatabase(file),
          destroyStore: () async {
            destroyed++;
            return true;
          },
        );

        expect(destroyed, 0);
        expect(await isSchemaIntact(opened.db), isTrue);
        expect(await count(opened.db, 'outbox'), 1);
        await opened.db.close();
      },
    );
  });
}
