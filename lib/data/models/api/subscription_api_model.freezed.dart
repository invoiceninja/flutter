// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subscription_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SubscriptionApi {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'assigned_user_id') String get assignedUserId;@JsonKey(name: 'company_id') String get companyId; String get name;// num-or-string on the wire. Domain model normalizes to Decimal.
 Object get price;@JsonKey(name: 'currency_id') String get currencyId;@JsonKey(name: 'frequency_id') String get frequencyId;@JsonKey(name: 'product_ids') String get productIds;@JsonKey(name: 'recurring_product_ids') String get recurringProductIds;@JsonKey(name: 'optional_product_ids') String get optionalProductIds;@JsonKey(name: 'optional_recurring_product_ids') String get optionalRecurringProductIds;@JsonKey(name: 'group_id') String get groupId;@JsonKey(name: 'auto_bill') String get autoBill;@JsonKey(name: 'remaining_cycles') int get remainingCycles;@JsonKey(name: 'refund_period') int get refundPeriod;@JsonKey(name: 'trial_enabled') bool get trialEnabled;@JsonKey(name: 'trial_duration') int get trialDuration;@JsonKey(name: 'promo_code') String get promoCode;@JsonKey(name: 'promo_discount') Object get promoDiscount;@JsonKey(name: 'promo_price') Object get promoPrice;@JsonKey(name: 'is_amount_discount') bool get isAmountDiscount;@JsonKey(name: 'allow_cancellation') bool get allowCancellation;@JsonKey(name: 'allow_plan_changes') bool get allowPlanChanges;@JsonKey(name: 'allow_query_overrides') bool get allowQueryOverrides;@JsonKey(name: 'registration_required') bool get registrationRequired;@JsonKey(name: 'use_inventory_management') bool get useInventoryManagement;@JsonKey(name: 'per_seat_enabled') bool get perSeatEnabled;@JsonKey(name: 'max_seats_limit') int get maxSeatsLimit;@JsonKey(name: 'webhook_configuration') WebhookConfigurationApi get webhookConfiguration; String get steps;@JsonKey(name: 'purchase_page') String get purchasePage;// Internal field — opaque round-trip, no editor.
@JsonKey(name: 'plan_map') String get planMap;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of SubscriptionApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionApiCopyWith<SubscriptionApi> get copyWith => _$SubscriptionApiCopyWithImpl<SubscriptionApi>(this as SubscriptionApi, _$identity);

  /// Serializes this SubscriptionApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.price, price)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.frequencyId, frequencyId) || other.frequencyId == frequencyId)&&(identical(other.productIds, productIds) || other.productIds == productIds)&&(identical(other.recurringProductIds, recurringProductIds) || other.recurringProductIds == recurringProductIds)&&(identical(other.optionalProductIds, optionalProductIds) || other.optionalProductIds == optionalProductIds)&&(identical(other.optionalRecurringProductIds, optionalRecurringProductIds) || other.optionalRecurringProductIds == optionalRecurringProductIds)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.autoBill, autoBill) || other.autoBill == autoBill)&&(identical(other.remainingCycles, remainingCycles) || other.remainingCycles == remainingCycles)&&(identical(other.refundPeriod, refundPeriod) || other.refundPeriod == refundPeriod)&&(identical(other.trialEnabled, trialEnabled) || other.trialEnabled == trialEnabled)&&(identical(other.trialDuration, trialDuration) || other.trialDuration == trialDuration)&&(identical(other.promoCode, promoCode) || other.promoCode == promoCode)&&const DeepCollectionEquality().equals(other.promoDiscount, promoDiscount)&&const DeepCollectionEquality().equals(other.promoPrice, promoPrice)&&(identical(other.isAmountDiscount, isAmountDiscount) || other.isAmountDiscount == isAmountDiscount)&&(identical(other.allowCancellation, allowCancellation) || other.allowCancellation == allowCancellation)&&(identical(other.allowPlanChanges, allowPlanChanges) || other.allowPlanChanges == allowPlanChanges)&&(identical(other.allowQueryOverrides, allowQueryOverrides) || other.allowQueryOverrides == allowQueryOverrides)&&(identical(other.registrationRequired, registrationRequired) || other.registrationRequired == registrationRequired)&&(identical(other.useInventoryManagement, useInventoryManagement) || other.useInventoryManagement == useInventoryManagement)&&(identical(other.perSeatEnabled, perSeatEnabled) || other.perSeatEnabled == perSeatEnabled)&&(identical(other.maxSeatsLimit, maxSeatsLimit) || other.maxSeatsLimit == maxSeatsLimit)&&(identical(other.webhookConfiguration, webhookConfiguration) || other.webhookConfiguration == webhookConfiguration)&&(identical(other.steps, steps) || other.steps == steps)&&(identical(other.purchasePage, purchasePage) || other.purchasePage == purchasePage)&&(identical(other.planMap, planMap) || other.planMap == planMap)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,companyId,name,const DeepCollectionEquality().hash(price),currencyId,frequencyId,productIds,recurringProductIds,optionalProductIds,optionalRecurringProductIds,groupId,autoBill,remainingCycles,refundPeriod,trialEnabled,trialDuration,promoCode,const DeepCollectionEquality().hash(promoDiscount),const DeepCollectionEquality().hash(promoPrice),isAmountDiscount,allowCancellation,allowPlanChanges,allowQueryOverrides,registrationRequired,useInventoryManagement,perSeatEnabled,maxSeatsLimit,webhookConfiguration,steps,purchasePage,planMap,createdAt,updatedAt,archivedAt,isDeleted]);

@override
String toString() {
  return 'SubscriptionApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, companyId: $companyId, name: $name, price: $price, currencyId: $currencyId, frequencyId: $frequencyId, productIds: $productIds, recurringProductIds: $recurringProductIds, optionalProductIds: $optionalProductIds, optionalRecurringProductIds: $optionalRecurringProductIds, groupId: $groupId, autoBill: $autoBill, remainingCycles: $remainingCycles, refundPeriod: $refundPeriod, trialEnabled: $trialEnabled, trialDuration: $trialDuration, promoCode: $promoCode, promoDiscount: $promoDiscount, promoPrice: $promoPrice, isAmountDiscount: $isAmountDiscount, allowCancellation: $allowCancellation, allowPlanChanges: $allowPlanChanges, allowQueryOverrides: $allowQueryOverrides, registrationRequired: $registrationRequired, useInventoryManagement: $useInventoryManagement, perSeatEnabled: $perSeatEnabled, maxSeatsLimit: $maxSeatsLimit, webhookConfiguration: $webhookConfiguration, steps: $steps, purchasePage: $purchasePage, planMap: $planMap, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class $SubscriptionApiCopyWith<$Res>  {
  factory $SubscriptionApiCopyWith(SubscriptionApi value, $Res Function(SubscriptionApi) _then) = _$SubscriptionApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'company_id') String companyId, String name, Object price,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'frequency_id') String frequencyId,@JsonKey(name: 'product_ids') String productIds,@JsonKey(name: 'recurring_product_ids') String recurringProductIds,@JsonKey(name: 'optional_product_ids') String optionalProductIds,@JsonKey(name: 'optional_recurring_product_ids') String optionalRecurringProductIds,@JsonKey(name: 'group_id') String groupId,@JsonKey(name: 'auto_bill') String autoBill,@JsonKey(name: 'remaining_cycles') int remainingCycles,@JsonKey(name: 'refund_period') int refundPeriod,@JsonKey(name: 'trial_enabled') bool trialEnabled,@JsonKey(name: 'trial_duration') int trialDuration,@JsonKey(name: 'promo_code') String promoCode,@JsonKey(name: 'promo_discount') Object promoDiscount,@JsonKey(name: 'promo_price') Object promoPrice,@JsonKey(name: 'is_amount_discount') bool isAmountDiscount,@JsonKey(name: 'allow_cancellation') bool allowCancellation,@JsonKey(name: 'allow_plan_changes') bool allowPlanChanges,@JsonKey(name: 'allow_query_overrides') bool allowQueryOverrides,@JsonKey(name: 'registration_required') bool registrationRequired,@JsonKey(name: 'use_inventory_management') bool useInventoryManagement,@JsonKey(name: 'per_seat_enabled') bool perSeatEnabled,@JsonKey(name: 'max_seats_limit') int maxSeatsLimit,@JsonKey(name: 'webhook_configuration') WebhookConfigurationApi webhookConfiguration, String steps,@JsonKey(name: 'purchase_page') String purchasePage,@JsonKey(name: 'plan_map') String planMap,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});


