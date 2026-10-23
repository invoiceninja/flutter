// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'company_gateway.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CompanyGateway {

 String get id; String get gatewayKey; int get acceptedCreditCards; bool get requireCvv; bool get requireBillingAddress; bool get requireShippingAddress; bool get requireClientName; bool get requireClientPhone; bool get requireContactName; bool get requireContactEmail; bool get requirePostalCode; bool get requireCustomValue1; bool get requireCustomValue2; bool get requireCustomValue3; bool get requireCustomValue4; bool get updateDetails; bool get alwaysShowRequiredFields; String get tokenBilling; String get label; String get config; Map<String, FeesAndLimits> get feesAndLimits; bool get testMode; int get createdAt; int get updatedAt; int get archivedAt; bool get isDeleted; bool get isDirty;
/// Create a copy of CompanyGateway
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CompanyGatewayCopyWith<CompanyGateway> get copyWith => _$CompanyGatewayCopyWithImpl<CompanyGateway>(this as CompanyGateway, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as CompanyGateway;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CompanyGateway&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.gatewayKey, _this.gatewayKey) || other.gatewayKey == _this.gatewayKey)&&(identical(other.acceptedCreditCards, _this.acceptedCreditCards) || other.acceptedCreditCards == _this.acceptedCreditCards)&&(identical(other.requireCvv, _this.requireCvv) || other.requireCvv == _this.requireCvv)&&(identical(other.requireBillingAddress, _this.requireBillingAddress) || other.requireBillingAddress == _this.requireBillingAddress)&&(identical(other.requireShippingAddress, _this.requireShippingAddress) || other.requireShippingAddress == _this.requireShippingAddress)&&(identical(other.requireClientName, _this.requireClientName) || other.requireClientName == _this.requireClientName)&&(identical(other.requireClientPhone, _this.requireClientPhone) || other.requireClientPhone == _this.requireClientPhone)&&(identical(other.requireContactName, _this.requireContactName) || other.requireContactName == _this.requireContactName)&&(identical(other.requireContactEmail, _this.requireContactEmail) || other.requireContactEmail == _this.requireContactEmail)&&(identical(other.requirePostalCode, _this.requirePostalCode) || other.requirePostalCode == _this.requirePostalCode)&&(identical(other.requireCustomValue1, _this.requireCustomValue1) || other.requireCustomValue1 == _this.requireCustomValue1)&&(identical(other.requireCustomValue2, _this.requireCustomValue2) || other.requireCustomValue2 == _this.requireCustomValue2)&&(identical(other.requireCustomValue3, _this.requireCustomValue3) || other.requireCustomValue3 == _this.requireCustomValue3)&&(identical(other.requireCustomValue4, _this.requireCustomValue4) || other.requireCustomValue4 == _this.requireCustomValue4)&&(identical(other.updateDetails, _this.updateDetails) || other.updateDetails == _this.updateDetails)&&(identical(other.alwaysShowRequiredFields, _this.alwaysShowRequiredFields) || other.alwaysShowRequiredFields == _this.alwaysShowRequiredFields)&&(identical(other.tokenBilling, _this.tokenBilling) || other.tokenBilling == _this.tokenBilling)&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.config, _this.config) || other.config == _this.config)&&const DeepCollectionEquality().equals(other.feesAndLimits, _this.feesAndLimits)&&(identical(other.testMode, _this.testMode) || other.testMode == _this.testMode)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt)&&(identical(other.isDeleted, _this.isDeleted) || other.isDeleted == _this.isDeleted)&&(identical(other.isDirty, _this.isDirty) || other.isDirty == _this.isDirty));
}


@override
int get hashCode {
  final _this = this as CompanyGateway;
  return Object.hashAll([runtimeType,_this.id,_this.gatewayKey,_this.acceptedCreditCards,_this.requireCvv,_this.requireBillingAddress,_this.requireShippingAddress,_this.requireClientName,_this.requireClientPhone,_this.requireContactName,_this.requireContactEmail,_this.requirePostalCode,_this.requireCustomValue1,_this.requireCustomValue2,_this.requireCustomValue3,_this.requireCustomValue4,_this.updateDetails,_this.alwaysShowRequiredFields,_this.tokenBilling,_this.label,_this.config,const DeepCollectionEquality().hash(_this.feesAndLimits),_this.testMode,_this.createdAt,_this.updatedAt,_this.archivedAt,_this.isDeleted,_this.isDirty]);
}

