// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tax_rate_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaxRateApi {

 String get id; String get name; double get rate;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of TaxRateApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaxRateApiCopyWith<TaxRateApi> get copyWith => _$TaxRateApiCopyWithImpl<TaxRateApi>(this as TaxRateApi, _$identity);

  /// Serializes this TaxRateApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaxRateApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,rate,createdAt,updatedAt,archivedAt,isDeleted);

@override
String toString() {
  return 'TaxRateApi(id: $id, name: $name, rate: $rate, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class $TaxRateApiCopyWith<$Res>  {
  factory $TaxRateApiCopyWith(TaxRateApi value, $Res Function(TaxRateApi) _then) = _$TaxRateApiCopyWithImpl;
@useResult
$Res call({
 String id, String name, double rate,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class _$TaxRateApiCopyWithImpl<$Res>
    implements $TaxRateApiCopyWith<$Res> {
  _$TaxRateApiCopyWithImpl(this._self, this._then);

  final TaxRateApi _self;
  final $Res Function(TaxRateApi) _then;

/// Create a copy of TaxRateApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? rate = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as double,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [TaxRateApi].
extension TaxRateApiPatterns on TaxRateApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaxRateApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaxRateApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaxRateApi value)  $default,){
final _that = this;
switch (_that) {
case _TaxRateApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaxRateApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaxRateApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  double rate, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaxRateApi() when $default != null:
return $default(_that.id,_that.name,_that.rate,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  double rate, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _TaxRateApi():
return $default(_that.id,_that.name,_that.rate,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  double rate, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _TaxRateApi() when $default != null:
return $default(_that.id,_that.name,_that.rate,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaxRateApi implements TaxRateApi {
  const _TaxRateApi({this.id = '', this.name = '', this.rate = 0.0, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false});
  factory _TaxRateApi.fromJson(Map<String, dynamic> json) => _$TaxRateApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  double rate;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of TaxRateApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaxRateApiCopyWith<_TaxRateApi> get copyWith => __$TaxRateApiCopyWithImpl<_TaxRateApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaxRateApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaxRateApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.rate, rate) || other.rate == rate)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,rate,createdAt,updatedAt,archivedAt,isDeleted);

@override
String toString() {
  return 'TaxRateApi(id: $id, name: $name, rate: $rate, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$TaxRateApiCopyWith<$Res> implements $TaxRateApiCopyWith<$Res> {
  factory _$TaxRateApiCopyWith(_TaxRateApi value, $Res Function(_TaxRateApi) _then) = __$TaxRateApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, double rate,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class __$TaxRateApiCopyWithImpl<$Res>
    implements _$TaxRateApiCopyWith<$Res> {
  __$TaxRateApiCopyWithImpl(this._self, this._then);

  final _TaxRateApi _self;
  final $Res Function(_TaxRateApi) _then;

/// Create a copy of TaxRateApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? rate = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_TaxRateApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate // ignore: cast_nullable_to_non_nullable
as double,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$TaxRateListApi {

@JsonKey(fromJson: _taxRateListData) List<TaxRateApi> get data;
/// Create a copy of TaxRateListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaxRateListApiCopyWith<TaxRateListApi> get copyWith => _$TaxRateListApiCopyWithImpl<TaxRateListApi>(this as TaxRateListApi, _$identity);

  /// Serializes this TaxRateListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaxRateListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'TaxRateListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $TaxRateListApiCopyWith<$Res>  {
  factory $TaxRateListApiCopyWith(TaxRateListApi value, $Res Function(TaxRateListApi) _then) = _$TaxRateListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _taxRateListData) List<TaxRateApi> data
});




}
/// @nodoc
class _$TaxRateListApiCopyWithImpl<$Res>
    implements $TaxRateListApiCopyWith<$Res> {
  _$TaxRateListApiCopyWithImpl(this._self, this._then);

  final TaxRateListApi _self;
  final $Res Function(TaxRateListApi) _then;

/// Create a copy of TaxRateListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<TaxRateApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [TaxRateListApi].
extension TaxRateListApiPatterns on TaxRateListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaxRateListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaxRateListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaxRateListApi value)  $default,){
final _that = this;
switch (_that) {
case _TaxRateListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaxRateListApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaxRateListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _taxRateListData)  List<TaxRateApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaxRateListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _taxRateListData)  List<TaxRateApi> data)  $default,) {final _that = this;
switch (_that) {
case _TaxRateListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _taxRateListData)  List<TaxRateApi> data)?  $default,) {final _that = this;
switch (_that) {
case _TaxRateListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaxRateListApi implements TaxRateListApi {
  const _TaxRateListApi({@JsonKey(fromJson: _taxRateListData) final  List<TaxRateApi> data = const []}): _data = data;
  factory _TaxRateListApi.fromJson(Map<String, dynamic> json) => _$TaxRateListApiFromJson(json);

 final  List<TaxRateApi> _data;
@override@JsonKey(fromJson: _taxRateListData) List<TaxRateApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of TaxRateListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaxRateListApiCopyWith<_TaxRateListApi> get copyWith => __$TaxRateListApiCopyWithImpl<_TaxRateListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaxRateListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaxRateListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'TaxRateListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TaxRateListApiCopyWith<$Res> implements $TaxRateListApiCopyWith<$Res> {
  factory _$TaxRateListApiCopyWith(_TaxRateListApi value, $Res Function(_TaxRateListApi) _then) = __$TaxRateListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _taxRateListData) List<TaxRateApi> data
});




}
/// @nodoc
class __$TaxRateListApiCopyWithImpl<$Res>
    implements _$TaxRateListApiCopyWith<$Res> {
  __$TaxRateListApiCopyWithImpl(this._self, this._then);

  final _TaxRateListApi _self;
  final $Res Function(_TaxRateListApi) _then;

/// Create a copy of TaxRateListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TaxRateListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<TaxRateApi>,
  ));
}


}