$WebhookConfigurationApiCopyWith<$Res> get webhookConfiguration;

}
/// @nodoc
class _$SubscriptionApiCopyWithImpl<$Res>
    implements $SubscriptionApiCopyWith<$Res> {
  _$SubscriptionApiCopyWithImpl(this._self, this._then);

  final SubscriptionApi _self;
  final $Res Function(SubscriptionApi) _then;

/// Create a copy of SubscriptionApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? companyId = null,Object? name = null,Object? price = null,Object? currencyId = null,Object? frequencyId = null,Object? productIds = null,Object? recurringProductIds = null,Object? optionalProductIds = null,Object? optionalRecurringProductIds = null,Object? groupId = null,Object? autoBill = null,Object? remainingCycles = null,Object? refundPeriod = null,Object? trialEnabled = null,Object? trialDuration = null,Object? promoCode = null,Object? promoDiscount = null,Object? promoPrice = null,Object? isAmountDiscount = null,Object? allowCancellation = null,Object? allowPlanChanges = null,Object? allowQueryOverrides = null,Object? registrationRequired = null,Object? useInventoryManagement = null,Object? perSeatEnabled = null,Object? maxSeatsLimit = null,Object? webhookConfiguration = null,Object? steps = null,Object? purchasePage = null,Object? planMap = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price ,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,frequencyId: null == frequencyId ? _self.frequencyId : frequencyId // ignore: cast_nullable_to_non_nullable
as String,productIds: null == productIds ? _self.productIds : productIds // ignore: cast_nullable_to_non_nullable
as String,recurringProductIds: null == recurringProductIds ? _self.recurringProductIds : recurringProductIds // ignore: cast_nullable_to_non_nullable
as String,optionalProductIds: null == optionalProductIds ? _self.optionalProductIds : optionalProductIds // ignore: cast_nullable_to_non_nullable
as String,optionalRecurringProductIds: null == optionalRecurringProductIds ? _self.optionalRecurringProductIds : optionalRecurringProductIds // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,autoBill: null == autoBill ? _self.autoBill : autoBill // ignore: cast_nullable_to_non_nullable
as String,remainingCycles: null == remainingCycles ? _self.remainingCycles : remainingCycles // ignore: cast_nullable_to_non_nullable
as int,refundPeriod: null == refundPeriod ? _self.refundPeriod : refundPeriod // ignore: cast_nullable_to_non_nullable
as int,trialEnabled: null == trialEnabled ? _self.trialEnabled : trialEnabled // ignore: cast_nullable_to_non_nullable
as bool,trialDuration: null == trialDuration ? _self.trialDuration : trialDuration // ignore: cast_nullable_to_non_nullable
as int,promoCode: null == promoCode ? _self.promoCode : promoCode // ignore: cast_nullable_to_non_nullable
as String,promoDiscount: null == promoDiscount ? _self.promoDiscount : promoDiscount ,promoPrice: null == promoPrice ? _self.promoPrice : promoPrice ,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
as bool,allowCancellation: null == allowCancellation ? _self.allowCancellation : allowCancellation // ignore: cast_nullable_to_non_nullable
as bool,allowPlanChanges: null == allowPlanChanges ? _self.allowPlanChanges : allowPlanChanges // ignore: cast_nullable_to_non_nullable
as bool,allowQueryOverrides: null == allowQueryOverrides ? _self.allowQueryOverrides : allowQueryOverrides // ignore: cast_nullable_to_non_nullable
as bool,registrationRequired: null == registrationRequired ? _self.registrationRequired : registrationRequired // ignore: cast_nullable_to_non_nullable
as bool,useInventoryManagement: null == useInventoryManagement ? _self.useInventoryManagement : useInventoryManagement // ignore: cast_nullable_to_non_nullable
as bool,perSeatEnabled: null == perSeatEnabled ? _self.perSeatEnabled : perSeatEnabled // ignore: cast_nullable_to_non_nullable
as bool,maxSeatsLimit: null == maxSeatsLimit ? _self.maxSeatsLimit : maxSeatsLimit // ignore: cast_nullable_to_non_nullable
as int,webhookConfiguration: null == webhookConfiguration ? _self.webhookConfiguration : webhookConfiguration // ignore: cast_nullable_to_non_nullable
as WebhookConfigurationApi,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as String,purchasePage: null == purchasePage ? _self.purchasePage : purchasePage // ignore: cast_nullable_to_non_nullable
as String,planMap: null == planMap ? _self.planMap : planMap // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of SubscriptionApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WebhookConfigurationApiCopyWith<$Res> get webhookConfiguration {
  
  return $WebhookConfigurationApiCopyWith<$Res>(_self.webhookConfiguration, (value) {
    return _then(_self.copyWith(webhookConfiguration: value));
  });
}
}


