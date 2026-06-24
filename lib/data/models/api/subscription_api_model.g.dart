// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription_api_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SubscriptionApi _$SubscriptionApiFromJson(Map<String, dynamic> json) =>
    _SubscriptionApi(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      assignedUserId: json['assigned_user_id'] as String? ?? '',
      companyId: json['company_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: json['price'] as Object? ?? '0',
      currencyId: json['currency_id'] as String? ?? '',
      frequencyId: json['frequency_id'] as String? ?? '5',
      productIds: json['product_ids'] as String? ?? '',
      recurringProductIds: json['recurring_product_ids'] as String? ?? '',
      optionalProductIds: json['optional_product_ids'] as String? ?? '',
      optionalRecurringProductIds:
          json['optional_recurring_product_ids'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      autoBill: json['auto_bill'] as String? ?? '',
      remainingCycles: (json['remaining_cycles'] as num?)?.toInt() ?? -1,
      refundPeriod: (json['refund_period'] as num?)?.toInt() ?? 0,
      trialEnabled: json['trial_enabled'] as bool? ?? false,
      trialDuration: (json['trial_duration'] as num?)?.toInt() ?? 0,
      promoCode: json['promo_code'] as String? ?? '',
      promoDiscount: json['promo_discount'] as Object? ?? '0',
      promoPrice: json['promo_price'] as Object? ?? '0',
      isAmountDiscount: json['is_amount_discount'] as bool? ?? false,
      allowCancellation: json['allow_cancellation'] as bool? ?? false,
      allowPlanChanges: json['allow_plan_changes'] as bool? ?? false,
      allowQueryOverrides: json['allow_query_overrides'] as bool? ?? false,
      registrationRequired: json['registration_required'] as bool? ?? false,
      useInventoryManagement:
          json['use_inventory_management'] as bool? ?? false,
      perSeatEnabled: json['per_seat_enabled'] as bool? ?? false,
      maxSeatsLimit: (json['max_seats_limit'] as num?)?.toInt() ?? 0,
      webhookConfiguration: json['webhook_configuration'] == null
          ? const WebhookConfigurationApi()
          : WebhookConfigurationApi.fromJson(
              json['webhook_configuration'] as Map<String, dynamic>,
            ),
      steps: json['steps'] as String? ?? 'cart,auth.login-or-register',
      purchasePage: json['purchase_page'] as String? ?? '',
      planMap: json['plan_map'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      archivedAt: (json['archived_at'] as num?)?.toInt() ?? 0,
      isDeleted: json['is_deleted'] as bool? ?? false,
    );

Map<String, dynamic> _$SubscriptionApiToJson(_SubscriptionApi instance) =>
    <String, dynamic>{
      'id': instance.id,
      'user_id': instance.userId,
      'assigned_user_id': instance.assignedUserId,
      'company_id': instance.companyId,
      'name': instance.name,
      'price': instance.price,
      'currency_id': instance.currencyId,
      'frequency_id': instance.frequencyId,
      'product_ids': instance.productIds,
      'recurring_product_ids': instance.recurringProductIds,
      'optional_product_ids': instance.optionalProductIds,
      'optional_recurring_product_ids': instance.optionalRecurringProductIds,
      'group_id': instance.groupId,
      'auto_bill': instance.autoBill,
      'remaining_cycles': instance.remainingCycles,
      'refund_period': instance.refundPeriod,
      'trial_enabled': instance.trialEnabled,
      'trial_duration': instance.trialDuration,
      'promo_code': instance.promoCode,
      'promo_discount': instance.promoDiscount,
      'promo_price': instance.promoPrice,
      'is_amount_discount': instance.isAmountDiscount,
      'allow_cancellation': instance.allowCancellation,
      'allow_plan_changes': instance.allowPlanChanges,
      'allow_query_overrides': instance.allowQueryOverrides,
      'registration_required': instance.registrationRequired,
      'use_inventory_management': instance.useInventoryManagement,
      'per_seat_enabled': instance.perSeatEnabled,
      'max_seats_limit': instance.maxSeatsLimit,
      'webhook_configuration': instance.webhookConfiguration,
      'steps': instance.steps,
      'purchase_page': instance.purchasePage,
      'plan_map': instance.planMap,
      'created_at': instance.createdAt,
      'updated_at': instance.updatedAt,
      'archived_at': instance.archivedAt,
      'is_deleted': instance.isDeleted,
    };

_WebhookConfigurationApi _$WebhookConfigurationApiFromJson(
  Map<String, dynamic> json,
) => _WebhookConfigurationApi(
  returnUrl: json['return_url'] as String? ?? '',
  postPurchaseUrl: json['post_purchase_url'] as String? ?? '',
  postPurchaseRestMethod: json['post_purchase_rest_method'] as String? ?? '',
  postPurchaseHeaders: json['post_purchase_headers'] == null
      ? const <String, String>{}
      : _headersFromJson(json['post_purchase_headers']),
  postPurchaseBody: json['post_purchase_body'] as String? ?? '',
);

Map<String, dynamic> _$WebhookConfigurationApiToJson(
  _WebhookConfigurationApi instance,
) => <String, dynamic>{
  'return_url': instance.returnUrl,
  'post_purchase_url': instance.postPurchaseUrl,
  'post_purchase_rest_method': instance.postPurchaseRestMethod,
  'post_purchase_headers': instance.postPurchaseHeaders,
  'post_purchase_body': instance.postPurchaseBody,
};

_SubscriptionListApi _$SubscriptionListApiFromJson(Map<String, dynamic> json) =>
    _SubscriptionListApi(
      data: json['data'] == null
          ? const []
          : _subscriptionListData(json['data']),
    );

Map<String, dynamic> _$SubscriptionListApiToJson(
  _SubscriptionListApi instance,
) => <String, dynamic>{'data': instance.data};

_SubscriptionItemApi _$SubscriptionItemApiFromJson(Map<String, dynamic> json) =>
    _SubscriptionItemApi(
      data: SubscriptionApi.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$SubscriptionItemApiToJson(
  _SubscriptionItemApi instance,
) => <String, dynamic>{'data': instance.data};

_SubscriptionStepApi _$SubscriptionStepApiFromJson(Map<String, dynamic> json) =>
    _SubscriptionStepApi(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      dependencies:
          (json['dependencies'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$SubscriptionStepApiToJson(
  _SubscriptionStepApi instance,
) => <String, dynamic>{
  'id': instance.id,
  'label': instance.label,
  'dependencies': instance.dependencies,
};
