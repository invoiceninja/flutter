// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'task_api_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TaskApi {

 String get id;@JsonKey(name: 'user_id') String get userId;@JsonKey(name: 'assigned_user_id') String get assignedUserId; String get number; String get description;@JsonKey(name: 'rate') Object get rate;@JsonKey(name: 'invoice_id') String get invoiceId;@JsonKey(name: 'client_id') String get clientId;@JsonKey(name: 'project_id') String get projectId;@JsonKey(name: 'status_id') String get statusId;@JsonKey(name: 'status_order') int? get statusOrder;@JsonKey(name: 'time_log') String get timeLog;@JsonKey(name: 'custom_value1') String get customValue1;@JsonKey(name: 'custom_value2') String get customValue2;@JsonKey(name: 'custom_value3') String get customValue3;@JsonKey(name: 'custom_value4') String get customValue4;@JsonKey(name: 'created_at') int get createdAt;@JsonKey(name: 'updated_at') int get updatedAt;@JsonKey(name: 'archived_at') int get archivedAt;@JsonKey(name: 'is_deleted') bool get isDeleted;@JsonKey(name: 'is_running') bool get isRunning;@JsonKey(name: 'is_date_based') bool get isDateBased;@JsonKey(name: 'due_date') String get dueDate;@JsonKey(name: 'estimated_duration') int? get estimatedDuration; List<DocumentApi>? get documents;@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags;@TaskMetaConverter() TaskMetaApi? get meta;
/// Create a copy of TaskApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskApiCopyWith<TaskApi> get copyWith => _$TaskApiCopyWithImpl<TaskApi>(this as TaskApi, _$identity);

  /// Serializes this TaskApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TaskApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskApi&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.userId, _this.userId) || other.userId == _this.userId)&&(identical(other.assignedUserId, _this.assignedUserId) || other.assignedUserId == _this.assignedUserId)&&(identical(other.number, _this.number) || other.number == _this.number)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.rate, _this.rate)&&(identical(other.invoiceId, _this.invoiceId) || other.invoiceId == _this.invoiceId)&&(identical(other.clientId, _this.clientId) || other.clientId == _this.clientId)&&(identical(other.projectId, _this.projectId) || other.projectId == _this.projectId)&&(identical(other.statusId, _this.statusId) || other.statusId == _this.statusId)&&(identical(other.statusOrder, _this.statusOrder) || other.statusOrder == _this.statusOrder)&&(identical(other.timeLog, _this.timeLog) || other.timeLog == _this.timeLog)&&(identical(other.customValue1, _this.customValue1) || other.customValue1 == _this.customValue1)&&(identical(other.customValue2, _this.customValue2) || other.customValue2 == _this.customValue2)&&(identical(other.customValue3, _this.customValue3) || other.customValue3 == _this.customValue3)&&(identical(other.customValue4, _this.customValue4) || other.customValue4 == _this.customValue4)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.archivedAt, _this.archivedAt) || other.archivedAt == _this.archivedAt)&&(identical(other.isDeleted, _this.isDeleted) || other.isDeleted == _this.isDeleted)&&(identical(other.isRunning, _this.isRunning) || other.isRunning == _this.isRunning)&&(identical(other.isDateBased, _this.isDateBased) || other.isDateBased == _this.isDateBased)&&(identical(other.dueDate, _this.dueDate) || other.dueDate == _this.dueDate)&&(identical(other.estimatedDuration, _this.estimatedDuration) || other.estimatedDuration == _this.estimatedDuration)&&const DeepCollectionEquality().equals(other.documents, _this.documents)&&const DeepCollectionEquality().equals(other.tags, _this.tags)&&(identical(other.meta, _this.meta) || other.meta == _this.meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TaskApi;
  return Object.hashAll([runtimeType,_this.id,_this.userId,_this.assignedUserId,_this.number,_this.description,const DeepCollectionEquality().hash(_this.rate),_this.invoiceId,_this.clientId,_this.projectId,_this.statusId,_this.statusOrder,_this.timeLog,_this.customValue1,_this.customValue2,_this.customValue3,_this.customValue4,_this.createdAt,_this.updatedAt,_this.archivedAt,_this.isDeleted,_this.isRunning,_this.isDateBased,_this.dueDate,_this.estimatedDuration,const DeepCollectionEquality().hash(_this.documents),const DeepCollectionEquality().hash(_this.tags),_this.meta]);
}

