// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Schedule {

 String get id; String get name; String get template; String get frequencyId; Date? get nextRun; bool get isPaused; int get remainingCycles; Map<String, dynamic> get parameters; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; bool get isDeleted; bool get isDirty;
/// Create a copy of Schedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleCopyWith<Schedule> get copyWith => _$ScheduleCopyWithImpl<Schedule>(this as Schedule, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Schedule;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Schedule&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.template, _this.template) || other.template == _this.template)&&(identical(other.frequencyId, _this.frequencyId) || other.frequencyId == _this.frequencyId)&&(identical(other.nextRun, _this.nextRun) || other.nextRun == _this.nextRun)&&(identical(other.isPaused, _this.isPaused) || other.isPaused == _this.isPaused)&&(identical(other.remainingCycles, _this.remainingCycles) || other.remainingCycles == _this.remainingCycles)&&const DeepCollectionEquality().equals(other.parameters, _this.parameters)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt)&&(identical(other.isDeleted, _this.isDeleted) || other.isDeleted == _this.isDeleted)&&(identical(other.isDirty, _this.isDirty) || other.isDirty == _this.isDirty));
}


@override
int get hashCode {
  final _this = this as Schedule;
  return Object.hash(runtimeType,_this.id,_this.name,_this.template,_this.frequencyId,_this.nextRun,_this.isPaused,_this.remainingCycles,const DeepCollectionEquality().hash(_this.parameters),_this.updatedAt,_this.createdAt,_this.archivedAt,_this.isDeleted,_this.isDirty);
}

@override
String toString() {
  final _this = this as Schedule;
  return 'Schedule(id: ${_this.id}, name: ${_this.name}, template: ${_this.template}, frequencyId: ${_this.frequencyId}, nextRun: ${_this.nextRun}, isPaused: ${_this.isPaused}, remainingCycles: ${_this.remainingCycles}, parameters: ${_this.parameters}, updatedAt: ${_this.updatedAt}, createdAt: ${_this.createdAt}, archivedAt: ${_this.archivedAt}, isDeleted: ${_this.isDeleted}, isDirty: ${_this.isDirty})';
}


}

