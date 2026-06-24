// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'expense_category_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ExpenseCategoryApi {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'assigned_user_id') String get assignedUserId; String get name; String get color;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of ExpenseCategoryApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseCategoryApiCopyWith<ExpenseCategoryApi> get copyWith => _$ExpenseCategoryApiCopyWithImpl<ExpenseCategoryApi>(this as ExpenseCategoryApi, _$identity);

  /// Serializes this ExpenseCategoryApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseCategoryApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,assignedUserId,name,color,createdAt,updatedAt,archivedAt,isDeleted);

@override
String toString() {
  return 'ExpenseCategoryApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, name: $name, color: $color, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class $ExpenseCategoryApiCopyWith<$Res>  {
  factory $ExpenseCategoryApiCopyWith(ExpenseCategoryApi value, $Res Function(ExpenseCategoryApi) _then) = _$ExpenseCategoryApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId, String name, String color,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class _$ExpenseCategoryApiCopyWithImpl<$Res>
    implements $ExpenseCategoryApiCopyWith<$Res> {
  _$ExpenseCategoryApiCopyWithImpl(this._self, this._then);

  final ExpenseCategoryApi _self;
  final $Res Function(ExpenseCategoryApi) _then;

/// Create a copy of ExpenseCategoryApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? name = null,Object? color = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ExpenseCategoryApi].
extension ExpenseCategoryApiPatterns on ExpenseCategoryApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseCategoryApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseCategoryApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseCategoryApi value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseCategoryApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseCategoryApi value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseCategoryApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String name,  String color, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseCategoryApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.name,_that.color,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String name,  String color, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _ExpenseCategoryApi():
return $default(_that.id,_that.userId,_that.assignedUserId,_that.name,_that.color,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String name,  String color, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseCategoryApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.name,_that.color,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseCategoryApi implements ExpenseCategoryApi {
  const _ExpenseCategoryApi({this.id = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', this.name = '', this.color = '', @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false});
  factory _ExpenseCategoryApi.fromJson(Map<String, dynamic> json) => _$ExpenseCategoryApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey() final  String name;
@override@JsonKey() final  String color;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of ExpenseCategoryApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseCategoryApiCopyWith<_ExpenseCategoryApi> get copyWith => __$ExpenseCategoryApiCopyWithImpl<_ExpenseCategoryApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseCategoryApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseCategoryApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,assignedUserId,name,color,createdAt,updatedAt,archivedAt,isDeleted);

@override
String toString() {
  return 'ExpenseCategoryApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, name: $name, color: $color, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$ExpenseCategoryApiCopyWith<$Res> implements $ExpenseCategoryApiCopyWith<$Res> {
  factory _$ExpenseCategoryApiCopyWith(_ExpenseCategoryApi value, $Res Function(_ExpenseCategoryApi) _then) = __$ExpenseCategoryApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId, String name, String color,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class __$ExpenseCategoryApiCopyWithImpl<$Res>
    implements _$ExpenseCategoryApiCopyWith<$Res> {
  __$ExpenseCategoryApiCopyWithImpl(this._self, this._then);

  final _ExpenseCategoryApi _self;
  final $Res Function(_ExpenseCategoryApi) _then;

/// Create a copy of ExpenseCategoryApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? name = null,Object? color = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_ExpenseCategoryApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ExpenseCategoryListApi {

@JsonKey(fromJson: _expenseCategoryListData) List<ExpenseCategoryApi> get data;
/// Create a copy of ExpenseCategoryListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseCategoryListApiCopyWith<ExpenseCategoryListApi> get copyWith => _$ExpenseCategoryListApiCopyWithImpl<ExpenseCategoryListApi>(this as ExpenseCategoryListApi, _$identity);

  /// Serializes this ExpenseCategoryListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseCategoryListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'ExpenseCategoryListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ExpenseCategoryListApiCopyWith<$Res>  {
  factory $ExpenseCategoryListApiCopyWith(ExpenseCategoryListApi value, $Res Function(ExpenseCategoryListApi) _then) = _$ExpenseCategoryListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _expenseCategoryListData) List<ExpenseCategoryApi> data
});




}
/// @nodoc
class _$ExpenseCategoryListApiCopyWithImpl<$Res>
    implements $ExpenseCategoryListApiCopyWith<$Res> {
  _$ExpenseCategoryListApiCopyWithImpl(this._self, this._then);

  final ExpenseCategoryListApi _self;
  final $Res Function(ExpenseCategoryListApi) _then;

/// Create a copy of ExpenseCategoryListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<ExpenseCategoryApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [ExpenseCategoryListApi].
extension ExpenseCategoryListApiPatterns on ExpenseCategoryListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseCategoryListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseCategoryListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseCategoryListApi value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseCategoryListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseCategoryListApi value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseCategoryListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _expenseCategoryListData)  List<ExpenseCategoryApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseCategoryListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _expenseCategoryListData)  List<ExpenseCategoryApi> data)  $default,) {final _that = this;
switch (_that) {
case _ExpenseCategoryListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _expenseCategoryListData)  List<ExpenseCategoryApi> data)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseCategoryListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseCategoryListApi implements ExpenseCategoryListApi {
  const _ExpenseCategoryListApi({@JsonKey(fromJson: _expenseCategoryListData) final  List<ExpenseCategoryApi> data = const []}): _data = data;
  factory _ExpenseCategoryListApi.fromJson(Map<String, dynamic> json) => _$ExpenseCategoryListApiFromJson(json);

 final  List<ExpenseCategoryApi> _data;
@override@JsonKey(fromJson: _expenseCategoryListData) List<ExpenseCategoryApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of ExpenseCategoryListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseCategoryListApiCopyWith<_ExpenseCategoryListApi> get copyWith => __$ExpenseCategoryListApiCopyWithImpl<_ExpenseCategoryListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseCategoryListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseCategoryListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'ExpenseCategoryListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ExpenseCategoryListApiCopyWith<$Res> implements $ExpenseCategoryListApiCopyWith<$Res> {
  factory _$ExpenseCategoryListApiCopyWith(_ExpenseCategoryListApi value, $Res Function(_ExpenseCategoryListApi) _then) = __$ExpenseCategoryListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _expenseCategoryListData) List<ExpenseCategoryApi> data
});




}
/// @nodoc
class __$ExpenseCategoryListApiCopyWithImpl<$Res>
    implements _$ExpenseCategoryListApiCopyWith<$Res> {
  __$ExpenseCategoryListApiCopyWithImpl(this._self, this._then);

  final _ExpenseCategoryListApi _self;
  final $Res Function(_ExpenseCategoryListApi) _then;

/// Create a copy of ExpenseCategoryListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ExpenseCategoryListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<ExpenseCategoryApi>,
  ));
}


}


