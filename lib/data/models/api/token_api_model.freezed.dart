// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'token_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TokenApi {

 String get id;@JsonKey(name: 'user_id') String get userId; String get token; String get name;@JsonKey(name: 'is_system') bool get isSystem;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;
/// Create a copy of TokenApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TokenApiCopyWith<TokenApi> get copyWith => _$TokenApiCopyWithImpl<TokenApi>(this as TokenApi, _$identity);

  /// Serializes this TokenApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TokenApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,token,name,isSystem,isDeleted,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'TokenApi(id: $id, userId: $userId, token: $token, name: $name, isSystem: $isSystem, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $TokenApiCopyWith<$Res>  {
  factory $TokenApiCopyWith(TokenApi value, $Res Function(TokenApi) _then) = _$TokenApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, String token, String name,@JsonKey(name: 'is_system') bool isSystem,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class _$TokenApiCopyWithImpl<$Res>
    implements $TokenApiCopyWith<$Res> {
  _$TokenApiCopyWithImpl(this._self, this._then);

  final TokenApi _self;
  final $Res Function(TokenApi) _then;

/// Create a copy of TokenApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? token = null,Object? name = null,Object? isSystem = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isSystem: null == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TokenApi].
extension TokenApiPatterns on TokenApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TokenApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TokenApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TokenApi value)  $default,){
final _that = this;
switch (_that) {
case _TokenApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TokenApi value)?  $default,){
final _that = this;
switch (_that) {
case _TokenApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  String token,  String name, @JsonKey(name: 'is_system')  bool isSystem, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TokenApi() when $default != null:
return $default(_that.id,_that.userId,_that.token,_that.name,_that.isSystem,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId,  String token,  String name, @JsonKey(name: 'is_system')  bool isSystem, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _TokenApi():
return $default(_that.id,_that.userId,_that.token,_that.name,_that.isSystem,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId,  String token,  String name, @JsonKey(name: 'is_system')  bool isSystem, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _TokenApi() when $default != null:
return $default(_that.id,_that.userId,_that.token,_that.name,_that.isSystem,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _TokenApi implements TokenApi {
  const _TokenApi({this.id = '', @JsonKey(name: 'user_id') this.userId = '', this.token = '', this.name = '', @JsonKey(name: 'is_system') this.isSystem = false, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0});
  factory _TokenApi.fromJson(Map<String, dynamic> json) => _$TokenApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey() final  String token;
@override@JsonKey() final  String name;
@override@JsonKey(name: 'is_system') final  bool isSystem;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;

/// Create a copy of TokenApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TokenApiCopyWith<_TokenApi> get copyWith => __$TokenApiCopyWithImpl<_TokenApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TokenApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TokenApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.token, token) || other.token == token)&&(identical(other.name, name) || other.name == name)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,token,name,isSystem,isDeleted,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'TokenApi(id: $id, userId: $userId, token: $token, name: $name, isSystem: $isSystem, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$TokenApiCopyWith<$Res> implements $TokenApiCopyWith<$Res> {
  factory _$TokenApiCopyWith(_TokenApi value, $Res Function(_TokenApi) _then) = __$TokenApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId, String token, String name,@JsonKey(name: 'is_system') bool isSystem,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class __$TokenApiCopyWithImpl<$Res>
    implements _$TokenApiCopyWith<$Res> {
  __$TokenApiCopyWithImpl(this._self, this._then);

  final _TokenApi _self;
  final $Res Function(_TokenApi) _then;

/// Create a copy of TokenApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? token = null,Object? name = null,Object? isSystem = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_TokenApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,token: null == token ? _self.token : token // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,isSystem: null == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TokenListApi {

@JsonKey(fromJson: _tokenListData) List<TokenApi> get data;
/// Create a copy of TokenListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TokenListApiCopyWith<TokenListApi> get copyWith => _$TokenListApiCopyWithImpl<TokenListApi>(this as TokenListApi, _$identity);

  /// Serializes this TokenListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TokenListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'TokenListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $TokenListApiCopyWith<$Res>  {
  factory $TokenListApiCopyWith(TokenListApi value, $Res Function(TokenListApi) _then) = _$TokenListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _tokenListData) List<TokenApi> data
});




}
/// @nodoc
class _$TokenListApiCopyWithImpl<$Res>
    implements $TokenListApiCopyWith<$Res> {
  _$TokenListApiCopyWithImpl(this._self, this._then);

  final TokenListApi _self;
  final $Res Function(TokenListApi) _then;

/// Create a copy of TokenListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<TokenApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [TokenListApi].
extension TokenListApiPatterns on TokenListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TokenListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TokenListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TokenListApi value)  $default,){
final _that = this;
switch (_that) {
case _TokenListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TokenListApi value)?  $default,){
final _that = this;
switch (_that) {
case _TokenListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _tokenListData)  List<TokenApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TokenListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _tokenListData)  List<TokenApi> data)  $default,) {final _that = this;
switch (_that) {
case _TokenListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _tokenListData)  List<TokenApi> data)?  $default,) {final _that = this;
switch (_that) {
case _TokenListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TokenListApi implements TokenListApi {
  const _TokenListApi({@JsonKey(fromJson: _tokenListData) final  List<TokenApi> data = const []}): _data = data;
  factory _TokenListApi.fromJson(Map<String, dynamic> json) => _$TokenListApiFromJson(json);

 final  List<TokenApi> _data;
@override@JsonKey(fromJson: _tokenListData) List<TokenApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of TokenListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TokenListApiCopyWith<_TokenListApi> get copyWith => __$TokenListApiCopyWithImpl<_TokenListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TokenListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TokenListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'TokenListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TokenListApiCopyWith<$Res> implements $TokenListApiCopyWith<$Res> {
  factory _$TokenListApiCopyWith(_TokenListApi value, $Res Function(_TokenListApi) _then) = __$TokenListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _tokenListData) List<TokenApi> data
});




}
/// @nodoc
class __$TokenListApiCopyWithImpl<$Res>
    implements _$TokenListApiCopyWith<$Res> {
  __$TokenListApiCopyWithImpl(this._self, this._then);

  final _TokenListApi _self;
  final $Res Function(_TokenListApi) _then;

/// Create a copy of TokenListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TokenListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<TokenApi>,
  ));
}


}


