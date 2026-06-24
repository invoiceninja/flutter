// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'company_gateway_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FeesAndLimitsApi {

@JsonKey(name: 'min_limit') double get minLimit;@JsonKey(name: 'max_limit') double get maxLimit;@JsonKey(name: 'fee_amount') double get feeAmount;@JsonKey(name: 'fee_percent') double get feePercent;@JsonKey(name: 'fee_cap') double get feeCap;@JsonKey(name: 'fee_tax_rate1') double get feeTaxRate1;@JsonKey(name: 'fee_tax_name1') String get feeTaxName1;@JsonKey(name: 'fee_tax_rate2') double get feeTaxRate2;@JsonKey(name: 'fee_tax_name2') String get feeTaxName2;@JsonKey(name: 'fee_tax_rate3') double get feeTaxRate3;@JsonKey(name: 'fee_tax_name3') String get feeTaxName3;@JsonKey(name: 'adjust_fee_percent') bool get adjustFeePercent;@JsonKey(name: 'is_enabled') bool get isEnabled;
/// Create a copy of FeesAndLimitsApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FeesAndLimitsApiCopyWith<FeesAndLimitsApi> get copyWith => _$FeesAndLimitsApiCopyWithImpl<FeesAndLimitsApi>(this as FeesAndLimitsApi, _$identity);

  /// Serializes this FeesAndLimitsApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FeesAndLimitsApi&&(identical(other.minLimit, minLimit) || other.minLimit == minLimit)&&(identical(other.maxLimit, maxLimit) || other.maxLimit == maxLimit)&&(identical(other.feeAmount, feeAmount) || other.feeAmount == feeAmount)&&(identical(other.feePercent, feePercent) || other.feePercent == feePercent)&&(identical(other.feeCap, feeCap) || other.feeCap == feeCap)&&(identical(other.feeTaxRate1, feeTaxRate1) || other.feeTaxRate1 == feeTaxRate1)&&(identical(other.feeTaxName1, feeTaxName1) || other.feeTaxName1 == feeTaxName1)&&(identical(other.feeTaxRate2, feeTaxRate2) || other.feeTaxRate2 == feeTaxRate2)&&(identical(other.feeTaxName2, feeTaxName2) || other.feeTaxName2 == feeTaxName2)&&(identical(other.feeTaxRate3, feeTaxRate3) || other.feeTaxRate3 == feeTaxRate3)&&(identical(other.feeTaxName3, feeTaxName3) || other.feeTaxName3 == feeTaxName3)&&(identical(other.adjustFeePercent, adjustFeePercent) || other.adjustFeePercent == adjustFeePercent)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,minLimit,maxLimit,feeAmount,feePercent,feeCap,feeTaxRate1,feeTaxName1,feeTaxRate2,feeTaxName2,feeTaxRate3,feeTaxName3,adjustFeePercent,isEnabled);

@override
String toString() {
  return 'FeesAndLimitsApi(minLimit: $minLimit, maxLimit: $maxLimit, feeAmount: $feeAmount, feePercent: $feePercent, feeCap: $feeCap, feeTaxRate1: $feeTaxRate1, feeTaxName1: $feeTaxName1, feeTaxRate2: $feeTaxRate2, feeTaxName2: $feeTaxName2, feeTaxRate3: $feeTaxRate3, feeTaxName3: $feeTaxName3, adjustFeePercent: $adjustFeePercent, isEnabled: $isEnabled)';
}


}

