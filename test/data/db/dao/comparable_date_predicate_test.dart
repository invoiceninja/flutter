import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

/// The single-date comparator mirror (`>`, `>=`, `<`, `<=`, `=`) on the billing
/// date columns.
///
/// The trap these pin down: those columns are `TEXT ... withDefault('')`, and
/// in SQLite `'' < '2026-08-01'` is TRUE — so a naive `<` / `<=` sweeps in
/// every row that has NO date at all, which the server (comparing a real date
/// column, where NULL comparisons are false) excludes. Due dates are optional,
/// so that is not a rare row.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> insertInvoice({required String id, required String dueDate}) =>
      db
          .into(db.invoices)
          .insert(
            InvoicesCompanion.insert(
              id: id,
              companyId: 'co',
              number: Value(id),
              clientId: const Value('c1'),
              statusId: const Value('2'),
              amount: const Value('100'),
              balance: const Value('100'),
              date: const Value('2026-01-01'),
              dueDate: Value(dueDate),
              payload: jsonEncode({'id': id}),
              updatedAt: 1700000000,
            ),
          );

  Future<List<String>> idsWhere({String? op, String? value}) async {
    final rows = await db.invoiceDao
        .watchPage(
          companyId: 'co',
          offset: 0,
          limit: 50,
          dueDateOp: op,
          dueDateValue: value,
        )
        .first;
    return rows.map((r) => r.id).toList()..sort();
  }

  setUp(() async {
    await insertInvoice(id: 'a', dueDate: '2026-07-01');
    await insertInvoice(id: 'b', dueDate: '2026-08-01');
    await insertInvoice(id: 'c', dueDate: '2026-09-01');
    // The row the naive predicate wrongly swept in.
    await insertInvoice(id: 'blank', dueDate: '');
  });

  test('no comparator → every row, blank date included', () async {
    expect(await idsWhere(), ['a', 'b', 'blank', 'c']);
  });

  test('lte / lt exclude the blank-date row', () async {
    expect(await idsWhere(op: 'lte', value: '2026-08-01'), ['a', 'b']);
    expect(await idsWhere(op: 'lt', value: '2026-08-01'), ['a']);
  });

  test('gte / gt exclude it too', () async {
    expect(await idsWhere(op: 'gte', value: '2026-08-01'), ['b', 'c']);
    expect(await idsWhere(op: 'gt', value: '2026-08-01'), ['c']);
  });

  test('eq matches exactly one, never the blank', () async {
    expect(await idsWhere(op: 'eq', value: '2026-08-01'), ['b']);
    expect(await idsWhere(op: 'eq', value: ''), ['a', 'b', 'blank', 'c']);
  });

  test('an omitted operator defaults to gte, matching '
      'DateColumnFilterKey.defaultOp', () async {
    expect(await idsWhere(value: '2026-08-01'), ['b', 'c']);
  });
}
