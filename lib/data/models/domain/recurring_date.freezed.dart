// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recurring_date.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RecurringDate {

 Date? get sendDate;
/// Create a copy of RecurringDate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecurringDateCopyWith<RecurringDate> get copyWith => _$RecurringDateCopyWithImpl<RecurringDate>(this as RecurringDate, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RecurringDate;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecurringDate&&(identical(other.sendDate, _this.sendDate) || other.sendDate == _this.sendDate));
}


@override
int get hashCode {
  final _this = this as RecurringDate;
  return Object.hash(runtimeType,_this.sendDate);
}

@override
String toString() {
  final _this = this as RecurringDate;
  return 'RecurringDate(sendDate: ${_this.sendDate})';
}


}

/// @nodoc
abstract mixin class $RecurringDateCopyWith<$Res>  {
  factory $RecurringDateCopyWith(RecurringDate value, $Res Function(RecurringDate) _then) = _$RecurringDateCopyWithImpl;
@useResult
$Res call({
 Date? sendDate
});




}
/// @nodoc
class _$RecurringDateCopyWithImpl<$Res>
    implements $RecurringDateCopyWith<$Res> {
  _$RecurringDateCopyWithImpl(this._self, this._then);

  final RecurringDate _self;
  final $Res Function(RecurringDate) _then;

/// Create a copy of RecurringDate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? sendDate = freezed,}) {
  return _then(RecurringDate(
sendDate: freezed == sendDate ? _self.sendDate : sendDate // ignore: cast_nullable_to_non_nullable
as Date?,
  ));
}

}


/// Adds pattern-matching-related methods to [RecurringDate].
extension RecurringDatePatterns on RecurringDate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecurringDate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecurringDate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecurringDate value)  $default,){
final _that = this;
switch (_that) {
case _RecurringDate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecurringDate value)?  $default,){
final _that = this;
switch (_that) {
case _RecurringDate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Date? sendDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecurringDate() when $default != null:
return $default(_that.sendDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Date? sendDate)  $default,) {final _that = this;
switch (_that) {
case _RecurringDate():
return $default(_that.sendDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Date? sendDate)?  $default,) {final _that = this;
switch (_that) {
case _RecurringDate() when $default != null:
return $default(_that.sendDate);case _:
  return null;

}
}

}

/// @nodoc


class _RecurringDate implements RecurringDate {
  const _RecurringDate({required this.sendDate});
  

@override final  Date? sendDate;

/// Create a copy of RecurringDate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecurringDateCopyWith<_RecurringDate> get copyWith => __$RecurringDateCopyWithImpl<_RecurringDate>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecurringDate&&(identical(other.sendDate, sendDate) || other.sendDate == sendDate));
}


@override
int get hashCode {
    return Object.hash(runtimeType,sendDate);
}

@override
String toString() {
    return 'RecurringDate(sendDate: $sendDate)';
}


}

/// @nodoc
abstract mixin class _$RecurringDateCopyWith<$Res> implements $RecurringDateCopyWith<$Res> {
  factory _$RecurringDateCopyWith(_RecurringDate value, $Res Function(_RecurringDate) _then) = __$RecurringDateCopyWithImpl;
@override @useResult
$Res call({
 Date? sendDate
});




}
/// @nodoc
class __$RecurringDateCopyWithImpl<$Res>
    implements _$RecurringDateCopyWith<$Res> {
  __$RecurringDateCopyWithImpl(this._self, this._then);

  final _RecurringDate _self;
  final $Res Function(_RecurringDate) _then;

/// Create a copy of RecurringDate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? sendDate = freezed,}) {
  return _then(_RecurringDate(
sendDate: freezed == sendDate ? _self.sendDate : sendDate // ignore: cast_nullable_to_non_nullable
as Date?,
  ));
}


}

// dart format on