/// @nodoc
abstract mixin class $ScheduleCopyWith<$Res>  {
  factory $ScheduleCopyWith(Schedule value, $Res Function(Schedule) _then) = _$ScheduleCopyWithImpl;
@useResult
$Res call({
 String id, String name, String template, String frequencyId, Date? nextRun, bool isPaused, int remainingCycles, Map<String, dynamic> parameters, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, bool isDirty
});




}
/// @nodoc
class _$ScheduleCopyWithImpl<$Res>
    implements $ScheduleCopyWith<$Res> {
  _$ScheduleCopyWithImpl(this._self, this._then);

  final Schedule _self;
  final $Res Function(Schedule) _then;

/// Create a copy of Schedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? template = null,Object? frequencyId = null,Object? nextRun = freezed,Object? isPaused = null,Object? remainingCycles = null,Object? parameters = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? isDirty = null,}) {
  return _then(Schedule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String,frequencyId: null == frequencyId ? _self.frequencyId : frequencyId // ignore: cast_nullable_to_non_nullable
as String,nextRun: freezed == nextRun ? _self.nextRun : nextRun // ignore: cast_nullable_to_non_nullable
as Date?,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,remainingCycles: null == remainingCycles ? _self.remainingCycles : remainingCycles // ignore: cast_nullable_to_non_nullable
as int,parameters: null == parameters ? _self.parameters : parameters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Schedule].
extension SchedulePatterns on Schedule {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Schedule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Schedule() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Schedule value)  $default,){
final _that = this;
switch (_that) {
case _Schedule():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Schedule value)?  $default,){
final _that = this;
switch (_that) {
case _Schedule() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String template,  String frequencyId,  Date? nextRun,  bool isPaused,  int remainingCycles,  Map<String, dynamic> parameters,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Schedule() when $default != null:
return $default(_that.id,_that.name,_that.template,_that.frequencyId,_that.nextRun,_that.isPaused,_that.remainingCycles,_that.parameters,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String template,  String frequencyId,  Date? nextRun,  bool isPaused,  int remainingCycles,  Map<String, dynamic> parameters,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _Schedule():
return $default(_that.id,_that.name,_that.template,_that.frequencyId,_that.nextRun,_that.isPaused,_that.remainingCycles,_that.parameters,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String template,  String frequencyId,  Date? nextRun,  bool isPaused,  int remainingCycles,  Map<String, dynamic> parameters,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _Schedule() when $default != null:
return $default(_that.id,_that.name,_that.template,_that.frequencyId,_that.nextRun,_that.isPaused,_that.remainingCycles,_that.parameters,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDeleted,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _Schedule implements Schedule {
  const _Schedule({required this.id, required this.name, required this.template, required this.frequencyId, required this.nextRun, required this.isPaused, required this.remainingCycles, required  Map<String, dynamic> parameters, required this.updatedAt, required this.createdAt, required this.archivedAt, required this.isDeleted, this.isDirty = false}): _parameters = parameters;
  

@override final  String id;
@override final  String name;
@override final  String template;
@override final  String frequencyId;
@override final  Date? nextRun;
@override final  bool isPaused;
@override final  int remainingCycles;
 final  Map<String, dynamic> _parameters;
@override Map<String, dynamic> get parameters {
  if (_parameters is EqualUnmodifiableMapView) return _parameters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_parameters);
}

@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
@override final  bool isDeleted;
@override@JsonKey() final  bool isDirty;

/// Create a copy of Schedule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleCopyWith<_Schedule> get copyWith => __$ScheduleCopyWithImpl<_Schedule>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Schedule&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.template, template) || other.template == template)&&(identical(other.frequencyId, frequencyId) || other.frequencyId == frequencyId)&&(identical(other.nextRun, nextRun) || other.nextRun == nextRun)&&(identical(other.isPaused, isPaused) || other.isPaused == isPaused)&&(identical(other.remainingCycles, remainingCycles) || other.remainingCycles == remainingCycles)&&const DeepCollectionEquality().equals(other.parameters, _parameters)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,template,frequencyId,nextRun,isPaused,remainingCycles,const DeepCollectionEquality().hash(_parameters),updatedAt,createdAt,archivedAt,isDeleted,isDirty);
}

@override
String toString() {
    return 'Schedule(id: $id, name: $name, template: $template, frequencyId: $frequencyId, nextRun: $nextRun, isPaused: $isPaused, remainingCycles: $remainingCycles, parameters: $parameters, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDeleted: $isDeleted, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$ScheduleCopyWith<$Res> implements $ScheduleCopyWith<$Res> {
  factory _$ScheduleCopyWith(_Schedule value, $Res Function(_Schedule) _then) = __$ScheduleCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String template, String frequencyId, Date? nextRun, bool isPaused, int remainingCycles, Map<String, dynamic> parameters, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDeleted, bool isDirty
});




}
/// @nodoc
class __$ScheduleCopyWithImpl<$Res>
    implements _$ScheduleCopyWith<$Res> {
  __$ScheduleCopyWithImpl(this._self, this._then);

  final _Schedule _self;
  final $Res Function(_Schedule) _then;

/// Create a copy of Schedule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? template = null,Object? frequencyId = null,Object? nextRun = freezed,Object? isPaused = null,Object? remainingCycles = null,Object? parameters = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? isDirty = null,}) {
  return _then(_Schedule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,template: null == template ? _self.template : template // ignore: cast_nullable_to_non_nullable
as String,frequencyId: null == frequencyId ? _self.frequencyId : frequencyId // ignore: cast_nullable_to_non_nullable
as String,nextRun: freezed == nextRun ? _self.nextRun : nextRun // ignore: cast_nullable_to_non_nullable
as Date?,isPaused: null == isPaused ? _self.isPaused : isPaused // ignore: cast_nullable_to_non_nullable
as bool,remainingCycles: null == remainingCycles ? _self.remainingCycles : remainingCycles // ignore: cast_nullable_to_non_nullable
as int,parameters: null == parameters ? _self._parameters : parameters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
