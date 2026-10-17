// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DocumentRecord {

 String get id; String get name; String get type; String get hash; int get size; int get width; int get height; bool get isPublic; String get userId; String get assignedUserId; DateTime get createdAt; DateTime get updatedAt; DateTime? get archivedAt; bool get isDeleted; bool get isDirty; EntityType? get parentType; String? get parentId;
/// Create a copy of DocumentRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentRecordCopyWith<DocumentRecord> get copyWith => _$DocumentRecordCopyWithImpl<DocumentRecord>(this as DocumentRecord, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.size, size) || other.size == size)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.isPublic, isPublic) || other.isPublic == isPublic)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.parentType, parentType) || other.parentType == parentType)&&(identical(other.parentId, parentId) || other.parentId == parentId));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,type,hash,size,width,height,isPublic,userId,assignedUserId,createdAt,updatedAt,archivedAt,isDeleted,isDirty,parentType,parentId);

@override
String toString() {
  return 'DocumentRecord(id: $id, name: $name, type: $type, hash: $hash, size: $size, width: $width, height: $height, isPublic: $isPublic, userId: $userId, assignedUserId: $assignedUserId, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, isDirty: $isDirty, parentType: $parentType, parentId: $parentId)';
}


}

/// @nodoc
abstract mixin class $DocumentRecordCopyWith<$Res>  {
  factory $DocumentRecordCopyWith(DocumentRecord value, $Res Function(DocumentRecord) _then) = _$DocumentRecordCopyWithImpl;
@useResult
$Res call({
 String id, String name, String type, String hash, int size, int width, int height, bool isPublic, String userId, String assignedUserId, DateTime createdAt, DateTime updatedAt, DateTime? archivedAt, bool isDeleted, bool isDirty, EntityType? parentType, String? parentId
});




}
/// @nodoc
class _$DocumentRecordCopyWithImpl<$Res>
    implements $DocumentRecordCopyWith<$Res> {
  _$DocumentRecordCopyWithImpl(this._self, this._then);

  final DocumentRecord _self;
  final $Res Function(DocumentRecord) _then;

/// Create a copy of DocumentRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? hash = null,Object? size = null,Object? width = null,Object? height = null,Object? isPublic = null,Object? userId = null,Object? assignedUserId = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? isDirty = null,Object? parentType = freezed,Object? parentId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,isPublic: null == isPublic ? _self.isPublic : isPublic // ignore: cast_nullable_to_non_nullable
as bool,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,parentType: freezed == parentType ? _self.parentType : parentType // ignore: cast_nullable_to_non_nullable
as EntityType?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentRecord].
extension DocumentRecordPatterns on DocumentRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentRecord value)  $default,){
final _that = this;
switch (_that) {
case _DocumentRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentRecord value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String hash,  int size,  int width,  int height,  bool isPublic,  String userId,  String assignedUserId,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty,  EntityType? parentType,  String? parentId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentRecord() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.hash,_that.size,_that.width,_that.height,_that.isPublic,_that.userId,_that.assignedUserId,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isDirty,_that.parentType,_that.parentId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String type,  String hash,  int size,  int width,  int height,  bool isPublic,  String userId,  String assignedUserId,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty,  EntityType? parentType,  String? parentId)  $default,) {final _that = this;
switch (_that) {
case _DocumentRecord():
return $default(_that.id,_that.name,_that.type,_that.hash,_that.size,_that.width,_that.height,_that.isPublic,_that.userId,_that.assignedUserId,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isDirty,_that.parentType,_that.parentId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String type,  String hash,  int size,  int width,  int height,  bool isPublic,  String userId,  String assignedUserId,  DateTime createdAt,  DateTime updatedAt,  DateTime? archivedAt,  bool isDeleted,  bool isDirty,  EntityType? parentType,  String? parentId)?  $default,) {final _that = this;
switch (_that) {
case _DocumentRecord() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.hash,_that.size,_that.width,_that.height,_that.isPublic,_that.userId,_that.assignedUserId,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isDirty,_that.parentType,_that.parentId);case _:
  return null;

}
}

}

/// @nodoc


class _DocumentRecord extends DocumentRecord {
  const _DocumentRecord({required this.id, required this.name, required this.type, required this.hash, required this.size, required this.width, required this.height, required this.isPublic, required this.userId, required this.assignedUserId, required this.createdAt, required this.updatedAt, required this.archivedAt, this.isDeleted = false, this.isDirty = false, this.parentType, this.parentId}): super._();
  

@override final  String id;
@override final  String name;
@override final  String type;
@override final  String hash;
@override final  int size;
@override final  int width;
@override final  int height;
@override final  bool isPublic;
@override final  String userId;
@override final  String assignedUserId;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime? archivedAt;
@override@JsonKey() final  bool isDeleted;
@override@JsonKey() final  bool isDirty;
@override final  EntityType? parentType;
@override final  String? parentId;

/// Create a copy of DocumentRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentRecordCopyWith<_DocumentRecord> get copyWith => __$DocumentRecordCopyWithImpl<_DocumentRecord>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentRecord&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.size, size) || other.size == size)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.isPublic, isPublic) || other.isPublic == isPublic)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isDirty, isDirty) || other.isDirty == isDirty)&&(identical(other.parentType, parentType) || other.parentType == parentType)&&(identical(other.parentId, parentId) || other.parentId == parentId));
}


@override
int get hashCode => Object.hash(runtimeType,id,name,type,hash,size,width,height,isPublic,userId,assignedUserId,createdAt,updatedAt,archivedAt,isDeleted,isDirty,parentType,parentId);

@override
String toString() {
  return 'DocumentRecord(id: $id, name: $name, type: $type, hash: $hash, size: $size, width: $width, height: $height, isPublic: $isPublic, userId: $userId, assignedUserId: $assignedUserId, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, isDirty: $isDirty, parentType: $parentType, parentId: $parentId)';
}


}

/// @nodoc
abstract mixin class _$DocumentRecordCopyWith<$Res> implements $DocumentRecordCopyWith<$Res> {
  factory _$DocumentRecordCopyWith(_DocumentRecord value, $Res Function(_DocumentRecord) _then) = __$DocumentRecordCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String type, String hash, int size, int width, int height, bool isPublic, String userId, String assignedUserId, DateTime createdAt, DateTime updatedAt, DateTime? archivedAt, bool isDeleted, bool isDirty, EntityType? parentType, String? parentId
});




}
/// @nodoc
class __$DocumentRecordCopyWithImpl<$Res>
    implements _$DocumentRecordCopyWith<$Res> {
  __$DocumentRecordCopyWithImpl(this._self, this._then);

  final _DocumentRecord _self;
  final $Res Function(_DocumentRecord) _then;

/// Create a copy of DocumentRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? hash = null,Object? size = null,Object? width = null,Object? height = null,Object? isPublic = null,Object? userId = null,Object? assignedUserId = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = freezed,Object? isDeleted = null,Object? isDirty = null,Object? parentType = freezed,Object? parentId = freezed,}) {
  return _then(_DocumentRecord(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,isPublic: null == isPublic ? _self.isPublic : isPublic // ignore: cast_nullable_to_non_nullable
as bool,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,archivedAt: freezed == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isDirty: null == isDirty ? _self.isDirty : isDirty // ignore: cast_nullable_to_non_nullable
as bool,parentType: freezed == parentType ? _self.parentType : parentType // ignore: cast_nullable_to_non_nullable
as EntityType?,parentId: freezed == parentId ? _self.parentId : parentId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