@override
String toString() {
  final _this = this as TaskApi;
  return 'TaskApi(id: ${_this.id}, userId: ${_this.userId}, assignedUserId: ${_this.assignedUserId}, number: ${_this.number}, description: ${_this.description}, rate: ${_this.rate}, invoiceId: ${_this.invoiceId}, clientId: ${_this.clientId}, projectId: ${_this.projectId}, statusId: ${_this.statusId}, statusOrder: ${_this.statusOrder}, timeLog: ${_this.timeLog}, customValue1: ${_this.customValue1}, customValue2: ${_this.customValue2}, customValue3: ${_this.customValue3}, customValue4: ${_this.customValue4}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, archivedAt: ${_this.archivedAt}, isDeleted: ${_this.isDeleted}, isRunning: ${_this.isRunning}, isDateBased: ${_this.isDateBased}, dueDate: ${_this.dueDate}, estimatedDuration: ${_this.estimatedDuration}, documents: ${_this.documents}, tags: ${_this.tags}, meta: ${_this.meta})';
}


}

/// @nodoc
abstract mixin class $TaskApiCopyWith<$Res>  {
  factory $TaskApiCopyWith(TaskApi value, $Res Function(TaskApi) _then) = _$TaskApiCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId, String number, String description,@JsonKey(name: 'rate') Object rate,@JsonKey(name: 'invoice_id') String invoiceId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'status_order') int? statusOrder,@JsonKey(name: 'time_log') String timeLog,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'is_running') bool isRunning,@JsonKey(name: 'is_date_based') bool isDateBased,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'estimated_duration') int? estimatedDuration, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags,@TaskMetaConverter() TaskMetaApi? meta
});


$TaskMetaApiCopyWith<$Res>? get meta;

}
/// @nodoc
class _$TaskApiCopyWithImpl<$Res>
    implements $TaskApiCopyWith<$Res> {
  _$TaskApiCopyWithImpl(this._self, this._then);

  final TaskApi _self;
  final $Res Function(TaskApi) _then;

/// Create a copy of TaskApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? number = null,Object? description = null,Object? rate = null,Object? invoiceId = null,Object? clientId = null,Object? projectId = null,Object? statusId = null,Object? statusOrder = freezed,Object? timeLog = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? isRunning = null,Object? isDateBased = null,Object? dueDate = null,Object? estimatedDuration = freezed,Object? documents = freezed,Object? tags = null,Object? meta = freezed,}) {
  return _then(TaskApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate ,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,statusOrder: freezed == statusOrder ? _self.statusOrder : statusOrder // ignore: cast_nullable_to_non_nullable
as int?,timeLog: null == timeLog ? _self.timeLog : timeLog // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,isDateBased: null == isDateBased ? _self.isDateBased : isDateBased // ignore: cast_nullable_to_non_nullable
as bool,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,estimatedDuration: freezed == estimatedDuration ? _self.estimatedDuration : estimatedDuration // ignore: cast_nullable_to_non_nullable
as int?,documents: freezed == documents ? _self.documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as TaskMetaApi?,
  ));
}
/// Create a copy of TaskApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskMetaApiCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $TaskMetaApiCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}


