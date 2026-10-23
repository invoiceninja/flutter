// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gateway_token.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GatewayToken {

 String get id; String get companyGatewayId; String get gatewayTypeId; String get customerReference; bool get isDefault; String get brand; String get last4; String get expMonth; String get expYear; String get cardType;
/// Create a copy of GatewayToken
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GatewayTokenCopyWith<GatewayToken> get copyWith => _$GatewayTokenCopyWithImpl<GatewayToken>(this as GatewayToken, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as GatewayToken;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GatewayToken&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.companyGatewayId, _this.companyGatewayId) || other.companyGatewayId == _this.companyGatewayId)&&(identical(other.gatewayTypeId, _this.gatewayTypeId) || other.gatewayTypeId == _this.gatewayTypeId)&&(identical(other.customerReference, _this.customerReference) || other.customerReference == _this.customerReference)&&(identical(other.isDefault, _this.isDefault) || other.isDefault == _this.isDefault)&&(identical(other.brand, _this.brand) || other.brand == _this.brand)&&(identical(other.last4, _this.last4) || other.last4 == _this.last4)&&(identical(other.expMonth, _this.expMonth) || other.expMonth == _this.expMonth)&&(identical(other.expYear, _this.expYear) || other.expYear == _this.expYear)&&(identical(other.cardType, _this.cardType) || other.cardType == _this.cardType));
}


@override
int get hashCode {
  final _this = this as GatewayToken;
  return Object.hash(runtimeType,_this.id,_this.companyGatewayId,_this.gatewayTypeId,_this.customerReference,_this.isDefault,_this.brand,_this.last4,_this.expMonth,_this.expYear,_this.cardType);
}

@override
String toString() {
  final _this = this as GatewayToken;
  return 'GatewayToken(id: ${_this.id}, companyGatewayId: ${_this.companyGatewayId}, gatewayTypeId: ${_this.gatewayTypeId}, customerReference: ${_this.customerReference}, isDefault: ${_this.isDefault}, brand: ${_this.brand}, last4: ${_this.last4}, expMonth: ${_this.expMonth}, expYear: ${_this.expYear}, cardType: ${_this.cardType})';
}


}

/// @nodoc
abstract mixin class $GatewayTokenCopyWith<$Res>  {
  factory $GatewayTokenCopyWith(GatewayToken value, $Res Function(GatewayToken) _then) = _$GatewayTokenCopyWithImpl;
@useResult
$Res call({
 String id, String companyGatewayId, String gatewayTypeId, String customerReference, bool isDefault, String brand, String last4, String expMonth, String expYear, String cardType
});




}
/// @nodoc
class _$GatewayTokenCopyWithImpl<$Res>
    implements $GatewayTokenCopyWith<$Res> {
  _$GatewayTokenCopyWithImpl(this._self, this._then);

  final GatewayToken _self;
  final $Res Function(GatewayToken) _then;

/// Create a copy of GatewayToken
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? companyGatewayId = null,Object? gatewayTypeId = null,Object? customerReference = null,Object? isDefault = null,Object? brand = null,Object? last4 = null,Object? expMonth = null,Object? expYear = null,Object? cardType = null,}) {
  return _then(GatewayToken(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,companyGatewayId: null == companyGatewayId ? _self.companyGatewayId : companyGatewayId // ignore: cast_nullable_to_non_nullable
as String,gatewayTypeId: null == gatewayTypeId ? _self.gatewayTypeId : gatewayTypeId // ignore: cast_nullable_to_non_nullable
as String,customerReference: null == customerReference ? _self.customerReference : customerReference // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,brand: null == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String,last4: null == last4 ? _self.last4 : last4 // ignore: cast_nullable_to_non_nullable
as String,expMonth: null == expMonth ? _self.expMonth : expMonth // ignore: cast_nullable_to_non_nullable
as String,expYear: null == expYear ? _self.expYear : expYear // ignore: cast_nullable_to_non_nullable
as String,cardType: null == cardType ? _self.cardType : cardType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [GatewayToken].
extension GatewayTokenPatterns on GatewayToken {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GatewayToken value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GatewayToken() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GatewayToken value)  $default,){
final _that = this;
switch (_that) {
case _GatewayToken():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GatewayToken value)?  $default,){
final _that = this;
switch (_that) {
case _GatewayToken() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String companyGatewayId,  String gatewayTypeId,  String customerReference,  bool isDefault,  String brand,  String last4,  String expMonth,  String expYear,  String cardType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GatewayToken() when $default != null:
return $default(_that.id,_that.companyGatewayId,_that.gatewayTypeId,_that.customerReference,_that.isDefault,_that.brand,_that.last4,_that.expMonth,_that.expYear,_that.cardType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String companyGatewayId,  String gatewayTypeId,  String customerReference,  bool isDefault,  String brand,  String last4,  String expMonth,  String expYear,  String cardType)  $default,) {final _that = this;
switch (_that) {
case _GatewayToken():
return $default(_that.id,_that.companyGatewayId,_that.gatewayTypeId,_that.customerReference,_that.isDefault,_that.brand,_that.last4,_that.expMonth,_that.expYear,_that.cardType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String companyGatewayId,  String gatewayTypeId,  String customerReference,  bool isDefault,  String brand,  String last4,  String expMonth,  String expYear,  String cardType)?  $default,) {final _that = this;
switch (_that) {
case _GatewayToken() when $default != null:
return $default(_that.id,_that.companyGatewayId,_that.gatewayTypeId,_that.customerReference,_that.isDefault,_that.brand,_that.last4,_that.expMonth,_that.expYear,_that.cardType);case _:
  return null;

}
}

}

/// @nodoc


class _GatewayToken implements GatewayToken {
  const _GatewayToken({required this.id, required this.companyGatewayId, required this.gatewayTypeId, required this.customerReference, required this.isDefault, this.brand = '', this.last4 = '', this.expMonth = '', this.expYear = '', this.cardType = ''});
  

@override final  String id;
@override final  String companyGatewayId;
@override final  String gatewayTypeId;
@override final  String customerReference;
@override final  bool isDefault;
@override@JsonKey() final  String brand;
@override@JsonKey() final  String last4;
@override@JsonKey() final  String expMonth;
@override@JsonKey() final  String expYear;
@override@JsonKey() final  String cardType;

/// Create a copy of GatewayToken
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GatewayTokenCopyWith<_GatewayToken> get copyWith => __$GatewayTokenCopyWithImpl<_GatewayToken>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GatewayToken&&(identical(other.id, id) || other.id == id)&&(identical(other.companyGatewayId, companyGatewayId) || other.companyGatewayId == companyGatewayId)&&(identical(other.gatewayTypeId, gatewayTypeId) || other.gatewayTypeId == gatewayTypeId)&&(identical(other.customerReference, customerReference) || other.customerReference == customerReference)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.last4, last4) || other.last4 == last4)&&(identical(other.expMonth, expMonth) || other.expMonth == expMonth)&&(identical(other.expYear, expYear) || other.expYear == expYear)&&(identical(other.cardType, cardType) || other.cardType == cardType));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,companyGatewayId,gatewayTypeId,customerReference,isDefault,brand,last4,expMonth,expYear,cardType);
}

