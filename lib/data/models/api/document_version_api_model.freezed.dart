// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'document_version_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DocumentVersionItemApi {

@JsonKey(fromJson: _versionEntity) DocumentVersionEntityApi get data;
/// Create a copy of DocumentVersionItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentVersionItemApiCopyWith<DocumentVersionItemApi> get copyWith => _$DocumentVersionItemApiCopyWithImpl<DocumentVersionItemApi>(this as DocumentVersionItemApi, _$identity);

  /// Serializes this DocumentVersionItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentVersionItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'DocumentVersionItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class $DocumentVersionItemApiCopyWith<$Res>  {
  factory $DocumentVersionItemApiCopyWith(DocumentVersionItemApi value, $Res Function(DocumentVersionItemApi) _then) = _$DocumentVersionItemApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _versionEntity) DocumentVersionEntityApi data
});


$DocumentVersionEntityApiCopyWith<$Res> get data;

}
/// @nodoc
class _$DocumentVersionItemApiCopyWithImpl<$Res>
    implements $DocumentVersionItemApiCopyWith<$Res> {
  _$DocumentVersionItemApiCopyWithImpl(this._self, this._then);

  final DocumentVersionItemApi _self;
  final $Res Function(DocumentVersionItemApi) _then;

/// Create a copy of DocumentVersionItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(_self.copyWith(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as DocumentVersionEntityApi,
  ));
}
/// Create a copy of DocumentVersionItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DocumentVersionEntityApiCopyWith<$Res> get data {
  
  return $DocumentVersionEntityApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [DocumentVersionItemApi].
extension DocumentVersionItemApiPatterns on DocumentVersionItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentVersionItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentVersionItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentVersionItemApi value)  $default,){
final _that = this;
switch (_that) {
case _DocumentVersionItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentVersionItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentVersionItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _versionEntity)  DocumentVersionEntityApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentVersionItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _versionEntity)  DocumentVersionEntityApi data)  $default,) {final _that = this;
switch (_that) {
case _DocumentVersionItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _versionEntity)  DocumentVersionEntityApi data)?  $default,) {final _that = this;
switch (_that) {
case _DocumentVersionItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DocumentVersionItemApi implements DocumentVersionItemApi {
  const _DocumentVersionItemApi({@JsonKey(fromJson: _versionEntity) this.data = const DocumentVersionEntityApi()});
  factory _DocumentVersionItemApi.fromJson(Map<String, dynamic> json) => _$DocumentVersionItemApiFromJson(json);

@override@JsonKey(fromJson: _versionEntity) final  DocumentVersionEntityApi data;

/// Create a copy of DocumentVersionItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentVersionItemApiCopyWith<_DocumentVersionItemApi> get copyWith => __$DocumentVersionItemApiCopyWithImpl<_DocumentVersionItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DocumentVersionItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentVersionItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,data);

@override
String toString() {
  return 'DocumentVersionItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$DocumentVersionItemApiCopyWith<$Res> implements $DocumentVersionItemApiCopyWith<$Res> {
  factory _$DocumentVersionItemApiCopyWith(_DocumentVersionItemApi value, $Res Function(_DocumentVersionItemApi) _then) = __$DocumentVersionItemApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _versionEntity) DocumentVersionEntityApi data
});


@override $DocumentVersionEntityApiCopyWith<$Res> get data;

}
/// @nodoc
class __$DocumentVersionItemApiCopyWithImpl<$Res>
    implements _$DocumentVersionItemApiCopyWith<$Res> {
  __$DocumentVersionItemApiCopyWithImpl(this._self, this._then);

  final _DocumentVersionItemApi _self;
  final $Res Function(_DocumentVersionItemApi) _then;

/// Create a copy of DocumentVersionItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_DocumentVersionItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as DocumentVersionEntityApi,
  ));
}

/// Create a copy of DocumentVersionItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DocumentVersionEntityApiCopyWith<$Res> get data {
  
  return $DocumentVersionEntityApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// @nodoc