/// Adds pattern-matching-related methods to [TaskApi].
extension TaskApiPatterns on TaskApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskApi value)  $default,){
final _that = this;
switch (_that) {
case _TaskApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaskApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String number,  String description, @JsonKey(name: 'rate')  Object rate, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'status_order')  int? statusOrder, @JsonKey(name: 'time_log')  String timeLog, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'is_running')  bool isRunning, @JsonKey(name: 'is_date_based')  bool isDateBased, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'estimated_duration')  int? estimatedDuration,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags, @TaskMetaConverter()  TaskMetaApi? meta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.number,_that.description,_that.rate,_that.invoiceId,_that.clientId,_that.projectId,_that.statusId,_that.statusOrder,_that.timeLog,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isRunning,_that.isDateBased,_that.dueDate,_that.estimatedDuration,_that.documents,_that.tags,_that.meta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String number,  String description, @JsonKey(name: 'rate')  Object rate, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'status_order')  int? statusOrder, @JsonKey(name: 'time_log')  String timeLog, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'is_running')  bool isRunning, @JsonKey(name: 'is_date_based')  bool isDateBased, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'estimated_duration')  int? estimatedDuration,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags, @TaskMetaConverter()  TaskMetaApi? meta)  $default,) {final _that = this;
switch (_that) {
case _TaskApi():
return $default(_that.id,_that.userId,_that.assignedUserId,_that.number,_that.description,_that.rate,_that.invoiceId,_that.clientId,_that.projectId,_that.statusId,_that.statusOrder,_that.timeLog,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isRunning,_that.isDateBased,_that.dueDate,_that.estimatedDuration,_that.documents,_that.tags,_that.meta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'user_id')  String userId, @JsonKey(name: 'assigned_user_id')  String assignedUserId,  String number,  String description, @JsonKey(name: 'rate')  Object rate, @JsonKey(name: 'invoice_id')  String invoiceId, @JsonKey(name: 'client_id')  String clientId, @JsonKey(name: 'project_id')  String projectId, @JsonKey(name: 'status_id')  String statusId, @JsonKey(name: 'status_order')  int? statusOrder, @JsonKey(name: 'time_log')  String timeLog, @JsonKey(name: 'custom_value1')  String customValue1, @JsonKey(name: 'custom_value2')  String customValue2, @JsonKey(name: 'custom_value3')  String customValue3, @JsonKey(name: 'custom_value4')  String customValue4, @JsonKey(name: 'created_at')  int createdAt, @JsonKey(name: 'updated_at')  int updatedAt, @JsonKey(name: 'archived_at')  int archivedAt, @JsonKey(name: 'is_deleted')  bool isDeleted, @JsonKey(name: 'is_running')  bool isRunning, @JsonKey(name: 'is_date_based')  bool isDateBased, @JsonKey(name: 'due_date')  String dueDate, @JsonKey(name: 'estimated_duration')  int? estimatedDuration,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags, @TaskMetaConverter()  TaskMetaApi? meta)?  $default,) {final _that = this;
switch (_that) {
case _TaskApi() when $default != null:
return $default(_that.id,_that.userId,_that.assignedUserId,_that.number,_that.description,_that.rate,_that.invoiceId,_that.clientId,_that.projectId,_that.statusId,_that.statusOrder,_that.timeLog,_that.customValue1,_that.customValue2,_that.customValue3,_that.customValue4,_that.createdAt,_that.updatedAt,_that.archivedAt,_that.isDeleted,_that.isRunning,_that.isDateBased,_that.dueDate,_that.estimatedDuration,_that.documents,_that.tags,_that.meta);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskApi implements TaskApi {
  const _TaskApi({this.id = '', @JsonKey(name: 'user_id') this.userId = '', @JsonKey(name: 'assigned_user_id') this.assignedUserId = '', this.number = '', this.description = '', @JsonKey(name: 'rate') this.rate = '0', @JsonKey(name: 'invoice_id') this.invoiceId = '', @JsonKey(name: 'client_id') this.clientId = '', @JsonKey(name: 'project_id') this.projectId = '', @JsonKey(name: 'status_id') this.statusId = '', @JsonKey(name: 'status_order') this.statusOrder, @JsonKey(name: 'time_log') this.timeLog = '', @JsonKey(name: 'custom_value1') this.customValue1 = '', @JsonKey(name: 'custom_value2') this.customValue2 = '', @JsonKey(name: 'custom_value3') this.customValue3 = '', @JsonKey(name: 'custom_value4') this.customValue4 = '', @JsonKey(name: 'created_at') this.createdAt = 0, @JsonKey(name: 'updated_at') this.updatedAt = 0, @JsonKey(name: 'archived_at') this.archivedAt = 0, @JsonKey(name: 'is_deleted') this.isDeleted = false, @JsonKey(name: 'is_running') this.isRunning = false, @JsonKey(name: 'is_date_based') this.isDateBased = false, @JsonKey(name: 'due_date') this.dueDate = '', @JsonKey(name: 'estimated_duration') this.estimatedDuration,  List<DocumentApi>? documents, @JsonKey(name: 'tags')@EmbeddedTagsConverter()  List<TagRefApi> tags = const <TagRefApi>[], @TaskMetaConverter() this.meta}): _documents = documents,_tags = tags;
  factory _TaskApi.fromJson(Map<String, dynamic> json) => _$TaskApiFromJson(json);

@override@JsonKey() final  String id;
@override@JsonKey(name: 'user_id') final  String userId;
@override@JsonKey(name: 'assigned_user_id') final  String assignedUserId;
@override@JsonKey() final  String number;
@override@JsonKey() final  String description;
@override@JsonKey(name: 'rate') final  Object rate;
@override@JsonKey(name: 'invoice_id') final  String invoiceId;
@override@JsonKey(name: 'client_id') final  String clientId;
@override@JsonKey(name: 'project_id') final  String projectId;
@override@JsonKey(name: 'status_id') final  String statusId;
@override@JsonKey(name: 'status_order') final  int? statusOrder;
@override@JsonKey(name: 'time_log') final  String timeLog;
@override@JsonKey(name: 'custom_value1') final  String customValue1;
@override@JsonKey(name: 'custom_value2') final  String customValue2;
@override@JsonKey(name: 'custom_value3') final  String customValue3;
@override@JsonKey(name: 'custom_value4') final  String customValue4;
@override@JsonKey(name: 'created_at') final  int createdAt;
@override@JsonKey(name: 'updated_at') final  int updatedAt;
@override@JsonKey(name: 'archived_at') final  int archivedAt;
@override@JsonKey(name: 'is_deleted') final  bool isDeleted;
@override@JsonKey(name: 'is_running') final  bool isRunning;
@override@JsonKey(name: 'is_date_based') final  bool isDateBased;
@override@JsonKey(name: 'due_date') final  String dueDate;
@override@JsonKey(name: 'estimated_duration') final  int? estimatedDuration;
 final  List<DocumentApi>? _documents;
@override List<DocumentApi>? get documents {
  final value = _documents;
  if (value == null) return null;
  if (_documents is EqualUnmodifiableListView) return _documents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<TagRefApi> _tags;
@override@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override@TaskMetaConverter() final  TaskMetaApi? meta;

/// Create a copy of TaskApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskApiCopyWith<_TaskApi> get copyWith => __$TaskApiCopyWithImpl<_TaskApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskApi&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.assignedUserId, assignedUserId) || other.assignedUserId == assignedUserId)&&(identical(other.number, number) || other.number == number)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.rate, rate)&&(identical(other.invoiceId, invoiceId) || other.invoiceId == invoiceId)&&(identical(other.clientId, clientId) || other.clientId == clientId)&&(identical(other.projectId, projectId) || other.projectId == projectId)&&(identical(other.statusId, statusId) || other.statusId == statusId)&&(identical(other.statusOrder, statusOrder) || other.statusOrder == statusOrder)&&(identical(other.timeLog, timeLog) || other.timeLog == timeLog)&&(identical(other.customValue1, customValue1) || other.customValue1 == customValue1)&&(identical(other.customValue2, customValue2) || other.customValue2 == customValue2)&&(identical(other.customValue3, customValue3) || other.customValue3 == customValue3)&&(identical(other.customValue4, customValue4) || other.customValue4 == customValue4)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.archivedAt, archivedAt) || other.archivedAt == archivedAt)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.isRunning, isRunning) || other.isRunning == isRunning)&&(identical(other.isDateBased, isDateBased) || other.isDateBased == isDateBased)&&(identical(other.dueDate, dueDate) || other.dueDate == dueDate)&&(identical(other.estimatedDuration, estimatedDuration) || other.estimatedDuration == estimatedDuration)&&const DeepCollectionEquality().equals(other.documents, _documents)&&const DeepCollectionEquality().equals(other.tags, _tags)&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,userId,assignedUserId,number,description,const DeepCollectionEquality().hash(rate),invoiceId,clientId,projectId,statusId,statusOrder,timeLog,customValue1,customValue2,customValue3,customValue4,createdAt,updatedAt,archivedAt,isDeleted,isRunning,isDateBased,dueDate,estimatedDuration,const DeepCollectionEquality().hash(_documents),const DeepCollectionEquality().hash(_tags),meta]);
}

@override
String toString() {
    return 'TaskApi(id: $id, userId: $userId, assignedUserId: $assignedUserId, number: $number, description: $description, rate: $rate, invoiceId: $invoiceId, clientId: $clientId, projectId: $projectId, statusId: $statusId, statusOrder: $statusOrder, timeLog: $timeLog, customValue1: $customValue1, customValue2: $customValue2, customValue3: $customValue3, customValue4: $customValue4, createdAt: $createdAt, updatedAt: $updatedAt, archivedAt: $archivedAt, isDeleted: $isDeleted, isRunning: $isRunning, isDateBased: $isDateBased, dueDate: $dueDate, estimatedDuration: $estimatedDuration, documents: $documents, tags: $tags, meta: $meta)';
}


}

/// @nodoc
abstract mixin class _$TaskApiCopyWith<$Res> implements $TaskApiCopyWith<$Res> {
  factory _$TaskApiCopyWith(_TaskApi value, $Res Function(_TaskApi) _then) = __$TaskApiCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'user_id') String userId,@JsonKey(name: 'assigned_user_id') String assignedUserId, String number, String description,@JsonKey(name: 'rate') Object rate,@JsonKey(name: 'invoice_id') String invoiceId,@JsonKey(name: 'client_id') String clientId,@JsonKey(name: 'project_id') String projectId,@JsonKey(name: 'status_id') String statusId,@JsonKey(name: 'status_order') int? statusOrder,@JsonKey(name: 'time_log') String timeLog,@JsonKey(name: 'custom_value1') String customValue1,@JsonKey(name: 'custom_value2') String customValue2,@JsonKey(name: 'custom_value3') String customValue3,@JsonKey(name: 'custom_value4') String customValue4,@JsonKey(name: 'created_at') int createdAt,@JsonKey(name: 'updated_at') int updatedAt,@JsonKey(name: 'archived_at') int archivedAt,@JsonKey(name: 'is_deleted') bool isDeleted,@JsonKey(name: 'is_running') bool isRunning,@JsonKey(name: 'is_date_based') bool isDateBased,@JsonKey(name: 'due_date') String dueDate,@JsonKey(name: 'estimated_duration') int? estimatedDuration, List<DocumentApi>? documents,@JsonKey(name: 'tags')@EmbeddedTagsConverter() List<TagRefApi> tags,@TaskMetaConverter() TaskMetaApi? meta
});


