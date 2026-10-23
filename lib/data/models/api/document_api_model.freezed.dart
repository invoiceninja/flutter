// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DocumentApi {

 String get id; String get name; String get hash; String get type; String get url; int get size; int get width; int get height;@JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty) String get userId;@JsonKey(name: 'assigned_user_id', fromJson: jsonScalarToStringOrEmpty) String get assignedUserId;@JsonKey(name: 'is_default') bool get isDefault;@JsonKey(name: 'is_public') bool get isPublic;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'documentable_type', fromJson: jsonScalarToString) String? get documentableType;@JsonKey(name: 'documentable_id', fromJson: jsonScalarToString) String? get documentableId;
/// Create a copy of DocumentApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentApiCopyWith<DocumentApi> get copyWith => _$DocumentApiCopyWithImpl<DocumentApi>(this as DocumentApi, _$identity);

  /// Serializes this DocumentApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DocumentApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentApi&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.hash, _this.hash) || other.hash == _this.hash)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.url, _this.url) || other.url == _this.url)&&(identical(other.size, _this.size) || other.size == _this.size)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.assignedUserId, _this.assignedUserId) || other.assignedUserId == _this.assignedUserId)&&(identical(other.isDefault, _this.isDefault) || other.isDefault == _this.isDefault)&&(identical(other.isPublic, _this.isPublic) || other.isPublic == _this.isPublic)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt)&&(identical(other.documentableType, _this.documentableType) || other.documentableType == _this.documentableType)&&(identical(other.documentableId, _this.documentableId) || other.documentableId == _this.documentableId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DocumentApi;
  return Object.hash(runtimeType,_this.id,_this.name,_this.hash,_this.type,_this.url,_this.size,_this.width,_this.height,_this.userId,_this.assignedUserId,_this.isDefault,_this.isPublic,_this.createdAt,_this.updatedAt,_this.archivedAt,_this.documentableType,_this.documentableId);
}

@override
String toString() {
  final _this = this as DocumentApi;
  return 'DocumentApi(id: ${_this.id}, name: ${_this.name}, hash: ${_this.hash}, type: ${_this.type}, url: ${_this.url}, size: ${_this.size}, width: ${_this.width}, height: ${_this.height}, userId: ${_this.userId}, assignedUserId: ${_this.assignedUserId}, isDefault: ${_this.isDefault}, isPublic: ${_this.isPublic}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, archivedAt: ${_this.archivedAt}, documentableType: ${_this.documentableType}, documentableId: ${_this.documentableId})';
}


}

