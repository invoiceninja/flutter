// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'gateway_token_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GatewayTokenApi {

 String get id;@JsonKey(name: 'company_gateway_id') String get companyGatewayId;@JsonKey(name: 'gateway_type_id') String get gatewayTypeId;@JsonKey(name: 'gateway_customer_reference') String get gatewayCustomerReference;@JsonKey(name: 'is_default') bool get isDefault; Map<String, dynamic>? get meta;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of GatewayTokenApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GatewayTokenApiCopyWith<GatewayTokenApi> get copyWith => _$GatewayTokenApiCopyWithImpl<GatewayTokenApi>(this as GatewayTokenApi, _$identity);

  /// Serializes this GatewayTokenApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as GatewayTokenApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GatewayTokenApi&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.companyGatewayId, _this.companyGatewayId) || other.companyGatewayId == _this.companyGatewayId)&&(identical(other.gatewayTypeId, _this.gatewayTypeId) || other.gatewayTypeId == _this.gatewayTypeId)&&(identical(other.gatewayCustomerReference, _this.gatewayCustomerReference) || other.gatewayCustomerReference == _this.gatewayCustomerReference)&&(identical(other.isDefault, _this.isDefault) || other.isDefault == _this.isDefault)&&const DeepCollectionEquality().equals(other.meta, _this.meta)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt)&&(identical(other.isDeleted, _this.isDeleted) || other.isDeleted == _this.isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as GatewayTokenApi;
  return Object.hash(runtimeType,_this.id,_this.companyGatewayId,_this.gatewayTypeId,_this.gatewayCustomerReference,_this.isDefault,const DeepCollectionEquality().hash(_this.meta),_this.createdAt,_this.updatedAt,_this.archivedAt,_this.isDeleted);
}

@override
String toString() {
  final _this = this as GatewayTokenApi;
  return 'GatewayTokenApi(id: ${_this.id}, companyGatewayId: ${_this.companyGatewayId}, gatewayTypeId: ${_this.gatewayTypeId}, gatewayCustomerReference: ${_this.gatewayCustomerReference}, isDefault: ${_this.isDefault}, meta: ${_this.meta}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, archivedAt: ${_this.archivedAt}, isDeleted: ${_this.isDeleted})';
}


}