/// @nodoc
abstract mixin class $FeesAndLimitsApiCopyWith<$Res>  {
  factory $FeesAndLimitsApiCopyWith(FeesAndLimitsApi value, $Res Function(FeesAndLimitsApi) _then) = _$FeesAndLimitsApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'min_limit') double minLimit,@JsonKey(name: 'max_limit') double maxLimit,@JsonKey(name: 'fee_amount') double feeAmount,@JsonKey(name: 'fee_percent') double feePercent,@JsonKey(name: 'fee_cap') double feeCap,@JsonKey(name: 'fee_tax_rate1') double feeTaxRate1,@JsonKey(name: 'fee_tax_name1') String feeTaxName1,@JsonKey(name: 'fee_tax_rate2') double feeTaxRate2,@JsonKey(name: 'fee_tax_name2') String feeTaxName2,@JsonKey(name: 'fee_tax_rate3') double feeTaxRate3,@JsonKey(name: 'fee_tax_name3') String feeTaxName3,@JsonKey(name: 'adjust_fee_percent') bool adjustFeePercent,@JsonKey(name: 'is_enabled') bool isEnabled
});




}
/// @nodoc
class _$FeesAndLimitsApiCopyWithImpl<$Res>
    implements $FeesAndLimitsApiCopyWith<$Res> {
  _$FeesAndLimitsApiCopyWithImpl(this._self, this._then);

  final FeesAndLimitsApi _self;
  final $Res Function(FeesAndLimitsApi) _then;

/// Create a copy of FeesAndLimitsApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? minLimit = null,Object? maxLimit = null,Object? feeAmount = null,Object? feePercent = null,Object? feeCap = null,Object? feeTaxRate1 = null,Object? feeTaxName1 = null,Object? feeTaxRate2 = null,Object? feeTaxName2 = null,Object? feeTaxRate3 = null,Object? feeTaxName3 = null,Object? adjustFeePercent = null,Object? isEnabled = null,}) {
  return _then(_self.copyWith(
minLimit: null == minLimit ? _self.minLimit : minLimit // ignore: cast_nullable_to_non_nullable
as double,maxLimit: null == maxLimit ? _self.maxLimit : maxLimit // ignore: cast_nullable_to_non_nullable
as double,feeAmount: null == feeAmount ? _self.feeAmount : feeAmount // ignore: cast_nullable_to_non_nullable
as double,feePercent: null == feePercent ? _self.feePercent : feePercent // ignore: cast_nullable_to_non_nullable
as double,feeCap: null == feeCap ? _self.feeCap : feeCap // ignore: cast_nullable_to_non_nullable
as double,feeTaxRate1: null == feeTaxRate1 ? _self.feeTaxRate1 : feeTaxRate1 // ignore: cast_nullable_to_non_nullable
as double,feeTaxName1: null == feeTaxName1 ? _self.feeTaxName1 : feeTaxName1 // ignore: cast_nullable_to_non_nullable
as String,feeTaxRate2: null == feeTaxRate2 ? _self.feeTaxRate2 : feeTaxRate2 // ignore: cast_nullable_to_non_nullable
as double,feeTaxName2: null == feeTaxName2 ? _self.feeTaxName2 : feeTaxName2 // ignore: cast_nullable_to_non_nullable
as String,feeTaxRate3: null == feeTaxRate3 ? _self.feeTaxRate3 : feeTaxRate3 // ignore: cast_nullable_to_non_nullable
as double,feeTaxName3: null == feeTaxName3 ? _self.feeTaxName3 : feeTaxName3 // ignore: cast_nullable_to_non_nullable
as String,adjustFeePercent: null == adjustFeePercent ? _self.adjustFeePercent : adjustFeePercent // ignore: cast_nullable_to_non_nullable
as bool,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [FeesAndLimitsApi].
extension FeesAndLimitsApiPatterns on FeesAndLimitsApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FeesAndLimitsApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FeesAndLimitsApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FeesAndLimitsApi value)  $default,){
final _that = this;
switch (_that) {
case _FeesAndLimitsApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FeesAndLimitsApi value)?  $default,){
final _that = this;
switch (_that) {
case _FeesAndLimitsApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'min_limit')  double minLimit, @JsonKey(name: 'max_limit')  double maxLimit, @JsonKey(name: 'fee_amount')  double feeAmount, @JsonKey(name: 'fee_percent')  double feePercent, @JsonKey(name: 'fee_cap')  double feeCap, @JsonKey(name: 'fee_tax_rate1')  double feeTaxRate1, @JsonKey(name: 'fee_tax_name1')  String feeTaxName1, @JsonKey(name: 'fee_tax_rate2')  double feeTaxRate2, @JsonKey(name: 'fee_tax_name2')  String feeTaxName2, @JsonKey(name: 'fee_tax_rate3')  double feeTaxRate3, @JsonKey(name: 'fee_tax_name3')  String feeTaxName3, @JsonKey(name: 'adjust_fee_percent')  bool adjustFeePercent, @JsonKey(name: 'is_enabled')  bool isEnabled)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FeesAndLimitsApi() when $default != null:
return $default(_that.minLimit,_that.maxLimit,_that.feeAmount,_that.feePercent,_that.feeCap,_that.feeTaxRate1,_that.feeTaxName1,_that.feeTaxRate2,_that.feeTaxName2,_that.feeTaxRate3,_that.feeTaxName3,_that.adjustFeePercent,_that.isEnabled);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'min_limit')  double minLimit, @JsonKey(name: 'max_limit')  double maxLimit, @JsonKey(name: 'fee_amount')  double feeAmount, @JsonKey(name: 'fee_percent')  double feePercent, @JsonKey(name: 'fee_cap')  double feeCap, @JsonKey(name: 'fee_tax_rate1')  double feeTaxRate1, @JsonKey(name: 'fee_tax_name1')  String feeTaxName1, @JsonKey(name: 'fee_tax_rate2')  double feeTaxRate2, @JsonKey(name: 'fee_tax_name2')  String feeTaxName2, @JsonKey(name: 'fee_tax_rate3')  double feeTaxRate3, @JsonKey(name: 'fee_tax_name3')  String feeTaxName3, @JsonKey(name: 'adjust_fee_percent')  bool adjustFeePercent, @JsonKey(name: 'is_enabled')  bool isEnabled)  $default,) {final _that = this;
switch (_that) {
case _FeesAndLimitsApi():
return $default(_that.minLimit,_that.maxLimit,_that.feeAmount,_that.feePercent,_that.feeCap,_that.feeTaxRate1,_that.feeTaxName1,_that.feeTaxRate2,_that.feeTaxName2,_that.feeTaxRate3,_that.feeTaxName3,_that.adjustFeePercent,_that.isEnabled);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'min_limit')  double minLimit, @JsonKey(name: 'max_limit')  double maxLimit, @JsonKey(name: 'fee_amount')  double feeAmount, @JsonKey(name: 'fee_percent')  double feePercent, @JsonKey(name: 'fee_cap')  double feeCap, @JsonKey(name: 'fee_tax_rate1')  double feeTaxRate1, @JsonKey(name: 'fee_tax_name1')  String feeTaxName1, @JsonKey(name: 'fee_tax_rate2')  double feeTaxRate2, @JsonKey(name: 'fee_tax_name2')  String feeTaxName2, @JsonKey(name: 'fee_tax_rate3')  double feeTaxRate3, @JsonKey(name: 'fee_tax_name3')  String feeTaxName3, @JsonKey(name: 'adjust_fee_percent')  bool adjustFeePercent, @JsonKey(name: 'is_enabled')  bool isEnabled)?  $default,) {final _that = this;
switch (_that) {
case _FeesAndLimitsApi() when $default != null:
return $default(_that.minLimit,_that.maxLimit,_that.feeAmount,_that.feePercent,_that.feeCap,_that.feeTaxRate1,_that.feeTaxName1,_that.feeTaxRate2,_that.feeTaxName2,_that.feeTaxRate3,_that.feeTaxName3,_that.adjustFeePercent,_that.isEnabled);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _FeesAndLimitsApi implements FeesAndLimitsApi {
  const _FeesAndLimitsApi({@JsonKey(name: 'min_limit') this.minLimit = -1.0, @JsonKey(name: 'max_limit') this.maxLimit = -1.0, @JsonKey(name: 'fee_amount') this.feeAmount = 0.0, @JsonKey(name: 'fee_percent') this.feePercent = 0.0, @JsonKey(name: 'fee_cap') this.feeCap = 0.0, @JsonKey(name: 'fee_tax_rate1') this.feeTaxRate1 = 0.0, @JsonKey(name: 'fee_tax_name1') this.feeTaxName1 = '', @JsonKey(name: 'fee_tax_rate2') this.feeTaxRate2 = 0.0, @JsonKey(name: 'fee_tax_name2') this.feeTaxName2 = '', @JsonKey(name: 'fee_tax_rate3') this.feeTaxRate3 = 0.0, @JsonKey(name: 'fee_tax_name3') this.feeTaxName3 = '', @JsonKey(name: 'adjust_fee_percent') this.adjustFeePercent = false, @JsonKey(name: 'is_enabled') this.isEnabled = true});
  factory _FeesAndLimitsApi.fromJson(Map<String, dynamic> json) => _$FeesAndLimitsApiFromJson(json);

@override@JsonKey(name: 'min_limit') final  double minLimit;
@override@JsonKey(name: 'max_limit') final  double maxLimit;
@override@JsonKey(name: 'fee_amount') final  double feeAmount;
@override@JsonKey(name: 'fee_percent') final  double feePercent;
@override@JsonKey(name: 'fee_cap') final  double feeCap;
@override@JsonKey(name: 'fee_tax_rate1') final  double feeTaxRate1;
@override@JsonKey(name: 'fee_tax_name1') final  String feeTaxName1;
@override@JsonKey(name: 'fee_tax_rate2') final  double feeTaxRate2;
@override@JsonKey(name: 'fee_tax_name2') final  String feeTaxName2;
@override@JsonKey(name: 'fee_tax_rate3') final  double feeTaxRate3;
@override@JsonKey(name: 'fee_tax_name3') final  String feeTaxName3;
@override@JsonKey(name: 'adjust_fee_percent') final  bool adjustFeePercent;
@override@JsonKey(name: 'is_enabled') final  bool isEnabled;

/// Create a copy of FeesAndLimitsApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FeesAndLimitsApiCopyWith<_FeesAndLimitsApi> get copyWith => __$FeesAndLimitsApiCopyWithImpl<_FeesAndLimitsApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FeesAndLimitsApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FeesAndLimitsApi&&(identical(other.minLimit, minLimit) || other.minLimit == minLimit)&&(identical(other.maxLimit, maxLimit) || other.maxLimit == maxLimit)&&(identical(other.feeAmount, feeAmount) || other.feeAmount == feeAmount)&&(identical(other.feePercent, feePercent) || other.feePercent == feePercent)&&(identical(other.feeCap, feeCap) || other.feeCap == feeCap)&&(identical(other.feeTaxRate1, feeTaxRate1) || other.feeTaxRate1 == feeTaxRate1)&&(identical(other.feeTaxName1, feeTaxName1) || other.feeTaxName1 == feeTaxName1)&&(identical(other.feeTaxRate2, feeTaxRate2) || other.feeTaxRate2 == feeTaxRate2)&&(identical(other.feeTaxName2, feeTaxName2) || other.feeTaxName2 == feeTaxName2)&&(identical(other.feeTaxRate3, feeTaxRate3) || other.feeTaxRate3 == feeTaxRate3)&&(identical(other.feeTaxName3, feeTaxName3) || other.feeTaxName3 == feeTaxName3)&&(identical(other.adjustFeePercent, adjustFeePercent) || other.adjustFeePercent == adjustFeePercent)&&(identical(other.isEnabled, isEnabled) || other.isEnabled == isEnabled));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,minLimit,maxLimit,feeAmount,feePercent,feeCap,feeTaxRate1,feeTaxName1,feeTaxRate2,feeTaxName2,feeTaxRate3,feeTaxName3,adjustFeePercent,isEnabled);

@override
String toString() {
  return 'FeesAndLimitsApi(minLimit: $minLimit, maxLimit: $maxLimit, feeAmount: $feeAmount, feePercent: $feePercent, feeCap: $feeCap, feeTaxRate1: $feeTaxRate1, feeTaxName1: $feeTaxName1, feeTaxRate2: $feeTaxRate2, feeTaxName2: $feeTaxName2, feeTaxRate3: $feeTaxRate3, feeTaxName3: $feeTaxName3, adjustFeePercent: $adjustFeePercent, isEnabled: $isEnabled)';
}


}

/// @nodoc
abstract mixin class _$FeesAndLimitsApiCopyWith<$Res> implements $FeesAndLimitsApiCopyWith<$Res> {
  factory _$FeesAndLimitsApiCopyWith(_FeesAndLimitsApi value, $Res Function(_FeesAndLimitsApi) _then) = __$FeesAndLimitsApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'min_limit') double minLimit,@JsonKey(name: 'max_limit') double maxLimit,@JsonKey(name: 'fee_amount') double feeAmount,@JsonKey(name: 'fee_percent') double feePercent,@JsonKey(name: 'fee_cap') double feeCap,@JsonKey(name: 'fee_tax_rate1') double feeTaxRate1,@JsonKey(name: 'fee_tax_name1') String feeTaxName1,@JsonKey(name: 'fee_tax_rate2') double feeTaxRate2,@JsonKey(name: 'fee_tax_name2') String feeTaxName2,@JsonKey(name: 'fee_tax_rate3') double feeTaxRate3,@JsonKey(name: 'fee_tax_name3') String feeTaxName3,@JsonKey(name: 'adjust_fee_percent') bool adjustFeePercent,@JsonKey(name: 'is_enabled') bool isEnabled
});




}
/// @nodoc
class __$FeesAndLimitsApiCopyWithImpl<$Res>
    implements _$FeesAndLimitsApiCopyWith<$Res> {
  __$FeesAndLimitsApiCopyWithImpl(this._self, this._then);

  final _FeesAndLimitsApi _self;
  final $Res Function(_FeesAndLimitsApi) _then;

/// Create a copy of FeesAndLimitsApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? minLimit = null,Object? maxLimit = null,Object? feeAmount = null,Object? feePercent = null,Object? feeCap = null,Object? feeTaxRate1 = null,Object? feeTaxName1 = null,Object? feeTaxRate2 = null,Object? feeTaxName2 = null,Object? feeTaxRate3 = null,Object? feeTaxName3 = null,Object? adjustFeePercent = null,Object? isEnabled = null,}) {
  return _then(_FeesAndLimitsApi(
minLimit: null == minLimit ? _self.minLimit : minLimit // ignore: cast_nullable_to_non_nullable
as double,maxLimit: null == maxLimit ? _self.maxLimit : maxLimit // ignore: cast_nullable_to_non_nullable
as double,feeAmount: null == feeAmount ? _self.feeAmount : feeAmount // ignore: cast_nullable_to_non_nullable
as double,feePercent: null == feePercent ? _self.feePercent : feePercent // ignore: cast_nullable_to_non_nullable
as double,feeCap: null == feeCap ? _self.feeCap : feeCap // ignore: cast_nullable_to_non_nullable
as double,feeTaxRate1: null == feeTaxRate1 ? _self.feeTaxRate1 : feeTaxRate1 // ignore: cast_nullable_to_non_nullable
as double,feeTaxName1: null == feeTaxName1 ? _self.feeTaxName1 : feeTaxName1 // ignore: cast_nullable_to_non_nullable
as String,feeTaxRate2: null == feeTaxRate2 ? _self.feeTaxRate2 : feeTaxRate2 // ignore: cast_nullable_to_non_nullable
as double,feeTaxName2: null == feeTaxName2 ? _self.feeTaxName2 : feeTaxName2 // ignore: cast_nullable_to_non_nullable
as String,feeTaxRate3: null == feeTaxRate3 ? _self.feeTaxRate3 : feeTaxRate3 // ignore: cast_nullable_to_non_nullable
as double,feeTaxName3: null == feeTaxName3 ? _self.feeTaxName3 : feeTaxName3 // ignore: cast_nullable_to_non_nullable
as String,adjustFeePercent: null == adjustFeePercent ? _self.adjustFeePercent : adjustFeePercent // ignore: cast_nullable_to_non_nullable
as bool,isEnabled: null == isEnabled ? _self.isEnabled : isEnabled // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$CompanyGatewayApi {

 String get id;@JsonKey(name: 'gateway_key') String get gatewayKey;@JsonKey(name: 'accepted_credit_cards') int get acceptedCreditCards;@JsonKey(name: 'require_cvv') bool get requireCvv;@JsonKey(name: 'require_billing_address') bool get requireBillingAddress;@JsonKey(name: 'require_shipping_address') bool get requireShippingAddress;@JsonKey(name: 'require_client_name') bool get requireClientName;@JsonKey(name: 'require_client_phone') bool get requireClientPhone;@JsonKey(name: 'require_contact_name') bool get requireContactName;@JsonKey(name: 'require_contact_email') bool get requireContactEmail;@JsonKey(name: 'require_postal_code') bool get requirePostalCode;@JsonKey(name: 'require_custom_value1') bool get requireCustomValue1;@JsonKey(name: 'require_custom_value2') bool get requireCustomValue2;@JsonKey(name: 'require_custom_value3') bool get requireCustomValue3;@JsonKey(name: 'require_custom_value4') bool get requireCustomValue4;@JsonKey(name: 'update_details') bool get updateDetails;@JsonKey(name: 'always_show_required_fields') bool get alwaysShowRequiredFields;@JsonKey(name: 'token_billing') String get tokenBilling; String get label; String get config;@JsonKey(name: 'fees_and_limits', fromJson: _feesAndLimitsFromJson) Map<String, FeesAndLimitsApi> get feesAndLimits;@JsonKey(name: 'test_mode') bool get testMode;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of CompanyGatewayApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyGatewayApiCopyWith<CompanyGatewayApi> get copyWith => _$CompanyGatewayApiCopyWithImpl<CompanyGatewayApi>(this as CompanyGatewayApi, _$identity);

  /// Serializes this CompanyGatewayApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyGatewayApi&&(identical(other.id, id) || other.id == id)&&(identical(other.gatewayKey, gatewayKey) || other.gatewayKey == gatewayKey)&&(identical(other.acceptedCreditCards, acceptedCreditCards) || other.acceptedCreditCards == acceptedCreditCards)&&(identical(other.requireCvv, requireCvv) || other.requireCvv == requireCvv)&&(identical(other.requireBillingAddress, requireBillingAddress) || other.requireBillingAddress == requireBillingAddress)&&(identical(other.requireShippingAddress, requireShippingAddress) || other.requireShippingAddress == requireShippingAddress)&&(identical(other.requireClientName, requireClientName) || other.requireClientName == requireClientName)&&(identical(other.requireClientPhone, requireClientPhone) || other.requireClientPhone == requireClientPhone)&&(identical(other.requireContactName, requireContactName) || other.requireContactName == requireContactName)&&(identical(other.requireContactEmail, requireContactEmail) || other.requireContactEmail == requireContactEmail)&&(identical(other.requirePostalCode, requirePostalCode) || other.requirePostalCode == requirePostalCode)&&(identical(other.requireCustomValue1, requireCustomValue1) || other.requireCustomValue1 == requireCustomValue1)&&(identical(other.requireCustomValue2, requireCustomValue2) || other.requireCustomValue2 == requireCustomValue2)&&(identical(other.requireCustomValue3, requireCustomValue3) || other.requireCustomValue3 == requireCustomValue3)&&(identical(other.requireCustomValue4, requireCustomValue4) || other.requireCustomValue4 == requireCustomValue4)&&(identical(other.updateDetails, updateDetails) || other.updateDetails == updateDetails)&&(identical(other.alwaysShowRequiredFields, alwaysShowRequiredFields) || other.alwaysShowRequiredFields == alwaysShowRequiredFields)&&(identical(other.tokenBilling, tokenBilling) || other.tokenBilling == tokenBilling)&&(identical(other.label, label) || other.label == label)&&(identical(other.config, config) || other.config == config)&&const DeepCollectionEquality().equals(other.feesAndLimits, feesAndLimits)&&(identical(other.testMode, testMode) || other.testMode == testMode)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,gatewayKey,acceptedCreditCards,requireCvv,requireBillingAddress,requireShippingAddress,requireClientName,requireClientPhone,requireContactName,requireContactEmail,requirePostalCode,requireCustomValue1,requireCustomValue2,requireCustomValue3,requireCustomValue4,updateDetails,alwaysShowRequiredFields,tokenBilling,label,config,const DeepCollectionEquality().hash(feesAndLimits),testMode,createdAt,updatedAt,archivedAt,isDeleted]);

@override
String toString() {
  return 'CompanyGatewayApi(id: $id, gatewayKey: $gatewayKey, acceptedCreditCards: $acceptedCreditCards, requireCvv: $requireCvv, requireBillingAddress: $requireBillingAddress, requireShippingAddress: $requireShippingAddress, requireClientName: $requireClientName, requireClientPhone: $requireClientPhone, requireContactName: $requireContactName, requireContactEmail: $requireContactEmail, requirePostalCode: $requirePostalCode, requireCustomValue1: $requireCustomValue1, requireCustomValue2: $requireCustomValue2, requireCustomValue3: $requireCustomValue3, requireCustomValue4: $requireCustomValue4, updateDetails: $updateDetails, alwaysShowRequiredFields: $alwaysShowRequiredFields, tokenBilling: $tokenBilling, label: $label, config: $config, feesAndLimits: $feesAndLimits, testMode: $testMode, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class $CompanyGatewayApiCopyWith<$Res>  {
  factory $CompanyGatewayApiCopyWith(CompanyGatewayApi value, $Res Function(CompanyGatewayApi) _then) = _$CompanyGatewayApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'gateway_key') String gatewayKey,@JsonKey(name: 'accepted_credit_cards') int acceptedCreditCards,@JsonKey(name: 'require_cvv') bool requireCvv,@JsonKey(name: 'require_billing_address') bool requireBillingAddress,@JsonKey(name: 'require_shipping_address') bool requireShippingAddress,@JsonKey(name: 'require_client_name') bool requireClientName,@JsonKey(name: 'require_client_phone') bool requireClientPhone,@JsonKey(name: 'require_contact_name') bool requireContactName,@JsonKey(name: 'require_contact_email') bool requireContactEmail,@JsonKey(name: 'require_postal_code') bool requirePostalCode,@JsonKey(name: 'require_custom_value1') bool requireCustomValue1,@JsonKey(name: 'require_custom_value2') bool requireCustomValue2,@JsonKey(name: 'require_custom_value3') bool requireCustomValue3,@JsonKey(name: 'require_custom_value4') bool requireCustomValue4,@JsonKey(name: 'update_details') bool updateDetails,@JsonKey(name: 'always_show_required_fields') bool alwaysShowRequiredFields,@JsonKey(name: 'token_billing') String tokenBilling, String label, String config,@JsonKey(name: 'fees_and_limits', fromJson: _feesAndLimitsFromJson) Map<String, FeesAndLimitsApi> feesAndLimits,@JsonKey(name: 'test_mode') bool testMode,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class _$CompanyGatewayApiCopyWithImpl<$Res>
    implements $CompanyGatewayApiCopyWith<$Res> {
  _$CompanyGatewayApiCopyWithImpl(this._self, this._then);

  final CompanyGatewayApi _self;
  final $Res Function(CompanyGatewayApi) _then;

/// Create a copy of CompanyGatewayApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? gatewayKey = null,Object? acceptedCreditCards = null,Object? requireCvv = null,Object? requireBillingAddress = null,Object? requireShippingAddress = null,Object? requireClientName = null,Object? requireClientPhone = null,Object? requireContactName = null,Object? requireContactEmail = null,Object? requirePostalCode = null,Object? requireCustomValue1 = null,Object? requireCustomValue2 = null,Object? requireCustomValue3 = null,Object? requireCustomValue4 = null,Object? updateDetails = null,Object? alwaysShowRequiredFields = null,Object? tokenBilling = null,Object? label = null,Object? config = null,Object? feesAndLimits = null,Object? testMode = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,gatewayKey: null == gatewayKey ? _self.gatewayKey : gatewayKey // ignore: cast_nullable_to_non_nullable
as String,acceptedCreditCards: null == acceptedCreditCards ? _self.acceptedCreditCards : acceptedCreditCards // ignore: cast_nullable_to_non_nullable
as int,requireCvv: null == requireCvv ? _self.requireCvv : requireCvv // ignore: cast_nullable_to_non_nullable
as bool,requireBillingAddress: null == requireBillingAddress ? _self.requireBillingAddress : requireBillingAddress // ignore: cast_nullable_to_non_nullable
as bool,requireShippingAddress: null == requireShippingAddress ? _self.requireShippingAddress : requireShippingAddress // ignore: cast_nullable_to_non_nullable
as bool,requireClientName: null == requireClientName ? _self.requireClientName : requireClientName // ignore: cast_nullable_to_non_nullable
as bool,requireClientPhone: null == requireClientPhone ? _self.requireClientPhone : requireClientPhone // ignore: cast_nullable_to_non_nullable
as bool,requireContactName: null == requireContactName ? _self.requireContactName : requireContactName // ignore: cast_nullable_to_non_nullable
as bool,requireContactEmail: null == requireContactEmail ? _self.requireContactEmail : requireContactEmail // ignore: cast_nullable_to_non_nullable
as bool,requirePostalCode: null == requirePostalCode ? _self.requirePostalCode : requirePostalCode // ignore: cast_nullable_to_non_nullable
as bool,requireCustomValue1: null == requireCustomValue1 ? _self.requireCustomValue1 : requireCustomValue1 // ignore: cast_nullable_to_non_nullable
as bool,requireCustomValue2: null == requireCustomValue2 ? _self.requireCustomValue2 : requireCustomValue2 // ignore: cast_nullable_to_non_nullable
as bool,requireCustomValue3: null == requireCustomValue3 ? _self.requireCustomValue3 : requireCustomValue3 // ignore: cast_nullable_to_non_nullable
as bool,requireCustomValue4: null == requireCustomValue4 ? _self.requireCustomValue4 : requireCustomValue4 // ignore: cast_nullable_to_non_nullable
as bool,updateDetails: null == updateDetails ? _self.updateDetails : updateDetails // ignore: cast_nullable_to_non_nullable
as bool,alwaysShowRequiredFields: null == alwaysShowRequiredFields ? _self.alwaysShowRequiredFields : alwaysShowRequiredFields // ignore: cast_nullable_to_non_nullable
as bool,tokenBilling: null == tokenBilling ? _self.tokenBilling : tokenBilling // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as String,feesAndLimits: null == feesAndLimits ? _self.feesAndLimits : feesAndLimits // ignore: cast_nullable_to_non_nullable
as Map<String, FeesAndLimitsApi>,testMode: null == testMode ? _self.testMode : testMode // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CompanyGatewayApi].
extension CompanyGatewayApiPatterns on CompanyGatewayApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyGatewayApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyGatewayApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyGatewayApi value)  $default,){
final _that = this;
switch (_that) {
case _CompanyGatewayApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyGatewayApi value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyGatewayApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'gateway_key')  String gatewayKey, @JsonKey(name: 'accepted_credit_cards')  int acceptedCreditCards, @JsonKey(name: 'require_cvv')  bool requireCvv, @JsonKey(name: 'require_billing_address')  bool requireBillingAddress, @JsonKey(name: 'require_shipping_address')  bool requireShippingAddress, @JsonKey(name: 'require_client_name')  bool requireClientName, @JsonKey(name: 'require_client_phone')  bool requireClientPhone, @JsonKey(name: 'require_contact_name')  bool requireContactName, @JsonKey(name: 'require_contact_email')  bool requireContactEmail, @JsonKey(name: 'require_postal_code')  bool requirePostalCode, @JsonKey(name: 'require_custom_value1')  bool requireCustomValue1, @JsonKey(name: 'require_custom_value2')  bool requireCustomValue2, @JsonKey(name: 'require_custom_value3')  bool requireCustomValue3, @JsonKey(name: 'require_custom_value4')  bool requireCustomValue4, @JsonKey(name: 'update_details')  bool updateDetails, @JsonKey(name: 'always_show_required_fields')  bool alwaysShowRequiredFields, @JsonKey(name: 'token_billing')  String tokenBilling,  String label,  String config, @JsonKey(name: 'fees_and_limits', fromJson: _feesAndLimitsFromJson)  Map<String, FeesAndLimitsApi> feesAndLimits, @JsonKey(name: 'test_mode')  bool testMode, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyGatewayApi() when $default != null:
return $default(_that.id,_that.gatewayKey,_that.acceptedCreditCards,_that.requireCvv,_that.requireBillingAddress,_that.requireShippingAddress,_that.requireClientName,_that.requireClientPhone,_that.requireContactName,_that.requireContactEmail,_that.requirePostalCode,_that.requireCustomValue1,_that.requireCustomValue2,_that.requireCustomValue3,_that.requireCustomValue4,_that.updateDetails,_that.alwaysShowRequiredFields,_that.tokenBilling,_that.label,_that.config,_that.feesAndLimits,_that.testMode,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'gateway_key')  String gatewayKey, @JsonKey(name: 'accepted_credit_cards')  int acceptedCreditCards, @JsonKey(name: 'require_cvv')  bool requireCvv, @JsonKey(name: 'require_billing_address')  bool requireBillingAddress, @JsonKey(name: 'require_shipping_address')  bool requireShippingAddress, @JsonKey(name: 'require_client_name')  bool requireClientName, @JsonKey(name: 'require_client_phone')  bool requireClientPhone, @JsonKey(name: 'require_contact_name')  bool requireContactName, @JsonKey(name: 'require_contact_email')  bool requireContactEmail, @JsonKey(name: 'require_postal_code')  bool requirePostalCode, @JsonKey(name: 'require_custom_value1')  bool requireCustomValue1, @JsonKey(name: 'require_custom_value2')  bool requireCustomValue2, @JsonKey(name: 'require_custom_value3')  bool requireCustomValue3, @JsonKey(name: 'require_custom_value4')  bool requireCustomValue4, @JsonKey(name: 'update_details')  bool updateDetails, @JsonKey(name: 'always_show_required_fields')  bool alwaysShowRequiredFields, @JsonKey(name: 'token_billing')  String tokenBilling,  String label,  String config, @JsonKey(name: 'fees_and_limits', fromJson: _feesAndLimitsFromJson)  Map<String, FeesAndLimitsApi> feesAndLimits, @JsonKey(name: 'test_mode')  bool testMode, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _CompanyGatewayApi():
return $default(_that.id,_that.gatewayKey,_that.acceptedCreditCards,_that.requireCvv,_that.requireBillingAddress,_that.requireShippingAddress,_that.requireClientName,_that.requireClientPhone,_that.requireContactName,_that.requireContactEmail,_that.requirePostalCode,_that.requireCustomValue1,_that.requireCustomValue2,_that.requireCustomValue3,_that.requireCustomValue4,_that.updateDetails,_that.alwaysShowRequiredFields,_that.tokenBilling,_that.label,_that.config,_that.feesAndLimits,_that.testMode,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'gateway_key')  String gatewayKey, @JsonKey(name: 'accepted_credit_cards')  int acceptedCreditCards, @JsonKey(name: 'require_cvv')  bool requireCvv, @JsonKey(name: 'require_billing_address')  bool requireBillingAddress, @JsonKey(name: 'require_shipping_address')  bool requireShippingAddress, @JsonKey(name: 'require_client_name')  bool requireClientName, @JsonKey(name: 'require_client_phone')  bool requireClientPhone, @JsonKey(name: 'require_contact_name')  bool requireContactName, @JsonKey(name: 'require_contact_email')  bool requireContactEmail, @JsonKey(name: 'require_postal_code')  bool requirePostalCode, @JsonKey(name: 'require_custom_value1')  bool requireCustomValue1, @JsonKey(name: 'require_custom_value2')  bool requireCustomValue2, @JsonKey(name: 'require_custom_value3')  bool requireCustomValue3, @JsonKey(name: 'require_custom_value4')  bool requireCustomValue4, @JsonKey(name: 'update_details')  bool updateDetails, @JsonKey(name: 'always_show_required_fields')  bool alwaysShowRequiredFields, @JsonKey(name: 'token_billing')  String tokenBilling,  String label,  String config, @JsonKey(name: 'fees_and_limits', fromJson: _feesAndLimitsFromJson)  Map<String, FeesAndLimitsApi> feesAndLimits, @JsonKey(name: 'test_mode')  bool testMode, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _CompanyGatewayApi() when $default != null:
return $default(_that.id,_that.gatewayKey,_that.acceptedCreditCards,_that.requireCvv,_that.requireBillingAddress,_that.requireShippingAddress,_that.requireClientName,_that.requireClientPhone,_that.requireContactName,_that.requireContactEmail,_that.requirePostalCode,_that.requireCustomValue1,_that.requireCustomValue2,_that.requireCustomValue3,_that.requireCustomValue4,_that.updateDetails,_that.alwaysShowRequiredFields,_that.tokenBilling,_that.label,_that.config,_that.feesAndLimits,_that.testMode,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _CompanyGatewayApi implements CompanyGatewayApi {
  const _CompanyGatewayApi({this.id = '', @JsonKey(name: 'gateway_key') this.gatewayKey = '', @JsonKey(name: 'accepted_credit_cards') this.acceptedCreditCards = 0, @JsonKey(name: 'require_cvv') this.requireCvv = false, @JsonKey(name: 'require_billing_address') this.requireBillingAddress = false, @JsonKey(name: 'require_shipping_address') this.requireShippingAddress = false, @JsonKey(name: 'require_client_name') this.requireClientName = false, @JsonKey(name: 'require_client_phone') this.requireClientPhone = false, @JsonKey(name: 'require_contact_name') this.requireContactName = false, @JsonKey(name: 'require_contact_email') this.requireContactEmail = true, @JsonKey(name: 'require_postal_code') this.requirePostalCode = true, @JsonKey(name: 'require_custom_value1') this.requireCustomValue1 = false, @JsonKey(name: 'require_custom_value2') this.requireCustomValue2 = false, @JsonKey(name: 'require_custom_value3') this.requireCustomValue3 = false, @JsonKey(name: 'require_custom_value4') this.requireCustomValue4 = false, @JsonKey(name: 'update_details') this.updateDetails = false, @JsonKey(name: 'always_show_required_fields') this.alwaysShowRequiredFields = true, @JsonKey(name: 'token_billing') this.tokenBilling = 'off', this.label = '', this.config = '', @JsonKey(name: 'fees_and_limits', fromJson: _feesAndLimitsFromJson) final  Map<String, FeesAndLimitsApi> feesAndLimits = const <String, FeesAndLimitsApi>{}, @JsonKey(name: 'test_mode') this.testMode = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false}): _feesAndLimits = feesAndLimits;
  factory _CompanyGatewayApi.fromJson(Map<String, dynamic> json) => _$CompanyGatewayApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'gateway_key') final  String gatewayKey;
@override@JsonKey(name: 'accepted_credit_cards') final  int acceptedCreditCards;
@override@JsonKey(name: 'require_cvv') final  bool requireCvv;
@override@JsonKey(name: 'require_billing_address') final  bool requireBillingAddress;
@override@JsonKey(name: 'require_shipping_address') final  bool requireShippingAddress;
@override@JsonKey(name: 'require_client_name') final  bool requireClientName;
@override@JsonKey(name: 'require_client_phone') final  bool requireClientPhone;
@override@JsonKey(name: 'require_contact_name') final  bool requireContactName;
@override@JsonKey(name: 'require_contact_email') final  bool requireContactEmail;
@override@JsonKey(name: 'require_postal_code') final  bool requirePostalCode;
@override@JsonKey(name: 'require_custom_value1') final  bool requireCustomValue1;
@override@JsonKey(name: 'require_custom_value2') final  bool requireCustomValue2;
@override@JsonKey(name: 'require_custom_value3') final  bool requireCustomValue3;
@override@JsonKey(name: 'require_custom_value4') final  bool requireCustomValue4;
@override@JsonKey(name: 'update_details') final  bool updateDetails;
@override@JsonKey(name: 'always_show_required_fields') final  bool alwaysShowRequiredFields;
@override@JsonKey(name: 'token_billing') final  String tokenBilling;
@override@JsonKey() final  String label;
@override@JsonKey() final  String config;
 final  Map<String, FeesAndLimitsApi> _feesAndLimits;
@override@JsonKey(name: 'fees_and_limits', fromJson: _feesAndLimitsFromJson) Map<String, FeesAndLimitsApi> get feesAndLimits {
  if (_feesAndLimits is EqualUnmodifiableMapView) return _feesAndLimits;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_feesAndLimits);
}

@override@JsonKey(name: 'test_mode') final  bool testMode;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of CompanyGatewayApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyGatewayApiCopyWith<_CompanyGatewayApi> get copyWith => __$CompanyGatewayApiCopyWithImpl<_CompanyGatewayApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyGatewayApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyGatewayApi&&(identical(other.id, id) || other.id == id)&&(identical(other.gatewayKey, gatewayKey) || other.gatewayKey == gatewayKey)&&(identical(other.acceptedCreditCards, acceptedCreditCards) || other.acceptedCreditCards == acceptedCreditCards)&&(identical(other.requireCvv, requireCvv) || other.requireCvv == requireCvv)&&(identical(other.requireBillingAddress, requireBillingAddress) || other.requireBillingAddress == requireBillingAddress)&&(identical(other.requireShippingAddress, requireShippingAddress) || other.requireShippingAddress == requireShippingAddress)&&(identical(other.requireClientName, requireClientName) || other.requireClientName == requireClientName)&&(identical(other.requireClientPhone, requireClientPhone) || other.requireClientPhone == requireClientPhone)&&(identical(other.requireContactName, requireContactName) || other.requireContactName == requireContactName)&&(identical(other.requireContactEmail, requireContactEmail) || other.requireContactEmail == requireContactEmail)&&(identical(other.requirePostalCode, requirePostalCode) || other.requirePostalCode == requirePostalCode)&&(identical(other.requireCustomValue1, requireCustomValue1) || other.requireCustomValue1 == requireCustomValue1)&&(identical(other.requireCustomValue2, requireCustomValue2) || other.requireCustomValue2 == requireCustomValue2)&&(identical(other.requireCustomValue3, requireCustomValue3) || other.requireCustomValue3 == requireCustomValue3)&&(identical(other.requireCustomValue4, requireCustomValue4) || other.requireCustomValue4 == requireCustomValue4)&&(identical(other.updateDetails, updateDetails) || other.updateDetails == updateDetails)&&(identical(other.alwaysShowRequiredFields, alwaysShowRequiredFields) || other.alwaysShowRequiredFields == alwaysShowRequiredFields)&&(identical(other.tokenBilling, tokenBilling) || other.tokenBilling == tokenBilling)&&(identical(other.label, label) || other.label == label)&&(identical(other.config, config) || other.config == config)&&const DeepCollectionEquality().equals(other._feesAndLimits, _feesAndLimits)&&(identical(other.testMode, testMode) || other.testMode == testMode)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,gatewayKey,acceptedCreditCards,requireCvv,requireBillingAddress,requireShippingAddress,requireClientName,requireClientPhone,requireContactName,requireContactEmail,requirePostalCode,requireCustomValue1,requireCustomValue2,requireCustomValue3,requireCustomValue4,updateDetails,alwaysShowRequiredFields,tokenBilling,label,config,const DeepCollectionEquality().hash(_feesAndLimits),testMode,createdAt,updatedAt,archivedAt,isDeleted]);

@override
String toString() {
  return 'CompanyGatewayApi(id: $id, gatewayKey: $gatewayKey, acceptedCreditCards: $acceptedCreditCards, requireCvv: $requireCvv, requireBillingAddress: $requireBillingAddress, requireShippingAddress: $requireShippingAddress, requireClientName: $requireClientName, requireClientPhone: $requireClientPhone, requireContactName: $requireContactName, requireContactEmail: $requireContactEmail, requirePostalCode: $requirePostalCode, requireCustomValue1: $requireCustomValue1, requireCustomValue2: $requireCustomValue2, requireCustomValue3: $requireCustomValue3, requireCustomValue4: $requireCustomValue4, updateDetails: $updateDetails, alwaysShowRequiredFields: $alwaysShowRequiredFields, tokenBilling: $tokenBilling, label: $label, config: $config, feesAndLimits: $feesAndLimits, testMode: $testMode, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$CompanyGatewayApiCopyWith<$Res> implements $CompanyGatewayApiCopyWith<$Res> {
  factory _$CompanyGatewayApiCopyWith(_CompanyGatewayApi value, $Res Function(_CompanyGatewayApi) _then) = __$CompanyGatewayApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'gateway_key') String gatewayKey,@JsonKey(name: 'accepted_credit_cards') int acceptedCreditCards,@JsonKey(name: 'require_cvv') bool requireCvv,@JsonKey(name: 'require_billing_address') bool requireBillingAddress,@JsonKey(name: 'require_shipping_address') bool requireShippingAddress,@JsonKey(name: 'require_client_name') bool requireClientName,@JsonKey(name: 'require_client_phone') bool requireClientPhone,@JsonKey(name: 'require_contact_name') bool requireContactName,@JsonKey(name: 'require_contact_email') bool requireContactEmail,@JsonKey(name: 'require_postal_code') bool requirePostalCode,@JsonKey(name: 'require_custom_value1') bool requireCustomValue1,@JsonKey(name: 'require_custom_value2') bool requireCustomValue2,@JsonKey(name: 'require_custom_value3') bool requireCustomValue3,@JsonKey(name: 'require_custom_value4') bool requireCustomValue4,@JsonKey(name: 'update_details') bool updateDetails,@JsonKey(name: 'always_show_required_fields') bool alwaysShowRequiredFields,@JsonKey(name: 'token_billing') String tokenBilling, String label, String config,@JsonKey(name: 'fees_and_limits', fromJson: _feesAndLimitsFromJson) Map<String, FeesAndLimitsApi> feesAndLimits,@JsonKey(name: 'test_mode') bool testMode,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class __$CompanyGatewayApiCopyWithImpl<$Res>
    implements _$CompanyGatewayApiCopyWith<$Res> {
  __$CompanyGatewayApiCopyWithImpl(this._self, this._then);

  final _CompanyGatewayApi _self;
  final $Res Function(_CompanyGatewayApi) _then;

/// Create a copy of CompanyGatewayApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? gatewayKey = null,Object? acceptedCreditCards = null,Object? requireCvv = null,Object? requireBillingAddress = null,Object? requireShippingAddress = null,Object? requireClientName = null,Object? requireClientPhone = null,Object? requireContactName = null,Object? requireContactEmail = null,Object? requirePostalCode = null,Object? requireCustomValue1 = null,Object? requireCustomValue2 = null,Object? requireCustomValue3 = null,Object? requireCustomValue4 = null,Object? updateDetails = null,Object? alwaysShowRequiredFields = null,Object? tokenBilling = null,Object? label = null,Object? config = null,Object? feesAndLimits = null,Object? testMode = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_CompanyGatewayApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,gatewayKey: null == gatewayKey ? _self.gatewayKey : gatewayKey // ignore: cast_nullable_to_non_nullable
as String,acceptedCreditCards: null == acceptedCreditCards ? _self.acceptedCreditCards : acceptedCreditCards // ignore: cast_nullable_to_non_nullable
as int,requireCvv: null == requireCvv ? _self.requireCvv : requireCvv // ignore: cast_nullable_to_non_nullable
as bool,requireBillingAddress: null == requireBillingAddress ? _self.requireBillingAddress : requireBillingAddress // ignore: cast_nullable_to_non_nullable
as bool,requireShippingAddress: null == requireShippingAddress ? _self.requireShippingAddress : requireShippingAddress // ignore: cast_nullable_to_non_nullable
as bool,requireClientName: null == requireClientName ? _self.requireClientName : requireClientName // ignore: cast_nullable_to_non_nullable
as bool,requireClientPhone: null == requireClientPhone ? _self.requireClientPhone : requireClientPhone // ignore: cast_nullable_to_non_nullable
as bool,requireContactName: null == requireContactName ? _self.requireContactName : requireContactName // ignore: cast_nullable_to_non_nullable
as bool,requireContactEmail: null == requireContactEmail ? _self.requireContactEmail : requireContactEmail // ignore: cast_nullable_to_non_nullable
as bool,requirePostalCode: null == requirePostalCode ? _self.requirePostalCode : requirePostalCode // ignore: cast_nullable_to_non_nullable
as bool,requireCustomValue1: null == requireCustomValue1 ? _self.requireCustomValue1 : requireCustomValue1 // ignore: cast_nullable_to_non_nullable
as bool,requireCustomValue2: null == requireCustomValue2 ? _self.requireCustomValue2 : requireCustomValue2 // ignore: cast_nullable_to_non_nullable
as bool,requireCustomValue3: null == requireCustomValue3 ? _self.requireCustomValue3 : requireCustomValue3 // ignore: cast_nullable_to_non_nullable
as bool,requireCustomValue4: null == requireCustomValue4 ? _self.requireCustomValue4 : requireCustomValue4 // ignore: cast_nullable_to_non_nullable
as bool,updateDetails: null == updateDetails ? _self.updateDetails : updateDetails // ignore: cast_nullable_to_non_nullable
as bool,alwaysShowRequiredFields: null == alwaysShowRequiredFields ? _self.alwaysShowRequiredFields : alwaysShowRequiredFields // ignore: cast_nullable_to_non_nullable
as bool,tokenBilling: null == tokenBilling ? _self.tokenBilling : tokenBilling // ignore: cast_nullable_to_non_nullable
as String,label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,config: null == config ? _self.config : config // ignore: cast_nullable_to_non_nullable
as String,feesAndLimits: null == feesAndLimits ? _self._feesAndLimits : feesAndLimits // ignore: cast_nullable_to_non_nullable
as Map<String, FeesAndLimitsApi>,testMode: null == testMode ? _self.testMode : testMode // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$CompanyGatewayListApi {

@JsonKey(fromJson: _companyGatewayListData) List<CompanyGatewayApi> get data;
/// Create a copy of CompanyGatewayListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyGatewayListApiCopyWith<CompanyGatewayListApi> get copyWith => _$CompanyGatewayListApiCopyWithImpl<CompanyGatewayListApi>(this as CompanyGatewayListApi, _$identity);

  /// Serializes this CompanyGatewayListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyGatewayListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'CompanyGatewayListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $CompanyGatewayListApiCopyWith<$Res>  {
  factory $CompanyGatewayListApiCopyWith(CompanyGatewayListApi value, $Res Function(CompanyGatewayListApi) _then) = _$CompanyGatewayListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _companyGatewayListData) List<CompanyGatewayApi> data
});




}
/// @nodoc
class _$CompanyGatewayListApiCopyWithImpl<$Res>
    implements $CompanyGatewayListApiCopyWith<$Res> {
  _$CompanyGatewayListApiCopyWithImpl(this._self, this._then);

  final CompanyGatewayListApi _self;
  final $Res Function(CompanyGatewayListApi) _then;

/// Create a copy of CompanyGatewayListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<CompanyGatewayApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [CompanyGatewayListApi].
extension CompanyGatewayListApiPatterns on CompanyGatewayListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyGatewayListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyGatewayListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyGatewayListApi value)  $default,){
final _that = this;
switch (_that) {
case _CompanyGatewayListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyGatewayListApi value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyGatewayListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _companyGatewayListData)  List<CompanyGatewayApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyGatewayListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _companyGatewayListData)  List<CompanyGatewayApi> data)  $default,) {final _that = this;
switch (_that) {
case _CompanyGatewayListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _companyGatewayListData)  List<CompanyGatewayApi> data)?  $default,) {final _that = this;
switch (_that) {
case _CompanyGatewayListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CompanyGatewayListApi implements CompanyGatewayListApi {
  const _CompanyGatewayListApi({@JsonKey(fromJson: _companyGatewayListData) final  List<CompanyGatewayApi> data = const []}): _data = data;
  factory _CompanyGatewayListApi.fromJson(Map<String, dynamic> json) => _$CompanyGatewayListApiFromJson(json);

 final  List<CompanyGatewayApi> _data;
@override@JsonKey(fromJson: _companyGatewayListData) List<CompanyGatewayApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of CompanyGatewayListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyGatewayListApiCopyWith<_CompanyGatewayListApi> get copyWith => __$CompanyGatewayListApiCopyWithImpl<_CompanyGatewayListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyGatewayListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyGatewayListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'CompanyGatewayListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$CompanyGatewayListApiCopyWith<$Res> implements $CompanyGatewayListApiCopyWith<$Res> {
  factory _$CompanyGatewayListApiCopyWith(_CompanyGatewayListApi value, $Res Function(_CompanyGatewayListApi) _then) = __$CompanyGatewayListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _companyGatewayListData) List<CompanyGatewayApi> data
});




}
/// @nodoc
class __$CompanyGatewayListApiCopyWithImpl<$Res>
    implements _$CompanyGatewayListApiCopyWith<$Res> {
  __$CompanyGatewayListApiCopyWithImpl(this._self, this._then);

  final _CompanyGatewayListApi _self;
  final $Res Function(_CompanyGatewayListApi) _then;

/// Create a copy of CompanyGatewayListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_CompanyGatewayListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<CompanyGatewayApi>,
  ));
}


}


