import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

/// Coverage for [ClientDao.pageForContactSync] — the one-shot, paged read the
/// contacts-sync reconcile uses instead of a watch stream.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insert(
    String id, {
    String companyId = 'co',
    String assignedUserId = '',
    int? archivedAt,
    bool isDeleted = false,
  }) => db.clientDao.upsert(
    ClientsCompanion(
      id: Value(id),
      companyId: Value(companyId),
      name: Value(id),
      displayName: Value(id),
      number: const Value(''),
      email: const Value(''),
      balance: const Value('0'),
      assignedUserId: Value(assignedUserId),
      archivedAt: Value(archivedAt),
      isDeleted: Value(isDeleted),
      updatedAt: const Value(1700000000),
      payload: Value(jsonEncode({'id': id, 'name': id})),
    ),
  );

  Future<List<String>> page({
    int offset = 0,
    int limit = 50,
    String? assignedUserId,
    String companyId = 'co',
  }) async {
    final rows = await db.clientDao.pageForContactSync(
      companyId: companyId,
      offset: offset,
      limit: limit,
      assignedUserId: assignedUserId,
    );
    return rows.map((r) => r.id).toList();
  }

  test('returns only active rows — an archived client has stopped trading and '
      'should not keep a card on the phone', () async {
    await insert('a');
    await insert('b', archivedAt: 1700000001);
    await insert('c', isDeleted: true);

    expect(await page(), ['a']);
  });

  test('is scoped by company — one device can hold cards for several, each '
      'under its own label', () async {
    await insert('a');
    await insert('b', companyId: 'other');

    expect(await page(), ['a']);
    expect(await page(companyId: 'other'), ['b']);
  });

  test('filters by assignee when a scope is given', () async {
    await insert('a', assignedUserId: 'u1');
    await insert('b', assignedUserId: 'u2');
    await insert('c');

    expect(await page(assignedUserId: 'u1'), ['a']);
  });

  test('a blank assignee filter means everyone, not "unassigned"', () async {
    await insert('a', assignedUserId: 'u1');
    await insert('b');

    expect(await page(assignedUserId: ''), ['a', 'b']);
    expect(await page(), ['a', 'b']);
  });

  test('pages in a stable order with no gaps or repeats', () async {
    for (final id in ['c3', 'c1', 'c4', 'c2']) {
      await insert(id);
    }

    final first = await page(limit: 2);
    final second = await page(offset: 2, limit: 2);

    expect(first, ['c1', 'c2']);
    expect(second, ['c3', 'c4']);
    expect({...first, ...second}, hasLength(4));
  });

  test('a short page signals the end of the walk', () async {
    await insert('a');
    expect(await page(limit: 2), hasLength(1));
    expect(await page(offset: 1, limit: 2), isEmpty);
  });
}
