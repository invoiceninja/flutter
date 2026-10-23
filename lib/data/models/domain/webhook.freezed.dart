// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'webhook.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Webhook {

 String get id; String get eventId; String get targetUrl; String get format; String get restMethod; Map<String, String> get headers; bool get isDeleted; DateTime get updatedAt; DateTime get createdAt; DateTime? get archivedAt; bool get isDirty;
/// Create a copy of Webhook
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WebhookCopyWith<Webhook> get copyWith => _$WebhookCopyWithImpl<Webhook>(this as Webhook, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Webhook;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Webhook&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.eventId, _this.eventId) || other.eventId == _this.eventId)&&(identical(other.targetUrl, _this.targetUrl) || other.targetUrl == _this.targetUrl)&&(identical(other.format, _this.format) || other.format == _this.format)&&(identical(other.restMethod, _this.restMethod) || other.restMethod == _this.restMethod)&&const DeepCollectionEquality().equals(other.headers, _this.headers)&&(identical(other.isDeleted, _this.isDeleted) || other.isDeleted == _this.isDeleted)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt)&&(identical(other.isDirty, _this.isDirty) || other.isDirty == _this.isDirty));
}


@override
int get hashCode {
  final _this = this as Webhook;
  return Object.hash(runtimeType,_this.id,_this.eventId,_this.targetUrl,_this.format,_this.restMethod,const DeepCollectionEquality().hash(_this.headers),_this.isDeleted,_this.updatedAt,_this.createdAt,_this.archivedAt,_this.isDirty);
}

@override
String toString() {
  final _this = this as Webhook;
  return 'Webhook(id: ${_this.id}, eventId: ${_this.eventId}, targetUrl: ${_this.targetUrl}, format: ${_this.format}, restMethod: ${_this.restMethod}, headers: ${_this.headers}, isDeleted: ${_this.isDeleted}, updatedAt: ${_this.updatedAt}, createdAt: ${_this.createdAt}, archivedAt: ${_this.archivedAt}, isDirty: ${_this.isDirty})';
}


}

/// @nodoc
abstract mixin class $WebhookCopyWith<$Res>  {
  factory $WebhookCopyWith(Webhook value, $Res Function(Webhook) _then) = _$WebhookCopyWithImpl;
@useResult
$Res call({
 String id, String eventId, String targetUrl, String format, String restMethod, Map<String, String> headers, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDirty
});




}
/// @nodoc
class _$WebhookCopyWithImpl<$Res>
    implements $WebhookCopyWith<$Res> {
  _$WebhookCopyWithImpl(this._self, this._then);

  final Webhook _self;
  final $Res Function(Webhook) _then;

/// Create a copy of Webhook
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? eventId = null,Object? targetUrl = null,Object? format = null,Object? restMethod = null,Object? headers = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDirty = null,}) {
  return _then(Webhook(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,targetUrl: null == targetUrl ? _self.targetUrl : targetUrl // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,restMethod: null == restMethod ? _self.restMethod : restMethod // ignore: cast_nullable_to_non_nullable
as String,headers: null == headers ? _self.headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Webhook].
extension WebhookPatterns on Webhook {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Webhook value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Webhook() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Webhook value)  $default,){
final _that = this;
switch (_that) {
case _Webhook():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Webhook value)?  $default,){
final _that = this;
switch (_that) {
case _Webhook() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String eventId,  String targetUrl,  String format,  String restMethod,  Map<String, String> headers,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDirty)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Webhook() when $default != null:
return $default(_that.id,_that.eventId,_that.targetUrl,_that.format,_that.restMethod,_that.headers,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDirty);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String eventId,  String targetUrl,  String format,  String restMethod,  Map<String, String> headers,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDirty)  $default,) {final _that = this;
switch (_that) {
case _Webhook():
return $default(_that.id,_that.eventId,_that.targetUrl,_that.format,_that.restMethod,_that.headers,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDirty);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String eventId,  String targetUrl,  String format,  String restMethod,  Map<String, String> headers,  bool isDeleted,  DateTime updatedAt,  DateTime createdAt,  DateTime? archivedAt,  bool isDirty)?  $default,) {final _that = this;
switch (_that) {
case _Webhook() when $default != null:
return $default(_that.id,_that.eventId,_that.targetUrl,_that.format,_that.restMethod,_that.headers,_that.isDeleted,_that.updatedAt,_that.createdAt,_that.archivedAt,_that.isDirty);case _:
  return null;

}
}

}

