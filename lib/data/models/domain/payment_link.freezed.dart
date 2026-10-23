// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_link.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$PaymentLink {

 String get id; String get userId; String get assignedUserId; String get companyId; String get name; Decimal get price; String get currencyId; String get frequencyId; String get productIds; String get recurringProductIds; String get optionalProductIds; String get optionalRecurringProductIds; String get groupId; String get autoBill; int get remainingCycles; int get refundPeriod; bool get trialEnabled; int get trialDuration; String get promoCode; Decimal get promoDiscount; Decimal get promoPrice; bool get isAmountDiscount; bool get allowCancellation; bool get allowPlanChanges; bool get allowQueryOverrides; bool get registrationRequired; bool get useInventoryManagement; bool get perSeatEnabled; int get maxSeatsLimit; PaymentLinkWebhook get webhookConfiguration; String get steps; String get purchasePage; String get planMap; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; bool get isDeleted; bool get isDirty;
/// Create a copy of PaymentLink
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentLinkCopyWith<PaymentLink> get copyWith => _$PaymentLinkCopyWithImpl<PaymentLink>(this as PaymentLink, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PaymentLink;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentLink&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.assignedUserId, _this.assignedUserId) || other.assignedUserId == _this.assignedUserId)&&(identical(other.companyId, _this.companyId) || other.companyId == _this.companyId)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.price, _this.price) || other.price == _this.price)&&(identical(other.currencyId, _this.currencyId) || other.currencyId == _this.currencyId)&&(identical(other.frequencyId, _this.frequencyId) || other.frequencyId == _this.frequencyId)&&(identical(other.productIds, _this.productIds) || other.productIds == _this.productIds)&&(identical(other.recurringProductIds, _this.recurringProductIds) || other.recurringProductIds == _this.recurringProductIds)&&(identical(other.optionalProductIds, _this.optionalProductIds) || other.optionalProductIds == _this.optionalProductIds)&&(identical(other.optionalRecurringProductIds, _this.optionalRecurringProductIds) || other.optionalRecurringProductIds == _this.optionalRecurringProductIds)&&(identical(other.groupId, _this.groupId) || other.groupId == _this.groupId)&&(identical(other.autoBill, _this.autoBill) || other.autoBill == _this.autoBill)&&(identical(other.remainingCycles, _this.remainingCycles) || other.remainingCycles == _this.remainingCycles)&&(identical(other.refundPeriod, _this.refundPeriod) || other.refundPeriod == _this.refundPeriod)&&(identical(other.trialEnabled, _this.trialEnabled) || other.trialEnabled == _this.trialEnabled)&&(identical(other.trialDuration, _this.trialDuration) || other.trialDuration == _this.trialDuration)&&(identical(other.promoCode, _this.promoCode) || other.promoCode == _this.promoCode)&&(identical(other.promoDiscount, _this.promoDiscount) || other.promoDiscount == _this.promoDiscount)&&(identical(other.promoPrice, _this.promoPrice) || other.promoPrice == _this.promoPrice)&&(identical(other.isAmountDiscount, _this.isAmountDiscount) || other.isAmountDiscount == _this.isAmountDiscount)&&(identical(other.allowCancellation, _this.allowCancellation) || other.allowCancellation == _this.allowCancellation)&&(identical(other.allowPlanChanges, _this.allowPlanChanges) || other.allowPlanChanges == _this.allowPlanChanges)&&(identical(other.allowQueryOverrides, _this.allowQueryOverrides) || other.allowQueryOverrides == _this.allowQueryOverrides)&&(identical(other.registrationRequired, _this.registrationRequired) || other.registrationRequired == _this.registrationRequired)&&(identical(other.useInventoryManagement, _this.useInventoryManagement) || other.useInventoryManagement == _this.useInventoryManagement)&&(identical(other.perSeatEnabled, _this.perSeatEnabled) || other.perSeatEnabled == _this.perSeatEnabled)&&(identical(other.maxSeatsLimit, _this.maxSeatsLimit) || other.maxSeatsLimit == _this.maxSeatsLimit)&&(identical(other.webhookConfiguration, _this.webhookConfiguration) || other.webhookConfiguration == _this.webhookConfiguration)&&(identical(other.steps, _this.steps) || other.steps == _this.steps)&&(identical(other.purchasePage, _this.purchasePage) || other.purchasePage == _this.purchasePage)&&(identical(other.planMap, _this.planMap) || other.planMap == _this.planMap)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt)&&(identical(other.isDeleted, _this.isDeleted) || other.isDeleted == _this.isDeleted)&&(identical(other.isDirty, _this.isDirty) || other.isDirty == _this.isDirty));
}