/// @nodoc
mixin _$ExpenseCategoryItemApi {

 ExpenseCategoryApi get data;
/// Create a copy of ExpenseCategoryItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExpenseCategoryItemApiCopyWith<ExpenseCategoryItemApi> get copyWith => _$ExpenseCategoryItemApiCopyWithImpl<ExpenseCategoryItemApi>(this as ExpenseCategoryItemApi, _$identity);

  /// Serializes this ExpenseCategoryItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ExpenseCategoryItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ExpenseCategoryItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ExpenseCategoryItemApiCopyWith<$Res>  {
  factory $ExpenseCategoryItemApiCopyWith(ExpenseCategoryItemApi value, $Res Function(ExpenseCategoryItemApi) _then) = _$ExpenseCategoryItemApiCopyWithImpl;
@useResult
$Res call({
 ExpenseCategoryApi data
});


$ExpenseCategoryApiCopyWith<$Res> get data;

}
/// @nodoc
class _$ExpenseCategoryItemApiCopyWithImpl<$Res>
    implements $ExpenseCategoryItemApiCopyWith<$Res> {
  _$ExpenseCategoryItemApiCopyWithImpl(this._self, this._then);

  final ExpenseCategoryItemApi _self;
  final $Res Function(ExpenseCategoryItemApi) _then;

/// Create a copy of ExpenseCategoryItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ExpenseCategoryApi,
  ));
}
/// Create a copy of ExpenseCategoryItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExpenseCategoryApiCopyWith<$Res> get data {
  
  return $ExpenseCategoryApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [ExpenseCategoryItemApi].
extension ExpenseCategoryItemApiPatterns on ExpenseCategoryItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ExpenseCategoryItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ExpenseCategoryItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ExpenseCategoryItemApi value)  $default,){
final _that = this;
switch (_that) {
case _ExpenseCategoryItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ExpenseCategoryItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _ExpenseCategoryItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ExpenseCategoryApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ExpenseCategoryItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ExpenseCategoryApi data)  $default,) {final _that = this;
switch (_that) {
case _ExpenseCategoryItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ExpenseCategoryApi data)?  $default,) {final _that = this;
switch (_that) {
case _ExpenseCategoryItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ExpenseCategoryItemApi implements ExpenseCategoryItemApi {
  const _ExpenseCategoryItemApi({required this.data});
  factory _ExpenseCategoryItemApi.fromJson(Map<String, dynamic> json) => _$ExpenseCategoryItemApiFromJson(json);

@override final  ExpenseCategoryApi data;

/// Create a copy of ExpenseCategoryItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExpenseCategoryItemApiCopyWith<_ExpenseCategoryItemApi> get copyWith => __$ExpenseCategoryItemApiCopyWithImpl<_ExpenseCategoryItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ExpenseCategoryItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ExpenseCategoryItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ExpenseCategoryItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ExpenseCategoryItemApiCopyWith<$Res> implements $ExpenseCategoryItemApiCopyWith<$Res> {
  factory _$ExpenseCategoryItemApiCopyWith(_ExpenseCategoryItemApi value, $Res Function(_ExpenseCategoryItemApi) _then) = __$ExpenseCategoryItemApiCopyWithImpl;
@override @useResult
$Res call({
 ExpenseCategoryApi data
});


@override $ExpenseCategoryApiCopyWith<$Res> get data;

}
/// @nodoc
class __$ExpenseCategoryItemApiCopyWithImpl<$Res>
    implements _$ExpenseCategoryItemApiCopyWith<$Res> {
  __$ExpenseCategoryItemApiCopyWithImpl(this._self, this._then);

  final _ExpenseCategoryItemApi _self;
  final $Res Function(_ExpenseCategoryItemApi) _then;

/// Create a copy of ExpenseCategoryItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ExpenseCategoryItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ExpenseCategoryApi,
  ));
}

/// Create a copy of ExpenseCategoryItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExpenseCategoryApiCopyWith<$Res> get data {
  
  return $ExpenseCategoryApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
