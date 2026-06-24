// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'group_setting_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$GroupSettingApi {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'assigned_user_id') String get assignedUserId; String get name;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'settings', includeIfNull: false) Map<String, dynamic>? get settings;// Nullable to distinguish JSON-omitted (list endpoint without
// `?include=documents`) from JSON-present-and-empty. Lives in its own
// Drift column; the repo's `_fromRow` overlays it. See `ClientApi.documents`.
 List<DocumentApi>? get documents;
/// Create a copy of GroupSettingApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupSettingApiCopyWith<GroupSettingApi> get copyWith => _$GroupSettingApiCopyWithImpl<GroupSettingApi>(this as GroupSettingApi, _$identity);

  /// Serializes this GroupSettingApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupSettingApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.name, name) || other.name == name)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other.settings, settings)&&const DeepCollectionEquality().equals(other.documents, documents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,assignedUserId,name,customValue1,customValue2,customValue3,customValue4,createdAt,updatedAt,archivedAt,isDeleted,const DeepCollectionEquality().hash(settings),const DeepCollectionEquality().hash(documents));

@override
String toString() {
  return 'GroupSettingApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, name: $name, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, settings: $settings, documents: $documents)';
}


}

/// @nodoc
abstract mixin class $GroupSettingApiCopyWith<$Res>  {
  factory $GroupSettingApiCopyWith(GroupSettingApi value, $Res Function(GroupSettingApi) _then) = _$GroupSettingApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId, String name,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'settings', includeIfNull: false) Map<String, dynamic>? settings, List<DocumentApi>? documents
});




}
/// @nodoc
class _$GroupSettingApiCopyWithImpl<$Res>
    implements $GroupSettingApiCopyWith<$Res> {
  _$GroupSettingApiCopyWithImpl(this._self, this._then);

  final GroupSettingApi _self;
  final $Res Function(GroupSettingApi) _then;

/// Create a copy of GroupSettingApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? name = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? settings = freezed,Object? documents = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,settings: freezed == settings ? _self.settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,documents: freezed == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupSettingApi].
extension GroupSettingApiPatterns on GroupSettingApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupSettingApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupSettingApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupSettingApi value)  $default,){
final _that = this;
switch (_that) {
case _GroupSettingApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupSettingApi value)?  $default,){
final _that = this;
switch (_that) {
case _GroupSettingApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String name, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'settings', includeIfNull: false)  Map<String, dynamic>? settings,  List<DocumentApi>? documents)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupSettingApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.name,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.settings,_that.documents);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String name, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'settings', includeIfNull: false)  Map<String, dynamic>? settings,  List<DocumentApi>? documents)  $default,) {final _that = this;
switch (_that) {
case _GroupSettingApi():
return $default(_that.id,_that.userId,_that.assignedUserId,_that.name,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.settings,_that.documents);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String name, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'settings', includeIfNull: false)  Map<String, dynamic>? settings,  List<DocumentApi>? documents)?  $default,) {final _that = this;
switch (_that) {
case _GroupSettingApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.name,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.settings,_that.documents);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GroupSettingApi implements GroupSettingApi {
  const _GroupSettingApi({this.id = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', this.name = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'settings', includeIfNull: false) final  Map<String, dynamic>? settings, final  List<DocumentApi>? documents}): _settings = settings,_documents = documents;
  factory _GroupSettingApi.fromJson(Map<String, dynamic> json) => _$GroupSettingApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey() final  String name;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
 final  Map<String, dynamic>? _settings;
@override@JsonKey(name: 'settings', includeIfNull: false) Map<String, dynamic>? get settings {
  final value = _settings;
  if (value == null) return null;
  if (_settings is EqualUnmodifiableMapView) return _settings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

// Nullable to distinguish JSON-omitted (list endpoint without
// `?include=documents`) from JSON-present-and-empty. Lives in its own
// Drift column; the repo's `_fromRow` overlays it. See `ClientApi.documents`.
 final  List<DocumentApi>? _documents;
// Nullable to distinguish JSON-omitted (list endpoint without
// `?include=documents`) from JSON-present-and-empty. Lives in its own
// Drift column; the repo's `_fromRow` overlays it. See `ClientApi.documents`.
@override List<DocumentApi>? get documents {
  final value = _documents;
  if (value == null) return null;
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of GroupSettingApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupSettingApiCopyWith<_GroupSettingApi> get copyWith => __$GroupSettingApiCopyWithImpl<_GroupSettingApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupSettingApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupSettingApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.name, name) || other.name == name)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other._settings, _settings)&&const DeepCollectionEquality().equals(other._documents, _documents));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,assignedUserId,name,customValue1,customValue2,customValue3,customValue4,createdAt,updatedAt,archivedAt,isDeleted,const DeepCollectionEquality().hash(_settings),const DeepCollectionEquality().hash(_documents));

@override
String toString() {
  return 'GroupSettingApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, name: $name, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, settings: $settings, documents: $documents)';
}


}

