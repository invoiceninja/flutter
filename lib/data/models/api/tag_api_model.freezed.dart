// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tag_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TagApi {

 String get id;// Echoed as the FQCN by the server; normalize via [normalizeTagEntityType]
// before it reaches the domain model.
@JsonKey(name: 'entity_type') String get entityType; String get name;// Hex string (`#RRGGBB`) or null when unset.
 String? get color;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;
/// Create a copy of TagApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TagApiCopyWith<TagApi> get copyWith => _$TagApiCopyWithImpl<TagApi>(this as TagApi, _$identity);

  /// Serializes this TagApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TagApi&&(identical(other.id, id) || other.id == id)&&(identical(other.entityType, entityType) || other.entityType == entityType)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,entityType,name,color,isDeleted,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'TagApi(id: $id, entityType: $entityType, name: $name, color: $color, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $TagApiCopyWith<$Res>  {
  factory $TagApiCopyWith(TagApi value, $Res Function(TagApi) _then) = _$TagApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'entity_type') String entityType, String name, String? color,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class _$TagApiCopyWithImpl<$Res>
    implements $TagApiCopyWith<$Res> {
  _$TagApiCopyWithImpl(this._self, this._then);

  final TagApi _self;
  final $Res Function(TagApi) _then;

/// Create a copy of TagApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? entityType = null,Object? name = null,Object? color = freezed,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entityType: null == entityType ? _self.entityType : entityType // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [TagApi].
extension TagApiPatterns on TagApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TagApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TagApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TagApi value)  $default,){
final _that = this;
switch (_that) {
case _TagApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TagApi value)?  $default,){
final _that = this;
switch (_that) {
case _TagApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'entity_type')  String entityType,  String name,  String? color, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TagApi() when $default != null:
return $default(_that.id,_that.entityType,_that.name,_that.color,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'entity_type')  String entityType,  String name,  String? color, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _TagApi():
return $default(_that.id,_that.entityType,_that.name,_that.color,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'entity_type')  String entityType,  String name,  String? color, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _TagApi() when $default != null:
return $default(_that.id,_that.entityType,_that.name,_that.color,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TagApi implements TagApi {
  const _TagApi({this.id = '', @JsonKey(name: 'entity_type') this.entityType = '', this.name = '', this.color, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0});
  factory _TagApi.fromJson(Map<String, dynamic> json) => _$TagApiFromJson(json);

@override@JsonKey() final  String id;
// Echoed as the FQCN by the server; normalize via [normalizeTagEntityType]
// before it reaches the domain model.
@override@JsonKey(name: 'entity_type') final  String entityType;
@override@JsonKey() final  String name;
// Hex string (`#RRGGBB`) or null when unset.
@override final  String? color;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;

/// Create a copy of TagApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TagApiCopyWith<_TagApi> get copyWith => __$TagApiCopyWithImpl<_TagApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TagApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TagApi&&(identical(other.id, id) || other.id == id)&&(identical(other.entityType, entityType) || other.entityType == entityType)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,entityType,name,color,isDeleted,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'TagApi(id: $id, entityType: $entityType, name: $name, color: $color, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$TagApiCopyWith<$Res> implements $TagApiCopyWith<$Res> {
  factory _$TagApiCopyWith(_TagApi value, $Res Function(_TagApi) _then) = __$TagApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'entity_type') String entityType, String name, String? color,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class __$TagApiCopyWithImpl<$Res>
    implements _$TagApiCopyWith<$Res> {
  __$TagApiCopyWithImpl(this._self, this._then);

  final _TagApi _self;
  final $Res Function(_TagApi) _then;

/// Create a copy of TagApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? entityType = null,Object? name = null,Object? color = freezed,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_TagApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,entityType: null == entityType ? _self.entityType : entityType // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$TagRefApi {

 String get id; String get name; String? get color;
/// Create a copy of TagRefApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TagRefApiCopyWith<TagRefApi> get copyWith => _$TagRefApiCopyWithImpl<TagRefApi>(this as TagRefApi, _$identity);

  /// Serializes this TagRefApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TagRefApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,color);

@override
String toString() {
  return 'TagRefApi(id: $id, name: $name, color: $color)';
}


}

/// @nodoc
abstract mixin class $TagRefApiCopyWith<$Res>  {
  factory $TagRefApiCopyWith(TagRefApi value, $Res Function(TagRefApi) _then) = _$TagRefApiCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? color
});




}
/// @nodoc
class _$TagRefApiCopyWithImpl<$Res>
    implements $TagRefApiCopyWith<$Res> {
  _$TagRefApiCopyWithImpl(this._self, this._then);

  final TagRefApi _self;
  final $Res Function(TagRefApi) _then;

/// Create a copy of TagRefApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? color = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TagRefApi].
extension TagRefApiPatterns on TagRefApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TagRefApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TagRefApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TagRefApi value)  $default,){
final _that = this;
switch (_that) {
case _TagRefApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TagRefApi value)?  $default,){
final _that = this;
switch (_that) {
case _TagRefApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? color)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TagRefApi() when $default != null:
return $default(_that.id,_that.name,_that.color);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? color)  $default,) {final _that = this;
switch (_that) {
case _TagRefApi():
return $default(_that.id,_that.name,_that.color);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? color)?  $default,) {final _that = this;
switch (_that) {
case _TagRefApi() when $default != null:
return $default(_that.id,_that.name,_that.color);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TagRefApi implements TagRefApi {
  const _TagRefApi({this.id = '', this.name = '', this.color});
  factory _TagRefApi.fromJson(Map<String, dynamic> json) => _$TagRefApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override final  String? color;

/// Create a copy of TagRefApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TagRefApiCopyWith<_TagRefApi> get copyWith => __$TagRefApiCopyWithImpl<_TagRefApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TagRefApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TagRefApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,color);

@override
String toString() {
  return 'TagRefApi(id: $id, name: $name, color: $color)';
}


}

/// @nodoc
abstract mixin class _$TagRefApiCopyWith<$Res> implements $TagRefApiCopyWith<$Res> {
  factory _$TagRefApiCopyWith(_TagRefApi value, $Res Function(_TagRefApi) _then) = __$TagRefApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? color
});




}
/// @nodoc
class __$TagRefApiCopyWithImpl<$Res>
    implements _$TagRefApiCopyWith<$Res> {
  __$TagRefApiCopyWithImpl(this._self, this._then);

  final _TagRefApi _self;
  final $Res Function(_TagRefApi) _then;

/// Create a copy of TagRefApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? color = freezed,}) {
  return _then(_TagRefApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: freezed == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$TagListApi {

@JsonKey(fromJson: _tagListData) List<TagApi> get data;
/// Create a copy of TagListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TagListApiCopyWith<TagListApi> get copyWith => _$TagListApiCopyWithImpl<TagListApi>(this as TagListApi, _$identity);

  /// Serializes this TagListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TagListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'TagListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $TagListApiCopyWith<$Res>  {
  factory $TagListApiCopyWith(TagListApi value, $Res Function(TagListApi) _then) = _$TagListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _tagListData) List<TagApi> data
});




}
/// @nodoc
class _$TagListApiCopyWithImpl<$Res>
    implements $TagListApiCopyWith<$Res> {
  _$TagListApiCopyWithImpl(this._self, this._then);

  final TagListApi _self;
  final $Res Function(TagListApi) _then;

/// Create a copy of TagListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<TagApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [TagListApi].
extension TagListApiPatterns on TagListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TagListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TagListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TagListApi value)  $default,){
final _that = this;
switch (_that) {
case _TagListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TagListApi value)?  $default,){
final _that = this;
switch (_that) {
case _TagListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _tagListData)  List<TagApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TagListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _tagListData)  List<TagApi> data)  $default,) {final _that = this;
switch (_that) {
case _TagListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _tagListData)  List<TagApi> data)?  $default,) {final _that = this;
switch (_that) {
case _TagListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TagListApi implements TagListApi {
  const _TagListApi({@JsonKey(fromJson: _tagListData) final  List<TagApi> data = const []}): _data = data;
  factory _TagListApi.fromJson(Map<String, dynamic> json) => _$TagListApiFromJson(json);

 final  List<TagApi> _data;
@override@JsonKey(fromJson: _tagListData) List<TagApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of TagListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TagListApiCopyWith<_TagListApi> get copyWith => __$TagListApiCopyWithImpl<_TagListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TagListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TagListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'TagListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TagListApiCopyWith<$Res> implements $TagListApiCopyWith<$Res> {
  factory _$TagListApiCopyWith(_TagListApi value, $Res Function(_TagListApi) _then) = __$TagListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _tagListData) List<TagApi> data
});




}
/// @nodoc
class __$TagListApiCopyWithImpl<$Res>
    implements _$TagListApiCopyWith<$Res> {
  __$TagListApiCopyWithImpl(this._self, this._then);

  final _TagListApi _self;
  final $Res Function(_TagListApi) _then;

/// Create a copy of TagListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TagListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<TagApi>,
  ));
}


}