/// @nodoc
abstract mixin class $DocumentApiCopyWith<$Res>  {
  factory $DocumentApiCopyWith(DocumentApi value, $Res Function(DocumentApi) _then) = _$DocumentApiCopyWithImpl;
@useResult
$Res call({
 String id, String name, String hash, String type, String url, int size, int width, int height,@JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty) String userId,@JsonKey(name: 'assigned_user_id', fromJson: jsonScalarToStringOrEmpty) String assignedUserId,@JsonKey(name: 'is_default') bool isDefault,@JsonKey(name: 'is_public') bool isPublic,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'documentable_type', fromJson: jsonScalarToString) String? documentableType,@JsonKey(name: 'documentable_id', fromJson: jsonScalarToString) String? documentableId
});




}
/// @nodoc
class _$DocumentApiCopyWithImpl<$Res>
    implements $DocumentApiCopyWith<$Res> {
  _$DocumentApiCopyWithImpl(this._self, this._then);

  final DocumentApi _self;
  final $Res Function(DocumentApi) _then;

/// Create a copy of DocumentApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? hash = null,Object? type = null,Object? url = null,Object? size = null,Object? width = null,Object? height = null,Object? userId = null,Object? assignedUserId = null,Object? isDefault = null,Object? isPublic = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? documentableType = freezed,Object? documentableId = freezed,}) {
  return _then(DocumentApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,isPublic: null == isPublic ? _self.isPublic : isPublic // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,documentableType: freezed == documentableType ? _self.documentableType : documentableType // ignore: cast_nullable_to_non_nullable
as String?,documentableId: freezed == documentableId ? _self.documentableId : documentableId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentApi].
extension DocumentApiPatterns on DocumentApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentApi value)  $default,){
final _that = this;
switch (_that) {
case _DocumentApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentApi value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String hash,  String type,  String url,  int size,  int width,  int height, @JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty)  String userId, @JsonKey(name: 'assigned_user_id', fromJson: jsonScalarToStringOrEmpty)  String assignedUserId, @JsonKey(name: 'is_default')  bool isDefault, @JsonKey(name: 'is_public')  bool isPublic, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'documentable_type', fromJson: jsonScalarToString)  String? documentableType, @JsonKey(name: 'documentable_id', fromJson: jsonScalarToString)  String? documentableId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentApi() when $default != null:
return $default(_that.id,_that.name,_that.hash,_that.type,_that.url,_that.size,_that.width,_that.height,_that.userId,_that.assignedUserId,_that.isDefault,_that.isPublic,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.documentableType,_that.documentableId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String hash,  String type,  String url,  int size,  int width,  int height, @JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty)  String userId, @JsonKey(name: 'assigned_user_id', fromJson: jsonScalarToStringOrEmpty)  String assignedUserId, @JsonKey(name: 'is_default')  bool isDefault, @JsonKey(name: 'is_public')  bool isPublic, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'documentable_type', fromJson: jsonScalarToString)  String? documentableType, @JsonKey(name: 'documentable_id', fromJson: jsonScalarToString)  String? documentableId)  $default,) {final _that = this;
switch (_that) {
case _DocumentApi():
return $default(_that.id,_that.name,_that.hash,_that.type,_that.url,_that.size,_that.width,_that.height,_that.userId,_that.assignedUserId,_that.isDefault,_that.isPublic,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.documentableType,_that.documentableId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String hash,  String type,  String url,  int size,  int width,  int height, @JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty)  String userId, @JsonKey(name: 'assigned_user_id', fromJson: jsonScalarToStringOrEmpty)  String assignedUserId, @JsonKey(name: 'is_default')  bool isDefault, @JsonKey(name: 'is_public')  bool isPublic, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'documentable_type', fromJson: jsonScalarToString)  String? documentableType, @JsonKey(name: 'documentable_id', fromJson: jsonScalarToString)  String? documentableId)?  $default,) {final _that = this;
switch (_that) {
case _DocumentApi() when $default != null:
return $default(_that.id,_that.name,_that.hash,_that.type,_that.url,_that.size,_that.width,_that.height,_that.userId,_that.assignedUserId,_that.isDefault,_that.isPublic,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.documentableType,_that.documentableId);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(includeIfNull: false)
class _DocumentApi implements DocumentApi {
  const _DocumentApi({this.id = '', this.name = '', this.hash = '', this.type = '', this.url = '', this.size = 0, this.width = 0, this.height = 0, @JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty) this.userId = '', @JsonKey(name: 'assigned_user_id', fromJson: jsonScalarToStringOrEmpty) this.assignedUserId = '', @JsonKey(name: 'is_default') this.isDefault = false, @JsonKey(name: 'is_public') this.isPublic = true, @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'documentable_type', fromJson: jsonScalarToString) this.documentableType, @JsonKey(name: 'documentable_id', fromJson: jsonScalarToString) this.documentableId});
  factory _DocumentApi.fromJson(Map<String, dynamic> json) => _$DocumentApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey() final  String name;
@override@JsonKey() final  String hash;
@override@JsonKey() final  String type;
@override@JsonKey() final  String url;
@override@JsonKey() final  int size;
@override@JsonKey() final  int width;
@override@JsonKey() final  int height;
@override@JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty) final  String userId;
@override@JsonKey(name: 'assigned_user_id', fromJson: jsonScalarToStringOrEmpty) final  String assignedUserId;
@override@JsonKey(name: 'is_default') final  bool isDefault;
@override@JsonKey(name: 'is_public') final  bool isPublic;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'documentable_type', fromJson: jsonScalarToString) final  String? documentableType;
@override@JsonKey(name: 'documentable_id', fromJson: jsonScalarToString) final  String? documentableId;

/// Create a copy of DocumentApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentApiCopyWith<_DocumentApi> get copyWith => __$DocumentApiCopyWithImpl<_DocumentApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DocumentApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentApi&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.hash, hash) || other.hash == hash)&&(identical(other.type, type) || other.type == type)&&(identical(other.url, url) || other.url == url)&&(identical(other.size, size) || other.size == size)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.isDefault, isDefault) || other.isDefault == isDefault)&&(identical(other.isPublic, isPublic) || other.isPublic == isPublic)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.documentableType, documentableType) || other.documentableType == documentableType)&&(identical(other.documentableId, documentableId) || other.documentableId == documentableId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,hash,type,url,size,width,height,userId,assignedUserId,isDefault,isPublic,createdAt,updatedAt,archivedAt,documentableType,documentableId);
}