/// @nodoc
mixin _$CompanyGatewayItemApi {

 CompanyGatewayApi get data;
/// Create a copy of CompanyGatewayItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyGatewayItemApiCopyWith<CompanyGatewayItemApi> get copyWith => _$CompanyGatewayItemApiCopyWithImpl<CompanyGatewayItemApi>(this as CompanyGatewayItemApi, _$identity);

  /// Serializes this CompanyGatewayItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyGatewayItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'CompanyGatewayItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $CompanyGatewayItemApiCopyWith<$Res>  {
  factory $CompanyGatewayItemApiCopyWith(CompanyGatewayItemApi value, $Res Function(CompanyGatewayItemApi) _then) = _$CompanyGatewayItemApiCopyWithImpl;
@useResult
$Res call({
 CompanyGatewayApi data
});


$CompanyGatewayApiCopyWith<$Res> get data;

}
/// @nodoc
class _$CompanyGatewayItemApiCopyWithImpl<$Res>
    implements $CompanyGatewayItemApiCopyWith<$Res> {
  _$CompanyGatewayItemApiCopyWithImpl(this._self, this._then);

  final CompanyGatewayItemApi _self;
  final $Res Function(CompanyGatewayItemApi) _then;

/// Create a copy of CompanyGatewayItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as CompanyGatewayApi,
  ));
}
/// Create a copy of CompanyGatewayItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyGatewayApiCopyWith<$Res> get data {
  
  return $CompanyGatewayApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [CompanyGatewayItemApi].