mixin _$DocumentVersionEntityApi {

@JsonKey(fromJson: _versionActivities) List<DocumentVersionActivityApi> get activities;
/// Create a copy of DocumentVersionEntityApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentVersionEntityApiCopyWith<DocumentVersionEntityApi> get copyWith => _$DocumentVersionEntityApiCopyWithImpl<DocumentVersionEntityApi>(this as DocumentVersionEntityApi, _$identity);

  /// Serializes this DocumentVersionEntityApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentVersionEntityApi&&const DeepCollectionEquality().equals(other.activities, activities));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(activities));

@override
String toString() {
  return 'DocumentVersionEntityApi(activities: $activities)';
}


}

/// @nodoc
abstract mixin class $DocumentVersionEntityApiCopyWith<$Res>  {
  factory $DocumentVersionEntityApiCopyWith(DocumentVersionEntityApi value, $Res Function(DocumentVersionEntityApi) _then) = _$DocumentVersionEntityApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _versionActivities) List<DocumentVersionActivityApi> activities
});




}
/// @nodoc
class _$DocumentVersionEntityApiCopyWithImpl<$Res>
    implements $DocumentVersionEntityApiCopyWith<$Res> {
  _$DocumentVersionEntityApiCopyWithImpl(this._self, this._then);

  final DocumentVersionEntityApi _self;
  final $Res Function(DocumentVersionEntityApi) _then;

/// Create a copy of DocumentVersionEntityApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? activities = null,}) {
  return _then(_self.copyWith(
activities: null == activities ? _self.activities : activities // ignore: cast_nullable_to_non_nullable
as List<DocumentVersionActivityApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentVersionEntityApi].
extension DocumentVersionEntityApiPatterns on DocumentVersionEntityApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentVersionEntityApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentVersionEntityApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentVersionEntityApi value)  $default,){
final _that = this;
switch (_that) {
case _DocumentVersionEntityApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentVersionEntityApi value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentVersionEntityApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _versionActivities)  List<DocumentVersionActivityApi> activities)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentVersionEntityApi() when $default != null:
return $default(_that.activities);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _versionActivities)  List<DocumentVersionActivityApi> activities)  $default,) {final _that = this;
switch (_that) {
case _DocumentVersionEntityApi():
return $default(_that.activities);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _versionActivities)  List<DocumentVersionActivityApi> activities)?  $default,) {final _that = this;
switch (_that) {
case _DocumentVersionEntityApi() when $default != null:
return $default(_that.activities);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DocumentVersionEntityApi implements DocumentVersionEntityApi {
  const _DocumentVersionEntityApi({@JsonKey(fromJson: _versionActivities) final  List<DocumentVersionActivityApi> activities = const []}): _activities = activities;
  factory _DocumentVersionEntityApi.fromJson(Map<String, dynamic> json) => _$DocumentVersionEntityApiFromJson(json);

 final  List<DocumentVersionActivityApi> _activities;
@override@JsonKey(fromJson: _versionActivities) List<DocumentVersionActivityApi> get activities {
  if (_activities is EqualUnmodifiableListView) return _activities;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_activities);
}


/// Create a copy of DocumentVersionEntityApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentVersionEntityApiCopyWith<_DocumentVersionEntityApi> get copyWith => __$DocumentVersionEntityApiCopyWithImpl<_DocumentVersionEntityApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DocumentVersionEntityApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentVersionEntityApi&&const DeepCollectionEquality().equals(other._activities, _activities));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_activities));

@override
String toString() {
  return 'DocumentVersionEntityApi(activities: $activities)';
}


}

/// @nodoc
abstract mixin class _$DocumentVersionEntityApiCopyWith<$Res> implements $DocumentVersionEntityApiCopyWith<$Res> {
  factory _$DocumentVersionEntityApiCopyWith(_DocumentVersionEntityApi value, $Res Function(_DocumentVersionEntityApi) _then) = __$DocumentVersionEntityApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _versionActivities) List<DocumentVersionActivityApi> activities
});




}
/// @nodoc
class __$DocumentVersionEntityApiCopyWithImpl<$Res>
    implements _$DocumentVersionEntityApiCopyWith<$Res> {
  __$DocumentVersionEntityApiCopyWithImpl(this._self, this._then);

  final _DocumentVersionEntityApi _self;
  final $Res Function(_DocumentVersionEntityApi) _then;

/// Create a copy of DocumentVersionEntityApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? activities = null,}) {
  return _then(_DocumentVersionEntityApi(
activities: null == activities ? _self._activities : activities // ignore: cast_nullable_to_non_nullable
as List<DocumentVersionActivityApi>,
  ));
}


}


