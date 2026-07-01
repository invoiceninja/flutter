import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin/data/models/domain/product.dart';
import 'package:admin/data/repositories/product_repository.dart';

/// Unit coverage for [stockFilterMatches] — the local low-stock predicate the
/// products list applies post-decode (the server has no stock filter). Mirrors
/// the backend `AdjustProductInventory` two-tier threshold check.
void main() {
  Product product({required int inStock, int threshold = 0}) =>
      emptyProductWithKey('p').copyWith(
        inStockQuantity: Decimal.fromInt(inStock),
        stockNotificationThreshold: Decimal.fromInt(threshold),
      );

  group('stockFilterMatches', () {
    test('none matches everything', () {
      expect(
        stockFilterMatches(
          product(inStock: 7),
          StockFilter.none,
          companyThreshold: 0,
        ),
        isTrue,
      );
      expect(
        stockFilterMatches(
          product(inStock: -3),
          StockFilter.none,
          companyThreshold: 5,
        ),
        isTrue,
      );
    });

    test('out = at or below zero (includes negative over-allocation)', () {
      expect(
        stockFilterMatches(
          product(inStock: 0),
          StockFilter.out,
          companyThreshold: 5,
        ),
        isTrue,
      );
      expect(
        stockFilterMatches(
          product(inStock: -2),
          StockFilter.out,
          companyThreshold: 5,
        ),
        isTrue,
      );
      expect(
        stockFilterMatches(
          product(inStock: 1),
          StockFilter.out,
          companyThreshold: 5,
        ),
        isFalse,
      );
    });

    test('low uses the product threshold when it is set (> 0)', () {
      expect(
        stockFilterMatches(
          product(inStock: 4, threshold: 5),
          StockFilter.low,
          companyThreshold: 0,
        ),
        isTrue, // 4 <= 5
      );
      expect(
        stockFilterMatches(
          product(inStock: 6, threshold: 5),
          StockFilter.low,
          companyThreshold: 0,
        ),
        isFalse, // 6 > 5
      );
    });

    test('low falls back to the company threshold when the product is 0', () {
      expect(
        stockFilterMatches(
          product(inStock: 4, threshold: 0),
          StockFilter.low,
          companyThreshold: 10,
        ),
        isTrue, // 4 <= 10 (company fallback)
      );
      expect(
        stockFilterMatches(
          product(inStock: 12, threshold: 0),
          StockFilter.low,
          companyThreshold: 10,
        ),
        isFalse, // 12 > 10
      );
    });

    test('low includes out-of-stock (low ⊇ out)', () {
      expect(
        stockFilterMatches(
          product(inStock: 0, threshold: 5),
          StockFilter.low,
          companyThreshold: 0,
        ),
        isTrue,
      );
      expect(
        stockFilterMatches(
          product(inStock: -1, threshold: 0),
          StockFilter.low,
          companyThreshold: 3,
        ),
        isTrue,
      );
    });

    test('with both thresholds 0, low only catches out-of-stock', () {
      expect(
        stockFilterMatches(
          product(inStock: 5, threshold: 0),
          StockFilter.low,
          companyThreshold: 0,
        ),
        isFalse, // in stock, no threshold to be "low" against
      );
      expect(
        stockFilterMatches(
          product(inStock: 0, threshold: 0),
          StockFilter.low,
          companyThreshold: 0,
        ),
        isTrue, // 0 <= 0
      );
    });
  });
}