@override
String toString() {
    return 'GatewayToken(id: $id, companyGatewayId: $companyGatewayId, gatewayTypeId: $gatewayTypeId, customerReference: $customerReference, isDefault: $isDefault, brand: $brand, last4: $last4, expMonth: $expMonth, expYear: $expYear, cardType: $cardType)';
}


}

/// @nodoc
abstract mixin class _$GatewayTokenCopyWith<$Res> implements $GatewayTokenCopyWith<$Res> {
  factory _$GatewayTokenCopyWith(_GatewayToken value, $Res Function(_GatewayToken) _then) = __$GatewayTokenCopyWithImpl;
@override @useResult
$Res call({
 String id, String companyGatewayId, String gatewayTypeId, String customerReference, bool isDefault, String brand, String last4, String expMonth, String expYear, String cardType
});




}
/// @nodoc
class __$GatewayTokenCopyWithImpl<$Res>
    implements _$GatewayTokenCopyWith<$Res> {
  __$GatewayTokenCopyWithImpl(this._self, this._then);

  final _GatewayToken _self;
  final $Res Function(_GatewayToken) _then;

/// Create a copy of GatewayToken
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? companyGatewayId = null,Object? gatewayTypeId = null,Object? customerReference = null,Object? isDefault = null,Object? brand = null,Object? last4 = null,Object? expMonth = null,Object? expYear = null,Object? cardType = null,}) {
  return _then(_GatewayToken(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,companyGatewayId: null == companyGatewayId ? _self.companyGatewayId : companyGatewayId // ignore: cast_nullable_to_non_nullable
as String,gatewayTypeId: null == gatewayTypeId ? _self.gatewayTypeId : gatewayTypeId // ignore: cast_nullable_to_non_nullable
as String,customerReference: null == customerReference ? _self.customerReference : customerReference // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,brand: null == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String,last4: null == last4 ? _self.last4 : last4 // ignore: cast_nullable_to_non_nullable
as String,expMonth: null == expMonth ? _self.expMonth : expMonth // ignore: cast_nullable_to_non_nullable
as String,expYear: null == expYear ? _self.expYear : expYear // ignore: cast_nullable_to_non_nullable
as String,cardType: null == cardType ? _self.cardType : cardType // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
