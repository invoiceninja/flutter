// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'webhook_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WebhookApi {

 String get id;@JsonKey(name: 'event_id') String get eventId;@JsonKey(name: 'target_url') String get targetUrl; String get format;@JsonKey(name: 'rest_method') String get restMethod;@JsonKey(fromJson: _headersFromJson) Map<String, String> get headers;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;
/// Create a copy of WebhookApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WebhookApiCopyWith<WebhookApi> get copyWith => _$WebhookApiCopyWithImpl<WebhookApi>(this as WebhookApi, _$identity);

  /// Serializes this WebhookApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WebhookApi&&(identical(other.id, id) || other.id == id)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.targetUrl, targetUrl) || other.targetUrl == targetUrl)&&(identical(other.format, format) || other.format == format)&&(identical(other.restMethod, restMethod) || other.restMethod == restMethod)&&const DeepCollectionEquality().equals(other.headers, headers)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,eventId,targetUrl,format,restMethod,const DeepCollectionEquality().hash(headers),isDeleted,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'WebhookApi(id: $id, eventId: $eventId, targetUrl: $targetUrl, format: $format, restMethod: $restMethod, headers: $headers, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class $WebhookApiCopyWith<$Res>  {
  factory $WebhookApiCopyWith(WebhookApi value, $Res Function(WebhookApi) _then) = _$WebhookApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'event_id') String eventId,@JsonKey(name: 'target_url') String targetUrl, String format,@JsonKey(name: 'rest_method') String restMethod,@JsonKey(fromJson: _headersFromJson) Map<String, String> headers,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class _$WebhookApiCopyWithImpl<$Res>
    implements $WebhookApiCopyWith<$Res> {
  _$WebhookApiCopyWithImpl(this._self, this._then);

  final WebhookApi _self;
  final $Res Function(WebhookApi) _then;

/// Create a copy of WebhookApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? eventId = null,Object? targetUrl = null,Object? format = null,Object? restMethod = null,Object? headers = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,targetUrl: null == targetUrl ? _self.targetUrl : targetUrl // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,restMethod: null == restMethod ? _self.restMethod : restMethod // ignore: cast_nullable_to_non_nullable
as String,headers: null == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [WebhookApi].
extension WebhookApiPatterns on WebhookApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WebhookApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WebhookApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WebhookApi value)  $default,){
final _that = this;
switch (_that) {
case _WebhookApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WebhookApi value)?  $default,){
final _that = this;
switch (_that) {
case _WebhookApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'event_id')  String eventId, @JsonKey(name: 'target_url')  String targetUrl,  String format, @JsonKey(name: 'rest_method')  String restMethod, @JsonKey(fromJson: _headersFromJson)  Map<String, String> headers, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WebhookApi() when $default != null:
return $default(_that.id,_that.eventId,_that.targetUrl,_that.format,_that.restMethod,_that.headers,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'event_id')  String eventId, @JsonKey(name: 'target_url')  String targetUrl,  String format, @JsonKey(name: 'rest_method')  String restMethod, @JsonKey(fromJson: _headersFromJson)  Map<String, String> headers, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)  $default,) {final _that = this;
switch (_that) {
case _WebhookApi():
return $default(_that.id,_that.eventId,_that.targetUrl,_that.format,_that.restMethod,_that.headers,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'event_id')  String eventId, @JsonKey(name: 'target_url')  String targetUrl,  String format, @JsonKey(name: 'rest_method')  String restMethod, @JsonKey(fromJson: _headersFromJson)  Map<String, String> headers, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt)?  $default,) {final _that = this;
switch (_that) {
case _WebhookApi() when $default != null:
return $default(_that.id,_that.eventId,_that.targetUrl,_that.format,_that.restMethod,_that.headers,_that.isDeleted,_that.createdAt,_that.updatedAt,_that.archivedAt);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _WebhookApi implements WebhookApi {
  const _WebhookApi({this.id = '', @JsonKey(name: 'event_id') this.eventId = '', @JsonKey(name: 'target_url') this.targetUrl = '', this.format = 'JSON', @JsonKey(name: 'rest_method') this.restMethod = 'post', @JsonKey(fromJson: _headersFromJson) final  Map<String, String> headers = const <String, String>{}, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0}): _headers = headers;
  factory _WebhookApi.fromJson(Map<String, dynamic> json) => _$WebhookApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'event_id') final  String eventId;
@override@JsonKey(name: 'target_url') final  String targetUrl;
@override@JsonKey() final  String format;
@override@JsonKey(name: 'rest_method') final  String restMethod;
 final  Map<String, String> _headers;
@override@JsonKey(fromJson: _headersFromJson) Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}

@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;

/// Create a copy of WebhookApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WebhookApiCopyWith<_WebhookApi> get copyWith => __$WebhookApiCopyWithImpl<_WebhookApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WebhookApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WebhookApi&&(identical(other.id, id) || other.id == id)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.targetUrl, targetUrl) || other.targetUrl == targetUrl)&&(identical(other.format, format) || other.format == format)&&(identical(other.restMethod, restMethod) || other.restMethod == restMethod)&&const DeepCollectionEquality().equals(other._headers, _headers)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,eventId,targetUrl,format,restMethod,const DeepCollectionEquality().hash(_headers),isDeleted,createdAt,updatedAt,archivedAt);

@override
String toString() {
  return 'WebhookApi(id: $id, eventId: $eventId, targetUrl: $targetUrl, format: $format, restMethod: $restMethod, headers: $headers, isDeleted: $isDeleted, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt)';
}


}

