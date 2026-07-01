import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/product.dart';
import 'package:admin/ui/features/products/widgets/inventory_scope.dart';

/// Unit coverage for [InventoryScope.statusFor] — the highlight cascade behind
/// the products list's low/out tint. `statusFor` is a pure method, so no widget
/// tree is needed.
void main() {
  Product product({required int inStock, int threshold = 0}) =>
      emptyProductWithKey('p').copyWith(
        inStockQuantity: Decimal.fromInt(inStock),
        stockNotificationThreshold: Decimal.fromInt(threshold),
      );

  InventoryScope scope({required bool track, int threshold = 0}) =>
      InventoryScope(
        trackInventory: track,
        threshold: threshold,
        child: const SizedBox(),
      );

  group('InventoryScope.statusFor', () {
    test('ok when inventory tracking is off (no highlight)', () {
      final s = scope(track: false, threshold: 10);
      expect(s.statusFor(product(inStock: 0)), StockStatus.ok);
      expect(s.statusFor(product(inStock: -5)), StockStatus.ok);
    });

    test('out at or below zero', () {
      final s = scope(track: true, threshold: 5);
      expect(s.statusFor(product(inStock: 0)), StockStatus.out);
      expect(s.statusFor(product(inStock: -2)), StockStatus.out);
    });

    test('low at/below the product threshold, distinct from out', () {
      final s = scope(track: true, threshold: 0);
      expect(s.statusFor(product(inStock: 4, threshold: 5)), StockStatus.low);
      expect(s.statusFor(product(inStock: 6, threshold: 5)), StockStatus.ok);
      // In stock but at the product threshold → low (amber), not out (red).
      expect(s.statusFor(product(inStock: 5, threshold: 5)), StockStatus.low);
    });

    test('low falls back to the company threshold when the product is 0', () {
      final s = scope(track: true, threshold: 10);
      expect(s.statusFor(product(inStock: 4)), StockStatus.low);
      expect(s.statusFor(product(inStock: 12)), StockStatus.ok);
    });

    test('with both thresholds 0, only out-of-stock is flagged', () {
      final s = scope(track: true, threshold: 0);
      expect(s.statusFor(product(inStock: 5)), StockStatus.ok);
      expect(s.statusFor(product(inStock: 0)), StockStatus.out);
    });
  });
}
