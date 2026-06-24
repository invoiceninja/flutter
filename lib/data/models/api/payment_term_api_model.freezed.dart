// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_term_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentTermApi {

 String get id; String get name;@JsonKey(name: 'num_days') int get numDays;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;
/// Create a copy of PaymentTermApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentTermApiCopyWith<PaymentTermApi> get copyWith => _$PaymentTermApiCopyWithImpl<PaymentTermApi>(this as PaymentTermApi, _$identity);

  /// Serializes this PaymentTermApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentTermApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.numDays, numDays) || other.numDays == numDays)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,numDays,createdAt,updatedAt,archivedAt,isDeleted);

@override
String toString() {
  return 'PaymentTermApi(id: $id, name: $name, numDays: $numDays, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class $PaymentTermApiCopyWith<$Res>  {
  factory $PaymentTermApiCopyWith(PaymentTermApi value, $Res Function(PaymentTermApi) _then) = _$PaymentTermApiCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(name: 'num_days') int numDays,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class _$PaymentTermApiCopyWithImpl<$Res>
    implements $PaymentTermApiCopyWith<$Res> {
  _$PaymentTermApiCopyWithImpl(this._self, this._then);

  final PaymentTermApi _self;
  final $Res Function(PaymentTermApi) _then;

/// Create a copy of PaymentTermApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? numDays = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,numDays: null == numDays ? _self.numDays : numDays // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentTermApi].
extension PaymentTermApiPatterns on PaymentTermApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentTermApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentTermApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentTermApi value)  $default,){
final _that = this;
switch (_that) {
case _PaymentTermApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentTermApi value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentTermApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'num_days')  int numDays, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentTermApi() when $default != null:
return $default(_that.id,_that.name,_that.numDays,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'num_days')  int numDays, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)  $default,) {final _that = this;
switch (_that) {
case _PaymentTermApi():
return $default(_that.id,_that.name,_that.numDays,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @JsonKey(name: 'num_days')  int numDays, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted)?  $default,) {final _that = this;
switch (_that) {
case _PaymentTermApi() when $default != null:
return $default(_that.id,_that.name,_that.numDays,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentTermApi implements PaymentTermApi {
  const _PaymentTermApi({this.id = '', this.name = '', @JsonKey(name: 'num_days') this.numDays = 0, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false});
  factory _PaymentTermApi.fromJson(Map<String, dynamic> json) => _$PaymentTermApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override@JsonKey(name: 'num_days') final  int numDays;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;

/// Create a copy of PaymentTermApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentTermApiCopyWith<_PaymentTermApi> get copyWith => __$PaymentTermApiCopyWithImpl<_PaymentTermApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentTermApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentTermApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.numDays, numDays) || other.numDays == numDays)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,numDays,createdAt,updatedAt,archivedAt,isDeleted);

@override
String toString() {
  return 'PaymentTermApi(id: $id, name: $name, numDays: $numDays, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted)';
}


}

/// @nodoc
abstract mixin class _$PaymentTermApiCopyWith<$Res> implements $PaymentTermApiCopyWith<$Res> {
  factory _$PaymentTermApiCopyWith(_PaymentTermApi value, $Res Function(_PaymentTermApi) _then) = __$PaymentTermApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@JsonKey(name: 'num_days') int numDays,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted
});




}
/// @nodoc
class __$PaymentTermApiCopyWithImpl<$Res>
    implements _$PaymentTermApiCopyWith<$Res> {
  __$PaymentTermApiCopyWithImpl(this._self, this._then);

  final _PaymentTermApi _self;
  final $Res Function(_PaymentTermApi) _then;

/// Create a copy of PaymentTermApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? numDays = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,}) {
  return _then(_PaymentTermApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,numDays: null == numDays ? _self.numDays : numDays // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$PaymentTermListApi {

@JsonKey(fromJson: _paymentTermListData) List<PaymentTermApi> get data;
/// Create a copy of PaymentTermListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentTermListApiCopyWith<PaymentTermListApi> get copyWith => _$PaymentTermListApiCopyWithImpl<PaymentTermListApi>(this as PaymentTermListApi, _$identity);

  /// Serializes this PaymentTermListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentTermListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'PaymentTermListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $PaymentTermListApiCopyWith<$Res>  {
  factory $PaymentTermListApiCopyWith(PaymentTermListApi value, $Res Function(PaymentTermListApi) _then) = _$PaymentTermListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _paymentTermListData) List<PaymentTermApi> data
});




}
/// @nodoc
class _$PaymentTermListApiCopyWithImpl<$Res>
    implements $PaymentTermListApiCopyWith<$Res> {
  _$PaymentTermListApiCopyWithImpl(this._self, this._then);

  final PaymentTermListApi _self;
  final $Res Function(PaymentTermListApi) _then;

/// Create a copy of PaymentTermListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<PaymentTermApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [PaymentTermListApi].
extension PaymentTermListApiPatterns on PaymentTermListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentTermListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentTermListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentTermListApi value)  $default,){
final _that = this;
switch (_that) {
case _PaymentTermListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentTermListApi value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentTermListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _paymentTermListData)  List<PaymentTermApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentTermListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _paymentTermListData)  List<PaymentTermApi> data)  $default,) {final _that = this;
switch (_that) {
case _PaymentTermListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _paymentTermListData)  List<PaymentTermApi> data)?  $default,) {final _that = this;
switch (_that) {
case _PaymentTermListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentTermListApi implements PaymentTermListApi {
  const _PaymentTermListApi({@JsonKey(fromJson: _paymentTermListData) final  List<PaymentTermApi> data = const []}): _data = data;
  factory _PaymentTermListApi.fromJson(Map<String, dynamic> json) => _$PaymentTermListApiFromJson(json);

 final  List<PaymentTermApi> _data;
@override@JsonKey(fromJson: _paymentTermListData) List<PaymentTermApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of PaymentTermListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentTermListApiCopyWith<_PaymentTermListApi> get copyWith => __$PaymentTermListApiCopyWithImpl<_PaymentTermListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentTermListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentTermListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'PaymentTermListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$PaymentTermListApiCopyWith<$Res> implements $PaymentTermListApiCopyWith<$Res> {
  factory _$PaymentTermListApiCopyWith(_PaymentTermListApi value, $Res Function(_PaymentTermListApi) _then) = __$PaymentTermListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _paymentTermListData) List<PaymentTermApi> data
});




}
/// @nodoc
class __$PaymentTermListApiCopyWithImpl<$Res>
    implements _$PaymentTermListApiCopyWith<$Res> {
  __$PaymentTermListApiCopyWithImpl(this._self, this._then);

  final _PaymentTermListApi _self;
  final $Res Function(_PaymentTermListApi) _then;

/// Create a copy of PaymentTermListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_PaymentTermListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<PaymentTermApi>,
  ));
}


}