/// @nodoc
mixin _$TokenItemApi {

 TokenApi get data;
/// Create a copy of TokenItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TokenItemApiCopyWith<TokenItemApi> get copyWith => _$TokenItemApiCopyWithImpl<TokenItemApi>(this as TokenItemApi, _$identity);

  /// Serializes this TokenItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TokenItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'TokenItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $TokenItemApiCopyWith<$Res>  {
  factory $TokenItemApiCopyWith(TokenItemApi value, $Res Function(TokenItemApi) _then) = _$TokenItemApiCopyWithImpl;
@useResult
$Res call({
 TokenApi data
});


$TokenApiCopyWith<$Res> get data;

}
/// @nodoc
class _$TokenItemApiCopyWithImpl<$Res>
    implements $TokenItemApiCopyWith<$Res> {
  _$TokenItemApiCopyWithImpl(this._self, this._then);

  final TokenItemApi _self;
  final $Res Function(TokenItemApi) _then;

/// Create a copy of TokenItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TokenApi,
  ));
}
/// Create a copy of TokenItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TokenApiCopyWith<$Res> get data {
  
  return $TokenApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [TokenItemApi].
extension TokenItemApiPatterns on TokenItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TokenItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TokenItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TokenItemApi value)  $default,){
final _that = this;
switch (_that) {
case _TokenItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TokenItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _TokenItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TokenApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TokenItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TokenApi data)  $default,) {final _that = this;
switch (_that) {
case _TokenItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TokenApi data)?  $default,) {final _that = this;
switch (_that) {
case _TokenItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TokenItemApi implements TokenItemApi {
  const _TokenItemApi({required this.data});
  factory _TokenItemApi.fromJson(Map<String, dynamic> json) => _$TokenItemApiFromJson(json);

@override final  TokenApi data;

/// Create a copy of TokenItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TokenItemApiCopyWith<_TokenItemApi> get copyWith => __$TokenItemApiCopyWithImpl<_TokenItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TokenItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TokenItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'TokenItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TokenItemApiCopyWith<$Res> implements $TokenItemApiCopyWith<$Res> {
  factory _$TokenItemApiCopyWith(_TokenItemApi value, $Res Function(_TokenItemApi) _then) = __$TokenItemApiCopyWithImpl;
@override @useResult
$Res call({
 TokenApi data
});


@override $TokenApiCopyWith<$Res> get data;

}
/// @nodoc
class __$TokenItemApiCopyWithImpl<$Res>
    implements _$TokenItemApiCopyWith<$Res> {
  __$TokenItemApiCopyWithImpl(this._self, this._then);

  final _TokenItemApi _self;
  final $Res Function(_TokenItemApi) _then;

/// Create a copy of TokenItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TokenItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TokenApi,
  ));
}

/// Create a copy of TokenItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TokenApiCopyWith<$Res> get data {
  
  return $TokenApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