@override
int get hashCode {
  final _this = this as PaymentLink;
  return Object.hashAll([runtimeType,_this.id,_this.userId,_this.assignedUserId,_this.companyId,_this.name,_this.price,_this.currencyId,_this.frequencyId,_this.productIds,_this.recurringProductIds,_this.optionalProductIds,_this.optionalRecurringProductIds,_this.groupId,_this.autoBill,_this.remainingCycles,_this.refundPeriod,_this.trialEnabled,_this.trialDuration,_this.promoCode,_this.promoDiscount,_this.promoPrice,_this.isAmountDiscount,_this.allowCancellation,_this.allowPlanChanges,_this.allowQueryOverrides,_this.registrationRequired,_this.useInventoryManagement,_this.perSeatEnabled,_this.maxSeatsLimit,_this.webhookConfiguration,_this.steps,_this.purchasePage,_this.planMap,_this.updatedAt,_this.createdAt,_this.archivedAt,_this.isDeleted,_this.isDirty]);
}

@override
String toString() {
  final _this = this as PaymentLink;
  return 'PaymentLink(id: ${_this.id}, userId: ${_this.userId}, assignedUserId: ${_this.assignedUserId}, companyId: ${_this.companyId}, name: ${_this.name}, price: ${_this.price}, currencyId: ${_this.currencyId}, frequencyId: ${_this.frequencyId}, productIds: ${_this.productIds}, recurringProductIds: ${_this.recurringProductIds}, optionalProductIds: ${_this.optionalProductIds}, optionalRecurringProductIds: ${_this.optionalRecurringProductIds}, groupId: ${_this.groupId}, autoBill: ${_this.autoBill}, remainingCycles: ${_this.remainingCycles}, refundPeriod: ${_this.refundPeriod}, trialEnabled: ${_this.trialEnabled}, trialDuration: ${_this.trialDuration}, promoCode: ${_this.promoCode}, promoDiscount: ${_this.promoDiscount}, promoPrice: ${_this.promoPrice}, isAmountDiscount: ${_this.isAmountDiscount}, allowCancellation: ${_this.allowCancellation}, allowPlanChanges: ${_this.allowPlanChanges}, allowQueryOverrides: ${_this.allowQueryOverrides}, registrationRequired: ${_this.registrationRequired}, useInventoryManagement: ${_this.useInventoryManagement}, perSeatEnabled: ${_this.perSeatEnabled}, maxSeatsLimit: ${_this.maxSeatsLimit}, webhookConfiguration: ${_this.webhookConfiguration}, steps: ${_this.steps}, purchasePage: ${_this.purchasePage}, planMap: ${_this.planMap}, updatedAt: ${_this.updatedAt}, createdAt: ${_this.createdAt}, archivedAt: ${_this.archivedAt}, isDeleted: ${_this.isDeleted}, isDirty: ${_this.isDirty})';
}


}