@override
String toString() {
  final _this = this as CompanyGateway;
  return 'CompanyGateway(id: ${_this.id}, gatewayKey: ${_this.gatewayKey}, acceptedCreditCards: ${_this.acceptedCreditCards}, requireCvv: ${_this.requireCvv}, requireBillingAddress: ${_this.requireBillingAddress}, requireShippingAddress: ${_this.requireShippingAddress}, requireClientName: ${_this.requireClientName}, requireClientPhone: ${_this.requireClientPhone}, requireContactName: ${_this.requireContactName}, requireContactEmail: ${_this.requireContactEmail}, requirePostalCode: ${_this.requirePostalCode}, requireCustomValue1: ${_this.requireCustomValue1}, requireCustomValue2: ${_this.requireCustomValue2}, requireCustomValue3: ${_this.requireCustomValue3}, requireCustomValue4: ${_this.requireCustomValue4}, updateDetails: ${_this.updateDetails}, alwaysShowRequiredFields: ${_this.alwaysShowRequiredFields}, tokenBilling: ${_this.tokenBilling}, label: ${_this.label}, config: ${_this.config}, feesAndLimits: ${_this.feesAndLimits}, testMode: ${_this.testMode}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, archivedAt: ${_this.archivedAt}, isDeleted: ${_this.isDeleted}, isDirty: ${_this.isDirty})';
}


}

