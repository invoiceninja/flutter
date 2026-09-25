/// FOSS stub: store billing needs the Play Billing library, which F-Droid
/// forbids.
///
/// [StoreBilling.isAvailable] is always false, so every upgrade surface falls
/// back to the web portal (`showUpgradeSheet`) and nothing else here is ever
/// reached. The value types match packages/store_services exactly.
enum StorePurchaseStatus { pending, purchased, restored, error, canceled }

class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });

  final String id;
  final String title;
  final String description;
  final String price;
}

class StoreProductQuery {
  const StoreProductQuery({required this.products, this.error});

  final List<StoreProduct> products;
  final String? error;
}

class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.status,
    this.error,
    this.purchaseId,
    this.localVerificationData = '',
    this.pendingCompletePurchase = false,
    this.isStoreKit1 = false,
    this.storeKit1OriginalTransactionId,
  });

  final String productId;
  final StorePurchaseStatus status;
  final String? error;
  final String? purchaseId;
  final String localVerificationData;
  final bool pendingCompletePurchase;
  final bool isStoreKit1;
  final String? storeKit1OriginalTransactionId;
}

class StoreBilling {
  Future<bool> isAvailable() async => false;

  Stream<List<StorePurchase>> get purchaseStream => const Stream.empty();

  Future<StoreProductQuery> queryProducts(Set<String> ids) async =>
      const StoreProductQuery(products: []);

  Future<void> buyNonConsumable(StoreProduct product) async {}

  Future<void> restorePurchases() async {}

  Future<void> completePurchase(StorePurchase purchase) async {}
}