/// @nodoc
abstract mixin class _$GroupSettingApiCopyWith<$Res> implements $GroupSettingApiCopyWith<$Res> {
  factory _$GroupSettingApiCopyWith(_GroupSettingApi value, $Res Function(_GroupSettingApi) _then) = __$GroupSettingApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId, String name,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'settings', includeIfNull: false) Map<String, dynamic>? settings, List<DocumentApi>? documents
});




}
/// @nodoc
class __$GroupSettingApiCopyWithImpl<$Res>
    implements _$GroupSettingApiCopyWith<$Res> {
  __$GroupSettingApiCopyWithImpl(this._self, this._then);

  final _GroupSettingApi _self;
  final $Res Function(_GroupSettingApi) _then;

/// Create a copy of GroupSettingApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? name = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? settings = freezed,Object? documents = freezed,}) {
  return _then(_GroupSettingApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,settings: freezed == settings ? _self._settings : settings // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,documents: freezed == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,
  ));
}


}


/// @nodoc
mixin _$GroupSettingListApi {

@JsonKey(fromJson: _groupSettingListData) List<GroupSettingApi> get data;
/// Create a copy of GroupSettingListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupSettingListApiCopyWith<GroupSettingListApi> get copyWith => _$GroupSettingListApiCopyWithImpl<GroupSettingListApi>(this as GroupSettingListApi, _$identity);

  /// Serializes this GroupSettingListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupSettingListApi&&const DeepCollectionEquality().equals(other.data, data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(data));

@override
String toString() {
  return 'GroupSettingListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $GroupSettingListApiCopyWith<$Res>  {
  factory $GroupSettingListApiCopyWith(GroupSettingListApi value, $Res Function(GroupSettingListApi) _then) = _$GroupSettingListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _groupSettingListData) List<GroupSettingApi> data
});




}
/// @nodoc
class _$GroupSettingListApiCopyWithImpl<$Res>
    implements $GroupSettingListApiCopyWith<$Res> {
  _$GroupSettingListApiCopyWithImpl(this._self, this._then);

  final GroupSettingListApi _self;
  final $Res Function(GroupSettingListApi) _then;

/// Create a copy of GroupSettingListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<GroupSettingApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [GroupSettingListApi].
extension GroupSettingListApiPatterns on GroupSettingListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupSettingListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupSettingListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupSettingListApi value)  $default,){
final _that = this;
switch (_that) {
case _GroupSettingListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupSettingListApi value)?  $default,){
final _that = this;
switch (_that) {
case _GroupSettingListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _groupSettingListData)  List<GroupSettingApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupSettingListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _groupSettingListData)  List<GroupSettingApi> data)  $default,) {final _that = this;
switch (_that) {
case _GroupSettingListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _groupSettingListData)  List<GroupSettingApi> data)?  $default,) {final _that = this;
switch (_that) {
case _GroupSettingListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GroupSettingListApi implements GroupSettingListApi {
  const _GroupSettingListApi({@JsonKey(fromJson: _groupSettingListData) final  List<GroupSettingApi> data = const []}): _data = data;
  factory _GroupSettingListApi.fromJson(Map<String, dynamic> json) => _$GroupSettingListApiFromJson(json);

 final  List<GroupSettingApi> _data;
@override@JsonKey(fromJson: _groupSettingListData) List<GroupSettingApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of GroupSettingListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupSettingListApiCopyWith<_GroupSettingListApi> get copyWith => __$GroupSettingListApiCopyWithImpl<_GroupSettingListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupSettingListApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupSettingListApi&&const DeepCollectionEquality().equals(other._data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));

@override
String toString() {
  return 'GroupSettingListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$GroupSettingListApiCopyWith<$Res> implements $GroupSettingListApiCopyWith<$Res> {
  factory _$GroupSettingListApiCopyWith(_GroupSettingListApi value, $Res Function(_GroupSettingListApi) _then) = __$GroupSettingListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _groupSettingListData) List<GroupSettingApi> data
});




}
/// @nodoc
class __$GroupSettingListApiCopyWithImpl<$Res>
    implements _$GroupSettingListApiCopyWith<$Res> {
  __$GroupSettingListApiCopyWithImpl(this._self, this._then);

  final _GroupSettingListApi _self;
  final $Res Function(_GroupSettingListApi) _then;

/// Create a copy of GroupSettingListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_GroupSettingListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<GroupSettingApi>,
  ));
}


}