/// Adds pattern-matching-related methods to [SubscriptionApi].
extension SubscriptionApiPatterns on SubscriptionApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionApi value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionApi value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'company_id')  String companyId,  String name,  Object price, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'product_ids')  String productIds, @JsonKey(name: 'recurring_product_ids')  String recurringProductIds, @JsonKey(name: 'optional_product_ids')  String optionalProductIds, @JsonKey(name: 'optional_recurring_product_ids')  String optionalRecurringProductIds, @JsonKey(name: 'group_id')  String groupId, @JsonKey(name: 'auto_bill')  String autoBill, @JsonKey(name: 'remaining_cycles')  int remainingCycles, @JsonKey(name: 'refund_period')  int refundPeriod, @JsonKey(name: 'trial_enabled')  bool trialEnabled, @JsonKey(name: 'trial_duration')  int trialDuration, @JsonKey(name: 'promo_code')  String promoCode, @JsonKey(name: 'promo_discount')  Object promoDiscount, @JsonKey(name: 'promo_price')  Object promoPrice, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'allow_cancellation')  bool allowCancellation, @JsonKey(name: 'allow_plan_changes')  bool allowPlanChanges, @JsonKey(name: 'allow_query_overrides')  bool allowQueryOverrides, @JsonKey(name: 'registration_required')  bool registrationRequired, @JsonKey(name: 'use_inventory_management')  bool useInventoryManagement, @JsonKey(name: 'per_seat_enabled')  bool perSeatEnabled, @JsonKey(name: 'max_seats_limit')  int maxSeatsLimit, @JsonKey(name: 'webhook_configuration')  WebhookConfigurationApi webhookConfiguration,  String steps, @JsonKey(name: 'purchase_page')  String purchasePage, @JsonKey(name: 'plan_map')  String planMap, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.companyId,_that.name,_that.price,_that.currencyId,_that.frequencyId,_that.productIds,_that.recurringProductIds,_that.optionalProductIds,_that.optionalRecurringProductIds,_that.groupId,_that.autoBill,_that.remainingCycles,_that.refundPeriod,_that.trialEnabled,_that.trialDuration,_that.promoCode,_that.promoDiscount,_that.promoPrice,_that.isAmountDiscount,_that.allowCancellation,_that.allowPlanChanges,_that.allowQueryOverrides,_that.registrationRequired,_that.useInventoryManagement,_that.perSeatEnabled,_that.maxSeatsLimit,_that.webhookConfiguration,_that.steps,_that.purchasePage,_that.planMap,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'company_id')  String companyId,  String name,  Object price, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'product_ids')  String productIds, @JsonKey(name: 'recurring_product_ids')  String recurringProductIds, @JsonKey(name: 'optional_product_ids')  String optionalProductIds, @JsonKey(name: 'optional_recurring_product_ids')  String optionalRecurringProductIds, @JsonKey(name: 'group_id')  String groupId, @JsonKey(name: 'auto_bill')  String autoBill, @JsonKey(name: 'remaining_cycles')  int remainingCycles, @JsonKey(name: 'refund_period')  int refundPeriod, @JsonKey(name: 'trial_enabled')  bool trialEnabled, @JsonKey(name: 'trial_duration')  int trialDuration, @JsonKey(name: 'promo_code')  String promoCode, @JsonKey(name: 'promo_discount')  Object promoDiscount, @JsonKey(name: 'promo_price')  Object promoPrice, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'allow_cancellation')  bool allowCancellation, @JsonKey(name: 'allow_plan_changes')  bool allowPlanChanges, @JsonKey(name: 'allow_query_overrides')  bool allowQueryOverrides, @JsonKey(name: 'registration_required')  bool registrationRequired, @JsonKey(name: 'use_inventory_management')  bool useInventoryManagement, @JsonKey(name: 'per_seat_enabled')  bool perSeatEnabled, @JsonKey(name: 'max_seats_limit')  int maxSeatsLimit, @JsonKey(name: 'webhook_configuration')  WebhookConfigurationApi webhookConfiguration,  String steps, @JsonKey(name: 'purchase_page')  String purchasePage, @JsonKey(name: 'plan_map')  String planMap, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionApi():
return $default(_that.id,_that.userId,_that.assignedUserId,_that.companyId,_that.name,_that.price,_that.currencyId,_that.frequencyId,_that.productIds,_that.recurringProductIds,_that.optionalProductIds,_that.optionalRecurringProductIds,_that.groupId,_that.autoBill,_that.remainingCycles,_that.refundPeriod,_that.trialEnabled,_that.trialDuration,_that.promoCode,_that.promoDiscount,_that.promoPrice,_that.isAmountDiscount,_that.allowCancellation,_that.allowPlanChanges,_that.allowQueryOverrides,_that.registrationRequired,_that.useInventoryManagement,_that.perSeatEnabled,_that.maxSeatsLimit,_that.webhookConfiguration,_that.steps,_that.purchasePage,_that.planMap,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId, @JsonKey(name: 'company_id')  String companyId,  String name,  Object price, @JsonKey(name: 'currency_id')  String currencyId, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'product_ids')  String productIds, @JsonKey(name: 'recurring_product_ids')  String recurringProductIds, @JsonKey(name: 'optional_product_ids')  String optionalProductIds, @JsonKey(name: 'optional_recurring_product_ids')  String optionalRecurringProductIds, @JsonKey(name: 'group_id')  String groupId, @JsonKey(name: 'auto_bill')  String autoBill, @JsonKey(name: 'remaining_cycles')  int remainingCycles, @JsonKey(name: 'refund_period')  int refundPeriod, @JsonKey(name: 'trial_enabled')  bool trialEnabled, @JsonKey(name: 'trial_duration')  int trialDuration, @JsonKey(name: 'promo_code')  String promoCode, @JsonKey(name: 'promo_discount')  Object promoDiscount, @JsonKey(name: 'promo_price')  Object promoPrice, @JsonKey(name: 'is_amount_discount')  bool isAmountDiscount, @JsonKey(name: 'allow_cancellation')  bool allowCancellation, @JsonKey(name: 'allow_plan_changes')  bool allowPlanChanges, @JsonKey(name: 'allow_query_overrides')  bool allowQueryOverrides, @JsonKey(name: 'registration_required')  bool registrationRequired, @JsonKey(name: 'use_inventory_management')  bool useInventoryManagement, @JsonKey(name: 'per_seat_enabled')  bool perSeatEnabled, @JsonKey(name: 'max_seats_limit')  int maxSeatsLimit, @JsonKey(name: 'webhook_configuration')  WebhookConfigurationApi webhookConfiguration,  String steps, @JsonKey(name: 'purchase_page')  String purchasePage, @JsonKey(name: 'plan_map')  String planMap, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.companyId,_that.name,_that.price,_that.currencyId,_that.frequencyId,_that.productIds,_that.recurringProductIds,_that.optionalProductIds,_that.optionalRecurringProductIds,_that.groupId,_that.autoBill,_that.remainingCycles,_that.refundPeriod,_that.trialEnabled,_that.trialDuration,_that.promoCode,_that.promoDiscount,_that.promoPrice,_that.isAmountDiscount,_that.allowCancellation,_that.allowPlanChanges,_that.allowQueryOverrides,_that.registrationRequired,_that.useInventoryManagement,_that.perSeatEnabled,_that.maxSeatsLimit,_that.webhookConfiguration,_that.steps,_that.purchasePage,_that.planMap,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionApi implements SubscriptionApi {
  const _SubscriptionApi({this.id = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', @JsonKey(name: 'company_id') this.companyId = '', this.name = '', this.price = '0', @JsonKey(name: 'currency_id') this.currencyId = '', @JsonKey(name: 'frequency_id') this.frequencyId = '5', @JsonKey(name: 'product_ids') this.productIds = '', @JsonKey(name: 'recurring_product_ids') this.recurringProductIds = '', @JsonKey(name: 'optional_product_ids') this.optionalProductIds = '', @JsonKey(name: 'optional_recurring_product_ids') this.optionalRecurringProductIds = '', @JsonKey(name: 'group_id') this.groupId = '', @JsonKey(name: 'auto_bill') this.autoBill = '', @JsonKey(name: 'remaining_cycles') this.remainingCycles = -1, @JsonKey(name: 'refund_period') this.refundPeriod = 0, @JsonKey(name: 'trial_enabled') this.trialEnabled = false, @JsonKey(name: 'trial_duration') this.trialDuration = 0, @JsonKey(name: 'promo_code') this.promoCode = '', @JsonKey(name: 'promo_discount') this.promoDiscount = '0', @JsonKey(name: 'promo_price') this.promoPrice = '0', @JsonKey(name: 'is_amount_discount') this.isAmountDiscount = false, @JsonKey(name: 'allow_cancellation') this.allowCancellation = false, @JsonKey(name: 'allow_plan_changes') this.allowPlanChanges = false, @JsonKey(name: 'allow_query_overrides') this.allowQueryOverrides = false, @JsonKey(name: 'registration_required') this.registrationRequired = false, @JsonKey(name: 'use_inventory_management') this.useInventoryManagement = false, @JsonKey(name: 'per_seat_enabled') this.perSeatEnabled = false, @JsonKey(name: 'max_seats_limit') this.maxSeatsLimit = 0, @JsonKey(name: 'webhook_configuration') this.webhookConfiguration = const WebhookConfigurationApi(), this.steps = 'cart,auth.login-or-register', @JsonKey(name: 'purchase_page') this.purchasePage = '', @JsonKey(name: 'plan_map') this.planMap = '', @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false});
  factory _SubscriptionApi.fromJson(Map<String, dynamic> json) => _$SubscriptionApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey(name: 'company_id') final  String companyId;
@override@JsonKey() final  String name;
// num-or-string on the wire. Domain model normalizes to Decimal.
@override@JsonKey() final  Object price;
@override@JsonKey(name: 'currency_id') final  String currencyId;
@override@JsonKey(name: 'frequency_id') final  String frequencyId;
@override@JsonKey(name: 'product_ids') final  String productIds;
@override@JsonKey(name: 'recurring_product_ids') final  String recurringProductIds;
@override@JsonKey(name: 'optional_product_ids') final  String optionalProductIds;
@override@JsonKey(name: 'optional_recurring_product_ids') final  String optionalRecurringProductIds;
@override@JsonKey(name: 'group_id') final  String groupId;
@override@JsonKey(name: 'auto_bill') final  String autoBill;
@override@JsonKey(name: 'remaining_cycles') final  int remainingCycles;
@override@JsonKey(name: 'refund_period') final  int refundPeriod;
@override@JsonKey(name: 'trial_enabled') final  bool trialEnabled;
@override@JsonKey(name: 'trial_duration') final  int trialDuration;
@override@JsonKey(name: 'promo_code') final  String promoCode;
@override@JsonKey(name: 'promo_discount') final  Object promoDiscount;
@override@JsonKey(name: 'promo_price') final  Object promoPrice;
@override@JsonKey(name: 'is_amount_discount') final  bool isAmountDiscount;
@override@JsonKey(name: 'allow_cancellation') final  bool allowCancellation;
@override@JsonKey(name: 'allow_plan_changes') final  bool allowPlanChanges;
@override@JsonKey(name: 'allow_query_overrides') final  bool allowQueryOverrides;
@override@JsonKey(name: 'registration_required') final  bool registrationRequired;
@override@JsonKey(name: 'use_inventory_management') final  bool useInventoryManagement;
@override@JsonKey(name: 'per_seat_enabled') final  bool perSeatEnabled;
@override@JsonKey(name: 'max_seats_limit') final  int maxSeatsLimit;
@override@JsonKey(name: 'webhook_configuration') final  WebhookConfigurationApi webhookConfiguration;
@override@JsonKey() final  String steps;
@override@JsonKey(name: 'purchase_page') final  String purchasePage;
// Internal field — opaque round-trip, no editor.
@override@JsonKey(name: 'plan_map') final  String planMap;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of SubscriptionApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionApiCopyWith<_SubscriptionApi> get copyWith => __$SubscriptionApiCopyWithImpl<_SubscriptionApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.price, price)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.frequencyId, frequencyId) || other.frequencyId == frequencyId)&&(identical(other.productIds, productIds) || other.productIds == productIds)&&(identical(other.recurringProductIds, recurringProductIds) || other.recurringProductIds == recurringProductIds)&&(identical(other.optionalProductIds, optionalProductIds) || other.optionalProductIds == optionalProductIds)&&(identical(other.optionalRecurringProductIds, optionalRecurringProductIds) || other.optionalRecurringProductIds == optionalRecurringProductIds)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.autoBill, autoBill) || other.autoBill == autoBill)&&(identical(other.remainingCycles, remainingCycles) || other.remainingCycles == remainingCycles)&&(identical(other.refundPeriod, refundPeriod) || other.refundPeriod == refundPeriod)&&(identical(other.trialEnabled, trialEnabled) || other.trialEnabled == trialEnabled)&&(identical(other.trialDuration, trialDuration) || other.trialDuration == trialDuration)&&(identical(other.promoCode, promoCode) || other.promoCode == promoCode)&&const DeepCollectionEquality().equals(other.promoDiscount, promoDiscount)&&const DeepCollectionEquality().equals(other.promoPrice, promoPrice)&&(identical(other.isAmountDiscount, isAmountDiscount) || other.isAmountDiscount == isAmountDiscount)&&(identical(other.allowCancellation, allowCancellation) || other.allowCancellation == allowCancellation)&&(identical(other.allowPlanChanges, allowPlanChanges) || other.allowPlanChanges == allowPlanChanges)&&(identical(other.allowQueryOverrides, allowQueryOverrides) || other.allowQueryOverrides == allowQueryOverrides)&&(identical(other.registrationRequired, registrationRequired) || other.registrationRequired == registrationRequired)&&(identical(other.useInventoryManagement, useInventoryManagement) || other.useInventoryManagement == useInventoryManagement)&&(identical(other.perSeatEnabled, perSeatEnabled) || other.perSeatEnabled == perSeatEnabled)&&(identical(other.maxSeatsLimit, maxSeatsLimit) || other.maxSeatsLimit == maxSeatsLimit)&&(identical(other.webhookConfiguration, webhookConfiguration) || other.webhookConfiguration == webhookConfiguration)&&(identical(other.steps, steps) || other.steps == steps)&&(identical(other.purchasePage, purchasePage) || other.purchasePage == purchasePage)&&(identical(other.planMap, planMap) || other.planMap == planMap)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,userId,assignedUserId,companyId,name,const DeepCollectionEquality().hash(price),currencyId,frequencyId,productIds,recurringProductIds,optionalProductIds,optionalRecurringProductIds,groupId,autoBill,remainingCycles,refundPeriod,trialEnabled,trialDuration,promoCode,const DeepCollectionEquality().hash(promoDiscount),const DeepCollectionEquality().hash(promoPrice),isAmountDiscount,allowCancellation,allowPlanChanges,allowQueryOverrides,registrationRequired,useInventoryManagement,perSeatEnabled,maxSeatsLimit,webhookConfiguration,steps,purchasePage,planMap,createdAt,updatedAt,archivedAt,isDeleted]);