@override $TaskMetaApiCopyWith<$Res>? get meta;

}
/// @nodoc
class __$TaskApiCopyWithImpl<$Res>
    implements _$TaskApiCopyWith<$Res> {
  __$TaskApiCopyWithImpl(this._self, this._then);

  final _TaskApi _self;
  final $Res Function(_TaskApi) _then;

/// Create a copy of TaskApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? userId = null,Object? assignedUserId = null,Object? number = null,Object? description = null,Object? rate = null,Object? invoiceId = null,Object? clientId = null,Object? projectId = null,Object? statusId = null,Object? statusOrder = freezed,Object? timeLog = null,Object? customValue1 = null,Object? customValue2 = null,Object? customValue3 = null,Object? customValue4 = null,Object? createdAt = null,Object? updatedAt = null,Object? archivedAt = null,Object? isDeleted = null,Object? isRunning = null,Object? isDateBased = null,Object? dueDate = null,Object? estimatedDuration = freezed,Object? documents = freezed,Object? tags = null,Object? meta = freezed,}) {
  return _then(_TaskApi(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,assignedUserId: null == assignedUserId ? _self.assignedUserId : assignedUserId // ignore: cast_nullable_to_non_nullable
as String,number: null == number ? _self.number : number // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,rate: null == rate ? _self.rate : rate ,invoiceId: null == invoiceId ? _self.invoiceId : invoiceId // ignore: cast_nullable_to_non_nullable
as String,clientId: null == clientId ? _self.clientId : clientId // ignore: cast_nullable_to_non_nullable
as String,projectId: null == projectId ? _self.projectId : projectId // ignore: cast_nullable_to_non_nullable
as String,statusId: null == statusId ? _self.statusId : statusId // ignore: cast_nullable_to_non_nullable
as String,statusOrder: freezed == statusOrder ? _self.statusOrder : statusOrder // ignore: cast_nullable_to_non_nullable
as int?,timeLog: null == timeLog ? _self.timeLog : timeLog // ignore: cast_nullable_to_non_nullable
as String,customValue1: null == customValue1 ? _self.customValue1 : customValue1 // ignore: cast_nullable_to_non_nullable
as String,customValue2: null == customValue2 ? _self.customValue2 : customValue2 // ignore: cast_nullable_to_non_nullable
as String,customValue3: null == customValue3 ? _self.customValue3 : customValue3 // ignore: cast_nullable_to_non_nullable
as String,customValue4: null == customValue4 ? _self.customValue4 : customValue4 // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as int,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as int,archivedAt: null == archivedAt ? _self.archivedAt : archivedAt // ignore: cast_nullable_to_non_nullable
as int,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,isRunning: null == isRunning ? _self.isRunning : isRunning // ignore: cast_nullable_to_non_nullable
as bool,isDateBased: null == isDateBased ? _self.isDateBased : isDateBased // ignore: cast_nullable_to_non_nullable
as bool,dueDate: null == dueDate ? _self.dueDate : dueDate // ignore: cast_nullable_to_non_nullable
as String,estimatedDuration: freezed == estimatedDuration ? _self.estimatedDuration : estimatedDuration // ignore: cast_nullable_to_non_nullable
as int?,documents: freezed == documents ? _self._documents : documents // ignore: cast_nullable_to_non_nullable
as List<DocumentApi>?,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<TagRefApi>,meta: freezed == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as TaskMetaApi?,
  ));
}

