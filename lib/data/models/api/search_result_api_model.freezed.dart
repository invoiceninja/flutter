// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'search_result_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SearchResultApi {

 String get name; String get type; String get id; String get path;
/// Create a copy of SearchResultApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SearchResultApiCopyWith<SearchResultApi> get copyWith => _$SearchResultApiCopyWithImpl<SearchResultApi>(this as SearchResultApi, _$identity);

  /// Serializes this SearchResultApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SearchResultApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SearchResultApi&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.path, _this.path) || other.path == _this.path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SearchResultApi;
  return Object.hash(runtimeType,_this.name,_this.type,_this.id,_this.path);
}

@override
String toString() {
  final _this = this as SearchResultApi;
  return 'SearchResultApi(name: ${_this.name}, type: ${_this.type}, id: ${_this.id}, path: ${_this.path})';
}


}

/// @nodoc
abstract mixin class $SearchResultApiCopyWith<$Res>  {
  factory $SearchResultApiCopyWith(SearchResultApi value, $Res Function(SearchResultApi) _then) = _$SearchResultApiCopyWithImpl;
@useResult
$Res call({
 String name, String type, String id, String path
});




}
/// @nodoc
class _$SearchResultApiCopyWithImpl<$Res>
    implements $SearchResultApiCopyWith<$Res> {
  _$SearchResultApiCopyWithImpl(this._self, this._then);

  final SearchResultApi _self;
  final $Res Function(SearchResultApi) _then;

/// Create a copy of SearchResultApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? type = null,Object? id = null,Object? path = null,}) {
  return _then(SearchResultApi(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SearchResultApi].
extension SearchResultApiPatterns on SearchResultApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SearchResultApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SearchResultApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SearchResultApi value)  $default,){
final _that = this;
switch (_that) {
case _SearchResultApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SearchResultApi value)?  $default,){
final _that = this;
switch (_that) {
case _SearchResultApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String type,  String id,  String path)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SearchResultApi() when $default != null:
return $default(_that.name,_that.type,_that.id,_that.path);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String type,  String id,  String path)  $default,) {final _that = this;
switch (_that) {
case _SearchResultApi():
return $default(_that.name,_that.type,_that.id,_that.path);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String type,  String id,  String path)?  $default,) {final _that = this;
switch (_that) {
case _SearchResultApi() when $default != null:
return $default(_that.name,_that.type,_that.id,_that.path);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SearchResultApi implements SearchResultApi {
  const _SearchResultApi({this.name = '', this.type = '', this.id = '', this.path = ''});
  factory _SearchResultApi.fromJson(Map<String, dynamic> json) => _$SearchResultApiFromJson(json);

@override@JsonKey() final  String name;
@override@JsonKey() final  String type;
@override@JsonKey() final  String id;
@override@JsonKey() final  String path;

/// Create a copy of SearchResultApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SearchResultApiCopyWith<_SearchResultApi> get copyWith => __$SearchResultApiCopyWithImpl<_SearchResultApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SearchResultApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SearchResultApi&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.id, id) || other.id == id)&&(identical(other.path, path) || other.path == path));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,name,type,id,path);
}

@override
String toString() {
    return 'SearchResultApi(name: $name, type: $type, id: $id, path: $path)';
}


}

/// @nodoc
abstract mixin class _$SearchResultApiCopyWith<$Res> implements $SearchResultApiCopyWith<$Res> {
  factory _$SearchResultApiCopyWith(_SearchResultApi value, $Res Function(_SearchResultApi) _then) = __$SearchResultApiCopyWithImpl;
@override @useResult
$Res call({
 String name, String type, String id, String path
});




}
/// @nodoc
class __$SearchResultApiCopyWithImpl<$Res>
    implements _$SearchResultApiCopyWith<$Res> {
  __$SearchResultApiCopyWithImpl(this._self, this._then);

  final _SearchResultApi _self;
  final $Res Function(_SearchResultApi) _then;

/// Create a copy of SearchResultApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? type = null,Object? id = null,Object? path = null,}) {
  return _then(_SearchResultApi(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