@override
String toString() {
  return 'SubscriptionApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, companyId: $companyId, name: $name, price: $price, currencyId: $currencyId, frequencyId: $frequencyId, productIds: $productIds, recurringProductIds: $recurringProductIds, optionalProductIds: $optionalProductIds, optionalRecurringProductIds: $optionalRecurringProductIds, groupId: $groupId, autoBill: $autoBill, remainingCycles: $remainingCycles, refundPeriod: $refundPeriod, trialEnabled: $trialEnabled, trialDuration: $trialDuration, promoCode: $promoCode, promoDiscount: $promoDiscount, promoPrice: $promoPrice, isAmountDiscount: $isAmountDiscount, allowCancellation: $allowCancellation, allowPlanChanges: $allowPlanChanges, allowQueryOverrides: $allowQueryOverrides, registrationRequired: $registrationRequired, useInventoryManagement: $useInventoryManagement, perSeatEnabled: $perSeatEnabled, maxSeatsLimit: $maxSeatsLimit, webhookConfiguration: $webhookConfiguration, steps: $steps, purchasePage: $purchasePage, planMap: $planMap, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionApiCopyWith<$Res> implements $SubscriptionApiCopyWith<$Res> {
  factory _$SubscriptionApiCopyWith(_SubscriptionApi value, $Res Function(_SubscriptionApi) _then) = __$SubscriptionApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId,@JsonKey(name: 'company_id') String companyId, String name, Object price,@JsonKey(name: 'currency_id') String currencyId,@JsonKey(name: 'frequency_id') String frequencyId,@JsonKey(name: 'product_ids') String productIds,@JsonKey(name: 'recurring_product_ids') String recurringProductIds,@JsonKey(name: 'optional_product_ids') String optionalProductIds,@JsonKey(name: 'optional_recurring_product_ids') String optionalRecurringProductIds,@JsonKey(name: 'group_id') String groupId,@JsonKey(name: 'auto_bill') String autoBill,@JsonKey(name: 'remaining_cycles') int remainingCycles,@JsonKey(name: 'refund_period') int refundPeriod,@JsonKey(name: 'trial_enabled') bool trialEnabled,@JsonKey(name: 'trial_duration') int trialDuration,@JsonKey(name: 'promo_code') String promoCode,@JsonKey(name: 'promo_discount') Object promoDiscount,@JsonKey(name: 'promo_price') Object promoPrice,@JsonKey(name: 'is_amount_discount') bool isAmountDiscount,@JsonKey(name: 'allow_cancellation') bool allowCancellation,@JsonKey(name: 'allow_plan_changes') bool allowPlanChanges,@JsonKey(name: 'allow_query_overrides') bool allowQueryOverrides,@JsonKey(name: 'registration_required') bool registrationRequired,@JsonKey(name: 'use_inventory_management') bool useInventoryManagement,@JsonKey(name: 'per_seat_enabled') bool perSeatEnabled,@JsonKey(name: 'max_seats_limit') int maxSeatsLimit,@JsonKey(name: 'webhook_configuration') WebhookConfigurationApi webhookConfiguration, String steps,@JsonKey(name: 'purchase_page') String purchasePage,@JsonKey(name: 'plan_map') String planMap,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});