/// Create a copy of TaskApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskMetaApiCopyWith<$Res>? get meta {
    if (_self.meta == null) {
    return null;
  }

  return $TaskMetaApiCopyWith<$Res>(_self.meta!, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}


/// @nodoc
mixin _$TaskMetaApi {

@JsonKey(name: 'calendar_event_id') String get calendarEventId;
/// Create a copy of TaskMetaApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskMetaApiCopyWith<TaskMetaApi> get copyWith => _$TaskMetaApiCopyWithImpl<TaskMetaApi>(this as TaskMetaApi, _$identity);

  /// Serializes this TaskMetaApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TaskMetaApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskMetaApi&&(identical(other.calendarEventId, _this.calendarEventId) || other.calendarEventId == _this.calendarEventId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TaskMetaApi;
  return Object.hash(runtimeType,_this.calendarEventId);
}

@override
String toString() {
  final _this = this as TaskMetaApi;
  return 'TaskMetaApi(calendarEventId: ${_this.calendarEventId})';
}


}

/// @nodoc
abstract mixin class $TaskMetaApiCopyWith<$Res>  {
  factory $TaskMetaApiCopyWith(TaskMetaApi value, $Res Function(TaskMetaApi) _then) = _$TaskMetaApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'calendar_event_id') String calendarEventId
});




}
/// @nodoc
class _$TaskMetaApiCopyWithImpl<$Res>
    implements $TaskMetaApiCopyWith<$Res> {
  _$TaskMetaApiCopyWithImpl(this._self, this._then);

  final TaskMetaApi _self;
  final $Res Function(TaskMetaApi) _then;

/// Create a copy of TaskMetaApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? calendarEventId = null,}) {
  return _then(TaskMetaApi(
calendarEventId: null == calendarEventId ? _self.calendarEventId : calendarEventId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskMetaApi].
extension TaskMetaApiPatterns on TaskMetaApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskMetaApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskMetaApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskMetaApi value)  $default,){
final _that = this;
switch (_that) {
case _TaskMetaApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskMetaApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaskMetaApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'calendar_event_id')  String calendarEventId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskMetaApi() when $default != null:
return $default(_that.calendarEventId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'calendar_event_id')  String calendarEventId)  $default,) {final _that = this;
switch (_that) {
case _TaskMetaApi():
return $default(_that.calendarEventId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'calendar_event_id')  String calendarEventId)?  $default,) {final _that = this;
switch (_that) {
case _TaskMetaApi() when $default != null:
return $default(_that.calendarEventId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskMetaApi implements TaskMetaApi {
  const _TaskMetaApi({@JsonKey(name: 'calendar_event_id') this.calendarEventId = ''});
  factory _TaskMetaApi.fromJson(Map<String, dynamic> json) => _$TaskMetaApiFromJson(json);

@override@JsonKey(name: 'calendar_event_id') final  String calendarEventId;

/// Create a copy of TaskMetaApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskMetaApiCopyWith<_TaskMetaApi> get copyWith => __$TaskMetaApiCopyWithImpl<_TaskMetaApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskMetaApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskMetaApi&&(identical(other.calendarEventId, calendarEventId) || other.calendarEventId == calendarEventId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,calendarEventId);
}

@override
String toString() {
    return 'TaskMetaApi(calendarEventId: $calendarEventId)';
}


}

/// @nodoc
abstract mixin class _$TaskMetaApiCopyWith<$Res> implements $TaskMetaApiCopyWith<$Res> {
  factory _$TaskMetaApiCopyWith(_TaskMetaApi value, $Res Function(_TaskMetaApi) _then) = __$TaskMetaApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'calendar_event_id') String calendarEventId
});




}
/// @nodoc
class __$TaskMetaApiCopyWithImpl<$Res>
    implements _$TaskMetaApiCopyWith<$Res> {
  __$TaskMetaApiCopyWithImpl(this._self, this._then);

  final _TaskMetaApi _self;
  final $Res Function(_TaskMetaApi) _then;

/// Create a copy of TaskMetaApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? calendarEventId = null,}) {
  return _then(_TaskMetaApi(
calendarEventId: null == calendarEventId ? _self.calendarEventId : calendarEventId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$TaskListApi {

@JsonKey(fromJson: _taskListData) List<TaskApi> get data;
/// Create a copy of TaskListApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskListApiCopyWith<TaskListApi> get copyWith => _$TaskListApiCopyWithImpl<TaskListApi>(this as TaskListApi, _$identity);

  /// Serializes this TaskListApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TaskListApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskListApi&&const DeepCollectionEquality().equals(other.data, _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TaskListApi;
  return Object.hash(runtimeType,const DeepCollectionEquality().hash(_this.data));
}

@override
String toString() {
  final _this = this as TaskListApi;
  return 'TaskListApi(data: ${_this.data})';
}


}

/// @nodoc
abstract mixin class $TaskListApiCopyWith<$Res>  {
  factory $TaskListApiCopyWith(TaskListApi value, $Res Function(TaskListApi) _then) = _$TaskListApiCopyWithImpl;
@useResult
$Res call({
@JsonKey(fromJson: _taskListData) List<TaskApi> data
});




}
/// @nodoc
class _$TaskListApiCopyWithImpl<$Res>
    implements $TaskListApiCopyWith<$Res> {
  _$TaskListApiCopyWithImpl(this._self, this._then);

  final TaskListApi _self;
  final $Res Function(TaskListApi) _then;

/// Create a copy of TaskListApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(TaskListApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as List<TaskApi>,
  ));
}

}