/// @nodoc
abstract mixin class _$WebhookApiCopyWith<$Res> implements $WebhookApiCopyWith<$Res> {
  factory _$WebhookApiCopyWith(_WebhookApi value, $Res Function(_WebhookApi) _then) = __$WebhookApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'event_id') String eventId,@JsonKey(name: 'target_url') String targetUrl, String format,@JsonKey(name: 'rest_method') String restMethod,@JsonKey(fromJson: _headersFromJson) Map<String, String> headers,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt
});




}
/// @nodoc
class __$WebhookApiCopyWithImpl<$Res>
    implements _$WebhookApiCopyWith<$Res> {
  __$WebhookApiCopyWithImpl(this._self, this._then);

  final _WebhookApi _self;
  final $Res Function(_WebhookApi) _then;

/// Create a copy of WebhookApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? eventId = null,Object? targetUrl = null,Object? format = null,Object? restMethod = null,Object? headers = null,Object? isDeleted = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,}) {
  return _then(_WebhookApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,targetUrl: null == targetUrl ? _self.targetUrl : targetUrl // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,restMethod: null == restMethod ? _self.restMethod : restMethod // ignore: cast_nullable_to_non_nullable
as String,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$WebhookListApi {

@JsonKey(fromJson: _webhookListData) List<WebhookApi> get data;
/// Create a copy of WebhookListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WebhookListApiCopyWith<WebhookListApi> get copyWith => _$WebhookListApiCopyWithImpl<WebhookListApi>(this as WebhookListApi, _$identity);

  /// Serializes this WebhookListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WebhookListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'WebhookListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $WebhookListApiCopyWith<$Res>  {
  factory $WebhookListApiCopyWith(WebhookListApi value, $Res Function(WebhookListApi) _then) = _$WebhookListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _webhookListData) List<WebhookApi> data
});




}
/// @nodoc
class _$WebhookListApiCopyWithImpl<$Res>
    implements $WebhookListApiCopyWith<$Res> {
  _$WebhookListApiCopyWithImpl(this._self, this._then);

  final WebhookListApi _self;
  final $Res Function(WebhookListApi) _then;

/// Create a copy of WebhookListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<WebhookApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [WebhookListApi].
extension WebhookListApiPatterns on WebhookListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WebhookListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WebhookListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WebhookListApi value)  $default,){
final _that = this;
switch (_that) {
case _WebhookListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WebhookListApi value)?  $default,){
final _that = this;
switch (_that) {
case _WebhookListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _webhookListData)  List<WebhookApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WebhookListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _webhookListData)  List<WebhookApi> data)  $default,) {final _that = this;
switch (_that) {
case _WebhookListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _webhookListData)  List<WebhookApi> data)?  $default,) {final _that = this;
switch (_that) {
case _WebhookListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WebhookListApi implements WebhookListApi {
  const _WebhookListApi({@JsonKey(fromJson: _webhookListData) final  List<WebhookApi> data = const []}): _data = data;
  factory _WebhookListApi.fromJson(Map<String, dynamic> json) => _$WebhookListApiFromJson(json);

 final  List<WebhookApi> _data;
@override@JsonKey(fromJson: _webhookListData) List<WebhookApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of WebhookListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WebhookListApiCopyWith<_WebhookListApi> get copyWith => __$WebhookListApiCopyWithImpl<_WebhookListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WebhookListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WebhookListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'WebhookListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$WebhookListApiCopyWith<$Res> implements $WebhookListApiCopyWith<$Res> {
  factory _$WebhookListApiCopyWith(_WebhookListApi value, $Res Function(_WebhookListApi) _then) = __$WebhookListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _webhookListData) List<WebhookApi> data
});




}
/// @nodoc
class __$WebhookListApiCopyWithImpl<$Res>
    implements _$WebhookListApiCopyWith<$Res> {
  __$WebhookListApiCopyWithImpl(this._self, this._then);

  final _WebhookListApi _self;
  final $Res Function(_WebhookListApi) _then;

/// Create a copy of WebhookListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_WebhookListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<WebhookApi>,
  ));
}


}