/// @nodoc
abstract mixin class $PaymentLinkCopyWith<$Res>  {
  factory $PaymentLinkCopyWith(PaymentLink value, $Res Function(PaymentLink) _then) = _$PaymentLinkCopyWithImpl;
@useResult
$Res call({
 String id, String userId, String assignedUserId, String companyId, String name, Decimal price, String currencyId, String frequencyId, String productIds, String recurringProductIds, String optionalProductIds, String optionalRecurringProductIds, String groupId, String autoBill, int remainingCycles, int refundPeriod, bool trialEnabled, int trialDuration, String promoCode, Decimal promoDiscount, Decimal promoPrice, bool isAmountDiscount, bool allowCancellation, bool allowPlanChanges, bool allowQueryOverrides, bool registrationRequired, bool useInventoryManagement, bool perSeatEnabled, int maxSeatsLimit, PaymentLinkWebhook webhookConfiguration, String steps, String purchasePage, String planMap, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, bool isDirty
});


$PaymentLinkWebhookCopyWith<$Res> get webhookConfiguration;

}
/// @nodoc
class _$PaymentLinkCopyWithImpl<$Res>
    implements $PaymentLinkCopyWith<$Res> {
  _$PaymentLinkCopyWithImpl(this._self, this._then);

  final PaymentLink _self;
  final $Res Function(PaymentLink) _then;

/// Create a copy of PaymentLink
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? companyId = null,Object? name = null,Object? price = null,Object? currencyId = null,Object? frequencyId = null,Object? productIds = null,Object? recurringProductIds = null,Object? optionalProductIds = null,Object? optionalRecurringProductIds = null,Object? groupId = null,Object? autoBill = null,Object? remainingCycles = null,Object? refundPeriod = null,Object? trialEnabled = null,Object? trialDuration = null,Object? promoCode = null,Object? promoDiscount = null,Object? promoPrice = null,Object? isAmountDiscount = null,Object? allowCancellation = null,Object? allowPlanChanges = null,Object? allowQueryOverrides = null,Object? registrationRequired = null,Object? useInventoryManagement = null,Object? perSeatEnabled = null,Object? maxSeatsLimit = null,Object? webhookConfiguration = null,Object? steps = null,Object? purchasePage = null,Object? planMap = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? isDirty = null,}) {
  return _then(PaymentLink(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as Decimal,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
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
as String,promoDiscount: null == promoDiscount ? _self.promoDiscount : promoDiscount // ignore: cast_nullable_to_non_nullable
as Decimal,promoPrice: null == promoPrice ? _self.promoPrice : promoPrice // ignore: cast_nullable_to_non_nullable
as Decimal,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
as bool,allowCancellation: null == allowCancellation ? _self.allowCancellation : allowCancellation // ignore: cast_nullable_to_non_nullable
as bool,allowPlanChanges: null == allowPlanChanges ? _self.allowPlanChanges : allowPlanChanges // ignore: cast_nullable_to_non_nullable
as bool,allowQueryOverrides: null == allowQueryOverrides ? _self.allowQueryOverrides : allowQueryOverrides // ignore: cast_nullable_to_non_nullable
as bool,registrationRequired: null == registrationRequired ? _self.registrationRequired : registrationRequired // ignore: cast_nullable_to_non_nullable
as bool,useInventoryManagement: null == useInventoryManagement ? _self.useInventoryManagement : useInventoryManagement // ignore: cast_nullable_to_non_nullable
as bool,perSeatEnabled: null == perSeatEnabled ? _self.perSeatEnabled : perSeatEnabled // ignore: cast_nullable_to_non_nullable
as bool,maxSeatsLimit: null == maxSeatsLimit ? _self.maxSeatsLimit : maxSeatsLimit // ignore: cast_nullable_to_non_nullable
as int,webhookConfiguration: null == webhookConfiguration ? _self.webhookConfiguration : webhookConfiguration // ignore: cast_nullable_to_non_nullable
as PaymentLinkWebhook,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as String,purchasePage: null == purchasePage ? _self.purchasePage : purchasePage // ignore: cast_nullable_to_non_nullable
as String,planMap: null == planMap ? _self.planMap : planMap // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of PaymentLink
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentLinkWebhookCopyWith<$Res> get webhookConfiguration {
  
  return $PaymentLinkWebhookCopyWith<$Res>(_self.webhookConfiguration, (value) {
    return _then(_self.copyWith(webhookConfiguration: value));
  });
}
}


/// Adds pattern-matching-related methods to [PaymentLink].
extension PaymentLinkPatterns on PaymentLink {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentLink value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentLink() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentLink value)  $default,){
final _that = this;
switch (_that) {
case _PaymentLink():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentLink value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentLink() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String userId,  String assignedUserId,  String companyId,  String name,  Decimal price,  String currencyId,  String frequencyId,  String productIds,  String recurringProductIds,  String optionalProductIds,  String optionalRecurringProductIds,  String groupId,  String autoBill,  int remainingCycles,  int refundPeriod,  bool trialEnabled,  int trialDuration,  String promoCode,  Decimal promoDiscount,  Decimal promoPrice,  bool isAmountDiscount,  bool allowCancellation,  bool allowPlanChanges,  bool allowQueryOverrides,  bool registrationRequired,  bool useInventoryManagement,  bool perSeatEnabled,  int maxSeatsLimit,  PaymentLinkWebhook webhookConfiguration,  String steps,  String purchasePage,  String planMap,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentLink() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.companyId,_that.name,_that.price,_that.currencyId,_that.frequencyId,_that.productIds,_that.recurringProductIds,_that.optionalProductIds,_that.optionalRecurringProductIds,_that.groupId,_that.autoBill,_that.remainingCycles,_that.refundPeriod,_that.trialEnabled,_that.trialDuration,_that.promoCode,_that.promoDiscount,_that.promoPrice,_that.isAmountDiscount,_that.allowCancellation,_that.allowPlanChanges,_that.allowQueryOverrides,_that.registrationRequired,_that.useInventoryManagement,_that.perSeatEnabled,_that.maxSeatsLimit,_that.webhookConfiguration,_that.steps,_that.purchasePage,_that.planMap,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String userId,  String assignedUserId,  String companyId,  String name,  Decimal price,  String currencyId,  String frequencyId,  String productIds,  String recurringProductIds,  String optionalProductIds,  String optionalRecurringProductIds,  String groupId,  String autoBill,  int remainingCycles,  int refundPeriod,  bool trialEnabled,  int trialDuration,  String promoCode,  Decimal promoDiscount,  Decimal promoPrice,  bool isAmountDiscount,  bool allowCancellation,  bool allowPlanChanges,  bool allowQueryOverrides,  bool registrationRequired,  bool useInventoryManagement,  bool perSeatEnabled,  int maxSeatsLimit,  PaymentLinkWebhook webhookConfiguration,  String steps,  String purchasePage,  String planMap,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _PaymentLink():
return $default(_that.id,_that.userId,_that.assignedUserId,_that.companyId,_that.name,_that.price,_that.currencyId,_that.frequencyId,_that.productIds,_that.recurringProductIds,_that.optionalProductIds,_that.optionalRecurringProductIds,_that.groupId,_that.autoBill,_that.remainingCycles,_that.refundPeriod,_that.trialEnabled,_that.trialDuration,_that.promoCode,_that.promoDiscount,_that.promoPrice,_that.isAmountDiscount,_that.allowCancellation,_that.allowPlanChanges,_that.allowQueryOverrides,_that.registrationRequired,_that.useInventoryManagement,_that.perSeatEnabled,_that.maxSeatsLimit,_that.webhookConfiguration,_that.steps,_that.purchasePage,_that.planMap,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String userId,  String assignedUserId,  String companyId,  String name,  Decimal price,  String currencyId,  String frequencyId,  String productIds,  String recurringProductIds,  String optionalProductIds,  String optionalRecurringProductIds,  String groupId,  String autoBill,  int remainingCycles,  int refundPeriod,  bool trialEnabled,  int trialDuration,  String promoCode,  Decimal promoDiscount,  Decimal promoPrice,  bool isAmountDiscount,  bool allowCancellation,  bool allowPlanChanges,  bool allowQueryOverrides,  bool registrationRequired,  bool useInventoryManagement,  bool perSeatEnabled,  int maxSeatsLimit,  PaymentLinkWebhook webhookConfiguration,  String steps,  String purchasePage,  String planMap,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _PaymentLink() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.companyId,_that.name,_that.price,_that.currencyId,_that.frequencyId,_that.productIds,_that.recurringProductIds,_that.optionalProductIds,_that.optionalRecurringProductIds,_that.groupId,_that.autoBill,_that.remainingCycles,_that.refundPeriod,_that.trialEnabled,_that.trialDuration,_that.promoCode,_that.promoDiscount,_that.promoPrice,_that.isAmountDiscount,_that.allowCancellation,_that.allowPlanChanges,_that.allowQueryOverrides,_that.registrationRequired,_that.useInventoryManagement,_that.perSeatEnabled,_that.maxSeatsLimit,_that.webhookConfiguration,_that.steps,_that.purchasePage,_that.planMap,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _PaymentLink implements PaymentLink {
  const _PaymentLink({required this.id, required this.userId, required this.assignedUserId, required this.companyId, required this.name, required this.price, required this.currencyId, required this.frequencyId, required this.productIds, required this.recurringProductIds, required this.optionalProductIds, required this.optionalRecurringProductIds, required this.groupId, required this.autoBill, required this.remainingCycles, required this.refundPeriod, required this.trialEnabled, required this.trialDuration, required this.promoCode, required this.promoDiscount, required this.promoPrice, required this.isAmountDiscount, required this.allowCancellation, required this.allowPlanChanges, required this.allowQueryOverrides, required this.registrationRequired, required this.useInventoryManagement, required this.perSeatEnabled, required this.maxSeatsLimit, required this.webhookConfiguration, required this.steps, required this.purchasePage, required this.planMap, required this.updatedAt, required this.createdAt, required this.archivedAt, required this.isDeleted, this.isDirty = false});
  

@override final  String id;
@override final  String userId;
@override final  String assignedUserId;
@override final  String companyId;
@override final  String name;
@override final  Decimal price;
@override final  String currencyId;
@override final  String frequencyId;
@override final  String productIds;
@override final  String recurringProductIds;
@override final  String optionalProductIds;
@override final  String optionalRecurringProductIds;
@override final  String groupId;
@override final  String autoBill;
@override final  int remainingCycles;
@override final  int refundPeriod;
@override final  bool trialEnabled;
@override final  int trialDuration;
@override final  String promoCode;
@override final  Decimal promoDiscount;
@override final  Decimal promoPrice;
@override final  bool isAmountDiscount;
@override final  bool allowCancellation;
@override final  bool allowPlanChanges;
@override final  bool allowQueryOverrides;
@override final  bool registrationRequired;
@override final  bool useInventoryManagement;
@override final  bool perSeatEnabled;
@override final  int maxSeatsLimit;
@override final  PaymentLinkWebhook webhookConfiguration;
@override final  String steps;
@override final  String purchasePage;
@override final  String planMap;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
@override final  bool isDeleted;
@override@JsonKey() final  bool isDirty;

/// Create a copy of PaymentLink
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentLinkCopyWith<_PaymentLink> get copyWith => __$PaymentLinkCopyWithImpl<_PaymentLink>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentLink&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.name, name) || other.name == name)&&(identical(other.price, price) || other.price == price)&&(identical(other.currencyId, currencyId) || other.currencyId == currencyId)&&(identical(other.frequencyId, frequencyId) || other.frequencyId == frequencyId)&&(identical(other.productIds, productIds) || other.productIds == productIds)&&(identical(other.recurringProductIds, recurringProductIds) || other.recurringProductIds == recurringProductIds)&&(identical(other.optionalProductIds, optionalProductIds) || other.optionalProductIds == optionalProductIds)&&(identical(other.optionalRecurringProductIds, optionalRecurringProductIds) || other.optionalRecurringProductIds == optionalRecurringProductIds)&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.autoBill, autoBill) || other.autoBill == autoBill)&&(identical(other.remainingCycles, remainingCycles) || other.remainingCycles == remainingCycles)&&(identical(other.refundPeriod, refundPeriod) || other.refundPeriod == refundPeriod)&&(identical(other.trialEnabled, trialEnabled) || other.trialEnabled == trialEnabled)&&(identical(other.trialDuration, trialDuration) || other.trialDuration == trialDuration)&&(identical(other.promoCode, promoCode) || other.promoCode == promoCode)&&(identical(other.promoDiscount, promoDiscount) || other.promoDiscount == promoDiscount)&&(identical(other.promoPrice, promoPrice) || other.promoPrice == promoPrice)&&(identical(other.isAmountDiscount, isAmountDiscount) || other.isAmountDiscount == isAmountDiscount)&&(identical(other.allowCancellation, allowCancellation) || other.allowCancellation == allowCancellation)&&(identical(other.allowPlanChanges, allowPlanChanges) || other.allowPlanChanges == allowPlanChanges)&&(identical(other.allowQueryOverrides, allowQueryOverrides) || other.allowQueryOverrides == allowQueryOverrides)&&(identical(other.registrationRequired, registrationRequired) || other.registrationRequired == registrationRequired)&&(identical(other.useInventoryManagement, useInventoryManagement) || other.useInventoryManagement == useInventoryManagement)&&(identical(other.perSeatEnabled, perSeatEnabled) || other.perSeatEnabled == perSeatEnabled)&&(identical(other.maxSeatsLimit, maxSeatsLimit) || other.maxSeatsLimit == maxSeatsLimit)&&(identical(other.webhookConfiguration, webhookConfiguration) || other.webhookConfiguration == webhookConfiguration)&&(identical(other.steps, steps) || other.steps == steps)&&(identical(other.purchasePage, purchasePage) || other.purchasePage == purchasePage)&&(identical(other.planMap, planMap) || other.planMap == planMap)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,id,userId,assignedUserId,companyId,name,price,currencyId,frequencyId,productIds,recurringProductIds,optionalProductIds,optionalRecurringProductIds,groupId,autoBill,remainingCycles,refundPeriod,trialEnabled,trialDuration,promoCode,promoDiscount,promoPrice,isAmountDiscount,allowCancellation,allowPlanChanges,allowQueryOverrides,registrationRequired,useInventoryManagement,perSeatEnabled,maxSeatsLimit,webhookConfiguration,steps,purchasePage,planMap,updatedAt,createdAt,archivedAt,isDeleted,isDirty]);
}

