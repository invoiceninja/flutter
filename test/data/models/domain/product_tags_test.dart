import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/api/product_api_model.dart';
import 'package:admin/data/models/domain/product.dart';

void main() {
  group('Product tags wire round-trip', () {
    test('parses server [{id,name,color}] objects into tagIds', () {
      final api = ProductApi.fromJson({
        'id': 'p1',
        'product_key': 'Widget',
        'tags': [
          {'id': 't1', 'name': 'Featured', 'color': '#ff0000'},
          {'id': 't2', 'name': 'Sale', 'color': null},
        ],
      });
      expect(Product.fromApi(api).tagIds, ['t1', 't2']);
    });

    test('parses bare ["id"] strings (the payload round-trip form)', () {
      final api = ProductApi.fromJson({
        'id': 'p1',
        'product_key': 'Widget',
        'tags': ['t1', 't2'],
      });
      expect(Product.fromApi(api).tagIds, ['t1', 't2']);
    });

    test('drops empty ids', () {
      final api = ProductApi.fromJson({
        'id': 'p1',
        'product_key': 'Widget',
        'tags': [
          {'id': '', 'name': 'Ghost'},
          {'id': 't2', 'name': 'Sale'},
        ],
      });
      expect(Product.fromApi(api).tagIds, ['t2']);
    });

    test('toApiJson emits tags as the bare id list (full-set sync)', () {
      final api = ProductApi.fromJson({
        'id': 'p1',
        'product_key': 'Widget',
        'tags': [
          {'id': 't1', 'name': 'Featured', 'color': '#ff0000'},
        ],
      });
      expect(Product.fromApi(api).toApiJson()['tags'], ['t1']);
    });

    test('empty tags round-trips to an empty list', () {
      final api = ProductApi.fromJson({'id': 'p1', 'product_key': 'W'});
      final p = Product.fromApi(api);
      expect(p.tagIds, isEmpty);
      expect(p.toApiJson()['tags'], isEmpty);
    });
  });
}
