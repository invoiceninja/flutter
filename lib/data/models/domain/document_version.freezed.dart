// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document_version.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DocumentVersion {

/// The activity that produced this version. Also the path segment for the
/// PDF download, and the `?activity_id=` the PDF route reads.
 String get activityId;/// The document's total *after* this event, so a delta against the
/// previous version is meaningful.
 Decimal get amount;/// Always UTC — built with [epochSecondsToUtc]. A local `DateTime` here
/// renders an ISO string with no `Z`, which `Formatter.date(showTime:
/// true)` then treats as UTC and localizes a second time.
 DateTime get createdAt;/// Server activity type, as a string (`'5'`). Drives the row's label via
/// `kActivityTypeLabelKeys` and its tone via `kActivityTones`.
 String get activityTypeId;/// Acting user, when one is resolvable against the local roster.
 String get userId;/// Set instead of [userId] when a portal contact caused the change — an
/// approval or rejection, which is the change users least expect.
 String get contactId;/// Server-initiated (a reminder, a scheduled send, auto-billing).
 bool get isSystem;
/// Create a copy of DocumentVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentVersionCopyWith<DocumentVersion> get copyWith => _$DocumentVersionCopyWithImpl<DocumentVersion>(this as DocumentVersion, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentVersion&&(identical(other.activityId, activityId) || other.activityId == activityId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.activityTypeId, activityTypeId) || other.activityTypeId == activityTypeId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.contactId, contactId) || other.contactId == contactId)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem));
}


@override
int get hashCode => Object.hash(runtimeType,activityId,amount,createdAt,activityTypeId,userId,contactId,isSystem);

@override
String toString() {
  return 'DocumentVersion(activityId: $activityId, amount: $amount, createdAt: $createdAt, activityTypeId: $activityTypeId, userId: $userId, contactId: $contactId, isSystem: $isSystem)';
}


}

/// @nodoc
abstract mixin class $DocumentVersionCopyWith<$Res>  {
  factory $DocumentVersionCopyWith(DocumentVersion value, $Res Function(DocumentVersion) _then) = _$DocumentVersionCopyWithImpl;
@useResult
$Res call({
 String activityId, Decimal amount, DateTime createdAt, String activityTypeId, String userId, String contactId, bool isSystem
});




}
/// @nodoc
class _$DocumentVersionCopyWithImpl<$Res>
    implements $DocumentVersionCopyWith<$Res> {
  _$DocumentVersionCopyWithImpl(this._self, this._then);

  final DocumentVersion _self;
  final $Res Function(DocumentVersion) _then;

/// Create a copy of DocumentVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? activityId = null,Object? amount = null,Object? createdAt = null,Object? activityTypeId = null,Object? userId = null,Object? contactId = null,Object? isSystem = null,}) {
  return _then(_self.copyWith(
activityId: null == activityId ? _self.activityId : activityId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,activityTypeId: null == activityTypeId ? _self.activityTypeId : activityTypeId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,contactId: null == contactId ? _self.contactId : contactId // ignore: cast_nullable_to_non_nullable
as String,isSystem: null == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentVersion].
extension DocumentVersionPatterns on DocumentVersion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentVersion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentVersion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentVersion value)  $default,){
final _that = this;
switch (_that) {
case _DocumentVersion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentVersion value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentVersion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String activityId,  Decimal amount,  DateTime createdAt,  String activityTypeId,  String userId,  String contactId,  bool isSystem)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentVersion() when $default != null:
return $default(_that.activityId,_that.amount,_that.createdAt,_that.activityTypeId,_that.userId,_that.contactId,_that.isSystem);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String activityId,  Decimal amount,  DateTime createdAt,  String activityTypeId,  String userId,  String contactId,  bool isSystem)  $default,) {final _that = this;
switch (_that) {
case _DocumentVersion():
return $default(_that.activityId,_that.amount,_that.createdAt,_that.activityTypeId,_that.userId,_that.contactId,_that.isSystem);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String activityId,  Decimal amount,  DateTime createdAt,  String activityTypeId,  String userId,  String contactId,  bool isSystem)?  $default,) {final _that = this;
switch (_that) {
case _DocumentVersion() when $default != null:
return $default(_that.activityId,_that.amount,_that.createdAt,_that.activityTypeId,_that.userId,_that.contactId,_that.isSystem);case _:
  return null;

}
}

}

