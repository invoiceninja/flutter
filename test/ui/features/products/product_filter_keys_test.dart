import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/company.dart';
import 'package:admin/ui/features/products/product_filter_keys.dart';
import 'package:admin/ui/features/products/stock_filter_key.dart';

/// The low-stock filter must only appear when the company tracks inventory —
/// otherwise the products list offers a filter dimension that can't be acted on.
void main() {
  group('buildProductFilterKeys', () {
    test('omits the stock filter when inventory tracking is off', () {
      final keys = buildProductFilterKeys(
        company: const Company(trackInventory: false),
      );
      expect(keys.whereType<StockFilterKey>(), isEmpty);
    });

    test('includes the stock filter when inventory tracking is on', () {
      final keys = buildProductFilterKeys(
        company: const Company(trackInventory: true),
      );
      expect(keys.whereType<StockFilterKey>(), hasLength(1));
    });

    test('omits the stock filter when no company is supplied', () {
      expect(buildProductFilterKeys().whereType<StockFilterKey>(), isEmpty);
    });
  });
}
