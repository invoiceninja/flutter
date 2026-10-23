// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'email_history_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EmailHistoryEventApi {

 String get date;@JsonKey(name: 'delivery_message') String get deliveryMessage; String get recipient; String get server;@JsonKey(name: 'server_ip') String get serverIp; String get status;@JsonKey(name: 'bounce_id') String get bounceId;
/// Create a copy of EmailHistoryEventApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmailHistoryEventApiCopyWith<EmailHistoryEventApi> get copyWith => _$EmailHistoryEventApiCopyWithImpl<EmailHistoryEventApi>(this as EmailHistoryEventApi, _$identity);

  /// Serializes this EmailHistoryEventApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EmailHistoryEventApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EmailHistoryEventApi&&(identical(other.date, _this.date) || other.date == _this.date)&&(identical(other.deliveryMessage, _this.deliveryMessage) || other.deliveryMessage == _this.deliveryMessage)&&(identical(other.recipient, _this.recipient) || other.recipient == _this.recipient)&&(identical(other.server, _this.server) || other.server == _this.server)&&(identical(other.serverIp, _this.serverIp) || other.serverIp == _this.serverIp)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.bounceId, _this.bounceId) || other.bounceId == _this.bounceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EmailHistoryEventApi;
  return Object.hash(runtimeType,_this.date,_this.deliveryMessage,_this.recipient,_this.server,_this.serverIp,_this.status,_this.bounceId);
}

@override
String toString() {
  final _this = this as EmailHistoryEventApi;
  return 'EmailHistoryEventApi(date: ${_this.date}, deliveryMessage: ${_this.deliveryMessage}, recipient: ${_this.recipient}, server: ${_this.server}, serverIp: ${_this.serverIp}, status: ${_this.status}, bounceId: ${_this.bounceId})';
}


}