/// @nodoc
mixin _$TagItemApi {

 TagApi get data;
/// Create a copy of TagItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TagItemApiCopyWith<TagItemApi> get copyWith => _$TagItemApiCopyWithImpl<TagItemApi>(this as TagItemApi, _$identity);

  /// Serializes this TagItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TagItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'TagItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $TagItemApiCopyWith<$Res>  {
  factory $TagItemApiCopyWith(TagItemApi value, $Res Function(TagItemApi) _then) = _$TagItemApiCopyWithImpl;
@useResult
$Res call({
 TagApi data
});


$TagApiCopyWith<$Res> get data;

}
/// @nodoc
class _$TagItemApiCopyWithImpl<$Res>
    implements $TagItemApiCopyWith<$Res> {
  _$TagItemApiCopyWithImpl(this._self, this._then);

  final TagItemApi _self;
  final $Res Function(TagItemApi) _then;

/// Create a copy of TagItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TagApi,
  ));
}
/// Create a copy of TagItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TagApiCopyWith<$Res> get data {
  
  return $TagApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [TagItemApi].
extension TagItemApiPatterns on TagItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TagItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TagItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TagItemApi value)  $default,){
final _that = this;
switch (_that) {
case _TagItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TagItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _TagItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TagApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TagItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TagApi data)  $default,) {final _that = this;
switch (_that) {
case _TagItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TagApi data)?  $default,) {final _that = this;
switch (_that) {
case _TagItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TagItemApi implements TagItemApi {
  const _TagItemApi({required this.data});
  factory _TagItemApi.fromJson(Map<String, dynamic> json) => _$TagItemApiFromJson(json);

@override final  TagApi data;

/// Create a copy of TagItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TagItemApiCopyWith<_TagItemApi> get copyWith => __$TagItemApiCopyWithImpl<_TagItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TagItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TagItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'TagItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TagItemApiCopyWith<$Res> implements $TagItemApiCopyWith<$Res> {
  factory _$TagItemApiCopyWith(_TagItemApi value, $Res Function(_TagItemApi) _then) = __$TagItemApiCopyWithImpl;
@override @useResult
$Res call({
 TagApi data
});


@override $TagApiCopyWith<$Res> get data;

}
/// @nodoc
class __$TagItemApiCopyWithImpl<$Res>
    implements _$TagItemApiCopyWith<$Res> {
  __$TagItemApiCopyWithImpl(this._self, this._then);

  final _TagItemApi _self;
  final $Res Function(_TagItemApi) _then;

/// Create a copy of TagItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TagItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TagApi,
  ));
}

/// Create a copy of TagItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TagApiCopyWith<$Res> get data {
  
  return $TagApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
