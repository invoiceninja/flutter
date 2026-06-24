// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'system_log_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SystemLogApi {

 String get id;@JsonKey(name: 'company_id') String get companyId;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'client_id') String get clientId;@JsonKey(name: 'event_id') int get eventId;@JsonKey(name: 'category_id') int get categoryId;@JsonKey(name: 'type_id') int get typeId; String get log;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;
/// Create a copy of SystemLogApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SystemLogApiCopyWith<SystemLogApi> get copyWith => _$SystemLogApiCopyWithImpl<SystemLogApi>(this as SystemLogApi, _$identity);

  /// Serializes this SystemLogApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SystemLogApi&&(identical(other.id, id) || other.id == id)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.log, log) || other.log == log)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,companyId,userId,clientId,eventId,categoryId,typeId,log,createdAt,updatedAt);

@override
String toString() {
  return 'SystemLogApi(id: $id, companyId: $companyId, userId: $userId, clientId: $clientId, eventId: $eventId, categoryId: $categoryId, typeId: $typeId, log: $log, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $SystemLogApiCopyWith<$Res>  {
  factory $SystemLogApiCopyWith(SystemLogApi value, $Res Function(SystemLogApi) _then) = _$SystemLogApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'company_id') String companyId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'event_id') int eventId,@JsonKey(name: 'category_id') int categoryId,@JsonKey(name: 'type_id') int typeId, String log,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt
});




}
/// @nodoc
class _$SystemLogApiCopyWithImpl<$Res>
    implements $SystemLogApiCopyWith<$Res> {
  _$SystemLogApiCopyWithImpl(this._self, this._then);

  final SystemLogApi _self;
  final $Res Function(SystemLogApi) _then;

/// Create a copy of SystemLogApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? companyId = null,Object? userId = null,Object? clientId = null,Object? eventId = null,Object? categoryId = null,Object? typeId = null,Object? log = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as int,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,log: null == log ? _self.log : log // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SystemLogApi].
extension SystemLogApiPatterns on SystemLogApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SystemLogApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SystemLogApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SystemLogApi value)  $default,){
final _that = this;
switch (_that) {
case _SystemLogApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SystemLogApi value)?  $default,){
final _that = this;
switch (_that) {
case _SystemLogApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'company_id')  String companyId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'event_id')  int eventId, @JsonKey(name: 'category_id')  int categoryId, @JsonKey(name: 'type_id')  int typeId,  String log, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SystemLogApi() when $default != null:
return $default(_that.id,_that.companyId,_that.userId,_that.clientId,_that.eventId,_that.categoryId,_that.typeId,_that.log,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'company_id')  String companyId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'event_id')  int eventId, @JsonKey(name: 'category_id')  int categoryId, @JsonKey(name: 'type_id')  int typeId,  String log, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt)  $default,) {final _that = this;
switch (_that) {
case _SystemLogApi():
return $default(_that.id,_that.companyId,_that.userId,_that.clientId,_that.eventId,_that.categoryId,_that.typeId,_that.log,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'company_id')  String companyId, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'event_id')  int eventId, @JsonKey(name: 'category_id')  int categoryId, @JsonKey(name: 'type_id')  int typeId,  String log, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _SystemLogApi() when $default != null:
return $default(_that.id,_that.companyId,_that.userId,_that.clientId,_that.eventId,_that.categoryId,_that.typeId,_that.log,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SystemLogApi implements SystemLogApi {
  const _SystemLogApi({this.id = '', @JsonKey(name: 'company_id') this.companyId = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'client_id') this.clientId = '', @JsonKey(name: 'event_id') this.eventId = 0, @JsonKey(name: 'category_id') this.categoryId = 0, @JsonKey(name: 'type_id') this.typeId = 0, this.log = '', @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0});
  factory _SystemLogApi.fromJson(Map<String, dynamic> json) => _$SystemLogApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'company_id') final  String companyId;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'client_id') final  String clientId;
@override@JsonKey(name: 'event_id') final  int eventId;
@override@JsonKey(name: 'category_id') final  int categoryId;
@override@JsonKey(name: 'type_id') final  int typeId;
@override@JsonKey() final  String log;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;

/// Create a copy of SystemLogApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SystemLogApiCopyWith<_SystemLogApi> get copyWith => __$SystemLogApiCopyWithImpl<_SystemLogApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SystemLogApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SystemLogApi&&(identical(other.id, id) || other.id == id)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.log, log) || other.log == log)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,companyId,userId,clientId,eventId,categoryId,typeId,log,createdAt,updatedAt);