/// @nodoc
mixin _$WebhookItemApi {

 WebhookApi get data;
/// Create a copy of WebhookItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WebhookItemApiCopyWith<WebhookItemApi> get copyWith => _$WebhookItemApiCopyWithImpl<WebhookItemApi>(this as WebhookItemApi, _$identity);

  /// Serializes this WebhookItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WebhookItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'WebhookItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $WebhookItemApiCopyWith<$Res>  {
  factory $WebhookItemApiCopyWith(WebhookItemApi value, $Res Function(WebhookItemApi) _then) = _$WebhookItemApiCopyWithImpl;
@useResult
$Res call({
 WebhookApi data
});


$WebhookApiCopyWith<$Res> get data;

}
/// @nodoc
class _$WebhookItemApiCopyWithImpl<$Res>
    implements $WebhookItemApiCopyWith<$Res> {
  _$WebhookItemApiCopyWithImpl(this._self, this._then);

  final WebhookItemApi _self;
  final $Res Function(WebhookItemApi) _then;

/// Create a copy of WebhookItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as WebhookApi,
  ));
}
/// Create a copy of WebhookItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WebhookApiCopyWith<$Res> get data {
  
  return $WebhookApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [WebhookItemApi].
extension WebhookItemApiPatterns on WebhookItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WebhookItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WebhookItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WebhookItemApi value)  $default,){
final _that = this;
switch (_that) {
case _WebhookItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WebhookItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _WebhookItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( WebhookApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WebhookItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( WebhookApi data)  $default,) {final _that = this;
switch (_that) {
case _WebhookItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( WebhookApi data)?  $default,) {final _that = this;
switch (_that) {
case _WebhookItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _WebhookItemApi implements WebhookItemApi {
  const _WebhookItemApi({required this.data});
  factory _WebhookItemApi.fromJson(Map<String, dynamic> json) => _$WebhookItemApiFromJson(json);

@override final  WebhookApi data;

/// Create a copy of WebhookItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WebhookItemApiCopyWith<_WebhookItemApi> get copyWith => __$WebhookItemApiCopyWithImpl<_WebhookItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$WebhookItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _WebhookItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'WebhookItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$WebhookItemApiCopyWith<$Res> implements $WebhookItemApiCopyWith<$Res> {
  factory _$WebhookItemApiCopyWith(_WebhookItemApi value, $Res Function(_WebhookItemApi) _then) = __$WebhookItemApiCopyWithImpl;
@override @useResult
$Res call({
 WebhookApi data
});


@override $WebhookApiCopyWith<$Res> get data;

}
/// @nodoc
class __$WebhookItemApiCopyWithImpl<$Res>
    implements _$WebhookItemApiCopyWith<$Res> {
  __$WebhookItemApiCopyWithImpl(this._self, this._then);

  final _WebhookItemApi _self;
  final $Res Function(_WebhookItemApi) _then;

/// Create a copy of WebhookItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_WebhookItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as WebhookApi,
  ));
}

/// Create a copy of WebhookItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$WebhookApiCopyWith<$Res> get data {
  
  return $WebhookApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