@override
String toString() {
    return 'DocumentApi(id: $id, name: $name, hash: $hash, type: $type, url: $url, size: $size, width: $width, height: $height, userId: $userId, assignedUserId: $assignedUserId, isDefault: $isDefault, isPublic: $isPublic, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, documentableType: $documentableType, documentableId: $documentableId)';
}


}

/// @nodoc
abstract mixin class _$DocumentApiCopyWith<$Res> implements $DocumentApiCopyWith<$Res> {
  factory _$DocumentApiCopyWith(_DocumentApi value, $Res Function(_DocumentApi) _then) = __$DocumentApiCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String hash, String type, String url, int size, int width, int height,@JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty) String userId,@JsonKey(name: 'assigned_user_id', fromJson: jsonScalarToStringOrEmpty) String assignedUserId,@JsonKey(name: 'is_default') bool isDefault,@JsonKey(name: 'is_public') bool isPublic,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'documentable_type', fromJson: jsonScalarToString) String? documentableType,@JsonKey(name: 'documentable_id', fromJson: jsonScalarToString) String? documentableId
});




}
/// @nodoc
class __$DocumentApiCopyWithImpl<$Res>
    implements _$DocumentApiCopyWith<$Res> {
  __$DocumentApiCopyWithImpl(this._self, this._then);

  final _DocumentApi _self;
  final $Res Function(_DocumentApi) _then;

/// Create a copy of DocumentApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? hash = null,Object? type = null,Object? url = null,Object? size = null,Object? width = null,Object? height = null,Object? userId = null,Object? assignedUserId = null,Object? isDefault = null,Object? isPublic = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? documentableType = freezed,Object? documentableId = freezed,}) {
  return _then(_DocumentApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,hash: null == hash ? _self.hash : hash // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,isDefault: null == isDefault ? _self.isDefault : isDefault // ignore: cast_nullable_to_non_nullable
as bool,isPublic: null == isPublic ? _self.isPublic : isPublic // ignore: cast_nullable_to_non_nullable
as bool,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,documentableType: freezed == documentableType ? _self.documentableType : documentableType // ignore: cast_nullable_to_non_nullable
as String?,documentableId: freezed == documentableId ? _self.documentableId : documentableId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$DocumentListApi {

@JsonKey(fromJson: _documentListData) List<DocumentApi> get data;
/// Create a copy of DocumentListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentListApiCopyWith<DocumentListApi> get copyWith => _$DocumentListApiCopyWithImpl<DocumentListApi>(this as DocumentListApi, _$identity);

  /// Serializes this DocumentListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DocumentListApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentListApi&&const DeepCollectionEquality().equals(other.data, _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DocumentListApi;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data));
}

@override
String toString() {
  final _this = this as DocumentListApi;
  return 'DocumentListApi(data: ${_this.data})';
}


}

/// @nodoc
abstract mixin class $DocumentListApiCopyWith<$Res>  {
  factory $DocumentListApiCopyWith(DocumentListApi value, $Res Function(DocumentListApi) _then) = _$DocumentListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _documentListData) List<DocumentApi> data
});




}
/// @nodoc
class _$DocumentListApiCopyWithImpl<$Res>
    implements $DocumentListApiCopyWith<$Res> {
  _$DocumentListApiCopyWithImpl(this._self, this._then);

  final DocumentListApi _self;
  final $Res Function(DocumentListApi) _then;

/// Create a copy of DocumentListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(DocumentListApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentListApi].
extension DocumentListApiPatterns on DocumentListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentListApi value)  $default,){
final _that = this;
switch (_that) {
case _DocumentListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentListApi value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _documentListData)  List<DocumentApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _documentListData)  List<DocumentApi> data)  $default,) {final _that = this;
switch (_that) {
case _DocumentListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _documentListData)  List<DocumentApi> data)?  $default,) {final _that = this;
switch (_that) {
case _DocumentListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DocumentListApi implements DocumentListApi {
  const _DocumentListApi({@JsonKey(fromJson: _documentListData)  List<DocumentApi> data = const <DocumentApi>[]}): _data = data;
  factory _DocumentListApi.fromJson(Map<String, dynamic> json) => _$DocumentListApiFromJson(json);

 final  List<DocumentApi> _data;
@override@JsonKey(fromJson: _documentListData) List<DocumentApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of DocumentListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentListApiCopyWith<_DocumentListApi> get copyWith => __$DocumentListApiCopyWithImpl<_DocumentListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DocumentListApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentListApi&&const DeepCollectionEquality().equals(other.data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));
}

@override
String toString() {
    return 'DocumentListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$DocumentListApiCopyWith<$Res> implements $DocumentListApiCopyWith<$Res> {
  factory _$DocumentListApiCopyWith(_DocumentListApi value, $Res Function(_DocumentListApi) _then) = __$DocumentListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _documentListData) List<DocumentApi> data
});




}
/// @nodoc
class __$DocumentListApiCopyWithImpl<$Res>
    implements _$DocumentListApiCopyWith<$Res> {
  __$DocumentListApiCopyWithImpl(this._self, this._then);

  final _DocumentListApi _self;
  final $Res Function(_DocumentListApi) _then;

/// Create a copy of DocumentListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_DocumentListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>,
  ));
}


}