@override $WebhookConfigurationApiCopyWith<$Res> get webhookConfiguration;

}
/// @nodoc
class __$SubscriptionApiCopyWithImpl<$Res>
    implements _$SubscriptionApiCopyWith<$Res> {
  __$SubscriptionApiCopyWithImpl(this._self, this._then);

  final _SubscriptionApi _self;
  final $Res Function(_SubscriptionApi) _then;

/// Create a copy of SubscriptionApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? companyId = null,Object? name = null,Object? price = null,Object? currencyId = null,Object? frequencyId = null,Object? productIds = null,Object? recurringProductIds = null,Object? optionalProductIds = null,Object? optionalRecurringProductIds = null,Object? groupId = null,Object? autoBill = null,Object? remainingCycles = null,Object? refundPeriod = null,Object? trialEnabled = null,Object? trialDuration = null,Object? promoCode = null,Object? promoDiscount = null,Object? promoPrice = null,Object? isAmountDiscount = null,Object? allowCancellation = null,Object? allowPlanChanges = null,Object? allowQueryOverrides = null,Object? registrationRequired = null,Object? useInventoryManagement = null,Object? perSeatEnabled = null,Object? maxSeatsLimit = null,Object? webhookConfiguration = null,Object? steps = null,Object? purchasePage = null,Object? planMap = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_SubscriptionApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price ,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
as String,frequencyId: null == frequencyId ? _self.frequencyId : frequencyId // ignore: cast_nullable_to_non_nullable
as String,productIds: null == productIds ? _self.productIds : productIds // ignore: cast_nullable_to_non_nullable
as String,recurringProductIds: null == recurringProductIds ? _self.recurringProductIds : recurringProductIds // ignore: cast_nullable_to_non_nullable
as String,optionalProductIds: null == optionalProductIds ? _self.optionalProductIds : optionalProductIds // ignore: cast_nullable_to_non_nullable
as String,optionalRecurringProductIds: null == optionalRecurringProductIds ? _self.optionalRecurringProductIds : optionalRecurringProductIds // ignore: cast_nullable_to_non_nullable
as String,groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as String,autoBill: null == autoBill ? _self.autoBill : autoBill // ignore: cast_nullable_to_non_nullable
as String,remainingCycles: null == remainingCycles ? _self.remainingCycles : remainingCycles // ignore: cast_nullable_to_non_nullable
as int,refundPeriod: null == refundPeriod ? _self.refundPeriod : refundPeriod // ignore: cast_nullable_to_non_nullable
as int,trialEnabled: null == trialEnabled ? _self.trialEnabled : trialEnabled // ignore: cast_nullable_to_non_nullable
as bool,trialDuration: null == trialDuration ? _self.trialDuration : trialDuration // ignore: cast_nullable_to_non_nullable
as int,promoCode: null == promoCode ? _self.promoCode : promoCode // ignore: cast_nullable_to_non_nullable
as String,promoDiscount: null == promoDiscount ? _self.promoDiscount : promoDiscount ,promoPrice: null == promoPrice ? _self.promoPrice : promoPrice ,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
as bool,allowCancellation: null == allowCancellation ? _self.allowCancellation : allowCancellation // ignore: cast_nullable_to_non_nullable
as bool,allowPlanChanges: null == allowPlanChanges ? _self.allowPlanChanges : allowPlanChanges // ignore: cast_nullable_to_non_nullable
as bool,allowQueryOverrides: null == allowQueryOverrides ? _self.allowQueryOverrides : allowQueryOverrides // ignore: cast_nullable_to_non_nullable
as bool,registrationRequired: null == registrationRequired ? _self.registrationRequired : registrationRequired // ignore: cast_nullable_to_non_nullable
as bool,useInventoryManagement: null == useInventoryManagement ? _self.useInventoryManagement : useInventoryManagement // ignore: cast_nullable_to_non_nullable
as bool,perSeatEnabled: null == perSeatEnabled ? _self.perSeatEnabled : perSeatEnabled // ignore: cast_nullable_to_non_nullable
as bool,maxSeatsLimit: null == maxSeatsLimit ? _self.maxSeatsLimit : maxSeatsLimit // ignore: cast_nullable_to_non_nullable
as int,webhookConfiguration: null == webhookConfiguration ? _self.webhookConfiguration : webhookConfiguration // ignore: cast_nullable_to_non_nullable
as WebhookConfigurationApi,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as String,purchasePage: null == purchasePage ? _self.purchasePage : purchasePage // ignore: cast_nullable_to_non_nullable
as String,planMap: null == planMap ? _self.planMap : planMap // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of SubscriptionApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WebhookConfigurationApiCopyWith<$Res> get webhookConfiguration {
  
  return $WebhookConfigurationApiCopyWith<$Res>(_self.webhookConfiguration, (value) {
    return _then(_self.copyWith(webhookConfiguration: value));
  });
}
}


