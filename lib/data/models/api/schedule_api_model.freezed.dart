// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ScheduleApi {

 String get id; String get name; String get template;@JsonKey(name: 'frequency_id') String get frequencyId;@JsonKey(name: 'next_run') String get nextRun;@JsonKey(name: 'is_paused') bool get isPaused;@JsonKey(name: 'remaining_cycles') int get remainingCycles; Map<String, dynamic> get parameters;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'assigned_user_id') String get assignedUserId;
/// Create a copy of ScheduleApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleApiCopyWith<ScheduleApi> get copyWith => _$ScheduleApiCopyWithImpl<ScheduleApi>(this as ScheduleApi, _$identity);

  /// Serializes this ScheduleApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.template, template) || other.template == template)&&(identical(other.frequencyId, frequencyId) || other.frequencyId == frequencyId)&&(identical(other.nextRun, nextRun) || other.nextRun == nextRun)&&(identical(other.isPaused, isPaused) || other.isPaused == isPaused)&&(identical(other.remainingCycles, remainingCycles) || other.remainingCycles == remainingCycles)&&const DeepCollectionEquality().equals(other.parameters, parameters)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,template,frequencyId,nextRun,isPaused,remainingCycles,const DeepCollectionEquality().hash(parameters),createdAt,updatedAt,archivedAt,isDeleted,userId,assignedUserId);

@override
String toString() {
  return 'ScheduleApi(id: $id, name: $name, template: $template, frequencyId: $frequencyId, nextRun: $nextRun, isPaused: $isPaused, remainingCycles: $remainingCycles, parameters: $parameters, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, userId: $userId, assignedUserId: $assignedUserId)';
}


}

