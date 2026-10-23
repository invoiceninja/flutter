// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'email_history.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$EmailHistoryEvent {

 String get date; String get deliveryMessage; String get recipient; String get server; String get serverIp; String get status; String get bounceId;
/// Create a copy of EmailHistoryEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmailHistoryEventCopyWith<EmailHistoryEvent> get copyWith => _$EmailHistoryEventCopyWithImpl<EmailHistoryEvent>(this as EmailHistoryEvent, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EmailHistoryEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EmailHistoryEvent&&(identical(other.date, _this.date) || other.date == _this.date)&&(identical(other.deliveryMessage, _this.deliveryMessage) || other.deliveryMessage == _this.deliveryMessage)&&(identical(other.recipient, _this.recipient) || other.recipient == _this.recipient)&&(identical(other.server, _this.server) || other.server == _this.server)&&(identical(other.serverIp, _this.serverIp) || other.serverIp == _this.serverIp)&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.bounceId, _this.bounceId) || other.bounceId == _this.bounceId));
}


@override
int get hashCode {
  final _this = this as EmailHistoryEvent;
  return Object.hash(runtimeType,_this.date,_this.deliveryMessage,_this.recipient,_this.server,_this.serverIp,_this.status,_this.bounceId);
}

@override
String toString() {
  final _this = this as EmailHistoryEvent;
  return 'EmailHistoryEvent(date: ${_this.date}, deliveryMessage: ${_this.deliveryMessage}, recipient: ${_this.recipient}, server: ${_this.server}, serverIp: ${_this.serverIp}, status: ${_this.status}, bounceId: ${_this.bounceId})';
}


}

/// @nodoc
abstract mixin class $EmailHistoryEventCopyWith<$Res>  {
  factory $EmailHistoryEventCopyWith(EmailHistoryEvent value, $Res Function(EmailHistoryEvent) _then) = _$EmailHistoryEventCopyWithImpl;
@useResult
$Res call({
 String date, String deliveryMessage, String recipient, String server, String serverIp, String status, String bounceId
});




}
/// @nodoc
class _$EmailHistoryEventCopyWithImpl<$Res>
    implements $EmailHistoryEventCopyWith<$Res> {
  _$EmailHistoryEventCopyWithImpl(this._self, this._then);

  final EmailHistoryEvent _self;
  final $Res Function(EmailHistoryEvent) _then;

/// Create a copy of EmailHistoryEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? date = null,Object? deliveryMessage = null,Object? recipient = null,Object? server = null,Object? serverIp = null,Object? status = null,Object? bounceId = null,}) {
  return _then(EmailHistoryEvent(
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


/// Adds pattern-matching-related methods to [EmailHistoryEvent].
extension EmailHistoryEventPatterns on EmailHistoryEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EmailHistoryEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EmailHistoryEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EmailHistoryEvent value)  $default,){
final _that = this;
switch (_that) {
case _EmailHistoryEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EmailHistoryEvent value)?  $default,){
final _that = this;
switch (_that) {
case _EmailHistoryEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String date,  String deliveryMessage,  String recipient,  String server,  String serverIp,  String status,  String bounceId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EmailHistoryEvent() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String date,  String deliveryMessage,  String recipient,  String server,  String serverIp,  String status,  String bounceId)  $default,) {final _that = this;
switch (_that) {
case _EmailHistoryEvent():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String date,  String deliveryMessage,  String recipient,  String server,  String serverIp,  String status,  String bounceId)?  $default,) {final _that = this;
switch (_that) {
case _EmailHistoryEvent() when $default != null:
return $default(_that.date,_that.deliveryMessage,_that.recipient,_that.server,_that.serverIp,_that.status,_that.bounceId);case _:
  return null;

}
}

}

/// @nodoc