/// @nodoc
mixin _$WebhookConfigurationApi {

@JsonKey(name: 'return_url') String get returnUrl;@JsonKey(name: 'post_purchase_url') String get postPurchaseUrl;@JsonKey(name: 'post_purchase_rest_method') String get postPurchaseRestMethod;@JsonKey(name: 'post_purchase_headers', fromJson: _headersFromJson) Map<String, String> get postPurchaseHeaders;@JsonKey(name: 'post_purchase_body') String get postPurchaseBody;
/// Create a copy of WebhookConfigurationApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WebhookConfigurationApiCopyWith<WebhookConfigurationApi> get copyWith => _$WebhookConfigurationApiCopyWithImpl<WebhookConfigurationApi>(this as WebhookConfigurationApi, _$identity);

  /// Serializes this WebhookConfigurationApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WebhookConfigurationApi&&(identical(other.returnUrl, returnUrl) || other.returnUrl == returnUrl)&&(identical(other.postPurchaseUrl, postPurchaseUrl) || other.postPurchaseUrl == postPurchaseUrl)&&(identical(other.postPurchaseRestMethod, postPurchaseRestMethod) || other.postPurchaseRestMethod == postPurchaseRestMethod)&&const DeepCollectionEquality().equals(other.postPurchaseHeaders, postPurchaseHeaders)&&(identical(other.postPurchaseBody, postPurchaseBody) || other.postPurchaseBody == postPurchaseBody));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,returnUrl,postPurchaseUrl,postPurchaseRestMethod,const DeepCollectionEquality().hash(postPurchaseHeaders),postPurchaseBody);

@override
String toString() {
  return 'WebhookConfigurationApi(returnUrl: $returnUrl, postPurchaseUrl: $postPurchaseUrl, postPurchaseRestMethod: $postPurchaseRestMethod, postPurchaseHeaders: $postPurchaseHeaders, postPurchaseBody: $postPurchaseBody)';
}


}