@override
String toString() {
    return 'PaymentLink(id: $id, userId: $userId, assignedUserId: $assignedUserId, companyId: $companyId, name: $name, price: $price, currencyId: $currencyId, frequencyId: $frequencyId, productIds: $productIds, recurringProductIds: $recurringProductIds, optionalProductIds: $optionalProductIds, optionalRecurringProductIds: $optionalRecurringProductIds, groupId: $groupId, autoBill: $autoBill, remainingCycles: $remainingCycles, refundPeriod: $refundPeriod, trialEnabled: $trialEnabled, trialDuration: $trialDuration, promoCode: $promoCode, promoDiscount: $promoDiscount, promoPrice: $promoPrice, isAmountDiscount: $isAmountDiscount, allowCancellation: $allowCancellation, allowPlanChanges: $allowPlanChanges, allowQueryOverrides: $allowQueryOverrides, registrationRequired: $registrationRequired, useInventoryManagement: $useInventoryManagement, perSeatEnabled: $perSeatEnabled, maxSeatsLimit: $maxSeatsLimit, webhookConfiguration: $webhookConfiguration, steps: $steps, purchasePage: $purchasePage, planMap: $planMap, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$PaymentLinkCopyWith<$Res> implements $PaymentLinkCopyWith<$Res> {
  factory _$PaymentLinkCopyWith(_PaymentLink value, $Res Function(_PaymentLink) _then) = __$PaymentLinkCopyWithImpl;
@override @useResult
$Res call({
 String id, String userId, String assignedUserId, String companyId, String name, Decimal price, String currencyId, String frequencyId, String productIds, String recurringProductIds, String optionalProductIds, String optionalRecurringProductIds, String groupId, String autoBill, int remainingCycles, int refundPeriod, bool trialEnabled, int trialDuration, String promoCode, Decimal promoDiscount, Decimal promoPrice, bool isAmountDiscount, bool allowCancellation, bool allowPlanChanges, bool allowQueryOverrides, bool registrationRequired, bool useInventoryManagement, bool perSeatEnabled, int maxSeatsLimit, PaymentLinkWebhook webhookConfiguration, String steps, String purchasePage, String planMap, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, bool isDirty
});


@override $PaymentLinkWebhookCopyWith<$Res> get webhookConfiguration;

}
/// @nodoc
class __$PaymentLinkCopyWithImpl<$Res>
    implements _$PaymentLinkCopyWith<$Res> {
  __$PaymentLinkCopyWithImpl(this._self, this._then);

  final _PaymentLink _self;
  final $Res Function(_PaymentLink) _then;

/// Create a copy of PaymentLink
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? companyId = null,Object? name = null,Object? price = null,Object? currencyId = null,Object? frequencyId = null,Object? productIds = null,Object? recurringProductIds = null,Object? optionalProductIds = null,Object? optionalRecurringProductIds = null,Object? groupId = null,Object? autoBill = null,Object? remainingCycles = null,Object? refundPeriod = null,Object? trialEnabled = null,Object? trialDuration = null,Object? promoCode = null,Object? promoDiscount = null,Object? promoPrice = null,Object? isAmountDiscount = null,Object? allowCancellation = null,Object? allowPlanChanges = null,Object? allowQueryOverrides = null,Object? registrationRequired = null,Object? useInventoryManagement = null,Object? perSeatEnabled = null,Object? maxSeatsLimit = null,Object? webhookConfiguration = null,Object? steps = null,Object? purchasePage = null,Object? planMap = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? isDirty = null,}) {
  return _then(_PaymentLink(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as Decimal,currencyId: null == currencyId ? _self.currencyId : currencyId // ignore: cast_nullable_to_non_nullable
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
as String,promoDiscount: null == promoDiscount ? _self.promoDiscount : promoDiscount // ignore: cast_nullable_to_non_nullable
as Decimal,promoPrice: null == promoPrice ? _self.promoPrice : promoPrice // ignore: cast_nullable_to_non_nullable
as Decimal,isAmountDiscount: null == isAmountDiscount ? _self.isAmountDiscount : isAmountDiscount // ignore: cast_nullable_to_non_nullable
as bool,allowCancellation: null == allowCancellation ? _self.allowCancellation : allowCancellation // ignore: cast_nullable_to_non_nullable
as bool,allowPlanChanges: null == allowPlanChanges ? _self.allowPlanChanges : allowPlanChanges // ignore: cast_nullable_to_non_nullable
as bool,allowQueryOverrides: null == allowQueryOverrides ? _self.allowQueryOverrides : allowQueryOverrides // ignore: cast_nullable_to_non_nullable
as bool,registrationRequired: null == registrationRequired ? _self.registrationRequired : registrationRequired // ignore: cast_nullable_to_non_nullable
as bool,useInventoryManagement: null == useInventoryManagement ? _self.useInventoryManagement : useInventoryManagement // ignore: cast_nullable_to_non_nullable
as bool,perSeatEnabled: null == perSeatEnabled ? _self.perSeatEnabled : perSeatEnabled // ignore: cast_nullable_to_non_nullable
as bool,maxSeatsLimit: null == maxSeatsLimit ? _self.maxSeatsLimit : maxSeatsLimit // ignore: cast_nullable_to_non_nullable
as int,webhookConfiguration: null == webhookConfiguration ? _self.webhookConfiguration : webhookConfiguration // ignore: cast_nullable_to_non_nullable
as PaymentLinkWebhook,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as String,purchasePage: null == purchasePage ? _self.purchasePage : purchasePage // ignore: cast_nullable_to_non_nullable
as String,planMap: null == planMap ? _self.planMap : planMap // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of PaymentLink
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentLinkWebhookCopyWith<$Res> get webhookConfiguration {
  
  return $PaymentLinkWebhookCopyWith<$Res>(_self.webhookConfiguration, (value) {
    return _then(_self.copyWith(webhookConfiguration: value));
  });
}
}

/// @nodoc
mixin _$PaymentLinkWebhook {

 String get returnUrl; String get postPurchaseUrl; String get postPurchaseRestMethod; Map<String, String> get postPurchaseHeaders; String get postPurchaseBody;
/// Create a copy of PaymentLinkWebhook
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentLinkWebhookCopyWith<PaymentLinkWebhook> get copyWith => _$PaymentLinkWebhookCopyWithImpl<PaymentLinkWebhook>(this as PaymentLinkWebhook, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PaymentLinkWebhook;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentLinkWebhook&&(identical(other.returnUrl, _this.returnUrl) || other.returnUrl == _this.returnUrl)&&(identical(other.postPurchaseUrl, _this.postPurchaseUrl) || other.postPurchaseUrl == _this.postPurchaseUrl)&&(identical(other.postPurchaseRestMethod, _this.postPurchaseRestMethod) || other.postPurchaseRestMethod == _this.postPurchaseRestMethod)&&const DeepCollectionEquality().equals(other.postPurchaseHeaders, _this.postPurchaseHeaders)&&(identical(other.postPurchaseBody, _this.postPurchaseBody) || other.postPurchaseBody == _this.postPurchaseBody));
}


@override
int get hashCode {
  final _this = this as PaymentLinkWebhook;
  return Object.hash(runtimeType,_this.returnUrl,_this.postPurchaseUrl,_this.postPurchaseRestMethod,const DeepCollectionEquality().hash(_this.postPurchaseHeaders),_this.postPurchaseBody);
}

@override
String toString() {
  final _this = this as PaymentLinkWebhook;
  return 'PaymentLinkWebhook(returnUrl: ${_this.returnUrl}, postPurchaseUrl: ${_this.postPurchaseUrl}, postPurchaseRestMethod: ${_this.postPurchaseRestMethod}, postPurchaseHeaders: ${_this.postPurchaseHeaders}, postPurchaseBody: ${_this.postPurchaseBody})';
}


}

/// @nodoc
abstract mixin class $PaymentLinkWebhookCopyWith<$Res>  {
  factory $PaymentLinkWebhookCopyWith(PaymentLinkWebhook value, $Res Function(PaymentLinkWebhook) _then) = _$PaymentLinkWebhookCopyWithImpl;
@useResult
$Res call({
 String returnUrl, String postPurchaseUrl, String postPurchaseRestMethod, Map<String, String> postPurchaseHeaders, String postPurchaseBody
});




}
/// @nodoc
class _$PaymentLinkWebhookCopyWithImpl<$Res>
    implements $PaymentLinkWebhookCopyWith<$Res> {
  _$PaymentLinkWebhookCopyWithImpl(this._self, this._then);

  final PaymentLinkWebhook _self;
  final $Res Function(PaymentLinkWebhook) _then;

/// Create a copy of PaymentLinkWebhook
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? returnUrl = null,Object? postPurchaseUrl = null,Object? postPurchaseRestMethod = null,Object? postPurchaseHeaders = null,Object? postPurchaseBody = null,}) {
  return _then(PaymentLinkWebhook(
returnUrl: null == returnUrl ? _self.returnUrl : returnUrl // ignore: cast_nullable_to_non_nullable
as String,postPurchaseUrl: null == postPurchaseUrl ? _self.postPurchaseUrl : postPurchaseUrl // ignore: cast_nullable_to_non_nullable
as String,postPurchaseRestMethod: null == postPurchaseRestMethod ? _self.postPurchaseRestMethod : postPurchaseRestMethod // ignore: cast_nullable_to_non_nullable
as String,postPurchaseHeaders: null == postPurchaseHeaders ? _self.postPurchaseHeaders : postPurchaseHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>,postPurchaseBody: null == postPurchaseBody ? _self.postPurchaseBody : postPurchaseBody // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentLinkWebhook].
extension PaymentLinkWebhookPatterns on PaymentLinkWebhook {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentLinkWebhook value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentLinkWebhook() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentLinkWebhook value)  $default,){
final _that = this;
switch (_that) {
case _PaymentLinkWebhook():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentLinkWebhook value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentLinkWebhook() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String returnUrl,  String postPurchaseUrl,  String postPurchaseRestMethod,  Map<String, String> postPurchaseHeaders,  String postPurchaseBody)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentLinkWebhook() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String returnUrl,  String postPurchaseUrl,  String postPurchaseRestMethod,  Map<String, String> postPurchaseHeaders,  String postPurchaseBody)  $default,) {final _that = this;
switch (_that) {
case _PaymentLinkWebhook():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String returnUrl,  String postPurchaseUrl,  String postPurchaseRestMethod,  Map<String, String> postPurchaseHeaders,  String postPurchaseBody)?  $default,) {final _that = this;
switch (_that) {
case _PaymentLinkWebhook() when $default != null:
return $default(_that.returnUrl,_that.postPurchaseUrl,_that.postPurchaseRestMethod,_that.postPurchaseHeaders,_that.postPurchaseBody);case _:
  return null;

}
}

}

