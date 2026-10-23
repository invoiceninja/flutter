// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'invitation.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Invitation {

 String get id; String get key; String get link; String get clientContactId; String get vendorContactId; String get sentDate; String get viewedDate; String get openedDate; String get emailStatus; String get emailError; String get messageId;
/// Create a copy of Invitation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InvitationCopyWith<Invitation> get copyWith => _$InvitationCopyWithImpl<Invitation>(this as Invitation, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Invitation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Invitation&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.key, _this.key) || other.key == _this.key)&&(identical(other.link, _this.link) || other.link == _this.link)&&(identical(other.clientContactId, _this.clientContactId) || other.clientContactId == _this.clientContactId)&&(identical(other.vendorContactId, _this.vendorContactId) || other.vendorContactId == _this.vendorContactId)&&(identical(other.sentDate, _this.sentDate) || other.sentDate == _this.sentDate)&&(identical(other.viewedDate, _this.viewedDate) || other.viewedDate == _this.viewedDate)&&(identical(other.openedDate, _this.openedDate) || other.openedDate == _this.openedDate)&&(identical(other.emailStatus, _this.emailStatus) || other.emailStatus == _this.emailStatus)&&(identical(other.emailError, _this.emailError) || other.emailError == _this.emailError)&&(identical(other.messageId, _this.messageId) || other.messageId == _this.messageId));
}


@override
int get hashCode {
  final _this = this as Invitation;
  return Object.hash(runtimeType,_this.id,_this.key,_this.link,_this.clientContactId,_this.vendorContactId,_this.sentDate,_this.viewedDate,_this.openedDate,_this.emailStatus,_this.emailError,_this.messageId);
}

@override
String toString() {
  final _this = this as Invitation;
  return 'Invitation(id: ${_this.id}, key: ${_this.key}, link: ${_this.link}, clientContactId: ${_this.clientContactId}, vendorContactId: ${_this.vendorContactId}, sentDate: ${_this.sentDate}, viewedDate: ${_this.viewedDate}, openedDate: ${_this.openedDate}, emailStatus: ${_this.emailStatus}, emailError: ${_this.emailError}, messageId: ${_this.messageId})';
}


}