/// @nodoc
abstract mixin class $ScheduleApiCopyWith<$Res>  {
  factory $ScheduleApiCopyWith(ScheduleApi value, $Res Function(ScheduleApi) _then) = _$ScheduleApiCopyWithImpl;
@useResult
$Res call({
 String id, String name, String template,@JsonKey(name: 'frequency_id') String frequencyId,@JsonKey(name: 'next_run') String nextRun,@JsonKey(name: 'is_paused') bool isPaused,@JsonKey(name: 'remaining_cycles') int remainingCycles, Map<String, dynamic> parameters,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId
});




}
/// @nodoc
class _$ScheduleApiCopyWithImpl<$Res>
    implements $ScheduleApiCopyWith<$Res> {
  _$ScheduleApiCopyWithImpl(this._self, this._then);

  final ScheduleApi _self;
  final $Res Function(ScheduleApi) _then;

/// Create a copy of ScheduleApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? template = null,Object? frequencyId = null,Object? nextRun = null,Object? isPaused = null,Object? remainingCycles = null,Object? parameters = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? userId = null,Object? assignedUserId = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String,frequencyId: null == frequencyId ? _self.frequencyId : frequencyId // ignore: cast_nullable_to_non_nullable
as String,nextRun: null == nextRun ? _self.nextRun : nextRun // ignore: cast_nullable_to_non_nullable
as String,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,remainingCycles: null == remainingCycles ? _self.remainingCycles : remainingCycles // ignore: cast_nullable_to_non_nullable
as int,parameters: null == parameters ? _self.parameters : parameters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduleApi].
extension ScheduleApiPatterns on ScheduleApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduleApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduleApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduleApi value)  $default,){
final _that = this;
switch (_that) {
case _ScheduleApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduleApi value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduleApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String template, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'next_run')  String nextRun, @JsonKey(name: 'is_paused')  bool isPaused, @JsonKey(name: 'remaining_cycles')  int remainingCycles,  Map<String, dynamic> parameters, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleApi() when $default != null:
return $default(_that.id,_that.name,_that.template,_that.frequencyId,_that.nextRun,_that.isPaused,_that.remainingCycles,_that.parameters,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.userId,_that.assignedUserId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String template, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'next_run')  String nextRun, @JsonKey(name: 'is_paused')  bool isPaused, @JsonKey(name: 'remaining_cycles')  int remainingCycles,  Map<String, dynamic> parameters, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId)  $default,) {final _that = this;
switch (_that) {
case _ScheduleApi():
return $default(_that.id,_that.name,_that.template,_that.frequencyId,_that.nextRun,_that.isPaused,_that.remainingCycles,_that.parameters,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.userId,_that.assignedUserId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String template, @JsonKey(name: 'frequency_id')  String frequencyId, @JsonKey(name: 'next_run')  String nextRun, @JsonKey(name: 'is_paused')  bool isPaused, @JsonKey(name: 'remaining_cycles')  int remainingCycles,  Map<String, dynamic> parameters, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleApi() when $default != null:
return $default(_that.id,_that.name,_that.template,_that.frequencyId,_that.nextRun,_that.isPaused,_that.remainingCycles,_that.parameters,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.userId,_that.assignedUserId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScheduleApi implements ScheduleApi {
  const _ScheduleApi({this.id = '', this.name = '', this.template = '', @JsonKey(name: 'frequency_id') this.frequencyId = '', @JsonKey(name: 'next_run') this.nextRun = '', @JsonKey(name: 'is_paused') this.isPaused = false, @JsonKey(name: 'remaining_cycles') this.remainingCycles = -1, final  Map<String, dynamic> parameters = const <String, dynamic>{}, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = ''}): _parameters = parameters;
  factory _ScheduleApi.fromJson(Map<String, dynamic> json) => _$ScheduleApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String template;
@override@JsonKey(name: 'frequency_id') final  String frequencyId;
@override@JsonKey(name: 'next_run') final  String nextRun;
@override@JsonKey(name: 'is_paused') final  bool isPaused;
@override@JsonKey(name: 'remaining_cycles') final  int remainingCycles;
 final  Map<String, dynamic> _parameters;
@override@JsonKey() Map<String, dynamic> get parameters {
  if (_parameters is EqualUnmodifiableMapView) return _parameters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_parameters);
}

@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;

/// Create a copy of ScheduleApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleApiCopyWith<_ScheduleApi> get copyWith => __$ScheduleApiCopyWithImpl<_ScheduleApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduleApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.template, template) || other.template == template)&&(identical(other.frequencyId, frequencyId) || other.frequencyId == frequencyId)&&(identical(other.nextRun, nextRun) || other.nextRun == nextRun)&&(identical(other.isPaused, isPaused) || other.isPaused == isPaused)&&(identical(other.remainingCycles, remainingCycles) || other.remainingCycles == remainingCycles)&&const DeepCollectionEquality().equals(other._parameters, _parameters)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,template,frequencyId,nextRun,isPaused,remainingCycles,const DeepCollectionEquality().hash(_parameters),createdAt,updatedAt,archivedAt,isDeleted,userId,assignedUserId);

@override
String toString() {
  return 'ScheduleApi(id: $id, name: $name, template: $template, frequencyId: $frequencyId, nextRun: $nextRun, isPaused: $isPaused, remainingCycles: $remainingCycles, parameters: $parameters, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, userId: $userId, assignedUserId: $assignedUserId)';
}


}

/// @nodoc
abstract mixin class _$ScheduleApiCopyWith<$Res> implements $ScheduleApiCopyWith<$Res> {
  factory _$ScheduleApiCopyWith(_ScheduleApi value, $Res Function(_ScheduleApi) _then) = __$ScheduleApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String template,@JsonKey(name: 'frequency_id') String frequencyId,@JsonKey(name: 'next_run') String nextRun,@JsonKey(name: 'is_paused') bool isPaused,@JsonKey(name: 'remaining_cycles') int remainingCycles, Map<String, dynamic> parameters,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId
});




}
/// @nodoc
class __$ScheduleApiCopyWithImpl<$Res>
    implements _$ScheduleApiCopyWith<$Res> {
  __$ScheduleApiCopyWithImpl(this._self, this._then);

  final _ScheduleApi _self;
  final $Res Function(_ScheduleApi) _then;

/// Create a copy of ScheduleApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? template = null,Object? frequencyId = null,Object? nextRun = null,Object? isPaused = null,Object? remainingCycles = null,Object? parameters = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? userId = null,Object? assignedUserId = null,}) {
  return _then(_ScheduleApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String,frequencyId: null == frequencyId ? _self.frequencyId : frequencyId // ignore: cast_nullable_to_non_nullable
as String,nextRun: null == nextRun ? _self.nextRun : nextRun // ignore: cast_nullable_to_non_nullable
as String,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,remainingCycles: null == remainingCycles ? _self.remainingCycles : remainingCycles // ignore: cast_nullable_to_non_nullable
as int,parameters: null == parameters ? _self._parameters : parameters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ScheduleListApi {

@JsonKey(fromJson: _scheduleListData) List<ScheduleApi> get data;
/// Create a copy of ScheduleListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleListApiCopyWith<ScheduleListApi> get copyWith => _$ScheduleListApiCopyWithImpl<ScheduleListApi>(this as ScheduleListApi, _$identity);

  /// Serializes this ScheduleListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'ScheduleListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ScheduleListApiCopyWith<$Res>  {
  factory $ScheduleListApiCopyWith(ScheduleListApi value, $Res Function(ScheduleListApi) _then) = _$ScheduleListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _scheduleListData) List<ScheduleApi> data
});




}
/// @nodoc
class _$ScheduleListApiCopyWithImpl<$Res>
    implements $ScheduleListApiCopyWith<$Res> {
  _$ScheduleListApiCopyWithImpl(this._self, this._then);

  final ScheduleListApi _self;
  final $Res Function(ScheduleListApi) _then;

/// Create a copy of ScheduleListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<ScheduleApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [ScheduleListApi].
extension ScheduleListApiPatterns on ScheduleListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduleListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduleListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduleListApi value)  $default,){
final _that = this;
switch (_that) {
case _ScheduleListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduleListApi value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduleListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _scheduleListData)  List<ScheduleApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _scheduleListData)  List<ScheduleApi> data)  $default,) {final _that = this;
switch (_that) {
case _ScheduleListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _scheduleListData)  List<ScheduleApi> data)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScheduleListApi implements ScheduleListApi {
  const _ScheduleListApi({@JsonKey(fromJson: _scheduleListData) final  List<ScheduleApi> data = const []}): _data = data;
  factory _ScheduleListApi.fromJson(Map<String, dynamic> json) => _$ScheduleListApiFromJson(json);

 final  List<ScheduleApi> _data;
@override@JsonKey(fromJson: _scheduleListData) List<ScheduleApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of ScheduleListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleListApiCopyWith<_ScheduleListApi> get copyWith => __$ScheduleListApiCopyWithImpl<_ScheduleListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduleListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'ScheduleListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ScheduleListApiCopyWith<$Res> implements $ScheduleListApiCopyWith<$Res> {
  factory _$ScheduleListApiCopyWith(_ScheduleListApi value, $Res Function(_ScheduleListApi) _then) = __$ScheduleListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _scheduleListData) List<ScheduleApi> data
});




}
/// @nodoc
class __$ScheduleListApiCopyWithImpl<$Res>
    implements _$ScheduleListApiCopyWith<$Res> {
  __$ScheduleListApiCopyWithImpl(this._self, this._then);

  final _ScheduleListApi _self;
  final $Res Function(_ScheduleListApi) _then;

/// Create a copy of ScheduleListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ScheduleListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<ScheduleApi>,
  ));
}


}