/// @nodoc
mixin _$PaymentTermItemApi {

 PaymentTermApi get data;
/// Create a copy of PaymentTermItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PaymentTermItemApiCopyWith<PaymentTermItemApi> get copyWith => _$PaymentTermItemApiCopyWithImpl<PaymentTermItemApi>(this as PaymentTermItemApi, _$identity);

  /// Serializes this PaymentTermItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PaymentTermItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'PaymentTermItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $PaymentTermItemApiCopyWith<$Res>  {
  factory $PaymentTermItemApiCopyWith(PaymentTermItemApi value, $Res Function(PaymentTermItemApi) _then) = _$PaymentTermItemApiCopyWithImpl;
@useResult
$Res call({
 PaymentTermApi data
});


$PaymentTermApiCopyWith<$Res> get data;

}
/// @nodoc
class _$PaymentTermItemApiCopyWithImpl<$Res>
    implements $PaymentTermItemApiCopyWith<$Res> {
  _$PaymentTermItemApiCopyWithImpl(this._self, this._then);

  final PaymentTermItemApi _self;
  final $Res Function(PaymentTermItemApi) _then;

/// Create a copy of PaymentTermItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as PaymentTermApi,
  ));
}
/// Create a copy of PaymentTermItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentTermApiCopyWith<$Res> get data {
  
  return $PaymentTermApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [PaymentTermItemApi].
extension PaymentTermItemApiPatterns on PaymentTermItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PaymentTermItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PaymentTermItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PaymentTermItemApi value)  $default,){
final _that = this;
switch (_that) {
case _PaymentTermItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PaymentTermItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _PaymentTermItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PaymentTermApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PaymentTermItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PaymentTermApi data)  $default,) {final _that = this;
switch (_that) {
case _PaymentTermItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PaymentTermApi data)?  $default,) {final _that = this;
switch (_that) {
case _PaymentTermItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PaymentTermItemApi implements PaymentTermItemApi {
  const _PaymentTermItemApi({required this.data});
  factory _PaymentTermItemApi.fromJson(Map<String, dynamic> json) => _$PaymentTermItemApiFromJson(json);

@override final  PaymentTermApi data;

/// Create a copy of PaymentTermItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PaymentTermItemApiCopyWith<_PaymentTermItemApi> get copyWith => __$PaymentTermItemApiCopyWithImpl<_PaymentTermItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PaymentTermItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PaymentTermItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'PaymentTermItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$PaymentTermItemApiCopyWith<$Res> implements $PaymentTermItemApiCopyWith<$Res> {
  factory _$PaymentTermItemApiCopyWith(_PaymentTermItemApi value, $Res Function(_PaymentTermItemApi) _then) = __$PaymentTermItemApiCopyWithImpl;
@override @useResult
$Res call({
 PaymentTermApi data
});


@override $PaymentTermApiCopyWith<$Res> get data;

}
/// @nodoc
class __$PaymentTermItemApiCopyWithImpl<$Res>
    implements _$PaymentTermItemApiCopyWith<$Res> {
  __$PaymentTermItemApiCopyWithImpl(this._self, this._then);

  final _PaymentTermItemApi _self;
  final $Res Function(_PaymentTermItemApi) _then;

/// Create a copy of PaymentTermItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_PaymentTermItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as PaymentTermApi,
  ));
}

/// Create a copy of PaymentTermItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PaymentTermApiCopyWith<$Res> get data {
  
  return $PaymentTermApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
