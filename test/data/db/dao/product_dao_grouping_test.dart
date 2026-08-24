// Group-by ordering in `ProductDao.watchPage` (issue #56).
//
// Grouping leads the ORDER BY so a group's rows are contiguous and the list
// screen can print a header on each value change. Two details are easy to get
// wrong and both look "almost right" on a hand-picked fixture:
//   * blank values must sort LAST (Uncategorized at the bottom), and
//   * the label sort must be case-insensitive, because SQLite's default TEXT
//     collation is BINARY and would put `Zebra` ahead of `apple`.

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/product_dao.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  const co = 'co_1';

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  Future<void> product(String id, String custom1) => db.productDao.upsertAll([
    ProductsCompanion.insert(
      id: id,
      companyId: co,
      productKey: id,
      notes: '',
      price: '0',
      cost: '0',
      quantity: '1',
      updatedAt: 1,
      payload: '{}',
      customValue1: Value(custom1),
    ),
  ]);

  Future<List<String>> keys({String? groupField}) async {
    final rows = await db.productDao
        .watchPage(companyId: co, offset: 0, limit: 50, groupField: groupField)
        .first;
    return rows.map((r) => r.productKey).toList();
  }

  test('ungrouped ordering is unchanged', () async {
    await product('b', 'Zebra');
    await product('a', 'apple');
    expect(await keys(), ['a', 'b']);
  });

  test('groups are contiguous, case-insensitive, blanks last', () async {
    await product('z1', 'Zebra');
    await product('a1', 'apple');
    await product('n1', '');
    await product('a2', 'apple');
    await product('z2', 'Zebra');

    expect(await keys(groupField: ProductFieldIds.custom1), [
      // apple before Zebra — BINARY collation would have inverted these.
      'a1', 'a2',
      'z1', 'z2',
      // Uncategorized at the bottom, not the top.
      'n1',
    ]);
  });

  test('the chosen sort still applies within a group', () async {
    await product('a_z', 'apple');
    await product('a_a', 'apple');
    await product('b_z', 'beta');
    await product('b_a', 'beta');

    expect(await keys(groupField: ProductFieldIds.custom1), [
      'a_a',
      'a_z',
      'b_a',
      'b_z',
    ]);
  });

  test('values differing only in case stay contiguous', () async {
    // The screen groups on the RAW value but the ORDER BY lowercases, so
    // without an exact-case tiebreak `Retail` and `retail` tie and the sort
    // interleaves them — one header per run, and collapsing one hides
    // non-adjacent rows. Free-text custom fields make this reachable.
    await product('a', 'Retail');
    await product('b', 'retail');
    await product('c', 'Retail');

    expect(await keys(groupField: ProductFieldIds.custom1), [
      'a', 'c', // both `Retail`
      'b', // then `retail`
    ]);
  });

  test('an unknown or payload-only group id degrades to ungrouped', () async {
    await product('b', 'Zebra');
    await product('a', 'apple');
    // `tags` lives in the payload and is regrouped in Dart by the VM; a stale
    // id from persisted list state can also land here. Neither may throw the
    // way `_sortExpression` does for an unknown sort column.
    expect(await keys(groupField: 'tags'), ['a', 'b']);
    expect(await keys(groupField: 'not_a_column'), ['a', 'b']);
  });

  test(
    'watchDistinctCustomValues returns ordered unique non-empty values',
    () async {
      await product('a', 'Software');
      await product('b', 'Hardware');
      await product('c', 'Hardware');
      await product('d', '');

      expect(
        await db.productDao
            .watchDistinctCustomValues(companyId: co, columnIndex: 1)
            .first,
        ['Hardware', 'Software'],
      );
    },
  );

  test('watchDistinctCustomValues orders case-insensitively', () async {
    // BINARY collation would list `Zebra` before `apple`, which contradicts
    // the grouped list's own ordering.
    await product('a', 'Zebra');
    await product('b', 'apple');

    expect(
      await db.productDao
          .watchDistinctCustomValues(companyId: co, columnIndex: 1)
          .first,
      ['apple', 'Zebra'],
    );
  });
}