/// Adds pattern-matching-related methods to [TaskListApi].
extension TaskListApiPatterns on TaskListApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskListApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskListApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskListApi value)  $default,){
final _that = this;
switch (_that) {
case _TaskListApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskListApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaskListApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _taskListData)  List<TaskApi> data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskListApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(fromJson: _taskListData)  List<TaskApi> data)  $default,) {final _that = this;
switch (_that) {
case _TaskListApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(fromJson: _taskListData)  List<TaskApi> data)?  $default,) {final _that = this;
switch (_that) {
case _TaskListApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskListApi implements TaskListApi {
  const _TaskListApi({@JsonKey(fromJson: _taskListData)  List<TaskApi> data = const []}): _data = data;
  factory _TaskListApi.fromJson(Map<String, dynamic> json) => _$TaskListApiFromJson(json);

 final  List<TaskApi> _data;
@override@JsonKey(fromJson: _taskListData) List<TaskApi> get data {
  if (_data is EqualUnmodifiableListView) return _data;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_data);
}


/// Create a copy of TaskListApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskListApiCopyWith<_TaskListApi> get copyWith => __$TaskListApiCopyWithImpl<_TaskListApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskListApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskListApi&&const DeepCollectionEquality().equals(other.data, _data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,const DeepCollectionEquality().hash(_data));
}

@override
String toString() {
    return 'TaskListApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TaskListApiCopyWith<$Res> implements $TaskListApiCopyWith<$Res> {
  factory _$TaskListApiCopyWith(_TaskListApi value, $Res Function(_TaskListApi) _then) = __$TaskListApiCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(fromJson: _taskListData) List<TaskApi> data
});




}
/// @nodoc
class __$TaskListApiCopyWithImpl<$Res>
    implements _$TaskListApiCopyWith<$Res> {
  __$TaskListApiCopyWithImpl(this._self, this._then);

  final _TaskListApi _self;
  final $Res Function(_TaskListApi) _then;

/// Create a copy of TaskListApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TaskListApi(
data: null == data ? _self._data : data // ignore: cast_nullable_to_non_nullable
as List<TaskApi>,
  ));
}


}