/// @nodoc
abstract mixin class $InvitationCopyWith<$Res>  {
  factory $InvitationCopyWith(Invitation value, $Res Function(Invitation) _then) = _$InvitationCopyWithImpl;
@useResult
$Res call({
 String id, String key, String link, String clientContactId, String vendorContactId, String sentDate, String viewedDate, String openedDate, String emailStatus, String emailError, String messageId
});




}
/// @nodoc
class _$InvitationCopyWithImpl<$Res>
    implements $InvitationCopyWith<$Res> {
  _$InvitationCopyWithImpl(this._self, this._then);

  final Invitation _self;
  final $Res Function(Invitation) _then;

/// Create a copy of Invitation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? key = null,Object? link = null,Object? clientContactId = null,Object? vendorContactId = null,Object? sentDate = null,Object? viewedDate = null,Object? openedDate = null,Object? emailStatus = null,Object? emailError = null,Object? messageId = null,}) {
  return _then(Invitation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,clientContactId: null == clientContactId ? _self.clientContactId : clientContactId // ignore: cast_nullable_to_non_nullable
as String,vendorContactId: null == vendorContactId ? _self.vendorContactId : vendorContactId // ignore: cast_nullable_to_non_nullable
as String,sentDate: null == sentDate ? _self.sentDate : sentDate // ignore: cast_nullable_to_non_nullable
as String,viewedDate: null == viewedDate ? _self.viewedDate : viewedDate // ignore: cast_nullable_to_non_nullable
as String,openedDate: null == openedDate ? _self.openedDate : openedDate // ignore: cast_nullable_to_non_nullable
as String,emailStatus: null == emailStatus ? _self.emailStatus : emailStatus // ignore: cast_nullable_to_non_nullable
as String,emailError: null == emailError ? _self.emailError : emailError // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Invitation].
extension InvitationPatterns on Invitation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Invitation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Invitation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Invitation value)  $default,){
final _that = this;
switch (_that) {
case _Invitation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Invitation value)?  $default,){
final _that = this;
switch (_that) {
case _Invitation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String key,  String link,  String clientContactId,  String vendorContactId,  String sentDate,  String viewedDate,  String openedDate,  String emailStatus,  String emailError,  String messageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Invitation() when $default != null:
return $default(_that.id,_that.key,_that.link,_that.clientContactId,_that.vendorContactId,_that.sentDate,_that.viewedDate,_that.openedDate,_that.emailStatus,_that.emailError,_that.messageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String key,  String link,  String clientContactId,  String vendorContactId,  String sentDate,  String viewedDate,  String openedDate,  String emailStatus,  String emailError,  String messageId)  $default,) {final _that = this;
switch (_that) {
case _Invitation():
return $default(_that.id,_that.key,_that.link,_that.clientContactId,_that.vendorContactId,_that.sentDate,_that.viewedDate,_that.openedDate,_that.emailStatus,_that.emailError,_that.messageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String key,  String link,  String clientContactId,  String vendorContactId,  String sentDate,  String viewedDate,  String openedDate,  String emailStatus,  String emailError,  String messageId)?  $default,) {final _that = this;
switch (_that) {
case _Invitation() when $default != null:
return $default(_that.id,_that.key,_that.link,_that.clientContactId,_that.vendorContactId,_that.sentDate,_that.viewedDate,_that.openedDate,_that.emailStatus,_that.emailError,_that.messageId);case _:
  return null;

}
}

}

/// @nodoc


class _Invitation implements Invitation {
  const _Invitation({this.id = '', this.key = '', this.link = '', this.clientContactId = '', this.vendorContactId = '', this.sentDate = '', this.viewedDate = '', this.openedDate = '', this.emailStatus = '', this.emailError = '', this.messageId = ''});
  

@override@JsonKey() final  String id;
@override@JsonKey() final  String key;
@override@JsonKey() final  String link;
@override@JsonKey() final  String clientContactId;
@override@JsonKey() final  String vendorContactId;
@override@JsonKey() final  String sentDate;
@override@JsonKey() final  String viewedDate;
@override@JsonKey() final  String openedDate;
@override@JsonKey() final  String emailStatus;
@override@JsonKey() final  String emailError;
@override@JsonKey() final  String messageId;

/// Create a copy of Invitation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InvitationCopyWith<_Invitation> get copyWith => __$InvitationCopyWithImpl<_Invitation>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Invitation&&(identical(other.id, id) || other.id == id)&&(identical(other.key, key) || other.key == key)&&(identical(other.link, link) || other.link == link)&&(identical(other.clientContactId, clientContactId) || other.clientContactId == clientContactId)&&(identical(other.vendorContactId, vendorContactId) || other.vendorContactId == vendorContactId)&&(identical(other.sentDate, sentDate) || other.sentDate == sentDate)&&(identical(other.viewedDate, viewedDate) || other.viewedDate == viewedDate)&&(identical(other.openedDate, openedDate) || other.openedDate == openedDate)&&(identical(other.emailStatus, emailStatus) || other.emailStatus == emailStatus)&&(identical(other.emailError, emailError) || other.emailError == emailError)&&(identical(other.messageId, messageId) || other.messageId == messageId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,key,link,clientContactId,vendorContactId,sentDate,viewedDate,openedDate,emailStatus,emailError,messageId);
}

@override
String toString() {
    return 'Invitation(id: $id, key: $key, link: $link, clientContactId: $clientContactId, vendorContactId: $vendorContactId, sentDate: $sentDate, viewedDate: $viewedDate, openedDate: $openedDate, emailStatus: $emailStatus, emailError: $emailError, messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class _$InvitationCopyWith<$Res> implements $InvitationCopyWith<$Res> {
  factory _$InvitationCopyWith(_Invitation value, $Res Function(_Invitation) _then) = __$InvitationCopyWithImpl;
@override @useResult
$Res call({
 String id, String key, String link, String clientContactId, String vendorContactId, String sentDate, String viewedDate, String openedDate, String emailStatus, String emailError, String messageId
});




}
/// @nodoc
class __$InvitationCopyWithImpl<$Res>
    implements _$InvitationCopyWith<$Res> {
  __$InvitationCopyWithImpl(this._self, this._then);

  final _Invitation _self;
  final $Res Function(_Invitation) _then;

/// Create a copy of Invitation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? key = null,Object? link = null,Object? clientContactId = null,Object? vendorContactId = null,Object? sentDate = null,Object? viewedDate = null,Object? openedDate = null,Object? emailStatus = null,Object? emailError = null,Object? messageId = null,}) {
  return _then(_Invitation(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as String,link: null == link ? _self.link : link // ignore: cast_nullable_to_non_nullable
as String,clientContactId: null == clientContactId ? _self.clientContactId : clientContactId // ignore: cast_nullable_to_non_nullable
as String,vendorContactId: null == vendorContactId ? _self.vendorContactId : vendorContactId // ignore: cast_nullable_to_non_nullable
as String,sentDate: null == sentDate ? _self.sentDate : sentDate // ignore: cast_nullable_to_non_nullable
as String,viewedDate: null == viewedDate ? _self.viewedDate : viewedDate // ignore: cast_nullable_to_non_nullable
as String,openedDate: null == openedDate ? _self.openedDate : openedDate // ignore: cast_nullable_to_non_nullable
as String,emailStatus: null == emailStatus ? _self.emailStatus : emailStatus // ignore: cast_nullable_to_non_nullable
as String,emailError: null == emailError ? _self.emailError : emailError // ignore: cast_nullable_to_non_nullable
as String,messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