/// @nodoc
mixin _$DocumentVersionActivityApi {

@JsonKey(fromJson: jsonScalarToStringOrEmpty) String get id;@JsonKey(name: 'activity_type_id', fromJson: jsonScalarToStringOrEmpty) String get activityTypeId;@JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty) String get userId;@JsonKey(name: 'contact_id', fromJson: jsonScalarToStringOrEmpty) String get contactId;@JsonKey(name: 'is_system') bool get isSystem; DocumentVersionHistoryApi? get history;
/// Create a copy of DocumentVersionActivityApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentVersionActivityApiCopyWith<DocumentVersionActivityApi> get copyWith => _$DocumentVersionActivityApiCopyWithImpl<DocumentVersionActivityApi>(this as DocumentVersionActivityApi, _$identity);

  /// Serializes this DocumentVersionActivityApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentVersionActivityApi&&(identical(other.id, id) || other.id == id)&&(identical(other.activityTypeId, activityTypeId) || other.activityTypeId == activityTypeId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.contactId, contactId) || other.contactId == contactId)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem)&&(identical(other.history, history) || other.history == history));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activityTypeId,userId,contactId,isSystem,history);

@override
String toString() {
  return 'DocumentVersionActivityApi(id: $id, activityTypeId: $activityTypeId, userId: $userId, contactId: $contactId, isSystem: $isSystem, history: $history)';
}


}

/// @nodoc
abstract mixin class $DocumentVersionActivityApiCopyWith<$Res>  {
  factory $DocumentVersionActivityApiCopyWith(DocumentVersionActivityApi value, $Res Function(DocumentVersionActivityApi) _then) = _$DocumentVersionActivityApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: jsonScalarToStringOrEmpty) String id,@JsonKey(name: 'activity_type_id', fromJson: jsonScalarToStringOrEmpty) String activityTypeId,@JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty) String userId,@JsonKey(name: 'contact_id', fromJson: jsonScalarToStringOrEmpty) String contactId,@JsonKey(name: 'is_system') bool isSystem, DocumentVersionHistoryApi? history
});


$DocumentVersionHistoryApiCopyWith<$Res>? get history;

}
/// @nodoc
class _$DocumentVersionActivityApiCopyWithImpl<$Res>
    implements $DocumentVersionActivityApiCopyWith<$Res> {
  _$DocumentVersionActivityApiCopyWithImpl(this._self, this._then);

  final DocumentVersionActivityApi _self;
  final $Res Function(DocumentVersionActivityApi) _then;

/// Create a copy of DocumentVersionActivityApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? activityTypeId = null,Object? userId = null,Object? contactId = null,Object? isSystem = null,Object? history = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activityTypeId: null == activityTypeId ? _self.activityTypeId : activityTypeId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,contactId: null == contactId ? _self.contactId : contactId // ignore: cast_nullable_to_non_nullable
as String,isSystem: null == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool,history: freezed == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as DocumentVersionHistoryApi?,
  ));
}
/// Create a copy of DocumentVersionActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DocumentVersionHistoryApiCopyWith<$Res>? get history {
    if (_self.history == null) {
    return null;
  }

  return $DocumentVersionHistoryApiCopyWith<$Res>(_self.history!, (value) {
    return _then(_self.copyWith(history: value));
  });
}
}