extension CompanyGatewayItemApiPatterns on CompanyGatewayItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyGatewayItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyGatewayItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyGatewayItemApi value)  $default,){
final _that = this;
switch (_that) {
case _CompanyGatewayItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyGatewayItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyGatewayItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( CompanyGatewayApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyGatewayItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( CompanyGatewayApi data)  $default,) {final _that = this;
switch (_that) {
case _CompanyGatewayItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( CompanyGatewayApi data)?  $default,) {final _that = this;
switch (_that) {
case _CompanyGatewayItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CompanyGatewayItemApi implements CompanyGatewayItemApi {
  const _CompanyGatewayItemApi({required this.data});
  factory _CompanyGatewayItemApi.fromJson(Map<String, dynamic> json) => _$CompanyGatewayItemApiFromJson(json);

@override final  CompanyGatewayApi data;

/// Create a copy of CompanyGatewayItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyGatewayItemApiCopyWith<_CompanyGatewayItemApi> get copyWith => __$CompanyGatewayItemApiCopyWithImpl<_CompanyGatewayItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CompanyGatewayItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyGatewayItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'CompanyGatewayItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$CompanyGatewayItemApiCopyWith<$Res> implements $CompanyGatewayItemApiCopyWith<$Res> {
  factory _$CompanyGatewayItemApiCopyWith(_CompanyGatewayItemApi value, $Res Function(_CompanyGatewayItemApi) _then) = __$CompanyGatewayItemApiCopyWithImpl;
@override @useResult
$Res call({
 CompanyGatewayApi data
});


@override $CompanyGatewayApiCopyWith<$Res> get data;

}
/// @nodoc
class __$CompanyGatewayItemApiCopyWithImpl<$Res>
    implements _$CompanyGatewayItemApiCopyWith<$Res> {
  __$CompanyGatewayItemApiCopyWithImpl(this._self, this._then);

  final _CompanyGatewayItemApi _self;
  final $Res Function(_CompanyGatewayItemApi) _then;

/// Create a copy of CompanyGatewayItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_CompanyGatewayItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as CompanyGatewayApi,
  ));
}

/// Create a copy of CompanyGatewayItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CompanyGatewayApiCopyWith<$Res> get data {
  
  return $CompanyGatewayApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