/// @nodoc


class _PaymentLinkWebhook implements PaymentLinkWebhook {
  const _PaymentLinkWebhook({required this.returnUrl, required this.postPurchaseUrl, required this.postPurchaseRestMethod, required  Map<String, String> postPurchaseHeaders, required this.postPurchaseBody}): _postPurchaseHeaders = postPurchaseHeaders;
  

@override final  String returnUrl;
@override final  String postPurchaseUrl;
@override final  String postPurchaseRestMethod;
 final  Map<String, String> _postPurchaseHeaders;
@override Map<String, String> get postPurchaseHeaders {
  if (_postPurchaseHeaders is EqualUnmodifiableMapView) return _postPurchaseHeaders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_postPurchaseHeaders);
}

@override final  String postPurchaseBody;

/// Create a copy of PaymentLinkWebhook
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentLinkWebhookCopyWith<_PaymentLinkWebhook> get copyWith => __$PaymentLinkWebhookCopyWithImpl<_PaymentLinkWebhook>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentLinkWebhook&&(identical(other.returnUrl, returnUrl) || other.returnUrl == returnUrl)&&(identical(other.postPurchaseUrl, postPurchaseUrl) || other.postPurchaseUrl == postPurchaseUrl)&&(identical(other.postPurchaseRestMethod, postPurchaseRestMethod) || other.postPurchaseRestMethod == postPurchaseRestMethod)&&const DeepCollectionEquality().equals(other.postPurchaseHeaders, _postPurchaseHeaders)&&(identical(other.postPurchaseBody, postPurchaseBody) || other.postPurchaseBody == postPurchaseBody));
}


