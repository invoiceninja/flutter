import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

/// Where a store purchase stands, as the app acts on it.
enum StorePurchaseStatus { pending, purchased, restored, error, canceled }

/// A purchasable store product.
///
/// Built only by [StoreBilling.queryProducts]; the underlying SDK object rides
/// along privately so [StoreBilling.buyNonConsumable] can hand it back.
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  }) : _details = null;

  StoreProduct._(ProductDetails details)
    : id = details.id,
      title = details.title,
      description = details.description,
      price = details.price,
      _details = details;

  final String id;
  final String title;
  final String description;

  /// Localised, formatted by the store.
  final String price;

  final ProductDetails? _details;
}

/// The result of [StoreBilling.queryProducts].
class StoreProductQuery {
  const StoreProductQuery({required this.products, this.error});

  final List<StoreProduct> products;

  /// The store's error, if the query partly or wholly failed.
  final String? error;
}

/// A purchase update from [StoreBilling.purchaseStream].
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
  }) : _details = null;

  StorePurchase._(PurchaseDetails details)
    : productId = details.productID,
      status = _statusOf(details.status),
      error = details.error?.toString(),
      purchaseId = details.purchaseID,
      localVerificationData = details.verificationData.localVerificationData,
      pendingCompletePurchase = details.pendingCompletePurchase,
      isStoreKit1 = details is AppStorePurchaseDetails,
      storeKit1OriginalTransactionId = details is AppStorePurchaseDetails
          ? details
                .skPaymentTransaction
                .originalTransaction
                ?.transactionIdentifier
          : null,
      _details = details;

  final String productId;
  final StorePurchaseStatus status;
  final String? error;

  /// Google's `orderId`; Apple's per-transaction id.
  final String? purchaseId;

  /// Apple's `Transaction.jsonRepresentation` under StoreKit 2; Google's
  /// purchase JSON on Android.
  final String localVerificationData;

  final bool pendingCompletePurchase;

  /// True only if `enableStoreKit1()` is ever called — StoreKit 2 is the
  /// plugin default.
  final bool isStoreKit1;

  /// StoreKit 1's original transaction id, populated for restored
  /// transactions only.
  final String? storeKit1OriginalTransactionId;

  final PurchaseDetails? _details;

  static StorePurchaseStatus _statusOf(PurchaseStatus s) => switch (s) {
    PurchaseStatus.pending => StorePurchaseStatus.pending,
    PurchaseStatus.purchased => StorePurchaseStatus.purchased,
    PurchaseStatus.restored => StorePurchaseStatus.restored,
    PurchaseStatus.error => StorePurchaseStatus.error,
    PurchaseStatus.canceled => StorePurchaseStatus.canceled,
  };
}

/// App Store / Play in-app purchases, reduced to the calls the upgrade sheet
/// makes. The receipt handling lives in the app's `PurchaseService`.
class StoreBilling {
  final InAppPurchase _iap = InAppPurchase.instance;

  /// True only on store platforms with a reachable billing backend.
  Future<bool> isAvailable() => _iap.isAvailable();

  Stream<List<StorePurchase>> get purchaseStream => _iap.purchaseStream.map(
    (list) => [for (final p in list) StorePurchase._(p)],
  );

  Future<StoreProductQuery> queryProducts(Set<String> ids) async {
    final resp = await _iap.queryProductDetails(ids);
    return StoreProductQuery(
      products: [for (final d in resp.productDetails) StoreProduct._(d)],
      error: resp.error?.toString(),
    );
  }

  Future<void> buyNonConsumable(StoreProduct product) async {
    final details = product._details;
    if (details == null) {
      throw StateError('buyNonConsumable needs a product from queryProducts');
    }
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
  }

  Future<void> restorePurchases() => _iap.restorePurchases();

  Future<void> completePurchase(StorePurchase purchase) async {
    final details = purchase._details;
    if (details == null) {
      throw StateError('completePurchase needs a purchase from purchaseStream');
    }
    await _iap.completePurchase(details);
  }
}
