// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_status_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskStatusApi {

 String get id; String get name; String get color;@JsonKey(name: 'status_order') int? get statusOrder;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of TaskStatusApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskStatusApiCopyWith<TaskStatusApi> get copyWith => _$TaskStatusApiCopyWithImpl<TaskStatusApi>(this as TaskStatusApi, _$identity);

  /// Serializes this TaskStatusApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskStatusApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.statusOrder, statusOrder) || other.statusOrder == statusOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,color,statusOrder,createdAt,updatedAt,archivedAt,isDeleted);

@override
String toString() {
  return 'TaskStatusApi(id: $id, name: $name, color: $color, statusOrder: $statusOrder, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class $TaskStatusApiCopyWith<$Res>  {
  factory $TaskStatusApiCopyWith(TaskStatusApi value, $Res Function(TaskStatusApi) _then) = _$TaskStatusApiCopyWithImpl;
@useResult
$Res call({
 String id, String name, String color,@JsonKey(name: 'status_order') int? statusOrder,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class _$TaskStatusApiCopyWithImpl<$Res>
    implements $TaskStatusApiCopyWith<$Res> {
  _$TaskStatusApiCopyWithImpl(this._self, this._then);

  final TaskStatusApi _self;
  final $Res Function(TaskStatusApi) _then;

/// Create a copy of TaskStatusApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? color = null,Object? statusOrder = freezed,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,statusOrder: freezed == statusOrder ? _self.statusOrder : statusOrder // ignore: cast_nullable_to_non_nullable
as int?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskStatusApi].
extension TaskStatusApiPatterns on TaskStatusApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskStatusApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskStatusApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskStatusApi value)  $default,){
final _that = this;
switch (_that) {
case _TaskStatusApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskStatusApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaskStatusApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String color, @JsonKey(name: 'status_order')  int? statusOrder, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskStatusApi() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.statusOrder,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String color, @JsonKey(name: 'status_order')  int? statusOrder, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _TaskStatusApi():
return $default(_that.id,_that.name,_that.color,_that.statusOrder,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String color, @JsonKey(name: 'status_order')  int? statusOrder, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _TaskStatusApi() when $default != null:
return $default(_that.id,_that.name,_that.color,_that.statusOrder,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskStatusApi implements TaskStatusApi {
  const _TaskStatusApi({this.id = '', this.name = '', this.color = '', @JsonKey(name: 'status_order') this.statusOrder, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false});
  factory _TaskStatusApi.fromJson(Map<String, dynamic> json) => _$TaskStatusApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String color;
@override@JsonKey(name: 'status_order') final  int? statusOrder;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of TaskStatusApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskStatusApiCopyWith<_TaskStatusApi> get copyWith => __$TaskStatusApiCopyWithImpl<_TaskStatusApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskStatusApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskStatusApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.color, color) || other.color == color)&&(identical(other.statusOrder, statusOrder) || other.statusOrder == statusOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,color,statusOrder,createdAt,updatedAt,archivedAt,isDeleted);

@override
String toString() {
  return 'TaskStatusApi(id: $id, name: $name, color: $color, statusOrder: $statusOrder, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$TaskStatusApiCopyWith<$Res> implements $TaskStatusApiCopyWith<$Res> {
  factory _$TaskStatusApiCopyWith(_TaskStatusApi value, $Res Function(_TaskStatusApi) _then) = __$TaskStatusApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String color,@JsonKey(name: 'status_order') int? statusOrder,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class __$TaskStatusApiCopyWithImpl<$Res>
    implements _$TaskStatusApiCopyWith<$Res> {
  __$TaskStatusApiCopyWithImpl(this._self, this._then);

  final _TaskStatusApi _self;
  final $Res Function(_TaskStatusApi) _then;

/// Create a copy of TaskStatusApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? color = null,Object? statusOrder = freezed,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_TaskStatusApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,color: null == color ? _self.color : color // ignore: cast_nullable_to_non_nullable
as String,statusOrder: freezed == statusOrder ? _self.statusOrder : statusOrder // ignore: cast_nullable_to_non_nullable
as int?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TaskStatusListApi {

@JsonKey(fromJson: _taskStatusListData) List<TaskStatusApi> get data;
/// Create a copy of TaskStatusListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskStatusListApiCopyWith<TaskStatusListApi> get copyWith => _$TaskStatusListApiCopyWithImpl<TaskStatusListApi>(this as TaskStatusListApi, _$identity);

  /// Serializes this TaskStatusListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskStatusListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'TaskStatusListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $TaskStatusListApiCopyWith<$Res>  {
  factory $TaskStatusListApiCopyWith(TaskStatusListApi value, $Res Function(TaskStatusListApi) _then) = _$TaskStatusListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _taskStatusListData) List<TaskStatusApi> data
});




}
/// @nodoc
class _$TaskStatusListApiCopyWithImpl<$Res>
    implements $TaskStatusListApiCopyWith<$Res> {
  _$TaskStatusListApiCopyWithImpl(this._self, this._then);

  final TaskStatusListApi _self;
  final $Res Function(TaskStatusListApi) _then;

/// Create a copy of TaskStatusListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<TaskStatusApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskStatusListApi].
extension TaskStatusListApiPatterns on TaskStatusListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskStatusListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskStatusListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskStatusListApi value)  $default,){
final _that = this;
switch (_that) {
case _TaskStatusListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskStatusListApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaskStatusListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _taskStatusListData)  List<TaskStatusApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskStatusListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _taskStatusListData)  List<TaskStatusApi> data)  $default,) {final _that = this;
switch (_that) {
case _TaskStatusListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _taskStatusListData)  List<TaskStatusApi> data)?  $default,) {final _that = this;
switch (_that) {
case _TaskStatusListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskStatusListApi implements TaskStatusListApi {
  const _TaskStatusListApi({@JsonKey(fromJson: _taskStatusListData) final  List<TaskStatusApi> data = const []}): _data = data;
  factory _TaskStatusListApi.fromJson(Map<String, dynamic> json) => _$TaskStatusListApiFromJson(json);

 final  List<TaskStatusApi> _data;
@override@JsonKey(fromJson: _taskStatusListData) List<TaskStatusApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of TaskStatusListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskStatusListApiCopyWith<_TaskStatusListApi> get copyWith => __$TaskStatusListApiCopyWithImpl<_TaskStatusListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskStatusListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskStatusListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'TaskStatusListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TaskStatusListApiCopyWith<$Res> implements $TaskStatusListApiCopyWith<$Res> {
  factory _$TaskStatusListApiCopyWith(_TaskStatusListApi value, $Res Function(_TaskStatusListApi) _then) = __$TaskStatusListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _taskStatusListData) List<TaskStatusApi> data
});




}
/// @nodoc
class __$TaskStatusListApiCopyWithImpl<$Res>
    implements _$TaskStatusListApiCopyWith<$Res> {
  __$TaskStatusListApiCopyWithImpl(this._self, this._then);

  final _TaskStatusListApi _self;
  final $Res Function(_TaskStatusListApi) _then;

/// Create a copy of TaskStatusListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TaskStatusListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<TaskStatusApi>,
  ));
}


}


