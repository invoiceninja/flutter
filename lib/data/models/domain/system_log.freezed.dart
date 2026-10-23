// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'system_log.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SystemLog {

 String get id; String get companyId; String get userId; String get clientId; int get eventId; int get categoryId; int get typeId; String get log; DateTime get createdAt; DateTime get updatedAt;
/// Create a copy of SystemLog
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SystemLogCopyWith<SystemLog> get copyWith => _$SystemLogCopyWithImpl<SystemLog>(this as SystemLog, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SystemLog;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SystemLog&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.companyId, _this.companyId) || other.companyId == _this.companyId)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.clientId, _this.clientId) || other.clientId == _this.clientId)&&(identical(other.eventId, _this.eventId) || other.eventId == _this.eventId)&&(identical(other.categoryId, _this.categoryId) || other.categoryId == _this.categoryId)&&(identical(other.typeId, _this.typeId) || other.typeId == _this.typeId)&&(identical(other.log, _this.log) || other.log == _this.log)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}


@override
int get hashCode {
  final _this = this as SystemLog;
  return Object.hash(runtimeType,_this.id,_this.companyId,_this.userId,_this.clientId,_this.eventId,_this.categoryId,_this.typeId,_this.log,_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as SystemLog;
  return 'SystemLog(id: ${_this.id}, companyId: ${_this.companyId}, userId: ${_this.userId}, clientId: ${_this.clientId}, eventId: ${_this.eventId}, categoryId: ${_this.categoryId}, typeId: ${_this.typeId}, log: ${_this.log}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $SystemLogCopyWith<$Res>  {
  factory $SystemLogCopyWith(SystemLog value, $Res Function(SystemLog) _then) = _$SystemLogCopyWithImpl;
@useResult
$Res call({
 String id, String companyId, String userId, String clientId, int eventId, int categoryId, int typeId, String log, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class _$SystemLogCopyWithImpl<$Res>
    implements $SystemLogCopyWith<$Res> {
  _$SystemLogCopyWithImpl(this._self, this._then);

  final SystemLog _self;
  final $Res Function(SystemLog) _then;

/// Create a copy of SystemLog
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? companyId = null,Object? userId = null,Object? clientId = null,Object? eventId = null,Object? categoryId = null,Object? typeId = null,Object? log = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(SystemLog(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as int,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,log: null == log ? _self.log : log // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [SystemLog].
extension SystemLogPatterns on SystemLog {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SystemLog value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SystemLog() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SystemLog value)  $default,){
final _that = this;
switch (_that) {
case _SystemLog():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SystemLog value)?  $default,){
final _that = this;
switch (_that) {
case _SystemLog() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String companyId,  String userId,  String clientId,  int eventId,  int categoryId,  int typeId,  String log,  DateTime createdAt,  DateTime updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SystemLog() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String companyId,  String userId,  String clientId,  int eventId,  int categoryId,  int typeId,  String log,  DateTime createdAt,  DateTime updatedAt)  $default,) {final _that = this;
switch (_that) {
case _SystemLog():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String companyId,  String userId,  String clientId,  int eventId,  int categoryId,  int typeId,  String log,  DateTime createdAt,  DateTime updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _SystemLog() when $default != null:
return $default(_that.id,_that.companyId,_that.userId,_that.clientId,_that.eventId,_that.categoryId,_that.typeId,_that.log,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc


class _SystemLog extends SystemLog {
  const _SystemLog({required this.id, required this.companyId, required this.userId, required this.clientId, required this.eventId, required this.categoryId, required this.typeId, required this.log, required this.createdAt, required this.updatedAt}): super._();
  

@override final  String id;
@override final  String companyId;
@override final  String userId;
@override final  String clientId;
@override final  int eventId;
@override final  int categoryId;
@override final  int typeId;
@override final  String log;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;

/// Create a copy of SystemLog
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SystemLogCopyWith<_SystemLog> get copyWith => __$SystemLogCopyWithImpl<_SystemLog>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SystemLog&&(identical(other.id, id) || other.id == id)&&(identical(other.companyId, companyId) || other.companyId == companyId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.categoryId, categoryId) || other.categoryId == categoryId)&&(identical(other.typeId, typeId) || other.typeId == typeId)&&(identical(other.log, log) || other.log == log)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,companyId,userId,clientId,eventId,categoryId,typeId,log,createdAt,updatedAt);
}

@override
String toString() {
    return 'SystemLog(id: $id, companyId: $companyId, userId: $userId, clientId: $clientId, eventId: $eventId, categoryId: $categoryId, typeId: $typeId, log: $log, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SystemLogCopyWith<$Res> implements $SystemLogCopyWith<$Res> {
  factory _$SystemLogCopyWith(_SystemLog value, $Res Function(_SystemLog) _then) = __$SystemLogCopyWithImpl;
@override @useResult
$Res call({
 String id, String companyId, String userId, String clientId, int eventId, int categoryId, int typeId, String log, DateTime createdAt, DateTime updatedAt
});




}
/// @nodoc
class __$SystemLogCopyWithImpl<$Res>
    implements _$SystemLogCopyWith<$Res> {
  __$SystemLogCopyWithImpl(this._self, this._then);

  final _SystemLog _self;
  final $Res Function(_SystemLog) _then;

/// Create a copy of SystemLog
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? companyId = null,Object? userId = null,Object? clientId = null,Object? eventId = null,Object? categoryId = null,Object? typeId = null,Object? log = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_SystemLog(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,companyId: null == companyId ? _self.companyId : companyId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as int,categoryId: null == categoryId ? _self.categoryId : categoryId // ignore: cast_nullable_to_non_nullable
as int,typeId: null == typeId ? _self.typeId : typeId // ignore: cast_nullable_to_non_nullable
as int,log: null == log ? _self.log : log // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}

// dart format on
