// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule_item_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ScheduleItemApi {

 String get date; String get amount;@JsonKey(name: 'auto_bill') bool get autoBill;
/// Create a copy of ScheduleItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleItemApiCopyWith<ScheduleItemApi> get copyWith => _$ScheduleItemApiCopyWithImpl<ScheduleItemApi>(this as ScheduleItemApi, _$identity);

  /// Serializes this ScheduleItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ScheduleItemApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ScheduleItemApi&&(identical(other.date, _this.date) || other.date == _this.date)&&(identical(other.amount, _this.amount) || other.amount == _this.amount)&&(identical(other.autoBill, _this.autoBill) || other.autoBill == _this.autoBill));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ScheduleItemApi;
  return Object.hash(runtimeType,_this.date,_this.amount,_this.autoBill);
}

@override
String toString() {
  final _this = this as ScheduleItemApi;
  return 'ScheduleItemApi(date: ${_this.date}, amount: ${_this.amount}, autoBill: ${_this.autoBill})';
}


}

/// @nodoc
abstract mixin class $ScheduleItemApiCopyWith<$Res>  {
  factory $ScheduleItemApiCopyWith(ScheduleItemApi value, $Res Function(ScheduleItemApi) _then) = _$ScheduleItemApiCopyWithImpl;
@useResult
$Res call({
 String date, String amount,@JsonKey(name: 'auto_bill') bool autoBill
});




}
/// @nodoc
class _$ScheduleItemApiCopyWithImpl<$Res>
    implements $ScheduleItemApiCopyWith<$Res> {
  _$ScheduleItemApiCopyWithImpl(this._self, this._then);

  final ScheduleItemApi _self;
  final $Res Function(ScheduleItemApi) _then;

/// Create a copy of ScheduleItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? amount = null,Object? autoBill = null,}) {
  return _then(ScheduleItemApi(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,autoBill: null == autoBill ? _self.autoBill : autoBill // ignore: cast_nullable_to_non_nullable
as bool,
  ));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  String amount, @JsonKey(name: 'auto_bill')  bool autoBill)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ScheduleItemApi() when $default != null:
return $default(_that.date,_that.amount,_that.autoBill);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  String amount, @JsonKey(name: 'auto_bill')  bool autoBill)  $default,) {final _that = this;
switch (_that) {
case _ScheduleItemApi():
return $default(_that.date,_that.amount,_that.autoBill);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  String amount, @JsonKey(name: 'auto_bill')  bool autoBill)?  $default,) {final _that = this;
switch (_that) {
case _ScheduleItemApi() when $default != null:
return $default(_that.date,_that.amount,_that.autoBill);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ScheduleItemApi implements ScheduleItemApi {
  const _ScheduleItemApi({this.date = '', this.amount = '', @JsonKey(name: 'auto_bill') this.autoBill = false});
  factory _ScheduleItemApi.fromJson(Map<String, dynamic> json) => _$ScheduleItemApiFromJson(json);

@override@JsonKey() final  String date;
@override@JsonKey() final  String amount;
@override@JsonKey(name: 'auto_bill') final  bool autoBill;

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
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ScheduleItemApi&&(identical(other.date, date) || other.date == date)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.autoBill, autoBill) || other.autoBill == autoBill));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,date,amount,autoBill);
}

@override
String toString() {
    return 'ScheduleItemApi(date: $date, amount: $amount, autoBill: $autoBill)';
}


}

/// @nodoc
abstract mixin class _$ScheduleItemApiCopyWith<$Res> implements $ScheduleItemApiCopyWith<$Res> {
  factory _$ScheduleItemApiCopyWith(_ScheduleItemApi value, $Res Function(_ScheduleItemApi) _then) = __$ScheduleItemApiCopyWithImpl;
@override @useResult
$Res call({
 String date, String amount,@JsonKey(name: 'auto_bill') bool autoBill
});




}
/// @nodoc
class __$ScheduleItemApiCopyWithImpl<$Res>
    implements _$ScheduleItemApiCopyWith<$Res> {
  __$ScheduleItemApiCopyWithImpl(this._self, this._then);

  final _ScheduleItemApi _self;
  final $Res Function(_ScheduleItemApi) _then;

/// Create a copy of ScheduleItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? amount = null,Object? autoBill = null,}) {
  return _then(_ScheduleItemApi(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as String,autoBill: null == autoBill ? _self.autoBill : autoBill // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
