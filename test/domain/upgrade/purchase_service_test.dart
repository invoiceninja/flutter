import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:store_services/store_services.dart';

import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_client.dart';
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

/// The store SDK, as `PurchaseService` sees it — `implements`, so the real
/// `InAppPurchase.instance` is never touched.
class _FakeBilling implements StoreBilling {
  final purchases = StreamController<List<StorePurchase>>();
  final completed = <StorePurchase>[];
  final bought = <StoreProduct>[];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Stream<List<StorePurchase>> get purchaseStream => purchases.stream;

  @override
  Future<StoreProductQuery> queryProducts(Set<String> ids) async =>
      const StoreProductQuery(
        products: [
          StoreProduct(
            id: 'pro_plan',
            title: 'Pro',
            description: 'Pro plan',
            price: r'$10',
          ),
        ],
      );

  @override
  Future<void> buyNonConsumable(StoreProduct product) async =>
      bought.add(product);

  @override
  Future<void> restorePurchases() async {}

  @override
  Future<void> completePurchase(StorePurchase purchase) async =>
      completed.add(purchase);
}

class _FakeApi implements ApiClient {
  final posts = <(String, Map<String, dynamic>?)>[];

  @override
  Future<dynamic> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool readOnly = false,
    bool requiresPassword = false,
  }) async {
    posts.add((path, body));
    return null;
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _FakeAuth implements AuthRepository {
  int refreshes = 0;

  @override
  final ValueListenable<AuthSession?> session = ValueNotifier<AuthSession?>(
    const AuthSession(
      baseUrl: 'https://example.test',
      isHosted: true,
      accountId: 'acct',
      companies: [],
      currentCompanyId: 'co',
      userId: 'me',
    ),
  );

  @override
  Future<void> refresh({bool fullSync = false}) async => refreshes++;

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('PurchaseService over StoreBilling', () {
    late _FakeBilling billing;
    late _FakeApi api;
    late _FakeAuth auth;
    late PurchaseService svc;

    setUp(() async {
      billing = _FakeBilling();
      api = _FakeApi();
      auth = _FakeAuth();
      svc = PurchaseService(apiClient: api, auth: auth, billing: billing);
      await svc.init();
    });

    tearDown(() => svc.dispose());

    Future<void> emit(StorePurchase p) async {
      billing.purchases.add([p]);
      // Let the stream callback and its awaits run.
      await pumpEventQueue();
    }

    test('lists the store products', () {
      expect(svc.products.value.map((p) => p.id), ['pro_plan']);
    });

    test('delivers the StoreKit 2 original id, refreshes, completes', () async {
      final p = StorePurchase(
        productId: 'enterprise-plan',
        status: StorePurchaseStatus.purchased,
        purchaseId: '2000000999999',
        localVerificationData: _appleTransactionJson(),
        pendingCompletePurchase: true,
      );
      await emit(p);

      expect(api.posts, hasLength(1));
      final (path, body) = api.posts.single;
      expect(path, '/api/admin/subscription');
      expect(body, {
        'inapp_transaction_id': '2000000111111',
        'key': 'acct',
        'plan': 'enterprise_plan',
      });
      expect(auth.refreshes, 1);
      expect(billing.completed, [p]);
      expect(svc.busy.value, isFalse);
    });

    test('Android falls back to the purchase id (orderId)', () async {
      await emit(
        StorePurchase(
          productId: 'pro_plan',
          status: StorePurchaseStatus.restored,
          purchaseId: 'GPA.3123-4567-8901-23456',
          localVerificationData: jsonEncode({'orderId': 'x'}),
        ),
      );

      expect(
        api.posts.single.$2?['inapp_transaction_id'],
        'GPA.3123-4567-8901-23456',
      );
    });

    test('StoreKit 1 uses the original transaction when present', () async {
      await emit(
        const StorePurchase(
          productId: 'pro_plan',
          status: StorePurchaseStatus.restored,
          purchaseId: 'per-transaction',
          isStoreKit1: true,
          storeKit1OriginalTransactionId: 'original',
        ),
      );

      expect(api.posts.single.$2?['inapp_transaction_id'], 'original');
    });

    test('skips delivery with no transaction id, but completes', () async {
      const p = StorePurchase(
        productId: 'pro_plan',
        status: StorePurchaseStatus.purchased,
        pendingCompletePurchase: true,
      );
      await emit(p);

      expect(api.posts, isEmpty);
      expect(auth.refreshes, 0);
      expect(billing.completed, [p]);
    });

    test('an error clears busy and delivers nothing', () async {
      await svc.buy(svc.products.value.single);
      expect(svc.busy.value, isTrue);

      await emit(
        const StorePurchase(
          productId: 'pro_plan',
          status: StorePurchaseStatus.error,
          error: 'user cancelled',
        ),
      );

      expect(svc.busy.value, isFalse);
      expect(api.posts, isEmpty);
      expect(billing.bought.single.id, 'pro_plan');
    });
  });

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
