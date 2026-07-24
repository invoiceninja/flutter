import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/db/app_database.dart';
import 'package:admin/data/models/domain/company.dart';
import 'package:admin/data/repositories/tag_repository.dart';
import 'package:admin/data/services/tags_api.dart';
import 'package:admin/ui/core/list/search/filter_key.dart';
import 'package:admin/ui/core/list/search/tag_filter_key.dart';
import 'package:admin/ui/features/products/product_filter_keys.dart';
import 'package:admin/ui/features/products/stock_filter_key.dart';

/// The low-stock filter must only appear when the company tracks inventory —
/// otherwise the products list offers a filter dimension that can't be acted
/// on. Tags are always offered.
void main() {
  late AppDatabase db;
  late TagRepository tags;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tags = TagRepository(db: db, api: _StubTagsApi());
  });

  tearDown(() async {
    await db.close();
  });

  List<FilterKey> build({Company? company}) =>
      buildProductFilterKeys(tags: tags, companyId: 'co', company: company);

  void disposeKeys(List<FilterKey> keys) {
    for (final k in keys) {
      k.dispose();
    }
  }

  group('buildProductFilterKeys', () {
    test('omits the stock filter when inventory tracking is off', () {
      final keys = build(company: const Company(trackInventory: false));
      expect(keys.whereType<StockFilterKey>(), isEmpty);
      disposeKeys(keys);
    });

    test('includes the stock filter when inventory tracking is on', () {
      final keys = build(company: const Company(trackInventory: true));
      expect(keys.whereType<StockFilterKey>(), hasLength(1));
      disposeKeys(keys);
    });

    test('omits the stock filter when no company is supplied', () {
      final keys = build();
      expect(keys.whereType<StockFilterKey>(), isEmpty);
      disposeKeys(keys);
    });

    test('always offers a tag filter', () {
      final keys = build(company: const Company(trackInventory: false));
      expect(keys.whereType<TagFilterKey>(), hasLength(1));
      disposeKeys(keys);
    });
  });
}

/// The tag filter reads tags from the local DAO (never the API) in this test,
/// so the API is never exercised — throw if anything reaches it.
class _StubTagsApi implements TagsApi {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
