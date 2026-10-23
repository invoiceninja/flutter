// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'activity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Activity {

 String get id; int get activityTypeId; String get notes; DateTime get createdAt; String get ip; Map<String, ActivityRef> get refs;
/// Create a copy of Activity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivityCopyWith<Activity> get copyWith => _$ActivityCopyWithImpl<Activity>(this as Activity, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Activity;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Activity&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.activityTypeId, _this.activityTypeId) || other.activityTypeId == _this.activityTypeId)&&(identical(other.notes, _this.notes) || other.notes == _this.notes)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.ip, _this.ip) || other.ip == _this.ip)&&const DeepCollectionEquality().equals(other.refs, _this.refs));
}


@override
int get hashCode {
  final _this = this as Activity;
  return Object.hash(runtimeType,_this.id,_this.activityTypeId,_this.notes,_this.createdAt,_this.ip,const DeepCollectionEquality().hash(_this.refs));
}

@override
String toString() {
  final _this = this as Activity;
  return 'Activity(id: ${_this.id}, activityTypeId: ${_this.activityTypeId}, notes: ${_this.notes}, createdAt: ${_this.createdAt}, ip: ${_this.ip}, refs: ${_this.refs})';
}


}

/// @nodoc
abstract mixin class $ActivityCopyWith<$Res>  {
  factory $ActivityCopyWith(Activity value, $Res Function(Activity) _then) = _$ActivityCopyWithImpl;
@useResult
$Res call({
 String id, int activityTypeId, String notes, DateTime createdAt, String ip, Map<String, ActivityRef> refs
});




}
/// @nodoc
class _$ActivityCopyWithImpl<$Res>
    implements $ActivityCopyWith<$Res> {
  _$ActivityCopyWithImpl(this._self, this._then);

  final Activity _self;
  final $Res Function(Activity) _then;

/// Create a copy of Activity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? activityTypeId = null,Object? notes = null,Object? createdAt = null,Object? ip = null,Object? refs = null,}) {
  return _then(Activity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activityTypeId: null == activityTypeId ? _self.activityTypeId : activityTypeId // ignore: cast_nullable_to_non_nullable
as int,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,refs: null == refs ? _self.refs : refs // ignore: cast_nullable_to_non_nullable
as Map<String, ActivityRef>,
  ));
}

}


/// Adds pattern-matching-related methods to [Activity].
extension ActivityPatterns on Activity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Activity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Activity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Activity value)  $default,){
final _that = this;
switch (_that) {
case _Activity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Activity value)?  $default,){
final _that = this;
switch (_that) {
case _Activity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int activityTypeId,  String notes,  DateTime createdAt,  String ip,  Map<String, ActivityRef> refs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Activity() when $default != null:
return $default(_that.id,_that.activityTypeId,_that.notes,_that.createdAt,_that.ip,_that.refs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int activityTypeId,  String notes,  DateTime createdAt,  String ip,  Map<String, ActivityRef> refs)  $default,) {final _that = this;
switch (_that) {
case _Activity():
return $default(_that.id,_that.activityTypeId,_that.notes,_that.createdAt,_that.ip,_that.refs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int activityTypeId,  String notes,  DateTime createdAt,  String ip,  Map<String, ActivityRef> refs)?  $default,) {final _that = this;
switch (_that) {
case _Activity() when $default != null:
return $default(_that.id,_that.activityTypeId,_that.notes,_that.createdAt,_that.ip,_that.refs);case _:
  return null;

}
}

}

/// @nodoc


class _Activity extends Activity {
  const _Activity({required this.id, required this.activityTypeId, required this.notes, required this.createdAt, required this.ip,  Map<String, ActivityRef> refs = const <String, ActivityRef>{}}): _refs = refs,super._();
  

@override final  String id;
@override final  int activityTypeId;
@override final  String notes;
@override final  DateTime createdAt;
@override final  String ip;
 final  Map<String, ActivityRef> _refs;
@override@JsonKey() Map<String, ActivityRef> get refs {
  if (_refs is EqualUnmodifiableMapView) return _refs;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_refs);
}


/// Create a copy of Activity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivityCopyWith<_Activity> get copyWith => __$ActivityCopyWithImpl<_Activity>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Activity&&(identical(other.id, id) || other.id == id)&&(identical(other.activityTypeId, activityTypeId) || other.activityTypeId == activityTypeId)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.ip, ip) || other.ip == ip)&&const DeepCollectionEquality().equals(other.refs, _refs));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,activityTypeId,notes,createdAt,ip,const DeepCollectionEquality().hash(_refs));
}

@override
String toString() {
    return 'Activity(id: $id, activityTypeId: $activityTypeId, notes: $notes, createdAt: $createdAt, ip: $ip, refs: $refs)';
}


}

/// @nodoc
abstract mixin class _$ActivityCopyWith<$Res> implements $ActivityCopyWith<$Res> {
  factory _$ActivityCopyWith(_Activity value, $Res Function(_Activity) _then) = __$ActivityCopyWithImpl;
@override @useResult
$Res call({
 String id, int activityTypeId, String notes, DateTime createdAt, String ip, Map<String, ActivityRef> refs
});




}
/// @nodoc
class __$ActivityCopyWithImpl<$Res>
    implements _$ActivityCopyWith<$Res> {
  __$ActivityCopyWithImpl(this._self, this._then);

  final _Activity _self;
  final $Res Function(_Activity) _then;

/// Create a copy of Activity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? activityTypeId = null,Object? notes = null,Object? createdAt = null,Object? ip = null,Object? refs = null,}) {
  return _then(_Activity(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activityTypeId: null == activityTypeId ? _self.activityTypeId : activityTypeId // ignore: cast_nullable_to_non_nullable
as int,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,ip: null == ip ? _self.ip : ip // ignore: cast_nullable_to_non_nullable
as String,refs: null == refs ? _self._refs : refs // ignore: cast_nullable_to_non_nullable
as Map<String, ActivityRef>,
  ));
}


}

// dart format on
