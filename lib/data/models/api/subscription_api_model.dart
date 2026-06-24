import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:admin/data/models/api/json_coercion.dart';

part 'subscription_api_model.freezed.dart';
part 'subscription_api_model.g.dart';

/// Raw JSON shape of a Subscription ("Payment Link") as returned by
/// `/api/v1/subscriptions` and bundled onto each `data[N].company` as
/// `subscriptions` in `/refresh?first_load=true`.
///
/// Every wire field is declared explicitly so freezed doesn't drop unknown
/// keys on round-trip — even fields the UI doesn't edit (`purchase_page`,
/// `plan_map`, `currency_id`, `promo_price`) flow through cleanly. Numeric
/// money values (`price`, `promo_discount`, `promo_price`) ride as `Object`
/// so the server's "string OR number" wire shape doesn't fight json_serializable;
/// the domain model parses to `Decimal`.
@freezed
abstract class SubscriptionApi with _$SubscriptionApi {
  const factory SubscriptionApi({
    @Default('') String id,
    @JsonKey(name: 'user_id') @Default('') String userId,
    @JsonKey(name: 'assigned_user_id') @Default('') String assignedUserId,
    @JsonKey(name: 'company_id') @Default('') String companyId,
    @Default('') String name,
    // num-or-string on the wire. Domain model normalizes to Decimal.
    @Default('0') Object price,
    @JsonKey(name: 'currency_id') @Default('') String currencyId,
    @JsonKey(name: 'frequency_id') @Default('5') String frequencyId,
    @JsonKey(name: 'product_ids') @Default('') String productIds,
    @JsonKey(name: 'recurring_product_ids')
    @Default('')
    String recurringProductIds,
    @JsonKey(name: 'optional_product_ids')
    @Default('')
    String optionalProductIds,
    @JsonKey(name: 'optional_recurring_product_ids')
    @Default('')
    String optionalRecurringProductIds,
    @JsonKey(name: 'group_id') @Default('') String groupId,
    @JsonKey(name: 'auto_bill') @Default('') String autoBill,
    @JsonKey(name: 'remaining_cycles') @Default(-1) int remainingCycles,
    @JsonKey(name: 'refund_period') @Default(0) int refundPeriod,
    @JsonKey(name: 'trial_enabled') @Default(false) bool trialEnabled,
    @JsonKey(name: 'trial_duration') @Default(0) int trialDuration,
    @JsonKey(name: 'promo_code') @Default('') String promoCode,
    @JsonKey(name: 'promo_discount') @Default('0') Object promoDiscount,
    @JsonKey(name: 'promo_price') @Default('0') Object promoPrice,
    @JsonKey(name: 'is_amount_discount') @Default(false) bool isAmountDiscount,
    @JsonKey(name: 'allow_cancellation') @Default(false) bool allowCancellation,
    @JsonKey(name: 'allow_plan_changes') @Default(false) bool allowPlanChanges,
    @JsonKey(name: 'allow_query_overrides')
    @Default(false)
    bool allowQueryOverrides,
    @JsonKey(name: 'registration_required')
    @Default(false)
    bool registrationRequired,
    @JsonKey(name: 'use_inventory_management')
    @Default(false)
    bool useInventoryManagement,
    @JsonKey(name: 'per_seat_enabled') @Default(false) bool perSeatEnabled,
    @JsonKey(name: 'max_seats_limit') @Default(0) int maxSeatsLimit,
    @JsonKey(name: 'webhook_configuration')
    @Default(WebhookConfigurationApi())
    WebhookConfigurationApi webhookConfiguration,
    @Default('cart,auth.login-or-register') String steps,
    @JsonKey(name: 'purchase_page') @Default('') String purchasePage,
    // Internal field — opaque round-trip, no editor.
    @JsonKey(name: 'plan_map') @Default('') String planMap,
    @JsonKey(name: 'created_at') @Default(0) int createdAt,
    @JsonKey(name: 'updated_at') @Default(0) int updatedAt,
    @JsonKey(name: 'archived_at') @Default(0) int archivedAt,
    @JsonKey(name: 'is_deleted') @Default(false) bool isDeleted,
  }) = _SubscriptionApi;

  factory SubscriptionApi.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionApiFromJson(json);
}

/// PHP's `json_encode` serializes an empty associative array as `[]`
/// instead of `{}`. The strict generated parser crashes on the `Map` cast —
/// coerce a non-Map value to an empty map and stringify values defensively.
Map<String, String> _headersFromJson(Object? value) {
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
  }
  return const <String, String>{};
}

/// Nested `webhook_configuration` object. Carries the post-purchase webhook
/// URL/method/headers and the customer-return URL. `post_purchase_body` is
/// deprecated in admin-portal but preserved here for round-trip safety.
@freezed
abstract class WebhookConfigurationApi with _$WebhookConfigurationApi {
  const factory WebhookConfigurationApi({
    @JsonKey(name: 'return_url') @Default('') String returnUrl,
    @JsonKey(name: 'post_purchase_url') @Default('') String postPurchaseUrl,
    @JsonKey(name: 'post_purchase_rest_method')
    @Default('')
    String postPurchaseRestMethod,
    @JsonKey(name: 'post_purchase_headers', fromJson: _headersFromJson)
    @Default(<String, String>{})
    Map<String, String> postPurchaseHeaders,
    @JsonKey(name: 'post_purchase_body') @Default('') String postPurchaseBody,
  }) = _WebhookConfigurationApi;

  factory WebhookConfigurationApi.fromJson(Map<String, dynamic> json) =>
      _$WebhookConfigurationApiFromJson(json);
}

/// `GET /subscriptions` response envelope.
@freezed
abstract class SubscriptionListApi with _$SubscriptionListApi {
  const factory SubscriptionListApi({
    @JsonKey(fromJson: _subscriptionListData)
    @Default([])
    List<SubscriptionApi> data,
  }) = _SubscriptionListApi;

  factory SubscriptionListApi.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionListApiFromJson(json);
}

/// `POST/PUT /subscriptions/{id}` single-item envelope.
@freezed
abstract class SubscriptionItemApi with _$SubscriptionItemApi {
  const factory SubscriptionItemApi({required SubscriptionApi data}) =
      _SubscriptionItemApi;

  factory SubscriptionItemApi.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionItemApiFromJson(json);
}

/// One entry from `GET /api/v1/subscriptions/steps`. The endpoint returns
/// a keyed object (`Record<string,{id,label,dependencies}>`); the API
/// service flattens via `Object.values`.
@freezed
abstract class SubscriptionStepApi with _$SubscriptionStepApi {
  const factory SubscriptionStepApi({
    @Default('') String id,
    @Default('') String label,
    @Default(<String>[]) List<String> dependencies,
  }) = _SubscriptionStepApi;

  factory SubscriptionStepApi.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionStepApiFromJson(json);
}

List<SubscriptionApi> _subscriptionListData(Object? raw) =>
    tolerantList(raw, SubscriptionApi.fromJson, label: 'subscription');