/// @nodoc
mixin _$GroupSettingItemApi {

 GroupSettingApi get data;
/// Create a copy of GroupSettingItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GroupSettingItemApiCopyWith<GroupSettingItemApi> get copyWith => _$GroupSettingItemApiCopyWithImpl<GroupSettingItemApi>(this as GroupSettingItemApi, _$identity);

  /// Serializes this GroupSettingItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GroupSettingItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'GroupSettingItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $GroupSettingItemApiCopyWith<$Res>  {
  factory $GroupSettingItemApiCopyWith(GroupSettingItemApi value, $Res Function(GroupSettingItemApi) _then) = _$GroupSettingItemApiCopyWithImpl;
@useResult
$Res call({
 GroupSettingApi data
});


$GroupSettingApiCopyWith<$Res> get data;

}
/// @nodoc
class _$GroupSettingItemApiCopyWithImpl<$Res>
    implements $GroupSettingItemApiCopyWith<$Res> {
  _$GroupSettingItemApiCopyWithImpl(this._self, this._then);

  final GroupSettingItemApi _self;
  final $Res Function(GroupSettingItemApi) _then;

/// Create a copy of GroupSettingItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as GroupSettingApi,
  ));
}
/// Create a copy of GroupSettingItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GroupSettingApiCopyWith<$Res> get data {
  
  return $GroupSettingApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [GroupSettingItemApi].
extension GroupSettingItemApiPatterns on GroupSettingItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GroupSettingItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GroupSettingItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GroupSettingItemApi value)  $default,){
final _that = this;
switch (_that) {
case _GroupSettingItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GroupSettingItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _GroupSettingItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( GroupSettingApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GroupSettingItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( GroupSettingApi data)  $default,) {final _that = this;
switch (_that) {
case _GroupSettingItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( GroupSettingApi data)?  $default,) {final _that = this;
switch (_that) {
case _GroupSettingItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GroupSettingItemApi implements GroupSettingItemApi {
  const _GroupSettingItemApi({required this.data});
  factory _GroupSettingItemApi.fromJson(Map<String, dynamic> json) => _$GroupSettingItemApiFromJson(json);

@override final  GroupSettingApi data;

/// Create a copy of GroupSettingItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GroupSettingItemApiCopyWith<_GroupSettingItemApi> get copyWith => __$GroupSettingItemApiCopyWithImpl<_GroupSettingItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GroupSettingItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GroupSettingItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'GroupSettingItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$GroupSettingItemApiCopyWith<$Res> implements $GroupSettingItemApiCopyWith<$Res> {
  factory _$GroupSettingItemApiCopyWith(_GroupSettingItemApi value, $Res Function(_GroupSettingItemApi) _then) = __$GroupSettingItemApiCopyWithImpl;
@override @useResult
$Res call({
 GroupSettingApi data
});


@override $GroupSettingApiCopyWith<$Res> get data;

}
/// @nodoc
class __$GroupSettingItemApiCopyWithImpl<$Res>
    implements _$GroupSettingItemApiCopyWith<$Res> {
  __$GroupSettingItemApiCopyWithImpl(this._self, this._then);

  final _GroupSettingItemApi _self;
  final $Res Function(_GroupSettingItemApi) _then;

/// Create a copy of GroupSettingItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_GroupSettingItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as GroupSettingApi,
  ));
}

/// Create a copy of GroupSettingItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GroupSettingApiCopyWith<$Res> get data {
  
  return $GroupSettingApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
