// Product search matches every word, in any order, across fields — the user
// feedback was that `s22 120hz` could not find
// "Samsung Galaxy S22 5G OLED 120Hz Screen (TCGJ)".

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';

void main() {
  late AppDatabase db;
  const co = 'co';

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> product(
    String id,
    String key, {
    String notes = '',
    String custom1 = '',
  }) => db.productDao.upsertAll([
    ProductsCompanion.insert(
      id: id,
      companyId: co,
      productKey: key,
      notes: notes,
      price: '0',
      cost: '0',
      quantity: '1',
      updatedAt: 1,
      payload: '{}',
      customValue1: Value(custom1),
    ),
  ]);

  Future<List<String>> search(String s, {bool rankSearch = false}) async {
    final rows = await db.productDao
        .watchPage(
          companyId: co,
          offset: 0,
          limit: 50,
          search: s,
          rankSearch: rankSearch,
        )
        .first;
    return rows.map((r) => r.id).toList();
  }

  setUp(() async {
    await product(
      's22',
      'Samsung Galaxy S22 5G OLED 120Hz Screen (TCGJ)',
      notes: 'Replacement display',
    );
    await product('s22-split', 'S22-SCR', notes: 'OLED 120Hz panel');
    await product('s23', 'Samsung Galaxy S23 OLED 120Hz Screen');
    await product('iphone', 'iPhone 13 Screen', custom1: 'Grade A');
  });

  test('the feedback search finds the product', () async {
    expect(await search('s22 120hz'), containsAll(['s22', 's22-split']));
    expect(await search('s22 120hz'), isNot(contains('s23')));
  });

  test('word order does not matter', () async {
    expect(
      (await search('120HZ s22'))..sort(),
      (await search('s22 120hz'))..sort(),
    );
  });

  test('different words may match different fields', () async {
    expect(await search('s22-scr panel'), ['s22-split']);
    expect(await search('iphone grade'), ['iphone']);
  });

  test('one word matching nothing excludes the row', () async {
    expect(await search('s22 iphone'), isEmpty);
  });

  test('a one-word search is unchanged', () async {
    expect((await search('oled'))..sort(), ['s22', 's22-split', 's23']);
    expect(await search('display'), ['s22']);
  });

  test('ranked: rows whose key holds every word come first', () async {
    // By key alone `S22-SCR` sorts after `Samsung…` — but only the Samsung
    // key holds both words; the S22-SCR row matches 120hz through its notes.
    final ranked = await search('s22 120hz', rankSearch: true);
    expect(ranked.first, 's22');
    final plainKeys = await search('screen');
    expect(await search('screen', rankSearch: true), plainKeys);
  });

  // A whitespace-only search has no words. It once threw sorting the const
  // empty list `searchWords` returned; it now matches every row.
  test(
    'a whitespace-only search matches everything, and never throws',
    () async {
      expect(await search('   '), hasLength(4));
      expect(await search('   ', rankSearch: true), hasLength(4));
    },
  );
}