@override
String toString() {
  return 'SystemLogApi(id: $id, companyId: $companyId, userId: $userId, clientId: $clientId, eventId: $eventId, categoryId: $categoryId, typeId: $typeId, log: $log, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SystemLogApiCopyWith<$Res> implements $SystemLogApiCopyWith<$Res> {
  factory _$SystemLogApiCopyWith(_SystemLogApi value, $Res Function(_SystemLogApi) _then) = __$SystemLogApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'company_id') String companyId,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'event_id') int eventId,@JsonKey(name: 'category_id') int categoryId,@JsonKey(name: 'type_id') int typeId, String log,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt
});




}
/// @nodoc
class __$SystemLogApiCopyWithImpl<$Res>
    implements _$SystemLogApiCopyWith<$Res> {
  __$SystemLogApiCopyWithImpl(this._self, this._then);

  final _SystemLogApi _self;
  final $Res Function(_SystemLogApi) _then;

/// Create a copy of SystemLogApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? companyId = null,Object? userId = null,Object? clientId = null,Object? eventId = null,Object? categoryId = null,Object? typeId = null,Object? log = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_SystemLogApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as int,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,log: null == log ? _self.log : log // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$SystemLogListApi {

@JsonKey(fromJson: _systemLogListData) List<SystemLogApi> get data;
/// Create a copy of SystemLogListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SystemLogListApiCopyWith<SystemLogListApi> get copyWith => _$SystemLogListApiCopyWithImpl<SystemLogListApi>(this as SystemLogListApi, _$identity);

  /// Serializes this SystemLogListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SystemLogListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'SystemLogListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $SystemLogListApiCopyWith<$Res>  {
  factory $SystemLogListApiCopyWith(SystemLogListApi value, $Res Function(SystemLogListApi) _then) = _$SystemLogListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _systemLogListData) List<SystemLogApi> data
});




}
/// @nodoc
class _$SystemLogListApiCopyWithImpl<$Res>
    implements $SystemLogListApiCopyWith<$Res> {
  _$SystemLogListApiCopyWithImpl(this._self, this._then);

  final SystemLogListApi _self;
  final $Res Function(SystemLogListApi) _then;

/// Create a copy of SystemLogListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<SystemLogApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [SystemLogListApi].
extension SystemLogListApiPatterns on SystemLogListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SystemLogListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SystemLogListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SystemLogListApi value)  $default,){
final _that = this;
switch (_that) {
case _SystemLogListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SystemLogListApi value)?  $default,){
final _that = this;
switch (_that) {
case _SystemLogListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _systemLogListData)  List<SystemLogApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SystemLogListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _systemLogListData)  List<SystemLogApi> data)  $default,) {final _that = this;
switch (_that) {
case _SystemLogListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _systemLogListData)  List<SystemLogApi> data)?  $default,) {final _that = this;
switch (_that) {
case _SystemLogListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SystemLogListApi implements SystemLogListApi {
  const _SystemLogListApi({@JsonKey(fromJson: _systemLogListData) final  List<SystemLogApi> data = const []}): _data = data;
  factory _SystemLogListApi.fromJson(Map<String, dynamic> json) => _$SystemLogListApiFromJson(json);

 final  List<SystemLogApi> _data;
@override@JsonKey(fromJson: _systemLogListData) List<SystemLogApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of SystemLogListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SystemLogListApiCopyWith<_SystemLogListApi> get copyWith => __$SystemLogListApiCopyWithImpl<_SystemLogListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SystemLogListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SystemLogListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'SystemLogListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$SystemLogListApiCopyWith<$Res> implements $SystemLogListApiCopyWith<$Res> {
  factory _$SystemLogListApiCopyWith(_SystemLogListApi value, $Res Function(_SystemLogListApi) _then) = __$SystemLogListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _systemLogListData) List<SystemLogApi> data
});




}
/// @nodoc
class __$SystemLogListApiCopyWithImpl<$Res>
    implements _$SystemLogListApiCopyWith<$Res> {
  __$SystemLogListApiCopyWithImpl(this._self, this._then);

  final _SystemLogListApi _self;
  final $Res Function(_SystemLogListApi) _then;

/// Create a copy of SystemLogListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_SystemLogListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<SystemLogApi>,
  ));
}


}

// dart format on