/// @nodoc


class _Webhook extends Webhook {
  const _Webhook({required this.id, required this.eventId, required this.targetUrl, required this.format, required this.restMethod,  Map<String, String> headers = const <String, String>{}, required this.isDeleted, required this.updatedAt, required this.createdAt, required this.archivedAt, this.isDirty = false}): _headers = headers,super._();
  

@override final  String id;
@override final  String eventId;
@override final  String targetUrl;
@override final  String format;
@override final  String restMethod;
 final  Map<String, String> _headers;
@override@JsonKey() Map<String, String> get headers {
  if (_headers is EqualUnmodifiableMapView) return _headers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_headers);
}

@override final  bool isDeleted;
@override final  DateTime updatedAt;
@override final  DateTime createdAt;
@override final  DateTime? archivedAt;
@override@JsonKey() final  bool isDirty;

/// Create a copy of Webhook
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WebhookCopyWith<_Webhook> get copyWith => __$WebhookCopyWithImpl<_Webhook>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Webhook&&(identical(other.id, id) || other.id == id)&&(identical(other.eventId, eventId) || other.eventId == eventId)&&(identical(other.targetUrl, targetUrl) || other.targetUrl == targetUrl)&&(identical(other.format, format) || other.format == format)&&(identical(other.restMethod, restMethod) || other.restMethod == restMethod)&&const DeepCollectionEquality().equals(other.headers, _headers)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,eventId,targetUrl,format,restMethod,const DeepCollectionEquality().hash(_headers),isDeleted,updatedAt,createdAt,archivedAt,isDirty);
}

@override
String toString() {
    return 'Webhook(id: $id, eventId: $eventId, targetUrl: $targetUrl, format: $format, restMethod: $restMethod, headers: $headers, isDeleted: $isDeleted, updatedAt: $updatedAt, createdAt: $createdAt, archivedAt: $archivedAt, isDirty: $isDirty)';
}


}

/// @nodoc
abstract mixin class _$WebhookCopyWith<$Res> implements $WebhookCopyWith<$Res> {
  factory _$WebhookCopyWith(_Webhook value, $Res Function(_Webhook) _then) = __$WebhookCopyWithImpl;
@override @useResult
$Res call({
 String id, String eventId, String targetUrl, String format, String restMethod, Map<String, String> headers, bool isDeleted, DateTime updatedAt, DateTime createdAt, DateTime? archivedAt, bool isDirty
});




}
/// @nodoc
class __$WebhookCopyWithImpl<$Res>
    implements _$WebhookCopyWith<$Res> {
  __$WebhookCopyWithImpl(this._self, this._then);

  final _Webhook _self;
  final $Res Function(_Webhook) _then;

/// Create a copy of Webhook
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? eventId = null,Object? targetUrl = null,Object? format = null,Object? restMethod = null,Object? headers = null,Object? isDeleted = null,Object? updatedAt = null,Object? createdAt = null,Object? archivedAt = freezed,Object? isDirty = null,}) {
  return _then(_Webhook(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,eventId: null == eventId ? _self.eventId : eventId // ignore: cast_nullable_to_non_nullable
as String,targetUrl: null == targetUrl ? _self.targetUrl : targetUrl // ignore: cast_nullable_to_non_nullable
as String,format: null == format ? _self.format : format // ignore: cast_nullable_to_non_nullable
as String,restMethod: null == restMethod ? _self.restMethod : restMethod // ignore: cast_nullable_to_non_nullable
as String,headers: null == headers ? _self._headers : headers // ignore: cast_nullable_to_non_nullable
as Map<String, String>,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