@override
int get hashCode {
    return Object.hash(runtimeType,returnUrl,postPurchaseUrl,postPurchaseRestMethod,const DeepCollectionEquality().hash(_postPurchaseHeaders),postPurchaseBody);
}

@override
String toString() {
    return 'PaymentLinkWebhook(returnUrl: $returnUrl, postPurchaseUrl: $postPurchaseUrl, postPurchaseRestMethod: $postPurchaseRestMethod, postPurchaseHeaders: $postPurchaseHeaders, postPurchaseBody: $postPurchaseBody)';
}


}

/// @nodoc
abstract mixin class _$PaymentLinkWebhookCopyWith<$Res> implements $PaymentLinkWebhookCopyWith<$Res> {
  factory _$PaymentLinkWebhookCopyWith(_PaymentLinkWebhook value, $Res Function(_PaymentLinkWebhook) _then) = __$PaymentLinkWebhookCopyWithImpl;
@override @useResult
$Res call({
 String returnUrl, String postPurchaseUrl, String postPurchaseRestMethod, Map<String, String> postPurchaseHeaders, String postPurchaseBody
});




}
/// @nodoc
class __$PaymentLinkWebhookCopyWithImpl<$Res>
    implements _$PaymentLinkWebhookCopyWith<$Res> {
  __$PaymentLinkWebhookCopyWithImpl(this._self, this._then);

  final _PaymentLinkWebhook _self;
  final $Res Function(_PaymentLinkWebhook) _then;

/// Create a copy of PaymentLinkWebhook
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? returnUrl = null,Object? postPurchaseUrl = null,Object? postPurchaseRestMethod = null,Object? postPurchaseHeaders = null,Object? postPurchaseBody = null,}) {
  return _then(_PaymentLinkWebhook(
returnUrl: null == returnUrl ? _self.returnUrl : returnUrl // ignore: cast_nullable_to_non_nullable
as String,postPurchaseUrl: null == postPurchaseUrl ? _self.postPurchaseUrl : postPurchaseUrl // ignore: cast_nullable_to_non_nullable
as String,postPurchaseRestMethod: null == postPurchaseRestMethod ? _self.postPurchaseRestMethod : postPurchaseRestMethod // ignore: cast_nullable_to_non_nullable
as String,postPurchaseHeaders: null == postPurchaseHeaders ? _self._postPurchaseHeaders : postPurchaseHeaders // ignore: cast_nullable_to_non_nullable
as Map<String, String>,postPurchaseBody: null == postPurchaseBody ? _self.postPurchaseBody : postPurchaseBody // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