class _EmailHistoryEvent implements EmailHistoryEvent {
  const _EmailHistoryEvent({this.date = '', this.deliveryMessage = '', this.recipient = '', this.server = '', this.serverIp = '', this.status = '', this.bounceId = ''});
  

@override@JsonKey() final  String date;
@override@JsonKey() final  String deliveryMessage;
@override@JsonKey() final  String recipient;
@override@JsonKey() final  String server;
@override@JsonKey() final  String serverIp;
@override@JsonKey() final  String status;
@override@JsonKey() final  String bounceId;

/// Create a copy of EmailHistoryEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EmailHistoryEventCopyWith<_EmailHistoryEvent> get copyWith => __$EmailHistoryEventCopyWithImpl<_EmailHistoryEvent>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EmailHistoryEvent&&(identical(other.date, date) || other.date == date)&&(identical(other.deliveryMessage, deliveryMessage) || other.deliveryMessage == deliveryMessage)&&(identical(other.recipient, recipient) || other.recipient == recipient)&&(identical(other.server, server) || other.server == server)&&(identical(other.serverIp, serverIp) || other.serverIp == serverIp)&&(identical(other.status, status) || other.status == status)&&(identical(other.bounceId, bounceId) || other.bounceId == bounceId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,date,deliveryMessage,recipient,server,serverIp,status,bounceId);
}

@override
String toString() {
    return 'EmailHistoryEvent(date: $date, deliveryMessage: $deliveryMessage, recipient: $recipient, server: $server, serverIp: $serverIp, status: $status, bounceId: $bounceId)';
}


}

/// @nodoc
abstract mixin class _$EmailHistoryEventCopyWith<$Res> implements $EmailHistoryEventCopyWith<$Res> {
  factory _$EmailHistoryEventCopyWith(_EmailHistoryEvent value, $Res Function(_EmailHistoryEvent) _then) = __$EmailHistoryEventCopyWithImpl;
@override @useResult
$Res call({
 String date, String deliveryMessage, String recipient, String server, String serverIp, String status, String bounceId
});




}
/// @nodoc
class __$EmailHistoryEventCopyWithImpl<$Res>
    implements _$EmailHistoryEventCopyWith<$Res> {
  __$EmailHistoryEventCopyWithImpl(this._self, this._then);

  final _EmailHistoryEvent _self;
  final $Res Function(_EmailHistoryEvent) _then;

/// Create a copy of EmailHistoryEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? date = null,Object? deliveryMessage = null,Object? recipient = null,Object? server = null,Object? serverIp = null,Object? status = null,Object? bounceId = null,}) {
  return _then(_EmailHistoryEvent(
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
mixin _$EmailHistoryRecord {

 String get entity; String get entityId; String get subject; String get recipients; List<EmailHistoryEvent> get events;
/// Create a copy of EmailHistoryRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EmailHistoryRecordCopyWith<EmailHistoryRecord> get copyWith => _$EmailHistoryRecordCopyWithImpl<EmailHistoryRecord>(this as EmailHistoryRecord, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as EmailHistoryRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is EmailHistoryRecord&&(identical(other.entity, _this.entity) || other.entity == _this.entity)&&(identical(other.entityId, _this.entityId) || other.entityId == _this.entityId)&&(identical(other.subject, _this.subject) || other.subject == _this.subject)&&(identical(other.recipients, _this.recipients) || other.recipients == _this.recipients)&&const DeepCollectionEquality().equals(other.events, _this.events));
}


@override
int get hashCode {
  final _this = this as EmailHistoryRecord;
  return Object.hash(runtimeType,_this.entity,_this.entityId,_this.subject,_this.recipients,const DeepCollectionEquality().hash(_this.events));
}

@override
String toString() {
  final _this = this as EmailHistoryRecord;
  return 'EmailHistoryRecord(entity: ${_this.entity}, entityId: ${_this.entityId}, subject: ${_this.subject}, recipients: ${_this.recipients}, events: ${_this.events})';
}


}

/// @nodoc
abstract mixin class $EmailHistoryRecordCopyWith<$Res>  {
  factory $EmailHistoryRecordCopyWith(EmailHistoryRecord value, $Res Function(EmailHistoryRecord) _then) = _$EmailHistoryRecordCopyWithImpl;
@useResult
$Res call({
 String entity, String entityId, String subject, String recipients, List<EmailHistoryEvent> events
});




}
/// @nodoc
class _$EmailHistoryRecordCopyWithImpl<$Res>
    implements $EmailHistoryRecordCopyWith<$Res> {
  _$EmailHistoryRecordCopyWithImpl(this._self, this._then);

  final EmailHistoryRecord _self;
  final $Res Function(EmailHistoryRecord) _then;

/// Create a copy of EmailHistoryRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entity = null,Object? entityId = null,Object? subject = null,Object? recipients = null,Object? events = null,}) {
  return _then(EmailHistoryRecord(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as String,entityId: null == entityId ? _self.entityId : entityId // ignore: cast_nullable_to_non_nullable
as String,subject: null == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String,recipients: null == recipients ? _self.recipients : recipients // ignore: cast_nullable_to_non_nullable
as String,events: null == events ? _self.events : events // ignore: cast_nullable_to_non_nullable
as List<EmailHistoryEvent>,
  ));
}

}


/// Adds pattern-matching-related methods to [EmailHistoryRecord].
extension EmailHistoryRecordPatterns on EmailHistoryRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _EmailHistoryRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _EmailHistoryRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _EmailHistoryRecord value)  $default,){
final _that = this;
switch (_that) {
case _EmailHistoryRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _EmailHistoryRecord value)?  $default,){
final _that = this;
switch (_that) {
case _EmailHistoryRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String entity,  String entityId,  String subject,  String recipients,  List<EmailHistoryEvent> events)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _EmailHistoryRecord() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String entity,  String entityId,  String subject,  String recipients,  List<EmailHistoryEvent> events)  $default,) {final _that = this;
switch (_that) {
case _EmailHistoryRecord():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String entity,  String entityId,  String subject,  String recipients,  List<EmailHistoryEvent> events)?  $default,) {final _that = this;
switch (_that) {
case _EmailHistoryRecord() when $default != null:
return $default(_that.entity,_that.entityId,_that.subject,_that.recipients,_that.events);case _:
  return null;

}
}

}