/// @nodoc
mixin _$DocumentItemApi {

 DocumentApi get data;
/// Create a copy of DocumentItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentItemApiCopyWith<DocumentItemApi> get copyWith => _$DocumentItemApiCopyWithImpl<DocumentItemApi>(this as DocumentItemApi, _$identity);

  /// Serializes this DocumentItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DocumentItemApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentItemApi&&(identical(other.data, _this.data) || other.data == _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DocumentItemApi;
  return Object.hash(runtimeType,_this.data);
}

@override
String toString() {
  final _this = this as DocumentItemApi;
  return 'DocumentItemApi(data: ${_this.data})';
}


}

/// @nodoc
abstract mixin class $DocumentItemApiCopyWith<$Res>  {
  factory $DocumentItemApiCopyWith(DocumentItemApi value, $Res Function(DocumentItemApi) _then) = _$DocumentItemApiCopyWithImpl;
@useResult
$Res call({
 DocumentApi data
});


$DocumentApiCopyWith<$Res> get data;

}
/// @nodoc
class _$DocumentItemApiCopyWithImpl<$Res>
    implements $DocumentItemApiCopyWith<$Res> {
  _$DocumentItemApiCopyWithImpl(this._self, this._then);

  final DocumentItemApi _self;
  final $Res Function(DocumentItemApi) _then;

/// Create a copy of DocumentItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(DocumentItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as DocumentApi,
  ));
}
/// Create a copy of DocumentItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DocumentApiCopyWith<$Res> get data {
  
  return $DocumentApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [DocumentItemApi].
extension DocumentItemApiPatterns on DocumentItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentItemApi value)  $default,){
final _that = this;
switch (_that) {
case _DocumentItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DocumentApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DocumentApi data)  $default,) {final _that = this;
switch (_that) {
case _DocumentItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DocumentApi data)?  $default,) {final _that = this;
switch (_that) {
case _DocumentItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DocumentItemApi implements DocumentItemApi {
  const _DocumentItemApi({required this.data});
  factory _DocumentItemApi.fromJson(Map<String, dynamic> json) => _$DocumentItemApiFromJson(json);

@override final  DocumentApi data;

/// Create a copy of DocumentItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentItemApiCopyWith<_DocumentItemApi> get copyWith => __$DocumentItemApiCopyWithImpl<_DocumentItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DocumentItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,data);
}

@override
String toString() {
    return 'DocumentItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$DocumentItemApiCopyWith<$Res> implements $DocumentItemApiCopyWith<$Res> {
  factory _$DocumentItemApiCopyWith(_DocumentItemApi value, $Res Function(_DocumentItemApi) _then) = __$DocumentItemApiCopyWithImpl;
@override @useResult
$Res call({
 DocumentApi data
});


@override $DocumentApiCopyWith<$Res> get data;

}
/// @nodoc
class __$DocumentItemApiCopyWithImpl<$Res>
    implements _$DocumentItemApiCopyWith<$Res> {
  __$DocumentItemApiCopyWithImpl(this._self, this._then);

  final _DocumentItemApi _self;
  final $Res Function(_DocumentItemApi) _then;

/// Create a copy of DocumentItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_DocumentItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as DocumentApi,
  ));
}

/// Create a copy of DocumentItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DocumentApiCopyWith<$Res> get data {
  
  return $DocumentApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