/// Adds pattern-matching-related methods to [DocumentVersionActivityApi].
extension DocumentVersionActivityApiPatterns on DocumentVersionActivityApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentVersionActivityApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentVersionActivityApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentVersionActivityApi value)  $default,){
final _that = this;
switch (_that) {
case _DocumentVersionActivityApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentVersionActivityApi value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentVersionActivityApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonScalarToStringOrEmpty)  String id, @JsonKey(name: 'activity_type_id', fromJson: jsonScalarToStringOrEmpty)  String activityTypeId, @JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty)  String userId, @JsonKey(name: 'contact_id', fromJson: jsonScalarToStringOrEmpty)  String contactId, @JsonKey(name: 'is_system')  bool isSystem,  DocumentVersionHistoryApi? history)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentVersionActivityApi() when $default != null:
return $default(_that.id,_that.activityTypeId,_that.userId,_that.contactId,_that.isSystem,_that.history);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonScalarToStringOrEmpty)  String id, @JsonKey(name: 'activity_type_id', fromJson: jsonScalarToStringOrEmpty)  String activityTypeId, @JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty)  String userId, @JsonKey(name: 'contact_id', fromJson: jsonScalarToStringOrEmpty)  String contactId, @JsonKey(name: 'is_system')  bool isSystem,  DocumentVersionHistoryApi? history)  $default,) {final _that = this;
switch (_that) {
case _DocumentVersionActivityApi():
return $default(_that.id,_that.activityTypeId,_that.userId,_that.contactId,_that.isSystem,_that.history);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: jsonScalarToStringOrEmpty)  String id, @JsonKey(name: 'activity_type_id', fromJson: jsonScalarToStringOrEmpty)  String activityTypeId, @JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty)  String userId, @JsonKey(name: 'contact_id', fromJson: jsonScalarToStringOrEmpty)  String contactId, @JsonKey(name: 'is_system')  bool isSystem,  DocumentVersionHistoryApi? history)?  $default,) {final _that = this;
switch (_that) {
case _DocumentVersionActivityApi() when $default != null:
return $default(_that.id,_that.activityTypeId,_that.userId,_that.contactId,_that.isSystem,_that.history);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DocumentVersionActivityApi implements DocumentVersionActivityApi {
  const _DocumentVersionActivityApi({@JsonKey(fromJson: jsonScalarToStringOrEmpty) this.id = '', @JsonKey(name: 'activity_type_id', fromJson: jsonScalarToStringOrEmpty) this.activityTypeId = '', @JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty) this.userId = '', @JsonKey(name: 'contact_id', fromJson: jsonScalarToStringOrEmpty) this.contactId = '', @JsonKey(name: 'is_system') this.isSystem = false, this.history});
  factory _DocumentVersionActivityApi.fromJson(Map<String, dynamic> json) => _$DocumentVersionActivityApiFromJson(json);

@override@JsonKey(fromJson: jsonScalarToStringOrEmpty) final  String id;
@override@JsonKey(name: 'activity_type_id', fromJson: jsonScalarToStringOrEmpty) final  String activityTypeId;
@override@JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty) final  String userId;
@override@JsonKey(name: 'contact_id', fromJson: jsonScalarToStringOrEmpty) final  String contactId;
@override@JsonKey(name: 'is_system') final  bool isSystem;
@override final  DocumentVersionHistoryApi? history;

/// Create a copy of DocumentVersionActivityApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentVersionActivityApiCopyWith<_DocumentVersionActivityApi> get copyWith => __$DocumentVersionActivityApiCopyWithImpl<_DocumentVersionActivityApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DocumentVersionActivityApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentVersionActivityApi&&(identical(other.id, id) || other.id == id)&&(identical(other.activityTypeId, activityTypeId) || other.activityTypeId == activityTypeId)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.contactId, contactId) || other.contactId == contactId)&&(identical(other.isSystem, isSystem) || other.isSystem == isSystem)&&(identical(other.history, history) || other.history == history));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activityTypeId,userId,contactId,isSystem,history);

@override
String toString() {
  return 'DocumentVersionActivityApi(id: $id, activityTypeId: $activityTypeId, userId: $userId, contactId: $contactId, isSystem: $isSystem, history: $history)';
}


}

/// @nodoc
abstract mixin class _$DocumentVersionActivityApiCopyWith<$Res> implements $DocumentVersionActivityApiCopyWith<$Res> {
  factory _$DocumentVersionActivityApiCopyWith(_DocumentVersionActivityApi value, $Res Function(_DocumentVersionActivityApi) _then) = __$DocumentVersionActivityApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: jsonScalarToStringOrEmpty) String id,@JsonKey(name: 'activity_type_id', fromJson: jsonScalarToStringOrEmpty) String activityTypeId,@JsonKey(name: 'user_id', fromJson: jsonScalarToStringOrEmpty) String userId,@JsonKey(name: 'contact_id', fromJson: jsonScalarToStringOrEmpty) String contactId,@JsonKey(name: 'is_system') bool isSystem, DocumentVersionHistoryApi? history
});


