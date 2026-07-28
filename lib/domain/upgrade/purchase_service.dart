import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:logging/logging.dart';

import 'package:admin/data/models/api/json_coercion.dart';
import 'package:admin/data/repositories/auth_repository.dart';
import 'package:admin/data/services/api_client.dart';

/// App Store / Play product identifiers for the hosted plans. Mirrors
/// admin-portal's `kProductPlans` (legacy `lib/constants.dart`). The server
/// maps the productID back to a plan slug (`-` → `_`).
const String kProductProPlanMonth = 'pro_plan';
const String kProductProPlanYear = 'pro_plan_annual';
const String kProductEnterprisePlanMonth = 'enterprise_plan';
const String kProductEnterprisePlanMonth5 = 'enterprise_plan_5';
const String kProductEnterprisePlanMonth10 = 'enterprise_plan_10';
const String kProductEnterprisePlanMonth20 = 'enterprise_plan_20';
const String kProductEnterprisePlanYear = 'enterprise_plan_annual';
const String kProductEnterprisePlanYear5 = 'enterprise_plan_annual_5';
const String kProductEnterprisePlanYear10 = 'enterprise_plan_annual_10';
const String kProductEnterprisePlanYear20 = 'enterprise_plan_annual_20';

const Set<String> kProductPlans = {
  kProductProPlanMonth,
  kProductProPlanYear,
  kProductEnterprisePlanMonth,
  kProductEnterprisePlanMonth5,
  kProductEnterprisePlanMonth10,
  kProductEnterprisePlanMonth20,
  kProductEnterprisePlanYear,
  kProductEnterprisePlanYear5,
  kProductEnterprisePlanYear10,
  kProductEnterprisePlanYear20,
};

/// Drives the App Store / Play in-app-purchase flow for hosted plan
/// upgrades. Lifecycle is owned by the upgrade sheet (created on open,
/// disposed on close) so we don't hold a global purchase-stream subscription.
///
/// Port of admin-portal's `UpgradeDialog` purchase plumbing: query products,
/// `buyNonConsumable`, listen to `purchaseStream`, POST the receipt to
/// `/api/admin/subscription`, then `auth.refresh()` so the new plan lands in
/// the session (and every `PlanGateBanner` auto-clears).
///
/// NOTE: requires App Store Connect / Play Console product configuration
/// (the `kProductPlans` IDs) and sandbox testing — that store-side setup is
/// outside the Flutter codebase and cannot be exercised in CI.
class PurchaseService {
  PurchaseService({required ApiClient apiClient, required AuthRepository auth})
    : _apiClient = apiClient,
      _auth = auth;

  final ApiClient _apiClient;
  final AuthRepository _auth;
  final InAppPurchase _iap = InAppPurchase.instance;
  final _log = Logger('PurchaseService');

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final ValueNotifier<List<ProductDetails>> products = ValueNotifier(const []);
  final ValueNotifier<bool> busy = ValueNotifier(false);

  /// True only on store platforms with a reachable billing backend.
  Future<bool> get isAvailable => _iap.isAvailable();

  Future<void> init() async {
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => _log.warning('purchaseStream error: $e'),
    );
    await _queryProducts();
  }

  Future<void> _queryProducts() async {
    busy.value = true;
    try {
      final resp = await _iap.queryProductDetails(kProductPlans);
      if (resp.error != null) {
        _log.warning('queryProductDetails: ${resp.error}');
      }
      products.value = resp.productDetails;
    } finally {
      busy.value = false;
    }
  }

  Future<void> buy(ProductDetails product) async {
    busy.value = true;
    final param = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() => _iap.restorePurchases();

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.status == PurchaseStatus.pending) {
        busy.value = true;
        continue;
      }
      if (p.status == PurchaseStatus.error) {
        busy.value = false;
        _log.warning('purchase error: ${p.error}');
      } else if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        await _deliver(p);
      }
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  /// POST the receipt to the hosted admin endpoint, then refresh the session
  /// so the upgraded plan (and the cleared gates) take effect.
  Future<void> _deliver(PurchaseDetails p) async {
    busy.value = true;
    try {
      final purchaseId = _inAppTransactionId(p);
      if (purchaseId == null || purchaseId.isEmpty) {
        // The server requires a non-empty string; posting null just 422s.
        _log.warning('no transaction id for ${p.productID} — skipping deliver');
        return;
      }
      await _apiClient.postJson(
        '/api/admin/subscription',
        body: {
          'inapp_transaction_id': purchaseId,
          'key': _auth.session.value?.accountId ?? '',
          'plan': p.productID.replaceAll('-', '_'),
        },
      );
      // Full session snapshot — flips the plan slug everywhere.
      await _auth.refresh();
    } catch (e) {
      _log.warning('subscription deliver failed: $e');
    } finally {
      busy.value = false;
    }
  }

  /// The value the hosted endpoint stores as `accounts.inapp_transaction_id`.
  ///
  /// Apple keys its renewal / cancellation / refund notifications on the
  /// subscription's **original** transaction id and the server matches that
  /// exactly, so storing a per-transaction id silently orphans the account —
  /// later notifications find no match and the plan stops being extended. For
  /// an initial purchase the two are identical; they diverge on restore and on
  /// renewals, which both reach here.
  ///
  /// Google is the opposite: its notifications resolve to the `orderId` that
  /// already arrives as [PurchaseDetails.purchaseID], so Android falls through
  /// unchanged.
  String? _inAppTransactionId(PurchaseDetails p) {
    if (p is AppStorePurchaseDetails) {
      // StoreKit 1 — only reached if `enableStoreKit1()` is ever called.
      // `originalTransaction` is populated for restored transactions only.
      final original = p.skPaymentTransaction.originalTransaction;
      if (original != null) return original.transactionIdentifier;
    } else {
      // StoreKit 2 (the plugin default) drops `originalId` when it builds
      // SK2PurchaseDetails, but Apple's own transaction JSON is passed through
      // as `localVerificationData` and still carries it. Google's equivalent
      // JSON has no such key, so Android returns null here and falls back to
      // `purchaseID`.
      final original = appleOriginalTransactionId(
        p.verificationData.localVerificationData,
      );
      if (original != null) return original;
    }
    return p.purchaseID;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    products.dispose();
    busy.dispose();
  }
}

/// Pulls Apple's `originalTransactionId` out of a StoreKit 2 transaction's
/// `localVerificationData` — Apple's `Transaction.jsonRepresentation`.
///
/// Returns `null` when the payload is empty, isn't a JSON object, or carries no
/// usable `originalTransactionId`, so callers can fall back to `purchaseID`.
/// Never throws: this runs inside the purchase-stream callback, where an
/// exception would take down delivery of a paid purchase.
@visibleForTesting
String? appleOriginalTransactionId(String localVerificationData) {
  if (localVerificationData.isEmpty) return null;
  try {
    final decoded = jsonDecode(localVerificationData);
    if (decoded is! Map<String, dynamic>) return null;
    // Apple documents the field as a string, but encodes some numeric ids as
    // JSON numbers — same coercion hazard as the invoice line-item payloads.
    final id = jsonScalarToString(decoded['originalTransactionId']);
    return (id == null || id.isEmpty) ? null : id;
  } catch (_) {
    return null;
  }
}
