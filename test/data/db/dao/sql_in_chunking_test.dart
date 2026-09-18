// SQLite caps host parameters at SQLITE_MAX_VARIABLE_NUMBER, and a statement
// past it fails to even prepare. Nothing hit that while the only callers of the
// `WHERE id IN (...)` helpers were page-sized (<= 50 rows), but the `/refresh`
// delta (invoiceninja/flutter#170) hands them every row the server changed
// since the last sync — unbounded after a long absence on a busy account.
//
// Measured before `chunkIdsForSqlIn` existed: 5 000 ids fine, 60 000 threw
// `SqliteException(1): while preparing statement, too many SQL variables`.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/db/dao/base_entity_dao.dart';
import 'package:admin/data/models/api/product_api_model.dart';
import 'package:admin/data/repositories/product_repository.dart';
import 'package:admin/data/services/products_api.dart';

class _FakeProductsApi implements ProductsApi {
  @override
  Object? noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  group('chunkIdsForSqlIn', () {
    test('slices into runs of at most `size`, losing nothing', () {
      final ids = [for (var i = 0; i < 1201; i++) 'id_$i'];
      final chunks = chunkIdsForSqlIn(ids, size: 500).toList();
      expect(chunks.map((c) => c.length), [500, 500, 201]);
      expect(chunks.expand((c) => c), ids);
    });

    test('an exact multiple yields no trailing empty chunk', () {
      final ids = [for (var i = 0; i < 1000; i++) 'id_$i'];
      expect(chunkIdsForSqlIn(ids, size: 500).map((c) => c.length), [500, 500]);
    });

    test('an empty list yields nothing', () {
      expect(chunkIdsForSqlIn(const []), isEmpty);
    });
  });

  test('a delta far past the SQLite variable limit applies', () async {
    // Exercises both chunked helpers at once: `updatedAtAmong` (the staleness
    // guard) and `_dirtyIdsAmong` (inside `upsertAllPreservingDirty`).
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = ProductRepository(db: db, api: _FakeProductsApi());

    await repo.applyRefreshDelta(
      companyId: 'co',
      bundle: [
        for (var i = 0; i < 40000; i++)
          ProductApi(id: 'p_$i', productKey: 'SKU-$i', updatedAt: 100 + i),
      ],
    );

    expect(await repo.watch(companyId: 'co', id: 'p_39999').first, isNotNull);

    // And again, so the second pass reads 40 000 stored timestamps back.
    await repo.applyRefreshDelta(
      companyId: 'co',
      bundle: [
        for (var i = 0; i < 40000; i++)
          ProductApi(id: 'p_$i', productKey: 'SKU2-$i', updatedAt: 200000 + i),
      ],
    );
    final row = await repo.watch(companyId: 'co', id: 'p_0').first;
    expect(row!.productKey, 'SKU2-0');
  });
}