/// @nodoc
mixin _$TaskItemApi {

 TaskApi get data;
/// Create a copy of TaskItemApi
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TaskItemApiCopyWith<TaskItemApi> get copyWith => _$TaskItemApiCopyWithImpl<TaskItemApi>(this as TaskItemApi, _$identity);

  /// Serializes this TaskItemApi to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as TaskItemApi;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TaskItemApi&&(identical(other.data, _this.data) || other.data == _this.data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as TaskItemApi;
  return Object.hash(runtimeType,_this.data);
}

@override
String toString() {
  final _this = this as TaskItemApi;
  return 'TaskItemApi(data: ${_this.data})';
}


}

/// @nodoc
abstract mixin class $TaskItemApiCopyWith<$Res>  {
  factory $TaskItemApiCopyWith(TaskItemApi value, $Res Function(TaskItemApi) _then) = _$TaskItemApiCopyWithImpl;
@useResult
$Res call({
 TaskApi data
});


$TaskApiCopyWith<$Res> get data;

}
/// @nodoc
class _$TaskItemApiCopyWithImpl<$Res>
    implements $TaskItemApiCopyWith<$Res> {
  _$TaskItemApiCopyWithImpl(this._self, this._then);

  final TaskItemApi _self;
  final $Res Function(TaskItemApi) _then;

/// Create a copy of TaskItemApi
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? data = null,}) {
  return _then(TaskItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TaskApi,
  ));
}
/// Create a copy of TaskItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskApiCopyWith<$Res> get data {
  
  return $TaskApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}