/// @nodoc
abstract mixin class $CompanyGatewayCopyWith<$Res>  {
  factory $CompanyGatewayCopyWith(CompanyGateway value, $Res Function(CompanyGateway) _then) = _$CompanyGatewayCopyWithImpl;
@useResult
$Res call({
 String id, String gatewayKey, int acceptedCreditCards, bool requireCvv, bool requireBillingAddress, bool requireShippingAddress, bool requireClientName, bool requireClientPhone, bool requireContactName, bool requireContactEmail, bool requirePostalCode, bool requireCustomValue1, bool requireCustomValue2, bool requireCustomValue3, bool requireCustomValue4, bool updateDetails, bool alwaysShowRequiredFields, String tokenBilling, String label, String config, Map<String, FeesAndLimits> feesAndLimits, bool testMode, int createdAt, int updatedAt, int archivedAt, bool isDeleted, bool isDirty
});




}
/// @nodoc
class _$CompanyGatewayCopyWithImpl<$Res>
    implements $CompanyGatewayCopyWith<$Res> {
  _$CompanyGatewayCopyWithImpl(this._self, this._then);

  final CompanyGateway _self;
  final $Res Function(CompanyGateway) _then;

/// Create a copy of CompanyGateway
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? gatewayKey = null,Object? acceptedCreditCards = null,Object? requireCvv = null,Object? requireBillingAddress = null,Object? requireShippingAddress = null,Object? requireClientName = null,Object? requireClientPhone = null,Object? requireContactName = null,Object? requireContactEmail = null,Object? requirePostalCode = null,Object? requireCustomValue1 = null,Object? requireCustomValue2 = null,Object? requireCustomValue3 = null,Object? requireCustomValue4 = null,Object? updateDetails = null,Object? alwaysShowRequiredFields = null,Object? tokenBilling = null,Object? label = null,Object? config = null,Object? feesAndLimits = null,Object? testMode = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? isDirty = null,}) {
  return _then(CompanyGateway(
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
as Map<String, FeesAndLimits>,testMode: null == testMode ? _self.testMode : testMode // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [CompanyGateway].
extension CompanyGatewayPatterns on CompanyGateway {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CompanyGateway value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CompanyGateway() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CompanyGateway value)  $default,){
final _that = this;
switch (_that) {
case _CompanyGateway():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CompanyGateway value)?  $default,){
final _that = this;
switch (_that) {
case _CompanyGateway() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String gatewayKey,  int acceptedCreditCards,  bool requireCvv,  bool requireBillingAddress,  bool requireShippingAddress,  bool requireClientName,  bool requireClientPhone,  bool requireContactName,  bool requireContactEmail,  bool requirePostalCode,  bool requireCustomValue1,  bool requireCustomValue2,  bool requireCustomValue3,  bool requireCustomValue4,  bool updateDetails,  bool alwaysShowRequiredFields,  String tokenBilling,  String label,  String config,  Map<String, FeesAndLimits> feesAndLimits,  bool testMode,  int createdAt,  int updatedAt,  int archivedAt,  bool isDeleted,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CompanyGateway() when $default != null:
return $default(_that.id,_that.gatewayKey,_that.acceptedCreditCards,_that.requireCvv,_that.requireBillingAddress,_that.requireShippingAddress,_that.requireClientName,_that.requireClientPhone,_that.requireContactName,_that.requireContactEmail,_that.requirePostalCode,_that.requireCustomValue1,_that.requireCustomValue2,_that.requireCustomValue3,_that.requireCustomValue4,_that.updateDetails,_that.alwaysShowRequiredFields,_that.tokenBilling,_that.label,_that.config,_that.feesAndLimits,_that.testMode,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String gatewayKey,  int acceptedCreditCards,  bool requireCvv,  bool requireBillingAddress,  bool requireShippingAddress,  bool requireClientName,  bool requireClientPhone,  bool requireContactName,  bool requireContactEmail,  bool requirePostalCode,  bool requireCustomValue1,  bool requireCustomValue2,  bool requireCustomValue3,  bool requireCustomValue4,  bool updateDetails,  bool alwaysShowRequiredFields,  String tokenBilling,  String label,  String config,  Map<String, FeesAndLimits> feesAndLimits,  bool testMode,  int createdAt,  int updatedAt,  int archivedAt,  bool isDeleted,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _CompanyGateway():
return $default(_that.id,_that.gatewayKey,_that.acceptedCreditCards,_that.requireCvv,_that.requireBillingAddress,_that.requireShippingAddress,_that.requireClientName,_that.requireClientPhone,_that.requireContactName,_that.requireContactEmail,_that.requirePostalCode,_that.requireCustomValue1,_that.requireCustomValue2,_that.requireCustomValue3,_that.requireCustomValue4,_that.updateDetails,_that.alwaysShowRequiredFields,_that.tokenBilling,_that.label,_that.config,_that.feesAndLimits,_that.testMode,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String gatewayKey,  int acceptedCreditCards,  bool requireCvv,  bool requireBillingAddress,  bool requireShippingAddress,  bool requireClientName,  bool requireClientPhone,  bool requireContactName,  bool requireContactEmail,  bool requirePostalCode,  bool requireCustomValue1,  bool requireCustomValue2,  bool requireCustomValue3,  bool requireCustomValue4,  bool updateDetails,  bool alwaysShowRequiredFields,  String tokenBilling,  String label,  String config,  Map<String, FeesAndLimits> feesAndLimits,  bool testMode,  int createdAt,  int updatedAt,  int archivedAt,  bool isDeleted,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _CompanyGateway() when $default != null:
return $default(_that.id,_that.gatewayKey,_that.acceptedCreditCards,_that.requireCvv,_that.requireBillingAddress,_that.requireShippingAddress,_that.requireClientName,_that.requireClientPhone,_that.requireContactName,_that.requireContactEmail,_that.requirePostalCode,_that.requireCustomValue1,_that.requireCustomValue2,_that.requireCustomValue3,_that.requireCustomValue4,_that.updateDetails,_that.alwaysShowRequiredFields,_that.tokenBilling,_that.label,_that.config,_that.feesAndLimits,_that.testMode,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _CompanyGateway extends CompanyGateway {
  const _CompanyGateway({this.id = '', this.gatewayKey = '', this.acceptedCreditCards = 0, this.requireCvv = false, this.requireBillingAddress = false, this.requireShippingAddress = false, this.requireClientName = false, this.requireClientPhone = false, this.requireContactName = false, this.requireContactEmail = true, this.requirePostalCode = true, this.requireCustomValue1 = false, this.requireCustomValue2 = false, this.requireCustomValue3 = false, this.requireCustomValue4 = false, this.updateDetails = false, this.alwaysShowRequiredFields = true, this.tokenBilling = kAutoBillOff, this.label = '', this.config = '',  Map<String, FeesAndLimits> feesAndLimits = const <String, FeesAndLimits>{}, this.testMode = false, this.createdAt = 0, this.updatedAt = 0, this.archivedAt = 0, this.isDeleted = false, this.isDirty = false}): _feesAndLimits = feesAndLimits,super._();
  

@override@JsonKey() final  String id;
@override@JsonKey() final  String gatewayKey;
@override@JsonKey() final  int acceptedCreditCards;
@override@JsonKey() final  bool requireCvv;
@override@JsonKey() final  bool requireBillingAddress;
@override@JsonKey() final  bool requireShippingAddress;
@override@JsonKey() final  bool requireClientName;
@override@JsonKey() final  bool requireClientPhone;
@override@JsonKey() final  bool requireContactName;
@override@JsonKey() final  bool requireContactEmail;
@override@JsonKey() final  bool requirePostalCode;
@override@JsonKey() final  bool requireCustomValue1;
@override@JsonKey() final  bool requireCustomValue2;
@override@JsonKey() final  bool requireCustomValue3;
@override@JsonKey() final  bool requireCustomValue4;
@override@JsonKey() final  bool updateDetails;
@override@JsonKey() final  bool alwaysShowRequiredFields;
@override@JsonKey() final  String tokenBilling;
@override@JsonKey() final  String label;
@override@JsonKey() final  String config;
 final  Map<String, FeesAndLimits> _feesAndLimits;
@override@JsonKey() Map<String, FeesAndLimits> get feesAndLimits {
  if (_feesAndLimits is EqualUnmodifiableMapView) return _feesAndLimits;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_feesAndLimits);
}

@override@JsonKey() final  bool testMode;
@override@JsonKey() final  int createdAt;
@override@JsonKey() final  int updatedAt;
@override@JsonKey() final  int archivedAt;
@override@JsonKey() final  bool isDeleted;
@override@JsonKey() final  bool isDirty;

/// Create a copy of CompanyGateway
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CompanyGatewayCopyWith<_CompanyGateway> get copyWith => __$CompanyGatewayCopyWithImpl<_CompanyGateway>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CompanyGateway&&(identical(other.id, id) || other.id == id)&&(identical(other.gatewayKey, gatewayKey) || other.gatewayKey == gatewayKey)&&(identical(other.acceptedCreditCards, acceptedCreditCards) || other.acceptedCreditCards == acceptedCreditCards)&&(identical(other.requireCvv, requireCvv) || other.requireCvv == requireCvv)&&(identical(other.requireBillingAddress, requireBillingAddress) || other.requireBillingAddress == requireBillingAddress)&&(identical(other.requireShippingAddress, requireShippingAddress) || other.requireShippingAddress == requireShippingAddress)&&(identical(other.requireClientName, requireClientName) || other.requireClientName == requireClientName)&&(identical(other.requireClientPhone, requireClientPhone) || other.requireClientPhone == requireClientPhone)&&(identical(other.requireContactName, requireContactName) || other.requireContactName == requireContactName)&&(identical(other.requireContactEmail, requireContactEmail) || other.requireContactEmail == requireContactEmail)&&(identical(other.requirePostalCode, requirePostalCode) || other.requirePostalCode == requirePostalCode)&&(identical(other.requireCustomValue1, requireCustomValue1) || other.requireCustomValue1 == requireCustomValue1)&&(identical(other.requireCustomValue2, requireCustomValue2) || other.requireCustomValue2 == requireCustomValue2)&&(identical(other.requireCustomValue3, requireCustomValue3) || other.requireCustomValue3 == requireCustomValue3)&&(identical(other.requireCustomValue4, requireCustomValue4) || other.requireCustomValue4 == requireCustomValue4)&&(identical(other.updateDetails, updateDetails) || other.updateDetails == updateDetails)&&(identical(other.alwaysShowRequiredFields, alwaysShowRequiredFields) || other.alwaysShowRequiredFields == alwaysShowRequiredFields)&&(identical(other.tokenBilling, tokenBilling) || other.tokenBilling == tokenBilling)&&(identical(other.label, label) || other.label == label)&&(identical(other.config, config) || other.config == config)&&const DeepCollectionEquality().equals(other.feesAndLimits, _feesAndLimits)&&(identical(other.testMode, testMode) || other.testMode == testMode)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,id,gatewayKey,acceptedCreditCards,requireCvv,requireBillingAddress,requireShippingAddress,requireClientName,requireClientPhone,requireContactName,requireContactEmail,requirePostalCode,requireCustomValue1,requireCustomValue2,requireCustomValue3,requireCustomValue4,updateDetails,alwaysShowRequiredFields,tokenBilling,label,config,const DeepCollectionEquality().hash(_feesAndLimits),testMode,createdAt,updatedAt,archivedAt,isDeleted,isDirty]);
}

@override
String toString() {
    return 'CompanyGateway(id: $id, gatewayKey: $gatewayKey, acceptedCreditCards: $acceptedCreditCards, requireCvv: $requireCvv, requireBillingAddress: $requireBillingAddress, requireShippingAddress: $requireShippingAddress, requireClientName: $requireClientName, requireClientPhone: $requireClientPhone, requireContactName: $requireContactName, requireContactEmail: $requireContactEmail, requirePostalCode: $requirePostalCode, requireCustomValue1: $requireCustomValue1, requireCustomValue2: $requireCustomValue2, requireCustomValue3: $requireCustomValue3, requireCustomValue4: $requireCustomValue4, updateDetails: $updateDetails, alwaysShowRequiredFields: $alwaysShowRequiredFields, tokenBilling: $tokenBilling, label: $label, config: $config, feesAndLimits: $feesAndLimits, testMode: $testMode, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$CompanyGatewayCopyWith<$Res> implements $CompanyGatewayCopyWith<$Res> {
  factory _$CompanyGatewayCopyWith(_CompanyGateway value, $Res Function(_CompanyGateway) _then) = __$CompanyGatewayCopyWithImpl;
@override @useResult
$Res call({
 String id, String gatewayKey, int acceptedCreditCards, bool requireCvv, bool requireBillingAddress, bool requireShippingAddress, bool requireClientName, bool requireClientPhone, bool requireContactName, bool requireContactEmail, bool requirePostalCode, bool requireCustomValue1, bool requireCustomValue2, bool requireCustomValue3, bool requireCustomValue4, bool updateDetails, bool alwaysShowRequiredFields, String tokenBilling, String label, String config, Map<String, FeesAndLimits> feesAndLimits, bool testMode, int createdAt, int updatedAt, int archivedAt, bool isDeleted, bool isDirty
});




}
/// @nodoc
class __$CompanyGatewayCopyWithImpl<$Res>
    implements _$CompanyGatewayCopyWith<$Res> {
  __$CompanyGatewayCopyWithImpl(this._self, this._then);

  final _CompanyGateway _self;
  final $Res Function(_CompanyGateway) _then;

/// Create a copy of CompanyGateway
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? gatewayKey = null,Object? acceptedCreditCards = null,Object? requireCvv = null,Object? requireBillingAddress = null,Object? requireShippingAddress = null,Object? requireClientName = null,Object? requireClientPhone = null,Object? requireContactName = null,Object? requireContactEmail = null,Object? requirePostalCode = null,Object? requireCustomValue1 = null,Object? requireCustomValue2 = null,Object? requireCustomValue3 = null,Object? requireCustomValue4 = null,Object? updateDetails = null,Object? alwaysShowRequiredFields = null,Object? tokenBilling = null,Object? label = null,Object? config = null,Object? feesAndLimits = null,Object? testMode = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? isDirty = null,}) {
  return _then(_CompanyGateway(
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
as Map<String, FeesAndLimits>,testMode: null == testMode ? _self.testMode : testMode // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