/// @nodoc


class _EmailHistoryRecord implements EmailHistoryRecord {
  const _EmailHistoryRecord({this.entity = '', this.entityId = '', this.subject = '', this.recipients = '',  List<EmailHistoryEvent> events = const <EmailHistoryEvent>[]}): _events = events;
  

@override@JsonKey() final  String entity;
@override@JsonKey() final  String entityId;
@override@JsonKey() final  String subject;
@override@JsonKey() final  String recipients;
 final  List<EmailHistoryEvent> _events;
@override@JsonKey() List<EmailHistoryEvent> get events {
  if (_events is EqualUnmodifiableListView) return _events;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_events);
}


/// Create a copy of EmailHistoryRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EmailHistoryRecordCopyWith<_EmailHistoryRecord> get copyWith => __$EmailHistoryRecordCopyWithImpl<_EmailHistoryRecord>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _EmailHistoryRecord&&(identical(other.entity, entity) || other.entity == entity)&&(identical(other.entityId, entityId) || other.entityId == entityId)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.recipients, recipients) || other.recipients == recipients)&&const DeepCollectionEquality().equals(other.events, _events));
}


@override
int get hashCode {
    return Object.hash(runtimeType,entity,entityId,subject,recipients,const DeepCollectionEquality().hash(_events));
}

@override
String toString() {
    return 'EmailHistoryRecord(entity: $entity, entityId: $entityId, subject: $subject, recipients: $recipients, events: $events)';
}


}

/// @nodoc
abstract mixin class _$EmailHistoryRecordCopyWith<$Res> implements $EmailHistoryRecordCopyWith<$Res> {
  factory _$EmailHistoryRecordCopyWith(_EmailHistoryRecord value, $Res Function(_EmailHistoryRecord) _then) = __$EmailHistoryRecordCopyWithImpl;
@override @useResult
$Res call({
 String entity, String entityId, String subject, String recipients, List<EmailHistoryEvent> events
});




}
/// @nodoc
class __$EmailHistoryRecordCopyWithImpl<$Res>
    implements _$EmailHistoryRecordCopyWith<$Res> {
  __$EmailHistoryRecordCopyWithImpl(this._self, this._then);

  final _EmailHistoryRecord _self;
  final $Res Function(_EmailHistoryRecord) _then;

/// Create a copy of EmailHistoryRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entity = null,Object? entityId = null,Object? subject = null,Object? recipients = null,Object? events = null,}) {
  return _then(_EmailHistoryRecord(
entity: null == entity ? _self.entity : entity // ignore: cast_nullable_to_non_nullable
as String,entityId: null == entityId ? _self.entityId : entityId // ignore: cast_nullable_to_non_nullable
as String,subject: null == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String,recipients: null == recipients ? _self.recipients : recipients // ignore: cast_nullable_to_non_nullable
as String,events: null == events ? _self._events : events // ignore: cast_nullable_to_non_nullable
as List<EmailHistoryEvent>,
  ));
}


}

// dart format on