/// Adds pattern-matching-related methods to [TaskItemApi].
extension TaskItemApiPatterns on TaskItemApi {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TaskItemApi value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TaskItemApi() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TaskItemApi value)  $default,){
final _that = this;
switch (_that) {
case _TaskItemApi():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TaskItemApi value)?  $default,){
final _that = this;
switch (_that) {
case _TaskItemApi() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( TaskApi data)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TaskItemApi() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( TaskApi data)  $default,) {final _that = this;
switch (_that) {
case _TaskItemApi():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( TaskApi data)?  $default,) {final _that = this;
switch (_that) {
case _TaskItemApi() when $default != null:
return $default(_that.data);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TaskItemApi implements TaskItemApi {
  const _TaskItemApi({required this.data});
  factory _TaskItemApi.fromJson(Map<String, dynamic> json) => _$TaskItemApiFromJson(json);

@override final  TaskApi data;

/// Create a copy of TaskItemApi
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TaskItemApiCopyWith<_TaskItemApi> get copyWith => __$TaskItemApiCopyWithImpl<_TaskItemApi>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TaskItemApiToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _TaskItemApi&&(identical(other.data, data) || other.data == data));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,data);
}

@override
String toString() {
    return 'TaskItemApi(data: $data)';
}


}

/// @nodoc
abstract mixin class _$TaskItemApiCopyWith<$Res> implements $TaskItemApiCopyWith<$Res> {
  factory _$TaskItemApiCopyWith(_TaskItemApi value, $Res Function(_TaskItemApi) _then) = __$TaskItemApiCopyWithImpl;
@override @useResult
$Res call({
 TaskApi data
});


@override $TaskApiCopyWith<$Res> get data;

}
/// @nodoc
class __$TaskItemApiCopyWithImpl<$Res>
    implements _$TaskItemApiCopyWith<$Res> {
  __$TaskItemApiCopyWithImpl(this._self, this._then);

  final _TaskItemApi _self;
  final $Res Function(_TaskItemApi) _then;

/// Create a copy of TaskItemApi
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? data = null,}) {
  return _then(_TaskItemApi(
data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as TaskApi,
  ));
}

/// Create a copy of TaskItemApi
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TaskApiCopyWith<$Res> get data {
  
  return $TaskApiCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}
}

// dart format on