@override $DocumentVersionHistoryApiCopyWith<$Res>? get history;

}
/// @nodoc
class __$DocumentVersionActivityApiCopyWithImpl<$Res>
    implements _$DocumentVersionActivityApiCopyWith<$Res> {
  __$DocumentVersionActivityApiCopyWithImpl(this._self, this._then);

  final _DocumentVersionActivityApi _self;
  final $Res Function(_DocumentVersionActivityApi) _then;

/// Create a copy of DocumentVersionActivityApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? activityTypeId = null,Object? userId = null,Object? contactId = null,Object? isSystem = null,Object? history = freezed,}) {
  return _then(_DocumentVersionActivityApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activityTypeId: null == activityTypeId ? _self.activityTypeId : activityTypeId // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,contactId: null == contactId ? _self.contactId : contactId // ignore: cast_nullable_to_non_nullable
as String,isSystem: null == isSystem ? _self.isSystem : isSystem // ignore: cast_nullable_to_non_nullable
as bool,history: freezed == history ? _self.history : history // ignore: cast_nullable_to_non_nullable
as DocumentVersionHistoryApi?,
  ));
}

/// Create a copy of DocumentVersionActivityApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DocumentVersionHistoryApiCopyWith<$Res>? get history {
    if (_self.history == null) {
    return null;
  }

  return $DocumentVersionHistoryApiCopyWith<$Res>(_self.history!, (value) {
    return _then(_self.copyWith(history: value));
  });
}
}