/// @nodoc
mixin _$TaxRateItemApi {

 TaxRateApi get data;
/// Create a copy of TaxRateItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaxRateItemApiCopyWith<TaxRateItemApi> get copyWith => _$TaxRateItemApiCopyWithImpl<TaxRateItemApi>(this as TaxRateItemApi, _$identity);

  /// Serializes this TaxRateItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaxRateItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'TaxRateItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $TaxRateItemApiCopyWith<$Res>  {
  factory $TaxRateItemApiCopyWith(TaxRateItemApi value, $Res Function(TaxRateItemApi) _then) = _$TaxRateItemApiCopyWithImpl;
@useResult
$Res call({
 TaxRateApi data
});


$TaxRateApiCopyWith<$Res> get data;

}
/// @nodoc
class _$TaxRateItemApiCopyWithImpl<$Res>
    implements $TaxRateItemApiCopyWith<$Res> {
  _$TaxRateItemApiCopyWithImpl(this._self, this._then);

  final TaxRateItemApi _self;
  final $Res Function(TaxRateItemApi) _then;

/// Create a copy of TaxRateItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TaxRateApi,
  ));
}
/// Create a copy of TaxRateItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaxRateApiCopyWith<$Res> get data {
  
  return $TaxRateApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [TaxRateItemApi].
extension TaxRateItemApiPatterns on TaxRateItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaxRateItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaxRateItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaxRateItemApi value)  $default,){
final _that = this;
switch (_that) {
case _TaxRateItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaxRateItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaxRateItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TaxRateApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaxRateItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TaxRateApi data)  $default,) {final _that = this;
switch (_that) {
case _TaxRateItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TaxRateApi data)?  $default,) {final _that = this;
switch (_that) {
case _TaxRateItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaxRateItemApi implements TaxRateItemApi {
  const _TaxRateItemApi({required this.data});
  factory _TaxRateItemApi.fromJson(Map<String, dynamic> json) => _$TaxRateItemApiFromJson(json);

@override final  TaxRateApi data;

/// Create a copy of TaxRateItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaxRateItemApiCopyWith<_TaxRateItemApi> get copyWith => __$TaxRateItemApiCopyWithImpl<_TaxRateItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaxRateItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaxRateItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'TaxRateItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TaxRateItemApiCopyWith<$Res> implements $TaxRateItemApiCopyWith<$Res> {
  factory _$TaxRateItemApiCopyWith(_TaxRateItemApi value, $Res Function(_TaxRateItemApi) _then) = __$TaxRateItemApiCopyWithImpl;
@override @useResult
$Res call({
 TaxRateApi data
});


@override $TaxRateApiCopyWith<$Res> get data;

}
/// @nodoc
class __$TaxRateItemApiCopyWithImpl<$Res>
    implements _$TaxRateItemApiCopyWith<$Res> {
  __$TaxRateItemApiCopyWithImpl(this._self, this._then);

  final _TaxRateItemApi _self;
  final $Res Function(_TaxRateItemApi) _then;

/// Create a copy of TaxRateItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TaxRateItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TaxRateApi,
  ));
}

/// Create a copy of TaxRateItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaxRateApiCopyWith<$Res> get data {
  
  return $TaxRateApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
