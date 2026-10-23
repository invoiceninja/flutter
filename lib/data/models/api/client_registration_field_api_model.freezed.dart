// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'client_registration_field_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ClientRegistrationFieldApi {

 String get key; bool get required; bool get visible;
/// Create a copy of ClientRegistrationFieldApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClientRegistrationFieldApiCopyWith<ClientRegistrationFieldApi> get copyWith => _$ClientRegistrationFieldApiCopyWithImpl<ClientRegistrationFieldApi>(this as ClientRegistrationFieldApi, _$identity);

  /// Serializes this ClientRegistrationFieldApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ClientRegistrationFieldApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClientRegistrationFieldApi&&(identical(other.key, _this.key) || other.key == _this.key)&&(identical(other.required, _this.required) || other.required == _this.required)&&(identical(other.visible, _this.visible) || other.visible == _this.visible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ClientRegistrationFieldApi;
  return Object.hash(runtimeType,_this.key,_this.required,_this.visible);
}

@override
String toString() {
  final _this = this as ClientRegistrationFieldApi;
  return 'ClientRegistrationFieldApi(key: ${_this.key}, required: ${_this.required}, visible: ${_this.visible})';
}


}

/// @nodoc
abstract mixin class $ClientRegistrationFieldApiCopyWith<$Res>  {
  factory $ClientRegistrationFieldApiCopyWith(ClientRegistrationFieldApi value, $Res Function(ClientRegistrationFieldApi) _then) = _$ClientRegistrationFieldApiCopyWithImpl;
@useResult
$Res call({
 String key, bool required, bool visible
});




}
/// @nodoc
class _$ClientRegistrationFieldApiCopyWithImpl<$Res>
    implements $ClientRegistrationFieldApiCopyWith<$Res> {
  _$ClientRegistrationFieldApiCopyWithImpl(this._self, this._then);

  final ClientRegistrationFieldApi _self;
  final $Res Function(ClientRegistrationFieldApi) _then;

/// Create a copy of ClientRegistrationFieldApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,Object? required = null,Object? visible = null,}) {
  return _then(ClientRegistrationFieldApi(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ClientRegistrationFieldApi].
extension ClientRegistrationFieldApiPatterns on ClientRegistrationFieldApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClientRegistrationFieldApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClientRegistrationFieldApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClientRegistrationFieldApi value)  $default,){
final _that = this;
switch (_that) {
case _ClientRegistrationFieldApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClientRegistrationFieldApi value)?  $default,){
final _that = this;
switch (_that) {
case _ClientRegistrationFieldApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String key,  bool required,  bool visible)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClientRegistrationFieldApi() when $default != null:
return $default(_that.key,_that.required,_that.visible);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String key,  bool required,  bool visible)  $default,) {final _that = this;
switch (_that) {
case _ClientRegistrationFieldApi():
return $default(_that.key,_that.required,_that.visible);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String key,  bool required,  bool visible)?  $default,) {final _that = this;
switch (_that) {
case _ClientRegistrationFieldApi() when $default != null:
return $default(_that.key,_that.required,_that.visible);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _ClientRegistrationFieldApi implements ClientRegistrationFieldApi {
  const _ClientRegistrationFieldApi({this.key = '', this.required = false, this.visible = true});
  factory _ClientRegistrationFieldApi.fromJson(Map<String, dynamic> json) => _$ClientRegistrationFieldApiFromJson(json);

@override@JsonKey() final  String key;
@override@JsonKey() final  bool required;
@override@JsonKey() final  bool visible;

/// Create a copy of ClientRegistrationFieldApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClientRegistrationFieldApiCopyWith<_ClientRegistrationFieldApi> get copyWith => __$ClientRegistrationFieldApiCopyWithImpl<_ClientRegistrationFieldApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClientRegistrationFieldApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClientRegistrationFieldApi&&(identical(other.key, key) || other.key == key)&&(identical(other.required, required) || other.required == required)&&(identical(other.visible, visible) || other.visible == visible));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,key,required,visible);
}

@override
String toString() {
    return 'ClientRegistrationFieldApi(key: $key, required: $required, visible: $visible)';
}


}

/// @nodoc
abstract mixin class _$ClientRegistrationFieldApiCopyWith<$Res> implements $ClientRegistrationFieldApiCopyWith<$Res> {
  factory _$ClientRegistrationFieldApiCopyWith(_ClientRegistrationFieldApi value, $Res Function(_ClientRegistrationFieldApi) _then) = __$ClientRegistrationFieldApiCopyWithImpl;
@override @useResult
$Res call({
 String key, bool required, bool visible
});




}
/// @nodoc
class __$ClientRegistrationFieldApiCopyWithImpl<$Res>
    implements _$ClientRegistrationFieldApiCopyWith<$Res> {
  __$ClientRegistrationFieldApiCopyWithImpl(this._self, this._then);

  final _ClientRegistrationFieldApi _self;
  final $Res Function(_ClientRegistrationFieldApi) _then;

/// Create a copy of ClientRegistrationFieldApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? required = null,Object? visible = null,}) {
  return _then(_ClientRegistrationFieldApi(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,required: null == required ? _self.required : required // ignore: cast_nullable_to_non_nullable
as bool,visible: null == visible ? _self.visible : visible // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
