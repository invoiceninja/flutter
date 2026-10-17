import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

/// The Documents list's hand-written SQL, run directly — `DocumentRepository`
/// swallows a relink failure (a missing link costs a cell, never the list), so
/// a wrong table or column name in the parent-table list would otherwise skip
/// every later table without a trace.
void main() {
  late AppDatabase db;
  const co = 'co1';

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertDoc(String id, {bool dirty = false}) =>
      db.documentDao.upsert(
        DocumentRecordsCompanion.insert(
          id: id,
          companyId: co,
          updatedAt: 1,
          payload: jsonEncode({'id': id}),
          isDirty: Value(dirty),
        ),
      );

  test(
    'the relink and listed-ids SQL runs against every parent table',
    () async {
      // A fresh database: every parent table exists and is empty, so any bad
      // name in the list throws here instead of being logged and skipped.
      await insertDoc('d1');
      expect(await db.documentDao.relinkFromParentTables(companyId: co), 0);
      expect(await db.documentDao.idsListedOnRecords(companyId: co), isEmpty);
    },
  );

  test('a record listing a file links it and counts as evidence it exists, '
      'whatever its documents column holds', () async {
    await insertDoc('d1');
    await db.customStatement(
      'INSERT INTO group_settings (id, company_id, name, updated_at, '
      "payload, documents) VALUES ('g1', '$co', 'VIP', 1, '{}', ?)",
      [
        jsonEncode([
          {'id': 'd1'},
        ]),
      ],
    );
    // Malformed and empty columns elsewhere must not break either pass.
    await db.customStatement(
      'INSERT INTO group_settings (id, company_id, name, updated_at, '
      "payload, documents) VALUES ('g2', '$co', 'Other', 1, '{}', 'not json')",
    );

    expect(await db.documentDao.idsListedOnRecords(companyId: co), {'d1'});
    expect(await db.documentDao.relinkFromParentTables(companyId: co), 1);
    final row = await db.documentDao.byId(companyId: co, id: 'd1');
    expect(row!.parentType, 'group');
    expect(row.parentId, 'g1');
  });

  test('the relink wakes watchers only when it links something', () async {
    await insertDoc('d1');
    var emissions = 0;
    final sub = db
        .select(db.documentRecords)
        .watch()
        .listen((_) => emissions++);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final settled = emissions;

    await db.documentDao.relinkFromParentTables(companyId: co);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(emissions, settled, reason: 'nothing was linked');
    await sub.cancel();
  });

  test('deleteByIds never takes a dirty row', () async {
    await insertDoc('clean');
    await insertDoc('dirty', dirty: true);
    await db.documentDao.deleteByIds(companyId: co, ids: ['clean', 'dirty']);
    final left = await db.documentDao.allIds(companyId: co);
    expect(left.map((r) => r.id), ['dirty']);
  });
}