/// @nodoc
abstract mixin class $EmailHistoryEventApiCopyWith<$Res>  {
  factory $EmailHistoryEventApiCopyWith(EmailHistoryEventApi value, $Res Function(EmailHistoryEventApi) _then) = _$EmailHistoryEventApiCopyWithImpl;
@useResult
$Res call({
 String date,@JsonKey(name: 'delivery_message') String deliveryMessage, String recipient, String server,@JsonKey(name: 'server_ip') String serverIp, String status,@JsonKey(name: 'bounce_id') String bounceId
});




}
/// @nodoc
class _$EmailHistoryEventApiCopyWithImpl<$Res>
    implements $EmailHistoryEventApiCopyWith<$Res> {
  _$EmailHistoryEventApiCopyWithImpl(this._self, this._then);

  final EmailHistoryEventApi _self;
  final $Res Function(EmailHistoryEventApi) _then;

/// Create a copy of EmailHistoryEventApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? deliveryMessage = null,Object? recipient = null,Object? server = null,Object? serverIp = null,Object? status = null,Object? bounceId = null,}) {
  return _then(EmailHistoryEventApi(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,deliveryMessage: null == deliveryMessage ? _self.deliveryMessage : deliveryMessage // ignore: cast_nullable_to_non_nullable
as String,recipient: null == recipient ? _self.recipient : recipient // ignore: cast_nullable_to_non_nullable
as String,server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as String,serverIp: null == serverIp ? _self.serverIp : serverIp // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,bounceId: null == bounceId ? _self.bounceId : bounceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [EmailHistoryEventApi].
extension EmailHistoryEventApiPatterns on EmailHistoryEventApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EmailHistoryEventApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EmailHistoryEventApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EmailHistoryEventApi value)  $default,){
final _that = this;
switch (_that) {
case _EmailHistoryEventApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EmailHistoryEventApi value)?  $default,){
final _that = this;
switch (_that) {
case _EmailHistoryEventApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date, @JsonKey(name: 'delivery_message')  String deliveryMessage,  String recipient,  String server, @JsonKey(name: 'server_ip')  String serverIp,  String status, @JsonKey(name: 'bounce_id')  String bounceId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EmailHistoryEventApi() when $default != null:
return $default(_that.date,_that.deliveryMessage,_that.recipient,_that.server,_that.serverIp,_that.status,_that.bounceId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date, @JsonKey(name: 'delivery_message')  String deliveryMessage,  String recipient,  String server, @JsonKey(name: 'server_ip')  String serverIp,  String status, @JsonKey(name: 'bounce_id')  String bounceId)  $default,) {final _that = this;
switch (_that) {
case _EmailHistoryEventApi():
return $default(_that.date,_that.deliveryMessage,_that.recipient,_that.server,_that.serverIp,_that.status,_that.bounceId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date, @JsonKey(name: 'delivery_message')  String deliveryMessage,  String recipient,  String server, @JsonKey(name: 'server_ip')  String serverIp,  String status, @JsonKey(name: 'bounce_id')  String bounceId)?  $default,) {final _that = this;
switch (_that) {
case _EmailHistoryEventApi() when $default != null:
return $default(_that.date,_that.deliveryMessage,_that.recipient,_that.server,_that.serverIp,_that.status,_that.bounceId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EmailHistoryEventApi implements EmailHistoryEventApi {
  const _EmailHistoryEventApi({this.date = '', @JsonKey(name: 'delivery_message') this.deliveryMessage = '', this.recipient = '', this.server = '', @JsonKey(name: 'server_ip') this.serverIp = '', this.status = '', @JsonKey(name: 'bounce_id') this.bounceId = ''});
  factory _EmailHistoryEventApi.fromJson(Map<String, dynamic> json) => _$EmailHistoryEventApiFromJson(json);

@override@JsonKey() final  String date;
@override@JsonKey(name: 'delivery_message') final  String deliveryMessage;
@override@JsonKey() final  String recipient;
@override@JsonKey() final  String server;
@override@JsonKey(name: 'server_ip') final  String serverIp;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'bounce_id') final  String bounceId;

/// Create a copy of EmailHistoryEventApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EmailHistoryEventApiCopyWith<_EmailHistoryEventApi> get copyWith => __$EmailHistoryEventApiCopyWithImpl<_EmailHistoryEventApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EmailHistoryEventApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EmailHistoryEventApi&&(identical(other.date, date) || other.date == date)&&(identical(other.deliveryMessage, deliveryMessage) || other.deliveryMessage == deliveryMessage)&&(identical(other.recipient, recipient) || other.recipient == recipient)&&(identical(other.server, server) || other.server == server)&&(identical(other.serverIp, serverIp) || other.serverIp == serverIp)&&(identical(other.status, status) || other.status == status)&&(identical(other.bounceId, bounceId) || other.bounceId == bounceId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,date,deliveryMessage,recipient,server,serverIp,status,bounceId);
}

@override
String toString() {
    return 'EmailHistoryEventApi(date: $date, deliveryMessage: $deliveryMessage, recipient: $recipient, server: $server, serverIp: $serverIp, status: $status, bounceId: $bounceId)';
}


}

/// @nodoc
abstract mixin class _$EmailHistoryEventApiCopyWith<$Res> implements $EmailHistoryEventApiCopyWith<$Res> {
  factory _$EmailHistoryEventApiCopyWith(_EmailHistoryEventApi value, $Res Function(_EmailHistoryEventApi) _then) = __$EmailHistoryEventApiCopyWithImpl;
@override @useResult
$Res call({
 String date,@JsonKey(name: 'delivery_message') String deliveryMessage, String recipient, String server,@JsonKey(name: 'server_ip') String serverIp, String status,@JsonKey(name: 'bounce_id') String bounceId
});




}
/// @nodoc
class __$EmailHistoryEventApiCopyWithImpl<$Res>
    implements _$EmailHistoryEventApiCopyWith<$Res> {
  __$EmailHistoryEventApiCopyWithImpl(this._self, this._then);

  final _EmailHistoryEventApi _self;
  final $Res Function(_EmailHistoryEventApi) _then;

/// Create a copy of EmailHistoryEventApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? deliveryMessage = null,Object? recipient = null,Object? server = null,Object? serverIp = null,Object? status = null,Object? bounceId = null,}) {
  return _then(_EmailHistoryEventApi(
date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as String,deliveryMessage: null == deliveryMessage ? _self.deliveryMessage : deliveryMessage // ignore: cast_nullable_to_non_nullable
as String,recipient: null == recipient ? _self.recipient : recipient // ignore: cast_nullable_to_non_nullable
as String,server: null == server ? _self.server : server // ignore: cast_nullable_to_non_nullable
as String,serverIp: null == serverIp ? _self.serverIp : serverIp // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,bounceId: null == bounceId ? _self.bounceId : bounceId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$EmailHistoryRecordApi {

 String get entity;@JsonKey(name: 'entity_id') String get entityId; String get subject; String get recipients; List<EmailHistoryEventApi> get events;
/// Create a copy of EmailHistoryRecordApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmailHistoryRecordApiCopyWith<EmailHistoryRecordApi> get copyWith => _$EmailHistoryRecordApiCopyWithImpl<EmailHistoryRecordApi>(this as EmailHistoryRecordApi, _$identity);

  /// Serializes this EmailHistoryRecordApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as EmailHistoryRecordApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EmailHistoryRecordApi&&(identical(other.entity, _this.entity) || other.entity == _this.entity)&&(identical(other.entityId, _this.entityId) || other.entityId == _this.entityId)&&(identical(other.subject, _this.subject) || other.subject == _this.subject)&&(identical(other.recipients, _this.recipients) || other.recipients == _this.recipients)&&const DeepCollectionEquality().equals(other.events, _this.events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as EmailHistoryRecordApi;
  return Object.hash(runtimeType,_this.entity,_this.entityId,_this.subject,_this.recipients,const DeepCollectionEquality().hash(_this.events));
}

@override
String toString() {
  final _this = this as EmailHistoryRecordApi;
  return 'EmailHistoryRecordApi(entity: ${_this.entity}, entityId: ${_this.entityId}, subject: ${_this.subject}, recipients: ${_this.recipients}, events: ${_this.events})';
}


}

/// @nodoc
abstract mixin class $EmailHistoryRecordApiCopyWith<$Res>  {
  factory $EmailHistoryRecordApiCopyWith(EmailHistoryRecordApi value, $Res Function(EmailHistoryRecordApi) _then) = _$EmailHistoryRecordApiCopyWithImpl;
@useResult
$Res call({
 String entity,@JsonKey(name: 'entity_id') String entityId, String subject, String recipients, List<EmailHistoryEventApi> events
});




}
/// @nodoc
class _$EmailHistoryRecordApiCopyWithImpl<$Res>
    implements $EmailHistoryRecordApiCopyWith<$Res> {
  _$EmailHistoryRecordApiCopyWithImpl(this._self, this._then);

  final EmailHistoryRecordApi _self;
  final $Res Function(EmailHistoryRecordApi) _then;

/// Create a copy of EmailHistoryRecordApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entity = null,Object? entityId = null,Object? subject = null,Object? recipients = null,Object? events = null,}) {
  return _then(EmailHistoryRecordApi(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as String,entityId: null == entityId ? _self.entityId : entityId // ignore: cast_nullable_to_non_nullable
as String,subject: null == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String,recipients: null == recipients ? _self.recipients : recipients // ignore: cast_nullable_to_non_nullable
as String,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<EmailHistoryEventApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [EmailHistoryRecordApi].
extension EmailHistoryRecordApiPatterns on EmailHistoryRecordApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EmailHistoryRecordApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EmailHistoryRecordApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EmailHistoryRecordApi value)  $default,){
final _that = this;
switch (_that) {
case _EmailHistoryRecordApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EmailHistoryRecordApi value)?  $default,){
final _that = this;
switch (_that) {
case _EmailHistoryRecordApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String entity, @JsonKey(name: 'entity_id')  String entityId,  String subject,  String recipients,  List<EmailHistoryEventApi> events)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EmailHistoryRecordApi() when $default != null:
return $default(_that.entity,_that.entityId,_that.subject,_that.recipients,_that.events);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String entity, @JsonKey(name: 'entity_id')  String entityId,  String subject,  String recipients,  List<EmailHistoryEventApi> events)  $default,) {final _that = this;
switch (_that) {
case _EmailHistoryRecordApi():
return $default(_that.entity,_that.entityId,_that.subject,_that.recipients,_that.events);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String entity, @JsonKey(name: 'entity_id')  String entityId,  String subject,  String recipients,  List<EmailHistoryEventApi> events)?  $default,) {final _that = this;
switch (_that) {
case _EmailHistoryRecordApi() when $default != null:
return $default(_that.entity,_that.entityId,_that.subject,_that.recipients,_that.events);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _EmailHistoryRecordApi implements EmailHistoryRecordApi {
  const _EmailHistoryRecordApi({this.entity = '', @JsonKey(name: 'entity_id') this.entityId = '', this.subject = '', this.recipients = '',  List<EmailHistoryEventApi> events = const []}): _events = events;
  factory _EmailHistoryRecordApi.fromJson(Map<String, dynamic> json) => _$EmailHistoryRecordApiFromJson(json);

@override@JsonKey() final  String entity;
@override@JsonKey(name: 'entity_id') final  String entityId;
@override@JsonKey() final  String subject;
@override@JsonKey() final  String recipients;
 final  List<EmailHistoryEventApi> _events;
@override@JsonKey() List<EmailHistoryEventApi> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}


/// Create a copy of EmailHistoryRecordApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EmailHistoryRecordApiCopyWith<_EmailHistoryRecordApi> get copyWith => __$EmailHistoryRecordApiCopyWithImpl<_EmailHistoryRecordApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$EmailHistoryRecordApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EmailHistoryRecordApi&&(identical(other.entity, entity) || other.entity == entity)&&(identical(other.entityId, entityId) || other.entityId == entityId)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.recipients, recipients) || other.recipients == recipients)&&const DeepCollectionEquality().equals(other.events, _events));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,entity,entityId,subject,recipients,const DeepCollectionEquality().hash(_events));
}

@override
String toString() {
    return 'EmailHistoryRecordApi(entity: $entity, entityId: $entityId, subject: $subject, recipients: $recipients, events: $events)';
}


}

/// @nodoc
abstract mixin class _$EmailHistoryRecordApiCopyWith<$Res> implements $EmailHistoryRecordApiCopyWith<$Res> {
  factory _$EmailHistoryRecordApiCopyWith(_EmailHistoryRecordApi value, $Res Function(_EmailHistoryRecordApi) _then) = __$EmailHistoryRecordApiCopyWithImpl;
@override @useResult
$Res call({
 String entity,@JsonKey(name: 'entity_id') String entityId, String subject, String recipients, List<EmailHistoryEventApi> events
});




}
/// @nodoc
class __$EmailHistoryRecordApiCopyWithImpl<$Res>
    implements _$EmailHistoryRecordApiCopyWith<$Res> {
  __$EmailHistoryRecordApiCopyWithImpl(this._self, this._then);

  final _EmailHistoryRecordApi _self;
  final $Res Function(_EmailHistoryRecordApi) _then;

/// Create a copy of EmailHistoryRecordApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entity = null,Object? entityId = null,Object? subject = null,Object? recipients = null,Object? events = null,}) {
  return _then(_EmailHistoryRecordApi(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as String,entityId: null == entityId ? _self.entityId : entityId // ignore: cast_nullable_to_non_nullable
as String,subject: null == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String,recipients: null == recipients ? _self.recipients : recipients // ignore: cast_nullable_to_non_nullable
as String,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<EmailHistoryEventApi>,
  ));
}


}

// dart format on