/// @nodoc
mixin _$ScheduleItemApi {

 ScheduleApi get data;
/// Create a copy of ScheduleItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleItemApiCopyWith<ScheduleItemApi> get copyWith => _$ScheduleItemApiCopyWithImpl<ScheduleItemApi>(this as ScheduleItemApi, _$identity);

  /// Serializes this ScheduleItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ScheduleItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $ScheduleItemApiCopyWith<$Res>  {
  factory $ScheduleItemApiCopyWith(ScheduleItemApi value, $Res Function(ScheduleItemApi) _then) = _$ScheduleItemApiCopyWithImpl;
@useResult
$Res call({
 ScheduleApi data
});


$ScheduleApiCopyWith<$Res> get data;

}
/// @nodoc
class _$ScheduleItemApiCopyWithImpl<$Res>
    implements $ScheduleItemApiCopyWith<$Res> {
  _$ScheduleItemApiCopyWithImpl(this._self, this._then);

  final ScheduleItemApi _self;
  final $Res Function(ScheduleItemApi) _then;

/// Create a copy of ScheduleItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ScheduleApi,
  ));
}
/// Create a copy of ScheduleItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleApiCopyWith<$Res> get data {
  
  return $ScheduleApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [ScheduleItemApi].
extension ScheduleItemApiPatterns on ScheduleItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ScheduleItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ScheduleItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ScheduleItemApi value)  $default,){
final _that = this;
switch (_that) {
case _ScheduleItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ScheduleItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _ScheduleItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ScheduleApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ScheduleApi data)  $default,) {final _that = this;
switch (_that) {
case _ScheduleItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ScheduleApi data)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScheduleItemApi implements ScheduleItemApi {
  const _ScheduleItemApi({required this.data});
  factory _ScheduleItemApi.fromJson(Map<String, dynamic> json) => _$ScheduleItemApiFromJson(json);

@override final  ScheduleApi data;

/// Create a copy of ScheduleItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleItemApiCopyWith<_ScheduleItemApi> get copyWith => __$ScheduleItemApiCopyWithImpl<_ScheduleItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduleItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'ScheduleItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$ScheduleItemApiCopyWith<$Res> implements $ScheduleItemApiCopyWith<$Res> {
  factory _$ScheduleItemApiCopyWith(_ScheduleItemApi value, $Res Function(_ScheduleItemApi) _then) = __$ScheduleItemApiCopyWithImpl;
@override @useResult
$Res call({
 ScheduleApi data
});


@override $ScheduleApiCopyWith<$Res> get data;

}
/// @nodoc
class __$ScheduleItemApiCopyWithImpl<$Res>
    implements _$ScheduleItemApiCopyWith<$Res> {
  __$ScheduleItemApiCopyWithImpl(this._self, this._then);

  final _ScheduleItemApi _self;
  final $Res Function(_ScheduleItemApi) _then;

/// Create a copy of ScheduleItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_ScheduleItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as ScheduleApi,
  ));
}

/// Create a copy of ScheduleItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ScheduleApiCopyWith<$Res> get data {
  
  return $ScheduleApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