/// @nodoc
abstract mixin class $GatewayTokenApiCopyWith<$Res>  {
  factory $GatewayTokenApiCopyWith(GatewayTokenApi value, $Res Function(GatewayTokenApi) _then) = _$GatewayTokenApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'company_gateway_id') String companyGatewayId,@JsonKey(name: 'gateway_type_id') String gatewayTypeId,@JsonKey(name: 'gateway_customer_reference') String gatewayCustomerReference,@JsonKey(name: 'is_default') bool isDefault, Map<String, dynamic>? meta,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class _$GatewayTokenApiCopyWithImpl<$Res>
    implements $GatewayTokenApiCopyWith<$Res> {
  _$GatewayTokenApiCopyWithImpl(this._self, this._then);

  final GatewayTokenApi _self;
  final $Res Function(GatewayTokenApi) _then;

/// Create a copy of GatewayTokenApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? companyGatewayId = null,Object? gatewayTypeId = null,Object? gatewayCustomerReference = null,Object? isDefault = null,Object? meta = freezed,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(GatewayTokenApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,companyGatewayId: null == companyGatewayId ? _self.companyGatewayId : companyGatewayId // ignore: cast_nullable_to_non_nullable
as String,gatewayTypeId: null == gatewayTypeId ? _self.gatewayTypeId : gatewayTypeId // ignore: cast_nullable_to_non_nullable
as String,gatewayCustomerReference: null == gatewayCustomerReference ? _self.gatewayCustomerReference : gatewayCustomerReference // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GatewayTokenApi].
extension GatewayTokenApiPatterns on GatewayTokenApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GatewayTokenApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GatewayTokenApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GatewayTokenApi value)  $default,){
final _that = this;
switch (_that) {
case _GatewayTokenApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GatewayTokenApi value)?  $default,){
final _that = this;
switch (_that) {
case _GatewayTokenApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'company_gateway_id')  String companyGatewayId, @JsonKey(name: 'gateway_type_id')  String gatewayTypeId, @JsonKey(name: 'gateway_customer_reference')  String gatewayCustomerReference, @JsonKey(name: 'is_default')  bool isDefault,  Map<String, dynamic>? meta, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GatewayTokenApi() when $default != null:
return $default(_that.id,_that.companyGatewayId,_that.gatewayTypeId,_that.gatewayCustomerReference,_that.isDefault,_that.meta,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'company_gateway_id')  String companyGatewayId, @JsonKey(name: 'gateway_type_id')  String gatewayTypeId, @JsonKey(name: 'gateway_customer_reference')  String gatewayCustomerReference, @JsonKey(name: 'is_default')  bool isDefault,  Map<String, dynamic>? meta, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _GatewayTokenApi():
return $default(_that.id,_that.companyGatewayId,_that.gatewayTypeId,_that.gatewayCustomerReference,_that.isDefault,_that.meta,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'company_gateway_id')  String companyGatewayId, @JsonKey(name: 'gateway_type_id')  String gatewayTypeId, @JsonKey(name: 'gateway_customer_reference')  String gatewayCustomerReference, @JsonKey(name: 'is_default')  bool isDefault,  Map<String, dynamic>? meta, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _GatewayTokenApi() when $default != null:
return $default(_that.id,_that.companyGatewayId,_that.gatewayTypeId,_that.gatewayCustomerReference,_that.isDefault,_that.meta,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GatewayTokenApi implements GatewayTokenApi {
  const _GatewayTokenApi({this.id = '', @JsonKey(name: 'company_gateway_id') this.companyGatewayId = '', @JsonKey(name: 'gateway_type_id') this.gatewayTypeId = '', @JsonKey(name: 'gateway_customer_reference') this.gatewayCustomerReference = '', @JsonKey(name: 'is_default') this.isDefault = false,  Map<String, dynamic>? meta, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false}): _meta = meta;
  factory _GatewayTokenApi.fromJson(Map<String, dynamic> json) => _$GatewayTokenApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'company_gateway_id') final  String companyGatewayId;
@override@JsonKey(name: 'gateway_type_id') final  String gatewayTypeId;
@override@JsonKey(name: 'gateway_customer_reference') final  String gatewayCustomerReference;
@override@JsonKey(name: 'is_default') final  bool isDefault;
 final  Map<String, dynamic>? _meta;
@override Map<String, dynamic>? get meta {
  final value = _meta;
  if (value == null) return null;
  if (_meta is EqualUnmodifiableMapView) return _meta;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of GatewayTokenApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GatewayTokenApiCopyWith<_GatewayTokenApi> get copyWith => __$GatewayTokenApiCopyWithImpl<_GatewayTokenApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GatewayTokenApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _GatewayTokenApi&&(identical(other.id, id) || other.id == id)&&(identical(other.companyGatewayId, companyGatewayId) || other.companyGatewayId == companyGatewayId)&&(identical(other.gatewayTypeId, gatewayTypeId) || other.gatewayTypeId == gatewayTypeId)&&(identical(other.gatewayCustomerReference, gatewayCustomerReference) || other.gatewayCustomerReference == gatewayCustomerReference)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&const DeepCollectionEquality().equals(other.meta, _meta)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,companyGatewayId,gatewayTypeId,gatewayCustomerReference,isDefault,const DeepCollectionEquality().hash(_meta),createdAt,updatedAt,archivedAt,isDeleted);
}

@override
String toString() {
    return 'GatewayTokenApi(id: $id, companyGatewayId: $companyGatewayId, gatewayTypeId: $gatewayTypeId, gatewayCustomerReference: $gatewayCustomerReference, isDefault: $isDefault, meta: $meta, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$GatewayTokenApiCopyWith<$Res> implements $GatewayTokenApiCopyWith<$Res> {
  factory _$GatewayTokenApiCopyWith(_GatewayTokenApi value, $Res Function(_GatewayTokenApi) _then) = __$GatewayTokenApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'company_gateway_id') String companyGatewayId,@JsonKey(name: 'gateway_type_id') String gatewayTypeId,@JsonKey(name: 'gateway_customer_reference') String gatewayCustomerReference,@JsonKey(name: 'is_default') bool isDefault, Map<String, dynamic>? meta,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class __$GatewayTokenApiCopyWithImpl<$Res>
    implements _$GatewayTokenApiCopyWith<$Res> {
  __$GatewayTokenApiCopyWithImpl(this._self, this._then);

  final _GatewayTokenApi _self;
  final $Res Function(_GatewayTokenApi) _then;

/// Create a copy of GatewayTokenApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? companyGatewayId = null,Object? gatewayTypeId = null,Object? gatewayCustomerReference = null,Object? isDefault = null,Object? meta = freezed,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_GatewayTokenApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,companyGatewayId: null == companyGatewayId ? _self.companyGatewayId : companyGatewayId // ignore: cast_nullable_to_non_nullable
as String,gatewayTypeId: null == gatewayTypeId ? _self.gatewayTypeId : gatewayTypeId // ignore: cast_nullable_to_non_nullable
as String,gatewayCustomerReference: null == gatewayCustomerReference ? _self.gatewayCustomerReference : gatewayCustomerReference // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,meta: freezed == meta ? _self._meta : meta // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