/// @nodoc
abstract mixin class $WebhookConfigurationApiCopyWith<$Res>  {
  factory $WebhookConfigurationApiCopyWith(WebhookConfigurationApi value, $Res Function(WebhookConfigurationApi) _then) = _$WebhookConfigurationApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'return_url') String returnUrl,@JsonKey(name: 'post_purchase_url') String postPurchaseUrl,@JsonKey(name: 'post_purchase_rest_method') String postPurchaseRestMethod,@JsonKey(name: 'post_purchase_headers', fromJson: _headersFromJson) Map<String, String> postPurchaseHeaders,@JsonKey(name: 'post_purchase_body') String postPurchaseBody
});




}
/// @nodoc
class _$WebhookConfigurationApiCopyWithImpl<$Res>
    implements $WebhookConfigurationApiCopyWith<$Res> {
  _$WebhookConfigurationApiCopyWithImpl(this._self, this._then);

  final WebhookConfigurationApi _self;
  final $Res Function(WebhookConfigurationApi) _then;

/// Create a copy of WebhookConfigurationApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? returnUrl = null,Object? postPurchaseUrl = null,Object? postPurchaseRestMethod = null,Object? postPurchaseHeaders = null,Object? postPurchaseBody = null,}) {
  return _then(_self.copyWith(
returnUrl: null == returnUrl ? _self.returnUrl : returnUrl // ignore: cast_nullable_to_non_nullable
as String,postPurchaseUrl: null == postPurchaseUrl ? _self.postPurchaseUrl : postPurchaseUrl // ignore: cast_nullable_to_non_nullable
as String,postPurchaseRestMethod: null == postPurchaseRestMethod ? _self.postPurchaseRestMethod : postPurchaseRestMethod // ignore: cast_nullable_to_non_nullable
as String,postPurchaseHeaders: null == postPurchaseHeaders ? _self.postPurchaseHeaders : postPurchaseHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>,postPurchaseBody: null == postPurchaseBody ? _self.postPurchaseBody : postPurchaseBody // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [WebhookConfigurationApi].
extension WebhookConfigurationApiPatterns on WebhookConfigurationApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WebhookConfigurationApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WebhookConfigurationApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WebhookConfigurationApi value)  $default,){
final _that = this;
switch (_that) {
case _WebhookConfigurationApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WebhookConfigurationApi value)?  $default,){
final _that = this;
switch (_that) {
case _WebhookConfigurationApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'return_url')  String returnUrl, @JsonKey(name: 'post_purchase_url')  String postPurchaseUrl, @JsonKey(name: 'post_purchase_rest_method')  String postPurchaseRestMethod, @JsonKey(name: 'post_purchase_headers', fromJson: _headersFromJson)  Map<String, String> postPurchaseHeaders, @JsonKey(name: 'post_purchase_body')  String postPurchaseBody)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WebhookConfigurationApi() when $default != null:
return $default(_that.returnUrl,_that.postPurchaseUrl,_that.postPurchaseRestMethod,_that.postPurchaseHeaders,_that.postPurchaseBody);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'return_url')  String returnUrl, @JsonKey(name: 'post_purchase_url')  String postPurchaseUrl, @JsonKey(name: 'post_purchase_rest_method')  String postPurchaseRestMethod, @JsonKey(name: 'post_purchase_headers', fromJson: _headersFromJson)  Map<String, String> postPurchaseHeaders, @JsonKey(name: 'post_purchase_body')  String postPurchaseBody)  $default,) {final _that = this;
switch (_that) {
case _WebhookConfigurationApi():
return $default(_that.returnUrl,_that.postPurchaseUrl,_that.postPurchaseRestMethod,_that.postPurchaseHeaders,_that.postPurchaseBody);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'return_url')  String returnUrl, @JsonKey(name: 'post_purchase_url')  String postPurchaseUrl, @JsonKey(name: 'post_purchase_rest_method')  String postPurchaseRestMethod, @JsonKey(name: 'post_purchase_headers', fromJson: _headersFromJson)  Map<String, String> postPurchaseHeaders, @JsonKey(name: 'post_purchase_body')  String postPurchaseBody)?  $default,) {final _that = this;
switch (_that) {
case _WebhookConfigurationApi() when $default != null:
return $default(_that.returnUrl,_that.postPurchaseUrl,_that.postPurchaseRestMethod,_that.postPurchaseHeaders,_that.postPurchaseBody);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WebhookConfigurationApi implements WebhookConfigurationApi {
  const _WebhookConfigurationApi({@JsonKey(name: 'return_url') this.returnUrl = '', @JsonKey(name: 'post_purchase_url') this.postPurchaseUrl = '', @JsonKey(name: 'post_purchase_rest_method') this.postPurchaseRestMethod = '', @JsonKey(name: 'post_purchase_headers', fromJson: _headersFromJson) final  Map<String, String> postPurchaseHeaders = const <String, String>{}, @JsonKey(name: 'post_purchase_body') this.postPurchaseBody = ''}): _postPurchaseHeaders = postPurchaseHeaders;
  factory _WebhookConfigurationApi.fromJson(Map<String, dynamic> json) => _$WebhookConfigurationApiFromJson(json);

@override@JsonKey(name: 'return_url') final  String returnUrl;
@override@JsonKey(name: 'post_purchase_url') final  String postPurchaseUrl;
@override@JsonKey(name: 'post_purchase_rest_method') final  String postPurchaseRestMethod;
 final  Map<String, String> _postPurchaseHeaders;
@override@JsonKey(name: 'post_purchase_headers', fromJson: _headersFromJson) Map<String, String> get postPurchaseHeaders {
  if (_postPurchaseHeaders is EqualUnmodifiableMapView) return _postPurchaseHeaders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_postPurchaseHeaders);
}

@override@JsonKey(name: 'post_purchase_body') final  String postPurchaseBody;

/// Create a copy of WebhookConfigurationApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WebhookConfigurationApiCopyWith<_WebhookConfigurationApi> get copyWith => __$WebhookConfigurationApiCopyWithImpl<_WebhookConfigurationApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WebhookConfigurationApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WebhookConfigurationApi&&(identical(other.returnUrl, returnUrl) || other.returnUrl == returnUrl)&&(identical(other.postPurchaseUrl, postPurchaseUrl) || other.postPurchaseUrl == postPurchaseUrl)&&(identical(other.postPurchaseRestMethod, postPurchaseRestMethod) || other.postPurchaseRestMethod == postPurchaseRestMethod)&&const DeepCollectionEquality().equals(other._postPurchaseHeaders, _postPurchaseHeaders)&&(identical(other.postPurchaseBody, postPurchaseBody) || other.postPurchaseBody == postPurchaseBody));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,returnUrl,postPurchaseUrl,postPurchaseRestMethod,const DeepCollectionEquality().hash(_postPurchaseHeaders),postPurchaseBody);

@override
String toString() {
  return 'WebhookConfigurationApi(returnUrl: $returnUrl, postPurchaseUrl: $postPurchaseUrl, postPurchaseRestMethod: $postPurchaseRestMethod, postPurchaseHeaders: $postPurchaseHeaders, postPurchaseBody: $postPurchaseBody)';
}


}

/// @nodoc
abstract mixin class _$WebhookConfigurationApiCopyWith<$Res> implements $WebhookConfigurationApiCopyWith<$Res> {
  factory _$WebhookConfigurationApiCopyWith(_WebhookConfigurationApi value, $Res Function(_WebhookConfigurationApi) _then) = __$WebhookConfigurationApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'return_url') String returnUrl,@JsonKey(name: 'post_purchase_url') String postPurchaseUrl,@JsonKey(name: 'post_purchase_rest_method') String postPurchaseRestMethod,@JsonKey(name: 'post_purchase_headers', fromJson: _headersFromJson) Map<String, String> postPurchaseHeaders,@JsonKey(name: 'post_purchase_body') String postPurchaseBody
});




}
/// @nodoc
class __$WebhookConfigurationApiCopyWithImpl<$Res>
    implements _$WebhookConfigurationApiCopyWith<$Res> {
  __$WebhookConfigurationApiCopyWithImpl(this._self, this._then);

  final _WebhookConfigurationApi _self;
  final $Res Function(_WebhookConfigurationApi) _then;

/// Create a copy of WebhookConfigurationApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? returnUrl = null,Object? postPurchaseUrl = null,Object? postPurchaseRestMethod = null,Object? postPurchaseHeaders = null,Object? postPurchaseBody = null,}) {
  return _then(_WebhookConfigurationApi(
returnUrl: null == returnUrl ? _self.returnUrl : returnUrl // ignore: cast_nullable_to_non_nullable
as String,postPurchaseUrl: null == postPurchaseUrl ? _self.postPurchaseUrl : postPurchaseUrl // ignore: cast_nullable_to_non_nullable
as String,postPurchaseRestMethod: null == postPurchaseRestMethod ? _self.postPurchaseRestMethod : postPurchaseRestMethod // ignore: cast_nullable_to_non_nullable
as String,postPurchaseHeaders: null == postPurchaseHeaders ? _self._postPurchaseHeaders : postPurchaseHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>,postPurchaseBody: null == postPurchaseBody ? _self.postPurchaseBody : postPurchaseBody // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SubscriptionListApi {

@JsonKey(fromJson: _subscriptionListData) List<SubscriptionApi> get data;
/// Create a copy of SubscriptionListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionListApiCopyWith<SubscriptionListApi> get copyWith => _$SubscriptionListApiCopyWithImpl<SubscriptionListApi>(this as SubscriptionListApi, _$identity);

  /// Serializes this SubscriptionListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'SubscriptionListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $SubscriptionListApiCopyWith<$Res>  {
  factory $SubscriptionListApiCopyWith(SubscriptionListApi value, $Res Function(SubscriptionListApi) _then) = _$SubscriptionListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _subscriptionListData) List<SubscriptionApi> data
});




}
/// @nodoc
class _$SubscriptionListApiCopyWithImpl<$Res>
    implements $SubscriptionListApiCopyWith<$Res> {
  _$SubscriptionListApiCopyWithImpl(this._self, this._then);

  final SubscriptionListApi _self;
  final $Res Function(SubscriptionListApi) _then;

/// Create a copy of SubscriptionListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<SubscriptionApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionListApi].
extension SubscriptionListApiPatterns on SubscriptionListApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionListApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionListApi value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionListApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionListApi value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionListApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _subscriptionListData)  List<SubscriptionApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionListApi() when $default != null:
return $default(_that.data);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _subscriptionListData)  List<SubscriptionApi> data)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionListApi():
return $default(_that.data);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _subscriptionListData)  List<SubscriptionApi> data)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionListApi implements SubscriptionListApi {
  const _SubscriptionListApi({@JsonKey(fromJson: _subscriptionListData) final  List<SubscriptionApi> data = const []}): _data = data;
  factory _SubscriptionListApi.fromJson(Map<String, dynamic> json) => _$SubscriptionListApiFromJson(json);

 final  List<SubscriptionApi> _data;
@override@JsonKey(fromJson: _subscriptionListData) List<SubscriptionApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of SubscriptionListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionListApiCopyWith<_SubscriptionListApi> get copyWith => __$SubscriptionListApiCopyWithImpl<_SubscriptionListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'SubscriptionListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionListApiCopyWith<$Res> implements $SubscriptionListApiCopyWith<$Res> {
  factory _$SubscriptionListApiCopyWith(_SubscriptionListApi value, $Res Function(_SubscriptionListApi) _then) = __$SubscriptionListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _subscriptionListData) List<SubscriptionApi> data
});




}
/// @nodoc
class __$SubscriptionListApiCopyWithImpl<$Res>
    implements _$SubscriptionListApiCopyWith<$Res> {
  __$SubscriptionListApiCopyWithImpl(this._self, this._then);

  final _SubscriptionListApi _self;
  final $Res Function(_SubscriptionListApi) _then;

/// Create a copy of SubscriptionListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_SubscriptionListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<SubscriptionApi>,
  ));
}


}