/// @nodoc


class _DocumentVersion extends DocumentVersion {
  const _DocumentVersion({required this.activityId, required this.amount, required this.createdAt, this.activityTypeId = '', this.userId = '', this.contactId = '', this.isSystem = false}): super._();
  

/// The activity that produced this version. Also the path segment for the
/// PDF download, and the `?activity_id=` the PDF route reads.
@override final  String activityId;
/// The document's total *after* this event, so a delta against the
/// previous version is meaningful.
@override final  Decimal amount;
/// Always UTC — built with [epochSecondsToUtc]. A local `DateTime` here
/// renders an ISO string with no `Z`, which `Formatter.date(showTime:
/// true)` then treats as UTC and localizes a second time.
@override final  DateTime createdAt;
/// Server activity type, as a string (`'5'`). Drives the row's label via
/// `kActivityTypeLabelKeys` and its tone via `kActivityTones`.
@override@JsonKey() final  String activityTypeId;
/// Acting user, when one is resolvable against the local roster.
@override@JsonKey() final  String userId;
/// Set instead of [userId] when a portal contact caused the change — an
/// approval or rejection, which is the change users least expect.
@override@JsonKey() final  String contactId;
/// Server-initiated (a reminder, a scheduled send, auto-billing).
@override@JsonKey() final  bool isSystem;

/// Create a copy of DocumentVersion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentVersionCopyWith<_DocumentVersion> get copyWith => __$DocumentVersionCopyWithImpl<_DocumentVersion>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentVersion&&(identical(other.activityId, activityId) || other.activityId == activityId)&&(identical(other.amount, amount) || other.amount == amount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.activityTypeId, activityTypeId) || other.activityTypeId == activityTypeId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.contactId, contactId) || other.contactId == contactId)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem));
}


@override
int get hashCode => Object.hash(runtimeType,activityId,amount,createdAt,activityTypeId,userId,contactId,isSystem);

@override
String toString() {
  return 'DocumentVersion(activityId: $activityId, amount: $amount, createdAt: $createdAt, activityTypeId: $activityTypeId, userId: $userId, contactId: $contactId, isSystem: $isSystem)';
}


}

/// @nodoc
abstract mixin class _$DocumentVersionCopyWith<$Res> implements $DocumentVersionCopyWith<$Res> {
  factory _$DocumentVersionCopyWith(_DocumentVersion value, $Res Function(_DocumentVersion) _then) = __$DocumentVersionCopyWithImpl;
@override @useResult
$Res call({
 String activityId, Decimal amount, DateTime createdAt, String activityTypeId, String userId, String contactId, bool isSystem
});




}
/// @nodoc
class __$DocumentVersionCopyWithImpl<$Res>
    implements _$DocumentVersionCopyWith<$Res> {
  __$DocumentVersionCopyWithImpl(this._self, this._then);

  final _DocumentVersion _self;
  final $Res Function(_DocumentVersion) _then;

/// Create a copy of DocumentVersion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? activityId = null,Object? amount = null,Object? createdAt = null,Object? activityTypeId = null,Object? userId = null,Object? contactId = null,Object? isSystem = null,}) {
  return _then(_DocumentVersion(
activityId: null == activityId ? _self.activityId : activityId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount // ignore: cast_nullable_to_non_nullable
as Decimal,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,activityTypeId: null == activityTypeId ? _self.activityTypeId : activityTypeId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,contactId: null == contactId ? _self.contactId : contactId // ignore: cast_nullable_to_non_nullable
as String,isSystem: null == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
