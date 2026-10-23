// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'two_factor_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TwoFactorSetupApi {

@JsonKey(name: 'qrCode') String get qrCode; String get secret;
/// Create a copy of TwoFactorSetupApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TwoFactorSetupApiCopyWith<TwoFactorSetupApi> get copyWith => _$TwoFactorSetupApiCopyWithImpl<TwoFactorSetupApi>(this as TwoFactorSetupApi, _$identity);

  /// Serializes this TwoFactorSetupApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TwoFactorSetupApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TwoFactorSetupApi&&(identical(other.qrCode, _this.qrCode) || other.qrCode == _this.qrCode)&&(identical(other.secret, _this.secret) || other.secret == _this.secret));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TwoFactorSetupApi;
  return Object.hash(runtimeType,_this.qrCode,_this.secret);
}

@override
String toString() {
  final _this = this as TwoFactorSetupApi;
  return 'TwoFactorSetupApi(qrCode: ${_this.qrCode}, secret: ${_this.secret})';
}


}

/// @nodoc
abstract mixin class $TwoFactorSetupApiCopyWith<$Res>  {
  factory $TwoFactorSetupApiCopyWith(TwoFactorSetupApi value, $Res Function(TwoFactorSetupApi) _then) = _$TwoFactorSetupApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'qrCode') String qrCode, String secret
});




}
/// @nodoc
class _$TwoFactorSetupApiCopyWithImpl<$Res>
    implements $TwoFactorSetupApiCopyWith<$Res> {
  _$TwoFactorSetupApiCopyWithImpl(this._self, this._then);

  final TwoFactorSetupApi _self;
  final $Res Function(TwoFactorSetupApi) _then;

/// Create a copy of TwoFactorSetupApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? qrCode = null,Object? secret = null,}) {
  return _then(TwoFactorSetupApi(
qrCode: null == qrCode ? _self.qrCode : qrCode // ignore: cast_nullable_to_non_nullable
as String,secret: null == secret ? _self.secret : secret // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TwoFactorSetupApi].
extension TwoFactorSetupApiPatterns on TwoFactorSetupApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TwoFactorSetupApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TwoFactorSetupApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TwoFactorSetupApi value)  $default,){
final _that = this;
switch (_that) {
case _TwoFactorSetupApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TwoFactorSetupApi value)?  $default,){
final _that = this;
switch (_that) {
case _TwoFactorSetupApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'qrCode')  String qrCode,  String secret)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TwoFactorSetupApi() when $default != null:
return $default(_that.qrCode,_that.secret);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'qrCode')  String qrCode,  String secret)  $default,) {final _that = this;
switch (_that) {
case _TwoFactorSetupApi():
return $default(_that.qrCode,_that.secret);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'qrCode')  String qrCode,  String secret)?  $default,) {final _that = this;
switch (_that) {
case _TwoFactorSetupApi() when $default != null:
return $default(_that.qrCode,_that.secret);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TwoFactorSetupApi implements TwoFactorSetupApi {
  const _TwoFactorSetupApi({@JsonKey(name: 'qrCode') this.qrCode = '', this.secret = ''});
  factory _TwoFactorSetupApi.fromJson(Map<String, dynamic> json) => _$TwoFactorSetupApiFromJson(json);

@override@JsonKey(name: 'qrCode') final  String qrCode;
@override@JsonKey() final  String secret;

/// Create a copy of TwoFactorSetupApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TwoFactorSetupApiCopyWith<_TwoFactorSetupApi> get copyWith => __$TwoFactorSetupApiCopyWithImpl<_TwoFactorSetupApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TwoFactorSetupApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TwoFactorSetupApi&&(identical(other.qrCode, qrCode) || other.qrCode == qrCode)&&(identical(other.secret, secret) || other.secret == secret));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,qrCode,secret);
}

@override
String toString() {
    return 'TwoFactorSetupApi(qrCode: $qrCode, secret: $secret)';
}


}

/// @nodoc
abstract mixin class _$TwoFactorSetupApiCopyWith<$Res> implements $TwoFactorSetupApiCopyWith<$Res> {
  factory _$TwoFactorSetupApiCopyWith(_TwoFactorSetupApi value, $Res Function(_TwoFactorSetupApi) _then) = __$TwoFactorSetupApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'qrCode') String qrCode, String secret
});




}
/// @nodoc
class __$TwoFactorSetupApiCopyWithImpl<$Res>
    implements _$TwoFactorSetupApiCopyWith<$Res> {
  __$TwoFactorSetupApiCopyWithImpl(this._self, this._then);

  final _TwoFactorSetupApi _self;
  final $Res Function(_TwoFactorSetupApi) _then;

/// Create a copy of TwoFactorSetupApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? qrCode = null,Object? secret = null,}) {
  return _then(_TwoFactorSetupApi(
qrCode: null == qrCode ? _self.qrCode : qrCode // ignore: cast_nullable_to_non_nullable
as String,secret: null == secret ? _self.secret : secret // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
