import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:admin/domain/upgrade/purchase_service.dart';

/// A trimmed but realistic `Transaction.jsonRepresentation` payload — the
/// StoreKit 2 value the plugin surfaces as `localVerificationData`.
String _appleTransactionJson({
  Object? originalTransactionId = '2000000111111',
}) {
  return jsonEncode({
    'transactionId': '2000000999999',
    if (originalTransactionId != null)
      'originalTransactionId': originalTransactionId,
    'bundleId': 'com.invoiceninja.admin',
    'productId': 'pro_plan',
    'purchaseDate': 1751000000000,
    'type': 'Auto-Renewable Subscription',
    'environment': 'Production',
  });
}

void main() {
  group('appleOriginalTransactionId', () {
    test('reads the original id, not the per-transaction id', () {
      expect(
        appleOriginalTransactionId(_appleTransactionJson()),
        '2000000111111',
      );
    });

    test('coerces a numeric original id to a string', () {
      expect(
        appleOriginalTransactionId(
          _appleTransactionJson(originalTransactionId: 2000000111111),
        ),
        '2000000111111',
      );
    });

    test('returns null when the field is absent', () {
      expect(
        appleOriginalTransactionId(
          _appleTransactionJson(originalTransactionId: null),
        ),
        isNull,
      );
    });

    test('returns null for an empty original id', () {
      expect(
        appleOriginalTransactionId(
          _appleTransactionJson(originalTransactionId: ''),
        ),
        isNull,
      );
    });

    test('returns null for an empty payload', () {
      expect(appleOriginalTransactionId(''), isNull);
    });

    test('returns null for malformed JSON instead of throwing', () {
      expect(appleOriginalTransactionId('{not json'), isNull);
    });

    test('returns null when the payload is not a JSON object', () {
      expect(appleOriginalTransactionId('[1,2,3]'), isNull);
      expect(appleOriginalTransactionId('"a string"'), isNull);
    });

    test(
      "returns null for Google's purchase JSON, so Android keeps orderId",
      () {
        // GooglePlayPurchaseDetails passes `purchase.originalJson` through as
        // localVerificationData; it has no originalTransactionId key.
        final googleJson = jsonEncode({
          'orderId': 'GPA.3123-4567-8901-23456',
          'packageName': 'com.invoiceninja.admin',
          'productId': 'pro_plan',
          'purchaseTime': 1751000000000,
          'purchaseState': 0,
          'purchaseToken': 'abcdef.AO-J1Oy...',
          'acknowledged': false,
        });

        expect(appleOriginalTransactionId(googleJson), isNull);
      },
    );
  });
}