/// @nodoc
mixin _$TaskStatusItemApi {

 TaskStatusApi get data;
/// Create a copy of TaskStatusItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskStatusItemApiCopyWith<TaskStatusItemApi> get copyWith => _$TaskStatusItemApiCopyWithImpl<TaskStatusItemApi>(this as TaskStatusItemApi, _$identity);

  /// Serializes this TaskStatusItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskStatusItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'TaskStatusItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $TaskStatusItemApiCopyWith<$Res>  {
  factory $TaskStatusItemApiCopyWith(TaskStatusItemApi value, $Res Function(TaskStatusItemApi) _then) = _$TaskStatusItemApiCopyWithImpl;
@useResult
$Res call({
 TaskStatusApi data
});


$TaskStatusApiCopyWith<$Res> get data;

}
/// @nodoc
class _$TaskStatusItemApiCopyWithImpl<$Res>
    implements $TaskStatusItemApiCopyWith<$Res> {
  _$TaskStatusItemApiCopyWithImpl(this._self, this._then);

  final TaskStatusItemApi _self;
  final $Res Function(TaskStatusItemApi) _then;

/// Create a copy of TaskStatusItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TaskStatusApi,
  ));
}
/// Create a copy of TaskStatusItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskStatusApiCopyWith<$Res> get data {
  
  return $TaskStatusApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [TaskStatusItemApi].
extension TaskStatusItemApiPatterns on TaskStatusItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskStatusItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskStatusItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskStatusItemApi value)  $default,){
final _that = this;
switch (_that) {
case _TaskStatusItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskStatusItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaskStatusItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TaskStatusApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskStatusItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TaskStatusApi data)  $default,) {final _that = this;
switch (_that) {
case _TaskStatusItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TaskStatusApi data)?  $default,) {final _that = this;
switch (_that) {
case _TaskStatusItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskStatusItemApi implements TaskStatusItemApi {
  const _TaskStatusItemApi({required this.data});
  factory _TaskStatusItemApi.fromJson(Map<String, dynamic> json) => _$TaskStatusItemApiFromJson(json);

@override final  TaskStatusApi data;

/// Create a copy of TaskStatusItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskStatusItemApiCopyWith<_TaskStatusItemApi> get copyWith => __$TaskStatusItemApiCopyWithImpl<_TaskStatusItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskStatusItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskStatusItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'TaskStatusItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TaskStatusItemApiCopyWith<$Res> implements $TaskStatusItemApiCopyWith<$Res> {
  factory _$TaskStatusItemApiCopyWith(_TaskStatusItemApi value, $Res Function(_TaskStatusItemApi) _then) = __$TaskStatusItemApiCopyWithImpl;
@override @useResult
$Res call({
 TaskStatusApi data
});


@override $TaskStatusApiCopyWith<$Res> get data;

}
/// @nodoc
class __$TaskStatusItemApiCopyWithImpl<$Res>
    implements _$TaskStatusItemApiCopyWith<$Res> {
  __$TaskStatusItemApiCopyWithImpl(this._self, this._then);

  final _TaskStatusItemApi _self;
  final $Res Function(_TaskStatusItemApi) _then;

/// Create a copy of TaskStatusItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TaskStatusItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TaskStatusApi,
  ));
}

/// Create a copy of TaskStatusItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskStatusApiCopyWith<$Res> get data {
  
  return $TaskStatusApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