/// @nodoc
mixin _$SubscriptionItemApi {

 SubscriptionApi get data;
/// Create a copy of SubscriptionItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionItemApiCopyWith<SubscriptionItemApi> get copyWith => _$SubscriptionItemApiCopyWithImpl<SubscriptionItemApi>(this as SubscriptionItemApi, _$identity);

  /// Serializes this SubscriptionItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'SubscriptionItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $SubscriptionItemApiCopyWith<$Res>  {
  factory $SubscriptionItemApiCopyWith(SubscriptionItemApi value, $Res Function(SubscriptionItemApi) _then) = _$SubscriptionItemApiCopyWithImpl;
@useResult
$Res call({
 SubscriptionApi data
});


$SubscriptionApiCopyWith<$Res> get data;

}
/// @nodoc
class _$SubscriptionItemApiCopyWithImpl<$Res>
    implements $SubscriptionItemApiCopyWith<$Res> {
  _$SubscriptionItemApiCopyWithImpl(this._self, this._then);

  final SubscriptionItemApi _self;
  final $Res Function(SubscriptionItemApi) _then;

/// Create a copy of SubscriptionItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as SubscriptionApi,
  ));
}
/// Create a copy of SubscriptionItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionApiCopyWith<$Res> get data {
  
  return $SubscriptionApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [SubscriptionItemApi].
extension SubscriptionItemApiPatterns on SubscriptionItemApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionItemApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionItemApi value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionItemApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionItemApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( SubscriptionApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionItemApi() when $default != null:
return $default(_that.data);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( SubscriptionApi data)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionItemApi():
return $default(_that.data);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( SubscriptionApi data)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionItemApi implements SubscriptionItemApi {
  const _SubscriptionItemApi({required this.data});
  factory _SubscriptionItemApi.fromJson(Map<String, dynamic> json) => _$SubscriptionItemApiFromJson(json);

@override final  SubscriptionApi data;

/// Create a copy of SubscriptionItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionItemApiCopyWith<_SubscriptionItemApi> get copyWith => __$SubscriptionItemApiCopyWithImpl<_SubscriptionItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'SubscriptionItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionItemApiCopyWith<$Res> implements $SubscriptionItemApiCopyWith<$Res> {
  factory _$SubscriptionItemApiCopyWith(_SubscriptionItemApi value, $Res Function(_SubscriptionItemApi) _then) = __$SubscriptionItemApiCopyWithImpl;
@override @useResult
$Res call({
 SubscriptionApi data
});


@override $SubscriptionApiCopyWith<$Res> get data;

}
/// @nodoc
class __$SubscriptionItemApiCopyWithImpl<$Res>
    implements _$SubscriptionItemApiCopyWith<$Res> {
  __$SubscriptionItemApiCopyWithImpl(this._self, this._then);

  final _SubscriptionItemApi _self;
  final $Res Function(_SubscriptionItemApi) _then;

/// Create a copy of SubscriptionItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_SubscriptionItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as SubscriptionApi,
  ));
}

/// Create a copy of SubscriptionItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionApiCopyWith<$Res> get data {
  
  return $SubscriptionApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// @nodoc
mixin _$SubscriptionStepApi {

 String get id; String get label; List<String> get dependencies;
/// Create a copy of SubscriptionStepApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionStepApiCopyWith<SubscriptionStepApi> get copyWith => _$SubscriptionStepApiCopyWithImpl<SubscriptionStepApi>(this as SubscriptionStepApi, _$identity);

  /// Serializes this SubscriptionStepApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionStepApi&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&const DeepCollectionEquality().equals(other.dependencies, dependencies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,const DeepCollectionEquality().hash(dependencies));

@override
String toString() {
  return 'SubscriptionStepApi(id: $id, label: $label, dependencies: $dependencies)';
}


}

/// @nodoc
abstract mixin class $SubscriptionStepApiCopyWith<$Res>  {
  factory $SubscriptionStepApiCopyWith(SubscriptionStepApi value, $Res Function(SubscriptionStepApi) _then) = _$SubscriptionStepApiCopyWithImpl;
@useResult
$Res call({
 String id, String label, List<String> dependencies
});




}
/// @nodoc
class _$SubscriptionStepApiCopyWithImpl<$Res>
    implements $SubscriptionStepApiCopyWith<$Res> {
  _$SubscriptionStepApiCopyWithImpl(this._self, this._then);

  final SubscriptionStepApi _self;
  final $Res Function(SubscriptionStepApi) _then;

/// Create a copy of SubscriptionStepApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? label = null,Object? dependencies = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,dependencies: null == dependencies ? _self.dependencies : dependencies // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionStepApi].
extension SubscriptionStepApiPatterns on SubscriptionStepApi {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionStepApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionStepApi() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionStepApi value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionStepApi():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionStepApi value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionStepApi() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String label,  List<String> dependencies)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionStepApi() when $default != null:
return $default(_that.id,_that.label,_that.dependencies);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String label,  List<String> dependencies)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionStepApi():
return $default(_that.id,_that.label,_that.dependencies);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String label,  List<String> dependencies)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionStepApi() when $default != null:
return $default(_that.id,_that.label,_that.dependencies);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionStepApi implements SubscriptionStepApi {
  const _SubscriptionStepApi({this.id = '', this.label = '', final  List<String> dependencies = const <String>[]}): _dependencies = dependencies;
  factory _SubscriptionStepApi.fromJson(Map<String, dynamic> json) => _$SubscriptionStepApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String label;
 final  List<String> _dependencies;
@override@JsonKey() List<String> get dependencies {
  if (_dependencies is EqualUnmodifiableListView) return _dependencies;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_dependencies);
}


/// Create a copy of SubscriptionStepApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionStepApiCopyWith<_SubscriptionStepApi> get copyWith => __$SubscriptionStepApiCopyWithImpl<_SubscriptionStepApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionStepApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionStepApi&&(identical(other.id, id) || other.id == id)&&(identical(other.label, label) || other.label == label)&&const DeepCollectionEquality().equals(other._dependencies, _dependencies));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,label,const DeepCollectionEquality().hash(_dependencies));

@override
String toString() {
  return 'SubscriptionStepApi(id: $id, label: $label, dependencies: $dependencies)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionStepApiCopyWith<$Res> implements $SubscriptionStepApiCopyWith<$Res> {
  factory _$SubscriptionStepApiCopyWith(_SubscriptionStepApi value, $Res Function(_SubscriptionStepApi) _then) = __$SubscriptionStepApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String label, List<String> dependencies
});




}
/// @nodoc
class __$SubscriptionStepApiCopyWithImpl<$Res>
    implements _$SubscriptionStepApiCopyWith<$Res> {
  __$SubscriptionStepApiCopyWithImpl(this._self, this._then);

  final _SubscriptionStepApi _self;
  final $Res Function(_SubscriptionStepApi) _then;

/// Create a copy of SubscriptionStepApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? label = null,Object? dependencies = null,}) {
  return _then(_SubscriptionStepApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,dependencies: null == dependencies ? _self._dependencies : dependencies // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

// dart format on
