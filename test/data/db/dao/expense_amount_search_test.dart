// `ExpenseFilters` and `RecurringExpenseFilters` LIKE the amount, so the local
// search must too — or a server match on the amount is fetched and then
// hidden by the local re-read (docs/local-search-matching.md).

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test(
    'an expense is found by its amount, the way the server renders it',
    () async {
      await db.expenseDao.upsert(
        ExpensesCompanion.insert(
          id: 'fuel',
          companyId: 'co',
          updatedAt: 1,
          payload: '{"public_notes":"Fuel"}',
          amount: const Value('120.5'),
        ),
      );
      await db.expenseDao.upsert(
        ExpensesCompanion.insert(
          id: 'other',
          companyId: 'co',
          updatedAt: 1,
          payload: '{}',
          amount: const Value('9'),
        ),
      );
      Future<List<String>> search(String s) async => [
        for (final r
            in await db.expenseDao
                .watchPage(companyId: 'co', offset: 0, limit: 50, search: s)
                .first)
          r.id,
      ];
      expect(await search('120'), ['fuel']);
      // MySQL renders decimal(20,6): 120.500000.
      expect(await search('120.50'), ['fuel']);
      expect(await search('121'), isEmpty);
    },
  );

  test('a recurring expense is found by its amount', () async {
    await db.recurringExpenseDao.upsert(
      RecurringExpensesCompanion.insert(
        id: 'rent',
        companyId: 'co',
        updatedAt: 1,
        payload: '{}',
        amount: const Value('1500'),
      ),
    );
    final rows = await db.recurringExpenseDao
        .watchPage(companyId: 'co', offset: 0, limit: 50, search: '1500')
        .first;
    expect([for (final r in rows) r.id], ['rent']);
  });
}