/// @nodoc
mixin _$DocumentVersionHistoryApi {

@JsonKey(fromJson: jsonScalarToStringOrEmpty) String get id;@JsonKey(name: 'activity_id', fromJson: jsonScalarToStringOrEmpty) String get activityId; Object get amount;@JsonKey(name: 'created_at') int get createdAt;
/// Create a copy of DocumentVersionHistoryApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DocumentVersionHistoryApiCopyWith<DocumentVersionHistoryApi> get copyWith => _$DocumentVersionHistoryApiCopyWithImpl<DocumentVersionHistoryApi>(this as DocumentVersionHistoryApi, _$identity);

  /// Serializes this DocumentVersionHistoryApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DocumentVersionHistoryApi&&(identical(other.id, id) || other.id == id)&&(identical(other.activityId, activityId) || other.activityId == activityId)&&const DeepCollectionEquality().equals(other.amount, amount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activityId,const DeepCollectionEquality().hash(amount),createdAt);

@override
String toString() {
  return 'DocumentVersionHistoryApi(id: $id, activityId: $activityId, amount: $amount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $DocumentVersionHistoryApiCopyWith<$Res>  {
  factory $DocumentVersionHistoryApiCopyWith(DocumentVersionHistoryApi value, $Res Function(DocumentVersionHistoryApi) _then) = _$DocumentVersionHistoryApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: jsonScalarToStringOrEmpty) String id,@JsonKey(name: 'activity_id', fromJson: jsonScalarToStringOrEmpty) String activityId, Object amount,@JsonKey(name: 'created_at') int createdAt
});




}
/// @nodoc
class _$DocumentVersionHistoryApiCopyWithImpl<$Res>
    implements $DocumentVersionHistoryApiCopyWith<$Res> {
  _$DocumentVersionHistoryApiCopyWithImpl(this._self, this._then);

  final DocumentVersionHistoryApi _self;
  final $Res Function(DocumentVersionHistoryApi) _then;

/// Create a copy of DocumentVersionHistoryApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? activityId = null,Object? amount = null,Object? createdAt = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activityId: null == activityId ? _self.activityId : activityId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DocumentVersionHistoryApi].
extension DocumentVersionHistoryApiPatterns on DocumentVersionHistoryApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DocumentVersionHistoryApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DocumentVersionHistoryApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DocumentVersionHistoryApi value)  $default,){
final _that = this;
switch (_that) {
case _DocumentVersionHistoryApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DocumentVersionHistoryApi value)?  $default,){
final _that = this;
switch (_that) {
case _DocumentVersionHistoryApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonScalarToStringOrEmpty)  String id, @JsonKey(name: 'activity_id', fromJson: jsonScalarToStringOrEmpty)  String activityId,  Object amount, @JsonKey(name: 'created_at')  int createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DocumentVersionHistoryApi() when $default != null:
return $default(_that.id,_that.activityId,_that.amount,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: jsonScalarToStringOrEmpty)  String id, @JsonKey(name: 'activity_id', fromJson: jsonScalarToStringOrEmpty)  String activityId,  Object amount, @JsonKey(name: 'created_at')  int createdAt)  $default,) {final _that = this;
switch (_that) {
case _DocumentVersionHistoryApi():
return $default(_that.id,_that.activityId,_that.amount,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: jsonScalarToStringOrEmpty)  String id, @JsonKey(name: 'activity_id', fromJson: jsonScalarToStringOrEmpty)  String activityId,  Object amount, @JsonKey(name: 'created_at')  int createdAt)?  $default,) {final _that = this;
switch (_that) {
case _DocumentVersionHistoryApi() when $default != null:
return $default(_that.id,_that.activityId,_that.amount,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DocumentVersionHistoryApi implements DocumentVersionHistoryApi {
  const _DocumentVersionHistoryApi({@JsonKey(fromJson: jsonScalarToStringOrEmpty) this.id = '', @JsonKey(name: 'activity_id', fromJson: jsonScalarToStringOrEmpty) this.activityId = '', this.amount = '0', @JsonKey(name: 'created_at') this.createdAt = 0});
  factory _DocumentVersionHistoryApi.fromJson(Map<String, dynamic> json) => _$DocumentVersionHistoryApiFromJson(json);

@override@JsonKey(fromJson: jsonScalarToStringOrEmpty) final  String id;
@override@JsonKey(name: 'activity_id', fromJson: jsonScalarToStringOrEmpty) final  String activityId;
@override@JsonKey() final  Object amount;
@override@JsonKey(name: 'created_at') final  int createdAt;

/// Create a copy of DocumentVersionHistoryApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DocumentVersionHistoryApiCopyWith<_DocumentVersionHistoryApi> get copyWith => __$DocumentVersionHistoryApiCopyWithImpl<_DocumentVersionHistoryApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DocumentVersionHistoryApiToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DocumentVersionHistoryApi&&(identical(other.id, id) || other.id == id)&&(identical(other.activityId, activityId) || other.activityId == activityId)&&const DeepCollectionEquality().equals(other.amount, amount)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,activityId,const DeepCollectionEquality().hash(amount),createdAt);

@override
String toString() {
  return 'DocumentVersionHistoryApi(id: $id, activityId: $activityId, amount: $amount, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$DocumentVersionHistoryApiCopyWith<$Res> implements $DocumentVersionHistoryApiCopyWith<$Res> {
  factory _$DocumentVersionHistoryApiCopyWith(_DocumentVersionHistoryApi value, $Res Function(_DocumentVersionHistoryApi) _then) = __$DocumentVersionHistoryApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: jsonScalarToStringOrEmpty) String id,@JsonKey(name: 'activity_id', fromJson: jsonScalarToStringOrEmpty) String activityId, Object amount,@JsonKey(name: 'created_at') int createdAt
});




}
/// @nodoc
class __$DocumentVersionHistoryApiCopyWithImpl<$Res>
    implements _$DocumentVersionHistoryApiCopyWith<$Res> {
  __$DocumentVersionHistoryApiCopyWithImpl(this._self, this._then);

  final _DocumentVersionHistoryApi _self;
  final $Res Function(_DocumentVersionHistoryApi) _then;

/// Create a copy of DocumentVersionHistoryApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? activityId = null,Object? amount = null,Object? createdAt = null,}) {
  return _then(_DocumentVersionHistoryApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,activityId: null == activityId ? _self.activityId : activityId // ignore: cast_nullable_to_non_nullable
as String,amount: null == amount ? _self.amount : amount ,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
